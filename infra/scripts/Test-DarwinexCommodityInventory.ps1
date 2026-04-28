param(
    [string]$PythonExe = "python",
    [string]$TerminalPath = "D:\QM\mt5\T1\terminal64.exe",
    [string]$StagingDir = "D:\QM\reports\setup\tick-data-timezone",
    [string]$ImportsDoneDir = "D:\QM\mt5\T1\MQL5\Files\imports\done",
    [string]$OutJson = "infra/reports/darwinex_commodity_inventory_latest.json",
    [string]$OutMd = "infra/reports/darwinex_commodity_inventory_latest.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-IsoNow {
    return [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function New-CandidatePack {
    param(
        [string]$CommodityCode,
        [string[]]$SourceCandidates,
        [string[]]$CustomCandidates
    )

    [PSCustomObject]@{
        commodityCode = $CommodityCode
        sourceCandidates = $SourceCandidates
        customCandidates = $CustomCandidates
    }
}

function Join-List {
    param([object]$Values)
    $arr = @($Values | Where-Object { $null -ne $_ -and "$_" -ne "" })
    if ($arr.Count -eq 0) { return "" }
    return [string]::Join(", ", $arr)
}

$candidatePacks = @(
    (New-CandidatePack -CommodityCode "NG" -SourceCandidates @("XNGUSD","NGAS","NATGAS","NG") -CustomCandidates @("XNGUSD.DWX","NG.DWX","NGAS.DWX")),
    (New-CandidatePack -CommodityCode "RB" -SourceCandidates @("XRBUSD","RBOB","RB","GASOLINE") -CustomCandidates @("XRBUSD.DWX","RB.DWX","RBOB.DWX"))
)

$stagingRoots = @()
if (Test-Path -LiteralPath $StagingDir) {
    $stagingRoots = Get-ChildItem -LiteralPath $StagingDir -Filter "*_GMT+*_US-DST.csv" -File |
        ForEach-Object {
            if ($_.Name -match "^(?<root>.+?)_GMT[+\-]\d+_(US|EU)-DST\.csv$") {
                $matches["root"]
            }
        } |
        Where-Object { $_ } |
        Sort-Object -Unique
}

$doneSymbols = @()
if (Test-Path -LiteralPath $ImportsDoneDir) {
    $doneSymbols = Get-ChildItem -LiteralPath $ImportsDoneDir -Filter "*.import.txt" -File |
        ForEach-Object {
            $parts = $_.BaseName.Split("_")
            if ($parts.Length -ge 3) {
                $parts[2]
            }
        } |
        Where-Object { $_ -like "*.DWX" } |
        Sort-Object -Unique
}

$pythonProbe = @'
import json
import os
import sys
try:
    import MetaTrader5 as mt5
except Exception:
    e = sys.exc_info()[1]
    sys.stdout.write(json.dumps({"ok": False, "error": "MetaTrader5 import failed: {0}".format(e)}))
    raise SystemExit(0)

terminal = os.environ.get("QM_TERMINAL_PATH", "")
if not mt5.initialize(path=terminal, portable=True):
    err = mt5.last_error()
    sys.stdout.write(json.dumps({"ok": False, "error": "mt5.initialize failed: {0}".format(err)}))
    raise SystemExit(0)

try:
    symbols = mt5.symbols_get() or []
    broker = sorted([s.name for s in symbols if not getattr(s, "custom", False)])
    custom = sorted([s.name for s in symbols if getattr(s, "custom", False)])
    sys.stdout.write(json.dumps({"ok": True, "broker": broker, "custom": custom}))
finally:
    mt5.shutdown()
'@

$env:QM_TERMINAL_PATH = $TerminalPath
$pyCommand = @(
    "-c"
    $pythonProbe
)
$mt5Raw = $null
try {
    $mt5Raw = & $PythonExe @pyCommand 2>$null
} catch {
    $mt5Raw = $null
}
$mt5 = $null
if ($LASTEXITCODE -eq 0 -and $mt5Raw) {
    try {
        $mt5 = $mt5Raw | ConvertFrom-Json
    } catch {
        $mt5 = [PSCustomObject]@{
            ok = $false
            error = "failed to parse MT5 probe output"
        }
    }
}
if (-not $mt5) {
    $mt5 = [PSCustomObject]@{
        ok = $false
        error = "MT5 probe did not return output"
    }
}

$brokerSet = @{}
$customSet = @{}
if ($mt5.ok) {
    foreach ($s in $mt5.broker) { $brokerSet[$s] = $true }
    foreach ($s in $mt5.custom) { $customSet[$s] = $true }
}

$commodities = @()
foreach ($pack in $candidatePacks) {
    $sourceHits = @()
    $customHitsMt5 = @()
    $customHitsStaging = @()
    $customHitsDone = @()

    foreach ($c in $pack.sourceCandidates) {
        if ($brokerSet.ContainsKey($c)) { $sourceHits += $c }
    }
    foreach ($c in $pack.customCandidates) {
        if ($customSet.ContainsKey($c)) { $customHitsMt5 += $c }
    }

    foreach ($root in $stagingRoots) {
        $asDwx = "$root.DWX"
        if ($pack.customCandidates -contains $asDwx) {
            $customHitsStaging += $asDwx
        }
    }
    foreach ($d in $doneSymbols) {
        if ($pack.customCandidates -contains $d) {
            $customHitsDone += $d
        }
    }

    $status = "missing"
    if ($sourceHits.Count -gt 0 -and ($customHitsMt5.Count -gt 0 -or $customHitsDone.Count -gt 0 -or $customHitsStaging.Count -gt 0)) {
        $status = "present"
    } elseif ($sourceHits.Count -gt 0 -or $customHitsMt5.Count -gt 0 -or $customHitsDone.Count -gt 0 -or $customHitsStaging.Count -gt 0) {
        $status = "partial"
    }

    $commodities += [PSCustomObject]@{
        commodityCode = $pack.commodityCode
        status = $status
        sourceHitsBroker = ($sourceHits | Sort-Object -Unique)
        customHitsMt5 = ($customHitsMt5 | Sort-Object -Unique)
        customHitsStaging = ($customHitsStaging | Sort-Object -Unique)
        customHitsDone = ($customHitsDone | Sort-Object -Unique)
        sourceCandidates = $pack.sourceCandidates
        customCandidates = $pack.customCandidates
    }
}

$presentCount = @($commodities | Where-Object { $_.status -eq "present" }).Count
$nonMissingCount = @($commodities | Where-Object { $_.status -ne "missing" }).Count

$overall = if ($presentCount -eq $commodities.Count) {
    "pass"
} elseif ($nonMissingCount -gt 0) {
    "partial"
} else {
    "fail"
}

$report = [PSCustomObject]@{
    generatedAtUtc = Get-IsoNow
    terminalPath = $TerminalPath
    mt5Probe = [PSCustomObject]@{
        ok = [bool]$mt5.ok
        error = $mt5.error
    }
    paths = [PSCustomObject]@{
        stagingDir = $StagingDir
        importsDoneDir = $ImportsDoneDir
    }
    inventory = [PSCustomObject]@{
        overall = $overall
        commodities = $commodities
    }
}

$outJsonAbs = [System.IO.Path]::GetFullPath($OutJson)
$outMdAbs = [System.IO.Path]::GetFullPath($OutMd)
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($outJsonAbs)) | Out-Null
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($outMdAbs)) | Out-Null

$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outJsonAbs -Encoding UTF8

$md = @()
$md += "# Darwinex Commodity-CFD Inventory (RB + NG)"
$md += ""
$md += "- generated_at_utc: $($report.generatedAtUtc)"
$md += "- terminal_path: $TerminalPath"
$md += "- mt5_probe_ok: $($report.mt5Probe.ok)"
if ($report.mt5Probe.error) { $md += "- mt5_probe_error: $($report.mt5Probe.error)" }
$md += "- overall: $overall"
$md += ""
$md += "| commodity | status | broker_source_hits | custom_mt5_hits | staging_hits | imports_done_hits |"
$md += "|---|---|---|---|---|---|"
foreach ($row in $commodities) {
    $md += "| $($row.commodityCode) | $($row.status) | $(Join-List $row.sourceHitsBroker) | $(Join-List $row.customHitsMt5) | $(Join-List $row.customHitsStaging) | $(Join-List $row.customHitsDone) |"
}

$md | Set-Content -LiteralPath $outMdAbs -Encoding UTF8

Write-Output "wrote: $outJsonAbs"
Write-Output "wrote: $outMdAbs"
Write-Output "overall: $overall"
