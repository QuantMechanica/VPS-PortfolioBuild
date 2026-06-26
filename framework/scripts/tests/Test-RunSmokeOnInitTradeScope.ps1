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

$validReportHtml = @"
<html><body><table>
<tr><td>Expert:</td><td><b>QM5_12564_ohlc-mtf-index-energy</b></td></tr>
<tr><td>Symbol:</td><td><b>XAGUSD.DWX</b></td></tr>
<tr><td>Period:</td><td><b>H1 (2024.07.01 - 2024.12.31)</b></td></tr>
<tr><td>Bars:</td><td><b>3210</b></td></tr>
</table></body></html>
"@

$foreignOnInitTail = @"
AA  0  21:44:47.949 Core 01 XAGUSD.DWX,H1: total time from login to stop testing 0:02:16.197
BB  2  23:33:43.338 Core 01 tester stopped because OnInit returns non-zero code 1
"@

$tradedReasons = Get-ReportInvalidReasons `
    -Html $validReportHtml `
    -TesterLogTail $foreignOnInitTail `
    -ExpectedSymbol "XAGUSD.DWX" `
    -ExpectedFromDate "2024.07.01" `
    -ExpectedToDate "2024.12.31" `
    -HasRealTicksMarker $true `
    -ReportTotalTrades 37

if ($tradedReasons -contains "ONINIT_FAILED") {
    throw "Foreign OnInit failure was incorrectly applied to a report with trades."
}

$zeroTradeReasons = Get-ReportInvalidReasons `
    -Html $validReportHtml `
    -TesterLogTail $foreignOnInitTail `
    -ExpectedSymbol "XAGUSD.DWX" `
    -ExpectedFromDate "2024.07.01" `
    -ExpectedToDate "2024.12.31" `
    -HasRealTicksMarker $true `
    -ReportTotalTrades 0

if ($zeroTradeReasons -notcontains "ONINIT_FAILED") {
    throw "Zero-trade report did not preserve OnInit failure detection."
}

Write-Host "PASS Test-RunSmokeOnInitTradeScope"
