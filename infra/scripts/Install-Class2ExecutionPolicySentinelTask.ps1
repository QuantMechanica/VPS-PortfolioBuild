[CmdletBinding()]
param(
    [string]$TaskName = "QM_Class2ExecutionPolicySentinel_60min",
    [string]$RepoRoot = "C:\QM\repo",
    [string]$ScriptRelativePath = "infra\monitoring\Test-Class2ExecutionPolicySentinel.ps1",
    [int]$MinuteOffset = 8,
    [int]$EveryMinutes = 60,
    [switch]$ApplyMissingPolicy,
    [switch]$FailOnFinding,
    [switch]$RunNow,
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($EveryMinutes -lt 1) {
    throw "EveryMinutes must be >= 1."
}

$scriptPath = Join-Path $RepoRoot $ScriptRelativePath
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Class-2 execution-policy sentinel script not found: $scriptPath"
}

$minuteOffset = [Math]::Max(0, [Math]::Min(59, $MinuteOffset))
$now = Get-Date
$startBoundary = $now.Date.AddHours($now.Hour).AddMinutes($minuteOffset)
if ($startBoundary -le $now) {
    do {
        $startBoundary = $startBoundary.AddMinutes($EveryMinutes)
    } while ($startBoundary -le $now)
}

$args = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
if ($ApplyMissingPolicy.IsPresent) { $args += " -ApplyMissingPolicy" }
if ($FailOnFinding.IsPresent) { $args += " -FailOnFinding" }

$preview = [ordered]@{
    preview_only = [bool]$PreviewOnly.IsPresent
    task_name = $TaskName
    script_path = $scriptPath
    every_minutes = $EveryMinutes
    minute_offset = $minuteOffset
    next_start_boundary = $startBoundary.ToString("o")
    action = "powershell.exe $args"
    principal = "SYSTEM"
    multiple_instances = "IgnoreNew"
}

if ($PreviewOnly.IsPresent) {
    $preview | ConvertTo-Json -Depth 6
    exit 0
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $args -WorkingDirectory $RepoRoot
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Host "Task '$TaskName' is configured. Next run: $($taskInfo.NextRunTime)"
Write-Host "Action: powershell.exe $args"
Write-Host "Principal: SYSTEM, MultipleInstances=IgnoreNew, Repetition=$($EveryMinutes)m"

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task '$TaskName' started on demand."
}
