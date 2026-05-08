param(
    [string]$StrategyId = 'QM5_1004',
    [string]$Symbol = 'US500.DWX',
    [string[]]$Timeframes = @('H1', 'H4', 'D1'),
    [string]$Mt5Root = 'D:\QM\mt5',
    [string]$ReportRoot = 'D:\QM\reports',
    [string]$SmokeLog = 'infra\smoke\qua774_blocker_refresh_task.log'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$summaryScript = Join-Path $repoRoot 'infra\scripts\Test-P2RedeploySummary.ps1'
$statusScript = Join-Path $repoRoot 'infra\scripts\Update-QUA774BlockerStatus.ps1'
$smokeLogFull = Join-Path $repoRoot $SmokeLog

foreach ($path in @($summaryScript, $statusScript)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required script missing: $path"
    }
}

$smokeDir = Split-Path -Parent $smokeLogFull
if ($smokeDir -and -not (Test-Path -LiteralPath $smokeDir)) {
    New-Item -ItemType Directory -Path $smokeDir -Force | Out-Null
}

$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$summaryOut = Join-Path $repoRoot ("docs\ops\QUA-774_P2_REDEPLOY_SUMMARY_{0}.json" -f $ts)

Add-Content -LiteralPath $smokeLogFull -Value ("[{0}] run=start strategy={1} symbol={2}" -f ((Get-Date).ToUniversalTime().ToString('o')), $StrategyId, $Symbol)

$summaryArgs = @{
    StrategyId = $StrategyId
    Symbol = $Symbol
    Timeframes = $Timeframes
    Mt5Root = $Mt5Root
    ReportRoot = $ReportRoot
    JsonOut = $summaryOut
}
& $summaryScript @summaryArgs | Out-Null

$status = & $statusScript

Add-Content -LiteralPath $smokeLogFull -Value ("[{0}] run=done summary={1}" -f ((Get-Date).ToUniversalTime().ToString('o')), $summaryOut)
$status
