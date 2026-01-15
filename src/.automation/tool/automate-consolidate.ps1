# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Consolidate legacy top-level folders into .automation-only layout.

[CmdletBinding()]
param(
  [string]$Root = ".",
  [switch]$RemoveLegacy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Push-Location $Root
try {
  if (-not (Test-Path -LiteralPath ".automation")) {
    throw "Missing .automation. Apply the kit patch first."
  }

  $legacy = @("tool","Domain","docs","demo")
  $found = $legacy | Where-Object { Test-Path -LiteralPath $_ }
  if ($found.Count -eq 0) {
    Write-Host "No legacy folders found."
    exit 0
  }

  $stash = Join-Path ".automation" "legacy"
  if (-not (Test-Path -LiteralPath $stash)) { New-Item -ItemType Directory -Path $stash | Out-Null }

  foreach ($p in $found) {
    $dst = Join-Path $stash $p
    if (Test-Path -LiteralPath $dst) { Remove-Item -Recurse -Force -LiteralPath $dst }
    Write-Host "Move legacy $p -> $dst"
    Move-Item -Force -LiteralPath $p -Destination $dst
  }

  if ($RemoveLegacy) {
    Write-Host "Legacy folders moved under .automation/legacy."
  } else {
    Write-Host "Done. Review .automation/legacy and commit."
  }
} finally {
  Pop-Location
}
