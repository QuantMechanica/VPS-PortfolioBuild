param(
    [string]$RepoRoot = 'C:\QM\repo',
    [switch]$AppendHeartbeatLog = $true
)

$utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')

# 1) Readiness probe
$readinessScript = Join-Path $RepoRoot 'artifacts\qua-342\check_src04_s03_readiness.ps1'
if (Test-Path -LiteralPath $readinessScript) {
    powershell -NoProfile -ExecutionPolicy Bypass -File $readinessScript | Out-Null
}
$readinessPath = Join-Path $RepoRoot 'artifacts\qua-342\src04_s03_readiness_latest.json'
$readiness = $null
if (Test-Path -LiteralPath $readinessPath) {
    $readiness = Get-Content -LiteralPath $readinessPath -Raw | ConvertFrom-Json
}

# 2) Infra snapshot
$term = Get-Process terminal64 -ErrorAction SilentlyContinue | Select-Object Id,Path,StartTime
$agg = Get-CimInstance Win32_Process -Filter "name='python.exe'" | Where-Object { $_.CommandLine -like '*standalone_aggregator_loop.py*' } | Select-Object ProcessId,CommandLine
$statePath = 'D:\QM\reports\state\last_check_state.json'
$state = $null
if (Test-Path -LiteralPath $statePath) {
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
}
$htmCount = (Get-ChildItem D:\QM\reports -Recurse -Filter *.htm -File -ErrorAction SilentlyContinue | Measure-Object).Count
$trackerCount = if ($state) { [int]$state.report_htm_total } else { -1 }
$disk = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -in @('C','D') } | Select-Object Name,@{n='FreeGB';e={[math]::Round($_.Free/1GB,2)}}

$stateHashInput = ''
if ($readiness) {
    $stableReadiness = [ordered]@{
        issue = $readiness.issue
        required_artifacts = $readiness.required_artifacts
        payload_readiness = $readiness.payload_readiness
        dispatch_ready = $readiness.dispatch_ready
        unblock_owner = $readiness.unblock_owner
        unblock_action = $readiness.unblock_action
    }
    $stateHashInput = ($stableReadiness | ConvertTo-Json -Depth 8 -Compress)
}
$stateHashBytes = [System.Text.Encoding]::UTF8.GetBytes($stateHashInput)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
    $hashBytes = $sha256.ComputeHash($stateHashBytes)
    $stateHash = -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
} finally {
    $sha256.Dispose()
}
$stateMetaPath = Join-Path $RepoRoot 'artifacts\qua-342\tick_state_latest.json'
$previousStateHash = $null
if (Test-Path -LiteralPath $stateMetaPath) {
    try {
        $previousState = Get-Content -LiteralPath $stateMetaPath -Raw | ConvertFrom-Json
        $previousStateHash = $previousState.state_hash
    } catch {}
}
$stateChanged = $true
if ($previousStateHash -and $previousStateHash -eq $stateHash) { $stateChanged = $false }

$bundle = [pscustomobject]@{
    issue = 'QUA-342'
    tick_utc = $utc
    blocked = if ($readiness) { -not [bool]$readiness.dispatch_ready } else { $true }
    readiness = $readiness
    infra = [pscustomobject]@{
        terminal_count = ($term | Measure-Object).Count
        terminal_pids = @($term | Select-Object -ExpandProperty Id)
        aggregator_pid = @($agg | Select-Object -ExpandProperty ProcessId)
        state_file = $statePath
        tracker_htm_total = $trackerCount
        filesystem_htm_total = $htmCount
        fs_tracker_mismatch = if ($trackerCount -ge 0) { $htmCount -ne $trackerCount } else { $true }
        disk_free_gb = $disk
    }
    unblock_owner = if ($readiness -and $readiness.unblock_owner) { $readiness.unblock_owner } else { 'CTO' }
    unblock_action = if ($readiness -and $readiness.unblock_action) { $readiness.unblock_action } else { 'Provide executable mapping fields: ea_name and setfile_path' }
    change_detection = [pscustomobject]@{
        state_hash = $stateHash
        previous_state_hash = $previousStateHash
        state_changed = $stateChanged
    }
}

