$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '..\run_smoke.ps1'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path $scriptPath), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'run_smoke parser errors' }
foreach ($name in @('Convert-HtmlEntityText', 'Get-ReportMetricValue', 'Convert-ReportNumber',
                    'Get-ReportInvalidReasons', 'Test-TesterLogShowsOnInitFailure',
                    'Test-TesterLogShowsSetupDataMissing', 'Test-TesterLogHasNoHistoryForRun')) {
    $fn = $ast.Find({ param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true)
    if (-not $fn) { throw "Missing function $name" }
    Invoke-Expression $fn.Extent.Text
}
$html = '<table>' + ((@{
    Expert='QM\fixture'; Symbol='USDJPY.DWX'; Period='H1 (2023.01.01 - 2023.12.31)';
    Bars='6000'; 'Total Trades'='100'; 'Profit Factor'='1.2';
    'Equity Drawdown Maximal'='1000 (1%)'; 'Total Net Profit'='2000'
}.GetEnumerator() | ForEach-Object { "<tr><td>$($_.Key):</td><td><b>$($_.Value)</b></td></tr>" }) -join '') + '</table>'
$params = @{ Html=$html; TesterLogTail=''; ExpectedSymbol='USDJPY.DWX';
    ExpectedFromDate='2023.01.01'; ExpectedToDate='2023.12.31';
    HasRealTicksMarker=$true; ReportTotalTrades=100 }
$reasons = @(Get-ReportInvalidReasons @params)
if ($reasons.Count) { throw "Valid native report rejected: $reasons" }
$params.Html = ''
if (@(Get-ReportInvalidReasons @params) -notcontains 'REPORT_EMPTY') { throw 'Empty HTML must stay invalid' }
$params.Html = $html.Replace('<b>6000</b>', '<b>0</b>')
if (@(Get-ReportInvalidReasons @params) -notcontains 'BARS_ZERO') { throw 'Zero bars must stay invalid' }
$params.Html = $html; $params.ReportTotalTrades = 0
$params.TesterLogTail = 'tester stopped because OnInit returns non-zero code 1'
if (@(Get-ReportInvalidReasons @params) -notcontains 'ONINIT_FAILED') { throw 'Authenticated initialization failure must stay invalid' }
Write-Output 'PASS: empty log is accepted as absent evidence; invalid report/OnInit guards remain intact'
