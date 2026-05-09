param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$IssueId = $(if ($env:PAPERCLIP_TASK_ID) { $env:PAPERCLIP_TASK_ID } else { '' }),
    [int]$QuietHours = 24,
    [switch]$EnableWritesAfterOwnerSignoff
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($IssueId)) { throw 'IssueId is required.' }

$handoffPath = Join-Path $RepoRoot 'framework\deploy\manifests\QUA-671_OWNER_HANDOFF_2026-05-01.json'
$noPollingSignalPath = Join-Path $RepoRoot 'framework\deploy\manifests\QUA-671_NO_POLLING_UNTIL_OWNER_UNBLOCK.signal'
$ownerRequiredSignalPath = Join-Path $RepoRoot 'framework\deploy\manifests\QUA-671_OWNER_APPROVAL_REQUIRED.signal'
$ownerUnblockSignalPath = Join-Path $RepoRoot 'framework\deploy\manifests\QUA-671_OWNER_UNBLOCK_APPROVED.signal'
$handoff = Get-Content -Raw -Path $handoffPath | ConvertFrom-Json
$lastHeartbeatUtc = [datetime]::Parse($handoff.last_heartbeat_utc).ToUniversalTime()
$nowUtc = (Get-Date).ToUniversalTime()
$hoursSince = ($nowUtc - $lastHeartbeatUtc).TotalHours

$ownerUnblocked = Test-Path -LiteralPath $ownerUnblockSignalPath -PathType Leaf
$noPollingSignalPresent = Test-Path -LiteralPath $noPollingSignalPath -PathType Leaf
$ownerApprovalRequiredSignalPresent = Test-Path -LiteralPath $ownerRequiredSignalPath -PathType Leaf
$writesFrozen = -not ($ownerUnblocked -and $EnableWritesAfterOwnerSignoff.IsPresent)
$decision = if ($ownerUnblocked) { 'OWNER_UNBLOCK_APPROVED' } else { 'DEFER_NO_POLLING' }

if (-not $ownerUnblocked) {
    Write-Output 'wait_guard=DEFER_NO_POLLING_BLOCKED_OWNER_SIGNOFF_REQUIRED'
    exit 0
}

$stamp = $nowUtc.ToString('yyyy-MM-ddTHHmmssZ')
$outPath = Join-Path $RepoRoot ("docs\\ops\\QUA-671_WAIT_GUARD_{0}.json" -f $stamp)
$out = [ordered]@{
    captured_utc = $nowUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    issue_id = $IssueId
    issue_status = 'blocked_pending_owner_approval'
    pending_comments = 0
    latest_comment_id = ''
    hours_since_last_heartbeat = [math]::Round($hoursSince, 3)
    quiet_hours_threshold = $QuietHours
    unblock_owner = 'OWNER'
    unblock_action = 'Approve P0-13 T6 manifest dry-run evidence and authorize transition to done.'
    decision = $decision
    connectivity_error = $null
    polling_disabled = $true
    writes_frozen = $writesFrozen
    owner_unblock_signal_path = $ownerUnblockSignalPath
    owner_unblock_signal_present = $ownerUnblocked
    no_polling_signal_path = $noPollingSignalPath
    no_polling_signal_present = $noPollingSignalPresent
    owner_approval_required_signal_path = $ownerRequiredSignalPath
    owner_approval_required_signal_present = $ownerApprovalRequiredSignalPresent
}

if (-not $writesFrozen) {
    ($out | ConvertTo-Json -Depth 6) + "`n" | Set-Content -Encoding utf8 $outPath
}

Write-Output ("decision={0}" -f $decision)
if ($writesFrozen) {
    Write-Output 'snapshot=SKIPPED_WRITES_FROZEN_UNTIL_OWNER_SIGNOFF'
} else {
    Write-Output ("snapshot={0}" -f $outPath)
}
