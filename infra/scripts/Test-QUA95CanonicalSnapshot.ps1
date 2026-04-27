[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$SnapshotPath = 'docs\ops\QUA-95_CANONICAL_SNAPSHOT_2026-04-27.json',
    [string]$BlockerPath = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json',
    [string]$AuditSignalPath = 'docs\ops\QUA-95_AUDIT_SIGNAL_2026-04-27.json',
    [string]$CustomVisibilityEvidencePath = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json',
    [string]$CustomVisibilityProofPath = 'docs\ops\QUA-95_CUSTOM_VISIBILITY_RERUN_2026-04-27.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host $Message
    exit 1
}

$snapshotFull = Join-Path $RepoRoot $SnapshotPath
$blockerFull = Join-Path $RepoRoot $BlockerPath
$auditSignalFull = Join-Path $RepoRoot $AuditSignalPath
$customVisibilityEvidenceFull = Join-Path $RepoRoot $CustomVisibilityEvidencePath
$customVisibilityProofFull = Join-Path $RepoRoot $CustomVisibilityProofPath

foreach ($path in @($snapshotFull, $blockerFull, $auditSignalFull, $customVisibilityEvidenceFull, $customVisibilityProofFull)) {
    if (-not (Test-Path -LiteralPath $path)) {
        Fail ("missing_file=" + $path)
    }
}

$snapshot = Get-Content -LiteralPath $snapshotFull -Raw | ConvertFrom-Json
$blocker = Get-Content -LiteralPath $blockerFull -Raw | ConvertFrom-Json
$auditSignal = Get-Content -LiteralPath $auditSignalFull -Raw | ConvertFrom-Json

if ([string]$snapshot.issue -ne 'QUA-95') { Fail "snapshot_issue_mismatch" }
if ([string]$snapshot.flow -ne 'qua95_canonical_snapshot') { Fail "snapshot_flow_mismatch" }
if ([int]$snapshot.command_exit_code -ne 0) { Fail "snapshot_command_exit_nonzero" }
if ([int]$snapshot.steps.blocked_heartbeat_exit_code -ne 0) { Fail "snapshot_heartbeat_exit_nonzero" }
if ([int]$snapshot.steps.custom_visibility_proof_exit_code -ne 0) { Fail "snapshot_custom_visibility_proof_exit_nonzero" }
if ([int]$snapshot.steps.ops_bundle_update_exit_code -ne 0) { Fail "snapshot_bundle_update_exit_nonzero" }
if ([int]$snapshot.steps.ops_bundle_test_exit_code -ne 0) { Fail "snapshot_bundle_test_exit_nonzero" }

$customVisibilityEvidence = Get-Content -LiteralPath $customVisibilityEvidenceFull -Raw | ConvertFrom-Json
if ([string]$customVisibilityEvidence.target -ne 'XTIUSD.DWX') { Fail "custom_visibility_target_mismatch" }

if ([string]$snapshot.blocker.recommended_state -ne [string]$blocker.recommended_state) {
    Fail "snapshot_blocker_state_mismatch"
}
if ([string]$snapshot.blocker.disposition -ne [string]$blocker.current_observed.disposition) {
    Fail "snapshot_disposition_mismatch"
}
if ([int]$snapshot.blocker.bars_got -ne [int]$blocker.current_observed.bars_got) {
    Fail "snapshot_bars_mismatch"
}

$qua95Issues = [int]$snapshot.audit_signal.qua95_issues_count
$nonQua95Issues = [int]$snapshot.audit_signal.non_qua95_issues_count
if ($qua95Issues -lt 0) { Fail "snapshot_qua95_issue_count_invalid" }
if ($nonQua95Issues -lt 0) { Fail "snapshot_non_qua95_issue_count_invalid" }

$snapshotAuditStatus = [string]$snapshot.audit_signal.infra_audit_overall_status
if ($snapshotAuditStatus -notin @('ok','warn','critical')) {
    Fail "snapshot_audit_status_invalid"
}

if ([string]$auditSignal.issue -ne 'QUA-95') {
    Fail "audit_signal_issue_mismatch"
}

$barsGot = [int]$snapshot.blocker.bars_got
if ($barsGot -le 0 -and [string]$snapshot.blocker.recommended_state -ne 'blocked') {
    Fail "snapshot_blocked_invariant_violation"
}

Write-Host ("status=ok bars_got={0} disposition={1} qua95_issues={2} non_qua95_issues={3}" -f `
    $snapshot.blocker.bars_got, `
    $snapshot.blocker.disposition, `
    $snapshot.audit_signal.qua95_issues_count, `
    $snapshot.audit_signal.non_qua95_issues_count)
exit 0
