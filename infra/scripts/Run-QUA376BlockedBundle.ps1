[CmdletBinding()]
param(
    [string]$OutDir = "C:\QM\worktrees\pipeline-operator\docs\ops",
    [switch]$EmitTimestampedTick,
    [string]$BinaryName = "QM5_SRC05_S01_chan_at_bb_pair.ex5"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\.." )).Path
$tickScript = Join-Path $repoRoot "infra\scripts\Write-QUA376HeartbeatTick.ps1"
if (-not (Test-Path -LiteralPath $tickScript -PathType Leaf)) {
    throw "Missing script: $tickScript"
}

$stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
$tickOut = if ($EmitTimestampedTick.IsPresent) {
    Join-Path $OutDir ("QUA-376_HEARTBEAT_TICK_{0}.json" -f $stamp)
} else {
    Join-Path $OutDir "QUA-376_HEARTBEAT_TICK_latest.json"
}

$tickJson = & $tickScript -OutJson $tickOut
$tick = $tickJson | ConvertFrom-Json

$statusPath = Join-Path $OutDir "QUA-376_ISSUE_STATUS_UPDATE_2026-04-28.json"
$status = [ordered]@{
    issue = "QUA-376"
    generated_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    source = [ordered]@{
        heartbeat_tick_json = $tickOut
        readiness_artifact_json = "artifacts\\qua-376\\proxy_pair_readiness.json"
        first_run_request_json = "docs\\ops\\QUA-376_FIRST_PAIR_RUN_REQUEST_2026-04-28.json"
    }
    issue_update = [ordered]@{
        status = "blocked"
        reason = "waiting_on_src05_s01_expert_binary_and_magic_registry_activation"
        resume = $true
    }
    unblock = [ordered]@{
        owner = "CTO/Dev"
        action = "Compile/deploy QM5_SRC05_S01 expert to T1-T5 and activate corresponding magic registry row, then execute first pair-mapped queue run using XAUUSD.DWX/XTIUSD.DWX nonce-safe sub_gate_config."
    }
    note = "Blocked state refreshed from latest heartbeat tick."
}
$status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statusPath -Encoding UTF8

$commentPath = Join-Path $OutDir "QUA-376_BLOCKED_COMMENT_2026-04-28.md"
$lines = @(
    "# QUA-376 Blocked Status Comment - $(Get-Date -Format 'yyyy-MM-dd')",
    "",
    "Blocked state refreshed from latest heartbeat tick:",
    ("- tick: {0}" -f $tickOut),
    ("- queue_depth: {0}" -f $tick.queue_depth),
    ("- readiness: {0}" -f $tick.readiness),
    "",
    "Blocked on:",
    ("- owner: {0}" -f $tick.blocked_on.owner),
    ("- action: {0}" -f $tick.blocked_on.action),
    "",
    "Resume path remains `resume=true` once dependency is complete."
)
$lines | Set-Content -LiteralPath $commentPath -Encoding UTF8

$watchPath = if ($EmitTimestampedTick.IsPresent) {
    Join-Path $OutDir ("QUA-376_BLOCKER_WATCH_{0}.json" -f $stamp)
} else {
    Join-Path $OutDir "QUA-376_BLOCKER_WATCH_latest.json"
}

$terms = "T1", "T2", "T3", "T4", "T5"
$binaryRows = @()
foreach ($t in $terms) {
    $p = "D:\QM\mt5\$t\MQL5\Experts\QM\$BinaryName"
    $binaryRows += [ordered]@{
        terminal = $t
        exists = (Test-Path -LiteralPath $p)
        path = $p
    }
}
$binaryPresentAll = @($binaryRows | Where-Object { $_.exists -eq $true }).Count -eq $terms.Count

$registryRows = @()
$registryPath = Join-Path $repoRoot "framework\registry\magic_numbers.csv"
if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
    $registryRows = @(Import-Csv -LiteralPath $registryPath)
}
$activeRows = @($registryRows | Where-Object { $_.status -eq "active" })
$hasSrc05Active = @(
    $activeRows | Where-Object {
        $_.ea_slug -match "src05" -or
        $_.ea_slug -match "chan-at-bb-pair" -or
        $_.ea_id -match "SRC05"
    }
).Count -gt 0

$watch = [ordered]@{
    ts_utc = (Get-Date).ToUniversalTime().ToString("o")
    issue = "QUA-376"
    watch = "unblock_dependency"
    binary_name = $BinaryName
    binary_present_all_terminals = $binaryPresentAll
    terminals = $binaryRows
    registry_active_src05_s01 = $hasSrc05Active
    registry_active_rows = @($activeRows | ForEach-Object {
        [ordered]@{
            ea_id = $_.ea_id
            ea_slug = $_.ea_slug
            symbol = $_.symbol
            status = $_.status
        }
    })
    blocked_on = [ordered]@{
        owner = "CTO/Dev"
        action = "deploy binary + activate registry row"
    }
    state = $(if ($binaryPresentAll -and $hasSrc05Active) { "ready_to_resume" } else { "no_change_blocked" })
}
$watch | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $watchPath -Encoding UTF8

$result = [ordered]@{
    status = "ok"
    tick_json = $tickOut
    issue_status_update_json = $statusPath
    blocked_comment_md = $commentPath
    blocker_watch_json = $watchPath
}
$result | ConvertTo-Json -Depth 6
