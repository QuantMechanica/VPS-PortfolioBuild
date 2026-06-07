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
#  Task lifecycle is driven by the canonical manifest qm_tasks.manifest.ps1:
#    FACTORY + AI       -> enabled + started here
#    ALWAYS_ON          -> ENSURED enabled (morning brief, dashboards,
#                          health, gmail alarm, public snapshot, housekeeping)
#                          so nothing silently stays off after a reboot
#    ENFORCE_DISABLED   -> force-disabled (session-0 respawn hazards:
#                          Repair_Hourly, TerminalWorkers_AT_STARTUP)
#  Plus: spawns the 10 terminal_worker.py daemons IN THIS SESSION and runs
#  `farmctl.py repair` ONCE synchronously (replaces the old recurring
#  Repair_Hourly task, which spawned SYSTEM/session-0 daemons).
# =====================================================================
#
#  -NoPause : skip the trailing "Press Enter to close" prompt. Used by the
#             QM_StrategyFarm_FactoryON_AtLogon task (autologon console
#             session) so the run completes unattended instead of hanging
#             on Read-Host. Manual desktop double-clicks omit it, keeping
#             the window open to read.
# =====================================================================

param([switch]$NoPause)

# self-elevate
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $reArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
    if ($NoPause) { $reArgs += '-NoPause' }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $reArgs
    exit
}

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'qm_tasks.manifest.ps1')

$mySession = (Get-Process -Id $PID).SessionId
Write-Host ''
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ("  QuantMechanica  -  FACTORY ON  (session {0}, visible)" -f $mySession) -ForegroundColor Cyan
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ''

# 1. enable + (re)start the FACTORY + AI tasks
Write-Host '  [FACTORY + AI] enable + start' -ForegroundColor Cyan
foreach ($t in @($QM_FACTORY_TASKS + $QM_AI_TASKS)) {
    Enable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
    $st = (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue).State
    Write-Host ("    enabled : {0,-42} [{1}]" -f $t, $st)
}
Write-Host ''

# 2. ALWAYS-ON support: make sure these are enabled (they run on their own
#    schedule and are NOT torn down by Factory OFF). This is the safety net
#    so a reboot / accidental disable can never silently kill the morning
#    brief, dashboards, health, gmail alarm, snapshot, or housekeeping.
Write-Host '  [ALWAYS-ON] ensure enabled (left running by Factory OFF)' -ForegroundColor Green
$alwaysFixed = 0
foreach ($t in $QM_ALWAYSON_TASKS) {
    $task = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($null -eq $task) { Write-Host ("    MISSING : {0}" -f $t) -ForegroundColor Yellow; continue }
    if ($task.State -eq 'Disabled') {
        Enable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
        $alwaysFixed++
        Write-Host ("    re-enabled : {0}" -f $t) -ForegroundColor Yellow
    }
}
Write-Host ("    {0}/{1} always-on tasks enabled ({2} re-enabled)" -f `
    (@($QM_ALWAYSON_TASKS | ForEach-Object { (Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue).State } | Where-Object { $_ -ne 'Disabled' }).Count), `
    $QM_ALWAYSON_TASKS.Count, $alwaysFixed)
Write-Host ''

# 3. ENFORCE-DISABLED: kill session-0 respawn hazards if they drifted on
$drift = 0
foreach ($t in $QM_ENFORCE_DISABLED_TASKS) {
    $task = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($task -and $task.State -ne 'Disabled') {
        Stop-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
        Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
        $drift++
        Write-Host ("  [HAZARD] force-disabled drifted task: {0}" -f $t) -ForegroundColor Red
    }
}
if ($drift -eq 0) { Write-Host '  [HAZARD] respawn-hazard tasks verified disabled (0 drift)' }
Write-Host ''

# 4. kill any lingering daemons + terminals (clean slate, regardless of session)
$daemonsBefore = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
                   Where-Object { $_.CommandLine -match 'terminal_worker\.py' })
foreach ($d in $daemonsBefore) { Stop-Process -Id $d.ProcessId -Force -ErrorAction SilentlyContinue }
$termsBefore = @(Get-Process terminal64 -ErrorAction SilentlyContinue)
foreach ($p in $termsBefore) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
if ($daemonsBefore.Count -gt 0 -or $termsBefore.Count -gt 0) {
    Write-Host ("  cleared: {0} old daemon(s), {1} old terminal(s)" -f $daemonsBefore.Count, $termsBefore.Count)
    Start-Sleep -Seconds 2
}

# 5. spawn the 10 worker daemons IN THIS interactive session
Write-Host '  spawning T1-T10 worker daemons in your session (visible mode) ...'
$py = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
& $py 'C:\QM\repo\tools\strategy_farm\start_terminal_workers.py' --repo-root 'C:\QM\repo' --farm-root 'D:\QM\strategy_farm' --dedupe | Out-Null
Start-Sleep -Seconds 12

$daemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -match 'terminal_worker\.py' })
$inMySession = @($daemons | Where-Object { $_.SessionId -eq $mySession })
Write-Host ("  worker daemons up : {0} / 10  (in session {1}: {2})" -f $daemons.Count, $mySession, $inMySession.Count)

# 6. run farmctl repair ONCE synchronously (replaces recurring Repair_Hourly)
Write-Host '  running farmctl repair (one-shot, this session) ...'
& $py 'C:\QM\repo\tools\strategy_farm\farmctl.py' repair | Out-Null
Write-Host '  farmctl repair done'

# 7. trigger one Pump cycle to start dispatching
Start-ScheduledTask -TaskName 'QM_StrategyFarm_QuotaPull' -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName 'QM_StrategyFarm_AgentRouter_5min' -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue
Write-Host '  AI router/quota pull started; pump triggered (dispatching queued backtests)'

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
Write-Host '        Always-on tasks (dashboards/health/brief/alarm) keep running regardless.'
Write-Host '        After a reboot, log in via RDP and click this shortcut again.'
Write-Host ''
if (-not $NoPause) { Read-Host 'Press Enter to close' }
