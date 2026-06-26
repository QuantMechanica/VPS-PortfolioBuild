# Registers QM_StrategyFarm_CodexFleetPacer — paces a headless Codex fleet to the weekly cap
# (continuous work to reset, never a cap-stop). MUST run in session 1 (Interactive): the spawned
# Codex agents run run_smoke -> terminal64, which needs the logged-on desktop session, not SYSTEM.
# Re-run after a reboot if the task is missing (autologon provides session 1).
$ErrorActionPreference = "Stop"
$py = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe"
$taskName = "QM_StrategyFarm_CodexFleetPacer"
$user = (Get-CimInstance Win32_ComputerSystem).UserName
if (-not $user) { $user = "$env:USERDOMAIN\$env:USERNAME" }
$action = New-ScheduledTaskAction -Execute $py -Argument "tools\strategy_farm\codex_fleet_pacer.py" -WorkingDirectory "C:\QM\repo"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration ([TimeSpan]::FromDays(3650))
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew
try { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop } catch {}
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Pace headless Codex fleet to weekly cap; session 1." | Out-Null
Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State
