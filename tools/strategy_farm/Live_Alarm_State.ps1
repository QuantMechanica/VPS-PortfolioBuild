<#
.SYNOPSIS
  WS-E1 transition-deduplicated live-terminal alarm STATE contract.

.DESCRIPTION
  Function-only, side-effect-free helper dot-sourced by T_Live_Watchdog.ps1.
  It does NOT recover anything, does NOT launch, does NOT probe processes, and
  does NOT send mail. It is pure observability: the existing watchdog + resident
  session-supervisor chain remains the single recovery authority. This helper
  only translates the facts that chain already observed into a small, atomic,
  transition-deduplicated STATE file for downstream consumers (morning briefing,
  cockpit, WS-E2).

  Loading this file must have no effect other than defining functions, so the
  watchdog can fail closed (skip alarm emission) if it is ever absent.

.ALARM STATE FILE
  Path (production): D:\QM\reports\state\live_alarm_state.json
  Author: T_Live_Watchdog (SYSTEM, ~1/min). Single author => no write contention,
  deterministic deduplication.

  Top-level schema:
    schema_version   int     contract version (1)
    generated_utc    string  UTC 'yyyy-MM-ddTHH:mm:ssZ' of THIS write; refreshed
                             every cycle so consumers can detect a dead watchdog
                             (staleness => treat as UNKNOWN/RED, never green).
    author           string  'T_Live_Watchdog'
    watchdog_status  string  the watchdog's overall status this cycle
                             (healthy|degraded|critical|maintenance) for cross-ref.
    maintenance      bool    maintenance kill switch active this cycle.
    reboot_suppressed bool   a reboot-suppression / cancel / countdown-abort action
                             fired this cycle (informational for consumers).
    any_alarm        bool    true if ANY session condition is an alarm condition
                             (missing|duplicate|launch_failed|probe_unknown|stale).
    sessions         object  { T_LIVE: <entry>, FTMO: <entry> }

  Per-session entry schema (the deduplicated STATE contract):
    session            string  'T_LIVE' | 'FTMO'
    condition          string  ok | missing | duplicate | launch_failed |
                               probe_unknown | stale | maintenance
    detail             string  human-readable reason; MAY change without counting
                               as a transition (informational only).
    alarm              bool    condition is one of the alarm conditions above.
    since_utc          string  UTC when the CURRENT condition began (age anchor).
                               Stable while the condition holds; moves only on a
                               genuine condition change (deduplication).
    last_change        string  UTC of the most recent condition change. Equal to
                               since_utc by construction (both mark the last
                               transition); kept as an explicit transition marker
                               for consumers that prefer that name.
    transitions        int     count of condition CHANGES since the file was first
                               created for this session. First observation seeds a
                               baseline with transitions=0; it increments only when
                               the condition value actually changes.
    previous_condition string  the condition this session held before last_change
                               (null on the first observation).

  DEDUPLICATION invariant: while a session's condition is unchanged across cycles,
  transitions / since_utc / last_change / previous_condition are preserved
  byte-for-byte; only detail and the top-level generated_utc refresh. This is what
  makes the file safe for change-driven consumers (no thrash on a stable alarm).

.CONDITION DERIVATION (per session; precedence top to bottom)
    maintenance     maintenance flag active           (suppresses all alarms)
    probe_unknown   watchdog process probe UNKNOWN     (fail-closed; not "both up")
    duplicate       >1 terminal for this session, OR exactly one but placed in the
                    wrong desktop session
    launch_failed   terminal absent AND the resident supervisor (fresh heartbeat)
                    recorded a launcher failure for this session
    missing         terminal absent (recovery pending / no interactive session /
                    supervisor not fresh)
    stale           terminal UP and singly placed, BUT the supervisor heartbeat is
                    not fresh => recovery authority for this session is unconfirmed
    ok              terminal running, exactly one, correct session, supervisor fresh
#>

Set-StrictMode -Version Latest

$script:QmLiveAlarmStateVersion = 1
$script:QmLiveAlarmConditions = @('ok', 'missing', 'duplicate', 'launch_failed', 'probe_unknown', 'stale', 'maintenance')
$script:QmLiveAlarmAlarmConditions = @('missing', 'duplicate', 'launch_failed', 'probe_unknown', 'stale')
$script:QmLiveAlarmSessions = @('T_LIVE', 'FTMO')

