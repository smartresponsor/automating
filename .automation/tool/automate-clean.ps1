# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Root = ".",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function P([string]$Rel) { return (Join-Path $Root $Rel) }

$targets = @(
  "tool",
  "docs\automate",
  "Domain\Ai\agent-trigger\worker",
  "Domain\Tool\sr-agent-call.ps1",
  "Domain\Tool\sr-agent-task.ps1",
  "Domain\Tool\sr-agent-secret-set.ps1",
  "Domain\Tool\sr-agent-worker-init.ps1",
  "Domain\Tool\automate-call.ps1",
  "Domain\Tool\automate-task.ps1",
  "Domain\Tool\automate-secret-set.ps1",
  "Domain\Tool\automate-worker-init.ps1",
  "Domain\Tool\automate-kit-sync.ps1"
)

Write-Host "automate-clean: planned removals (only if .automation exists)"
if (-not (Test-Path (P ".automation"))) {
  throw ".automation folder not found at Root=$Root. Refusing to clean."
}

foreach ($rel in $targets) {
  $abs = P $rel
  if (Test-Path $abs) {
    if ($DryRun) {
      Write-Host "DRY-RUN: remove $rel"
      continue
    }
    if ($PSCmdlet.ShouldProcess($abs, "Remove")) {
      Remove-Item -Force -Recurse $abs
      Write-Host "removed $rel"
    }
  }
}

Write-Host "automate-clean: done"
