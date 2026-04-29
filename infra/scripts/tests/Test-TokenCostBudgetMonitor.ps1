[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$scriptPath = Join-Path $repoRoot "infra\monitoring\Test-TokenCostBudget.ps1"
$fixturePath = Join-Path $repoRoot "infra\scripts\tests\fixtures\token_cost_runs_fixture_qua524.json"
$outPath = Join-Path $env:TEMP "token_cost_budget_monitor_test_output.json"

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Missing script under test: $scriptPath"
}

if (-not (Test-Path -LiteralPath $fixturePath)) {
    throw "Missing fixture: $fixturePath"
}

$raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InputRunsJsonPath $fixturePath `
    -DailyBudgetUsd 10 `
    -SnapshotPath $outPath 2>&1

if ($LASTEXITCODE -ne 1) {
    throw "Expected exit code 1 (warn), got $LASTEXITCODE. Output: $($raw | Out-String)"
}

$jsonText = $raw | Out-String
$obj = $jsonText | ConvertFrom-Json -ErrorAction Stop

if ($obj.status -ne "warn") { throw "Expected status=warn, got $($obj.status)" }
if (-not $obj.snapshot_written) { throw "Expected snapshot_written=true." }
if ($obj.thresholds.pct_70_crossed -ne $true) { throw "Expected pct_70_crossed=true." }
if ($obj.thresholds.pct_80_crossed -ne $false) { throw "Expected pct_80_crossed=false." }
if ($obj.thresholds.pct_95_crossed -ne $false) { throw "Expected pct_95_crossed=false." }

if (-not (Test-Path -LiteralPath $outPath)) {
    throw "Expected snapshot output file not found: $outPath"
}

Write-Host "PASS Test-TokenCostBudgetMonitor"
