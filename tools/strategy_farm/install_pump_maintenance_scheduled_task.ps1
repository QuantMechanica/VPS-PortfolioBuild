$ErrorActionPreference = "Stop"

# Hourly lower-frequency maintenance removed from the 5-min pump (latency
# rebaseline 2026-08-23): ea_metrics refresh, zero-trade event census, and the
# hourly farm_state.sqlite backup. MUST be installed alongside the pump-latency
# change — without it the deferred DB backups silently stop. Freshness is
# monitored by chk_db_backup_fresh in health.py.

$taskName = "QM_StrategyFarm_PumpMaintenance_Hourly"
$pythonw = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe"
$wrapper = "C:\QM\repo\tools\strategy_farm\run_pump_maintenance_task.py"

$action = New-ScheduledTaskAction -Execute $pythonw -Argument "`"$wrapper`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Hours 1)
$settings = New-ScheduledTaskSettingsSet `
  -MultipleInstances IgnoreNew `
  -ExecutionTimeLimit (New-TimeSpan -Minutes 30) `
  -StartWhenAvailable `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask `
  -TaskName $taskName `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -Principal $principal `
  -Force | Out-Null

Get-ScheduledTask -TaskName $taskName |
  Select-Object TaskName, State, @{n = "Action"; e = { $_.Actions.Execute + " " + $_.Actions.Arguments } }
