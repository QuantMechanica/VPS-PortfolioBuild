[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonExe = "python",
    [string]$DwxRoutineInstallerScript = "C:\QM\repo\infra\scripts\Install-DwxHourlyRoutine.ps1",
    [switch]$EnableLegacyDwxTask,
    [string]$DwxHourlyScript = "C:\QM\repo\infra\scripts\dwx_hourly_check.py",
    [string]$AggregatorScript = "C:\QM\repo\scripts\aggregator\standalone_aggregator_loop.py",
    [string]$SnapshotScript = "C:\QM\repo\scripts\export_public_snapshot.ps1",
    [string]$HealthScript = "C:\QM\repo\infra\monitoring\Invoke-InfraHealthCheck.ps1",
    [string]$DriveGitExclusionScript = "C:\QM\repo\infra\monitoring\Test-DriveGitExclusion.ps1",
    [string]$DriveGitExclusionOutputPath = "C:\QM\logs\infra\health\drive_git_exclusion_latest.json",
    [string]$GitIndexLockMonitorScript = "C:\QM\repo\infra\monitoring\Invoke-GitIndexLockMonitor.ps1",
    [string]$Class2ExecutionPolicySentinelScript = "C:\QM\repo\infra\monitoring\Test-Class2ExecutionPolicySentinel.ps1",
    [string]$MainArtifactEnforcerScript = "C:\QM\repo\infra\monitoring\Test-MainArtifactEnforcer.ps1",
    [string]$TokenCostBudgetScript = "C:\QM\repo\infra\monitoring\Test-TokenCostBudget.ps1",
    [string]$StaleLockWatchdogScript = "C:\QM\repo\infra\monitoring\Invoke-PaperclipStaleLockWatchdog.ps1",
    [string]$Qua207RuntimeHeartbeatScript = "C:\QM\repo\infra\scripts\Run-QUA207RuntimeCompletionHeartbeat.ps1",
    [string]$TokenCostBudgetHealthScript = "C:\QM\repo\infra\monitoring\Test-TokenCostBudgetHealth.ps1",
    [int64]$DailyTokenBudget = 2500000,
    [string]$RuntimeHealthScanScript = "C:\QM\repo\infra\scripts\Run-RuntimeHealthScan.ps1",
    [string]$RuntimeHealthCompanyId = "03d4dcc8-4cea-4133-9f68-90c0d99628fb",
    [string]$PaperclipInstanceEnvFile = "C:\QM\paperclip\data\instances\default\.env",
    [string]$BackupScript = "C:\QM\repo\infra\backup.ps1",
    [string]$RecoveryOrphanCleanupScript = "C:\QM\repo\infra\scripts\Remove-RecoveryOrphans.ps1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Register-DesiredTask {
    param(
        [string]$TaskName,
        [string]$Executable,
        [string]$Arguments,
        [Microsoft.Management.Infrastructure.CimInstance]$Trigger,
        [string]$Description,
        [string]$WorkingDirectory = ""
    )

    $action = New-ScheduledTaskAction -Execute $Executable -Argument $Arguments
    if ($WorkingDirectory) {
        $action.WorkingDirectory = $WorkingDirectory
    }
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $Trigger `
        -Settings $settings `
        -Principal $principal `
        -Description $Description `
        -Force | Out-Null
    Write-Host "Converged task: $TaskName"
}

function New-RepeatingTriggerFromToday {
    param(
        [Parameter(Mandatory = $true)] [datetime]$AtTime,
        [Parameter(Mandatory = $true)] [timespan]$Interval,
        [Parameter(Mandatory = $true)] [timespan]$Duration
    )

    if ($Interval.TotalMinutes -lt 1) {
        throw "Interval must be at least 1 minute."
    }
    if ($Duration.TotalMinutes -lt $Interval.TotalMinutes) {
        throw "Duration must be greater than or equal to Interval."
    }

    $now = Get-Date
    $startBoundary = $now.Date.AddHours($AtTime.Hour).AddMinutes($AtTime.Minute)
    if ($startBoundary -le $now) {
        do {
            $startBoundary = $startBoundary.Add($Interval)
        } while ($startBoundary -le $now)
    }

    return New-ScheduledTaskTrigger -Once -At $startBoundary -RepetitionInterval $Interval -RepetitionDuration $Duration
}

