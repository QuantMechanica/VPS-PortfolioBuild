[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$BlockerStatusPath = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json',
    [string]$ReadinessPath = 'docs\ops\QUA-95_UNBLOCK_READINESS_2026-04-27.json',
    [int]$MaxLagMinutes = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$blockerFull = Join-Path $RepoRoot $BlockerStatusPath
$readinessFull = Join-Path $RepoRoot $ReadinessPath

if (-not (Test-Path -LiteralPath $blockerFull)) {
    Write-Host ("status=critical reason=blocker_status_missing path={0}" -f $blockerFull)
    exit 1
}
if (-not (Test-Path -LiteralPath $readinessFull)) {
    Write-Host ("status=critical reason=unblock_readiness_missing path={0}" -f $readinessFull)
    exit 1
}

$blocker = Get-Content -Raw -LiteralPath $blockerFull | ConvertFrom-Json
$readiness = Get-Content -Raw -LiteralPath $readinessFull | ConvertFrom-Json

$blockerChecked = Get-Date $blocker.last_checked_local
$readinessWrite = (Get-Item -LiteralPath $readinessFull).LastWriteTime
$lag = [math]::Round(([math]::Abs(($readinessWrite - $blockerChecked).TotalMinutes)), 2)
$ownersCount = @($readiness.unblock_owners).Count
$readyFlag = [bool]$readiness.readiness.ready_to_unblock
$barsGot = [int]$readiness.current.bars_got

$issues = @()
if ($lag -gt $MaxLagMinutes) { $issues += ("lag_minutes={0}" -f $lag) }
if ($ownersCount -lt 1) { $issues += 'missing_unblock_owners' }
if ($barsGot -le 0 -and $readyFlag) { $issues += 'ready_flag_invalid_for_zero_bars' }

if ($issues.Count -gt 0) {
    Write-Host ("status=critical issues={0} lag_minutes={1} ready_to_unblock={2} bars_got={3} owner_count={4}" -f `
        ($issues -join ','), $lag, $readyFlag, $barsGot, $ownersCount)
    exit 1
}

Write-Host ("status=ok lag_minutes={0} ready_to_unblock={1} bars_got={2} owner_count={3}" -f `
    $lag, $readyFlag, $barsGot, $ownersCount)
exit 0
