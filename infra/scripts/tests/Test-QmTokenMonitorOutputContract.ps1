[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$scriptPath = Join-Path $repoRoot "infra\monitoring\Invoke-QmTokenMonitor.ps1"
$agentsFixture = Join-Path $repoRoot "infra\scripts\tests\fixtures\qm_token_monitor_agents_fixture.json"
$prevStateFixture = Join-Path $repoRoot "infra\scripts\tests\fixtures\qm_token_monitor_previous_state_fixture.json"
$tmpState = Join-Path $env:TEMP "qm_token_monitor_contract_state.json"
$tmpOutJson = Join-Path $env:TEMP "qm_token_monitor_contract_output.json"
$tmpOutMd = Join-Path $env:TEMP "qm_token_monitor_contract_output.md"

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

$obj = (($raw | Out-String) | ConvertFrom-Json -ErrorAction Stop)

$requiredTopLevel = @(
    "check",
    "status",
    "spent_cents",
    "daily_delta",
    "org_cap_pct_used",
    "top3_agents",
    "anomalies"
)

foreach ($field in $requiredTopLevel) {
    if (-not $obj.PSObject.Properties[$field]) {
        throw "Missing required top-level field: $field"
    }
}

if ($obj.check -ne "qm_token_monitor") { throw "Unexpected check: $($obj.check)" }
if ($obj.status -notin @("ok", "warn", "critical")) { throw "Unexpected status: $($obj.status)" }
if (@($obj.top3_agents).Count -gt 3) { throw "top3_agents must have at most 3 entries." }

foreach ($agent in @($obj.top3_agents)) {
    foreach ($field in @("agent_id", "agent_name", "spent_cents", "daily_delta_cents")) {
        if (-not $agent.PSObject.Properties[$field]) {
            throw "top3_agents entry missing field: $field"
        }
    }
}

foreach ($anomaly in @($obj.anomalies)) {
    foreach ($field in @("code", "severity")) {
        if (-not $anomaly.PSObject.Properties[$field]) {
            throw "anomaly entry missing field: $field"
        }
    }
}

if (-not (Test-Path -LiteralPath $tmpOutJson)) { throw "Expected output JSON file missing." }
if (-not (Test-Path -LiteralPath $tmpOutMd)) { throw "Expected output markdown file missing." }

$mdText = Get-Content -Raw -LiteralPath $tmpOutMd
if ($mdText -match '\$\(@\{') {
    throw "Markdown top3 agent rendering leaked object interpolation syntax."
}
if ($mdText -notmatch '\| CEO \(`a1`\) \|') {
    throw "Markdown top3 row format mismatch; expected literal agent id marker."
}

Write-Host "PASS Test-QmTokenMonitorOutputContract"
