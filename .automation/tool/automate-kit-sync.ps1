# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Sync latest Automate Kit release from source repo and push directly to master.

    [CmdletBinding()]
param(
    [string]$SourceOwner = $env:AUTOMATE_KIT_OWNER,
    [string]$SourceRepo = $env:AUTOMATE_KIT_REPO,
    [string]$BaseBranch = $( if ($env:AUTOMATE_BASE_BRANCH)
{
    $env:AUTOMATE_BASE_BRANCH
}
else
{
    "master"
} ),
    [string]$PushTimer = $( if ($env:AUTOMATE_PUSH_TIMER)
{
    $env:AUTOMATE_PUSH_TIMER
}
elseif ($env:AUTOMATER_PUSH_TIMER)
{
    $env:AUTOMATER_PUSH_TIMER
}
else
{
    "PT6H"
} ),
    [string]$ForceTag = $env:AUTOMATE_FORCE_TAG,
    [string]$AssetZip = "automate-kit.zip",
    [string]$AssetSha = "automate-kit.sha256",
    [string]$LockPath = ".automation/lock/kit.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Require([string]$Name, [string]$Value)
{
    if ( [string]::IsNullOrWhiteSpace($Value))
    {
        throw "Missing required value: $Name"
    }
}

function EnsureDir([string]$Path)
{
    if (-not(Test-Path -LiteralPath $Path))
    {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function ReadJson([string]$Path)
{
    if (-not(Test-Path -LiteralPath $Path))
    {
        return $null
    }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ( [string]::IsNullOrWhiteSpace($raw))
    {
        return $null
    }
    return $raw | ConvertFrom-Json
}

function WriteJson([string]$Path, $Obj)
{
    $dir = Split-Path -Parent $Path
    EnsureDir $dir
    ($Obj | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Sha256File([string]$Path)
{
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Git([string[]]$Args)
{
    $p = Start-Process -FilePath git -ArgumentList $Args -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0)
    {
        throw "git failed: $( $Args -join ' ' )"
    }
}

function Gh([string[]]$Args)
{
    $p = Start-Process -FilePath gh -ArgumentList $Args -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0)
    {
        throw "gh failed: $( $Args -join ' ' )"
    }
}

function WithGhToken([string]$Token, [scriptblock]$Block)
{
    $prev = $env:GITHUB_TOKEN
    try
    {
        $env:GITHUB_TOKEN = $Token; & $Block
    }
    finally
    {
        $env:GITHUB_TOKEN = $prev
    }
}

function TryParseDuration([string]$s)
{
    try
    {
        return [System.Xml.XmlConvert]::ToTimeSpan($s)
    }
    catch
    {
        return [TimeSpan]::FromHours(6)
    }
}

Require "AUTOMATE_KIT_OWNER" $SourceOwner
Require "AUTOMATE_KIT_REPO" $SourceRepo

$writeToken = $env:GITHUB_TOKEN
if ( [string]::IsNullOrWhiteSpace($writeToken))
{
    throw "Missing GITHUB_TOKEN."
}

$readToken = $( if (-not [string]::IsNullOrWhiteSpace($env:AUTOMATE_SOURCE_TOKEN))
{
    $env:AUTOMATE_SOURCE_TOKEN
}
else
{
    $writeToken
} )

$lock = ReadJson $LockPath
$timer = TryParseDuration $PushTimer

if ( [string]::IsNullOrWhiteSpace($ForceTag))
{
    if ($lock -and $lock.lastAppliedAt)
    {
        $last = [DateTimeOffset]::Parse([string]$lock.lastAppliedAt)
        $now = [DateTimeOffset]::UtcNow
        if (($now - $last) -lt $timer)
        {
            Write-Host "Throttle: lastAppliedAt=$( $lock.lastAppliedAt ) timer=$PushTimer"
            exit 0
        }
    }
}

$tempRoot = $( if ($env:RUNNER_TEMP)
{
    $env:RUNNER_TEMP
}
else
{
    $env:TEMP
} )
EnsureDir $tempRoot
$tmp = Join-Path $tempRoot ("automate-kit-" + ([Guid]::NewGuid().ToString("N")))
EnsureDir $tmp

# Determine release tag
$tag = $ForceTag
if ( [string]::IsNullOrWhiteSpace($tag))
{
    $relPath = Join-Path $tmp "release.json"
    WithGhToken $readToken {
        Gh @("api", "repos/$SourceOwner/$SourceRepo/releases/latest", "--jq", ".", "-o", $relPath)
    }
    $rel = (Get-Content -LiteralPath $relPath -Raw -Encoding UTF8) | ConvertFrom-Json
    $tag = [string]$rel.tag_name
    if ( [string]::IsNullOrWhiteSpace($tag))
    {
        throw "No tag_name in latest release."
    }
}

if ($lock -and $lock.tag -eq $tag)
{
    Write-Host "Already applied: $tag"
    exit 0
}

# Download assets
WithGhToken $readToken {
    Gh @("release", "download", $tag, "-R", "$SourceOwner/$SourceRepo", "-p", $AssetZip, "-p", $AssetSha, "-D", $tmp)
}

$zipPath = Join-Path $tmp $AssetZip
$shaPath = Join-Path $tmp $AssetSha
if (-not(Test-Path -LiteralPath $zipPath))
{
    throw "Missing asset: $AssetZip"
}
if (-not(Test-Path -LiteralPath $shaPath))
{
    throw "Missing asset: $AssetSha"
}

$expected = (Get-Content -LiteralPath $shaPath -Raw -Encoding UTF8).Trim().Split(" ")[0].ToLowerInvariant()
$actual = Sha256File $zipPath
if ($expected -ne $actual)
{
    throw "SHA256 mismatch. expected=$expected actual=$actual"
}

Write-Host "Downloaded $AssetZip sha256=$actual tag=$tag"

# Backup current .automation (if exists)
$backupRoot = Join-Path ".automation/backup" $tag
if (Test-Path -LiteralPath ".automation")
{
    EnsureDir $backupRoot
    Copy-Item -Recurse -Force -LiteralPath ".automation" -Destination $backupRoot
}

# Extract
$extractDir = Join-Path $tmp "extract"
EnsureDir $extractDir
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractDir)

$payload = Join-Path $extractDir ".automation"
if (-not(Test-Path -LiteralPath $payload))
{
    throw "Invalid kit zip: missing .automation folder at root."
}

# Apply (overwrite)
Copy-Item -Recurse -Force -LiteralPath $payload -Destination ".automation"

$lockObj = [pscustomobject]@{
    source = "$SourceOwner/$SourceRepo"
    tag = $tag
    sha256 = $actual
    lastAppliedAt = ([DateTimeOffset]::UtcNow).ToString("o")
}
WriteJson $LockPath $lockObj

# Commit + direct push to master
Git @("checkout", $BaseBranch)
Git @("add", "-A")

$st = (git status --porcelain)
if ( [string]::IsNullOrWhiteSpace($st))
{
    Write-Host "No changes."
    exit 0
}

Git @("config", "user.name", "automate-bot")
Git @("config", "user.email", "automate-bot@users.noreply.github.com")
Git @("commit", "-m", "automate kit sync: $tag")
Git @("push", "origin", "HEAD:$BaseBranch")
Write-Host "Pushed to $BaseBranch."
