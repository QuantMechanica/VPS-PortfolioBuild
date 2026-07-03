# =====================================================================
#  QuantMechanica - TestWindow OFF (full quiesce for ad-hoc backtests)
#  Rule 12 (OPERATING_RULES_2026-07-03): Factory_OFF + watchdog/FactoryON/
#  Reconciler disabled + codex_parallel=0 + kill stray run_smoke wrappers.
#  The post-run pump hook of every run_smoke fire would otherwise resurrect
#  the factory (07-02 resurrection-chain incident).
#
#  This script wraps Factory_OFF.ps1 and adds:
#    (a) Verify quiesce completeness and print a checklist
#    (b) Kill stray pythonw run_pump_task.py spawns from earlier run_smoke fires
#
#  Restore with TestWindow_ON.ps1 when the test window is done.
# =====================================================================

param([switch]$NoPause)

$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $reArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
    if ($NoPause) { $reArgs += '-NoPause' }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $reArgs
    exit
}

$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host '=====================================================' -ForegroundColor Magenta
Write-Host '  QuantMechanica  -  TEST WINDOW OFF (full quiesce)' -ForegroundColor Magenta
Write-Host '=====================================================' -ForegroundColor Magenta
Write-Host '  Rule 12: Factory_OFF + respawn tasks disabled + codex_parallel=0' -ForegroundColor Magenta
Write-Host '  Restoring: run TestWindow_ON.ps1' -ForegroundColor Magenta
Write-Host ''

# Step 1: Run Factory_OFF (disables FACTORY+AI+RESPAWN tasks, kills daemons/terminals,
#         kills run_smoke wrappers, saves codex_parallel, writes FACTORY_OFF.flag).
Write-Host '  Step 1: Factory_OFF ...'
& (Join-Path $PSScriptRoot 'Factory_OFF.ps1') -NoPause:$true  # Factory_OFF.ps1 doesn't have -NoPause but it won't be shown interactively
Write-Host '  Factory_OFF complete.'
Write-Host ''

# Step 2: Kill any residual pythonw run_pump_task.py spawns that may have been
#         triggered by run_smoke wrappers that completed just before the kill.
$pumpSpawns = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandLine -match 'run_pump_task\.py' })
foreach ($p in $pumpSpawns) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host ("  Step 2: residual run_pump_task.py spawns killed: {0}" -f $pumpSpawns.Count)
Write-Host ''

# Step 3: Print quiesce verification checklist.
Write-Host '  Step 3: Quiesce verification' -ForegroundColor Cyan
$flagPath = 'D:\QM\strategy_farm\state\FACTORY_OFF.flag'
$cpPath   = 'D:\QM\strategy_farm\state\codex_parallel.txt'

$checks = @(
    @{ Name='FACTORY_OFF.flag'; OK=(Test-Path $flagPath); Expected='present' },
    @{ Name='codex_parallel=0';
       OK=((Get-Content $cpPath -ErrorAction SilentlyContinue).Trim() -eq '0');
       Expected='0' },
    @{ Name='terminal_worker daemons=0';
       OK=(@(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -match 'terminal_worker\.py' }).Count -eq 0);
       Expected='0 running' },
    @{ Name='terminal64 (non-T_Live)=0';
       OK=(@(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -notmatch 'T_Live' }).Count -eq 0);
       Expected='0 running' },
    @{ Name='run_smoke wrappers=0';
       OK=(@(Get-CimInstance Win32_Process -Filter "Name='pwsh.exe' OR Name='powershell.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -match [regex]::Escape('framework\scripts\run_smoke.ps1') }).Count -eq 0);
       Expected='0 running' },
    @{ Name='run_pump_task spawns=0';
       OK=(@(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -match 'run_pump_task\.py' }).Count -eq 0);
       Expected='0 running' }
)

$allOK = $true
foreach ($c in $checks) {
    $mark = if ($c.OK) { '[OK]' } else { '[FAIL]' }
    $color = if ($c.OK) { 'Green' } else { 'Red' }
    Write-Host ("  {0,-8} {1}" -f $mark, $c.Name) -ForegroundColor $color
    if (-not $c.OK) { $allOK = $false }
}
Write-Host ''

if ($allOK) {
    Write-Host '  QUIESCE COMPLETE. Factory fully stopped. Run_smoke can now run without resurrection.' -ForegroundColor Green
} else {
    Write-Host '  WARNING: Some checks failed. Review the output above before running ad-hoc backtests.' -ForegroundColor Red
}
Write-Host ''
Write-Host '  Restore with: TestWindow_ON.ps1'
Write-Host ''
if (-not $NoPause) { Read-Host 'Press Enter to close' }
