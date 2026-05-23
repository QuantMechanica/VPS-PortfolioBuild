param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$FarmRoot = "D:\QM\strategy_farm",
    [string]$TaskName = "QM_StrategyFarm_TerminalWorkers_AT_STARTUP",
    [string]$PythonExe = "python.exe"
)

$ErrorActionPreference = "Stop"

$starter = Join-Path $RepoRoot "tools\strategy_farm\start_terminal_workers.py"
if (-not (Test-Path -LiteralPath $starter -PathType Leaf)) {
    throw "Missing worker starter: $starter"
}

$resolvedPythonExe = $PythonExe
if (-not [System.IO.Path]::IsPathRooted($resolvedPythonExe)) {
    $pyCmd = Get-Command -Name $resolvedPythonExe -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $pyCmd -or [string]::IsNullOrWhiteSpace($pyCmd.Source)) {
        throw "Python executable '$PythonExe' is not resolvable to an absolute path."
    }
    $resolvedPythonExe = $pyCmd.Source
}
if (-not (Test-Path -LiteralPath $resolvedPythonExe -PathType Leaf)) {
    throw "Python executable not found: $resolvedPythonExe"
}

$argument = "`"$starter`" --repo-root `"$RepoRoot`" --farm-root `"$FarmRoot`""
$action = New-ScheduledTaskAction -Execute $resolvedPythonExe -Argument $argument -WorkingDirectory $RepoRoot
$startup = New-ScheduledTaskTrigger -AtStartup
$heartbeat = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 5)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger @($startup, $heartbeat) `
    -Settings $settings `
    -Principal $principal `
    -Force
