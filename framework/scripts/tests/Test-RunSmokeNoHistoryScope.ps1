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

$functionAst = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq "Test-TesterLogHasNoHistoryForRun"
}, $true)

if (-not $functionAst) {
    throw "Test-TesterLogHasNoHistoryForRun function not found."
}

Invoke-Expression $functionAst.Extent.Text

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

Write-Host "PASS Test-RunSmokeNoHistoryScope"