$out = Join-Path $RepoRoot ("artifacts\\qua-342\\tick_bundle_{0}.json" -f $stamp)
$bundle | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $out
$latest = Join-Path $RepoRoot 'artifacts\qua-342\tick_bundle_latest.json'
$bundle | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $latest
$stateMeta = [pscustomobject]@{
    issue = 'QUA-342'
    tick_utc = $utc
    state_hash = $stateHash
}
$stateMeta | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $stateMetaPath

# Track consecutive unchanged-blocked ticks for deterministic escalation.
$streakPath = Join-Path $RepoRoot 'artifacts\qua-342\blocked_streak_latest.json'
$prevStreak = 0
if (Test-Path -LiteralPath $streakPath) {
    try {
        $prev = Get-Content -LiteralPath $streakPath -Raw | ConvertFrom-Json
        $prevStreak = [int]$prev.consecutive_unchanged_blocked_ticks
    } catch {}
}
$currentStreak = 0
if ($bundle.blocked -and (-not $stateChanged)) {
    $currentStreak = $prevStreak + 1
}
$streak = [pscustomobject]@{
    issue = 'QUA-342'
    tick_utc = $utc
    consecutive_unchanged_blocked_ticks = $currentStreak
    blocked = $bundle.blocked
    state_changed = $stateChanged
}
$streak | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $streakPath

# Compact blocker status for external pollers/escalation hooks.
$unblockStatusPath = Join-Path $RepoRoot 'artifacts\qua-342\unblock_status_latest.json'
$escalationThreshold = 5
$unblockStatus = [pscustomobject]@{
    issue = 'QUA-342'
    tick_utc = $utc
    blocked = $bundle.blocked
    dispatch_ready = if ($readiness) { [bool]$readiness.dispatch_ready } else { $false }
    state_changed = $stateChanged
    missing_fields = if ($readiness -and $readiness.payload_readiness -and $readiness.payload_readiness.missing_fields) { @($readiness.payload_readiness.missing_fields) } else { @() }
    unblock_owner = $bundle.unblock_owner
    unblock_action = $bundle.unblock_action
    consecutive_unchanged_blocked_ticks = $currentStreak
    escalation_threshold = $escalationThreshold
    escalate_now = ($bundle.blocked -and $currentStreak -ge $escalationThreshold)
    latest_tick_bundle = $out
}
$unblockStatus | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $unblockStatusPath

$statusMdPath = Join-Path $RepoRoot 'artifacts\qua-342\CURRENT_BLOCKER_STATUS.md'
$statusMd = @"
# QUA-342 Current Blocker Status

Updated (UTC): $utc

- issue: QUA-342
- blocked: $($unblockStatus.blocked)
- dispatch_ready: $($unblockStatus.dispatch_ready)
- state_changed: $($unblockStatus.state_changed)
- missing_fields: $([string]::Join(', ', $unblockStatus.missing_fields))
- unblock_owner: $($unblockStatus.unblock_owner)
- unblock_action: $($unblockStatus.unblock_action)
- consecutive_unchanged_blocked_ticks: $($unblockStatus.consecutive_unchanged_blocked_ticks)
- escalation_threshold: $($unblockStatus.escalation_threshold)
- escalate_now: $($unblockStatus.escalate_now)
- latest_tick_bundle: $($unblockStatus.latest_tick_bundle)
"@
$statusMd | Set-Content -LiteralPath $statusMdPath

$escalationPath = Join-Path $RepoRoot 'artifacts\qua-342\cto_escalation_trigger_latest.json'
if ($unblockStatus.escalate_now) {
    $existingTriggeredAt = $null
    if (Test-Path -LiteralPath $escalationPath) {
        try {
            $existingEsc = Get-Content -LiteralPath $escalationPath -Raw | ConvertFrom-Json
            $existingTriggeredAt = $existingEsc.triggered_at_utc
        } catch {}
    }

    $escalation = [pscustomobject]@{
        issue = 'QUA-342'
        triggered_at_utc = if ($existingTriggeredAt) { $existingTriggeredAt } else { $utc }
        reason = 'blocked_streak_threshold_reached'
        escalation_latched = $true
        consecutive_unchanged_blocked_ticks = $currentStreak
        escalation_threshold = $escalationThreshold
        unblock_owner = $bundle.unblock_owner
        unblock_action = $bundle.unblock_action
        latest_tick_bundle = $out
        last_seen_utc = $utc
    }
    $escalation | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $escalationPath
}

