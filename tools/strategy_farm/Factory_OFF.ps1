# =====================================================================
#  QuantMechanica - Factory OFF
#  Stops the MT5 backtest factory cleanly:
#    - disables Pump + Tick scheduled tasks (TerminalWorkers + Repair
#      are permanently disabled - see Factory_ON.ps1 header)
#    - disables and stops the AI scheduled tasks (AgentRouter, Codex,
#      Gemini, Claude, QuotaReceiver)
#    - kills the 10 terminal_worker.py daemons
#    - kills any transient terminal64.exe backtest processes
#  Dashboards, health checks, Gmail alarm, and morning brief are left alone.
# =====================================================================

# --- self-elevate to Administrator ---
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs `
        -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
    exit
}

$ErrorActionPreference = 'Continue'
Write-Host ''
Write-Host '=====================================================' -ForegroundColor Yellow
Write-Host '  QuantMechanica  -  FACTORY OFF' -ForegroundColor Yellow
Write-Host '=====================================================' -ForegroundColor Yellow
Write-Host ''

# 1. disable dispatch + AI scheduled tasks (stop the respawn vectors)
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
# TerminalWorkers_AT_STARTUP + Repair_Hourly are permanently disabled
# (interactive-mode policy 2026-05-23). Daemons are spawned by Factory_ON
# in the user's session; farmctl repair is invoked once by Factory_ON
# inline. Both used to be Enabled and spawn SYSTEM/session-0 workers
# after a crash - that's now eliminated by leaving them permanently off.
foreach ($t in @($dispatchTasks + $aiTasks)) {
    Stop-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
    $st = (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue).State
    Write-Host ("  task disabled : {0,-42} [{1}]" -f $t, $st)
}
Write-Host ''

# 2. kill the terminal_worker.py daemons
$daemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -match 'terminal_worker\.py' })
foreach ($d in $daemons) { Stop-Process -Id $d.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host ("  worker daemons killed : {0}" -f $daemons.Count)

# 3. kill transient terminal64.exe backtest processes
$terms = @(Get-Process terminal64 -ErrorAction SilentlyContinue)
foreach ($p in $terms) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
Write-Host ("  terminal64.exe killed : {0}" -f $terms.Count)

Start-Sleep -Seconds 3
$leftDaemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe'" -ErrorAction SilentlyContinue |
                 Where-Object { $_.CommandLine -match 'terminal_worker\.py' }).Count
$leftTerms   = @(Get-Process terminal64 -ErrorAction SilentlyContinue).Count

Write-Host ''
if ($leftDaemons -eq 0 -and $leftTerms -eq 0) {
    Write-Host '  FACTORY STOPPED - 0 worker daemons, 0 terminals.' -ForegroundColor Green
} else {
    Write-Host ("  WARNING: still running - daemons={0} terminals={1}" -f $leftDaemons,$leftTerms) -ForegroundColor Red
    Write-Host '  Re-run this script, or check Task Scheduler.' -ForegroundColor Red
}
Write-Host ''
Write-Host '  AI scheduled tasks are disabled. Existing manually-started AI shells are not killed.'
Write-Host ''
Read-Host 'Press Enter to close'
