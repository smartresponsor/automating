# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("scan","health","doctor","validate","plan","codex","pr")]
    [string]$Task,

    [string]$Kind = "fix",
    [string]$Message = "agent update",
    [string]$Note = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-IfCommandExists {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList
    )
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Host "SKIP: $Command not found"
        return
    }
    & $Command @ArgumentList
}

function Invoke-IfPathExists {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList
    )
    if (-not (Test-Path $Path)) {
        Write-Host "SKIP: $Path not found"
        return
    }
    & $Path @ArgumentList
}

function Ensure-Dir {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

switch ($Task) {
    "health" {
        Invoke-IfCommandExists -Command "php" -ArgumentList @("-v")
        Invoke-IfCommandExists -Command "composer" -ArgumentList @("--version")
        if (Test-Path "composer.json") {
            Invoke-IfCommandExists -Command "composer" -ArgumentList @("validate","--no-check-all","--strict")
        } else {
            Write-Host "SKIP: composer.json not found"
        }
        if (Test-Path ".git") {
            Invoke-IfCommandExists -Command "git" -ArgumentList @("status","-sb")
        }
        Write-Host "OK health"
        exit 0
    }

    "scan" {
        if (Test-Path "composer.json") {
            Invoke-IfCommandExists -Command "composer" -ArgumentList @("audit","--no-interaction")
        } else {
            Write-Host "SKIP: composer.json not found"
        }
        Write-Host "OK scan"
        exit 0
    }

    "validate" {
        if (Test-Path "composer.json") {
            Invoke-IfCommandExists -Command "composer" -ArgumentList @("validate","--no-check-all","--strict")
        } else {
            Write-Host "SKIP: composer.json not found"
        }

        if (Test-Path "vendor/bin/phpstan") {
            Invoke-IfPathExists -Path "vendor/bin/phpstan" -ArgumentList @("analyse")
        } else {
            Write-Host "SKIP: vendor/bin/phpstan not found"
        }

        Write-Host "OK validate"
        exit 0
    }

    "doctor" {
        if (Test-Path "vendor/bin/phpunit") {
            Invoke-IfPathExists -Path "vendor/bin/phpunit" -ArgumentList @("--version")
            Invoke-IfPathExists -Path "vendor/bin/phpunit" -ArgumentList @()
        } else {
            Write-Host "SKIP: vendor/bin/phpunit not found"
        }
        Write-Host "OK doctor"
        exit 0
    }

    "plan" {
        Ensure-Dir -Path "report"
        $out = @{
            ok = $true
            task = "plan"
            kind = $Kind
            message = $Message
            note = $Note
            tsUtc = [DateTimeOffset]::UtcNow.ToString("o")
            git = $null
            php = $null
            composer = $null
        }

        try { $out.git = (& git rev-parse HEAD 2>$null) } catch {}
        try { $out.php = (& php -r "echo PHP_VERSION;" 2>$null) } catch {}
        try { $out.composer = (& composer --version 2>$null) } catch {}

        $json = $out | ConvertTo-Json -Depth 6
        Set-Content -Path "report/automater-plan.json" -Value $json -Encoding UTF8

        Write-Host "OK plan: report/automater-plan.json"
        exit 0
    }

    "codex" {
        Ensure-Dir -Path ".github/prompts"
        if (-not (Test-Path ".github/prompts/automater-repo-portrait-rwe.prompt.md")) {
            Copy-Item -Path "tool/template/prompt/automater-repo-portrait-rwe.prompt.md" -Destination ".github/prompts/automater-repo-portrait-rwe.prompt.md"
        }
        Write-Host "OK codex: .github/prompts/automater-repo-portrait-rwe.prompt.md"
        exit 0
    }

    "pr" {
        Write-Host "OK pr (no-op in generic runner)"
        exit 0
    }
}
