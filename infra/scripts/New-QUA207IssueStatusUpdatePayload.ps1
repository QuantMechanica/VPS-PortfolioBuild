[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$TransitionPayloadPath = 'docs\ops\QUA-207_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json',
    [string]$BlockedSnapshotPath = 'docs\ops\QUA-207_BLOCKED_ON_VERIFIER_2026-04-27.json',
    [string]$OutPath = 'docs\ops\QUA-207_ISSUE_STATUS_UPDATE_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$transitionFull = Join-Path $RepoRoot $TransitionPayloadPath
$blockedFull = Join-Path $RepoRoot $BlockedSnapshotPath
$outFull = Join-Path $RepoRoot $OutPath

foreach ($p in @($transitionFull, $blockedFull)) {
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Required input missing: $p"
    }
}

$transition = Get-Content -LiteralPath $transitionFull -Raw | ConvertFrom-Json
$blocked = Get-Content -LiteralPath $blockedFull -Raw | ConvertFrom-Json

$blockedReason = [string]$blocked.reason
$runtimeOwnerState = [string]$blocked.runtime_owner_scope.state
$unblockOwner = [string]$blocked.unblock_owner.owner
$transitionStatus = [string]$transition.recommended_transition.status
$transitionReason = [string]$transition.recommended_transition.reason

$effectiveStatus = $transitionStatus
$effectiveReason = $transitionReason

# Runtime owner scope is complete, but verifier work is still pending: keep issue explicitly blocked.
if ($runtimeOwnerState -eq 'completed' -and $unblockOwner -eq 'verifier_implementation_owner') {
    $effectiveStatus = 'blocked'
    $effectiveReason = if ([string]::IsNullOrWhiteSpace($blockedReason)) {
        'runtime_scope_completed_waiting_on_verifier_owner'
    } else {
        $blockedReason
    }
}

$payload = [ordered]@{
    issue = 'QUA-207'
    generated_at_local = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    source = [ordered]@{
        transition_payload_json = $TransitionPayloadPath
        blocked_snapshot_json = $BlockedSnapshotPath
    }
    issue_update = [ordered]@{
        status = $effectiveStatus
        reason = $effectiveReason
        resume = $true
    }
    unblock = [ordered]@{
        owner = $unblockOwner
        action = [string]$blocked.unblock_owner.required_action
    }
    note = if ($effectiveStatus -eq 'blocked') {
        'Mark blocked until verifier owner completes acceptance rerun/fix.'
    } else {
        'Transition can proceed using recommended status from transition payload.'
    }
}

$outDir = Split-Path -Parent $outFull
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Host ("wrote={0}" -f $outFull)
Write-Host ("status={0}" -f $effectiveStatus)
Write-Host ("reason={0}" -f $effectiveReason)
exit 0
