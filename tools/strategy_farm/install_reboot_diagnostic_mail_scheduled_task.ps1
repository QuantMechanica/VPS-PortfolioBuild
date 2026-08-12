[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe",
    [int]$DelayMinutes = 5,
    [switch]$RunNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$taskName = "QM_StrategyFarm_RebootDiagnostic_AtStartup"
$wrapper = Join-Path $RepoRoot "tools\strategy_farm\run_reboot_diagnostic_mail_task.py"
$diagnostic = Join-Path $RepoRoot "tools\strategy_farm\reboot_diagnostic_mail.py"
if (-not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) {
    throw "python.exe not found: $PythonExe"
}
if (-not (Test-Path -LiteralPath $wrapper -PathType Leaf)) {
    throw "reboot diagnostic wrapper not found: $wrapper"
}
if (-not (Test-Path -LiteralPath $diagnostic -PathType Leaf)) {
    throw "reboot diagnostic script not found: $diagnostic"
}
if ($DelayMinutes -lt 1 -or $DelayMinutes -gt 30) {
    throw "DelayMinutes must be between 1 and 30"
}

$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = "PT${DelayMinutes}M"
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -RestartCount 6 `
    -RestartInterval (New-TimeSpan -Minutes 5) `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest
$action = New-ScheduledTaskAction `
    -Execute $PythonExe `
    -Argument "`"$wrapper`"" `
    -WorkingDirectory $RepoRoot

# Establish a no-mail baseline for the installation boot. The next genuinely
# different boot is then reportable even when no Factory-Watchdog marker exists.
& $PythonExe $diagnostic --initialize-current-boot
if ($LASTEXITCODE -ne 0) {
    throw "Could not initialize reboot diagnostic baseline (exit $LASTEXITCODE)"
}

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Force `
    -Description "Five minutes after startup, send one deduplicated evidence-based cause mail for each new Windows boot; retry failed delivery up to six times; verified QM watchdog markers receive the detailed factory analysis." |
    Out-Null
Enable-ScheduledTask -TaskName $taskName | Out-Null

if ($RunNow.IsPresent) {
    # Safe on ordinary installs: this boot was baselined above, so the wrapper
    # records a no-op and sends no mail.
    Start-ScheduledTask -TaskName $taskName
}

Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State,
    @{N='NextRun';E={(Get-ScheduledTaskInfo $_.TaskName).NextRunTime}}
