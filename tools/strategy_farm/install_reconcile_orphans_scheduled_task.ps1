[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [int]$EveryMinutes = 60,
    [switch]$RunNow
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$taskName = "QM_StrategyFarm_ReconcileOrphans_Hourly"
$script   = Join-Path $RepoRoot "tools\strategy_farm\reconcile_orphans.ps1"
if (-not (Test-Path -LiteralPath $script)) { throw "reconcile script not found: $script" }

# SYSTEM principal: must Stop-Process cross-session terminal64.exe (factory runs
# in the autologon interactive session); SYSTEM has SeDebugPrivilege. Matches the
# quota_pull / news-refresh SYSTEM maintenance-task convention. Reaps ONLY
# terminal64 whose work_item is done/failed/missing (live backtests preserved);
# never touches T_Live. Complements the watchdog (which respawns/dispatch-heals
# but does NOT reap orphaned terminals — observed accumulating ~6/h on 2026-06-16).
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
    -Description "Reap orphaned factory terminal64.exe (every $EveryMinutes min, SYSTEM) via farmctl reconcile-mt5 --fix-orphan-terminals. Stops terminals whose work_item is done/failed/missing (designed path, not manual kill); preserves live backtests; never T_Live. Evidence: D:\QM\reports\state\reconcile_orphans.jsonl. Set up 2026-06-16 after 6/10 terminals were found orphaned, starving Q02 throughput." | Out-Null
Enable-ScheduledTask -TaskName $taskName | Out-Null
if ($RunNow.IsPresent) { Start-ScheduledTask -TaskName $taskName }

Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State,
    @{N='NextRun';E={(Get-ScheduledTaskInfo $_.TaskName).NextRunTime}}
