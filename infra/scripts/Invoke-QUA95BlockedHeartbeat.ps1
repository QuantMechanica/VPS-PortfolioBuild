[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [switch]$SkipRefresh,
    [switch]$SkipAudit,
    [string]$OutPath = 'docs\ops\QUA-95_BLOCKED_HEARTBEAT_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$refreshScript = Join-Path $RepoRoot 'infra\scripts\Run-QUA95BlockerRefresh.ps1'
$auditScript = Join-Path $RepoRoot 'infra\scripts\Invoke-InfraAudit.ps1'
$gateScript = Join-Path $RepoRoot 'infra\scripts\Get-QUA95GateDecision.ps1'
$assertionScript = Join-Path $RepoRoot 'infra\scripts\Update-QUA95BlockedAssertion.ps1'
$blockedInvariantScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95BlockedInvariant.ps1'
$unblockReadinessScript = Join-Path $RepoRoot 'infra\scripts\Update-QUA95UnblockReadiness.ps1'
$unblockReadinessSummaryScript = Join-Path $RepoRoot 'infra\scripts\Write-QUA95UnblockReadinessSummary.ps1'
$automationHealthScript = Join-Path $RepoRoot 'infra\monitoring\Test-QUA95AutomationHealth.ps1'
$auditSignalScript = Join-Path $RepoRoot 'infra\scripts\Update-QUA95AuditSignal.ps1'
$auditSignalCheckScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95AuditSignal.ps1'
$opsSuiteSnapshotScript = Join-Path $RepoRoot 'infra\scripts\Write-QUA95OpsSuiteSnapshot.ps1'
$opsBundleManifestScript = Join-Path $RepoRoot 'infra\scripts\Update-QUA95OpsBundleManifest.ps1'
$gateJson = Join-Path $RepoRoot 'docs\ops\QUA-95_GATE_DECISION_2026-04-27.json'
$auditSignalJson = Join-Path $RepoRoot 'docs\ops\QUA-95_AUDIT_SIGNAL_2026-04-27.json'
$customVisibilityEvidenceJson = Join-Path $RepoRoot 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json'
$auditJson = Join-Path $RepoRoot 'infra\reports\infra_audit_latest.json'
$outFull = Join-Path $RepoRoot $OutPath

foreach ($p in @($refreshScript, $auditScript, $gateScript, $assertionScript, $blockedInvariantScript, $unblockReadinessScript, $unblockReadinessSummaryScript, $automationHealthScript, $auditSignalScript, $auditSignalCheckScript, $opsSuiteSnapshotScript, $opsBundleManifestScript)) {
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Required script missing: $p"
    }
}

$refreshExit = $null
$auditExit = $null

if (-not $SkipRefresh.IsPresent) {
    & $refreshScript
    $refreshExit = $LASTEXITCODE
}

if (-not $SkipAudit.IsPresent) {
    & $auditScript
    $auditExit = $LASTEXITCODE
}

if (-not (Test-Path -LiteralPath $gateJson)) {
    throw "Gate snapshot missing: $gateJson"
}
if (-not (Test-Path -LiteralPath $auditJson)) {
    throw "Infra audit report missing: $auditJson"
}
if (-not (Test-Path -LiteralPath $auditSignalJson)) {
    throw "Audit signal snapshot missing: $auditSignalJson"
}
if (-not (Test-Path -LiteralPath $customVisibilityEvidenceJson)) {
    throw "Custom visibility evidence missing: $customVisibilityEvidenceJson"
}

$assertOut = & $assertionScript 2>&1
$assertCode = $LASTEXITCODE
if ($assertCode -ne 0) {
    $assertText = ($assertOut | ForEach-Object { $_.ToString() }) -join '; '
    throw ("Blocked assertion sync failed: exit_code={0} output={1}" -f $assertCode, $assertText)
}

$invariantOut = & $blockedInvariantScript 2>&1
$invariantCode = $LASTEXITCODE
if ($invariantCode -ne 0) {
    $invariantText = ($invariantOut | ForEach-Object { $_.ToString() }) -join '; '
    throw ("Blocked invariant check failed: exit_code={0} output={1}" -f $invariantCode, $invariantText)
}

$readinessOut = & $unblockReadinessScript 2>&1
$readinessCode = $LASTEXITCODE
if ($readinessCode -ne 0) {
    $readinessText = ($readinessOut | ForEach-Object { $_.ToString() }) -join '; '
    throw ("Unblock readiness update failed: exit_code={0} output={1}" -f $readinessCode, $readinessText)
}

$readinessSummaryOut = & $unblockReadinessSummaryScript 2>&1
$readinessSummaryCode = $LASTEXITCODE
if ($readinessSummaryCode -ne 0) {
    $readinessSummaryText = ($readinessSummaryOut | ForEach-Object { $_.ToString() }) -join '; '
    throw ("Unblock readiness summary update failed: exit_code={0} output={1}" -f $readinessSummaryCode, $readinessSummaryText)
}

