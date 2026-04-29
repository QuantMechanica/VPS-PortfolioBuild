[CmdletBinding()]
param(
    [string]$TaskName = "QM_RuntimeHealthScan_15min",
    [string]$RepoRoot = "C:\QM\repo",
    [string]$ScriptRelativePath = "infra\scripts\Run-RuntimeHealthScan.ps1",
    [string]$OutputPath = "C:\QM\logs\infra\health\runtime_health_scan_latest.json",
    [int]$MinuteOffset = 1,
    [int]$EveryMinutes = 15,
    [switch]$FailOnFinding,
    [switch]$DryRun,
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($EveryMinutes -lt 1) {
    throw "EveryMinutes must be >= 1."
}

$scriptPath = Join-Path $RepoRoot $ScriptRelativePath
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Runtime health scan script not found: $scriptPath"
}

$minuteOffset = [Math]::Max(0, [Math]::Min(59, $MinuteOffset))
$startBoundary = (Get-Date).Date.AddHours((Get-Date).Hour).AddMinutes($minuteOffset)
if ($startBoundary -le (Get-Date)) {
    $startBoundary = $startBoundary.AddMinutes($EveryMinutes)
}

$args = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -OutputPath `"$OutputPath`""
if ($FailOnFinding.IsPresent) { $args += " -FailOnFinding" }
if ($DryRun.IsPresent) { $args += " -DryRun" }

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
