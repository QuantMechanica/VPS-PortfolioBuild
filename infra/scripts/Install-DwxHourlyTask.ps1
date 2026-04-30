[CmdletBinding()]
param(
    [string]$TaskName = 'QM_DWX_HourlyCheck',
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$ScriptRelativePath = 'infra\scripts\Invoke-DwxHourlyCheck.ps1',
    [int]$MinuteOffset = 7,
    [switch]$PreviewOnly,
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $RepoRoot $ScriptRelativePath
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "DWX script not found: $scriptPath"
}

$minuteOffset = [Math]::Max(0, [Math]::Min(59, $MinuteOffset))
$now = Get-Date
$startBoundary = $now.Date.AddHours($now.Hour).AddMinutes($minuteOffset)
if ($startBoundary -le $now) {
    do {
        $startBoundary = $startBoundary.AddHours(1)
    } while ($startBoundary -le $now)
}

$actionArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $actionArgs -WorkingDirectory $RepoRoot
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary -RepetitionInterval (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 55)

$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
if ($PreviewOnly.IsPresent) {
    [pscustomobject]@{
        preview = $true
        task_name = $TaskName
        execute = "powershell.exe"
        arguments = $actionArgs
        working_directory = $RepoRoot
        start_boundary_local = $startBoundary.ToString("o")
        repetition_minutes = 60
        principal = "SYSTEM"
        run_level = "Highest"
    } | ConvertTo-Json -Depth 5
    exit 0
}
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

$registered = Get-ScheduledTask -TaskName $TaskName
$nextRun = (Get-ScheduledTaskInfo -TaskName $TaskName).NextRunTime
Write-Host "Task '$TaskName' is configured. Next run: $nextRun"
Write-Host "Action: powershell.exe $actionArgs"
Write-Host "Principal: $($registered.Principal.UserId)"

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task '$TaskName' started on demand."
}