$automationParams = @{}
if ($SkipRefresh.IsPresent -and $SkipAudit.IsPresent) {
    $automationParams.SkipRefreshLastResultCheck = $true
    $automationParams.SkipTaskHealthCheck = $true
}
$automationOut = & $automationHealthScript @automationParams 2>&1
$automationCode = $LASTEXITCODE
if ($automationCode -ne 0) {
    $automationText = ($automationOut | ForEach-Object { $_.ToString() }) -join '; '
    throw ("Automation health snapshot failed: exit_code={0} output={1}" -f $automationCode, $automationText)
}

$auditSignalOut = & $auditSignalScript 2>&1
$auditSignalCode = $LASTEXITCODE
if ($auditSignalCode -ne 0) {
    $auditSignalText = ($auditSignalOut | ForEach-Object { $_.ToString() }) -join '; '
    throw ("Audit signal snapshot failed: exit_code={0} output={1}" -f $auditSignalCode, $auditSignalText)
}

$auditSignalCheckOut = & $auditSignalCheckScript 2>&1
$auditSignalCheckCode = $LASTEXITCODE
if ($auditSignalCheckCode -ne 0) {
    $auditSignalCheckText = ($auditSignalCheckOut | ForEach-Object { $_.ToString() }) -join '; '
    throw ("Audit signal validation failed: exit_code={0} output={1}" -f $auditSignalCheckCode, $auditSignalCheckText)
}

if (-not ($SkipRefresh.IsPresent -and $SkipAudit.IsPresent)) {
    $bundleOut = & $opsBundleManifestScript 2>&1
    $bundleCode = $LASTEXITCODE
    if ($bundleCode -ne 0) {
        $bundleText = ($bundleOut | ForEach-Object { $_.ToString() }) -join '; '
        throw ("Ops bundle manifest failed: exit_code={0} output={1}" -f $bundleCode, $bundleText)
    }

    $opsSuiteOut = & $opsSuiteSnapshotScript -SkipBlockerTaskHealthCheck 2>&1
    $opsSuiteCode = $LASTEXITCODE
    if ($opsSuiteCode -ne 0) {
        $opsSuiteText = ($opsSuiteOut | ForEach-Object { $_.ToString() }) -join '; '
        throw ("Ops suite snapshot failed: exit_code={0} output={1}" -f $opsSuiteCode, $opsSuiteText)
    }

    $bundleOut = & $opsBundleManifestScript 2>&1
    $bundleCode = $LASTEXITCODE
    if ($bundleCode -ne 0) {
        $bundleText = ($bundleOut | ForEach-Object { $_.ToString() }) -join '; '
        throw ("Ops bundle manifest failed: exit_code={0} output={1}" -f $bundleCode, $bundleText)
    }
}

$gate = Get-Content -Raw -LiteralPath $gateJson | ConvertFrom-Json
$audit = Get-Content -Raw -LiteralPath $auditJson | ConvertFrom-Json
$auditSignal = Get-Content -Raw -LiteralPath $auditSignalJson | ConvertFrom-Json
$customVisibility = Get-Content -Raw -LiteralPath $customVisibilityEvidenceJson | ConvertFrom-Json

$summary = [ordered]@{
    issue = 'QUA-95'
    generated_at_local = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    refresh_executed = (-not $SkipRefresh.IsPresent)
    refresh_exit_code = $refreshExit
    audit_executed = (-not $SkipAudit.IsPresent)
    audit_exit_code = $auditExit
    gate = [ordered]@{
        recommended_state = $gate.recommended_state
        reason = $gate.reason
        disposition = $gate.disposition
        bars_got = $gate.bars_got
        tail_shortfall_seconds = $gate.tail_shortfall_seconds
        last_checked_local = $gate.last_checked_local
    }
    infra_audit = [ordered]@{
        overall_status = $audit.overall_status
        checks_count = @($audit.checks).Count
        issues_count = @($audit.issues).Count
    }
    audit_signal = [ordered]@{
        qua95_issues_count = $auditSignal.qua95_issues_count
        non_qua95_issues_count = $auditSignal.non_qua95_issues_count
        qua95_issue_names = @($auditSignal.qua95_issue_names)
        non_qua95_issue_names = @($auditSignal.non_qua95_issue_names)
    }
    custom_visibility = [ordered]@{
        isolated_custom_bars_visibility_failure = [bool]$customVisibility.isolated_custom_bars_visibility_failure
        target = [string]$customVisibility.target
        source = [string]$customVisibility.source
        target_bars_range_m1 = [int]$customVisibility.target_probe.rates_range_m1_count
        target_bars_from_pos_m1 = [int]$customVisibility.target_probe.rates_from_pos_m1_count
        source_bars_range_m1 = [int]$customVisibility.source_probe.rates_range_m1_count
        source_bars_from_pos_m1 = [int]$customVisibility.source_probe.rates_from_pos_m1_count
    }
}

$dir = Split-Path -Parent $outFull
if (-not [string]::IsNullOrWhiteSpace($dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Output ("wrote=" + $outFull)
Write-Output ("gate_state=" + $summary.gate.recommended_state)
Write-Output ("audit_overall_status=" + $summary.infra_audit.overall_status)
exit 0
