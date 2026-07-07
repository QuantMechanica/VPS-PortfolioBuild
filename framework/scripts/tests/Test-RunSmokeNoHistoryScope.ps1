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
    "Get-ReportInvalidReasons",
    "Resolve-InvalidReportVerdict"
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

$foreignNoHistoryTail = @"
RF	0	10:06:06.165	Tester	"QM\QM5_1142_usdjpy-time-range-breakout.ex5" X64
RO	3	10:06:06.166	Tester	custom group settings applied from file 'MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt'
EQ	3	10:06:06.410	Tester	USDJPY.DWX: no history data from 2024.01.01 00:00 to 2024.12.31 00:00
EF	3	10:06:06.410	Tester	no history data, stop testing
LK	0	10:06:15.725	Tester	EURUSD.DWX: history data begins from 2017.10.02 00:00
"@

$foreignDetected = Test-TesterLogHasNoHistoryForRun `
    -TesterLogTail $foreignNoHistoryTail `
    -ExpectedSymbol "EURUSD.DWX" `
    -ExpectedFromDate "2024.01.01" `
    -ExpectedToDate "2024.12.31"
if ($foreignDetected) {
    throw "Foreign-symbol no-history log was incorrectly classified as current run NO_HISTORY."
}

$currentNoHistoryTail = @"
LR	0	10:05:52.001	Tester	"QM\QM5_1056_moskowitz-tsmom-multiasset.ex5" X64
IH	3	10:05:52.002	Tester	custom group settings applied from file 'MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt'
LP	3	10:05:52.330	Tester	EURUSD.DWX: no history data from 2024.01.01 00:00 to 2024.12.31 00:00
CG	3	10:05:52.330	Tester	no history data, stop testing
"@

$currentDetected = Test-TesterLogHasNoHistoryForRun `
    -TesterLogTail $currentNoHistoryTail `
    -ExpectedSymbol "EURUSD.DWX" `
    -ExpectedFromDate "2024.01.01" `
    -ExpectedToDate "2024.12.31"
if (-not $currentDetected) {
    throw "Current-symbol no-history log was not detected."
}

$emptyShellReport = @"
<html><body><table>
<tr><td>Expert:</td><td><b></b></td></tr>
<tr><td>Symbol:</td><td><b></b></td></tr>
<tr><td>Period:</td><td><b>M0 (1970.01.01 - 1970.01.01)</b></td></tr>
<tr><td>Bars:</td><td><b>0</b></td></tr>
<tr><td>Profit Factor:</td><td><b>0.00</b></td></tr>
<tr><td>Equity Drawdown Maximal:</td><td><b>0 (0%)</b></td></tr>
<tr><td>Total Net Profit:</td><td><b>0</b></td></tr>
<tr><td>Total Trades:</td><td><b>0</b></td></tr>
</table></body></html>
"@

$successfulHistoryTail = @"
IJ	0	16:18:02.461	Tester	AUDNZD.DWX,Daily (Darwinex-Live): testing of Experts\QM\QM5_13020_audnzd-coint-reversion.ex5 from 2018.07.02 00:00 to 2024.12.31 00:00
LG	0	16:18:08.625	Core 01	AUDNZD.DWX,Daily: testing of Experts\QM\QM5_13020_audnzd-coint-reversion.ex5 from 2018.07.02 00:00 to 2024.12.31 00:00 started with inputs:
CS	0	16:18:53.481	Core 01	NZDUSD.DWX: history synchronized from 2017.10.02 to 2024.12.31
DS	0	16:18:53.481	Core 01	2018.07.03 00:05:00   market sell 0.89 AUDNZD.DWX sl: 1.10944 (1.09276 / 1.09354)
EL	0	16:19:22.698	Tester	automatical testing finished
"@

$shellReasons = Get-ReportInvalidReasons `
    -Html $emptyShellReport `
    -TesterLogTail $successfulHistoryTail `
    -ExpectedSymbol "AUDNZD.DWX" `
    -ExpectedFromDate "2018.07.02" `
    -ExpectedToDate "2024.12.31" `
    -HasRealTicksMarker $true `
    -ReportTotalTrades 0

if ($shellReasons -contains "HISTORY_CONTEXT_INVALID") {
    throw "Successful history log text incorrectly produced HISTORY_CONTEXT_INVALID."
}
if ((Resolve-InvalidReportVerdict -InvalidReasons $shellReasons) -eq "NO_HISTORY") {
    throw "Empty shell plus successful history text was incorrectly classified as NO_HISTORY."
}

$currentNoHistoryReasons = Get-ReportInvalidReasons `
    -Html $emptyShellReport `
    -TesterLogTail $currentNoHistoryTail `
    -ExpectedSymbol "EURUSD.DWX" `
    -ExpectedFromDate "2024.01.01" `
    -ExpectedToDate "2024.12.31" `
    -HasRealTicksMarker $true `
    -ReportTotalTrades 0

if ($currentNoHistoryReasons -notcontains "HISTORY_CONTEXT_INVALID") {
    throw "Current-symbol no-history shell did not produce HISTORY_CONTEXT_INVALID."
}
if ((Resolve-InvalidReportVerdict -InvalidReasons $currentNoHistoryReasons) -ne "NO_HISTORY") {
    throw "Current-symbol no-history shell was not classified as NO_HISTORY."
}

Write-Host "PASS Test-RunSmokeNoHistoryScope"
