[CmdletBinding()]
param(
    [string]$TaskName = "QM_PaperclipStaleLockWatchdog_15min",
    [string]$RepoRoot = "C:\QM\repo",
    [string]$ScriptRelativePath = "infra\monitoring\Invoke-PaperclipStaleLockWatchdog.ps1",
    [int]$MinuteOffset = 3,
    [int]$StaleAfterMinutes = 15,
    [int]$RunningLockMaxMinutes = 90,
    [string]$PaperclipApiUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { "" }),
    [string]$CompanyId = $(if ($env:PAPERCLIP_COMPANY_ID) { $env:PAPERCLIP_COMPANY_ID } else { "" }),
    [string]$AssigneeAgentId = $(if ($env:PAPERCLIP_AGENT_ID) { $env:PAPERCLIP_AGENT_ID } else { "" }),
    [string]$OutPath = "C:\QM\logs\infra\health\paperclip_stale_lock_watchdog_latest.json",
    [switch]$FailOnFinding,
    [switch]$PreviewOnly,
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

$actionArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -StaleAfterMinutes $StaleAfterMinutes -RunningLockMaxMinutes $RunningLockMaxMinutes"
if (-not [string]::IsNullOrWhiteSpace($PaperclipApiUrl)) {
    $actionArgs += " -PaperclipApiUrl `"$PaperclipApiUrl`""
}
if (-not [string]::IsNullOrWhiteSpace($CompanyId)) {
    $actionArgs += " -CompanyId `"$CompanyId`""
}
if (-not [string]::IsNullOrWhiteSpace($AssigneeAgentId)) {
    $actionArgs += " -AssigneeAgentId `"$AssigneeAgentId`""
}
if (-not [string]::IsNullOrWhiteSpace($OutPath)) {
    $actionArgs += " -OutPath `"$OutPath`""
}
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
if ($PreviewOnly.IsPresent) {
    Write-Host "PreviewOnly: no scheduler mutations applied."
    Write-Host "TaskName: $TaskName"
    Write-Host "StartBoundary: $($startBoundary.ToString('o'))"
    Write-Host "Action: powershell.exe $actionArgs"
    Write-Host "Principal: SYSTEM, MultipleInstances=IgnoreNew, Repetition=15m"
    exit 0
}

Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Host "Task '$TaskName' is configured. Next run: $($taskInfo.NextRunTime)"
Write-Host "Action: powershell.exe $actionArgs"
Write-Host "Principal: SYSTEM, MultipleInstances=IgnoreNew, Repetition=15m"

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task '$TaskName' started on demand."
}
