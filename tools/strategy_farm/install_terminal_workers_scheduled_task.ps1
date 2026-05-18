param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$FarmRoot = "D:\QM\strategy_farm",
    [string]$TaskName = "QM_StrategyFarm_TerminalWorkers_AT_STARTUP"
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $RepoRoot "tools\strategy_farm\start_terminal_workers.ps1"
$argument = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -RepoRoot `"$RepoRoot`" -FarmRoot `"$FarmRoot`""

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argument
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
