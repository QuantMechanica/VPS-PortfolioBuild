[CmdletBinding()]
param(
    [string]$TaskName = 'QM_QUA95_BlockedHeartbeat_60min',
    [string]$RepoRoot = 'C:\QM\repo',
    [int]$EveryMinutes = 60,
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($EveryMinutes -lt 15) {
    throw "EveryMinutes must be >= 15."
}

$heartbeatScript = Join-Path $RepoRoot 'infra\scripts\Invoke-QUA95BlockedHeartbeat.ps1'
if (-not (Test-Path -LiteralPath $heartbeatScript)) {
    throw "Heartbeat script missing: $heartbeatScript"
}

$args = "-NoProfile -ExecutionPolicy Bypass -File `"$heartbeatScript`" -RepoRoot `"$RepoRoot`""
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $args
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(3) `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

if ($PreviewOnly) {
    Write-Host ("preview_task_name={0}" -f $TaskName)
    Write-Host ("preview_interval_minutes={0}" -f $EveryMinutes)
    Write-Host ("preview_action=PowerShell {0}" -f $args)
    exit 0
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Host ("installed_task={0}" -f $TaskName)
exit 0
