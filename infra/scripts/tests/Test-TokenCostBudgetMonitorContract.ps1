[CmdletBinding()]
param(
    [string]$ScriptPath = "C:\QM\repo\infra\monitoring\Test-TokenCostBudgetHealth.ps1",
    [string]$FixturePath = "C:\QM\repo\infra\scripts\tests\fixtures\token_cost_runs_fixture.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ScriptPath)) { throw "Missing script: $ScriptPath" }
if (-not (Test-Path -LiteralPath $FixturePath)) { throw "Missing fixture: $FixturePath" }

$prev = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath -InputRunsPath $FixturePath -DailyTokenBudget 10000 -MonthlyTokenCap 100000 -NoWriteSnapshot -NoWriteMarkdownSummary 2>&1
$exitCode = $LASTEXITCODE
$ErrorActionPreference = $prev
if ($exitCode -ne 0) {
    throw "Expected success for fixture run; exit=$exitCode output=$($out -join ' | ')"
}

$json = ($out -join "`n") | ConvertFrom-Json
if (-not $json.per_agent) { throw "Missing per_agent rollup." }
if ($json.totals.tokens_last_24h -le 0) { throw "tokens_last_24h was not computed." }
if ($json.totals.tokens_last_7d -le 0) { throw "tokens_last_7d was not computed." }
if (-not $json.totals.monthly_forecast_linear) { throw "monthly_forecast_linear missing." }
if ($null -eq $json.alarm.breached_threshold_pct -and $json.alarm.level -ne "ok") { throw "alarm threshold wiring invalid." }

Write-Host "PASS: token-cost contract fields present and computed."