function Get-LiveAlarmUtcStamp {
    return [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function ConvertTo-LiveAlarmStamp {
    # Cross-version stamp normalizer. Windows PowerShell 5.1 (production) leaves
    # JSON date strings as strings; PowerShell 7.x auto-coerces ISO-8601 strings
    # to [DateTime] on ConvertFrom-Json. Normalize either form back to the exact
    # canonical UTC ISO string so round-tripped timestamps never drift into a
    # local-culture format.
    param([AllowNull()]$Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) {
        return ([datetime]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
    $s = [string]$Value
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    return $s
}

function Test-LiveAlarmCondition {
    # Central definition of "is this condition an alarm?" so callers stay in sync.
    param([AllowNull()][string]$Condition)
    return [bool]($script:QmLiveAlarmAlarmConditions -contains $Condition)
}

function Get-LiveAlarmCondition {
    <#
      Pure function: map one session's already-observed facts to a condition.
      No I/O, no process access. Inputs come straight from what the watchdog and
      the supervisor state file already produced.
    #>
    [CmdletBinding()]
    param(
        [bool]$Maintenance,
        [bool]$ProbeOk,
        [bool]$Running,
        [int]$ProcessCount,
        [bool]$SessionExists,
        [bool]$PlacementOk,
        [bool]$SupervisorHeartbeatReady,
        [AllowNull()][string]$SupervisorReason,
        [bool]$SupervisorLaunchFailed
    )
    if ($Maintenance) {
        return [pscustomobject]@{ condition = 'maintenance'; detail = 'maintenance_flag_active' }
    }
    if (-not $ProbeOk) {
        return [pscustomobject]@{ condition = 'probe_unknown'; detail = 'process_probe_failed' }
    }
    if ($ProcessCount -gt 1) {
        return [pscustomobject]@{ condition = 'duplicate'; detail = "duplicate_process_count=$ProcessCount" }
    }
    if ($Running -and $SessionExists -and (-not $PlacementOk)) {
        return [pscustomobject]@{ condition = 'duplicate'; detail = 'wrong_session_placement' }
    }
    if (-not $Running) {
        if ($SupervisorLaunchFailed) {
            return [pscustomobject]@{ condition = 'launch_failed'; detail = 'supervisor_reported_launch_failure' }
        }
        if (-not $SessionExists) {
            return [pscustomobject]@{ condition = 'missing'; detail = 'terminal_absent_no_interactive_session' }
        }
        if (-not $SupervisorHeartbeatReady) {
            $reasonTag = if ($SupervisorReason) { $SupervisorReason } else { 'unknown' }
            return [pscustomobject]@{ condition = 'missing'; detail = "terminal_absent_supervisor_${reasonTag}" }
        }
        return [pscustomobject]@{ condition = 'missing'; detail = 'terminal_absent_recovery_pending' }
    }
    # Running, single instance, correct placement.
    if (-not $SupervisorHeartbeatReady) {
        $reasonTag = if ($SupervisorReason) { $SupervisorReason } else { 'unknown' }
        return [pscustomobject]@{ condition = 'stale'; detail = "terminal_up_supervisor_${reasonTag}" }
    }
    return [pscustomobject]@{ condition = 'ok'; detail = 'terminal_running' }
}

function Update-LiveAlarmEntry {
    <#
      Pure function: apply transition deduplication to one session entry.
      Given the previous entry (or $null) and the newly derived condition/detail,
      return the updated ordered entry with stable since_utc/last_change/transitions
      while the condition is unchanged.
    #>
    [CmdletBinding()]
    param(
        [string]$SessionName,
        [AllowNull()]$PrevEntry,
        [string]$Condition,
        [AllowNull()][string]$Detail,
        [string]$NowStamp
    )
    $prevCondition = $null
    $prevSince = $null
    $prevTransitions = 0
    $prevLastChange = $null
    if ($null -ne $PrevEntry) {
        try { $prevCondition = [string]$PrevEntry.condition } catch { $prevCondition = $null }
        try { $prevSince = ConvertTo-LiveAlarmStamp $PrevEntry.since_utc } catch { $prevSince = $null }
        try { $prevTransitions = [int]$PrevEntry.transitions } catch { $prevTransitions = 0 }
        try { $prevLastChange = ConvertTo-LiveAlarmStamp $PrevEntry.last_change } catch { $prevLastChange = $null }
    }

    if ([string]::IsNullOrEmpty($prevCondition)) {
        # First observation for this session: establish the baseline, zero changes.
        $since = $NowStamp
        $lastChange = $NowStamp
        $transitions = 0
        $previousCondition = $null
    } elseif ($prevCondition -eq $Condition) {
        # No transition: preserve the durable transition fields (deduplication).
        $since = if ($prevSince) { $prevSince } else { $NowStamp }
        $lastChange = if ($prevLastChange) { $prevLastChange } else { $NowStamp }
        $transitions = $prevTransitions
        $previousCondition = $prevCondition
    } else {
        # Genuine condition change.
        $since = $NowStamp
        $lastChange = $NowStamp
        $transitions = $prevTransitions + 1
        $previousCondition = $prevCondition
    }

    return [ordered]@{
        session = $SessionName
        condition = $Condition
        detail = $Detail
        alarm = (Test-LiveAlarmCondition -Condition $Condition)
        since_utc = $since
        last_change = $lastChange
        transitions = $transitions
        previous_condition = $previousCondition
    }
}

function Get-SupervisorAlarmFacts {
    <#
      Read the resident supervisor's existing state file (read-only) for the two
      facts the watchdog does not already surface: per-session launcher failure
      and per-session target state. Freshness is judged against the supervisor's
      own last_checked_utc. This is a state-FILE read, never a process probe.
    #>
    [CmdletBinding()]
    param(
        [string]$StateFilePath,
        [ValidateRange(5, 600)][int]$FreshnessSeconds = 60,
        [datetime]$NowUtc = [DateTime]::UtcNow
    )
    $result = [pscustomobject]@{
        fresh = $false
        dxz_state = 'unknown'
        ftmo_state = 'unknown'
        dxz_launch_failed = $false
        ftmo_launch_failed = $false
        reason = 'not_read'
    }
    if (-not (Test-Path -LiteralPath $StateFilePath -PathType Leaf)) {
        $result.reason = 'state_missing'
        return $result
    }
    try {
        $value = Get-Content -LiteralPath $StateFilePath -Raw -ErrorAction Stop | ConvertFrom-Json
        $checked = $null
        $rawChecked = $null
        if ($value.PSObject.Properties.Name -contains 'last_checked_utc') { $rawChecked = $value.last_checked_utc }
        try {
            if ($rawChecked -is [datetime]) {
                # PowerShell 7.x already parsed the ISO stamp to a DateTime.
                $checked = ([datetime]$rawChecked).ToUniversalTime()
            } else {
                # Windows PowerShell 5.1 keeps it as the raw ISO string.
                $checked = [DateTime]::ParseExact(
                    [string]$rawChecked,
                    'yyyy-MM-ddTHH:mm:ssZ',
                    [Globalization.CultureInfo]::InvariantCulture,
                    ([Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal)
                )
            }
        } catch { $checked = $null }
        if ($null -eq $checked) {
            $result.reason = 'invalid_timestamp'
            return $result
        }
        $age = ($NowUtc - $checked).TotalSeconds
        $result.fresh = ($age -ge -5 -and $age -le $FreshnessSeconds)
        if ($value.PSObject.Properties.Name -contains 'dxz_state') { $result.dxz_state = [string]$value.dxz_state }
        if ($value.PSObject.Properties.Name -contains 'ftmo_state') { $result.ftmo_state = [string]$value.ftmo_state }
        $errs = @()
        if ($value.PSObject.Properties.Name -contains 'errors') { $errs = @($value.errors) }
        $launchPattern = '^(launcher_failed|launcher_exception|launcher_wrong_session|pending_launcher_failed):'
        $result.dxz_launch_failed = [bool](@($errs | Where-Object { $_ -match ($launchPattern + 'DXZ') }).Count -gt 0)
        $result.ftmo_launch_failed = [bool](@($errs | Where-Object { $_ -match ($launchPattern + 'FTMO') }).Count -gt 0)
        $result.reason = 'read'
    } catch {
        $result.reason = "unreadable:$($_.Exception.Message)"
    }
    return $result
}

function Build-LiveAlarmState {
    <#
      Pure builder: given the previous parsed alarm document (or $null) and the
      per-session derived {condition, detail}, return the ordered top-level state
      with deduplication applied. No I/O.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]$PrevDocument,
        [string]$NowStamp,
        [AllowNull()][string]$WatchdogStatus,
        [bool]$Maintenance,
        [bool]$RebootSuppressed,
        [System.Collections.IDictionary]$Sessions
    )
    $sessionOut = [ordered]@{}
    $anyAlarm = $false
    foreach ($name in $script:QmLiveAlarmSessions) {
        $c = $Sessions[$name]
        if ($null -eq $c) {
            $c = [pscustomobject]@{ condition = 'probe_unknown'; detail = 'session_condition_not_supplied' }
        }
        $prevEntry = $null
        if ($null -ne $PrevDocument -and ($PrevDocument.PSObject.Properties.Name -contains 'sessions') -and $null -ne $PrevDocument.sessions) {
            if ($PrevDocument.sessions.PSObject.Properties.Name -contains $name) {
                $prevEntry = $PrevDocument.sessions.$name
            }
        }
        $entry = Update-LiveAlarmEntry -SessionName $name -PrevEntry $prevEntry `
            -Condition ([string]$c.condition) -Detail ([string]$c.detail) -NowStamp $NowStamp
        if ($entry.alarm) { $anyAlarm = $true }
        $sessionOut[$name] = $entry
    }
    return [ordered]@{
        schema_version = $script:QmLiveAlarmStateVersion
        generated_utc = $NowStamp
        author = 'T_Live_Watchdog'
        watchdog_status = $WatchdogStatus
        maintenance = $Maintenance
        reboot_suppressed = $RebootSuppressed
        any_alarm = $anyAlarm
        sessions = $sessionOut
    }
}

function Write-LiveAlarmState {
    <#
      Read the previous alarm file (read-only), build the deduplicated state, and
      write it atomically (temp write + rename). DryRun emits the JSON to the
      pipeline and writes nothing. Returns the built ordered document.
    #>
    [CmdletBinding()]
    param(
        [string]$AlarmFilePath,
        [string]$NowStamp,
        [AllowNull()][string]$WatchdogStatus,
        [bool]$Maintenance,
        [bool]$RebootSuppressed,
        [System.Collections.IDictionary]$Sessions,
        [switch]$DryRun
    )
    $prev = $null
    if (Test-Path -LiteralPath $AlarmFilePath -PathType Leaf) {
        try { $prev = Get-Content -LiteralPath $AlarmFilePath -Raw -ErrorAction Stop | ConvertFrom-Json } catch { $prev = $null }
    }
    $doc = Build-LiveAlarmState -PrevDocument $prev -NowStamp $NowStamp -WatchdogStatus $WatchdogStatus `
        -Maintenance $Maintenance -RebootSuppressed $RebootSuppressed -Sessions $Sessions
    $json = $doc | ConvertTo-Json -Depth 6

    if ($DryRun.IsPresent) {
        Write-Output $json
        return $doc
    }

    $tmp = $null
    $replaceBackup = $null
    try {
        $dir = Split-Path -Parent $AlarmFilePath
        [IO.Directory]::CreateDirectory($dir) | Out-Null
        $tmp = Join-Path $dir ('.live_alarm_state.' + $PID + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
        $utf8NoBom = [Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText($tmp, $json, $utf8NoBom)
        if (Test-Path -LiteralPath $AlarmFilePath -PathType Leaf) {
            $replaceBackup = Join-Path $dir ('.live_alarm_state.' + $PID + '.' + [guid]::NewGuid().ToString('N') + '.bak')
            [IO.File]::Replace($tmp, $AlarmFilePath, $replaceBackup, $true)
        } else {
            [IO.File]::Move($tmp, $AlarmFilePath)
        }
        $tmp = $null
    } catch {
        Write-Warning "Could not write live alarm state: $($_.Exception.Message)"
    } finally {
        if ($tmp -and [IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) }
        if ($replaceBackup -and [IO.File]::Exists($replaceBackup)) { [IO.File]::Delete($replaceBackup) }
    }
    return $doc
}
