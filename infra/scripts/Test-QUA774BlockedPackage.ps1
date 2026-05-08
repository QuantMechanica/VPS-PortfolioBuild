param(
    [string]$BlockerStatusPath = 'docs\ops\QUA-774_BLOCKER_STATUS_2026-05-08.json',
    [string]$TransitionPayloadPath = 'docs\ops\QUA-774_ISSUE_TRANSITION_PAYLOAD_2026-05-08.json',
    [string]$BlockedCommentPath = 'docs\ops\QUA-774_BLOCKED_COMMENT_2026-05-08.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Reason) {
    Write-Host ("status=critical reason={0}" -f $Reason)
    exit 2
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$statusFull = Join-Path $repoRoot $BlockerStatusPath
$payloadFull = Join-Path $repoRoot $TransitionPayloadPath
$commentFull = Join-Path $repoRoot $BlockedCommentPath

foreach ($p in @($statusFull, $payloadFull, $commentFull)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        Fail ("missing_file:{0}" -f $p)
    }
}

$status = Get-Content -LiteralPath $statusFull -Raw -Encoding UTF8 | ConvertFrom-Json
$payload = Get-Content -LiteralPath $payloadFull -Raw -Encoding UTF8 | ConvertFrom-Json
$comment = Get-Content -LiteralPath $commentFull -Raw -Encoding UTF8

if ([string]$status.issue_id -ne 'QUA-774') { Fail 'status_issue_id_mismatch' }
if ([string]$payload.issue_id -ne 'QUA-774') { Fail 'payload_issue_id_mismatch' }

$expectedState = if ([string]$status.gate.status -eq 'ready') { 'in_review' } else { 'blocked' }
if ([string]$payload.transition.state -ne $expectedState) {
    Fail ('transition_state_mismatch expected={0} got={1}' -f $expectedState, [string]$payload.transition.state)
}

$expectedEvidence = [string]$status.source_evidence.file_name
if ([string]$payload.source.evidence_file_name -ne $expectedEvidence) {
    Fail ('evidence_file_mismatch expected={0} got={1}' -f $expectedEvidence, [string]$payload.source.evidence_file_name)
}

if ($comment -notmatch 'QUA-774 blocker refresh') { Fail 'comment_heading_missing' }
if ($comment -notmatch [regex]::Escape($expectedEvidence)) { Fail 'comment_evidence_ref_missing' }

Write-Host ("status=ok issue=QUA-774 gate={0} transition={1} evidence={2}" -f [string]$status.gate.status, [string]$payload.transition.state, $expectedEvidence)
exit 0
