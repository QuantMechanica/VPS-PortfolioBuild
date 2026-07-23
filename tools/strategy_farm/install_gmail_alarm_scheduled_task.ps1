[CmdletBinding()]
param(
    [string]$TaskName = "QM_StrategyFarm_GmailAlarm_Hourly",
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonwExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe",
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$wrapper = Join-Path $RepoRoot "tools\strategy_farm\run_gmail_alarm_task.py"
if (-not (Test-Path -LiteralPath $PythonwExe)) {
    throw "pythonw.exe not found: $PythonwExe"
}
if (-not (Test-Path -LiteralPath $wrapper)) {
    throw "Wrapper not found: $wrapper"
}
if ($RunNow.IsPresent) {
    throw "-RunNow is unavailable: the pipeline FAIL/OK mail channel is OWNER-disabled."
}

$action = New-ScheduledTaskAction `
    -Execute $PythonwExe `
    -Argument "`"$wrapper`"" `
    -WorkingDirectory $RepoRoot

$startBoundary = (Get-Date).Date.AddHours((Get-Date).Hour).AddMinutes(0)
if ($startBoundary -le (Get-Date)) {
    $startBoundary = $startBoundary.AddHours(1)
}
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary `
    -RepetitionInterval (New-TimeSpan -Hours 1) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Legacy PIPELINE FAIL/OK mail channel. OWNER-disabled by default since 2026-07-23; MorningBriefing is separate." `
    -User "SYSTEM" `
    -RunLevel Highest `
    -Force | Out-Null

Disable-ScheduledTask -TaskName $TaskName | Out-Null

Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo
