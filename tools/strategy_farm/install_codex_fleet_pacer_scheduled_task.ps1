# Registers QM_StrategyFarm_CodexFleetPacer — paces a headless Codex fleet to the weekly cap
# (continuous work to reset, never a cap-stop). The task root is SYSTEM; the approved console-
# session helper launches the pacer with the logged-on qm-admin token in session 1.
# Re-run after a reboot if the task is missing (autologon provides session 1).
$ErrorActionPreference = "Stop"
$py = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe"
$taskName = "QM_StrategyFarm_CodexFleetPacer"
$repoRoot = "C:\QM\repo"
$script = "$repoRoot\tools\strategy_farm\codex_fleet_pacer.py"
$helper = "$repoRoot\tools\strategy_farm\run_in_console_session.ps1"
$powerShellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$targetUser = "qm-admin"
foreach ($path in @($py, $script, $helper)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "required path not found: $path" }
}
$actionArguments = (
    '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Exe "{1}" -Arguments "{2}" -WorkDir "{3}" -TargetUser "{4}" -WaitSeconds 300' -f `
        $helper, $py, $script, $repoRoot, $targetUser
)
if ($actionArguments.Contains("'")) {
    throw 'MNT-003 v2 action must not contain literal apostrophe wrappers.'
}
$action = New-ScheduledTaskAction `
    -Execute $powerShellExe `
    -Argument $actionArguments `
    -WorkingDirectory $repoRoot
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration ([TimeSpan]::FromDays(3650))
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew
try { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop } catch {}
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Pace headless Codex fleet to weekly cap; SYSTEM root bridges to logged-on qm-admin session 1." | Out-Null
Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State
