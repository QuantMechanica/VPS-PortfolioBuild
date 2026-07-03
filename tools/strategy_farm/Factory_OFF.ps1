# =====================================================================
#  QuantMechanica - Factory OFF
#  Stops the MT5 backtest factory cleanly. Task lifecycle is driven by the
#  canonical manifest qm_tasks.manifest.ps1:
#    FACTORY + AI    -> stopped + disabled (the respawn vectors)
#    ALWAYS_ON       -> LEFT ALONE (dashboards, health, gmail alarm, morning
#                       brief, public snapshot, housekeeping keep running)
#    ENFORCE_DISABLED-> left disabled (Repair_Hourly, TerminalWorkers)
#  Plus: kills the 10 terminal_worker.py daemons + transient terminal64.exe.
#  Existing manually-started AI shells are not killed.
#
#  -NoPause : skip the trailing "Press Enter to close" prompt. Used when
#             called from TestWindow_OFF.ps1 or other wrapper scripts.
# =====================================================================

param([switch]$NoPause)

# --- self-elevate to Administrator ---
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $reArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
    if ($NoPause) { $reArgs += '-NoPause' }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $reArgs
    exit
}

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'qm_tasks.manifest.ps1')

$factoryOffFlagPath = 'D:\QM\strategy_farm\state\FACTORY_OFF.flag'
$codexParallelPath  = 'D:\QM\strategy_farm\state\codex_parallel.txt'

# Resurrection-vector tasks: NOT in FACTORY/AI manifest lists but can restart the
# factory autonomously after a plain OFF. Disabled here; re-enabled by Factory_ON.
$QM_RESPAWN_TASKS = @(
    'QM_StrategyFarm_FactoryWatchdog_15min',
    'QM_StrategyFarm_FactoryON_AtLogon',
    'QM_StrategyFarm_ReconcileOrphans_Hourly'
)

Write-Host ''
Write-Host '=====================================================' -ForegroundColor Yellow
Write-Host '  QuantMechanica  -  FACTORY OFF' -ForegroundColor Yellow
Write-Host '=====================================================' -ForegroundColor Yellow
Write-Host ''

# 1. stop + disable the FACTORY + AI tasks (stop the respawn vectors).
#    ALWAYS_ON tasks are deliberately NOT touched - you still get the
#    morning brief, dashboards, health and gmail alarm with the factory off.
foreach ($t in @($QM_FACTORY_TASKS + $QM_AI_TASKS)) {
    Stop-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
    $st = (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue).State
    Write-Host ("  task disabled : {0,-42} [{1}]" -f $t, $st)
}

# 1b. Disable resurrection-vector tasks (watchdog, auto-logon restart, reconciler).
Write-Host ''
Write-Host '  [RESPAWN GUARD] disabling resurrection-vector tasks' -ForegroundColor Yellow
foreach ($t in $QM_RESPAWN_TASKS) {
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
$terms = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
           Where-Object { $_.CommandLine -notmatch 'T_Live' })   # never kill the LIVE terminal (T_Live isolation hard rule)
foreach ($p in $terms) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host ("  terminal64.exe killed : {0} (T_Live excluded)" -f $terms.Count)

# 4. kill stray run_smoke wrapper pwsh processes (path-anchored; never T_Live)
#    run_smoke post-run triggers pump_task.py; kill the wrappers so the pump
#    resurrection chain (run_smoke -> run_pump_task -> farmctl pump) cannot fire.
$runSmokePath = 'framework\scripts\run_smoke.ps1'
$smokeWrappers = @(Get-CimInstance Win32_Process -Filter "Name='pwsh.exe' OR Name='powershell.exe'" -ErrorAction SilentlyContinue |
                   Where-Object { $_.CommandLine -match [regex]::Escape($runSmokePath) -and $_.CommandLine -notmatch 'T_Live' })
foreach ($p in $smokeWrappers) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host ("  run_smoke wrappers killed : {0}" -f $smokeWrappers.Count)

Start-Sleep -Seconds 3
$leftDaemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe'" -ErrorAction SilentlyContinue |
                 Where-Object { $_.CommandLine -match 'terminal_worker\.py' }).Count
$leftTerms   = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
                 Where-Object { $_.CommandLine -notmatch 'T_Live' }).Count

# 5. Save pre-OFF codex_parallel; set to 0 during OFF window.
$codexParallelBefore = '1'
try { $codexParallelBefore = (Get-Content $codexParallelPath -ErrorAction Stop).Trim() } catch {}
Set-Content -Path $codexParallelPath -Value '0' -Encoding ASCII -ErrorAction SilentlyContinue
Write-Host ("  codex_parallel: {0} -> 0 (saved in flag file)" -f $codexParallelBefore)

# 6. Write FACTORY_OFF.flag (software interlock for pump/watchdog/sweep_enqueue/run_smoke).
$flagJson = [ordered]@{
    off_at               = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    codex_parallel_before = $codexParallelBefore
} | ConvertTo-Json -Compress
Set-Content -Path $factoryOffFlagPath -Value $flagJson -Encoding UTF8
Write-Host ("  FACTORY_OFF.flag written: {0}" -f $factoryOffFlagPath)

Write-Host ''
if ($leftDaemons -eq 0 -and $leftTerms -eq 0) {
    Write-Host '  FACTORY STOPPED - 0 worker daemons, 0 terminals.' -ForegroundColor Green
} else {
    Write-Host ("  WARNING: still running - daemons={0} terminals={1}" -f $leftDaemons,$leftTerms) -ForegroundColor Red
    Write-Host '  Re-run this script, or check Task Scheduler.' -ForegroundColor Red
}
Write-Host ''
Write-Host '  Factory + AI tasks disabled. Resurrection-vector tasks disabled.'
Write-Host '  Always-on tasks (dashboards, health, gmail alarm, morning brief, snapshot, housekeeping) keep running.'
Write-Host '  FACTORY_OFF.flag blocks pump/watchdog/sweep_enqueue/run_smoke post-run hook.'
Write-Host '  Existing manually-started AI shells are not killed.'
Write-Host ''

# 7. Print remaining-active automation (ALWAYS_ON tasks that continue running).
Write-Host '  Still running (always-on, intentional):' -ForegroundColor Cyan
foreach ($t in $QM_ALWAYSON_TASKS) {
    $st = (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue).State
    if ($st -and $st -ne 'Disabled') { Write-Host ("    {0,-42} [{1}]" -f $t, $st) }
}
Write-Host ''
if (-not $NoPause) { Read-Host 'Press Enter to close' }
