[CmdletBinding()]
param(
    [string]$ScriptPath = "C:\QM\repo\infra\monitoring\Test-TokenCostBudgetHealth.ps1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Target script missing: $ScriptPath"
}

$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath -DailyTokenBudget 100 -FetchLimit 1 2>&1
$code = $LASTEXITCODE
if ($code -eq 0) {
    throw "Expected non-zero exit for missing API config; got code 0. Output: $($out -join ' | ')"
}

Write-Host "PASS: script exists and fails without API config as expected (exit=$code)."
