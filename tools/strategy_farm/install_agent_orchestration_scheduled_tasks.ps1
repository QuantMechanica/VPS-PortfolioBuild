[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonwExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe",
    [int]$EveryMinutes = 15,
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

# MaxSessions = concurrent headless sessions per orchestration run, per agent.
# Claude raised to 5 (OWNER directive 2026-06-01); must stay in sync with
# agent_router DEFAULT_AGENT_REGISTRY max_parallel (routing cap) and
# CLAUDE_BUDGET_POLICY.json max_sessions_per_run (budget cap).
#
# CODEX MUST STAY AT 1: codex CLI shares a single ~/.codex/auth.json OAuth
# token across all processes. Concurrent sessions race on token refresh
# ("refresh_token_reused" 401) and INVALIDATE the whole login. Setting codex=5
# on 2026-06-01 re-broke auth ~54min after re-login (evidence:
# codex_g0_*.live.log "Your refresh token has already been used"). 5 concurrent
# codex would need 5 separate Codex OAuth logins, which we do not have. Codex
# throughput comes from the pump's build dispatch + router, not parallel
# orchestration sessions. DO NOT raise without per-session auth isolation.
$definitions = @(
    @{ Name = "QM_StrategyFarm_CodexOrchestration_15min"; Agent = "codex"; MaxSessions = 1 },
    @{ Name = "QM_StrategyFarm_GeminiOrchestration_15min"; Agent = "gemini"; MaxSessions = 1 },
    @{ Name = "QM_StrategyFarm_ClaudeOrchestration_15min"; Agent = "claude"; MaxSessions = 5 }
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
    $maxSessions = [int]$definition.MaxSessions
    $arguments = "`"$wrapper`" --agent $agent --max-sessions $maxSessions"
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
