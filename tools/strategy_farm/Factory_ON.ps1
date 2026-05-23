# =====================================================================
#  QuantMechanica - Factory ON (interactive / visible mode)
#  Starts the MT5 backtest factory inside the CURRENT interactive session
#  so terminal64 windows are visible on the desktop.
#
#  Tradeoff vs the old session-0 model: the factory only runs while
#  this user session is alive. Disconnect (RDP) is fine - the session
#  stays active in the background. An explicit LOGOFF kills the session
#  and the factory dies with it. After a VPS reboot, log in via RDP and
#  click this shortcut to bring the factory back up.
#
#  What it does:
#    - enables the Pump / Tick / Repair scheduled tasks
#    - kills any lingering daemons + terminals (clean slate)
#    - spawns the 10 terminal_worker.py daemons IN THIS SESSION
#      (visible mode) via start_terminal_workers.py
#    - triggers one Pump cycle to start dispatching
#
#  The TerminalWorkers_AT_STARTUP scheduled task is permanently
#  disabled - it spawned daemons as SYSTEM / session-0 (headless).
# =====================================================================

# self-elevate
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs `
        -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
    exit
}

$ErrorActionPreference = 'Continue'
$mySession = (Get-Process -Id $PID).SessionId
Write-Host ''
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ("  QuantMechanica  -  FACTORY ON  (session {0}, visible)" -f $mySession) -ForegroundColor Cyan
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ''

# 1. enable dispatch/repair tasks (NOT TerminalWorkers_AT_STARTUP - that
#    task spawns daemons as SYSTEM/session-0 which is headless; we spawn
#    daemons directly in THIS session further below).
$tasks = @(
    'QM_StrategyFarm_Pump_5min',
    'QM_StrategyFarm_Tick_5min',
    'QM_StrategyFarm_Repair_Hourly'
)
foreach ($t in $tasks) {
    Enable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
    $st = (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue).State
    Write-Host ("  task enabled  : {0,-42} [{1}]" -f $t, $st)
}
Write-Host ''

# 2. kill any lingering daemons + terminals (clean slate, regardless of session)
$daemonsBefore = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
                   Where-Object { $_.CommandLine -match 'terminal_worker\.py' })
foreach ($d in $daemonsBefore) { Stop-Process -Id $d.ProcessId -Force -ErrorAction SilentlyContinue }
$termsBefore = @(Get-Process terminal64 -ErrorAction SilentlyContinue)
foreach ($p in $termsBefore) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
if ($daemonsBefore.Count -gt 0 -or $termsBefore.Count -gt 0) {
    Write-Host ("  cleared: {0} old daemon(s), {1} old terminal(s)" -f $daemonsBefore.Count, $termsBefore.Count)
    Start-Sleep -Seconds 2
}

# 3. spawn the 10 worker daemons IN THIS interactive session
Write-Host '  spawning T1-T10 worker daemons in your session (visible mode) ...'
$py = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
& $py 'C:\QM\repo\tools\strategy_farm\start_terminal_workers.py' --repo-root 'C:\QM\repo' --farm-root 'D:\QM\strategy_farm' --dedupe | Out-Null
Start-Sleep -Seconds 12

$daemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -match 'terminal_worker\.py' })
$inMySession = @($daemons | Where-Object { $_.SessionId -eq $mySession })
Write-Host ("  worker daemons up : {0} / 10  (in session {1}: {2})" -f $daemons.Count, $mySession, $inMySession.Count)

# 4. trigger one Pump cycle to start dispatching
Start-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue
Write-Host '  pump triggered (dispatching queued backtests)'

Write-Host ''
if ($inMySession.Count -ge 8) {
    Write-Host ("  FACTORY STARTED - {0}/10 daemons live in your session." -f $inMySession.Count) -ForegroundColor Green
    Write-Host '  terminal64 windows will appear on the desktop as backtests start.'
} else {
    Write-Host ("  PARTIAL START - only {0}/10 daemons in your session. Re-run if needed." -f $inMySession.Count) -ForegroundColor Yellow
}
Write-Host ''
Write-Host '  NOTE: The factory runs while this RDP session is alive (disconnect is OK).'
Write-Host '        An explicit LOGOFF kills the session and stops the factory.'
Write-Host '        After a reboot, log in via RDP and click this shortcut again.'
Write-Host ''
Read-Host 'Press Enter to close'
