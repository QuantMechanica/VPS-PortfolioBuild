[CmdletBinding()]
param(
    [string]$TaskName = "QM_Public_Snapshot_Hourly",
    [string]$RepoRoot = "C:\QM\repo",
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$wrapper = Join-Path $RepoRoot "scripts\run_public_snapshot_task.ps1"
if (-not (Test-Path -LiteralPath $wrapper)) {
    throw "Wrapper not found: $wrapper"
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$wrapper`"" `
    -WorkingDirectory $RepoRoot

$startBoundary = (Get-Date).Date.AddHours((Get-Date).Hour).AddMinutes(7)
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
    -ExecutionTimeLimit (New-TimeSpan -Minutes 20)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Builds pipeline_state.json and refreshes public-data snapshot JSON hourly." `
    -User "SYSTEM" `
    -RunLevel Highest `
    -Force | Out-Null

Enable-ScheduledTask -TaskName $TaskName | Out-Null

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $TaskName
}

Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo
