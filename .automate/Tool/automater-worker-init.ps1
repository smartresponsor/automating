# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp

[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [string]$WorkerRelPath = "Domain/Ai/agent-trigger/worker",
    [string]$DefaultWorkflowFile = "automater-dispatch.yml"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-GitRemoteOriginUrl {
    param([Parameter(Mandatory = $true)][string]$WorkDir)
    try {
        $p = Start-Process -FilePath "git" -ArgumentList @("-C",$WorkDir,"remote","get-url","origin") -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$env:TEMP\automater_git_out.txt"
        $url = (Get-Content "$env:TEMP\automater_git_out.txt" -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($url) { return $url.Trim() }
    } catch {}
    return ""
}

function Parse-GitHubOwnerRepo {
    param([Parameter(Mandatory = $true)][string]$OriginUrl)
    # supports https://github.com/owner/repo(.git) and git@github.com:owner/repo(.git)
    $u = $OriginUrl.Trim()
    if ($u -match "github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$") {
        return @{ Owner = $Matches.owner; Repo = $Matches.repo }
    }
    return @{ Owner = ""; Repo = "" }
}

$root = (Resolve-Path $RepoRoot).Path
$workerDir = Join-Path $root $WorkerRelPath
$wranglerToml = Join-Path $workerDir "wrangler.toml"

if (-not (Test-Path $wranglerToml)) {
    throw "Missing $wranglerToml"
}

$origin = Get-GitRemoteOriginUrl -WorkDir $root
$info = Parse-GitHubOwnerRepo -OriginUrl $origin

if (-not $info.Owner -or -not $info.Repo) {
    # fallback to folder name
    $info = @{ Owner = "marketing-america-corp"; Repo = (Split-Path $root -Leaf) }
}

$workerName = ($info.Repo + "-automater-trigger").ToLowerInvariant()

$toml = Get-Content $wranglerToml -Raw -Encoding UTF8
$toml = $toml -replace '^(name\s*=\s*)".*"$', ('$1"' + $workerName + '"')
$toml = $toml -replace '^(GH_OWNER\s*=\s*)".*"$', ('$1"' + $info.Owner + '"')
$toml = $toml -replace '^(GH_REPO\s*=\s*)".*"$', ('$1"' + $info.Repo + '"')
$toml = $toml -replace '^(GH_WORKFLOW\s*=\s*)".*"$', ('$1"' + $DefaultWorkflowFile + '"')

Set-Content -Path $wranglerToml -Value $toml -Encoding UTF8

Write-Host "Updated wrangler.toml:"
Write-Host ("  name=" + $workerName)
Write-Host ("  GH_OWNER=" + $info.Owner)
Write-Host ("  GH_REPO=" + $info.Repo)
Write-Host ("  GH_WORKFLOW=" + $DefaultWorkflowFile)
