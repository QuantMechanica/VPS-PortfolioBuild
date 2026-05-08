param(
    [string]$ChecklistPath = "C:\QM\repo\framework\EAs\QM5_1017_chan_pairs_stat_arb\CHECKLIST.md",
    [string]$ReadyPacketPath = "C:\QM\repo\docs\ops\QUA-750_READY_FOR_REVIEW_2026-05-05.md",
    [string]$FinalStatePath = "C:\QM\repo\docs\ops\QUA-750_FINAL_STATE_2026-05-05T2025Z.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ChecklistPath -PathType Leaf)) {
    throw "Checklist not found: $ChecklistPath"
}

$text = Get-Content -LiteralPath $ChecklistPath -Raw
$pending = $text -match "pending_cto_confirmation"
$readyExists = Test-Path -LiteralPath $ReadyPacketPath -PathType Leaf
$stateExists = Test-Path -LiteralPath $FinalStatePath -PathType Leaf
$readyMtime = if ($readyExists) { (Get-Item -LiteralPath $ReadyPacketPath).LastWriteTimeUtc.ToString("o") } else { $null }
$stateMtime = if ($stateExists) { (Get-Item -LiteralPath $FinalStatePath).LastWriteTimeUtc.ToString("o") } else { $null }
$packageComplete = $readyExists -and $stateExists

$snapshot = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
    issue = "QUA-750"
    guard = "qua750_wait_guard"
    pending_cto_confirmation = $pending
    package_complete = $packageComplete
    ready_packet_mtime_utc = $readyMtime
    final_state_mtime_utc = $stateMtime
    decision = $(if ($pending -and $packageComplete) { "NOOP_WAIT_EXTERNAL_REVIEW" } else { "REVIEW_SIGNAL_CHANGED" })
}

$snapshot | ConvertTo-Json -Depth 4
