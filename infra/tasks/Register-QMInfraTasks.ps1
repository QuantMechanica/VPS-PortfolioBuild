[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonExe = "python",
    [string]$DwxHourlyScript = "D:\QM\mt5\T1\dwx_import\dwx_hourly_check.py",
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

    $desired = New-ScheduledTask -Action $action -Trigger $Trigger -Settings $settings -Principal $principal
    Register-ScheduledTask -TaskName $TaskName -InputObject $desired -Description $Description -Force | Out-Null
    Write-Host "Converged task: $TaskName"
}

# Hourly public snapshot export at HH:07
$snapshotTrigger = New-ScheduledTaskTrigger -Daily -At "00:07"
$snapshotTrigger.RepetitionInterval = "PT1H"
$snapshotTrigger.RepetitionDuration = "P1D"
Register-DesiredTask `
    -TaskName "QM_PublicSnapshot_Export_Hourly" `
    -Executable "powershell.exe" `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SnapshotScript`"" `
    -Trigger $snapshotTrigger `
    -Description "Exports public-data snapshot JSON hourly and publishes if changed." `
    -WorkingDirectory $RepoRoot

# DWX hourly orchestrator, only if source script exists
if (Test-Path -LiteralPath $DwxHourlyScript) {
    $dwxTrigger = New-ScheduledTaskTrigger -Daily -At "00:11"
    $dwxTrigger.RepetitionInterval = "PT1H"
    $dwxTrigger.RepetitionDuration = "P1D"
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
$healthTrigger = New-ScheduledTaskTrigger -Daily -At "00:00"
$healthTrigger.RepetitionInterval = "PT5M"
$healthTrigger.RepetitionDuration = "P1D"
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
