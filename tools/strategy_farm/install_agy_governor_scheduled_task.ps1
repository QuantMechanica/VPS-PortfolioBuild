[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonwExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe",
    [int]$EveryMinutes = 10,
    [string]$UserId = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name),
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# agy quota governor: pulls the Antigravity/Gemini quota and raises/clears the
# AGY_LOW_QUOTA.flag gate. MUST run as Administrator with LogonType Interactive:
# the OAuth token lives in the Administrator user's DPAPI credential vault
# (Credential Manager target gemini:antigravity). SYSTEM / S4U cannot decrypt it
# (no password-derived DPAPI key), so this only works in the logged-on
# Administrator session -- which is exactly when the factory + agy run.
$taskName = "QM_StrategyFarm_AgyGovernor"
$script = Join-Path $RepoRoot "tools\strategy_farm\agy_governor.py"

if (-not (Test-Path -LiteralPath $PythonwExe)) { throw "pythonw.exe not found: $PythonwExe" }
if (-not (Test-Path -LiteralPath $script)) { throw "agy_governor.py not found: $script" }

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

# Interactive logon for the Administrator account = has the DPAPI key to read the
# credential vault. Runs only while Administrator is logged on (the factory's
# normal state); when no session, agy isn't running so no gating is needed.
$principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType Interactive -RunLevel Highest

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$action = New-ScheduledTaskAction -Execute $PythonwExe -Argument "`"$script`"" -WorkingDirectory $RepoRoot

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "agy (Antigravity/Gemini) quota governor: pull quota + raise/clear AGY_LOW_QUOTA.flag (every $EveryMinutes min, Administrator/Interactive for the DPAPI credential vault)." `
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
