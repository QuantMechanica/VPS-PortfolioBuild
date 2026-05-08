[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$publicDataDir = Join-Path $RepoRoot "public-data"
$fixturesDir = Join-Path $RepoRoot "scripts\tests\fixtures\public_snapshot_validation"

if (-not (Get-Command Test-Json -ErrorAction SilentlyContinue)) {
    throw "Test-Json is required for schema validation."
}

$targets = @(
    @{
        Name = "public-snapshot"
        Schema = Join-Path $publicDataDir "public-snapshot.schema.json"
        Data = Join-Path $publicDataDir "public-snapshot.json"
        Negative = Join-Path $fixturesDir "public-snapshot.invalid.extra-field.json"
    },
    @{
        Name = "process-roadmap"
        Schema = Join-Path $publicDataDir "process-roadmap.schema.json"
        Data = Join-Path $publicDataDir "process-roadmap.json"
        Negative = Join-Path $fixturesDir "process-roadmap.invalid.missing-required.json"
    },
    @{
        Name = "strategy-archive"
        Schema = Join-Path $publicDataDir "strategy-archive.schema.json"
        Data = Join-Path $publicDataDir "strategy-archive.json"
        Negative = Join-Path $fixturesDir "strategy-archive.invalid.wrong-enum.json"
    },
    @{
        Name = "company-operating-model"
        Schema = Join-Path $publicDataDir "company-operating-model.schema.json"
        Data = Join-Path $publicDataDir "company-operating-model.json"
        Negative = Join-Path $fixturesDir "company-operating-model.invalid.extra-field.json"
    }
)

foreach ($target in $targets) {
    foreach ($path in @($target.Schema, $target.Data, $target.Negative)) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Missing required file for $($target.Name): $path"
        }
    }

    $validJson = Get-Content -LiteralPath $target.Data -Raw
    $isValid = $false
    try {
        $isValid = $validJson | Test-Json -SchemaFile $target.Schema -ErrorAction Stop
    }
    catch {
        $isValid = $false
    }
    if (-not $isValid) {
        throw "Validation failed for $($target.Name): $($target.Data)"
    }

    $invalidJson = Get-Content -LiteralPath $target.Negative -Raw
    $unexpectedValid = $false
    try {
        $unexpectedValid = $invalidJson | Test-Json -SchemaFile $target.Schema -ErrorAction Stop
    }
    catch {
        $unexpectedValid = $false
    }
    if ($unexpectedValid) {
        throw "Negative fixture unexpectedly passed for $($target.Name): $($target.Negative)"
    }

    Write-Host "PASS $($target.Name)"
}

Write-Host "All public snapshot schemas validated (positive + negative)."
