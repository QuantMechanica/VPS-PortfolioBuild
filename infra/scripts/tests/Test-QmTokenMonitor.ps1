[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$scriptPath = Join-Path $repoRoot "infra\monitoring\Invoke-QmTokenMonitor.ps1"
$agentsFixture = Join-Path $repoRoot "infra\scripts\tests\fixtures\qm_token_monitor_agents_fixture.json"
$prevStateFixture = Join-Path $repoRoot "infra\scripts\tests\fixtures\qm_token_monitor_previous_state_fixture.json"
$tmpState = Join-Path $env:TEMP "qm_token_monitor_state_test.json"
$tmpOutJson = Join-Path $env:TEMP "qm_token_monitor_output_test.json"
$tmpOutMd = Join-Path $env:TEMP "qm_token_monitor_output_test.md"

if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Missing script: $scriptPath" }
if (-not (Test-Path -LiteralPath $agentsFixture)) { throw "Missing fixture: $agentsFixture" }
if (-not (Test-Path -LiteralPath $prevStateFixture)) { throw "Missing fixture: $prevStateFixture" }

Copy-Item -LiteralPath $prevStateFixture -Destination $tmpState -Force

$raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -InputAgentsJsonPath $agentsFixture `
    -StatePath $tmpState `
    -OutputJsonPath $tmpOutJson `
    -OutputMarkdownPath $tmpOutMd `
    -TokenBudgetPath (Join-Path $repoRoot "framework\registry\token_budget.json") 2>&1

$exitCode = $LASTEXITCODE
if ($exitCode -lt 0 -or $exitCode -gt 2) {
    throw "Unexpected exit code: $exitCode"
}

$jsonText = $raw | Out-String
$obj = $jsonText | ConvertFrom-Json -ErrorAction Stop

if ($obj.check -ne "qm_token_monitor") { throw "check mismatch: $($obj.check)" }
if ($obj.spent_cents -le 0) { throw "spent_cents must be positive." }
if ($obj.daily_delta -le 0) { throw "daily_delta must be positive." }
if ($obj.org_cap_pct_used -le 0) { throw "org_cap_pct_used must be positive." }
if (-not $obj.top3_agents) { throw "top3_agents missing." }
if (@($obj.top3_agents).Count -ne 3) { throw "Expected top3_agents count=3." }
if ($null -eq $obj.anomalies) { throw "anomalies missing." }

if (-not (Test-Path -LiteralPath $tmpState)) { throw "Expected state file write." }
if (-not (Test-Path -LiteralPath $tmpOutJson)) { throw "Expected json output write." }
if (-not (Test-Path -LiteralPath $tmpOutMd)) { throw "Expected markdown output write." }

Write-Host "PASS Test-QmTokenMonitor"

