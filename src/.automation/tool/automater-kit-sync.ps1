# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Automater Kit consumer sync:
# - Pull latest release asset from source repo
# - Verify sha256
# - Apply files (copy over)
# - Create branch + PR

[CmdletBinding()]
param(
  [string]$SourceOwner = $env:AUTOMATER_KIT_OWNER,
  [string]$SourceRepo  = $env:AUTOMATER_KIT_REPO,
  [string]$AssetZip    = $(if ($env:AUTOMATER_KIT_ASSET_ZIP) { $env:AUTOMATER_KIT_ASSET_ZIP } else { "automater-kit.zip" }),
  [string]$AssetSha    = $(if ($env:AUTOMATER_KIT_ASSET_SHA) { $env:AUTOMATER_KIT_ASSET_SHA } else { "automater-kit.sha256" }),
  [string]$LockPath    = $(if ($env:AUTOMATER_KIT_LOCK_PATH) { $env:AUTOMATER_KIT_LOCK_PATH } else { ".automatingr/automater-kit.lock.json" }),
  [string]$BranchPrefix = $(if ($env:AUTOMATER_KIT_BRANCH_PREFIX) { $env:AUTOMATER_KIT_BRANCH_PREFIX } else { "automater-kit" }),
  [string]$BaseBranch  = $(if ($env:AUTOMATER_BASE_BRANCH) { $env:AUTOMATER_BASE_BRANCH } else { "master" }),
  [switch]$NoPr,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Require([string]$Name, [string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) { throw "Missing required value: $Name" }
}

function EnsureDir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

function ReadJson([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
  return $raw | ConvertFrom-Json
}

function WriteJson([string]$Path, $Obj) {
  $dir = Split-Path -Parent $Path
  EnsureDir $dir
  ($Obj | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Sha256File([string]$Path) {
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Git([string[]]$Args) {
  $p = Start-Process -FilePath git -ArgumentList $Args -NoNewWindow -Wait -PassThru
  if ($p.ExitCode -ne 0) { throw "git failed: $($Args -join ' ')" }
}

function Gh([string[]]$Args) {
  $p = Start-Process -FilePath gh -ArgumentList $Args -NoNewWindow -Wait -PassThru
  if ($p.ExitCode -ne 0) { throw "gh failed: $($Args -join ' ')" }
}

function WithGhToken([string]$Token, [scriptblock]$Block) {
  $prev = $env:GH_TOKEN
  try {
    $env:GH_TOKEN = $Token
    & $Block
  } finally {
    $env:GH_TOKEN = $prev
  }
}

Require "AUTOMATER_KIT_OWNER" $SourceOwner
Require "AUTOMATER_KIT_REPO" $SourceRepo

$writeToken = $env:GITHUB_TOKEN
if ([string]::IsNullOrWhiteSpace($writeToken)) { throw "Missing GITHUB_TOKEN." }

$readToken = $(if (-not [string]::IsNullOrWhiteSpace($env:AUTOMATER_SOURCE_TOKEN)) { $env:AUTOMATER_SOURCE_TOKEN } else { $writeToken })

$tempRoot = $(if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { $env:RUNNER_TEMP } else { $env:TEMP })
EnsureDir $tempRoot

# 1) Determine latest release
$relJsonPath = Join-Path $tempRoot "automater-release.json"
WithGhToken $readToken {
  Gh @("api", "repos/$SourceOwner/$SourceRepo/releases/latest", "--jq", ".", "-o", $relJsonPath)
}

$rel = Get-Content -LiteralPath $relJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$tag = [string]$rel.tag_name
if ([string]::IsNullOrWhiteSpace($tag)) { throw "No tag_name in latest release response." }

# 2) Compare lock
$lock = ReadJson $LockPath
if ($lock -and $lock.tag -eq $tag) {
  Write-Host "No update: already on $tag"
  exit 0
}

# 3) Download assets
$tmp = Join-Path $tempRoot ("automater-kit-" + $tag.Replace("/","_"))
if (Test-Path -LiteralPath $tmp) { Remove-Item -Recurse -Force -LiteralPath $tmp }
New-Item -ItemType Directory -Path $tmp | Out-Null

WithGhToken $readToken {
  Gh @("release", "download", $tag, "-R", "$SourceOwner/$SourceRepo", "-p", $AssetZip, "-p", $AssetSha, "-D", $tmp)
}

$zipPath = Join-Path $tmp $AssetZip
$shaPath = Join-Path $tmp $AssetSha
if (-not (Test-Path -LiteralPath $zipPath)) { throw "Missing downloaded asset: $AssetZip" }
if (-not (Test-Path -LiteralPath $shaPath)) { throw "Missing downloaded asset: $AssetSha" }

$expected = (Get-Content -LiteralPath $shaPath -Raw -Encoding UTF8).Trim().Split(" ")[0].ToLowerInvariant()
$actual = Sha256File $zipPath
if ($expected -ne $actual) { throw "SHA256 mismatch. expected=$expected actual=$actual" }

Write-Host "Downloaded $AssetZip ($actual) from $SourceOwner/$SourceRepo@$tag"

if ($DryRun) {
  Write-Host "DryRun: skipping apply/commit."
  exit 0
}

# 4) Extract and apply
$extractDir = Join-Path $tmp "extract"
EnsureDir $extractDir

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractDir)

$payloadRoot = Join-Path $extractDir "automater-kit"
if (-not (Test-Path -LiteralPath $payloadRoot)) { throw "Invalid kit zip: missing top-level folder 'automater-kit'." }

$backupRoot = Join-Path ".automatingr/backup" $tag
EnsureDir $backupRoot

$files = Get-ChildItem -LiteralPath $payloadRoot -Recurse -File
foreach ($f in $files) {
  $relPath = $f.FullName.Substring($payloadRoot.Length).TrimStart("\","/")
  $dst = Join-Path (Get-Location) $relPath
  $dstDir = Split-Path -Parent $dst
  EnsureDir $dstDir

  if (Test-Path -LiteralPath $dst) {
    $bak = Join-Path $backupRoot $relPath
    $bakDir = Split-Path -Parent $bak
    EnsureDir $bakDir
    Copy-Item -LiteralPath $dst -Destination $bak -Force
  }
  Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
}

$lockObj = [pscustomobject]@{
  source = "$SourceOwner/$SourceRepo"
  tag = $tag
  sha256 = $actual
  appliedAt = (Get-Date).ToString("o")
}
WriteJson $LockPath $lockObj

# 5) Commit + PR
Git @("checkout","-B","$BranchPrefix/$tag")
Git @("add","-A")

$st = (git status --porcelain)
if ([string]::IsNullOrWhiteSpace($st)) {
  Write-Host "No changes after apply."
  exit 0
}

Git @("config","user.name","automater-bot")
Git @("config","user.email","automater-bot@users.noreply.github.com")
Git @("commit","-m","automater kit sync: $tag")
Git @("push","-u","origin","$BranchPrefix/$tag","--force-with-lease")

if ($NoPr) {
  Write-Host "NoPr: branch pushed."
  exit 0
}

WithGhToken $writeToken {
  $prListPath = Join-Path $tempRoot "automater-pr.json"
  Gh @("pr","list","--head","$BranchPrefix/$tag","--json","number,title,url","-o",$prListPath)
  $prs = Get-Content -LiteralPath $prListPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($prs -and $prs.Count -gt 0) {
    Write-Host "PR already exists: $($prs[0].url)"
    exit 0
  }
  Gh @("pr","create",
    "--title","automater kit sync: $tag",
    "--body","Automated sync from $SourceOwner/$SourceRepo release $tag.",
    "--head","$BranchPrefix/$tag",
    "--base",$BaseBranch
  )
}

Write-Host "PR created."
