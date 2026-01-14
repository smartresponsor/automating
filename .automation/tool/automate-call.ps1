# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Url,
  [Parameter(Mandatory = $true)][string]$Task,
  [string]$Kid = "K1",
  [string]$Secret = $env:AUTOMATE_TRIGGER_SECRET_K1,
  [int]$Ts = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds(),
  [hashtable]$Payload = @{}
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Sha256Hex([byte[]]$Bytes) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    ($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
  } finally { $sha.Dispose() }
}

function HmacHex([string]$Key, [byte[]]$Data) {
  $h = New-Object System.Security.Cryptography.HMACSHA256([Text.Encoding]::UTF8.GetBytes($Key.Trim()))
  try {
    ($h.ComputeHash($Data) | ForEach-Object { $_.ToString("x2") }) -join ""
  } finally { $h.Dispose() }
}

if ([string]::IsNullOrWhiteSpace($Secret)) {
  $fallback = $env:AUTOMATER_TRIGGER_SECRET_K1
  if (-not [string]::IsNullOrWhiteSpace($fallback)) { $Secret = $fallback }
}
if ([string]::IsNullOrWhiteSpace($Secret)) { throw "Missing secret. Set AUTOMATE_TRIGGER_SECRET_K1." }

$bodyObj = @{ task = $Task; payload = $Payload }
$body = ($bodyObj | ConvertTo-Json -Depth 10 -Compress)
$bodyBytes = [Text.Encoding]::UTF8.GetBytes($body)

$bodyHash = Sha256Hex $bodyBytes
$msg = "$Ts.$bodyHash"
$sig = HmacHex -Key $Secret -Data ([Text.Encoding]::UTF8.GetBytes($msg))

$headers = @{
  "X-AUTOMATE-Kid" = $Kid
  "X-AUTOMATE-Ts" = "$Ts"
  "X-AUTOMATE-Signature" = $sig
}

Write-Host "POST $Url task=$Task kid=$Kid"
Invoke-RestMethod -Method Post -Uri $Url -Headers $headers -ContentType "application/json" -Body $body
