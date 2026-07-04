# =====================================================================
#  Install QM_StrategyFarm_HygieneReboot + QM_StrategyFarm_LsmHealthProbe
#
#  ╔══════════════════════════════════════════════════════════════════╗
#  ║  DO NOT RUN WHILE THE TASK SCHEDULER IS DEGRADED               ║
#  ║  (symptom: tasks fail 0x800710E0 / qwinsta error 87).          ║
#  ║  Run once after the next CLEAN BOOT — from an elevated          ║
#  ║  (Administrator) PowerShell session.                            ║
#  ╚══════════════════════════════════════════════════════════════════╝
#
#  Registers two scheduled tasks — idempotent (unregister-then-register):
#
#  QM_StrategyFarm_HygieneReboot
#    Weekly, Saturday 07:00 local, SYSTEM principal, HighestPrivilege.
#    Runs weekly_hygiene_reboot.ps1 which re-checks its own guards and
#    exits 0 without rebooting if any guard fails.  Safe to leave
#    permanently registered; kills switch = HYGIENE_REBOOT_DISABLED.flag.
#
#  QM_StrategyFarm_LsmHealthProbe
#    Every 6 hours, SYSTEM principal, HighestPrivilege.
#    Runs lsm_health_probe.ps1; writes lsm_health.json + appends to
#    lsm_health_history.jsonl under D:\QM\reports\state\.
#
#  QM_StrategyFarm_WorkerDedupe
#    On-demand only (no trigger), qm-admin INTERACTIVE principal, Highest.
#    Runs start_terminal_workers.py --dedupe: fills only missing worker
#    slots without killing in-flight terminals. Started by the SYSTEM
#    watchdog via Start-ScheduledTask (a SYSTEM child spawn would produce
#    session-0 workers whose terminal64 dies 0xC0000142 — 2026-06-24 class).
#
#  Usage:
#    # From an elevated PowerShell prompt after a clean boot:
#    Set-ExecutionPolicy -Scope Process Bypass
#    & "C:\QM\repo\tools\strategy_farm\install_hygiene_and_lsm_tasks.ps1"
# =====================================================================
[CmdletBinding()]
param(
    [string]$RepoRoot    = 'C:\QM\repo',
    [string]$HygieneTime = '07:00:00',   # local time, Saturday
    [int]$LsmEveryHours  = 6,
    [switch]$RunLsmNow                   # immediately fire the probe once (safe smoke test)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Resolve script paths
# ---------------------------------------------------------------------------
$hygieneScript = Join-Path $RepoRoot 'tools\strategy_farm\weekly_hygiene_reboot.ps1'
$lsmScript     = Join-Path $RepoRoot 'tools\strategy_farm\lsm_health_probe.ps1'

if (-not (Test-Path -LiteralPath $hygieneScript)) {
    throw "Hygiene-reboot script not found: $hygieneScript"
}
if (-not (Test-Path -LiteralPath $lsmScript)) {
    throw "LSM health probe script not found: $lsmScript"
}

# Common task settings
$commonSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

# SYSTEM principal (matches quota-governor, watchdog, factory-recycle pattern)
$sysPrincipal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

# ---------------------------------------------------------------------------
# Task 1 — QM_StrategyFarm_HygieneReboot  (weekly, Saturday 07:00 local)
# ---------------------------------------------------------------------------
$hygieneTask = 'QM_StrategyFarm_HygieneReboot'

$hygieneTrigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek Saturday `
    -At $HygieneTime

$hygieneAction = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$hygieneScript`"" `
    -WorkingDirectory $RepoRoot

if (Get-ScheduledTask -TaskName $hygieneTask -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $hygieneTask -Confirm:$false
    Write-Host "Unregistered existing task: $hygieneTask"
}

Register-ScheduledTask `
    -TaskName $hygieneTask `
    -Action   $hygieneAction `
    -Trigger  $hygieneTrigger `
    -Settings $commonSettings `
    -Principal $sysPrincipal `
    -Force `
    -Description "Weekly preventive hygiene reboot (Saturday $HygieneTime local, SYSTEM). Purges LSM resource exhaustion from terminal64.exe spawns before qwinsta error 87 / task-scheduler 0x800710E0 degradation. Guards: Saturday+06-12 window, uptime>=5d, no DISABLED.flag, debounce 3d. Recovery chain: autologon -> QM_T_Live_AtLogon -> QM_StrategyFarm_FactoryON_AtLogon. Kill switch: D:\QM\reports\state\HYGIENE_REBOOT_DISABLED.flag. Log: D:\QM\reports\state\hygiene_reboot.log." `
    | Out-Null

Enable-ScheduledTask -TaskName $hygieneTask | Out-Null
Write-Host "Registered: $hygieneTask (weekly Saturday $HygieneTime local, SYSTEM)"

# ---------------------------------------------------------------------------
# Task 2 — QM_StrategyFarm_LsmHealthProbe  (every 6 hours)
# ---------------------------------------------------------------------------
$lsmTask = 'QM_StrategyFarm_LsmHealthProbe'

# Use the repeating-once pattern (same as FactoryWatchdog) for sub-daily cadences
$lsmTrigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Hours $LsmEveryHours) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$lsmAction = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$lsmScript`"" `
    -WorkingDirectory $RepoRoot

if (Get-ScheduledTask -TaskName $lsmTask -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $lsmTask -Confirm:$false
    Write-Host "Unregistered existing task: $lsmTask"
}

Register-ScheduledTask `
    -TaskName $lsmTask `
    -Action   $lsmAction `
    -Trigger  $lsmTrigger `
    -Settings $commonSettings `
    -Principal $sysPrincipal `
    -Force `
    -Description "LSM session-infrastructure health probe (every ${LsmEveryHours}h, SYSTEM). Probes: qwinsta exit+error87, 3 QM scheduled-task result+cadence-lag, Win32_LogonSession interactive presence, CreateProcess viability, uptime. Verdict ok/degrading/critical. Output: D:\QM\reports\state\lsm_health.json + lsm_health_history.jsonl." `
    | Out-Null

Enable-ScheduledTask -TaskName $lsmTask | Out-Null
Write-Host "Registered: $lsmTask (every ${LsmEveryHours}h, SYSTEM)"

# ---------------------------------------------------------------------------
# Task 3 — QM_StrategyFarm_WorkerDedupe  (on-demand, interactive qm-admin)
# ---------------------------------------------------------------------------
$dedupeTask   = 'QM_StrategyFarm_WorkerDedupe'
$dedupeScript = Join-Path $RepoRoot 'tools\strategy_farm\start_terminal_workers.py'
$pyExe        = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'

if (-not (Test-Path -LiteralPath $dedupeScript)) {
    throw "start_terminal_workers.py not found: $dedupeScript"
}

# Interactive qm-admin principal — mirrors QM_StrategyFarm_FactoryON_AtLogon.
# The watchdog (SYSTEM) starts this task on demand; the spawn then happens
# inside the interactive session so terminal64 children are viable.
$dedupePrincipal = New-ScheduledTaskPrincipal `
    -UserId 'qm-admin' `
    -LogonType Interactive `
    -RunLevel Highest

$dedupeAction = New-ScheduledTaskAction `
    -Execute $pyExe `
    -Argument "`"$dedupeScript`" --repo-root `"$RepoRoot`" --farm-root D:\QM\strategy_farm --dedupe" `
    -WorkingDirectory $RepoRoot

if (Get-ScheduledTask -TaskName $dedupeTask -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $dedupeTask -Confirm:$false
    Write-Host "Unregistered existing task: $dedupeTask"
}

Register-ScheduledTask `
    -TaskName $dedupeTask `
    -Action   $dedupeAction `
    -Settings $commonSettings `
    -Principal $dedupePrincipal `
    -Force `
    -Description "On-demand surgical worker heal (no trigger; started by the SYSTEM watchdog via Start-ScheduledTask). Runs start_terminal_workers.py --dedupe in the INTERACTIVE qm-admin session so spawned workers can launch visible terminal64. Never kills in-flight terminals. Direct SYSTEM spawns are forbidden: session-0 workers die 0xC0000142 (2026-06-24 broken-respawn class)." `
    | Out-Null

Enable-ScheduledTask -TaskName $dedupeTask | Out-Null
Write-Host "Registered: $dedupeTask (on-demand, qm-admin Interactive)"

# ---------------------------------------------------------------------------
# Optional immediate smoke run of the LSM probe
# ---------------------------------------------------------------------------
if ($RunLsmNow.IsPresent) {
    Write-Host "Firing $lsmTask immediately (smoke run)..."
    Start-ScheduledTask -TaskName $lsmTask
    Start-Sleep -Seconds 5
    $jsonPath = 'D:\QM\reports\state\lsm_health.json'
    if (Test-Path -LiteralPath $jsonPath) {
        Write-Host "lsm_health.json:"
        Get-Content -LiteralPath $jsonPath | Write-Host
    } else {
        Write-Host "WARNING: lsm_health.json not yet written (probe may still be running)"
    }
}

# ---------------------------------------------------------------------------
# Confirmation summary
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- Registered tasks ---'
foreach ($name in @($hygieneTask, $lsmTask, $dedupeTask)) {
    $task = Get-ScheduledTask -TaskName $name
    $info = Get-ScheduledTaskInfo -TaskName $name
    [pscustomobject]@{
        TaskName    = $task.TaskName
        State       = $task.State
        RunLevel    = $task.Principal.RunLevel
        LogonType   = $task.Principal.LogonType
        NextRunTime = $info.NextRunTime
    }
}
