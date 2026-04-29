param(
    [string]$PythonExe = "python",
    [string]$TerminalPath = "D:\QM\mt5\T1\terminal64.exe",
    [string]$StagingDir = "D:\QM\reports\setup\tick-data-timezone",
    [string]$ImportsDoneDir = "D:\QM\mt5\T1\MQL5\Files\imports\done",
    [string]$OutJson = "infra/reports/darwinex_bond_inventory_latest.json",
    [string]$OutMd = "infra/reports/darwinex_bond_inventory_latest.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-IsoNow {
    return [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function New-CandidatePack {
    param(
        [string]$BondCode,
        [string[]]$SourceCandidates,
        [string[]]$CustomCandidates
    )

    [PSCustomObject]@{
        bondCode = $BondCode
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
    (New-CandidatePack -BondCode "US10Y" -SourceCandidates @("US10Y","UST10Y","US10YR","US10YNOTE") -CustomCandidates @("US10Y.DWX","UST10Y.DWX","US10YR.DWX")),
    (New-CandidatePack -BondCode "DE10Y" -SourceCandidates @("DE10Y","BUND10Y","BUND","DE10YR") -CustomCandidates @("DE10Y.DWX","BUND10Y.DWX","BUND.DWX"))
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
from datetime import datetime

def norm(v):
    if v is None:
        return None
    if isinstance(v, (str, bool, int, float)):
        return v
    if hasattr(v, "item"):
        try:
            return v.item()
        except Exception:
            pass
    if isinstance(v, datetime):
        return v.isoformat()
    try:
        return float(v)
    except Exception:
        try:
            return int(v)
        except Exception:
            return str(v)

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
    try:
        symbols = mt5.symbols_get() or []
        broker = sorted([s.name for s in symbols if not getattr(s, "custom", False)])
        custom = sorted([s.name for s in symbols if getattr(s, "custom", False)])
        details = {}
        for name in broker + custom:
            info = mt5.symbol_info(name)
            if info is None:
                continue
            tick = mt5.symbol_info_tick(name)
            details[name] = {
                "description": norm(getattr(info, "description", None)),
                "path": norm(getattr(info, "path", None)),
                "trade_mode": norm(getattr(info, "trade_mode", None)),
                "trade_calc_mode": norm(getattr(info, "trade_calc_mode", None)),
                "spread_points": norm(getattr(info, "spread", None)),
                "spread_float": norm(getattr(info, "spread_float", None)),
                "point": norm(getattr(info, "point", None)),
                "digits": norm(getattr(info, "digits", None)),
                "volume_min": norm(getattr(info, "volume_min", None)),
                "volume_step": norm(getattr(info, "volume_step", None)),
                "volume_max": norm(getattr(info, "volume_max", None)),
                "trade_contract_size": norm(getattr(info, "trade_contract_size", None)),
                "margin_initial": norm(getattr(info, "margin_initial", None)),
                "margin_maintenance": norm(getattr(info, "margin_maintenance", None)),
                "bid": norm(getattr(tick, "bid", None) if tick else None),
                "ask": norm(getattr(tick, "ask", None) if tick else None),
                "tick_time": norm(getattr(tick, "time", None) if tick else None)
            }
        sys.stdout.write(json.dumps({"ok": True, "broker": broker, "custom": custom, "details": details}))
    except Exception:
        e = sys.exc_info()[1]
        sys.stdout.write(json.dumps({"ok": False, "error": "probe runtime failed: {0}".format(e)}))
finally:
    mt5.shutdown()
'@

$env:QM_TERMINAL_PATH = $TerminalPath
$tempProbe = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), ("qm_bond_probe_{0}.py" -f ([Guid]::NewGuid().ToString("N"))))
$pythonProbe | Set-Content -LiteralPath $tempProbe -Encoding UTF8
$mt5Raw = $null
try {
    $mt5Raw = & $PythonExe $tempProbe 2>$null
} catch {
    $mt5Raw = $null
} finally {
    if (Test-Path -LiteralPath $tempProbe) {
        Remove-Item -LiteralPath $tempProbe -Force -ErrorAction SilentlyContinue
    }
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
$mt5Error = $null
if ($mt5.PSObject.Properties.Name -contains "error") {
    $mt5Error = $mt5.error
}

$brokerSet = @{}
$customSet = @{}
if ($mt5.ok) {
    foreach ($s in $mt5.broker) { $brokerSet[$s] = $true }
    foreach ($s in $mt5.custom) { $customSet[$s] = $true }
}
$detailMap = @{}
if ($mt5.ok -and $mt5.details) {
    $detailProps = $mt5.details.PSObject.Properties
    foreach ($p in $detailProps) {
        $detailMap[$p.Name] = $p.Value
    }
}

function Get-SymbolDetail {
    param(
        [hashtable]$Map,
        [string[]]$Candidates
    )
    foreach ($candidate in $Candidates) {
        if ($Map.ContainsKey($candidate)) {
            return $Map[$candidate]
        }
    }
    return $null
}

$bonds = @()
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

    $detail = Get-SymbolDetail -Map $detailMap -Candidates @($sourceHits + $customHitsMt5)

    $bonds += [PSCustomObject]@{
        bondCode = $pack.bondCode
        status = $status
        sourceHitsBroker = ($sourceHits | Sort-Object -Unique)
        customHitsMt5 = ($customHitsMt5 | Sort-Object -Unique)
        customHitsStaging = ($customHitsStaging | Sort-Object -Unique)
        customHitsDone = ($customHitsDone | Sort-Object -Unique)
        sourceCandidates = $pack.sourceCandidates
        customCandidates = $pack.customCandidates
        mt5SymbolDetail = $detail
    }
}

$presentCount = @($bonds | Where-Object { $_.status -eq "present" }).Count
$nonMissingCount = @($bonds | Where-Object { $_.status -ne "missing" }).Count

$overall = if ($presentCount -eq $bonds.Count) {
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
        error = $mt5Error
    }
    paths = [PSCustomObject]@{
        stagingDir = $StagingDir
        importsDoneDir = $ImportsDoneDir
    }
    inventory = [PSCustomObject]@{
        overall = $overall
        bonds = $bonds
    }
}

$outJsonAbs = [System.IO.Path]::GetFullPath($OutJson)
$outMdAbs = [System.IO.Path]::GetFullPath($OutMd)
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($outJsonAbs)) | Out-Null
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($outMdAbs)) | Out-Null

