# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Url,

    [Parameter(Mandatory = $true)]
    [ValidateSet("scan","health","doctor","validate","plan","codex","pr")]
    [string]$Task,

    [string]$Ref = "master",
    [string]$Kind = "fix",
    [string]$Message = "agent update",
    [string]$Note = "",

    [ValidatePattern("^K\d+$")]
    [string]$Kid = "K1",

    [int]$TimeoutSec = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-HexString {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)
    ($Bytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        ConvertTo-HexString ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
    } finally {
        $sha.Dispose()
    }
}

function Get-HmacSha256Hex {
    param(
        [Parameter(Mandatory = $true)][string]$Secret,
        [Parameter(Mandatory = $true)][string]$Value
    )
    $hmac = [System.Security.Cryptography.HMACSHA256]::new(
        [System.Text.Encoding]::UTF8.GetBytes($Secret)
    )
    try {
        ConvertTo-HexString ($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
    } finally {
        $hmac.Dispose()
    }
}

function Get-AgentSecret {
    param([Parameter(Mandatory = $true)][string]$KidUpper)

    $byKid = "SR_TRIGGER_SECRET_$KidUpper"
    $v = (Get-Item "Env:$byKid" -ErrorAction SilentlyContinue).Value
    if ($v) { return @{ Secret = $v; Source = $byKid } }

    $legacy = (Get-Item "Env:SR_TRIGGER_SECRET" -ErrorAction SilentlyContinue).Value
    if ($legacy) { return @{ Secret = $legacy; Source = "SR_TRIGGER_SECRET" } }

    throw "Missing env var $byKid (or SR_TRIGGER_SECRET)"
}

function ConvertTo-CanonicalJson {
    param([Parameter(Mandatory = $true)]$Value)

    if ($Value -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}
        foreach ($k in ($Value.Keys | Sort-Object)) {
            $ordered[$k] = ConvertTo-CanonicalJson $Value[$k]
        }
        return $ordered
    }

    if ($Value -is [array]) {
        return @($Value | ForEach-Object { ConvertTo-CanonicalJson $_ })
    }

    return $Value
}

$kidUpper = $Kid.Trim().ToUpperInvariant()
$secretInfo = Get-AgentSecret -KidUpper $kidUpper
$secret = [string]$secretInfo.Secret

$timestamp = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

$bodyObj = @{
    task   = $Task
    ref    = $Ref
    inputs = @{
        kind    = $Kind
        message = $Message
        note    = $Note
    }
}

$bodyCanon = ConvertTo-CanonicalJson $bodyObj
$body = ($bodyCanon | ConvertTo-Json -Depth 8 -Compress)

# Normalize strictly (string-only protocol).
$body = $body -replace "^\uFEFF", ""
$body = $body -replace "\r?\n", ""
$body = $body.Trim()

$bodyHash = Get-Sha256Hex -Value $body
$signed = "$timestamp.$bodyHash"
$signature = (Get-HmacSha256Hex -Secret $secret -Value $signed).ToLowerInvariant()

$headers = @{
    "Accept"         = "application/json"
    "Content-Type"   = "application/json; charset=utf-8"
    "X-SR-Timestamp" = "$timestamp"
    "X-SR-Kid"       = $kidUpper
    "X-SR-Signature" = $signature
}

Write-Host "POST $Url task=$Task kid=$kidUpper"

Write-Verbose ("timestamp=" + $timestamp)
Write-Verbose ("body=" + $body)
Write-Verbose ("bodyHash=" + $bodyHash)
Write-Verbose ("signed=" + $signed)
Write-Verbose ("signature=" + $signature)
Write-Verbose ("secretSource=" + $secretInfo.Source)
Write-Verbose ("secretSha256=" + (Get-Sha256Hex -Value $secret))

try {
    Invoke-RestMethod -Method Post -Uri $Url -Headers $headers -ContentType "application/json; charset=utf-8" -Body $body -TimeoutSec $TimeoutSec
} catch {
    if ($_.Exception -and $_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $respBody = $reader.ReadToEnd()
            $reader.Close()
            Write-Error $respBody
        } catch {
            throw
        }
    }
    throw
}
