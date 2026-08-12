Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
$diagnosticRoot = Join-Path $repoRoot "framework\scripts\mt5_diagnostics"
$mqlPath = Join-Path $diagnosticRoot "QM_Dump_DWX_TickValue.mq5"
$runnerPath = Join-Path $diagnosticRoot "run_dwx_tickvalue_dump.ps1"

function Assert-ContainsText {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Expected,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not $Text.Contains($Expected, [System.StringComparison]::Ordinal)) {
        throw "$Label is missing required text: $Expected"
    }
}

function Assert-NoRegex {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ([regex]::IsMatch($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        throw "$Label contains forbidden pattern: $Pattern"
    }
}

if (-not (Test-Path -LiteralPath $mqlPath -PathType Leaf)) {
    throw "MQL diagnostic missing: $mqlPath"
}
if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
    throw "PowerShell runner missing: $runnerPath"
}

$mql = Get-Content -Raw -LiteralPath $mqlPath
$runner = Get-Content -Raw -LiteralPath $runnerPath

$tokens = $null
$parseErrors = $null
$runnerAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $runnerPath,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -ne 0) {
    $messages = ($parseErrors | ForEach-Object { "$($_.Extent.StartLineNumber):$($_.Message)" }) -join "; "
    throw "Runner PowerShell parse failed: $messages"
}

$parameterNames = @(
    $runnerAst.ParamBlock.Parameters |
        ForEach-Object { $_.Name.VariablePath.UserPath }
)
$expectedParameters = @("AgentTaskId", "CompileTimeoutSeconds", "RunTimeoutSeconds")
if (@(Compare-Object -ReferenceObject $expectedParameters -DifferenceObject $parameterNames).Count -ne 0) {
    throw "Runner parameter surface drifted; terminal/report roots must not be caller-controlled."
}

$launchCommands = @(
    $runnerAst.FindAll(
        {
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -eq "Start-Process"
        },
        $true
    )
)
if ($launchCommands.Count -ne 2) {
    throw "Runner must contain exactly two launch calls (compiler and T_Export); got $($launchCommands.Count)."
}
foreach ($launch in $launchCommands) {
    if ($launch.Extent.Text -notmatch '-FilePath\s+\$(metaEditorExe|terminalExe)\b') {
        throw "Start-Process is not bound to an approved resolved executable: $($launch.Extent.Text)"
    }
    if ($launch.Extent.Text -notmatch '-WindowStyle\s+Hidden\b') {
        throw "Approved process launch is not hidden: $($launch.Extent.Text)"
    }
}

foreach ($required in @(
    '$ExpectedTerminalRoot = "D:\QM\mt5\T_Export"',
    '$ExpectedOperation = "framework_h5_dwx_tickvalue_verify"',
    'Assert-AgentTaskAuthorization',
    'Assert-TExportIdle',
    'Assert-NotForbiddenTerminalPath',
    'ShutdownTerminal=1',
    '/portable',
    'Publish-AtomicFile',
    'Move-Item -LiteralPath $temporary -Destination $Destination',
    'QM_RiskSizer.mqh changed while the verification-only runner was executing.',
    '$rows.Count -ne 7',
    '$actualHeader -cne $ExpectedHeader'
)) {
    Assert-ContainsText -Text $runner -Expected $required -Label "runner"
}

foreach ($terminal in 1..10) {
    Assert-ContainsText -Text $runner -Expected "D:\QM\mt5\T$terminal" -Label "factory exclusion list"
}
Assert-ContainsText -Text $runner -Expected "C:\QM\mt5\T_Live" -Label "live exclusion list"
Assert-ContainsText -Text $runner -Expected "D:\QM\mt5\T_Live" -Label "live exclusion list"