# Hourly public snapshot export at HH:07
$snapshotTrigger = New-RepeatingTriggerFromToday `
    -AtTime (Get-Date "00:07") `
    -Interval (New-TimeSpan -Hours 1) `
    -Duration (New-TimeSpan -Days 3650)
Register-DesiredTask `
    -TaskName "QM_PublicSnapshot_Export_Hourly" `
    -Executable "powershell.exe" `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SnapshotScript`"" `
    -Trigger $snapshotTrigger `
    -Description "Exports public-data snapshot JSON hourly and publishes if changed." `
    -WorkingDirectory $RepoRoot

# DWX hourly orchestrator runs via Paperclip routine (primary scheduler path)
if (Test-Path -LiteralPath $DwxRoutineInstallerScript) {
    Write-Host "DWX hourly scheduler is Paperclip routine-based. Converge with:"
    Write-Host "  powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$DwxRoutineInstallerScript`" -Apply"
}
else {
    Write-Warning "DWX routine installer script missing; cannot print convergence command."
}

if ($EnableLegacyDwxTask.IsPresent) {
    if (Test-Path -LiteralPath $DwxHourlyScript) {
        $dwxTrigger = New-RepeatingTriggerFromToday `
            -AtTime (Get-Date "00:11") `
            -Interval (New-TimeSpan -Hours 1) `
            -Duration (New-TimeSpan -Days 3650)
        Register-DesiredTask `
            -TaskName "QM_DWX_HourlyCheck" `
            -Executable $PythonExe `
            -Arguments "`"$DwxHourlyScript`"" `
            -Trigger $dwxTrigger `
            -Description "Runs DWX import orchestrator hourly (legacy fallback; routine is primary)."
    }
    else {
        Write-Warning "DWX orchestrator script missing; skipped legacy QM_DWX_HourlyCheck registration."
    }
}

# Aggregator state writer every minute, only if source script exists
if (Test-Path -LiteralPath $AggregatorScript) {
    $aggTrigger = New-RepeatingTriggerFromToday `
        -AtTime (Get-Date "00:00") `
        -Interval (New-TimeSpan -Minutes 1) `
        -Duration (New-TimeSpan -Days 3650)
    Register-DesiredTask `
        -TaskName "QM_AggregatorState_1min" `
        -Executable $PythonExe `
        -Arguments "`"$AggregatorScript`" --once" `
        -Trigger $aggTrigger `
        -Description "Writes V5 last_check_state.json and aggregator heartbeat every minute."
}
else {
    Write-Warning "Aggregator script missing; skipped QM_AggregatorState_1min registration."
}

# Infra health monitor every 5 minutes
$healthTrigger = New-RepeatingTriggerFromToday `
    -AtTime (Get-Date "00:00") `
    -Interval (New-TimeSpan -Minutes 5) `
    -Duration (New-TimeSpan -Days 3650)
Register-DesiredTask `
    -TaskName "QM_InfraHealthCheck_5min" `
    -Executable "powershell.exe" `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$HealthScript`"" `
    -Trigger $healthTrigger `
    -Description "Checks infra health: disk, MT5 heartbeat, Paperclip daemon, Drive sync, stale index.lock."

# Daily token-cost budget snapshot (also emits 70/80/95% threshold status)
if (Test-Path -LiteralPath $TokenCostBudgetScript) {
    $tokenCostDailyTrigger = New-ScheduledTaskTrigger -Daily -At "00:05"
    Register-DesiredTask `
        -TaskName "QM_TokenCostSnapshot_Daily_0005" `
        -Executable "powershell.exe" `
        -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$TokenCostBudgetScript`"" `
        -Trigger $tokenCostDailyTrigger `
        -Description "Writes daily token-cost snapshot and threshold state (70/80/95%)."
}
else {
    Write-Warning "Token cost budget script missing; skipped QM_TokenCostSnapshot_Daily_0005 registration."
}

# Git index lock monitor every 10 minutes (PC1-00)
if (Test-Path -LiteralPath $GitIndexLockMonitorScript) {
    $gitLockTrigger = New-RepeatingTriggerFromToday `
        -AtTime (Get-Date "00:02") `
        -Interval (New-TimeSpan -Minutes 10) `
        -Duration (New-TimeSpan -Days 3650)
    Register-DesiredTask `
        -TaskName "QM_GitIndexLockMonitor_10min" `
        -Executable "powershell.exe" `
        -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$GitIndexLockMonitorScript`" -StaleAfterMinutes 20 -FailOnFinding" `
        -Trigger $gitLockTrigger `
        -Description "Detects stale .git/index.lock files and raises critical state."
}
else {
    Write-Warning "Git index lock monitor script missing; skipped QM_GitIndexLockMonitor_10min registration."
}

# Class-2 execution-policy sentinel every 60 minutes (DL-030 convention guard)
if (Test-Path -LiteralPath $Class2ExecutionPolicySentinelScript) {
    $class2PolicyTrigger = New-RepeatingTriggerFromToday `
        -AtTime (Get-Date "00:08") `
        -Interval (New-TimeSpan -Minutes 60) `
        -Duration (New-TimeSpan -Days 3650)
    Register-DesiredTask `
        -TaskName "QM_Class2ExecutionPolicySentinel_60min" `
        -Executable "powershell.exe" `
        -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Class2ExecutionPolicySentinelScript`" -FailOnFinding" `
        -Trigger $class2PolicyTrigger `
        -Description "Detects missing executionPolicy on Class-2 Strategy Card issues (DL-030 sentinel)."
}
else {
    Write-Warning "Class-2 execution-policy sentinel script missing; skipped QM_Class2ExecutionPolicySentinel_60min registration."
}

# Main-branch artifact enforcer every 15 minutes (QUA-616)
if (Test-Path -LiteralPath $MainArtifactEnforcerScript) {
    $mainArtifactTrigger = New-RepeatingTriggerFromToday `
        -AtTime (Get-Date "00:13") `
        -Interval (New-TimeSpan -Minutes 15) `
        -Duration (New-TimeSpan -Days 3650)
    Register-DesiredTask `
        -TaskName "QM_MainArtifactEnforcer_15min" `
        -Executable "powershell.exe" `
        -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$MainArtifactEnforcerScript`" -RepoRoot `"$RepoRoot`" -ProtectedBranch main" `
        -Trigger $mainArtifactTrigger `
        -Description "Detects forbidden QUA-* artifact paths on main checkout."
}
else {
    Write-Warning "Main artifact enforcer script missing; skipped QM_MainArtifactEnforcer_15min registration."
}

# Drive/git exclusion hard-fence verification every 15 minutes (PC1-00)
if (Test-Path -LiteralPath $DriveGitExclusionScript) {
    $driveFenceTrigger = New-RepeatingTriggerFromToday `
        -AtTime (Get-Date "00:06") `
        -Interval (New-TimeSpan -Minutes 15) `
        -Duration (New-TimeSpan -Days 3650)
    Register-DesiredTask `
        -TaskName "QM_DriveGitExclusion_15min" `
        -Executable "powershell.exe" `
        -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$DriveGitExclusionScript`" -PrimaryRepoForWorktrees `"$RepoRoot`" -IncludeGitWorktrees -OutputPath `"$DriveGitExclusionOutputPath`"" `
        -Trigger $driveFenceTrigger `
        -Description "Verifies repo/.git paths remain outside Drive sync roots (PC1-00 hard fence)."
}
else {
    Write-Warning "Drive/git exclusion script missing; skipped QM_DriveGitExclusion_15min registration."
}

# Paperclip stale-lock watchdog every 15 minutes, only if source script exists.
if (Test-Path -LiteralPath $StaleLockWatchdogScript) {
    $staleWatchdogTrigger = New-RepeatingTriggerFromToday `
        -AtTime (Get-Date "00:03") `
        -Interval (New-TimeSpan -Minutes 15) `
        -Duration (New-TimeSpan -Days 3650)
    Register-DesiredTask `
        -TaskName "QM_PaperclipStaleLockWatchdog_15min" `
        -Executable "powershell.exe" `
        -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$StaleLockWatchdogScript`" -StaleAfterMinutes 15 -FailOnFinding" `
        -Trigger $staleWatchdogTrigger `
        -Description "Detects stale Paperclip issue execution locks (monitor-only)."
}
else {
    Write-Warning "Paperclip stale-lock watchdog script missing; skipped QM_PaperclipStaleLockWatchdog_15min registration."
}

# QUA-207 runtime completion heartbeat every 30 minutes (if script exists)
if (Test-Path -LiteralPath $Qua207RuntimeHeartbeatScript) {
    $qua207Trigger = New-RepeatingTriggerFromToday `
        -AtTime (Get-Date "00:04") `
        -Interval (New-TimeSpan -Minutes 30) `
        -Duration (New-TimeSpan -Days 3650)
    Register-DesiredTask `
        -TaskName "QM_QUA207_RuntimeHeartbeat_30min" `
        -Executable "powershell.exe" `
        -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Qua207RuntimeHeartbeatScript`" -RepoRoot `"$RepoRoot`"" `
        -Trigger $qua207Trigger `
        -Description "Runs QUA-207 runtime completion heartbeat and refreshes transition/comment artifacts."
}
else {
    Write-Warning "QUA-207 runtime heartbeat script missing; skipped QM_QUA207_RuntimeHeartbeat_30min registration."
}

# Token-cost observability alarm every 15 minutes + daily snapshot
if (Test-Path -LiteralPath $TokenCostBudgetHealthScript) {
    $tokenCostAlarmTrigger = New-RepeatingTriggerFromToday `
        -AtTime (Get-Date "00:09") `
        -Interval (New-TimeSpan -Minutes 15) `
        -Duration (New-TimeSpan -Days 3650)
    Register-DesiredTask `
        -TaskName "QM_TokenCostBudgetHealth_15min" `
        -Executable "powershell.exe" `
        -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$TokenCostBudgetHealthScript`" -DailyTokenBudget $DailyTokenBudget" `
        -Trigger $tokenCostAlarmTrigger `
        -Description "Monitors daily token budget usage with 70/80/95 percent thresholds."

    $tokenCostDailySnapshotTrigger = New-ScheduledTaskTrigger -Daily -At "00:10"
    Register-DesiredTask `
        -TaskName "QM_TokenCostBudgetDailySnapshot_0010" `
        -Executable "powershell.exe" `
        -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$TokenCostBudgetHealthScript`" -DailyTokenBudget $DailyTokenBudget" `
        -Trigger $tokenCostDailySnapshotTrigger `
        -Description "Writes daily token-cost snapshot artifacts."
}
else {
    Write-Warning "Token-cost monitor script missing; skipped token-cost observability task registration."
}

# Agent runtime health scan every 15 minutes (6 runtime-pathology detectors)
if (Test-Path -LiteralPath $RuntimeHealthScanScript) {
    $runtimeHealthTrigger = New-RepeatingTriggerFromToday `
        -AtTime (Get-Date "00:05") `
        -Interval (New-TimeSpan -Minutes 15) `
        -Duration (New-TimeSpan -Days 3650)
    Register-DesiredTask `
        -TaskName "QM_RuntimeHealthScan_15min" `
        -Executable "powershell.exe" `
        -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"`$line=Select-String -Path '$PaperclipInstanceEnvFile' -Pattern '^DATABASE_URL=' | Select-Object -First 1; if(`$null -eq `$line) { throw 'DATABASE_URL not found in Paperclip instance env file.' }; `$pg=`$line.Line -replace '^DATABASE_URL=',''; & '$RuntimeHealthScanScript' -CompanyId '$RuntimeHealthCompanyId' -PostgresUrl `$pg`"" `
        -Trigger $runtimeHealthTrigger `
        -Description "Runs agent runtime health scan detectors (hot-poll, stuck-session, >=24h heartbeat silence, bottleneck, budget pressure, recursive self-wake)."
}
else {
    Write-Warning "Runtime health scan script missing; skipped QM_RuntimeHealthScan_15min registration."
}

# Daily backup at 02:15
$backupTrigger = New-ScheduledTaskTrigger -Daily -At "02:15"
Register-DesiredTask `
    -TaskName "QM_Backup_Daily_0215" `
    -Executable "powershell.exe" `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$BackupScript`"" `
    -Trigger $backupTrigger `
    -Description "Runs daily backup workflow with retention."

# Recovery orphan cleanup daily at 03:10 (24h min-age enforced inside script)
$recoveryCleanupTrigger = New-ScheduledTaskTrigger -Daily -At "03:10"
Register-DesiredTask `
    -TaskName "QM_RecoveryOrphans_Cleanup_Daily_0310" `
    -Executable "powershell.exe" `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RecoveryOrphanCleanupScript`"" `
    -Trigger $recoveryCleanupTrigger `
    -Description "Cleans D:\\QM\\_recovery_orphans_* directories older than 24h."
