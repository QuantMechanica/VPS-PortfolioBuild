[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonwExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe",
    [string]$TaskUser = "qm-admin",
    [switch]$RunNow,
    [switch]$Uninstall
)
# Weekly Book Evolution ceremony (OWNER-DEC-CBE-20260915, Phase H). Registers the five
# SYSTEM tasks that drive tools\strategy_farm\book_evolution_runner.py end to end:
#   QM_BookEvolution_FridayEvidenceCut         Fri 23:15 local  (after NY close incl. DST slack)
#   QM_BookEvolution_SaturdayAnalysis          Sat 06:00        (evaluate + cross-review)
#   QM_BookEvolution_SundayRecommendation      Sun 09:00        (OWNER package + CHANGE cards)
#   QM_BookEvolution_RuntimeVerify             Mon 06:30        (read-only runtime identity)
#   QM_StrategyFarm_BookEvolutionReadModels_15min  every 15 min (supporting read-models)
# The runner never deploys, toggles AutoTrading, starts terminal64, or buys anything —
# all of that stays OWNER-only. Rollback: -Uninstall (the produced reports/cards stay;
# a card is answered/ignored in Mission Control, never deleted by this installer).
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$runner = Join-Path $RepoRoot "tools\strategy_farm\book_evolution_runner.py"

$weeklyTasks = @(
    @{ Name = "QM_BookEvolution_FridayEvidenceCut";    Day = "Friday";   At = "23:15"; Args = "friday-cut" },
    @{ Name = "QM_BookEvolution_SaturdayAnalysis";     Day = "Saturday"; At = "06:00"; Args = "saturday-analysis" },
    @{ Name = "QM_BookEvolution_SundayRecommendation"; Day = "Sunday";   At = "09:00"; Args = "sunday-recommendation" },
    @{ Name = "QM_BookEvolution_RuntimeVerify";        Day = "Monday";   At = "06:30"; Args = "runtime-verify" }
)
$readModelsTask = "QM_StrategyFarm_BookEvolutionReadModels_15min"
$allNames = @($weeklyTasks.Name) + $readModelsTask

if ($Uninstall) {
    foreach ($n in $allNames) {
        Unregister-ScheduledTask -TaskName $n -Confirm:$false -ErrorAction SilentlyContinue
        Write-Output "UNINSTALLED $n"
    }
    return
}

foreach ($p in @($PythonwExe, $runner)) { if (-not (Test-Path -LiteralPath $p)) { throw "missing: $p" } }

# 2026-09-15 incident repair: SYSTEM has no G: drive mapping and would taint
# repo/report file ownership; the interactive qm-admin session is permanent on
# this VPS (same pattern as QM_Live_MT5_SessionSupervisor).
$principal = New-ScheduledTaskPrincipal -UserId $TaskUser -LogonType Interactive -RunLevel Highest

# --- four weekly ceremony tasks (local-time triggers; DST handled by the OS clock) ---
foreach ($t in $weeklyTasks) {
    $trigger  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $t.Day -At $t.At
    $action   = New-ScheduledTaskAction -Execute $PythonwExe -Argument "-X utf8 `"$runner`" $($t.Args)" -WorkingDirectory $RepoRoot
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 2) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $t.Name -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    Write-Output "REGISTERED $($t.Name) $($t.Day) $($t.At)"
}

# --- supporting read-models, every 15 minutes (IgnoreNew, 5-min limit) ---
$startBoundary = (Get-Date).Date.AddHours((Get-Date).Hour).AddMinutes(7)
$rmTrigger  = New-ScheduledTaskTrigger -Once -At $startBoundary -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days 3650)
$rmAction   = New-ScheduledTaskAction -Execute $PythonwExe -Argument "-X utf8 `"$runner`" readmodels" -WorkingDirectory $RepoRoot
$rmSettings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $readModelsTask -Action $rmAction -Trigger $rmTrigger -Settings $rmSettings -Principal $principal -Force | Out-Null
Write-Output "REGISTERED $readModelsTask every 15 min, first at $startBoundary"

if ($RunNow) {
    foreach ($n in $allNames) { Start-ScheduledTask -TaskName $n; Write-Output "STARTED $n" }
}
