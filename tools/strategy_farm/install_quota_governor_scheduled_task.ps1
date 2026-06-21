# =====================================================================
#  Install QM_StrategyFarm_QuotaGovernor scheduled task
#  Runs tools/strategy_farm/quota_governor.py every 15 min as SYSTEM.
#  Automated weekly-pace throttle for Codex + Claude (OWNER policy 2026-06-21):
#  spend tracks the weekly limit -> buffer builds EAs, ahead-of-pace throttles
#  the build/research lanes (CODEX_LOW_TOKENS.flag / CLAUDE_DISABLED.flag) +
#  boosts the non-throttled agent's lane; MT5 backtests are NEVER throttled.
#  See docs/ops/QUOTA_GOVERNOR_AND_FACTORY_RECOVERY_2026-06-21.md
# =====================================================================
param(
    [int]$EveryMinutes = 15,
    [string]$Python = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe',
    [string]$Script = 'C:\QM\repo\tools\strategy_farm\quota_governor.py'
)
$ErrorActionPreference = 'Stop'
$action  = New-ScheduledTaskAction -Execute $Python -Argument ('"' + $Script + '"') -WorkingDirectory 'C:\QM\repo'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName 'QM_StrategyFarm_QuotaGovernor' -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force `
    -Description "Every ${EveryMinutes}min: steer Codex+Claude controllable work along their weekly token limits (pace = used% - elapsed%, floor 15 / engage +12 / release +4 / hard ceiling 90). Throttles via CODEX_LOW_TOKENS.flag / CLAUDE_DISABLED.flag + lane-boost; MT5 backtests never throttled. OWNER policy 2026-06-21." | Out-Null
Start-ScheduledTask -TaskName 'QM_StrategyFarm_QuotaGovernor'
Write-Host "QM_StrategyFarm_QuotaGovernor installed (every ${EveryMinutes}min, SYSTEM) and started."
