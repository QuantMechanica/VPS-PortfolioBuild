[CmdletBinding()]
<#
.SYNOPSIS
    Installs QM_StrategyFarm_PipelineState — hourly rebuild of
    D:\QM\reports\state\pipeline_state.json via scripts\build_pipeline_state.py.

.DESCRIPTION
    QM-TODO-20260821-202. pipeline_state.json is an actively-consumed snapshot:
      * scripts\export_public_snapshot.ps1 reads it (public-data -> quantmechanica.com),
        driven by QM_Public_Snapshot_Hourly whose wrapper rebuilds it first.
      * scripts\qm_pipeline_summary.py reads it (internal daily summary).

    The wrapper's public_snapshot_incident_guard fail-closes the WHOLE hourly
    wrapper (build step included) whenever a Q02-bypass incident hold is active.
    That is deliberate for PUBLICATION but collaterally froze the internal
    pipeline_state.json snapshot (stale since 2026-07-29 while holds stood).

    This dedicated task decouples the READ-ONLY state build from publication:
    build_pipeline_state.py derives per-EA state from the work_items DB and disk
    artifacts and atomically writes ONLY pipeline_state.json. It publishes
    nothing, touches no verdicts, and does not bypass the publication guard
    (which gates a separate export step). Internal consumers therefore keep
    reading fresh state even while public publication is held.

    Runtime shape mirrors sibling QM_StrategyFarm_QuotaGovernor:
    SYSTEM / HighestAvailable, direct pythonw.exe action (no console window),
    WorkingDirectory C:\QM\repo.

.NOTES
    Rollback:  schtasks /delete /tn "QM_StrategyFarm_PipelineState" /f
#>
param(
    [string]$TaskName = "QM_StrategyFarm_PipelineState",
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonwExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe",
    [int]$IntervalHours = 1,
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script = Join-Path $RepoRoot "scripts\build_pipeline_state.py"
if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
    throw "Builder not found: $script"
}
if (-not (Test-Path -LiteralPath $PythonwExe -PathType Leaf)) {
    throw "pythonw.exe not found: $PythonwExe"
}

# Direct pythonw.exe action = CREATE_NO_WINDOW (GUI-subsystem interpreter, no
# console window), the canonical sibling pattern (QM_StrategyFarm_QuotaGovernor).
$action = New-ScheduledTaskAction `
    -Execute $PythonwExe `
    -Argument ('"{0}"' -f $script) `
    -WorkingDirectory $RepoRoot

$startBoundary = (Get-Date).Date.AddHours((Get-Date).Hour).AddMinutes(23)
if ($startBoundary -le (Get-Date)) {
    $startBoundary = $startBoundary.AddHours(1)
}

$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary `
    -RepetitionInterval (New-TimeSpan -Hours $IntervalHours) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

# SYSTEM service account, HighestAvailable — matches sibling QM_StrategyFarm_* tasks.
$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description ("Hourly READ-ONLY rebuild of D:\QM\reports\state\pipeline_state.json " +
        "(scripts\build_pipeline_state.py). Decoupled from public publication so " +
        "internal consumers stay fresh while the public-snapshot incident guard holds. " +
        "QM-TODO-20260821-202. Rollback: schtasks /delete /tn $TaskName /f") `
    -Force | Out-Null

Enable-ScheduledTask -TaskName $TaskName | Out-Null

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $TaskName
}

Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo
