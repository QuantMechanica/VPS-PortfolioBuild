[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [int]$EveryMinutes = 5,
    [switch]$RunNow
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$taskName = "QM_StrategyFarm_FactoryWatchdog_15min"   # historical name kept (manifest/monitoring references); cadence is $EveryMinutes
$script   = Join-Path $RepoRoot "tools\strategy_farm\factory_watchdog.ps1"
if (-not (Test-Path -LiteralPath $script)) { throw "watchdog script not found: $script" }

# IMPORTANT: SYSTEM principal (matches the LIVE task since the 2026-06-09 redesign;
# this installer previously said Interactive and would have broken a reinstall).
# The watchdog needs SYSTEM (SeTcb) for two reasons:
#   1. Respawn into a DISCONNECTED session: run_in_console_session.ps1 uses
#      WTSQueryUserToken + CreateProcessAsUser - only possible as SYSTEM. An
#      Interactive-principal task cannot run at all once the session is gone,
#      which is exactly the failure mode the watchdog must heal.
#   2. Session-loss reboot-heal (2026-06-11): checks the LSA DefaultPassword
#      secret and issues a controlled shutdown /r when the autologon session
#      was destroyed (docs/ops/SESSION_LOSS_SELF_HEAL_2026-06-11.md).
# Cadence 5 min (was 15): measured 2026-06-11 over 24h - steady-state claim gap
# is ~1s, but every wedge/session-loss event idles ~10 terminals until the next
# watchdog tick. At 15 min that costs ~2.5 slot-hours per event; 5 min cuts mean
# detection latency from ~7.5 to ~2.5 min.
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`"" `
    -WorkingDirectory $RepoRoot

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force `
    -Description "Factory watchdog (every $EveryMinutes min, SYSTEM): respawns dead/wedged T1-T10 workers into the autologon session (WTSQueryUserToken), heals dispatch stalls, and reboot-heals a DESTROYED interactive session via autologon (guards: 2x confirm, 6h cooldown, T_Live). Respects OWNER ON/OFF, never touches T_Live, no email. Evidence: D:\QM\reports\state\factory_watchdog.jsonl. Runbook: docs/ops/SESSION_LOSS_SELF_HEAL_2026-06-11.md." | Out-Null
Enable-ScheduledTask -TaskName $taskName | Out-Null
if ($RunNow.IsPresent) { Start-ScheduledTask -TaskName $taskName }

Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State,
    @{N='NextRun';E={(Get-ScheduledTaskInfo $_.TaskName).NextRunTime}}
