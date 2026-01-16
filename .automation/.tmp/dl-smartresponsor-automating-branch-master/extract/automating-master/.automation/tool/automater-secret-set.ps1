# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^K\d+$")]
    [string]$Kid = "K1",

    [Parameter(Mandatory = $true)]
    [string]$Secret,

    [ValidateSet("Process","User","Machine")]
    [string]$Scope = "User"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$kidUpper = $Kid.Trim().ToUpperInvariant()
$Secret = ($Secret -replace "\r?\n", "").Trim()
$name = "AUTOMATER_TRIGGER_SECRET_$kidUpper"

[Environment]::SetEnvironmentVariable($name, $Secret, $Scope)

# Also set for current session
Set-Item -Path "Env:$name" -Value $Secret

Write-Host "Set $name ($Scope) and current session."
