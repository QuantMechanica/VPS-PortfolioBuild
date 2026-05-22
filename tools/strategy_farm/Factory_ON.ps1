# =====================================================================
#  QuantMechanica - Factory ON
#  Starts the MT5 backtest factory:
#    - enables the 4 farm scheduled tasks (Pump / Tick / TerminalWorkers
#      / Repair)
#    - triggers TerminalWorkers now -> spawns the 10 terminal_worker.py
#      daemons (they claim work_items and run backtests)
#    - triggers one Pump cycle to start dispatching
#  Run this after a clean VPS boot, or any time the factory was stopped.
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
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host '  QuantMechanica  -  FACTORY ON' -ForegroundColor Cyan
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ''

# 1. enable the farm scheduled tasks
$tasks = @(
    'QM_StrategyFarm_Pump_5min',
    'QM_StrategyFarm_Tick_5min',
    'QM_StrategyFarm_TerminalWorkers_AT_STARTUP',
    'QM_StrategyFarm_Repair_Hourly'
)
foreach ($t in $tasks) {
    Enable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
    $st = (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue).State
    Write-Host ("  task enabled  : {0,-42} [{1}]" -f $t, $st)
}
Write-Host ''

# 2. trigger TerminalWorkers now -> spawn the T1-T10 daemons
Write-Host '  starting terminal worker daemons (T1-T10) ...'
Start-ScheduledTask -TaskName 'QM_StrategyFarm_TerminalWorkers_AT_STARTUP' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 14
$daemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -match 'terminal_worker\.py' })
Write-Host ("  worker daemons up : {0} / 10" -f $daemons.Count)

# 3. trigger one Pump cycle to start dispatching work
Start-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue
Write-Host '  pump triggered (dispatching queued backtests)'

Write-Host ''
if ($daemons.Count -ge 8) {
    Write-Host ("  FACTORY STARTED - {0}/10 worker daemons live." -f $daemons.Count) -ForegroundColor Green
} else {
    Write-Host ("  PARTIAL START - only {0}/10 daemons. Wait 1 min and re-run," -f $daemons.Count) -ForegroundColor Yellow
    Write-Host '  the TerminalWorkers task also re-checks on its own schedule.' -ForegroundColor Yellow
}
Write-Host ''
Write-Host '  The factory now claims queued work_items and runs backtests.'
Write-Host '  Check progress: cockpit.html / dashboards, or farmctl health.'
Write-Host ''
Read-Host 'Press Enter to close'
