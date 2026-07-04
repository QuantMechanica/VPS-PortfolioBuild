# =====================================================================
#  QM_StrategyFarm_HygieneReboot — Weekly preventive hygiene reboot
#
#  PURPOSE:
#    Controlled reboot during the forex/CFD market-closed window
#    (Saturday 06:00-12:00 local, W. Europe Standard Time) to purge
#    session-manager resource exhaustion.  The ~100+ terminal64.exe
#    spawns/day deplete LSM handles; symptoms after ~7 days uptime:
#    qwinsta error 87, scheduled tasks fail 0x800710E0, shutdown.exe /
#    Restart-Computer / WMI RPC 1722 — requiring a hosting-panel reset.
#
#  RECOVERY CHAIN (fully automatic post-reboot via existing tasks):
#    Autologon  →  QM_T_Live_AtLogon  →  QM_StrategyFarm_FactoryON_AtLogon
#    Forex market closes Fri ~21:00 UTC; reopens Sun ~21:00 UTC.
#    Saturday morning is safe for live trading.
#
#  GUARDS — ALL four must pass; any failure logs a skip reason and exits 0:
#    1. Local day-of-week = Saturday  AND  local hour ∈ [06, 12)
#    2. System uptime >= 5 days  (reboot too-soon is pointless churn)
#    3. Kill-switch flag absent:  D:\QM\reports\state\HYGIENE_REBOOT_DISABLED.flag
#    4. Debounce: last hygiene reboot > 3 days ago (or no prior record)
#
#  STATE FILE:  D:\QM\reports\state\hygiene_reboot_state.json
#                { ts, uptime_days, reason:'weekly_hygiene' }  — written BEFORE reboot
#  LOG FILE:    D:\QM\reports\state\hygiene_reboot.log  (append, UTC timestamps)
#  KILL SWITCH: touch D:\QM\reports\state\HYGIENE_REBOOT_DISABLED.flag
#
#  *** DO NOT RUN MANUALLY ***
#  Designed for the QM_StrategyFarm_HygieneReboot scheduled task (SYSTEM).
# =====================================================================

$STATE_DIR    = 'D:\QM\reports\state'
$STATE_FILE   = Join-Path $STATE_DIR 'hygiene_reboot_state.json'
$LOG_FILE     = Join-Path $STATE_DIR 'hygiene_reboot.log'
$DISABLE_FLAG = Join-Path $STATE_DIR 'HYGIENE_REBOOT_DISABLED.flag'

$MIN_UPTIME_DAYS = 5
$DEBOUNCE_DAYS   = 3
$HOUR_START      = 6    # inclusive
$HOUR_END        = 12   # exclusive  (06:00 <= hour < 12:00)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Log {
    param([string]$Msg)
    $ts   = [System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $line = "$ts  $Msg"
    Write-Host $line
    try {
        [System.IO.Directory]::CreateDirectory($STATE_DIR) | Out-Null
        [System.IO.File]::AppendAllText(
            $LOG_FILE,
            $line + [System.Environment]::NewLine,
            [System.Text.Encoding]::UTF8
        )
    } catch { }
}

# Ensure state dir exists (best-effort, very early)
try { [System.IO.Directory]::CreateDirectory($STATE_DIR) | Out-Null } catch { }

Write-Log '=== HygieneReboot guard evaluation START ==='

# ---------------------------------------------------------------------------
# Guard 1 — Saturday + 06-12 window (local time)
# ---------------------------------------------------------------------------
$now    = [System.DateTime]::Now
$dayOk  = ($now.DayOfWeek -eq [System.DayOfWeek]::Saturday)
$hourOk = ($now.Hour -ge $HOUR_START -and $now.Hour -lt $HOUR_END)
Write-Log "Guard1  day=$($now.DayOfWeek)  hour=$($now.Hour)  dayOk=$dayOk  hourOk=$hourOk"
if (-not ($dayOk -and $hourOk)) {
    Write-Log "SKIP: Guard1 FAIL — not Saturday 06-12 local time (day=$($now.DayOfWeek) hour=$($now.Hour))"
    exit 0
}
Write-Log 'Guard1 PASS'

# ---------------------------------------------------------------------------
# Guard 2 — System uptime >= 5 days
# ---------------------------------------------------------------------------
$uptimeDays = $null
try {
    $os         = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $uptimeDays = [System.Math]::Round(
        ([System.DateTime]::Now - $os.LastBootUpTime).TotalDays, 2
    )
} catch {
    Write-Log "SKIP: Guard2 ERROR — could not read Win32_OperatingSystem: $($_.Exception.Message)"
    exit 0
}
$uptimeOk = ($uptimeDays -ge $MIN_UPTIME_DAYS)
Write-Log "Guard2  uptimeDays=$uptimeDays  uptimeOk=$uptimeOk  (min=$MIN_UPTIME_DAYS)"
if (-not $uptimeOk) {
    Write-Log "SKIP: Guard2 FAIL — uptime ${uptimeDays}d < ${MIN_UPTIME_DAYS} days"
    exit 0
}
Write-Log 'Guard2 PASS'

# ---------------------------------------------------------------------------
# Guard 3 — Kill-switch flag absent
# ---------------------------------------------------------------------------
$disableOk = (-not [System.IO.File]::Exists($DISABLE_FLAG))
Write-Log "Guard3  disableFlagExists=$(-not $disableOk)  disableOk=$disableOk"
if (-not $disableOk) {
    Write-Log "SKIP: Guard3 FAIL — HYGIENE_REBOOT_DISABLED.flag present at $DISABLE_FLAG"
    exit 0
}
Write-Log 'Guard3 PASS'

