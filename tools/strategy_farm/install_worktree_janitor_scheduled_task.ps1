$ErrorActionPreference = 'Stop'

$taskName = 'QM_StrategyFarm_WorktreeJanitor_6h'
$pythonw = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe'
$script = 'C:\QM\repo\tools\strategy_farm\worktree_janitor.py'
$action = New-ScheduledTaskAction -Execute $pythonw -Argument "`"$script`" --apply"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Hours 6)
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -StartWhenAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null
Get-ScheduledTask -TaskName $taskName | Select-Object TaskName,State
