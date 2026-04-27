[CmdletBinding()]
param(
    [string]$TaskName = 'QM_QUA95_BlockerRefresh',
    [int]$MaxAgeMinutes = 125,
    [string]$TransitionPayloadCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95IssueTransitionPayload.ps1',
    [string]$UnblockReadinessCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95UnblockReadiness.ps1',
    [string]$AuditSignalCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95AuditSignal.ps1',
    [string]$UnblockOwnerConsistencyCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95UnblockOwnerConsistency.ps1',
    [string]$CanonicalSnapshotCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95CanonicalSnapshot.ps1',
    [string]$CustomVisibilityProofCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95CustomVisibilityProof.ps1',
    [string]$EvidenceCohesionCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95EvidenceCohesion.ps1',
    [string]$BlockerRefreshActionWiringCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95BlockerRefreshActionWiring.ps1',
    [string]$HeartbeatCustomVisibilityCheckScript = 'C:\QM\repo\infra\scripts\Test-QUA95HeartbeatCustomVisibility.ps1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop
} catch {
    Write-Host ("status=critical task={0} message=not_found" -f $TaskName)
    exit 2
}

$issues = @()
if ($task.State -eq 'Disabled') {
    $issues += 'disabled'
}
if ([int]$info.LastTaskResult -ne 0) {
    $issues += ("last_result={0}" -f [int]$info.LastTaskResult)
}

$ageMinutes = $null
if ($info.LastRunTime -and $info.LastRunTime.Year -gt 2000) {
    $ageMinutes = [math]::Round(((Get-Date) - $info.LastRunTime).TotalMinutes, 2)
    if ($ageMinutes -gt $MaxAgeMinutes) {
        $issues += ("stale_minutes={0}" -f $ageMinutes)
    }
} else {
    $issues += 'never_ran'
}

if ($issues.Count -gt 0) {
    Write-Host ("status=critical task={0} issues={1}" -f $TaskName, ($issues -join ','))
    exit 2
}

if (-not (Test-Path -LiteralPath $TransitionPayloadCheckScript)) {
    Write-Host ("status=critical task={0} issues=transition_check_missing path={1}" -f $TaskName, $TransitionPayloadCheckScript)
    exit 2
}

$transitionOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $TransitionPayloadCheckScript 2>&1
$transitionCode = $LASTEXITCODE
if ($transitionCode -ne 0) {
    $transitionText = ($transitionOut | ForEach-Object { $_.ToString() }) -join '; '
    Write-Host ("status=critical task={0} issues=transition_payload_check_failed exit_code={1} output={2}" -f $TaskName, $transitionCode, $transitionText)
    exit 2
}

if (-not (Test-Path -LiteralPath $UnblockReadinessCheckScript)) {
    Write-Host ("status=critical task={0} issues=unblock_readiness_check_missing path={1}" -f $TaskName, $UnblockReadinessCheckScript)
    exit 2
}

$readinessOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $UnblockReadinessCheckScript 2>&1
$readinessCode = $LASTEXITCODE
if ($readinessCode -ne 0) {
    $readinessText = ($readinessOut | ForEach-Object { $_.ToString() }) -join '; '
    Write-Host ("status=critical task={0} issues=unblock_readiness_check_failed exit_code={1} output={2}" -f $TaskName, $readinessCode, $readinessText)
    exit 2
}

if (-not (Test-Path -LiteralPath $AuditSignalCheckScript)) {
    Write-Host ("status=critical task={0} issues=audit_signal_check_missing path={1}" -f $TaskName, $AuditSignalCheckScript)
    exit 2
}

$auditSignalOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $AuditSignalCheckScript 2>&1
$auditSignalCode = $LASTEXITCODE
if ($auditSignalCode -ne 0) {
    $auditSignalText = ($auditSignalOut | ForEach-Object { $_.ToString() }) -join '; '
    Write-Host ("status=critical task={0} issues=audit_signal_check_failed exit_code={1} output={2}" -f $TaskName, $auditSignalCode, $auditSignalText)
    exit 2
}

if (-not (Test-Path -LiteralPath $UnblockOwnerConsistencyCheckScript)) {
    Write-Host ("status=critical task={0} issues=unblock_owner_consistency_check_missing path={1}" -f $TaskName, $UnblockOwnerConsistencyCheckScript)
    exit 2
}

$unblockOwnerConsistencyOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $UnblockOwnerConsistencyCheckScript 2>&1
$unblockOwnerConsistencyCode = $LASTEXITCODE
if ($unblockOwnerConsistencyCode -ne 0) {
    $unblockOwnerConsistencyText = ($unblockOwnerConsistencyOut | ForEach-Object { $_.ToString() }) -join '; '
    Write-Host ("status=critical task={0} issues=unblock_owner_consistency_check_failed exit_code={1} output={2}" -f $TaskName, $unblockOwnerConsistencyCode, $unblockOwnerConsistencyText)
    exit 2
}

if (-not (Test-Path -LiteralPath $CanonicalSnapshotCheckScript)) {
    Write-Host ("status=critical task={0} issues=canonical_snapshot_check_missing path={1}" -f $TaskName, $CanonicalSnapshotCheckScript)
    exit 2
}

$canonicalOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $CanonicalSnapshotCheckScript 2>&1
$canonicalCode = $LASTEXITCODE
if ($canonicalCode -ne 0) {
    $canonicalText = ($canonicalOut | ForEach-Object { $_.ToString() }) -join '; '
    Write-Host ("status=critical task={0} issues=canonical_snapshot_check_failed exit_code={1} output={2}" -f $TaskName, $canonicalCode, $canonicalText)
    exit 2
}

if (-not (Test-Path -LiteralPath $CustomVisibilityProofCheckScript)) {
    Write-Host ("status=critical task={0} issues=custom_visibility_proof_check_missing path={1}" -f $TaskName, $CustomVisibilityProofCheckScript)
    exit 2
}

$customVisibilityOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $CustomVisibilityProofCheckScript 2>&1
$customVisibilityCode = $LASTEXITCODE
if ($customVisibilityCode -ne 0) {
    $customVisibilityText = ($customVisibilityOut | ForEach-Object { $_.ToString() }) -join '; '
    Write-Host ("status=critical task={0} issues=custom_visibility_proof_check_failed exit_code={1} output={2}" -f $TaskName, $customVisibilityCode, $customVisibilityText)
    exit 2
}

if (-not (Test-Path -LiteralPath $EvidenceCohesionCheckScript)) {
    Write-Host ("status=critical task={0} issues=evidence_cohesion_check_missing path={1}" -f $TaskName, $EvidenceCohesionCheckScript)
    exit 2
}

$evidenceCohesionOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $EvidenceCohesionCheckScript 2>&1
$evidenceCohesionCode = $LASTEXITCODE
if ($evidenceCohesionCode -ne 0) {
    $evidenceCohesionText = ($evidenceCohesionOut | ForEach-Object { $_.ToString() }) -join '; '
    Write-Host ("status=critical task={0} issues=evidence_cohesion_check_failed exit_code={1} output={2}" -f $TaskName, $evidenceCohesionCode, $evidenceCohesionText)
    exit 2
}

if (-not (Test-Path -LiteralPath $BlockerRefreshActionWiringCheckScript)) {
    Write-Host ("status=critical task={0} issues=blocker_refresh_action_wiring_check_missing path={1}" -f $TaskName, $BlockerRefreshActionWiringCheckScript)
    exit 2
}

$blockerRefreshWiringOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $BlockerRefreshActionWiringCheckScript -TaskName $TaskName 2>&1
$blockerRefreshWiringCode = $LASTEXITCODE
if ($blockerRefreshWiringCode -ne 0) {
    $blockerRefreshWiringText = ($blockerRefreshWiringOut | ForEach-Object { $_.ToString() }) -join '; '
    Write-Host ("status=critical task={0} issues=blocker_refresh_action_wiring_check_failed exit_code={1} output={2}" -f $TaskName, $blockerRefreshWiringCode, $blockerRefreshWiringText)
    exit 2
}

if (-not (Test-Path -LiteralPath $HeartbeatCustomVisibilityCheckScript)) {
    Write-Host ("status=critical task={0} issues=heartbeat_custom_visibility_check_missing path={1}" -f $TaskName, $HeartbeatCustomVisibilityCheckScript)
    exit 2
}

$heartbeatCustomVisibilityOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $HeartbeatCustomVisibilityCheckScript 2>&1
$heartbeatCustomVisibilityCode = $LASTEXITCODE
if ($heartbeatCustomVisibilityCode -ne 0) {
    $heartbeatCustomVisibilityText = ($heartbeatCustomVisibilityOut | ForEach-Object { $_.ToString() }) -join '; '
    Write-Host ("status=critical task={0} issues=heartbeat_custom_visibility_check_failed exit_code={1} output={2}" -f $TaskName, $heartbeatCustomVisibilityCode, $heartbeatCustomVisibilityText)
    exit 2
}

Write-Host ("status=ok task={0} last_run={1:o} age_minutes={2}" -f $TaskName, $info.LastRunTime, $ageMinutes)
exit 0
