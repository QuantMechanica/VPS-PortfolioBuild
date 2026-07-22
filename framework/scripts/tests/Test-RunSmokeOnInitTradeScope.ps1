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
    "Get-TesterLogCurrentRunText",
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

$sharedDailyLog = @"
AA  0  12:00:00 Tester XNGUSD.DWX,Daily: testing of Experts\QM\old.ex5 from 2018.01.01 to 2018.12.31 started with inputs:
AA  2  12:00:01 Tester tester stopped because OnInit returns non-zero code 1
BB  0  13:00:00 Tester GBPNZD.DWX,H4: testing of Experts\QM\QM5_1517_ehlers-roofing-filter-trend-h4.ex5 from 2022.07.01 to 2022.12.31 started with inputs:
BB  0  13:00:30 Tester final balance 100000.00 USD
BB  0  13:00:30 Tester test passed in 0:00:30.000
"@

$currentRunText = Get-TesterLogCurrentRunText -TesterLogTail $sharedDailyLog
if ($currentRunText -match "old\.ex5" -or (Test-TesterLogShowsOnInitFailure -TesterLogTail $currentRunText)) {
    throw "A previous EA's OnInit failure leaked into the current run journal scope."
}

$currentFailureLog = @"
BB  0  13:00:00 Tester GBPNZD.DWX,H4: testing of Experts\QM\QM5_1517_ehlers-roofing-filter-trend-h4.ex5 from 2022.07.01 to 2022.12.31 started with inputs:
BB  2  13:00:01 Tester tester stopped because OnInit returns non-zero code 1
"@
if (-not (Test-TesterLogShowsOnInitFailure -TesterLogTail (Get-TesterLogCurrentRunText -TesterLogTail $currentFailureLog))) {
    throw "The current EA's OnInit failure was removed by journal scoping."
}

$initialDepositTail = @"
Core 01  Initial Deposit: 100000.00
Core 01  report failed to open cache on first attempt; retry succeeded
"@

if (Test-TesterLogShowsOnInitFailure -TesterLogTail $initialDepositTail) {
    throw "Initial Deposit or generic failed wording was incorrectly treated as OnInit failure."
}

Write-Host "PASS Test-RunSmokeOnInitTradeScope"