$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outJsonAbs -Encoding UTF8

$md = @()
$md += "# Darwinex Bond-CFD Inventory (US10Y + DE10Y)"
$md += ""
$md += "- generated_at_utc: $($report.generatedAtUtc)"
$md += "- terminal_path: $TerminalPath"
$md += "- mt5_probe_ok: $($report.mt5Probe.ok)"
if ($mt5Error) { $md += "- mt5_probe_error: $mt5Error" }
$md += "- overall: $overall"
$md += "- note: trade_hours/liquidity/commission fields require live broker symbol metadata; null means probe host could not read MT5 symbol details"
$md += ""
$md += "| bond | status | broker_source_hits | custom_mt5_hits | staging_hits | imports_done_hits |"
$md += "|---|---|---|---|---|---|"
foreach ($row in $bonds) {
    $md += "| $($row.bondCode) | $($row.status) | $(Join-List $row.sourceHitsBroker) | $(Join-List $row.customHitsMt5) | $(Join-List $row.customHitsStaging) | $(Join-List $row.customHitsDone) |"
}

$md += ""
$md += "## MT5 Symbol Details (when available)"
$md += ""
foreach ($row in $bonds) {
    $detail = $row.mt5SymbolDetail
    $md += "### $($row.bondCode)"
    if (-not $detail) {
        $md += "- detail: unavailable"
        continue
    }
    $md += "- description: $($detail.description)"
    $md += "- path: $($detail.path)"
    $md += "- trade_mode: $($detail.trade_mode)"
    $md += "- trade_calc_mode: $($detail.trade_calc_mode)"
    $md += "- spread_points: $($detail.spread_points)"
    $md += "- spread_float: $($detail.spread_float)"
    $md += "- point: $($detail.point)"
    $md += "- digits: $($detail.digits)"
    $md += "- volume_min: $($detail.volume_min)"
    $md += "- volume_step: $($detail.volume_step)"
    $md += "- volume_max: $($detail.volume_max)"
    $md += "- trade_contract_size: $($detail.trade_contract_size)"
    $md += "- margin_initial: $($detail.margin_initial)"
    $md += "- margin_maintenance: $($detail.margin_maintenance)"
    $md += "- bid: $($detail.bid)"
    $md += "- ask: $($detail.ask)"
    $md += "- tick_time: $($detail.tick_time)"
}

$md | Set-Content -LiteralPath $outMdAbs -Encoding UTF8

Write-Output "wrote: $outJsonAbs"
Write-Output "wrote: $outMdAbs"
Write-Output "overall: $overall"
