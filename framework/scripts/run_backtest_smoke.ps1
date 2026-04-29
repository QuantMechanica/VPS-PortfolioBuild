[CmdletBinding()]
param(
    [ValidateRange(2000, 2100)]
    [int]$Year = 2024,
    [ValidateSet("any", "T1", "T2", "T3", "T4", "T5")]
    [string]$Terminal = "T1",
    [string]$Symbol = "EURUSD.DWX",
    [string]$Period = "H1",
    [ValidateRange(60, 7200)]
    [int]$TimeoutSeconds = 1800,
    [string]$ReportRoot = "D:\QM\reports\smoke",
    [switch]$AllowRunningTerminal,
    [switch]$AllowMissingRealTicksLogMarker,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $Symbol.EndsWith(".DWX", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Backtest smoke requires a .DWX research/backtest symbol. Got '$Symbol'."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$setFile = Join-Path $repoRoot "framework\tests\smoke\QM5_1001_framework_smoke.set"
if (-not (Test-Path -LiteralPath $setFile -PathType Leaf)) {
    throw "Smoke set file not found: $setFile"
}

$runSmokePath = Join-Path $PSScriptRoot "run_smoke.ps1"
if (-not (Test-Path -LiteralPath $runSmokePath -PathType Leaf)) {
    throw "run_smoke.ps1 not found at $runSmokePath"
}

$resolvedTerminal = $Terminal
if ($Terminal -ieq "any") {
    $resolverPath = Join-Path $PSScriptRoot "resolve_backtest_target.py"
    if (-not (Test-Path -LiteralPath $resolverPath -PathType Leaf)) {
        throw "resolve_backtest_target.py not found at $resolverPath"
    }
    $jobPath = Join-Path $env:TEMP ("qua307_dispatch_job_{0}.json" -f [guid]::NewGuid().ToString("N"))
    $statePath = "D:\QM\Reports\pipeline\dispatch_state.json"
    $job = [ordered]@{
        ea_id = "QM5_1001"
        version = "smoke"
        symbol = $Symbol
        phase = "P1"
        sub_gate_config_hash = "{0}-{1}" -f $Period, $Year
        target_terminal = "any"
    } | ConvertTo-Json -Depth 4
    Set-Content -LiteralPath $jobPath -Value $job -Encoding utf8
    try {
        $raw = & python $resolverPath --job-json $jobPath --state-json $statePath --max-per-terminal 3
        if ($LASTEXITCODE -ne 0) {
            throw "resolve_backtest_target.py exited with code $LASTEXITCODE"
        }
        $decision = $raw | ConvertFrom-Json
        if (-not $decision.terminal) {
            throw "Terminal resolution returned no terminal. status=$($decision.status)"
        }
        $resolvedTerminal = [string]$decision.terminal
        Write-Output ("run_backtest_smoke.dispatch_status={0}" -f $decision.status)
        Write-Output ("run_backtest_smoke.dispatch_terminal={0}" -f $resolvedTerminal)
    } finally {
        if (Test-Path -LiteralPath $jobPath) {
            Remove-Item -LiteralPath $jobPath -Force
        }
    }
}

$invokeArgs = [ordered]@{
    EAId = 1001
    Expert = "QM\QM5_1001_framework_smoke"
    Symbol = $Symbol
    Year = $Year
    Terminal = $resolvedTerminal
    Period = $Period
    Runs = 2
    MinTrades = 0
    Model = 4
    TimeoutSeconds = $TimeoutSeconds
    SetFile = $setFile
    ReportRoot = $ReportRoot
}

$previewArgs = @(
    "-EAId", "1001",
    "-Expert", "QM\QM5_1001_framework_smoke",
    "-Symbol", $Symbol,
    "-Year", $Year.ToString(),
    "-Terminal", $resolvedTerminal,
    "-Period", $Period,
    "-Runs", "2",
    "-MinTrades", "0",
    "-Model", "4",
    "-TimeoutSeconds", $TimeoutSeconds.ToString(),
    "-SetFile", $setFile,
    "-ReportRoot", $ReportRoot
)

if ($AllowRunningTerminal.IsPresent) {
    $invokeArgs["AllowRunningTerminal"] = $true
    $previewArgs += "-AllowRunningTerminal"
}
if ($AllowMissingRealTicksLogMarker.IsPresent) {
    $invokeArgs["AllowMissingRealTicksLogMarker"] = $true
    $previewArgs += "-AllowMissingRealTicksLogMarker"
}

$commandPreview = "& `"$runSmokePath`" " + ($previewArgs -join " ")
Write-Output "run_backtest_smoke.command=$commandPreview"

if ($DryRun.IsPresent) {
    Write-Output "run_backtest_smoke.result=DRY_RUN"
    exit 0
}

& $runSmokePath @invokeArgs
exit $LASTEXITCODE
