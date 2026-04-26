[CmdletBinding()]
param(
    [string]$TaskName = 'QM_AggregatorState_1min',
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$PythonExe = 'python',
    [string]$ScriptRelativePath = 'scripts\aggregator\standalone_aggregator_loop.py',
    [int]$SecondOffset = 20,
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $RepoRoot $ScriptRelativePath
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Aggregator script not found: $scriptPath"
}

$offset = [Math]::Max(0, [Math]::Min(59, $SecondOffset))
$now = Get-Date
$startBoundary = Get-Date -Date $now.ToString('yyyy-MM-dd HH:mm:00')
$startBoundary = $startBoundary.AddSeconds($offset)
if ($startBoundary -le $now) {
    $startBoundary = $startBoundary.AddMinutes(1)
}

$args = "`"$scriptPath`" --once"
$action = New-ScheduledTaskAction -Execute $PythonExe -Argument $args -WorkingDirectory $RepoRoot
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary -RepetitionInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Seconds 45)

$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Host "Task '$TaskName' is configured. Next run: $($taskInfo.NextRunTime)"
Write-Host "Action: $PythonExe $args"
Write-Host "Principal: SYSTEM, MultipleInstances=IgnoreNew, Repetition=1m"

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task '$TaskName' started on demand."
}
