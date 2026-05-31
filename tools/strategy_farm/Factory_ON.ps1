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
#    - enables the Pump / Tick scheduled tasks
#    - enables the AI scheduled tasks (AgentRouter, Codex, Gemini, Claude,
#      QuotaReceiver)
#    - kills any lingering daemons + terminals (clean slate)
#    - spawns the 10 terminal_worker.py daemons IN THIS SESSION
#      (visible mode) via start_terminal_workers.py
#    - runs `farmctl.py repair` ONCE synchronously in this session
#      (replaces the old Repair_Hourly recurring task)
#    - triggers one Pump cycle to start dispatching
#
#  The TerminalWorkers_AT_STARTUP scheduled task is permanently
#  disabled - it spawned daemons as SYSTEM / session-0 (headless).
#  The Repair_Hourly scheduled task is ALSO permanently disabled
#  (OWNER call 2026-05-23): it spawned worker daemons as SYSTEM after
#  a crash if the task state survived as Enabled - same session-0
#  violation. Repair work now runs once on Factory_ON instead.
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

# 1. enable dispatch + AI tasks (NOT TerminalWorkers_AT_STARTUP, NOT
#    Repair_Hourly - both spawn daemons as SYSTEM/session-0 which is
#    headless. Daemons spawned directly in this session below; repair
#    runs once synchronously below).
$dispatchTasks = @(
    'QM_StrategyFarm_Pump_5min',
    'QM_StrategyFarm_Tick_5min'
)
$aiTasks = @(
    'QM_StrategyFarm_AgentRouter_5min',
    'QM_StrategyFarm_CodexOrchestration_15min',
    'QM_StrategyFarm_GeminiOrchestration_15min',
    'QM_StrategyFarm_ClaudeOrchestration_15min',
    'QM_StrategyFarm_QuotaReceiver'
)
foreach ($t in @($dispatchTasks + $aiTasks)) {
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

# 4. run farmctl repair ONCE synchronously in this session (replaces the
#    old Repair_Hourly recurring task which spawned session-0 daemons
#    after a crash). Repair cleans stale work_item claims, resets
#    timed-out items, etc. Worker daemons are already up from step 3,
#    so any spawn behavior inside repair is a no-op.
Write-Host '  running farmctl repair (one-shot, this session) ...'
& $py 'C:\QM\repo\tools\strategy_farm\farmctl.py' repair | Out-Null
Write-Host '  farmctl repair done'

# 5. trigger one Pump cycle to start dispatching
Start-ScheduledTask -TaskName 'QM_StrategyFarm_QuotaReceiver' -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName 'QM_StrategyFarm_AgentRouter_5min' -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue
Write-Host '  AI router/quota receiver started; pump triggered (dispatching queued backtests)'

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
