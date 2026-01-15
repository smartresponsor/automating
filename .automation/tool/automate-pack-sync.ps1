# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Purpose: Multi-pack consumer engine. Downloads release assets, verifies sha256, applies files, and pushes directly to base branch.

[CmdletBinding()]
param(
  [string]$PacksPath = ".automation/packs.json",
  [string]$LockDir = ".automation/lock",
  [string]$BackupDir = ".automation/backup",
  [string]$WorkDir = ".automation/.tmp",
  [string]$OnlyId = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function EnsureDir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
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
  ($Obj | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $Path -Encoding UTF8
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

function ParseIsoDurationSeconds([string]$Dur) {
  if ([string]::IsNullOrWhiteSpace($Dur)) { return 0 }
  $d = $Dur.Trim().ToUpperInvariant()
  $rx = '^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$'
  $m = [regex]::Match($d, $rx)
  if (-not $m.Success) { throw "Invalid ISO duration: $Dur (expected PnD or PTnHnM or PnDTnHnM)" }
  $days = 0; $hours = 0; $mins = 0; $secs = 0
  if ($m.Groups[1].Success) { $days = [int]$m.Groups[1].Value }
  if ($m.Groups[2].Success) { $hours = [int]$m.Groups[2].Value }
  if ($m.Groups[3].Success) { $mins = [int]$m.Groups[3].Value }
  if ($m.Groups[4].Success) { $secs = [int]$m.Groups[4].Value }
  return ($days * 86400) + ($hours * 3600) + ($mins * 60) + $secs
}

function NowUtc() { return [DateTimeOffset]::UtcNow }

function ShouldThrottle([string]$PackId, [string]$TimerIso) {
  $triggerTag = [string]$env:AUTOMATE_TRIGGER_TAG
  $triggerPack = [string]$env:AUTOMATE_TRIGGER_PACK_ID
  if (-not [string]::IsNullOrWhiteSpace($triggerTag)) {
    if ([string]::IsNullOrWhiteSpace($triggerPack) -or $triggerPack -eq $PackId) { return $false }
  }

  $lockPath = Join-Path $LockDir "$PackId.json"
  $lock = ReadJson $lockPath
  if (-not $lock) { return $false }

  $last = $null
  try { $last = [DateTimeOffset]::Parse([string]$lock.appliedAt) } catch { return $false }

  $seconds = ParseIsoDurationSeconds $TimerIso
  if ($seconds -le 0) { return $false }

  $age = ((NowUtc) - $last).TotalSeconds
  return ($age -lt $seconds)
}

function CopyTree([string]$FromDir, [string]$ToDir, [string]$PackId, [string]$Tag) {
  $files = Get-ChildItem -LiteralPath $FromDir -Recurse -File
  foreach ($f in $files) {
    $rel = $f.FullName.Substring($FromDir.Length).TrimStart('\','/')
    $dst = Join-Path $ToDir $rel
    $dstDir = Split-Path -Parent $dst
    EnsureDir $dstDir

    if (Test-Path -LiteralPath $dst) {
      $bakRoot = Join-Path $BackupDir $PackId
      $bakRoot = Join-Path $bakRoot $Tag
      $bak = Join-Path $bakRoot $rel
      $bakDir = Split-Path -Parent $bak
      EnsureDir $bakDir
      Copy-Item -LiteralPath $dst -Destination $bak -Force
    }

    Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
  }
}

function GetLatestTag([string]$Owner, [string]$Repo, [string]$ReadToken) {
  $tmp = Join-Path $WorkDir "release-latest.json"
  WithGhToken $ReadToken {
    Gh @("api","repos/$Owner/$Repo/releases/latest","--jq",".","-o",$tmp)
  }
  $rel = Get-Content -LiteralPath $tmp -Raw -Encoding UTF8 | ConvertFrom-Json
  $tag = [string]$rel.tag_name
  if ([string]::IsNullOrWhiteSpace($tag)) { throw "No tag_name for $Owner/$Repo latest release." }
  return $tag
}

function DownloadAssets([string]$Owner, [string]$Repo, [string]$Tag, [string]$ZipName, [string]$ShaName, [string]$ReadToken) {
  EnsureDir $WorkDir
  $dlDir = Join-Path $WorkDir ("dl-" + $Owner + "-" + $Repo + "-" + $Tag.Replace("/","_"))
  if (Test-Path -LiteralPath $dlDir) { Remove-Item -Recurse -Force -LiteralPath $dlDir }
  New-Item -ItemType Directory -Path $dlDir | Out-Null

  WithGhToken $ReadToken {
    Gh @("release","download",$Tag,"-R","$Owner/$Repo","-p",$ZipName,"-p",$ShaName,"-D",$dlDir)
  }

  $zipPath = Join-Path $dlDir $ZipName
  $shaPath = Join-Path $dlDir $ShaName
  if (-not (Test-Path -LiteralPath $zipPath)) { throw "Missing asset $ZipName in $Owner/$Repo@$Tag" }
  if (-not (Test-Path -LiteralPath $shaPath)) { throw "Missing asset $ShaName in $Owner/$Repo@$Tag" }
  return @{ zip = $zipPath; sha = $shaPath; dir = $dlDir }
}

function VerifySha([string]$ShaPath, [string]$ZipPath) {
  $expected = (Get-Content -LiteralPath $ShaPath -Raw -Encoding UTF8).Trim().Split(" ")[0].ToLowerInvariant()
  $actual = Sha256File $ZipPath
  if ($expected -ne $actual) { throw "SHA256 mismatch. expected=$expected actual=$actual" }
  return $actual
}

function ExtractZip([string]$ZipPath, [string]$ToDir) {
  if (Test-Path -LiteralPath $ToDir) { Remove-Item -Recurse -Force -LiteralPath $ToDir }
  New-Item -ItemType Directory -Path $ToDir | Out-Null
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ToDir)
}

if (-not (Test-Path -LiteralPath $PacksPath)) { throw "Missing packs config: $PacksPath" }

EnsureDir $LockDir
EnsureDir $BackupDir
EnsureDir $WorkDir

$config = ReadJson $PacksPath
if (-not $config) { throw "Invalid packs config: $PacksPath" }

$defaults = $config.defaults
$packs = @($config.packs)

if ($packs.Count -eq 0) { Write-Host "No packs configured."; exit 0 }

$baseBranch = $(if ($env:AUTOMATE_BASE_BRANCH) { [string]$env:AUTOMATE_BASE_BRANCH } elseif ($defaults.baseBranch) { [string]$defaults.baseBranch } else { "master" })

$writeToken = [string]$env:GITHUB_TOKEN
if ([string]::IsNullOrWhiteSpace($writeToken)) { throw "Missing GITHUB_TOKEN." }

$readToken = $(if (-not [string]::IsNullOrWhiteSpace([string]$env:AUTOMATE_SOURCE_TOKEN)) { [string]$env:AUTOMATE_SOURCE_TOKEN } else { $writeToken })

Git @("checkout",$baseBranch)
Git @("pull","--ff-only","origin",$baseBranch)

$globalTimer = $(if ($env:AUTOMATE_PUSH_TIMER) { [string]$env:AUTOMATE_PUSH_TIMER } elseif ($defaults.pushTimer) { [string]$defaults.pushTimer } else { "PT6H" })

$applied = New-Object System.Collections.Generic.List[object]

foreach ($pack in $packs) {
  $id = [string]$pack.id
  if ([string]::IsNullOrWhiteSpace($id)) { continue }
  if (-not [string]::IsNullOrWhiteSpace($OnlyId) -and $id -ne $OnlyId) { continue }

  $owner = [string]$pack.source.owner
  $repo  = [string]$pack.source.repo
  if ([string]::IsNullOrWhiteSpace($owner) -or [string]::IsNullOrWhiteSpace($repo)) { throw "Pack $id missing source owner/repo." }

  $zipName = $(if ($pack.source.assetZip) { [string]$pack.source.assetZip } elseif ($defaults.assetZip) { [string]$defaults.assetZip } else { "automate-kit.zip" })
  $shaName = $(if ($pack.source.assetSha) { [string]$pack.source.assetSha } elseif ($defaults.assetSha) { [string]$defaults.assetSha } else { "automate-kit.sha256" })
  $topFolder = $(if ($pack.source.topFolder) { [string]$pack.source.topFolder } elseif ($defaults.topFolder) { [string]$defaults.topFolder } else { "" })
  $targetRoot = $(if ($pack.apply.targetRoot) { [string]$pack.apply.targetRoot } elseif ($defaults.targetRoot) { [string]$defaults.targetRoot } else { "." })

  $timer = $(if ($pack.apply.pushTimer) { [string]$pack.apply.pushTimer } else { $globalTimer })
  if (ShouldThrottle $id $timer) {
    Write-Host "Throttle: skip $id (timer=$timer)"
    continue
  }

  $triggerTag = [string]$env:AUTOMATE_TRIGGER_TAG
  $triggerPack = [string]$env:AUTOMATE_TRIGGER_PACK_ID

  if (-not [string]::IsNullOrWhiteSpace($triggerTag) -and (-not [string]::IsNullOrWhiteSpace($triggerPack)) -and $triggerPack -ne $id) {
    continue
  }

  $tag = $null
  if (-not [string]::IsNullOrWhiteSpace($triggerTag) -and ([string]::IsNullOrWhiteSpace($triggerPack) -or $triggerPack -eq $id)) {
    $tag = $triggerTag
  } else {
    $tag = GetLatestTag $owner $repo $readToken
  }

  $lockPath = Join-Path $LockDir "$id.json"
  $lock = ReadJson $lockPath
  if ($lock -and ([string]$lock.tag -eq [string]$tag)) {
    Write-Host "No update: $id already on $tag"
    continue
  }

  $dl = DownloadAssets $owner $repo $tag $zipName $shaName $readToken
  $sha = VerifySha $dl.sha $dl.zip

  $extractRoot = Join-Path $dl.dir "extract"
  ExtractZip $dl.zip $extractRoot

  $payloadRoot = $extractRoot
  if (-not [string]::IsNullOrWhiteSpace($topFolder)) {
    $candidate = Join-Path $extractRoot $topFolder
    if (Test-Path -LiteralPath $candidate) { $payloadRoot = $candidate }
  }

  if (-not (Test-Path -LiteralPath $payloadRoot)) { throw "Invalid payload root for $id at $payloadRoot" }

  $dstRoot = Resolve-Path -LiteralPath $targetRoot
  CopyTree $payloadRoot $dstRoot.Path $id $tag

  $lockObj = [pscustomobject]@{
    id = $id
    source = "$owner/$repo"
    tag = $tag
    sha256 = $sha
    appliedAt = ((NowUtc).ToString("o"))
  }
  WriteJson $lockPath $lockObj
  $applied.Add(@{ id = $id; tag = $tag }) | Out-Null

  Write-Host "Applied: $id@$tag"
}

$st = (git status --porcelain)
if ([string]::IsNullOrWhiteSpace($st)) {
  Write-Host "No changes to commit."
  exit 0
}

Git @("config","user.name","automate-bot")
Git @("config","user.email","automate-bot@users.noreply.github.com")

$parts = @()
foreach ($a in $applied) { $parts += ("{0}@{1}" -f $a.id, $a.tag) }
$msg = "automate pack sync: " + ($parts -join "; ")
if ($parts.Count -eq 0) { $msg = "automate pack sync" }

Git @("add","-A")
Git @("commit","-m",$msg)
Git @("push","origin",$baseBranch)

Write-Host "Pushed to $baseBranch."
