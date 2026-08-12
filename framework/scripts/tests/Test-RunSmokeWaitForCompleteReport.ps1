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

    @"
<html><body><table>
<tr><td>Expert:</td><td><b>QM5_12783_edgelab-audusd-audjpy-cointegration</b></td></tr>
<tr><td>Symbol:</td><td><b>AUDUSD.DWX</b></td></tr>
<tr><td>Period:</td><td><b>D1 (2024.01.01 - 2024.12.31)</b></td></tr>
<tr><td>Bars:</td><td><b>260</b></td></tr>
<tr><td>Profit Factor:</td><td><b>0.00</b></td></tr>
<tr><td>Equity Drawdown Maximal:</td><td><b>0 (0%)</b></td></tr>
<tr><td>Total Trades:</td><td><b>0</b></td></tr>
</table></body></html>
"@ | Set-Content -LiteralPath $reportPath -Encoding UTF8

    if (-not (Wait-ForReportExport -ReportPath $reportPath -TerminalRoot $tmpRoot -MaxWaitSeconds 0 -RequireCompleteMetrics)) {
        throw "Complete zero-trade tester report was not accepted as materialized."
    }
} finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "PASS Test-RunSmokeWaitForCompleteReport"
