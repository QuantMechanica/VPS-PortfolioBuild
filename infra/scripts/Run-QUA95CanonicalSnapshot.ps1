[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$SummaryOutPath = 'docs/ops/QUA-95_CANONICAL_SNAPSHOT_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$heartbeatScript = Join-Path $RepoRoot 'infra\scripts\Invoke-QUA95BlockedHeartbeat.ps1'
$bundleUpdateScript = Join-Path $RepoRoot 'infra\scripts\Update-QUA95OpsBundleManifest.ps1'
$bundleTestScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95OpsBundleManifest.ps1'

foreach ($path in @($heartbeatScript, $bundleUpdateScript, $bundleTestScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required script missing: $path"
    }
}

$heartbeatOut = & $heartbeatScript 2>&1
$heartbeatCode = $LASTEXITCODE
($heartbeatOut | ForEach-Object { $_.ToString() }) | Write-Output
if ($heartbeatCode -ne 0) {
    throw ("Heartbeat failed: exit_code={0}" -f $heartbeatCode)
}

$bundleUpdateCode = -1
$bundleTestCode = -1

$blockerPath = Join-Path $RepoRoot 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json'
$auditSignalPath = Join-Path $RepoRoot 'docs\ops\QUA-95_AUDIT_SIGNAL_2026-04-27.json'
$opsSuitePath = Join-Path $RepoRoot 'docs\ops\QUA-95_OPS_SUITE_2026-04-27.json'

foreach ($path in @($blockerPath, $auditSignalPath, $opsSuitePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required artifact missing after canonical snapshot: $path"
    }
}

$blocker = Get-Content -LiteralPath $blockerPath -Raw | ConvertFrom-Json
$auditSignal = Get-Content -LiteralPath $auditSignalPath -Raw | ConvertFrom-Json
$opsSuite = Get-Content -LiteralPath $opsSuitePath -Raw | ConvertFrom-Json

$summary = [ordered]@{
    issue = 'QUA-95'
    generated_at_local = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    flow = 'qua95_canonical_snapshot'
    command = 'Run-QUA95CanonicalSnapshot.ps1'
    command_exit_code = 0
    steps = [ordered]@{
        blocked_heartbeat_exit_code = $heartbeatCode
        ops_bundle_update_exit_code = $bundleUpdateCode
        ops_bundle_test_exit_code = $bundleTestCode
    }
    blocker = [ordered]@{
        recommended_state = [string]$blocker.recommended_state
        disposition = [string]$blocker.current_observed.disposition
        verdict = [string]$blocker.current_observed.verdict
        bars_got = [int]$blocker.current_observed.bars_got
        tail_shortfall_seconds = [double]$blocker.current_observed.tail_shortfall_seconds
        acceptance_met = [bool]$blocker.acceptance.met
    }
    audit_signal = [ordered]@{
        infra_audit_overall_status = [string]$auditSignal.infra_audit_overall_status
        infra_audit_checks_count = [int]$auditSignal.infra_audit_checks_count
        infra_audit_issues_count = [int]$auditSignal.infra_audit_issues_count
        qua95_issues_count = [int]$auditSignal.qua95_issues_count
        non_qua95_issues_count = [int]$auditSignal.non_qua95_issues_count
    }
    ops_suite = [ordered]@{
        overall_status = [string]$opsSuite.overall_status
        checks_count = @($opsSuite.checks).Count
    }
}

$summaryFullPath = Join-Path $RepoRoot $SummaryOutPath
$summaryDir = Split-Path -Parent $summaryFullPath
if ($summaryDir) {
    New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null
}

$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryFullPath -Encoding UTF8
Write-Output ("wrote=" + $summaryFullPath)

$bundleUpdateOut = & $bundleUpdateScript 2>&1
$bundleUpdateCode = $LASTEXITCODE
($bundleUpdateOut | ForEach-Object { $_.ToString() }) | Write-Output
if ($bundleUpdateCode -ne 0) {
    throw ("Ops bundle update failed: exit_code={0}" -f $bundleUpdateCode)
}

$bundleTestOut = & $bundleTestScript 2>&1
$bundleTestCode = $LASTEXITCODE
($bundleTestOut | ForEach-Object { $_.ToString() }) | Write-Output
if ($bundleTestCode -ne 0) {
    throw ("Ops bundle verification failed: exit_code={0}" -f $bundleTestCode)
}

$summary.steps.ops_bundle_update_exit_code = $bundleUpdateCode
$summary.steps.ops_bundle_test_exit_code = $bundleTestCode
$summary.generated_at_local = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryFullPath -Encoding UTF8

Write-Output "status=ok flow=qua95_canonical_snapshot"
exit 0