# ---------------------------------------------------------------------------
# Guard 4 — Debounce: last hygiene reboot > 3 days ago (or no prior record)
# ---------------------------------------------------------------------------
$debounceOk = $true
if ([System.IO.File]::Exists($STATE_FILE)) {
    try {
        $stateRaw  = [System.IO.File]::ReadAllText($STATE_FILE, [System.Text.Encoding]::UTF8)
        $stateObj  = $stateRaw | ConvertFrom-Json
        $lastTsRaw = $stateObj.ts
        if ($lastTsRaw) {
            $lastReboot = [System.DateTimeOffset]::Parse(
                $lastTsRaw,
                [System.Globalization.CultureInfo]::InvariantCulture
            ).UtcDateTime
            $daysSince  = [System.Math]::Round(
                ([System.DateTime]::UtcNow - $lastReboot).TotalDays, 2
            )
            $debounceOk = ($daysSince -gt $DEBOUNCE_DAYS)
            Write-Log "Guard4  lastReboot=$lastTsRaw  daysSince=$daysSince  debounceOk=$debounceOk  (min=${DEBOUNCE_DAYS}d)"
        } else {
            Write-Log 'Guard4  state file has no ts field — debounce passes'
        }
    } catch {
        Write-Log "Guard4  state parse error — treating as absent (safe/pass): $($_.Exception.Message)"
    }
} else {
    Write-Log 'Guard4  no prior state file — debounce passes (first run)'
}
if (-not $debounceOk) {
    Write-Log "SKIP: Guard4 FAIL — last hygiene reboot was < ${DEBOUNCE_DAYS} days ago"
    exit 0
}
Write-Log 'Guard4 PASS'

# ---------------------------------------------------------------------------
# ALL GUARDS PASSED — arm the reboot
# ---------------------------------------------------------------------------
Write-Log 'ALL 4 guards PASSED — proceeding with weekly hygiene reboot'

# Write state JSON BEFORE issuing the reboot command so it persists on disk
# even if Restart-Computer returns before the write completes. Keep the previous
# state so a FAILED reboot attempt can restore it (otherwise the debounce would
# treat the failure as a success and block retries for 3 days).
$prevStateRaw = $null
try { if ([System.IO.File]::Exists($STATE_FILE)) { $prevStateRaw = [System.IO.File]::ReadAllText($STATE_FILE, [System.Text.Encoding]::UTF8) } } catch { }
$newState = [ordered]@{
    ts          = [System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    uptime_days = $uptimeDays
    reason      = 'weekly_hygiene'
}
try {
    $json = ConvertTo-Json -InputObject $newState -Compress
    [System.IO.File]::WriteAllText($STATE_FILE, $json, [System.Text.Encoding]::UTF8)
    Write-Log "State written: $STATE_FILE"
} catch {
    Write-Log "WARNING: could not write state file (non-fatal): $($_.Exception.Message)"
}

# Windows Event Log entry (best-effort; event source creation may fail if already exists
# from another session — that is harmless)
try {
    $src = 'QM_HygieneReboot'
    if (-not [System.Diagnostics.EventLog]::SourceExists($src)) {
        [System.Diagnostics.EventLog]::CreateEventSource($src, 'Application')
    }
    Write-EventLog -LogName Application -Source $src -EventId 9000 -EntryType Information `
        -Message "QuantMechanica weekly hygiene reboot. uptime_days=$uptimeDays state=$STATE_FILE"
    Write-Log 'Windows event written (Application log, Source=QM_HygieneReboot, EventId=9000)'
} catch {
    Write-Log "WARNING: event log write failed (non-fatal): $($_.Exception.Message)"
}

Write-Log 'Issuing Restart-Computer -Force — goodbye'
try {
    Restart-Computer -Force -ErrorAction Stop
    # If we are still alive a few seconds later, the call was accepted; nothing to do.
    Start-Sleep -Seconds 30
} catch {
    # Deep LSM degradation can break even local restarts (RPC 1722). Try the native
    # fallback once, then restore the previous state so the debounce does NOT count
    # this failed attempt as a completed reboot.
    Write-Log "ERROR: Restart-Computer failed: $($_.Exception.Message) — trying shutdown.exe fallback"
    & "$env:SystemRoot\System32\shutdown.exe" /r /t 30 /f /c "QM weekly hygiene reboot (fallback)" 2>&1 |
        ForEach-Object { Write-Log "shutdown.exe: $_" }
    Start-Sleep -Seconds 60
    # Still alive -> both mechanisms failed (provider-panel reset required).
    Write-Log 'CRITICAL: reboot NOT executed (Restart-Computer AND shutdown.exe failed) — restoring previous state; provider-panel reset required'
    try {
        if ($null -ne $prevStateRaw) {
            [System.IO.File]::WriteAllText($STATE_FILE, $prevStateRaw, [System.Text.Encoding]::UTF8)
        } elseif ([System.IO.File]::Exists($STATE_FILE)) {
            [System.IO.File]::Delete($STATE_FILE)
        }
    } catch { Write-Log "WARNING: state restore failed: $($_.Exception.Message)" }
}
