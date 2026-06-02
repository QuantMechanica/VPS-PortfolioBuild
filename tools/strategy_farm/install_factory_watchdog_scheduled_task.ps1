[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [int]$EveryMinutes = 15,
    [string]$User = "WIN-B95G5LPSJ1O\qm-admin",   # the autologon / interactive RDP user
    [switch]$RunNow
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$taskName = "QM_StrategyFarm_FactoryWatchdog_15min"
$script   = Join-Path $RepoRoot "tools\strategy_farm\factory_watchdog.ps1"
if (-not (Test-Path -LiteralPath $script)) { throw "watchdog script not found: $script" }

# IMPORTANT: Interactive principal (RunLevel=Highest) so the heal spawns the visible
# MT5 worker daemons IN the autologon session. A SYSTEM/session-0 task (like the hourly
# health monitor) physically cannot do this - that is why the hourly monitor only
# escalates "factory down". RunLevel=Highest also means the workers inherit an elevated
# session and CIM CommandLine reads succeed without a UAC prompt.
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
$principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Highest
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`"" `
    -WorkingDirectory $RepoRoot

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force `
    -Description "In-session factory watchdog (every $EveryMinutes min): if the factory is meant ON (Pump/Tick enabled) but worker daemons died, respawn only the missing ones via start_terminal_workers --dedupe. Runs in the autologon interactive session (visible mode). Respects OWNER ON/OFF, never touches T_Live, no email. Complements the session-0 hourly health monitor. Runbook: docs/ops/FACTORY_AUTOLOGON_2026-06-02.md." | Out-Null
Enable-ScheduledTask -TaskName $taskName | Out-Null
if ($RunNow.IsPresent) { Start-ScheduledTask -TaskName $taskName }

Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State,
    @{N='NextRun';E={(Get-ScheduledTaskInfo $_.TaskName).NextRunTime}}
