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
# =====================================================================

# --- self-elevate to Administrator ---
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs `
        -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
    exit
}

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'qm_tasks.manifest.ps1')

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
Write-Host '  Factory + AI tasks disabled. Always-on tasks (dashboards, health,'
Write-Host '  gmail alarm, morning brief, snapshot, housekeeping) keep running.'
Write-Host '  Existing manually-started AI shells are not killed.'
Write-Host ''
Read-Host 'Press Enter to close'
