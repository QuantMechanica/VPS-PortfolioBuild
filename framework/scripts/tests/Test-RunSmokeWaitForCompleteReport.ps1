[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$scriptPath = Join-Path $repoRoot "framework\scripts\run_smoke.ps1"

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
if (@($errors).Count -gt 0) {
    throw "run_smoke.ps1 parse errors: $($errors | Out-String)"
}

$neededFunctions = @(
    "Convert-HtmlEntityText",
    "Get-ReportMetricValue",
    "Convert-ReportNumber",
    "Test-TesterReportHasCompleteMetrics",
    "Test-TesterReportSafeToLatch",
    "Publish-TesterReportCandidate",
    "Wait-ForReportExport",
    "Get-ReportExportWaitSeconds"
)

foreach ($name in $neededFunctions) {
    $functionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $name
    }, $true)

    if (-not $functionAst) {
        throw "$name function not found."
    }

    Invoke-Expression $functionAst.Extent.Text
}

function Get-MetaTesterProcessesForTerminalRoot {
    param([string]$TerminalRoot)
    return @()
}

$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("qm-run-smoke-report-wait-{0}" -f [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
$reportPath = Join-Path $tmpRoot "report.htm"

try {
    @"
<html><body><table>
<tr><td>Expert:</td><td><b></b></td></tr>
<tr><td>Symbol:</td><td><b></b></td></tr>
<tr><td>Period:</td><td><b>M0 (1970.01.01 - 1970.01.01)</b></td></tr>
<tr><td>Bars:</td><td><b>0</b></td></tr>
<tr><td>Profit Factor:</td><td><b>0.00</b></td></tr>
<tr><td>Equity Drawdown Maximal:</td><td><b>0 (0%)</b></td></tr>
<tr><td>Total Trades:</td><td><b>0</b></td></tr>
</table></body></html>
"@ | Set-Content -LiteralPath $reportPath -Encoding UTF8

    if (Wait-ForReportExport -ReportPath $reportPath -TerminalRoot $tmpRoot -MaxWaitSeconds 0 -RequireCompleteMetrics) {
        throw "Incomplete M0/1970 tester report was accepted as materialized."
    }
    $fullWait = Get-ReportExportWaitSeconds -ReportPath $reportPath -WritersQuiescent $false -DefaultWaitSeconds 240
    if ($fullWait -ne 240) {
        throw "Incomplete report with an active/unproven writer lost its export grace: $fullWait"
    }
    $quiescentWait = Get-ReportExportWaitSeconds -ReportPath $reportPath -WritersQuiescent $true -DefaultWaitSeconds 240
    if ($quiescentWait -ne 0) {
        throw "Quiescent non-empty incomplete report retained the full export wait: $quiescentWait"
    }

    Remove-Item -LiteralPath $reportPath -Force
    $missingWait = Get-ReportExportWaitSeconds -ReportPath $reportPath -WritersQuiescent $true -DefaultWaitSeconds 240
    if ($missingWait -ne 240) {
        throw "Missing report lost its delayed-export grace: $missingWait"
    }

    @"
<html><body><table>
<tr><td>Expert:</td><td><b></b></td></tr>
<tr><td>Symbol:</td><td><b></b></td></tr>
<tr><td>Period:</td><td><b>M0 (1970.01.01 - 1970.01.01)</b></td></tr>
<tr><td>Bars:</td><td><b>0</b></td></tr>
<tr><td>Profit Factor:</td><td><b>0.00</b></td></tr>
<tr><td>Equity Drawdown Maximal:</td><td><b>0 (0%)</b></td></tr>
<tr><td>Total Trades:</td><td><b>0</b></td></tr>
</table></body></html>
"@ | Set-Content -LiteralPath $reportPath -Encoding UTF8

    $canonicalReportPath = Join-Path $tmpRoot "canonical-report.htm"
    $publishedPath = Publish-TesterReportCandidate -SourceReportPath $reportPath -CanonicalReportPath $canonicalReportPath
    if ($publishedPath -ne $canonicalReportPath) {
        throw "Incomplete tester report was not published to canonical evidence path."
    }
    if (-not (Test-Path -LiteralPath $canonicalReportPath -PathType Leaf)) {
        throw "Canonical evidence copy was not created for incomplete tester report."
    }
    if (Wait-ForReportExport -ReportPath $canonicalReportPath -TerminalRoot $tmpRoot -MaxWaitSeconds 0 -RequireCompleteMetrics) {
        throw "Publishing incomplete tester report incorrectly made it complete."
    }

    # Regression: QM5_20224 seed 2026 exposed a stable MT5 report shell with
    # plausible identity/range/metrics but Symbols=0 and Total Trades=0 while
    # the tester journal was still executing real deals.  It is parseable final
    # evidence after process exit, but must never trigger the early latch.
    @"
<html><body><table>
<tr><td>Expert:</td><td><b>QM5_20224_eurusd-eurjpy</b></td></tr>
<tr><td>Symbol:</td><td><b>EURUSD.DWX</b></td></tr>
<tr><td>Period:</td><td><b>Daily (2018.07.02 - 2025.12.31)</b></td></tr>
<tr><td>Bars:</td><td><b>1188</b></td></tr>
<tr><td>Symbols:</td><td><b>0</b></td></tr>
<tr><td>Profit Factor:</td><td><b>0.00</b></td></tr>
<tr><td>Equity Drawdown Maximal:</td><td><b>0 (0%)</b></td></tr>
<tr><td>Total Trades:</td><td><b>0</b></td></tr>
</table></body></html>
"@ | Set-Content -LiteralPath $reportPath -Encoding UTF8

    if (-not (Test-TesterReportHasCompleteMetrics -ReportPath $reportPath)) {
        throw "Plausible MT5 zero shell was not retained as parseable evidence."
    }
    if (Test-TesterReportSafeToLatch -ReportPath $reportPath) {
        throw "Plausible MT5 zero shell was incorrectly accepted by the early latch."
    }

    @"
<html><body><table>
<tr><td>Expert:</td><td><b>QM5_12783_edgelab-audusd-audjpy-cointegration</b></td></tr>
<tr><td>Symbol:</td><td><b>AUDUSD.DWX</b></td></tr>
<tr><td>Period:</td><td><b>D1 (2024.01.01 - 2024.12.31)</b></td></tr>
<tr><td>Bars:</td><td><b>260</b></td></tr>
<tr><td>Symbols:</td><td><b>0</b></td></tr>
<tr><td>Profit Factor:</td><td><b>0.00</b></td></tr>
<tr><td>Equity Drawdown Maximal:</td><td><b>0 (0%)</b></td></tr>
<tr><td>Total Trades:</td><td><b>0</b></td></tr>
</table></body></html>
"@ | Set-Content -LiteralPath $reportPath -Encoding UTF8

    if (-not (Wait-ForReportExport -ReportPath $reportPath -TerminalRoot $tmpRoot -MaxWaitSeconds 0 -RequireCompleteMetrics)) {
        throw "Complete zero-trade tester report was not accepted as materialized."
    }
    if (Test-TesterReportSafeToLatch -ReportPath $reportPath) {
        throw "Complete zero-trade report was incorrectly accepted by the early latch."
    }

    @"
<html><body><table>
<tr><td>Expert:</td><td><b>QM5_20224_eurusd-eurjpy</b></td></tr>
<tr><td>Symbol:</td><td><b>EURUSD.DWX</b></td></tr>
<tr><td>Period:</td><td><b>Daily (2018.07.02 - 2025.12.31)</b></td></tr>
<tr><td>Bars:</td><td><b>1928</b></td></tr>
<tr><td>Symbols:</td><td><b>2</b></td></tr>
<tr><td>Profit Factor:</td><td><b>1.08</b></td></tr>
<tr><td>Equity Drawdown Maximal:</td><td><b>3250.00 (3.25%)</b></td></tr>
<tr><td>Total Trades:</td><td><b>185</b></td></tr>
</table></body></html>
"@ | Set-Content -LiteralPath $reportPath -Encoding UTF8

    if (-not (Test-TesterReportSafeToLatch -ReportPath $reportPath)) {
        throw "Populated tester report was not accepted by the early latch."
    }
} finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "PASS Test-RunSmokeWaitForCompleteReport"
