$ErrorActionPreference = "Stop"

$taskName = "QM_StrategyFarm_Pump_5min"
$pythonw = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe"
$wrapper = "C:\QM\repo\tools\strategy_farm\run_pump_task.py"

$action = New-ScheduledTaskAction -Execute $pythonw -Argument "`"$wrapper`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 5)
$settings = New-ScheduledTaskSettingsSet `
  -MultipleInstances IgnoreNew `
  -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
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
