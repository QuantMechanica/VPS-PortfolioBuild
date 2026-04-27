[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$GateDecisionJson = 'docs\ops\QUA-95_GATE_DECISION_2026-04-27.json',
    [string]$BlockerJson = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json',
    [string]$BlockedCommentPath = 'docs\ops\QUA-95_BLOCKED_COMMENT_2026-04-27.md',
    [string]$OutPath = 'docs\ops\QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gatePath = Join-Path $RepoRoot $GateDecisionJson
$blockerPath = Join-Path $RepoRoot $BlockerJson
$commentPath = Join-Path $RepoRoot $BlockedCommentPath
$outFull = Join-Path $RepoRoot $OutPath

foreach ($p in @($gatePath, $blockerPath, $commentPath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Required input missing: $p"
    }
}

$gate = Get-Content -Raw -LiteralPath $gatePath | ConvertFrom-Json
$blocker = Get-Content -Raw -LiteralPath $blockerPath | ConvertFrom-Json

$status = if ($gate.recommended_state -eq 'blocked') { 'blocked' } else { 'in_progress' }
$statusReason = if ($gate.recommended_state -eq 'blocked') { 'acceptance_not_met' } else { 'acceptance_met' }

$effectiveOwners = @($gate.unblock_owners)
if (@($effectiveOwners).Count -eq 0) {
    $effectiveOwners = @($blocker.unblock_owners)
}

$runtimeRecovered = $false
if ($null -ne $gate.runtime_visibility_recovered) {
    $runtimeRecovered = [bool]$gate.runtime_visibility_recovered
}

$blockedNextAction = if ($runtimeRecovered) {
    'Runtime visibility restored. Wait for verifier rerun proof (bars_got > 0 with aligned tail).'
} else {
    'Wait for runtime custom-symbol bars visibility recovery and verifier rerun proof (bars_got > 0 with aligned tail).'
}

$payload = [ordered]@{
    issue = $blocker.issue
    generated_at_local = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    source = [ordered]@{
        gate_decision_json = $GateDecisionJson
        blocker_status_json = $BlockerJson
        blocked_comment_md = $BlockedCommentPath
    }
    transition = [ordered]@{
        status = $status
        reason = $statusReason
        disposition = $gate.disposition
        acceptance_met = [bool]$blocker.acceptance.met
        bars_got = [int]$gate.bars_got
        tail_shortfall_seconds = [double]$gate.tail_shortfall_seconds
        last_checked_local = $gate.last_checked_local
    }
    unblock_owners = @($effectiveOwners)
    next_action = if ($status -eq 'blocked') {
        $blockedNextAction
    } else {
        'Proceed with normal completion/handoff path.'
    }
}

$dir = Split-Path -Parent $outFull
if (-not [string]::IsNullOrWhiteSpace($dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Output ("wrote=" + $outFull)
exit 0
