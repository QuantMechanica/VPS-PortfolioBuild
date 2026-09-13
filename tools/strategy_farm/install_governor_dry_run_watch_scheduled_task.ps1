[CmdletBinding()]
param(
    [string]$TaskName = "QM_StrategyFarm_GovernorDryRunWatch",
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonwExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe",
    [string]$Snapshot = "C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\journal\account_snapshot.json",
    [long]$ExpectedLogin = 4000090541,
    [double]$MaxAgeSeconds = 180,
    [int]$IntervalMinutes = 5,
    [switch]$DryRun,
    [switch]$RunNow
)

# SP-C6 recurring dry-run watcher for the account/portfolio governor.
#
# READ-ONLY BY CONSTRUCTION. governor_dry_run_watch.py has no apply mode: it
# re-evaluates account_portfolio_governor.evaluate() on the deployed monitor's
# atomic account snapshot, journals every decision, and raises an alarm line
# only on a level transition. It never connects to MT5, never sends/cancels/
# closes an order, and never toggles AutoTrading. Enforcement is a separate,
# OWNER-gated component (account_governor_action_adapter.py, ships DISABLED).
#
# Cadence and principal mirror QM_StrategyFarm_LiveBookDDGuard (SYSTEM, highest,
# IgnoreNew). --max-age-seconds 180 matches the contract's equity-freshness
# backstop (ACCOUNT_PORTFOLIO_GOVERNOR_CONTRACT_2026-08-22.md:104-113); the
# module default of 90 s would flag every second tick of the 60 s monitor timer
# as stale.
#
# ONE canonical watcher only: do NOT also register
# account_portfolio_governor_recurring_dry_run.py. Both write
# D:\QM\reports\state and both append
# D:\QM\strategy_farm\state\health_alarms.log; scheduling both double-logs and
# races (docs/ops/evidence/2026-09-03_governor_v2_g6_design_and_adapter.md).
#
# -DryRun prints the exact registration plan and exits without touching the
# Windows scheduler.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script = Join-Path $RepoRoot "tools\strategy_farm\governor_dry_run_watch.py"
if (-not (Test-Path -LiteralPath $PythonwExe)) {
    throw "pythonw.exe not found: $PythonwExe"
}
if (-not (Test-Path -LiteralPath $script)) {
    throw "governor_dry_run_watch.py not found: $script"
}
if (-not (Test-Path -LiteralPath $Snapshot)) {
    throw "Account snapshot not found (is the monitor attached?): $Snapshot"
}
if ($IntervalMinutes -lt 1) {
    throw "IntervalMinutes must be >= 1."
}

$argument = "`"$script`" --dry-run --snapshot `"$Snapshot`" --expected-login $ExpectedLogin --max-age-seconds $MaxAgeSeconds"

$action = New-ScheduledTaskAction `
    -Execute $PythonwExe `
    -Argument $argument `
    -WorkingDirectory $RepoRoot

$startBoundary = (Get-Date).Date.AddHours((Get-Date).Hour).AddMinutes(2)
if ($startBoundary -le (Get-Date)) {
    $startBoundary = (Get-Date).AddMinutes(2)
}
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$description = "Read-only recurring dry run of the account/portfolio governor (SP-C6). No apply mode, no order operation, no AutoTrading toggle."

if ($DryRun.IsPresent) {
    [pscustomobject]@{
        mode                   = "DRY_RUN_NO_REGISTRATION"
        task_name              = $TaskName
        principal              = "SYSTEM / ServiceAccount / Highest"
        execute                = $PythonwExe
        argument               = $argument
        working_directory      = $RepoRoot
        start_boundary         = $startBoundary.ToString("s")
        repetition_interval    = "PT${IntervalMinutes}M"
        execution_time_limit   = "PT5M"
        multiple_instances     = "IgnoreNew"
        description            = $description
        existing_task_present  = [bool](Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
        writes                 = "D:\QM\reports\state\governor_dry_run_watch_{state.json,.log,_history.jsonl}; D:\QM\strategy_farm\state\health_alarms.log (level transitions only)"
        never_writes           = "C:\QM\mt5\T_Live (read-only source), farm_state.sqlite, any order/AutoTrading state"
    } | Format-List
    return
}

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description $description `
    -Force | Out-Null

Enable-ScheduledTask -TaskName $TaskName | Out-Null

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $TaskName
}

Get-ScheduledTask -TaskName $TaskName |
    Select-Object TaskName, State, @{n = "Action"; e = { $_.Actions.Execute + " " + $_.Actions.Arguments } }
