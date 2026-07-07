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
        $node.Name -eq "Test-TesterLogShowsAccountNotSpecified"
}, $true)

if (-not $functionAst) {
    throw "Test-TesterLogShowsAccountNotSpecified function not found."
}

Invoke-Expression $functionAst.Extent.Text

$accountMissingTail = @"
JP  0  05:30:59.107 Tester Cloud servers switched off
MF  2  05:30:59.543 Tester tester not started because the account is not specified
"@

if (-not (Test-TesterLogShowsAccountNotSpecified -TesterLogTail $accountMissingTail)) {
    throw "Missing account tester log marker was not detected."
}

$ordinaryReportMissingTail = @"
AA  0  05:30:59.107 Tester Cloud servers switched off
BB  2  05:30:59.543 Tester report export path was not created yet
"@

if (Test-TesterLogShowsAccountNotSpecified -TesterLogTail $ordinaryReportMissingTail) {
    throw "Generic report-missing wording was incorrectly treated as account missing."
}

Write-Host "PASS Test-RunSmokeAccountNotSpecified"
