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
    "Test-ReportShowsRealTicks",
    "Test-TesterLogShowsOnInitFailure",
    "Test-TesterLogShowsSetupDataMissing",
    "Test-TesterLogHasNoHistoryForRun",
    "Get-ReportInvalidReasons"
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

$realTickReportHtml = @"
<html><body><table>
<tr><td>Expert:</td><td><b>QM5_12533_edgelab-eurjpy-gbpjpy-cointegration</b></td></tr>
<tr><td>Symbol:</td><td><b>EURJPY.DWX</b></td></tr>
<tr><td>Period:</td><td><b>D1 (2018.07.02 - 2024.12.31)</b></td></tr>
<tr><td>History Quality:</td><td><b>100% real ticks</b></td></tr>
<tr><td>Bars:</td><td><b>1684</b></td></tr>
</table></body></html>
"@

if (-not (Test-ReportShowsRealTicks -Html $realTickReportHtml)) {
    throw "Report-level real-tick evidence was not detected."
}

$finishedTailWithoutLegacyMarker = @"
LN  0  00:11:21.418 Core 01 final balance 100000 JPY
OH  0  00:11:21.418 Core 01 EURJPY.DWX,Daily: 427767746 ticks, 1684 bars generated. Test passed in 1:06:54.626 (including ticks preprocessing 0:01:54.595).
MK  0  00:11:21.418 Core 01 1566380513 total ticks for all symbols
QG  0  00:11:21.463 Tester  automatical testing finished
"@

$reasons = Get-ReportInvalidReasons `
    -Html $realTickReportHtml `
    -TesterLogTail $finishedTailWithoutLegacyMarker `
    -ExpectedSymbol "EURJPY.DWX" `
    -ExpectedFromDate "2018.07.02" `
    -ExpectedToDate "2024.12.31" `
    -HasRealTicksMarker (Test-ReportShowsRealTicks -Html $realTickReportHtml) `
    -ReportTotalTrades 0

if ($reasons -contains "NO_REAL_TICKS_MARKER_FAST_FINISH") {
    throw "Zero-trade real-tick report was incorrectly classified as NO_REAL_TICKS."
}

$syntheticReportHtml = $realTickReportHtml -replace "100% real ticks", "Every tick"
if (Test-ReportShowsRealTicks -Html $syntheticReportHtml) {
    throw "Non-real-tick report quality was incorrectly accepted."
}

Write-Host "PASS Test-RunSmokeRealTicksReportEvidence"
