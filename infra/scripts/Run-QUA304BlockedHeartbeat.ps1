param(
    [string]$RepoRoot = "C:/QM/repo"
)

$ErrorActionPreference = 'Stop'

$opsDir = Join-Path $RepoRoot 'docs/ops'
$pauseFile = Join-Path $opsDir 'QUA-304_PAUSE_UNTIL_CTO_2026-04-28.json'
$checkpointFile = Join-Path $opsDir 'QUA-304_WAKE_CHECKPOINTS_2026-04-28.md'

$utc = (Get-Date).ToUniversalTime().ToString('o')

$pause = @{
    issue = 'QUA-304'
    state = 'paused_waiting_cto_review'
    execution_policy = 'review-only'
    last_checked_utc = $utc
    unblock_owner = 'CTO'
    unblock_action = 'Provide review decision or request scoped deltas'
    development_status = 'implementation_complete'
}

$pause | ConvertTo-Json -Depth 4 | Set-Content -Path $pauseFile

$line = "- $utc | blocked_review_gate | heartbeat helper tick; no active failed run; unblock owner CTO -> review decision/request deltas."
Add-Content -Path $checkpointFile -Value $line

Write-Output "Updated: $pauseFile"
Write-Output "Updated: $checkpointFile"
