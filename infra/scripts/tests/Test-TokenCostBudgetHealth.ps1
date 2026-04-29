[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$scriptPath = Join-Path $repoRoot "infra\monitoring\Test-TokenCostBudgetHealth.ps1"
$fixturePath = Join-Path $repoRoot "infra\scripts\tests\fixtures\token_cost_budget_health_fixture_qua524.json"
$outDir = Join-Path $env:TEMP "qua524_token_cost_health"

if (Test-Path -LiteralPath $outDir) { Remove-Item -LiteralPath $outDir -Recurse -Force }

$raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InputRunsPath $fixturePath `
    -MonthlyTokenCap 850000 `
    -WarnThresholdPct 70 `
    -HighWarnThresholdPct 80 `
    -CriticalThresholdPct 95 `
    -SnapshotDirectory $outDir 2>&1

if ($LASTEXITCODE -ne 1) {
    throw "Expected exit code 1 (warn), got $LASTEXITCODE. Output: $($raw | Out-String)"
}

$obj = (($raw | Out-String) | ConvertFrom-Json -ErrorAction Stop)
if ($obj.status -ne "warn") { throw "Expected status=warn, got $($obj.status)" }
if ($obj.alarm.breached_threshold_pct -ne 70) { throw "Expected breached_threshold_pct=70, got $($obj.alarm.breached_threshold_pct)" }
if ($obj.totals.monthly_forecast_linear -le 0) { throw "Expected monthly forecast > 0." }
if (-not (Test-Path -LiteralPath $obj.output.json_path)) { throw "JSON snapshot missing: $($obj.output.json_path)" }
if (-not (Test-Path -LiteralPath $obj.output.markdown_path)) { throw "Markdown summary missing: $($obj.output.markdown_path)" }

Write-Host "PASS Test-TokenCostBudgetHealth"
