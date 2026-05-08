# Batch caller: prepare_import.py for all 24 V5 broken symbols
# Run AFTER Delete_QM_V5_Custom_Symbols_Batch has cleaned MT5 symbol registry.
# Invokes prepare_import.py per symbol, handles the GDAXIm/NDXm rename via --source/--target.

[CmdletBinding()]
param(
    [string]$TdsFolder = "D:\QM\reports\setup\tick-data-timezone",
    [string]$ImportDir = "D:\QM\mt5\T1\dwx_import",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 24 broken symbols. Format: TDS_SOURCE_NAME, TARGET_NAME, BROKER_SOURCE_NAME
# (When TDS_SOURCE matches TARGET root, we omit overrides; for renames we set both.)
$jobs = @(
    @{ tds = "AUDCAD"; target = "AUDCAD.DWX"; source = "AUDCAD" },
    @{ tds = "AUDCHF"; target = "AUDCHF.DWX"; source = "AUDCHF" },
    @{ tds = "AUDJPY"; target = "AUDJPY.DWX"; source = "AUDJPY" },
    @{ tds = "AUDNZD"; target = "AUDNZD.DWX"; source = "AUDNZD" },
    @{ tds = "CADJPY"; target = "CADJPY.DWX"; source = "CADJPY" },
    @{ tds = "EURAUD"; target = "EURAUD.DWX"; source = "EURAUD" },
    @{ tds = "EURCAD"; target = "EURCAD.DWX"; source = "EURCAD" },
    @{ tds = "EURCHF"; target = "EURCHF.DWX"; source = "EURCHF" },
    @{ tds = "EURJPY"; target = "EURJPY.DWX"; source = "EURJPY" },
    @{ tds = "EURNZD"; target = "EURNZD.DWX"; source = "EURNZD" },
    @{ tds = "GBPAUD"; target = "GBPAUD.DWX"; source = "GBPAUD" },
    @{ tds = "GBPCAD"; target = "GBPCAD.DWX"; source = "GBPCAD" },
    @{ tds = "GBPCHF"; target = "GBPCHF.DWX"; source = "GBPCHF" },
    @{ tds = "GBPJPY"; target = "GBPJPY.DWX"; source = "GBPJPY" },
    @{ tds = "GBPNZD"; target = "GBPNZD.DWX"; source = "GBPNZD" },
    @{ tds = "GBPUSD"; target = "GBPUSD.DWX"; source = "GBPUSD" },
    @{ tds = "NZDJPY"; target = "NZDJPY.DWX"; source = "NZDJPY" },
    @{ tds = "USDJPY"; target = "USDJPY.DWX"; source = "USDJPY" },
    @{ tds = "XAUUSD"; target = "XAUUSD.DWX"; source = "XAUUSD" },
    @{ tds = "XNGUSD"; target = "XNGUSD.DWX"; source = "XNGUSD" },
    # CFD/index renames per DL-059: TDS still ships as "...m", target is broker name without suffix
    @{ tds = "GDAXIm"; target = "GDAXI.DWX"; source = "GDAXI" },
    @{ tds = "NDXm";   target = "NDX.DWX";   source = "NDX" },
    @{ tds = "UK100"; target = "UK100.DWX"; source = "UK100" },
    @{ tds = "WS30";  target = "WS30.DWX";  source = "WS30" }
)

Set-Location -LiteralPath $ImportDir
$tsStart = Get-Date
$ok = 0; $fail = 0; $results = @()

Write-Output "[batch] prepare_import for $($jobs.Count) symbols (start: $tsStart)"
Write-Output "[batch] TDS folder : $TdsFolder"
Write-Output "[batch] dry-run    : $DryRun"
Write-Output ""

foreach ($job in $jobs) {
    $tickCsv = Join-Path $TdsFolder "$($job.tds)_GMT+2_US-DST.csv"
    if (-not (Test-Path -LiteralPath $tickCsv)) {
        Write-Output "[$($job.tds)] SKIP — tick CSV not found: $tickCsv"
        $fail += 1
        $results += [PSCustomObject]@{ symbol = $job.tds; result = "csv_missing"; target = $job.target }
        continue
    }
    $tStart = Get-Date
    $args = @(
        "prepare_import.py",
        $tickCsv,
        "--target", $job.target,
        "--source", $job.source
    )
    if ($DryRun) {
        Write-Output "[$($job.tds)] DRY: python $($args -join ' ')"
        $ok += 1
        continue
    }
    Write-Output "[$($job.tds)] → target=$($job.target) source=$($job.source) ..."
    & python $args 2>&1 | Tee-Object -Variable out | Select-Object -Last 4 | ForEach-Object { Write-Output "  $_" }
    $rc = $LASTEXITCODE
    $tEnd = Get-Date
    $dur = [int]($tEnd - $tStart).TotalSeconds
    if ($rc -eq 0) {
        Write-Output "[$($job.tds)] OK in ${dur}s"
        $ok += 1
        $results += [PSCustomObject]@{ symbol = $job.tds; result = "ok"; target = $job.target; secs = $dur }
    } else {
        Write-Output "[$($job.tds)] FAILED rc=$rc in ${dur}s"
        $fail += 1
        $results += [PSCustomObject]@{ symbol = $job.tds; result = "rc=$rc"; target = $job.target; secs = $dur }
    }
}

$tsEnd = Get-Date
Write-Output ""
Write-Output "[batch] done in $([int](($tsEnd - $tsStart).TotalSeconds))s | OK=$ok FAIL=$fail"
$results | Format-Table -AutoSize

# Summary count of staged bins
$stagedTick = (Get-ChildItem "D:\QM\mt5\T1\MQL5\Files\imports\*.tick.bin" -ErrorAction SilentlyContinue).Count
$stagedM1 = (Get-ChildItem "D:\QM\mt5\T1\MQL5\Files\imports\*.m1.bin" -ErrorAction SilentlyContinue).Count
$stagedSc = (Get-ChildItem "D:\QM\mt5\T1\MQL5\Files\imports\*.import.txt" -ErrorAction SilentlyContinue).Count
Write-Output "[batch] staged in imports/: tick.bin=$stagedTick m1.bin=$stagedM1 import.txt=$stagedSc"

if ($fail -gt 0) { exit 1 }
exit 0
