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

$terminalParameter = $ast.ParamBlock.Parameters | Where-Object {
    $_.Name.VariablePath.UserPath -eq "Terminal"
}
if (-not $terminalParameter) {
    throw "Terminal parameter not found."
}

$validateSet = $terminalParameter.Attributes | Where-Object {
    $_ -is [System.Management.Automation.Language.AttributeAst] -and
        $_.TypeName.FullName -eq "ValidateSet"
}
if (-not $validateSet) {
    throw "Terminal ValidateSet not found."
}

$allowedTerminals = @($validateSet.PositionalArguments | ForEach-Object { [string]$_.SafeGetValue() })
$expectedTerminals = @("any", "DEV1", "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10")
if ([string]::Join("|", $allowedTerminals) -cne [string]::Join("|", $expectedTerminals)) {
    throw "Unexpected Terminal ValidateSet: $([string]::Join(', ', $allowedTerminals))"
}
foreach ($forbidden in @("T_Live", "DEV2", "LOCAL", "T11")) {
    if ($allowedTerminals -contains $forbidden) {
        throw "Forbidden terminal '$forbidden' is present in Terminal ValidateSet."
    }
}

try {
    & $scriptPath -Symbol "NDX.DWX" -Year 2024 -Terminal "DEV1" -AllowRunningTerminal
    throw "DEV1 was allowed with -AllowRunningTerminal."
} catch {
    if ($_.Exception.Message -like "DEV1 was allowed*") {
        throw
    }
    if ($_.Exception.Message -notlike "*Refusing -Terminal DEV1 with -AllowRunningTerminal*") {
        throw "Unexpected DEV1/AllowRunningTerminal rejection: $($_.Exception.Message)"
    }
}

$expectedDev1Sid = (New-Object System.Security.Principal.NTAccount("$env:COMPUTERNAME\QMDev1")).Translate([System.Security.Principal.SecurityIdentifier]).Value
$currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
if ($currentSid -cne $expectedDev1Sid) {
    try {
        & $scriptPath -EAId 20009 -Symbol "NDX.DWX" -Year 2024 -Terminal "DEV1"
        throw "DEV1 was allowed under a non-QMDev1 Windows identity."
    } catch {
        if ($_.Exception.Message -like "DEV1 was allowed*") {
            throw
        }
        if ($_.Exception.Message -notlike "*DEV1 requires the isolated*$env:COMPUTERNAME\QMDev1*identity*") {
            throw "Unexpected DEV1 identity rejection: $($_.Exception.Message)"
        }
    }
}

$resolveRootAst = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq "Resolve-TerminalRoot"
}, $true)
if (-not $resolveRootAst) {
    throw "Resolve-TerminalRoot function not found."
}
Invoke-Expression $resolveRootAst.Extent.Text

$script:existingTerminalRoots = @(
    "D:\QM\mt5\DEV1",
    "D:\QM\mt5\T1"
)
function Test-Path {
    param(
        [string]$LiteralPath,
        [object]$PathType
    )
    return $script:existingTerminalRoots -contains $LiteralPath
}
function Resolve-Path {
    param([string]$LiteralPath)
    return [pscustomobject]@{ Path = $LiteralPath }
}

if ((Resolve-TerminalRoot -TerminalName "DEV1") -cne "D:\QM\mt5\DEV1") {
    throw "Explicit DEV1 did not resolve to D:\QM\mt5\DEV1."
}
if ((Resolve-TerminalRoot -TerminalName "T1") -cne "D:\QM\mt5\T1") {
    throw "Factory terminal T1 no longer resolves normally."
}
foreach ($forbidden in @("T_Live", "DEV2", "LOCAL", "..\T_Live")) {
    try {
        $null = Resolve-TerminalRoot -TerminalName $forbidden
        throw "Forbidden terminal '$forbidden' was accepted by Resolve-TerminalRoot."
    } catch {
        if ($_.Exception.Message -like "Forbidden terminal*") {
            throw
        }
    }
}

