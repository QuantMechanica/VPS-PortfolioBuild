[CmdletBinding()]
param(
    [string]$TaskName = "QM_GitIndexLockMonitor_10min",
    [string]$RepoRoot = "C:\QM\repo",
    [string]$ScriptRelativePath = "infra\monitoring\Invoke-GitIndexLockMonitor.ps1",
    [int]$MinuteOffset = 2,
    [int]$EveryMinutes = 10,
    [int]$StaleAfterMinutes = 20,
    [switch]$FailOnFinding,
    [switch]$AutoCleanup,
    [switch]$PreviewOnly,
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($EveryMinutes -lt 1) {
    throw "EveryMinutes must be >= 1."
}

$scriptPath = Join-Path $RepoRoot $ScriptRelativePath
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Git index lock monitor script not found: $scriptPath"
}

$minuteOffset = [Math]::Max(0, [Math]::Min(59, $MinuteOffset))
$now = Get-Date
$startBoundary = $now.Date.AddHours($now.Hour).AddMinutes($minuteOffset)
if ($startBoundary -le $now) {
    do {
        $startBoundary = $startBoundary.AddMinutes($EveryMinutes)
    } while ($startBoundary -le $now)
}

$args = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -StaleAfterMinutes $StaleAfterMinutes"
if ($FailOnFinding.IsPresent) { $args += " -FailOnFinding" }
if ($AutoCleanup.IsPresent) { $args += " -AutoCleanup" }

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $args -WorkingDirectory $RepoRoot
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
if ($PreviewOnly.IsPresent) {
    [pscustomobject]@{
        preview = $true
        task_name = $TaskName
        execute = "powershell.exe"
        arguments = $args
        working_directory = $RepoRoot
        start_boundary_local = $startBoundary.ToString("o")
        repetition_minutes = $EveryMinutes
        principal = "SYSTEM"
        run_level = "Highest"
    } | ConvertTo-Json -Depth 5
    exit 0
}
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Host "Task '$TaskName' is configured. Next run: $($taskInfo.NextRunTime)"
Write-Host "Action: powershell.exe $args"
Write-Host "Principal: SYSTEM, MultipleInstances=IgnoreNew, Repetition=$($EveryMinutes)m"

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task '$TaskName' started on demand."
}
