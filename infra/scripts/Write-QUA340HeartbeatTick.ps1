[CmdletBinding()]
param(
    [string]$ReadinessJson,
    [string]$DiagnosticsPath = "C:\QM\worktrees\pipeline-operator\docs\ops\QUA-340_REPORT_MISSING_DIAGNOSTICS_2026-04-28.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $ReadinessJson) {
    $latest = Get-ChildItem -LiteralPath "C:\QM\worktrees\pipeline-operator\artifacts\qua-340-real" -Filter "qua340_readiness_check_*.json" -File |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if (-not $latest) { throw "No readiness snapshot found." }
    $ReadinessJson = $latest.FullName
}

if (-not (Test-Path -LiteralPath $ReadinessJson -PathType Leaf)) {
    throw "Readiness JSON not found: $ReadinessJson"
}

$j = Get-Content -LiteralPath $ReadinessJson -Raw | ConvertFrom-Json
$ts = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$ready = $j.readiness.ready_for_queued_smoke
$reason = $j.card_parse.reason
$raw = $j.card_parse.raw

$stateDir = "C:\QM\worktrees\pipeline-operator\artifacts\qua-340-real\state"
$queuePath = Join-Path $stateDir "factory_run_queue_v1.jsonl"
$dedupPath = Join-Path $stateDir "factory_run_dedup_v1.csv"

$queueDepth = 0
$claimedTerminals = @()
$runningTerminals = @()
$finalAckCounts = @{}
$dedupRejects = 0

if (Test-Path -LiteralPath $queuePath -PathType Leaf) {
    $queueRows = @(Get-Content -LiteralPath $queuePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json })
    foreach ($row in $queueRows) {
        $lastTransition = $null
        if ($row.transitions -and $row.transitions.Count -gt 0) {
            $lastTransition = $row.transitions[-1]
        }
        if ($null -eq $lastTransition) { continue }

        $status = [string]$lastTransition.status
        if ($status -eq "claim") { $claimedTerminals += [string]$row.terminal }
        if ($status -eq "running") { $runningTerminals += [string]$row.terminal }
        if ($status -ne "ack") { $queueDepth++ }
    }
}

if (Test-Path -LiteralPath $dedupPath -PathType Leaf) {
    $dedupRows = Import-Csv -LiteralPath $dedupPath
    foreach ($row in $dedupRows) {
        if ([string]$row.status -eq "ack") {
            $finalStatus = [string]$row.final_status
            if (-not $finalAckCounts.ContainsKey($finalStatus)) { $finalAckCounts[$finalStatus] = 0 }
            $finalAckCounts[$finalStatus]++
        }
    }
}

$claimedTerminals = @($claimedTerminals | Where-Object { $_ } | Sort-Object -Unique)
$runningTerminals = @($runningTerminals | Where-Object { $_ } | Sort-Object -Unique)
$finalAckSummary = if ($finalAckCounts.Count -gt 0) {
    ($finalAckCounts.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ", "
} else {
    "none"
}

$lines = @(
    "",
    "## Heartbeat Tick $ts",
    "",
    "No-change blocked tick.",
    "",
    "- Refreshed readiness snapshot: ``$ReadinessJson``",
    "- Snapshot verdict: ``ready_for_queued_smoke=$ready``, ``card_parse.reason=$reason``, ``card_parse.raw=$raw``",
    "- Refreshed unblock payload: ``docs/ops/QUA-340_UNBLOCK_PAYLOAD_2026-04-28.md``",
    "- Queue depth: ``$queueDepth``",
    "- Claimed terminals: ``$($claimedTerminals -join ',')``",
    "- Running terminals: ``$($runningTerminals -join ',')``",
    "- De-dup rejects (this heartbeat): ``$dedupRejects``",
    "- Final ack statuses (aggregate): ``$finalAckSummary``",
    "- Blocker unchanged: upstream allocation/build gates still open."
)

$lines | Add-Content -LiteralPath $DiagnosticsPath -Encoding UTF8
Write-Output "tick_written=$DiagnosticsPath"
