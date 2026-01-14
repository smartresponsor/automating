# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Demo: health + signed dispatch

    [CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUrl,

    [ValidatePattern("^K\d+$")]
    [string]$Kid = "K1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$healthUrl = ($BaseUrl.TrimEnd("/") + "/health")
$dispatchUrl = ($BaseUrl.TrimEnd("/") + "/dispatch")

Write-Host ("GET " + $healthUrl)
Invoke-RestMethod -Method Get -Uri $healthUrl -TimeoutSec 30 | ConvertTo-Json -Depth 8

Write-Host ("POST " + $dispatchUrl + " task=health kid=" + $Kid)
./Domain/tool/automater-call.ps1 -Url $dispatchUrl -Task health -Kid $Kid -TimeoutSec 60 | ConvertTo-Json -Depth 8
