# =====================================================================
#  QuantMechanica - TestWindow ON (restore from full quiesce)
#  Reverses TestWindow_OFF: removes FACTORY_OFF.flag, restores codex_parallel,
#  re-enables all tasks (FACTORY+AI+RESPAWN), spawns workers, runs repair.
#  Pair with TestWindow_OFF.ps1.
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
Write-Host '  QuantMechanica  -  TEST WINDOW ON (restore)' -ForegroundColor Magenta
Write-Host '=====================================================' -ForegroundColor Magenta
Write-Host '  Restoring from TestWindow_OFF quiesce state.' -ForegroundColor Magenta
Write-Host ''

# Step 1: Verify we are actually in a test-window state.
$flagPath = 'D:\QM\strategy_farm\state\FACTORY_OFF.flag'
if (-not (Test-Path $flagPath)) {
    Write-Host '  NOTE: FACTORY_OFF.flag not present — factory may already be running.' -ForegroundColor Yellow
    Write-Host '        Proceeding with Factory_ON to ensure clean start state.'
    Write-Host ''
}

# Step 2: Run Factory_ON (removes flag, restores codex_parallel, re-enables all tasks,
#         spawns workers, runs farmctl repair, triggers pump).
Write-Host '  Step 1: Factory_ON ...'
& (Join-Path $PSScriptRoot 'Factory_ON.ps1') -NoPause:$true
Write-Host '  Factory_ON complete.'
Write-Host ''

# Step 3: Verify restore checklist.
Write-Host '  Restore verification' -ForegroundColor Cyan
$cpPath = 'D:\QM\strategy_farm\state\codex_parallel.txt'
$cpVal  = (Get-Content $cpPath -ErrorAction SilentlyContinue).Trim()

$checks = @(
    @{ Name='FACTORY_OFF.flag removed';
       OK=(-not (Test-Path $flagPath));
       Expected='absent' },
    @{ Name="codex_parallel != 0";
       OK=($cpVal -ne '' -and $cpVal -ne '0');
       Expected="non-zero (was: $cpVal)" },
    @{ Name='terminal_worker daemons > 0';
       OK=(@(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -match 'terminal_worker\.py' }).Count -gt 0);
       Expected='>0 running' }
)

$allOK = $true
foreach ($c in $checks) {
    $mark = if ($c.OK) { '[OK]' } else { '[WARN]' }
    $color = if ($c.OK) { 'Green' } else { 'Yellow' }
    Write-Host ("  {0,-8} {1}" -f $mark, $c.Name) -ForegroundColor $color
    if (-not $c.OK) { $allOK = $false }
}
Write-Host ''

if ($allOK) {
    Write-Host '  RESTORE COMPLETE. Factory back in normal production mode.' -ForegroundColor Green
} else {
    Write-Host '  PARTIAL RESTORE. Review warnings above; run Factory_ON manually if needed.' -ForegroundColor Yellow
}
Write-Host ''
if (-not $NoPause) { Read-Host 'Press Enter to close' }
