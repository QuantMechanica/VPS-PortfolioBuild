# =====================================================================
#  Install QM_StrategyFarm_PortfolioReport scheduled task
#  Runs tools/strategy_farm/portfolio/portfolio_periodic_report.py every 6h as SYSTEM.
#  R-064-5 periodic re-fit: assembles the portfolio from the STRESS-GATED robust pool
#  (Q08 FAIL_SOFT sleeves), fixed greedy assembler (risk-parity, picks the best
#  cap-feasible book) + out-of-sample selection guard, writes portfolio_latest.json +
#  a dated report under D:\QM\reports\portfolio so the book's growth is visible as
#  sleeves accumulate. Read-only on DB/streams; session-0 safe (no MT5). See DL-064.
# =====================================================================
param(
    [int]$EveryHours = 6,
    [string]$Python = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe',
    [string]$Script = 'C:\QM\repo\tools\strategy_farm\portfolio\portfolio_periodic_report.py'
)
$ErrorActionPreference = 'Stop'
$action  = New-ScheduledTaskAction -Execute $Python -Argument ('"' + $Script + '"') -WorkingDirectory 'C:\QM\repo'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours $EveryHours)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
Register-ScheduledTask -TaskName 'QM_StrategyFarm_PortfolioReport' -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force `
    -Description "Every ${EveryHours}h: assemble the portfolio from the stress-gated robust pool (Q08 FAIL_SOFT), fixed greedy assembler + OOS selection guard, write D:\QM\reports\portfolio\portfolio_latest.json. R-064-5 / DL-064. Read-only, SYSTEM, session-0 safe." | Out-Null
Start-ScheduledTask -TaskName 'QM_StrategyFarm_PortfolioReport'
Write-Host "QM_StrategyFarm_PortfolioReport installed (every ${EveryHours}h, SYSTEM) and started."
