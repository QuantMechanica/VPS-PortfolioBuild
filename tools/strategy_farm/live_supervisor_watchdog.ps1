<#
.SYNOPSIS
  SYSTEM-context watchdog for the interactive live-terminal session supervisor.

.DESCRIPTION
  Forensics 2026-07-25: the resident QM_Live_MT5_SessionSupervisor (Interactive
  task, session 1) died silently at an RDP disconnect on Fri 2026-07-24 14:51
  and NOTHING could revive it for ~23h — RestartCount only arms on failed
  exits (all exits were RC=0), the At-Logon trigger never re-fires on
  reconnects, and Interactive-task launches can be queued while the session is
  disconnected. The FTMO terminal stayed dead unattended for the whole window.

  This watchdog runs as SYSTEM ("run whether user is logged on or not"), so it
  is immune to session/connection state. It NEVER touches a terminal and NEVER
  kills anything. It only checks two signals and, when both say the supervisor
  is gone, kicks the supervisor task so the interactive machinery relaunches:

    1. state-file age:  D:\QM\reports\state\live_session_supervisor.json
                        (the resident writes it every ~10s cycle)
    2. process probe:   a powershell.exe whose command line contains
                        Live_MT5_SessionSupervisor

  Fail-closed: probe errors count as "unknown", and unknown NEVER kicks —
  only positive evidence of absence (stale file AND no process) does.
  LIVE_UPTIME_MAINTENANCE.flag suppresses kicks entirely.

  Scheduled: QM_LiveSupervisor_Watchdog_SYSTEM (SYSTEM, every 5 min).
  PS5.1-safe by doctrine: ErrorActionPreference=Continue, no 2>&1 traps.
#>
[CmdletBinding()]
param(
    [ValidateRange(60, 3600)][int]$StaleSeconds = 300
)

$ErrorActionPreference = 'Continue'

$stateFile = 'D:\QM\reports\state\live_session_supervisor.json'
$logFile = 'D:\QM\reports\state\live_supervisor_watchdog.log'
$maintenanceFlag = 'D:\QM\reports\state\LIVE_UPTIME_MAINTENANCE.flag'
$supervisorTask = 'QM_Live_MT5_SessionSupervisor'

function Write-Log {
    param([string]$Message)
    $line = "$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')) $Message"
    try { Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8 } catch { }
}

if (Test-Path -LiteralPath $maintenanceFlag -PathType Leaf) {
    Write-Log 'skip maintenance_flag_present'
    exit 0
}

# Signal 1: state-file age (resident writes every ~10s).
$stateAgeSec = $null
try {
    $item = Get-Item -LiteralPath $stateFile -ErrorAction Stop
    $stateAgeSec = [int]([DateTime]::UtcNow - $item.LastWriteTimeUtc).TotalSeconds
} catch {
    $stateAgeSec = $null   # unknown (file missing/unreadable)
}

# Signal 2: resident process present?
$procKnown = $false
$procPresent = $false
try {
    $matches = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction Stop |
        Where-Object { $_.CommandLine -match 'Live_MT5_SessionSupervisor' })
    $procKnown = $true
    $procPresent = @($matches).Count -gt 0
} catch {
    $procKnown = $false
}

$stale = ($stateAgeSec -ne $null) -and ($stateAgeSec -gt $StaleSeconds)
$fileMissing = ($stateAgeSec -eq $null)

if ($procKnown -and $procPresent -and -not $stale) {
    # Healthy — stay silent (no log spam every 5 min).
    exit 0
}
if (-not $procKnown) {
    Write-Log "no-action probe_unknown state_age=$stateAgeSec"
    exit 0
}
if ($procPresent) {
    # Process alive but state stale — resident may be wedged mid-cycle; kicking
    # would be refused by its mutex anyway (IgnoreNew). Log for the trail.
    Write-Log "observe process_alive_but_state_stale state_age=$stateAgeSec"
    exit 0
}

# Positive evidence: no resident process AND (stale or missing state file).
if ($stale -or $fileMissing) {
    try {
        Start-ScheduledTask -TaskName $supervisorTask -ErrorAction Stop
        Write-Log "kicked $supervisorTask state_age=$stateAgeSec file_missing=$fileMissing"
    } catch {
        Write-Log "kick_failed $supervisorTask error=$($_.Exception.Message)"
    }
} else {
    # Process absent but state file still fresh (<StaleSeconds): the resident
    # died within the last few minutes — next run decides. No premature kick.
    Write-Log "wait process_absent_but_state_fresh state_age=$stateAgeSec"
}
exit 0
