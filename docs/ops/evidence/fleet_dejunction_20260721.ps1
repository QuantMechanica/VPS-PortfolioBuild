# FLEET bases de-junction - no-seed variant, validated factory-ON on T5 2026-07-21
# (isolated store = 0 error32 vs 300-700 on shared terminals under the live storm).
# Restructures T2..T10: real per-terminal bases + nested Custom junction (shared, 0 disk)
# + own EMPTY Darwinex-Live (cold-syncs from server on first use; mitigation self-heals).
# T1 stays the source store. Reversible. Requires FACTORY_OFF.flag + idle terminals.
# T_Live never touched (only T2..T10). ASCII only.
param([switch]$Apply, [switch]$Rollback,
      [string[]]$Terminals = @('T2','T3','T4','T5','T6','T7','T8','T9','T10'))
$ErrorActionPreference = 'Stop'
$MT5 = 'D:\QM\mt5'
$T1  = 'D:\QM\mt5\T1\Bases'
$OFFFLAG = 'D:\QM\strategy_farm\state\FACTORY_OFF.flag'

function Guard-IdleTerminal([string]$tn) {
    $p = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" |
           Where-Object { $_.ExecutablePath -like "*\$tn\*" -or $_.CommandLine -like "*\$tn\*" })
    if ($p.Count -gt 0) { throw ("ABORT " + $tn + ": terminal64 running PID " + $p[0].ProcessId) }
}

function Restructure-Terminal([string]$tn) {
    $base = Join-Path $MT5 ($tn + '\bases')
    Guard-IdleTerminal $tn
    $b = Get-Item $base -ErrorAction SilentlyContinue
    if ($b -and $b.LinkType -ne 'Junction') { Write-Host ("  " + $tn + " : already real bases - skipping"); return 'skipped' }
    if (-not $b) { throw ("ABORT " + $tn + ": bases missing") }
    cmd /c rmdir "$base" | Out-Null
    if (Test-Path $base) { throw ("ABORT " + $tn + ": junction remove failed") }
    New-Item -ItemType Directory -Path $base | Out-Null
    cmd /c mklink /J "$base\Custom" "$T1\Custom" | Out-Null
    Get-ChildItem "$T1\*.dat" | Copy-Item -Destination $base -Force
    foreach ($d in @('Default','signals')) {
        if (Test-Path "$T1\$d") { Copy-Item "$T1\$d" "$base\$d" -Recurse -Force }
    }
    New-Item -ItemType Directory -Path "$base\Darwinex-Live" | Out-Null
    $custOk = (Get-Item "$base\Custom").LinkType -eq 'Junction'
    $baseOk = (Get-Item $base).LinkType -ne 'Junction'
    if (-not ($custOk -and $baseOk)) { throw ("ABORT " + $tn + ": post-verify failed") }
    Write-Host ("  " + $tn + " : restructured (Custom shared, own empty Darwinex-Live)")
    return 'restructured'
}

function Rollback-Terminal([string]$tn) {
    $base = Join-Path $MT5 ($tn + '\bases')
    Guard-IdleTerminal $tn
    if ((Get-Item $base -ErrorAction SilentlyContinue).LinkType -eq 'Junction') { Write-Host ("  " + $tn + " : already junction"); return }
    if (Test-Path $base) { cmd /c rmdir /S /Q "$base" | Out-Null }
    cmd /c mklink /J "$base" "$T1" | Out-Null
    Write-Host ("  " + $tn + " : rolled back to junction")
}

if (-not $Apply -and -not $Rollback) { Write-Host 'pass -Apply or -Rollback'; return }
if ($Apply -and -not (Test-Path $OFFFLAG)) { throw 'ABORT: FACTORY_OFF.flag not present - quiesce the factory first.' }

$mode = 'ROLLBACK'
if ($Apply) { $mode = 'APPLY' }
Write-Host ("=== FLEET bases de-junction " + $mode + " : " + ($Terminals -join ',') + " ===")
$results = @{}
foreach ($tn in $Terminals) {
    if ($Apply)    { $results[$tn] = Restructure-Terminal $tn }
    if ($Rollback) { Rollback-Terminal $tn; $results[$tn] = 'rolled_back' }
}
Write-Host ''
Write-Host ("DONE. free D: " + [math]::Round((Get-PSDrive D).Free/1GB,1) + " GB")
$results.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Host ("  " + $_.Key + ": " + $_.Value) }
