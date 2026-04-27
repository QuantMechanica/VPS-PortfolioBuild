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
$opsSuiteSnapshotScript = Join-Path $RepoRoot 'infra\scripts\Write-QUA95OpsSuiteSnapshot.ps1'
$opsBundleManifestScript = Join-Path $RepoRoot 'infra\scripts\Update-QUA95OpsBundleManifest.ps1'
$gateJson = Join-Path $RepoRoot 'docs\ops\QUA-95_GATE_DECISION_2026-04-27.json'
$auditJson = Join-Path $RepoRoot 'infra\reports\infra_audit_latest.json'
$outFull = Join-Path $RepoRoot $OutPath

foreach ($p in @($refreshScript, $auditScript, $gateScript, $assertionScript, $blockedInvariantScript, $unblockReadinessScript, $unblockReadinessSummaryScript, $automationHealthScript, $opsSuiteSnapshotScript, $opsBundleManifestScript)) {
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

$automationOut = & $automationHealthScript 2>&1
$automationCode = $LASTEXITCODE
if ($automationCode -ne 0) {
    $automationText = ($automationOut | ForEach-Object { $_.ToString() }) -join '; '
    throw ("Automation health snapshot failed: exit_code={0} output={1}" -f $automationCode, $automationText)
}

if (-not ($SkipRefresh.IsPresent -and $SkipAudit.IsPresent)) {
    $bundleOut = & $opsBundleManifestScript 2>&1
    $bundleCode = $LASTEXITCODE
    if ($bundleCode -ne 0) {
        $bundleText = ($bundleOut | ForEach-Object { $_.ToString() }) -join '; '
        throw ("Ops bundle manifest failed: exit_code={0} output={1}" -f $bundleCode, $bundleText)
    }

    $opsSuiteOut = & $opsSuiteSnapshotScript 2>&1
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
