param(
    [string]$TaskName = "QM_StrategyFarm_ContinuousRetention_45min",
    [int]$EveryMinutes = 45
)

$ErrorActionPreference = "Stop"
if ($EveryMinutes -lt 30 -or $EveryMinutes -gt 60) {
    throw "EveryMinutes must be between 30 and 60"
}

$python = "C:\Python311\python.exe"
$repo = "C:\QM\repo"
$runner = Join-Path $repo "tools\strategy_farm\continuous_retention_runner.py"
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) { throw "Python missing: $python" }
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) { throw "Runner missing: $runner" }

$action = New-ScheduledTaskAction `
    -Execute $python `
    -Argument ('"{0}" --apply' -f $runner) `
    -WorkingDirectory $repo
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(2)) `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 40) `
    -StartWhenAvailable `
    -Hidden

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings `
    -Description "Fail-closed OWNER retention: DB quick_check, newest-10+14d backup rotation/compression, >2h closed-evidence NTFS compression, and 48h log rotation. No-op above 150 GiB free." `
    -Force | Out-Null

Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName,State
