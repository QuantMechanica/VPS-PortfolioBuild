[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonwExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe",
    [int]$EveryMinutes = 15,
    [int]$MaxPerRun = 2,
    [switch]$RunNow,
    [switch]$Uninstall
)
# Creator -> Critic -> Formatter chain: bounded sweep over agent_tasks REVIEW rows without a
# critique receipt (OWNER 2026-09-15). Runs like the agent lanes: SYSTEM task that hands the
# child to the interactive console session (MNT-003 v2 helper) so the headless CLIs find the
# operator profile and credentials. Read-only towards the farm; kill switch QM_AGENT_CHAIN=0.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$taskName = "QM_StrategyFarm_AgentChain_Critique_15min"
$runner = Join-Path $RepoRoot "tools\strategy_farm\agent_chain.py"
$helper = Join-Path $RepoRoot "tools\strategy_farm\run_in_console_session.ps1"
$powerShellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$targetUser = "qm-admin"

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Output "UNINSTALLED $taskName"
    return
}
foreach ($p in @($PythonwExe, $runner, $helper)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "missing: $p" }
}
# Offset by 7 minutes against the lane runners (:00/:15/:30/:45) so the sweep sees fresh REVIEW rows.
$startBoundary = (Get-Date).Date.AddHours((Get-Date).Hour).AddMinutes(7)
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)
$childArguments = "`"$runner`" critique-pending --apply --max $MaxPerRun"
$arguments = (
    '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Exe "{1}" -Arguments "{2}" -WorkDir "{3}" -TargetUser "{4}" -WaitSeconds 3300' -f `
        $helper, $PythonwExe, $childArguments, $RepoRoot, $targetUser
)
$action = New-ScheduledTaskAction -Execute $powerShellExe -Argument $arguments -WorkingDirectory $RepoRoot
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Write-Output "REGISTERED $taskName every $EveryMinutes min, max $MaxPerRun critiques per run, first at $startBoundary"
if ($RunNow) { Start-ScheduledTask -TaskName $taskName; Write-Output "STARTED $taskName" }