if ($AppendHeartbeatLog) {
    $hbPath = Join-Path $RepoRoot 'docs\ops\QUA-342_HEARTBEAT_UPDATE_2026-04-28.md'
    $stateChangedText = if ($stateChanged) { 'true' } else { 'false' }
    $missingText = if ($readiness -and $readiness.payload_readiness -and $readiness.payload_readiness.missing_fields) { ($readiness.payload_readiness.missing_fields -join ',') } else { 'none' }

    # Keep per-tick JSON artifacts, but reduce heartbeat doc noise for unchanged blocked state.
    $shouldAppend = $true
    if (-not $stateChanged -and $bundle.blocked) {
        $lastWriteUtc = $null
        if (Test-Path -LiteralPath $hbPath) {
            $lastLine = Get-Content -LiteralPath $hbPath -Tail 1
            if ($lastLine -match '^\-\s(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z):') {
                $lastWriteUtc = [datetime]::ParseExact($matches[1], 'yyyy-MM-ddTHH:mm:ssZ', $null).ToUniversalTime()
            }
        }

        if ($lastWriteUtc) {
            $minutesSince = ((Get-Date).ToUniversalTime() - $lastWriteUtc).TotalMinutes
            if ($minutesSince -lt 30) {
                $shouldAppend = $false
            }
        }
    }

    if ($shouldAppend) {
        $line = ('- {0}: auto-tick {1}; state_changed={2}; blocked={3}; dispatch_ready={4}; missing={5}; fs_tracker_mismatch={6}; unblock_owner={7}; unblock_action="{8}".' -f $utc, [System.IO.Path]::GetFileName($out), $stateChangedText, $bundle.blocked, $readiness.dispatch_ready, $missingText, $bundle.infra.fs_tracker_mismatch, $bundle.unblock_owner, $bundle.unblock_action)
        Add-Content -LiteralPath $hbPath -Value $line
    }
}

# Auto-write compact no-change heartbeat marker/log for low-noise ops tracking.
$noChangeLine = ('{0} | blocked={1} dispatch_ready={2} escalate_now={3} streak={4}' -f $utc, $unblockStatus.blocked, $unblockStatus.dispatch_ready, $unblockStatus.escalate_now, $unblockStatus.consecutive_unchanged_blocked_ticks)
$noChangeLatestPath = Join-Path $RepoRoot 'artifacts\qua-342\heartbeat_nochange_latest.txt'
$noChangeLogPath = Join-Path $RepoRoot 'artifacts\qua-342\heartbeat_nochange_log.txt'
Set-Content -LiteralPath $noChangeLatestPath -Value $noChangeLine -Encoding ASCII
Add-Content -LiteralPath $noChangeLogPath -Value $noChangeLine -Encoding ASCII
try {
    $allNoChange = Get-Content -LiteralPath $noChangeLogPath
    if ($allNoChange.Count -gt 200) {
        $allNoChange | Select-Object -Last 200 | Set-Content -LiteralPath $noChangeLogPath -Encoding ASCII
    }
} catch {}

# Auto-refresh CTO handoff manifest when helper script exists.
$manifestScript = Join-Path $RepoRoot 'artifacts\qua-342\emit_cto_handoff_manifest.ps1'
if (Test-Path -LiteralPath $manifestScript) {
    try {
        powershell -NoProfile -ExecutionPolicy Bypass -File $manifestScript -RepoRoot $RepoRoot | Out-Null
    } catch {}
}

Write-Output "tick.output=$out"
Write-Output (Get-Content -LiteralPath $out -Raw)
