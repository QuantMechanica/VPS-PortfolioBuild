[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonExe = "python",
    [string]$DwxHourlyScript = "C:\QM\repo\infra\scripts\dwx_hourly_check.py",
    [string]$SnapshotScript = "C:\QM\repo\scripts\export_public_snapshot.ps1",
    [string]$HealthScript = "C:\QM\repo\infra\monitoring\Invoke-InfraHealthCheck.ps1",
    [string]$BackupScript = "C:\QM\repo\infra\backup.ps1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Register-DesiredTask {
    param(
        [string]$TaskName,
        [string]$Executable,
        [string]$Arguments,
        [Microsoft.Management.Infrastructure.CimInstance]$Trigger,
        [string]$Description,
        [string]$WorkingDirectory = ""
    )

    $action = New-ScheduledTaskAction -Execute $Executable -Argument $Arguments
    if ($WorkingDirectory) {
        $action.WorkingDirectory = $WorkingDirectory
    }
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $Trigger `
        -Settings $settings `
        -Principal $principal `
        -Description $Description `
        -Force | Out-Null
    Write-Host "Converged task: $TaskName"
}

function New-RepeatingTriggerFromToday {
    param(
        [Parameter(Mandatory = $true)] [datetime]$AtTime,
        [Parameter(Mandatory = $true)] [timespan]$Interval,
        [Parameter(Mandatory = $true)] [timespan]$Duration
    )

    $todayStart = (Get-Date).Date.AddHours($AtTime.Hour).AddMinutes($AtTime.Minute)
    return New-ScheduledTaskTrigger -Once -At $todayStart -RepetitionInterval $Interval -RepetitionDuration $Duration
}

# Hourly public snapshot export at HH:07
$snapshotTrigger = New-RepeatingTriggerFromToday `
    -AtTime (Get-Date "00:07") `
    -Interval (New-TimeSpan -Hours 1) `
    -Duration (New-TimeSpan -Days 3650)
Register-DesiredTask `
    -TaskName "QM_PublicSnapshot_Export_Hourly" `
    -Executable "powershell.exe" `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SnapshotScript`"" `
    -Trigger $snapshotTrigger `
    -Description "Exports public-data snapshot JSON hourly and publishes if changed." `
    -WorkingDirectory $RepoRoot

# DWX hourly orchestrator, only if source script exists
if (Test-Path -LiteralPath $DwxHourlyScript) {
    $dwxTrigger = New-RepeatingTriggerFromToday `
        -AtTime (Get-Date "00:11") `
        -Interval (New-TimeSpan -Hours 1) `
        -Duration (New-TimeSpan -Days 3650)
    Register-DesiredTask `
        -TaskName "QM_DWX_HourlyCheck" `
        -Executable $PythonExe `
        -Arguments "`"$DwxHourlyScript`"" `
        -Trigger $dwxTrigger `
        -Description "Runs DWX import orchestrator hourly."
}
else {
    Write-Warning "DWX orchestrator script missing; skipped QM_DWX_HourlyCheck registration."
}

# Infra health monitor every 5 minutes
$healthTrigger = New-RepeatingTriggerFromToday `
    -AtTime (Get-Date "00:00") `
    -Interval (New-TimeSpan -Minutes 5) `
    -Duration (New-TimeSpan -Days 3650)
Register-DesiredTask `
    -TaskName "QM_InfraHealthCheck_5min" `
    -Executable "powershell.exe" `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$HealthScript`"" `
    -Trigger $healthTrigger `
    -Description "Checks infra health: disk, MT5 heartbeat, Paperclip daemon, Drive sync, stale index.lock."

# Daily backup at 02:15
$backupTrigger = New-ScheduledTaskTrigger -Daily -At "02:15"
Register-DesiredTask `
    -TaskName "QM_Backup_Daily_0215" `
    -Executable "powershell.exe" `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$BackupScript`"" `
    -Trigger $backupTrigger `
    -Description "Runs daily backup workflow with retention."
