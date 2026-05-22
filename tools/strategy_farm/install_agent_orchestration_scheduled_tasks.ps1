[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonwExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe",
    [int]$EveryMinutes = 10,
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$wrapper = Join-Path $RepoRoot "tools\strategy_farm\run_agent_orchestration_task.py"
if (-not (Test-Path -LiteralPath $PythonwExe)) {
    throw "pythonw.exe not found: $PythonwExe"
}
if (-not (Test-Path -LiteralPath $wrapper)) {
    throw "Wrapper not found: $wrapper"
}

$definitions = @(
    @{ Name = "QM_StrategyFarm_CodexOrchestration_15min"; Agent = "codex" },
    @{ Name = "QM_StrategyFarm_GeminiOrchestration_15min"; Agent = "gemini" }
)

$startBoundary = (Get-Date).Date
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances Parallel `
    -ExecutionTimeLimit (New-TimeSpan -Hours 4)

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$registered = @()
foreach ($definition in $definitions) {
    $taskName = [string]$definition.Name
    $agent = [string]$definition.Agent
    $arguments = "`"$wrapper`" --agent $agent"
    $action = New-ScheduledTaskAction `
        -Execute $PythonwExe `
        -Argument $arguments `
        -WorkingDirectory $RepoRoot

    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "Headless single-pass $agent orchestration cycle for Strategy Farm agent_tasks." `
        -Force | Out-Null

    Enable-ScheduledTask -TaskName $taskName | Out-Null

    if ($RunNow.IsPresent) {
        Start-ScheduledTask -TaskName $taskName
    }

    $task = Get-ScheduledTask -TaskName $taskName
    $info = Get-ScheduledTaskInfo -TaskName $taskName
    $registered += [pscustomobject]@{
        TaskName = $task.TaskName
        State = $task.State
        UserId = $task.Principal.UserId
        LogonType = $task.Principal.LogonType
        RunLevel = $task.Principal.RunLevel
        Execute = $task.Actions.Execute
        Arguments = $task.Actions.Arguments
        LastTaskResult = $info.LastTaskResult
        NextRunTime = $info.NextRunTime
    }
}

$registered
