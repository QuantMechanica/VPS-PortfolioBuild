param(
    [string]$TaskName = "QM_PythonRuntimeHealth_10min",
    [int]$EveryMinutes = 10,
    [string]$RepoRoot = "C:\QM\repo",
    [string]$MonitorScript = "",
    [string]$PythonExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe",
    [string]$ExpectedPrefix = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311",
    [switch]$SkipPip,
    [switch]$PreviewOnly
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($MonitorScript)) {
    $MonitorScript = Join-Path $RepoRoot "infra\monitoring\Test-PythonRuntimeHealth.ps1"
}

if (-not (Test-Path -LiteralPath $MonitorScript)) {
    throw "Monitor script not found: $MonitorScript"
}

if ($EveryMinutes -lt 1) {
    throw "-EveryMinutes must be >= 1"
}

$skipPipArg = if ($SkipPip.IsPresent) { " -SkipPip" } else { "" }
$psArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$MonitorScript`" -PythonExe `"$PythonExe`" -ExpectedPrefix `"$ExpectedPrefix`"$skipPipArg"

if ($PreviewOnly.IsPresent) {
    Write-Host ("preview_task_name={0}" -f $TaskName)
    Write-Host ("preview_schedule_minutes={0}" -f $EveryMinutes)
    Write-Host ("preview_action=powershell.exe {0}" -f $psArgs)
    exit 0
}

$taskCmd = "powershell.exe $psArgs"
$createArgs = @(
    '/Create',
    '/TN', $TaskName,
    '/SC', 'MINUTE',
    '/MO', "$EveryMinutes",
    '/TR', $taskCmd,
    '/RU', 'SYSTEM',
    '/F'
)

$createOut = & schtasks.exe @createArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    throw ("schtasks create failed exit_code={0} output={1}" -f $LASTEXITCODE, (($createOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine))
}

$changeOut = & schtasks.exe /Change /TN $TaskName /RL HIGHEST 2>&1
if ($LASTEXITCODE -ne 0) {
    throw ("schtasks rl change failed exit_code={0} output={1}" -f $LASTEXITCODE, (($changeOut | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine))
}

Write-Host ("installed_task={0}" -f $TaskName)
Write-Host ("schedule_minutes={0}" -f $EveryMinutes)
Write-Host ("action=powershell.exe {0}" -f $psArgs)
