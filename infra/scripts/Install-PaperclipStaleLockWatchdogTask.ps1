[CmdletBinding()]
param(
    [string]$TaskName = "QM_PaperclipStaleLockWatchdog_15min",
    [string]$RepoRoot = "C:\QM\repo",
    [string]$ScriptRelativePath = "infra\monitoring\Invoke-PaperclipStaleLockWatchdog.ps1",
    [int]$MinuteOffset = 3,
    [int]$StaleAfterMinutes = 15,
    [switch]$FailOnFinding,
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $RepoRoot $ScriptRelativePath
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Paperclip stale-lock watchdog script not found: $scriptPath"
}

$minuteOffset = [Math]::Max(0, [Math]::Min(59, $MinuteOffset))
$startBoundary = (Get-Date).Date.AddHours((Get-Date).Hour).AddMinutes($minuteOffset)
if ($startBoundary -le (Get-Date)) {
    $startBoundary = $startBoundary.AddMinutes(15)
}

$actionArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -StaleAfterMinutes $StaleAfterMinutes"
if ($FailOnFinding.IsPresent) {
    $actionArgs += " -FailOnFinding"
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $actionArgs -WorkingDirectory $RepoRoot
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary -RepetitionInterval (New-TimeSpan -Minutes 15)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Host "Task '$TaskName' is configured. Next run: $($taskInfo.NextRunTime)"
Write-Host "Action: powershell.exe $actionArgs"
Write-Host "Principal: SYSTEM, MultipleInstances=IgnoreNew, Repetition=15m"

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task '$TaskName' started on demand."
}
