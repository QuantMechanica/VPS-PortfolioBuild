param(
    [string]$RepoRoot = 'C:\QM\repo'
)

$set1 = Join-Path $RepoRoot 'framework\EAs\QM5_1003_davey_baseline_3bar\sets\QM5_1003_davey_baseline_3bar_AUDCHF.DWX_M15_backtest.set'
$set2 = Join-Path $RepoRoot 'framework\EAs\QM5_1003_davey_baseline_3bar\sets\QM5_1003_davey_baseline_3bar_EURNZD.DWX_M15_backtest.set'

$ok1 = Test-Path -LiteralPath $set1
$ok2 = Test-Path -LiteralPath $set2

if ($ok1 -and $ok2) {
    Write-Output "status=READY missing=0"
    exit 0
}

$missing = @()
if (-not $ok1) { $missing += $set1 }
if (-not $ok2) { $missing += $set2 }
Write-Output ("status=BLOCKED missing=" + $missing.Count)
$missing | ForEach-Object { Write-Output ("missing_setfile=" + $_) }
exit 2
