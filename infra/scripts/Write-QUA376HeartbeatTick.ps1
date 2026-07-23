[CmdletBinding()]
param(
    [string]$StateRoot = "C:\QM\worktrees\pipeline-operator\artifacts\qua-376-smoke\state",
    [string]$ReadinessArtifact = "C:\QM\worktrees\pipeline-operator\artifacts\qua-376\proxy_pair_readiness.json",
    [string]$OutJson = "C:\QM\worktrees\pipeline-operator\docs\ops\QUA-376_HEARTBEAT_TICK_latest.json",
    [string]$HeartbeatType = "no_change",
    [string]$BlockedOwner = "CTO/Dev",
    [string]$BlockedAction = "deploy SRC05_S01 binary + activate registry row"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$queuePath = Join-Path $StateRoot "factory_run_queue_v1.jsonl"
$dedupPath = Join-Path $StateRoot "factory_run_dedup_v1.csv"

$events = if (Test-Path -LiteralPath $queuePath) {
    Get-Content -LiteralPath $queuePath |
        Where-Object { $_ -and $_.Trim() } |
        ForEach-Object { $_ | ConvertFrom-Json }
} else {
    @()
}

$rows = if (Test-Path -LiteralPath $dedupPath) {
    Import-Csv -LiteralPath $dedupPath
} else {
    @()
}

$queueDepth = @($events | Where-Object { $_.transitions[-1].status -ne "ack" }).Count
$ackStatusCounts = @($rows | Group-Object final_status | ForEach-Object {
    [ordered]@{
        status = $_.Name
        count = $_.Count
    }
})

$terminals = "T1", "T2", "T3", "T4", "T5"
$procs = Get-Process terminal64 -ErrorAction SilentlyContinue | Select-Object Id, Path
$running = @()
foreach ($p in $procs) {
    if ($p.Path -match "\\(T[1-5])\\terminal64\.exe$") {
        $running += $matches[1]
    }
}
$runningUnique = @($running | Sort-Object -Unique)

$terminalStatus = @()
foreach ($t in $terminals) {
    $terminalStatus += [ordered]@{
        terminal = $t
        running = ($runningUnique -contains $t)
    }
}

$readiness = "unknown"
if (Test-Path -LiteralPath $ReadinessArtifact) {
    try {
        $r = Get-Content -LiteralPath $ReadinessArtifact -Raw | ConvertFrom-Json
        if ($r.readiness) {
            $readiness = [string]$r.readiness
        }
    } catch {
        $readiness = "parse_error"
    }
}

$payload = [ordered]@{
    ts_utc = (Get-Date).ToUniversalTime().ToString("o")
    issue = "QUA-376"
    status = "blocked_pending_cto_dev"
    heartbeat_type = $HeartbeatType
    queue_depth = $queueDepth
    terminals = $terminalStatus
    claimed_terminals = @($rows | Select-Object -ExpandProperty terminal -Unique)
    dedup_row_count = @($rows).Count
    ack_status_counts = $ackStatusCounts
    readiness = $readiness
    readiness_artifact = $ReadinessArtifact
    blocked_on = [ordered]@{
        owner = $BlockedOwner
        action = $BlockedAction
    }
}

$parent = Split-Path -Parent $OutJson
if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutJson -Encoding UTF8
$payload | ConvertTo-Json -Depth 8
