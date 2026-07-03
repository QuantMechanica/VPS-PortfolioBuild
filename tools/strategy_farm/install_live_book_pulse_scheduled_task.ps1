[CmdletBinding()]
param(
    [string]$TaskName = "QM_StrategyFarm_LiveBookPulse",
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonwExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe",
    [string]$LiveRoot = "C:\QM\mt5\T_Live",
    [string]$MagicCsv = "C:\QM\repo\framework\registry\magic_numbers.csv",
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script = Join-Path $RepoRoot "tools\strategy_farm\live_book_pulse.py"
if (-not (Test-Path -LiteralPath $PythonwExe)) {
    throw "pythonw.exe not found: $PythonwExe"
}
if (-not (Test-Path -LiteralPath $script)) {
    throw "live_book_pulse.py not found: $script"
}
if (-not (Test-Path -LiteralPath $LiveRoot)) {
    throw "Live root not found: $LiveRoot"
}
if (-not (Test-Path -LiteralPath $MagicCsv)) {
    throw "magic_numbers.csv not found: $MagicCsv"
}

$action = New-ScheduledTaskAction `
    -Execute $PythonwExe `
    -Argument "`"$script`" --live-root `"$LiveRoot`" --magic-csv `"$MagicCsv`"" `
    -WorkingDirectory $RepoRoot

$startBoundary = (Get-Date).Date.AddHours((Get-Date).Hour).AddMinutes(30)
if ($startBoundary -le (Get-Date)) {
    $startBoundary = $startBoundary.AddMinutes(30)
}
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary `
    -RepetitionInterval (New-TimeSpan -Minutes 30) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Read-only T_Live journal and EA-log pulse monitor for the QM live book." `
    -Force | Out-Null

Enable-ScheduledTask -TaskName $TaskName | Out-Null

if ($RunNow.IsPresent) {
    Start-ScheduledTask -TaskName $TaskName
}

Get-ScheduledTask -TaskName $TaskName |
    Select-Object TaskName, State, @{n = "Action"; e = { $_.Actions.Execute + " " + $_.Actions.Arguments } }
