[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonwExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe",
    [int]$EveryMinutes = 15,
    [switch]$RunNow,
    [switch]$Uninstall
)
# Kimi subscription/quota governor (OWNER-DEC-KIMI-INTEGRATION-20260915): evaluates the local
# usage ledger every 15 min and reconciles D:\QM\strategy_farm\KIMI_LOW_QUOTA.flag
# (MANAGED_BY=kimi_governor). No CLI call, no network, no purchase: plain SYSTEM task.
# Rollback: -Uninstall (the flag, if set, stays until kimi_governor.py evaluate clears it).
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$taskName = "QM_StrategyFarm_KimiGovernor_15min"
$governor = Join-Path $RepoRoot "tools\strategy_farm\kimi_governor.py"
if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Output "UNINSTALLED $taskName"
    return
}
foreach ($p in @($PythonwExe, $governor)) { if (-not (Test-Path -LiteralPath $p)) { throw "missing: $p" } }
$startBoundary = (Get-Date).Date.AddHours((Get-Date).Hour).AddMinutes(11)
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)
$action = New-ScheduledTaskAction -Execute $PythonwExe -Argument "-X utf8 `"$governor`" evaluate" -WorkingDirectory $RepoRoot
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Write-Output "REGISTERED $taskName every $EveryMinutes min, first at $startBoundary"
if ($RunNow) { Start-ScheduledTask -TaskName $taskName; Write-Output "STARTED $taskName" }