$resolveDispatchAst = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq "Resolve-DispatchTerminal"
}, $true)
if (-not $resolveDispatchAst) {
    throw "Resolve-DispatchTerminal function not found."
}
$runSmokeScriptRoot = Split-Path -Parent $scriptPath
$resolveDispatchText = $resolveDispatchAst.Extent.Text.Replace('$PSScriptRoot', "'$($runSmokeScriptRoot.Replace("'", "''"))'")
Invoke-Expression $resolveDispatchText

$dispatchArgs = @{
    EAIdValue = 20009
    SymbolName = "NDX.DWX"
    PeriodName = "M1"
    YearValue = 2024
    DispatchPhaseValue = "P1"
    DispatchVersionValue = "smoke"
    DispatchSubGateHashValue = "dev1-static-test"
}

$explicitDev = Resolve-DispatchTerminal -TargetTerminal "DEV1" @dispatchArgs
if ($explicitDev -cne "DEV1") {
    throw "Explicit DEV1 dispatch changed to '$explicitDev'."
}

$script:factoryCandidates = New-Object System.Collections.Generic.List[string]
function Resolve-TerminalRoot {
    param([string]$TerminalName)
    $script:factoryCandidates.Add($TerminalName)
    return "D:\QM\mt5\$TerminalName"
}
function Test-TerminalAlreadyRunning {
    param([string]$TerminalRoot)
    return $true
}

try {
    $null = Resolve-DispatchTerminal -TargetTerminal "any" -SetFilePath "" @dispatchArgs
    throw "Factory fallback unexpectedly found a free terminal."
} catch {
    if ($_.Exception.Message -like "Factory fallback unexpectedly*") {
        throw
    }
}
$expectedFactoryCandidates = @("T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10")
if ([string]::Join("|", $script:factoryCandidates) -cne [string]::Join("|", $expectedFactoryCandidates)) {
    throw "-Terminal any fallback candidates drifted: $([string]::Join(', ', $script:factoryCandidates))"
}
if ($script:factoryCandidates -contains "DEV1") {
    throw "DEV1 leaked into the -Terminal any fallback candidate list."
}

$runSmokeText = [System.IO.File]::ReadAllText($scriptPath)
if ($runSmokeText -notlike '*DEV1 ReportRoot must stay under*D:\QM\reports\dev1*') {
    throw "DEV1 does not fail closed when ReportRoot escapes D:\QM\reports\dev1."
}
if ($runSmokeText -notlike '*post_run_pump_skipped (DEV1 isolation)*') {
    throw "DEV1 still lacks an explicit post-run pump isolation branch."
}
if ($runSmokeText -notlike '*Join-Path $resolvedReportRoot "_framework_evidence\22"*') {
    throw "DEV1 framework evidence is not rooted beneath its isolated ReportRoot."
}
if ($runSmokeText -notlike '*WindowsIdentity]::GetCurrent().User.Value*' -or
    $runSmokeText -notlike '*DEV1 requires the isolated*QMDev1*identity*') {
    throw "DEV1 lacks the exact Windows SID identity guard."
}
$reportBoundaryIndex = $runSmokeText.IndexOf('DEV1 ReportRoot must stay under')
$idleBoundaryIndex = $runSmokeText.IndexOf('if (($Terminal -ine "any") -and (-not $AllowRunningTerminal.IsPresent))')
$terminalMutationIndex = $runSmokeText.IndexOf('Set-BacktestTerminalConfig -TerminalRoot $terminalRoot')
$expertMutationIndex = $runSmokeText.IndexOf('Deploy-ExpertBinaryToTerminal -ExpertPath $Expert')
if ($reportBoundaryIndex -lt 0 -or $idleBoundaryIndex -lt 0 -or
    $terminalMutationIndex -lt 0 -or $expertMutationIndex -lt 0 -or
    $reportBoundaryIndex -ge $terminalMutationIndex -or
    $idleBoundaryIndex -ge $terminalMutationIndex -or
    $reportBoundaryIndex -ge $expertMutationIndex) {
    throw "DEV1 isolation checks no longer precede terminal mutations."
}

function Get-QmTempDirectory { return "C:\QM\tmp" }
function Test-Path {
    param(
        [string]$LiteralPath,
        [object]$PathType
    )
    return $LiteralPath.EndsWith("resolve_backtest_target.py")
}
function Set-Content {
    param(
        [string]$LiteralPath,
        [object]$Value,
        [object]$Encoding
    )
}
function Remove-Item {
    param(
        [string]$LiteralPath,
        [switch]$Force
    )
}
function python {
    param([Parameter(ValueFromRemainingArguments = $true)][object[]]$Arguments)
    return '{"status":"assigned","terminal":"DEV1"}'
}
$global:LASTEXITCODE = 0

try {
    $null = Resolve-DispatchTerminal -TargetTerminal "any" -SetFilePath "C:\QM\sets\candidate.set" @dispatchArgs
    throw "External any-resolver was allowed to return DEV1."
} catch {
    if ($_.Exception.Message -like "External any-resolver was allowed*") {
        throw
    }
    if ($_.Exception.Message -notlike "*non-factory terminal 'DEV1'*") {
        throw "Unexpected resolver rejection: $($_.Exception.Message)"
    }
}

Write-Host "PASS Test-RunSmokeDev1Terminal"
