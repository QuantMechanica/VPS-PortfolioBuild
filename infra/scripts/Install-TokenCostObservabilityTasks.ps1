[CmdletBinding()]
param(
    [string]$TaskName = "QM_TokenCostBudgetHealth_15min",
    [string]$DailySnapshotTaskName = "QM_TokenCostBudgetDailySnapshot_0010",
    [string]$RepoRoot = "C:\QM\repo",
    [string]$ScriptRelativePath = "infra\monitoring\Test-TokenCostBudgetHealth.ps1",
    [int]$MinuteOffset = 5,
    [int]$EveryMinutes = 15,
    [int64]$DailyTokenBudget = 2500000,
    [int]$WarnThresholdPct = 70,
    [int]$HighWarnThresholdPct = 80,
    [int]$CriticalThresholdPct = 95,
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($EveryMinutes -lt 1) { throw "EveryMinutes must be >= 1." }
if ($DailyTokenBudget -le 0) { throw "DailyTokenBudget must be > 0." }

$scriptPath = Join-Path $RepoRoot $ScriptRelativePath
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Token-cost health script not found: $scriptPath"
}

$offset = [Math]::Max(0, [Math]::Min(59, $MinuteOffset))
$now = Get-Date
$startBoundary = $now.Date.AddHours($now.Hour).AddMinutes($offset)
if ($startBoundary -le $now) {
    do {
        $startBoundary = $startBoundary.AddMinutes($EveryMinutes)
    } while ($startBoundary -le $now)
}

$baseArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -DailyTokenBudget $DailyTokenBudget -WarnThresholdPct $WarnThresholdPct -HighWarnThresholdPct $HighWarnThresholdPct -CriticalThresholdPct $CriticalThresholdPct"

$healthAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $baseArgs -WorkingDirectory $RepoRoot
$healthTrigger = New-ScheduledTaskTrigger -Once -At $startBoundary -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

$healthTask = New-ScheduledTask -Action $healthAction -Trigger $healthTrigger -Principal $principal -Settings $settings
Register-ScheduledTask -TaskName $TaskName -InputObject $healthTask -Force | Out-Null

$snapshotArgs = $baseArgs
$snapshotAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $snapshotArgs -WorkingDirectory $RepoRoot
$snapshotTrigger = New-ScheduledTaskTrigger -Daily -At "00:10"
$snapshotTask = New-ScheduledTask -Action $snapshotAction -Trigger $snapshotTrigger -Principal $principal -Settings $settings
Register-ScheduledTask -TaskName $DailySnapshotTaskName -InputObject $snapshotTask -Force | Out-Null

$healthInfo = Get-ScheduledTaskInfo -TaskName $TaskName
$snapshotInfo = Get-ScheduledTaskInfo -TaskName $DailySnapshotTaskName
Write-Host "Task '$TaskName' configured. Next run: $($healthInfo.NextRunTime)"
Write-Host "Task '$DailySnapshotTaskName' configured. Next run: $($snapshotInfo.NextRunTime)"
Write-Host "Action: powershell.exe $baseArgs"

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task '$TaskName' started on demand."
}
