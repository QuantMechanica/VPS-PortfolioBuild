# =====================================================================
#  QuantMechanica - Factory OFF
#  Stops the MT5 backtest factory cleanly. Task lifecycle is driven by the
#  canonical manifest qm_tasks.manifest.ps1:
#    FACTORY + AI    -> stopped + disabled (the respawn vectors)
#    ALWAYS_ON       -> LEFT ALONE (dashboards, health, reboot diagnostics,
#                       morning brief, public snapshot, housekeeping keep running)
#    ENFORCE_DISABLED-> left disabled (Repair_Hourly, TerminalWorkers)
#  Plus: kills the 10 terminal_worker.py daemons + transient terminal64.exe.
#  Existing manually-started AI shells are not killed.
# =====================================================================

# --- self-elevate to Administrator ---
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs `
        -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
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
    foreach ($requiredFunction in @(
        'Test-QmFactoryMt5ImagePath',
        'Test-QmFactoryWorkerCommandLine',
        'Test-QmFactoryRunSmokeCommandLine'
    )) {
        if (-not (Get-Command -Name $requiredFunction -CommandType Function -ErrorAction SilentlyContinue)) {
            throw "Process-scope guard lacks required function: $requiredFunction"
        }
    }
} catch {
    throw "FACTORY OFF ABORTED before mutation: process-scope guard failed: $($_.Exception.Message)"
}
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
#    morning brief, dashboards, health and reboot diagnostics with the factory off.
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

# 2. Kill only positively identified T1..T10 terminal_worker.py daemons.
$daemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
             Where-Object { Test-QmFactoryWorkerCommandLine -CommandLine $_.CommandLine })
foreach ($d in $daemons) { Stop-Process -Id $d.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host ("  worker daemons killed : {0}" -f $daemons.Count)

# 3. Kill run_smoke wrappers before their terminal children. Reversing this order
#    leaves a race where a wrapper spawns another terminal after the first sweep.
#    The classifier requires the fixed runner plus T1..T10 (or a UUID-bound
#    factory work-item dispatch); DEV1/DEV2 wrappers cannot match.
$smokeWrappers = @(Get-CimInstance Win32_Process -Filter "Name='pwsh.exe' OR Name='powershell.exe'" -ErrorAction SilentlyContinue |
                   Where-Object { Test-QmFactoryRunSmokeCommandLine -CommandLine $_.CommandLine })
foreach ($p in $smokeWrappers) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host ("  run_smoke wrappers killed : {0}" -f $smokeWrappers.Count)
Start-Sleep -Seconds 2

# 4. kill transient terminal64.exe backtest processes
#    POSITIVE exact-image anchor: only D:\QM\mt5\T1..T10\terminal64.exe.
#    DEV1/DEV2, T_Live, T_Export, and unrelated terminals fail closed.
$terms = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
           Where-Object { Test-QmFactoryMt5ImagePath -Path $_.ExecutablePath -ImageName 'terminal64.exe' })
foreach ($p in $terms) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host ("  terminal64.exe killed : {0} (exact T1..T10 image paths only)" -f $terms.Count)

# 4b. kill orphaned/local tester agents under factory roots. A killed terminal can
#     otherwise leave metatester64.exe holding the terminal profile during an OFF window.
$metaTesters = @(Get-CimInstance Win32_Process -Filter "Name='metatester64.exe'" -ErrorAction SilentlyContinue |
                 Where-Object { Test-QmFactoryMt5ImagePath -Path $_.ExecutablePath -ImageName 'metatester64.exe' })
foreach ($p in $metaTesters) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host ("  metatester64.exe killed : {0} (exact T1..T10 image paths only)" -f $metaTesters.Count)

Start-Sleep -Seconds 3
$leftDaemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
                 Where-Object { Test-QmFactoryWorkerCommandLine -CommandLine $_.CommandLine }).Count
$leftTerms   = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
                 Where-Object { Test-QmFactoryMt5ImagePath -Path $_.ExecutablePath -ImageName 'terminal64.exe' }).Count
$leftMeta    = @(Get-CimInstance Win32_Process -Filter "Name='metatester64.exe'" -ErrorAction SilentlyContinue |
                 Where-Object { Test-QmFactoryMt5ImagePath -Path $_.ExecutablePath -ImageName 'metatester64.exe' }).Count

# 5. Save pre-OFF codex_parallel; repeated OFF calls preserve the original restore value.
$codexParallelBefore = '1'
if (Test-Path -LiteralPath $factoryOffFlagPath) {
    try {
        $existingOff = Get-Content -LiteralPath $factoryOffFlagPath -Raw -ErrorAction Stop | ConvertFrom-Json
        if ($null -ne $existingOff.codex_parallel_before) {
            $codexParallelBefore = [string]$existingOff.codex_parallel_before
        }
    } catch {}
} else {
    try { $codexParallelBefore = (Get-Content $codexParallelPath -ErrorAction Stop).Trim() } catch {}
}
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
if ($leftDaemons -eq 0 -and $leftTerms -eq 0 -and $leftMeta -eq 0) {
    Write-Host '  FACTORY STOPPED - 0 worker daemons, 0 terminals, 0 tester agents.' -ForegroundColor Green
} else {
    Write-Host ("  WARNING: still running - daemons={0} terminals={1} tester_agents={2}" -f $leftDaemons,$leftTerms,$leftMeta) -ForegroundColor Red
    Write-Host '  Re-run this script, or check Task Scheduler.' -ForegroundColor Red
}
Write-Host ''
Write-Host '  Factory + AI tasks disabled. Resurrection-vector tasks disabled.'
Write-Host '  Always-on tasks (dashboards, health, reboot diagnostics, morning brief, snapshot, housekeeping) keep running.'
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
Read-Host 'Press Enter to close'
