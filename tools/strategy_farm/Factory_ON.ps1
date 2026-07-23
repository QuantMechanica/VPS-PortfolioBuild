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
#                          health, reboot diagnostics, public snapshot, housekeeping)
#                          so nothing silently stays off after a reboot
#    ENFORCE_DISABLED   -> force-disabled (unsafe paths and OWNER opt-outs)
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
$processScopePath = Join-Path $PSScriptRoot 'factory_process_scope.ps1'
try {
    $script:QmFactoryProcessScopeVersion = $null
    if (-not (Test-Path -LiteralPath $processScopePath -PathType Leaf)) {
        throw "Required process-scope guard is missing: $processScopePath"
    }
    . $processScopePath
    if ($script:QmFactoryProcessScopeVersion -ne 1) {
        throw 'Process-scope guard version mismatch.'
    }
    foreach ($requiredFunction in @('Test-QmFactoryMt5ImagePath', 'Test-QmFactoryWorkerCommandLine')) {
        if (-not (Get-Command -Name $requiredFunction -CommandType Function -ErrorAction SilentlyContinue)) {
            throw "Process-scope guard lacks required function: $requiredFunction"
        }
    }
} catch {
    throw "FACTORY ON ABORTED before mutation: process-scope guard failed: $($_.Exception.Message)"
}
. (Join-Path $PSScriptRoot 'qm_tasks.manifest.ps1')

$factoryOffFlagPath = 'D:\QM\strategy_farm\state\FACTORY_OFF.flag'
$codexParallelPath  = 'D:\QM\strategy_farm\state\codex_parallel.txt'
$watchdogResetBlockPath = 'D:\QM\strategy_farm\state\WATCHDOG_RESET_PENDING.json'

# Resurrection-vector tasks: disabled by Factory_OFF to prevent autonomous restart;
# re-enabled here so the watchdog/auto-logon/reconciler resume normal operation.
$QM_RESPAWN_TASKS = @(
    'QM_StrategyFarm_FactoryWatchdog_15min',
    'QM_StrategyFarm_FactoryON_AtLogon',
    'QM_StrategyFarm_ReconcileOrphans_Hourly'
)

# Operator concurrency cap awareness (2026-06-22). disabled_terminals.txt removes
# terminals (e.g. T8,T9,T10 for the RAM cap, commit 050829f9b) so the fleet is < 10.
# Derive the expected worker count from it; otherwise the fixed "/10" + ">= 8"
# success check mislabels a correct capped fleet (7) as "PARTIAL START 7/10".
$disabledTerminalsPath = 'D:\QM\strategy_farm\state\disabled_terminals.txt'
$disabledCount = 0
if (Test-Path $disabledTerminalsPath) {
    $disabledCount = @(Get-Content $disabledTerminalsPath -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match '^T(?:[1-9]|10)$' }).Count
}
$expectWorkers = [math]::Max(1, 10 - $disabledCount)

$mySession = (Get-Process -Id $PID).SessionId
Write-Host ''
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ("  QuantMechanica  -  FACTORY ON  (session {0}, visible)" -f $mySession) -ForegroundColor Cyan
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ''

# 0. Remove FACTORY_OFF.flag and restore codex_parallel before starting anything.
$codexParallelRestored = ''
if (Test-Path $factoryOffFlagPath) {
    try {
        $flagData = Get-Content $factoryOffFlagPath -Raw | ConvertFrom-Json
        $codexParallelRestored = $flagData.codex_parallel_before
    } catch {}
    Remove-Item -Path $factoryOffFlagPath -Force -ErrorAction SilentlyContinue
    Write-Host ("  FACTORY_OFF.flag removed: {0}" -f $factoryOffFlagPath)
} else {
    Write-Host '  FACTORY_OFF.flag not present (was already removed or never set)'
}
if ($codexParallelRestored -and $codexParallelRestored -match '^\d+$') {
    Set-Content -Path $codexParallelPath -Value $codexParallelRestored -Encoding ASCII -ErrorAction SilentlyContinue
    Write-Host ("  codex_parallel restored: {0}" -f $codexParallelRestored)
} else {
    Write-Host '  codex_parallel: no saved value in flag; leaving current value'
}
Write-Host ''

# 1. enable + (re)start the FACTORY + AI tasks
Write-Host '  [FACTORY + AI] enable + start' -ForegroundColor Cyan
foreach ($t in @($QM_FACTORY_TASKS + $QM_AI_TASKS)) {
    Enable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
    $st = (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue).State
    Write-Host ("    enabled : {0,-42} [{1}]" -f $t, $st)
}
Write-Host ''

