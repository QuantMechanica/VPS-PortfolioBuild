[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$taskName = "QM_StrategyFarm_ClaudeVerify_4h"
$runner = Join-Path $RepoRoot "tools\strategy_farm\run_claude_verify_4h.ps1"
if (-not (Test-Path -LiteralPath $runner)) {
    throw "Runner not found: $runner"
}

$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).Date) `
    -RepetitionInterval (New-TimeSpan -Hours 4) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 4)

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$runner`""
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument $arguments `
    -WorkingDirectory $RepoRoot

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Headless Claude 4-hour Strategy Farm verification and REVIEW-resolution pass." `
    -Force | Out-Null

Enable-ScheduledTask -TaskName $taskName | Out-Null

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $taskName
}

$task = Get-ScheduledTask -TaskName $taskName
$info = Get-ScheduledTaskInfo -TaskName $taskName
[pscustomobject]@{
    TaskName = $task.TaskName
    State = $task.State
    UserId = $task.Principal.UserId
    LogonType = $task.Principal.LogonType
    RunLevel = $task.Principal.RunLevel
    Execute = $task.Actions.Execute
    Arguments = $task.Actions.Arguments
    RepetitionInterval = $task.Triggers[0].Repetition.Interval
    LastTaskResult = $info.LastTaskResult
    NextRunTime = $info.NextRunTime
}
