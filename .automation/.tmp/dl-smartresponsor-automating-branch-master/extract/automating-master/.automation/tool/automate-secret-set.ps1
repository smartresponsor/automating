# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^K\d+$")]
    [string]$Kid = "K1",

    [Parameter(Mandatory = $true)]
    [string]$Secret,

    [ValidateSet("Process","User","Machine")]
    [string]$Scope = "User",

    [switch]$SetLegacy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$kidUpper = $Kid.Trim().ToUpperInvariant()

# Preferred
$name = "AUTOMATE_TRIGGER_SECRET_$kidUpper"
[Environment]::SetEnvironmentVariable($name, $Secret, $Scope)
Set-Item -Path "Env:$name" -Value $Secret
Write-Host "Set $name ($Scope) and current session."

if ($SetLegacy) {
    $legacy1 = "AUTOMATER_TRIGGER_SECRET_$kidUpper"
    $legacy2 = "SR_TRIGGER_SECRET_$kidUpper"
    [Environment]::SetEnvironmentVariable($legacy1, $Secret, $Scope)
    [Environment]::SetEnvironmentVariable($legacy2, $Secret, $Scope)
    Set-Item -Path "Env:$legacy1" -Value $Secret
    Set-Item -Path "Env:$legacy2" -Value $Secret
    Write-Host "Also set legacy env vars: $legacy1, $legacy2"
}