# 1b. Re-enable resurrection-vector tasks.
Write-Host '  [RESPAWN TASKS] re-enable watchdog / auto-logon / reconciler' -ForegroundColor Cyan
foreach ($t in $QM_RESPAWN_TASKS) {
    Enable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
    $st = (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue).State
    Write-Host ("    enabled : {0,-42} [{1}]" -f $t, $st)
}
Write-Host ''

# 2. ALWAYS-ON support: make sure these are enabled (they run on their own
#    schedule and are NOT torn down by Factory OFF). This is the safety net
#    so a reboot / accidental disable can never silently kill the morning
#    brief, reboot diagnostics, dashboards, health, snapshot, or housekeeping.
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

# 4. Kill only positively identified T1..T10 daemons + terminals.
$daemonsBefore = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
                   Where-Object { Test-QmFactoryWorkerCommandLine -CommandLine $_.CommandLine })
foreach ($d in $daemonsBefore) { Stop-Process -Id $d.ProcessId -Force -ErrorAction SilentlyContinue }
$termsBefore = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
                 Where-Object { Test-QmFactoryMt5ImagePath -Path $_.ExecutablePath -ImageName 'terminal64.exe' })
foreach ($p in $termsBefore) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
if ($daemonsBefore.Count -gt 0 -or $termsBefore.Count -gt 0) {
    Write-Host ("  cleared: {0} old daemon(s), {1} old terminal(s)" -f $daemonsBefore.Count, $termsBefore.Count)
    Start-Sleep -Seconds 2
}

# A watchdog-triggered clean-slate handover blocks new SQLite claims before it
# starts this task. Existing workers and terminals are now gone, so release the
# admission block immediately before the replacement daemons are spawned.
try {
    if (Test-Path -LiteralPath $watchdogResetBlockPath -ErrorAction Stop) {
        Remove-Item -LiteralPath $watchdogResetBlockPath -Force -ErrorAction Stop
        if (Test-Path -LiteralPath $watchdogResetBlockPath -ErrorAction Stop) {
            throw 'marker still exists after removal'
        }
        Write-Host '  watchdog reset admission block cleared'
    }
} catch {
    throw "FACTORY ON ABORTED before worker spawn: cannot acknowledge watchdog reset handover: $($_.Exception.Message)"
}

# 5. spawn the 10 worker daemons IN THIS interactive session
Write-Host ("  spawning worker daemons in your session (visible mode, cap={0}) ..." -f $expectWorkers)
$py = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
& $py 'C:\QM\repo\tools\strategy_farm\start_terminal_workers.py' --repo-root 'C:\QM\repo' --farm-root 'D:\QM\strategy_farm' --dedupe | Out-Null
Start-Sleep -Seconds 12

$daemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
             Where-Object { Test-QmFactoryWorkerCommandLine -CommandLine $_.CommandLine })
$inMySession = @($daemons | Where-Object { $_.SessionId -eq $mySession })
Write-Host ("  worker daemons up : {0} / {1}  (in session {2}: {3})" -f $daemons.Count, $expectWorkers, $mySession, $inMySession.Count)

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
if ($inMySession.Count -ge $expectWorkers) {
    Write-Host ("  FACTORY STARTED - {0}/{1} daemons live in your session." -f $inMySession.Count, $expectWorkers) -ForegroundColor Green
    Write-Host '  terminal64 windows will appear on the desktop as backtests start.'
} else {
    Write-Host ("  PARTIAL START - only {0}/{1} daemons in your session. Re-run if needed." -f $inMySession.Count, $expectWorkers) -ForegroundColor Yellow
}
Write-Host ''

# 8. Warn about disabled_terminals entries beyond the standard T8-T10 RAM cap.
#    T8/T9/T10 are expected; entries outside that set suggest a temporary cap that
#    was never cleaned up and may silently reduce throughput below the worker target.
if (Test-Path $disabledTerminalsPath) {
    $extraDisabled = @(Get-Content $disabledTerminalsPath -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match '^T(?:[1-9]|10)$' -and $_ -notin @('T8','T9','T10') })
    if ($extraDisabled.Count -gt 0) {
        Write-Host ("  WARNING: disabled_terminals.txt contains {0} non-standard entr(y/ies): {1}" -f $extraDisabled.Count, ($extraDisabled -join ', ')) -ForegroundColor Yellow
        Write-Host '           Review D:\QM\strategy_farm\state\disabled_terminals.txt if throughput is below target.' -ForegroundColor Yellow
    }
}

Write-Host '  NOTE: The factory runs while this RDP session is alive (disconnect is OK).'
Write-Host '        An explicit LOGOFF kills the session and stops the factory.'
Write-Host '        Always-on tasks (dashboards/health/brief/alarm) keep running regardless.'
Write-Host '        After a reboot, log in via RDP and click this shortcut again.'
Write-Host ''
if (-not $NoPause) { Read-Host 'Press Enter to close' }