foreach ($required in @(
    '#include "..\..\include\QM\QM_RiskSizer.mqh"',
    'QM_RiskSizerReadSymbolSnapshot(symbol, snapshot)',
    'QM_LotsForRiskFromSnapshot(snapshot, QM_DWX_RISK_MONEY, sl_points)',
    'QM_RiskSizerQuantizeLots(ordercalc_raw_lots',
    'OrderCalcProfit(order_type, symbol, 1.0, open_price, close_price, profit)',
    'FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON',
    'QM\\state\\dwx_tickvalue_dump_staging.csv',
    'QM\\state\\dwx_tickvalue_dump_complete.marker',
    'QM_DWX_DATA_WAIT_MS = 60000',
    'WaitForConnectedQuotes(symbols)',
    'TerminalInfoInteger(TERMINAL_CONNECTED)',
    'QM_DWX_TICKVALUE_COMPLETE'
)) {
    Assert-ContainsText -Text $mql -Expected $required -Label "MQL diagnostic"
}

foreach ($symbol in @(
    "NDX.DWX", "WS30.DWX", "SP500.DWX", "GDAXI.DWX",
    "XAUUSD.DWX", "XTIUSD.DWX", "XNGUSD.DWX"
)) {
    Assert-ContainsText -Text $mql -Expected ('"' + $symbol + '"') -Label "MQL symbol set"
}

foreach ($forbiddenPattern in @(
    '\bOrderSend\s*\(',
    '\bCTrade\b',
    '\bPositionClose\s*\(',
    '\bCustomSymbol(Set|Delete|Create)',
    '\bGlobalVariableSet\s*\(',
    '\bACCOUNT_LOGIN\b',
    '\bACCOUNT_NAME\b'
)) {
    Assert-NoRegex -Text $mql -Pattern $forbiddenPattern -Label "MQL diagnostic"
}
foreach ($forbiddenPattern in @(
    '\bSet-ItemProperty\b',
    '\bNew-ItemProperty\b',
    '\breg(?:\.exe)?\s+',
    '\bExpertsEnable\b',
    '\bACCOUNT_LOGIN\b'
)) {
    Assert-NoRegex -Text $runner -Pattern $forbiddenPattern -Label "runner"
}

$mqlHeaderMatch = [regex]::Match(
    $mql,
    '(?s)const string QM_DWX_CSV_HEADER\s*=\s*(?<body>.*?);'
)
if (-not $mqlHeaderMatch.Success) {
    throw "Could not parse the MQL CSV header declaration."
}
$mqlHeaderParts = [regex]::Matches(
    $mqlHeaderMatch.Groups["body"].Value,
    '"(?<value>(?:\\.|[^"])*)"'
)
$mqlHeader = ($mqlHeaderParts | ForEach-Object { $_.Groups["value"].Value }) -join ""
$mqlColumns = @($mqlHeader -split ",")
if ($mqlColumns.Count -ne 67 -or @($mqlColumns | Select-Object -Unique).Count -ne 67) {
    throw "MQL schema must contain exactly 67 unique columns."
}

$runnerColumnsMatch = [regex]::Match(
    $runner,
    '(?s)\$ExpectedColumns\s*=\s*@\((?<body>.*?)\)\s*\r?\n\$ExpectedHeader'
)
if (-not $runnerColumnsMatch.Success) {
    throw "Could not parse the runner's expected-column declaration."
}
$runnerColumnParts = [regex]::Matches(
    $runnerColumnsMatch.Groups["body"].Value,
    '"(?<value>[^"]+)"'
)
$runnerHeader = ($runnerColumnParts | ForEach-Object { $_.Groups["value"].Value }) -join ","
if ($runnerHeader -cne $mqlHeader) {
    throw "Runner and MQL CSV schemas differ."
}

$rowStart = $mql.IndexOf("string fields[];")
$rowEnd = $mql.IndexOf('string line = "";', $rowStart)
if ($rowStart -lt 0 -or $rowEnd -le $rowStart) {
    throw "Could not isolate the MQL row builder."
}
$rowBuilder = $mql.Substring($rowStart, $rowEnd - $rowStart)
$fieldCount = [regex]::Matches($rowBuilder, 'AddField\(').Count
if ($fieldCount -ne $mqlColumns.Count) {
    throw "MQL row field count ($fieldCount) differs from schema count ($($mqlColumns.Count))."
}

Write-Output "PASS: H5 DWX tick-value diagnostic and T_Export runner static contracts"
