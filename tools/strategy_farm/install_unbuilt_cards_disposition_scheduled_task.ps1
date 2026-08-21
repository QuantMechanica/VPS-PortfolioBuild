[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonwExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe",
    [int]$EveryMinutes = 60,
    [switch]$RunNow
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# MNT-013: schedules the READY/NEEDS_SOURCE/DATA_BLOCKED disposition snapshot
# that chk_unbuilt_cards_count (health.py) reads to enrich the bare
# unbuilt_cards_count WARN/FAIL with a bucket breakdown. Read-only: never
# creates build tasks, never touches cards/work_items/pipeline state. Hourly
# matches the Dashboard/ReconcileOrphans cadence; a manual run measured
# ~15s for 365 cards, so this stays cheap at that interval.
$taskName = "QM_StrategyFarm_UnbuiltCardsDisposition_Hourly"
$script   = Join-Path $RepoRoot "tools\strategy_farm\unbuilt_cards_disposition.py"
if (-not (Test-Path -LiteralPath $PythonwExe)) { throw "pythonw.exe not found: $PythonwExe" }
if (-not (Test-Path -LiteralPath $script)) { throw "unbuilt_cards_disposition.py not found: $script" }

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$action = New-ScheduledTaskAction -Execute $PythonwExe `
    -Argument "`"$script`"" `
    -WorkingDirectory $RepoRoot

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force `
    -Description "Read-only approved-cards backlog disposition snapshot (READY/NEEDS_SOURCE/DATA_BLOCKED) for chk_unbuilt_cards_count, every $EveryMinutes min, SYSTEM. Writes D:\QM\reports\state\unbuilt_cards_disposition\snapshot_*.json. Never creates build tasks or touches pipeline state. MNT-013." | Out-Null
Enable-ScheduledTask -TaskName $taskName | Out-Null
if ($RunNow.IsPresent) { Start-ScheduledTask -TaskName $taskName }

Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State,
    @{N='NextRun';E={(Get-ScheduledTaskInfo $_.TaskName).NextRunTime}}
