[CmdletBinding()]
param(
    [string]$TaskName = 'QM_QUA95_TaskHealth_15min',
    [string]$RepoRoot = 'C:\QM\repo',
    [int]$EveryMinutes = 15,
    [int]$MaxAgeMinutes = 125,
    [string]$TransitionPayloadCheckScript = '',
    [string]$UnblockReadinessCheckScript = '',
    [string]$AuditSignalCheckScript = '',
    [string]$UnblockOwnerConsistencyCheckScript = '',
    [string]$CanonicalSnapshotCheckScript = '',
    [string]$DirectVerifierProofCheckScript = '',
    [string]$CustomVisibilityProofCheckScript = '',
    [string]$EvidenceCohesionCheckScript = '',
    [string]$FailureSignatureCheckScript = '',
    [string]$BlockerRefreshActionWiringCheckScript = '',
    [string]$HeartbeatCustomVisibilityCheckScript = '',
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($EveryMinutes -lt 5) {
    throw "EveryMinutes must be >= 5."
}

$checkScript = Join-Path $RepoRoot 'infra\monitoring\Test-QUA95BlockerTaskHealth.ps1'
if (-not (Test-Path -LiteralPath $checkScript)) {
    throw "Health check script missing: $checkScript"
}

if ([string]::IsNullOrWhiteSpace($TransitionPayloadCheckScript)) {
    $TransitionPayloadCheckScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95IssueTransitionPayload.ps1'
}
if (-not (Test-Path -LiteralPath $TransitionPayloadCheckScript)) {
    throw "Transition payload check script missing: $TransitionPayloadCheckScript"
}

if ([string]::IsNullOrWhiteSpace($UnblockReadinessCheckScript)) {
    $UnblockReadinessCheckScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95UnblockReadiness.ps1'
}
if (-not (Test-Path -LiteralPath $UnblockReadinessCheckScript)) {
    throw "Unblock readiness check script missing: $UnblockReadinessCheckScript"
}

if ([string]::IsNullOrWhiteSpace($AuditSignalCheckScript)) {
    $AuditSignalCheckScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95AuditSignal.ps1'
}
if (-not (Test-Path -LiteralPath $AuditSignalCheckScript)) {
    throw "Audit signal check script missing: $AuditSignalCheckScript"
}

if ([string]::IsNullOrWhiteSpace($UnblockOwnerConsistencyCheckScript)) {
    $UnblockOwnerConsistencyCheckScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95UnblockOwnerConsistency.ps1'
}
if (-not (Test-Path -LiteralPath $UnblockOwnerConsistencyCheckScript)) {
    throw "Unblock owner consistency check script missing: $UnblockOwnerConsistencyCheckScript"
}

if ([string]::IsNullOrWhiteSpace($CanonicalSnapshotCheckScript)) {
    $CanonicalSnapshotCheckScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95CanonicalSnapshot.ps1'
}
if (-not (Test-Path -LiteralPath $CanonicalSnapshotCheckScript)) {
    throw "Canonical snapshot check script missing: $CanonicalSnapshotCheckScript"
}

if ([string]::IsNullOrWhiteSpace($DirectVerifierProofCheckScript)) {
    $DirectVerifierProofCheckScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95DirectVerifierProof.ps1'
}
if (-not (Test-Path -LiteralPath $DirectVerifierProofCheckScript)) {
    throw "Direct verifier proof check script missing: $DirectVerifierProofCheckScript"
}

if ([string]::IsNullOrWhiteSpace($CustomVisibilityProofCheckScript)) {
    $CustomVisibilityProofCheckScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95CustomVisibilityProof.ps1'
}
if (-not (Test-Path -LiteralPath $CustomVisibilityProofCheckScript)) {
    throw "Custom visibility proof check script missing: $CustomVisibilityProofCheckScript"
}

if ([string]::IsNullOrWhiteSpace($EvidenceCohesionCheckScript)) {
    $EvidenceCohesionCheckScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95EvidenceCohesion.ps1'
}
if (-not (Test-Path -LiteralPath $EvidenceCohesionCheckScript)) {
    throw "Evidence cohesion check script missing: $EvidenceCohesionCheckScript"
}

if ([string]::IsNullOrWhiteSpace($FailureSignatureCheckScript)) {
    $FailureSignatureCheckScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95FailureSignature.ps1'
}
if (-not (Test-Path -LiteralPath $FailureSignatureCheckScript)) {
    throw "Failure signature check script missing: $FailureSignatureCheckScript"
}

if ([string]::IsNullOrWhiteSpace($BlockerRefreshActionWiringCheckScript)) {
    $BlockerRefreshActionWiringCheckScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95BlockerRefreshActionWiring.ps1'
}
if (-not (Test-Path -LiteralPath $BlockerRefreshActionWiringCheckScript)) {
    throw "Blocker refresh action wiring check script missing: $BlockerRefreshActionWiringCheckScript"
}

if ([string]::IsNullOrWhiteSpace($HeartbeatCustomVisibilityCheckScript)) {
    $HeartbeatCustomVisibilityCheckScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95HeartbeatCustomVisibility.ps1'
}
if (-not (Test-Path -LiteralPath $HeartbeatCustomVisibilityCheckScript)) {
    throw "Heartbeat custom visibility check script missing: $HeartbeatCustomVisibilityCheckScript"
}

$args = "-NoProfile -ExecutionPolicy Bypass -File `"$checkScript`" -MaxAgeMinutes $MaxAgeMinutes -TransitionPayloadCheckScript `"$TransitionPayloadCheckScript`" -UnblockReadinessCheckScript `"$UnblockReadinessCheckScript`" -AuditSignalCheckScript `"$AuditSignalCheckScript`" -UnblockOwnerConsistencyCheckScript `"$UnblockOwnerConsistencyCheckScript`" -CanonicalSnapshotCheckScript `"$CanonicalSnapshotCheckScript`" -DirectVerifierProofCheckScript `"$DirectVerifierProofCheckScript`" -CustomVisibilityProofCheckScript `"$CustomVisibilityProofCheckScript`" -EvidenceCohesionCheckScript `"$EvidenceCohesionCheckScript`" -FailureSignatureCheckScript `"$FailureSignatureCheckScript`" -BlockerRefreshActionWiringCheckScript `"$BlockerRefreshActionWiringCheckScript`" -HeartbeatCustomVisibilityCheckScript `"$HeartbeatCustomVisibilityCheckScript`""
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $args
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(2) `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

if ($PreviewOnly) {
    Write-Host ("preview_task_name={0}" -f $TaskName)
    Write-Host ("preview_interval_minutes={0}" -f $EveryMinutes)
    Write-Host ("preview_max_age_minutes={0}" -f $MaxAgeMinutes)
    Write-Host ("preview_transition_payload_check_script={0}" -f $TransitionPayloadCheckScript)
    Write-Host ("preview_unblock_readiness_check_script={0}" -f $UnblockReadinessCheckScript)
    Write-Host ("preview_audit_signal_check_script={0}" -f $AuditSignalCheckScript)
    Write-Host ("preview_unblock_owner_consistency_check_script={0}" -f $UnblockOwnerConsistencyCheckScript)
    Write-Host ("preview_canonical_snapshot_check_script={0}" -f $CanonicalSnapshotCheckScript)
    Write-Host ("preview_direct_verifier_proof_check_script={0}" -f $DirectVerifierProofCheckScript)
    Write-Host ("preview_custom_visibility_proof_check_script={0}" -f $CustomVisibilityProofCheckScript)
    Write-Host ("preview_evidence_cohesion_check_script={0}" -f $EvidenceCohesionCheckScript)
    Write-Host ("preview_failure_signature_check_script={0}" -f $FailureSignatureCheckScript)
    Write-Host ("preview_blocker_refresh_action_wiring_check_script={0}" -f $BlockerRefreshActionWiringCheckScript)
    Write-Host ("preview_heartbeat_custom_visibility_check_script={0}" -f $HeartbeatCustomVisibilityCheckScript)
    Write-Host ("preview_action=PowerShell {0}" -f $args)
    exit 0
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Host ("installed_task={0}" -f $TaskName)
