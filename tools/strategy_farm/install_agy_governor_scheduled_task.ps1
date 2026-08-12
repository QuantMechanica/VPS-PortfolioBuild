[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonwExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe",
    [int]$EveryMinutes = 10,
    [string]$UserId = 'qm-admin',
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# agy quota governor: pulls the Antigravity/Gemini quota and raises/clears the
# AGY_LOW_QUOTA.flag gate. The scheduler root runs as SYSTEM, then the approved
# console-session helper launches pythonw with the logged-on qm-admin token so
# the child can use that user's DPAPI credential vault.
$taskName = "QM_StrategyFarm_AgyGovernor"
$script = Join-Path $RepoRoot "tools\strategy_farm\agy_governor.py"
$helper = Join-Path $RepoRoot "tools\strategy_farm\run_in_console_session.ps1"
$powerShellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

if (-not (Test-Path -LiteralPath $PythonwExe)) { throw "pythonw.exe not found: $PythonwExe" }
if (-not (Test-Path -LiteralPath $script)) { throw "agy_governor.py not found: $script" }
if (-not (Test-Path -LiteralPath $helper)) { throw "console-session helper not found: $helper" }
if ($UserId -ne 'qm-admin') { throw "Agy governor target user must be qm-admin, not $UserId" }

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$actionArguments = (
    '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Exe "{1}" -Arguments "{2}" -WorkDir "{3}" -TargetUser "{4}" -WaitSeconds 240' -f `
        $helper, $PythonwExe, $script, $RepoRoot, $UserId
)
if ($actionArguments.Contains("'")) {
    throw 'MNT-003 v2 action must not contain literal apostrophe wrappers.'
}
$action = New-ScheduledTaskAction `
    -Execute $powerShellExe `
    -Argument $actionArguments `
    -WorkingDirectory $RepoRoot

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "agy (Antigravity/Gemini) quota governor: SYSTEM scheduler root bridges into the logged-on qm-admin session for DPAPI-backed quota access (every $EveryMinutes min)." `
    -Force | Out-Null

Enable-ScheduledTask -TaskName $taskName | Out-Null
if ($RunNow.IsPresent) { Start-ScheduledTask -TaskName $taskName }

$task = Get-ScheduledTask -TaskName $taskName
$info = Get-ScheduledTaskInfo -TaskName $taskName
[pscustomobject]@{
    TaskName = $task.TaskName
    State = $task.State
    UserId = $task.Principal.UserId
    LogonType = $task.Principal.LogonType
    RunLevel = $task.Principal.RunLevel
    Execute = $task.Actions.Execute
    Arguments = $task.Actions.Arguments
    NextRunTime = $info.NextRunTime
}
