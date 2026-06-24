[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$AtTime   = "04:30",   # daily local time; backtests run 24/7 so any low-stakes hour is fine
    [int]$MinHoursSinceReset = 18,
    [switch]$RunNow
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$taskName = "QM_StrategyFarm_FactoryRecycle_Daily"
$script   = Join-Path $RepoRoot "tools\strategy_farm\Factory_Recycle.ps1"
if (-not (Test-Path -LiteralPath $script)) { throw "recycle script not found: $script" }

# SYSTEM principal (same rationale as the watchdog installer): the recycle respawns
# workers INTO the interactive session via run_in_console_session.ps1
# (WTSQueryUserToken + CreateProcessAsUser), which only SYSTEM (SeTcb) can do. An
# Interactive-principal task could not respawn into a disconnected RDP session.
$trigger = New-ScheduledTaskTrigger -Daily -At $AtTime
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -MinHoursSinceReset $MinHoursSinceReset" `
    -WorkingDirectory $RepoRoot

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force `
    -Description "Factory preventive recycle (daily $AtTime, SYSTEM): proactively reclaims leaked session-global init resources (desktop heap / CSRSS / USER handles) that cause the 0xC0000142 launch_fault wedge, via an OFF/ON-equivalent reset. Adaptive: skips if a reset/recycle happened < ${MinHoursSinceReset}h ago (shares watchdog_realstall.json). Guards: OWNER ON/OFF, never touches T_Live. Evidence: D:\QM\reports\state\factory_recycle.log. Root cause: project_qm_launch_fault_wedge_manual_recovery_2026-06-24." | Out-Null
Enable-ScheduledTask -TaskName $taskName | Out-Null
if ($RunNow.IsPresent) { Start-ScheduledTask -TaskName $taskName }

Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State,
    @{N='NextRun';E={(Get-ScheduledTaskInfo $_.TaskName).NextRunTime}}
