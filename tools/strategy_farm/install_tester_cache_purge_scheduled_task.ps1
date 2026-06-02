[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [int]$EveryHours = 3,
    [string]$UserId = "qm-admin"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$taskName = "QM_StrategyFarm_TesterCachePurge"
$script   = Join-Path $RepoRoot "tools\strategy_farm\tester_cache_purge.ps1"
if (-not (Test-Path -LiteralPath $script)) { throw "purge script not found: $script" }

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Hours $EveryHours) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
# INTERACTIVE principal (NOT SYSTEM) so restarted workers land in OWNER's visible
# RDP session. Task only runs when qm-admin is logged on (factory only runs then anyway).
$principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType Interactive -RunLevel Highest
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`"" `
    -WorkingDirectory $RepoRoot

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force `
    -Description "Every ${EveryHours}h: if D: free < 80GB, stop factory, purge regenerable MT5 tester caches (T*\Tester\bases + Agent-*), restart factory in the user's visible session. Permanent fix for D: fill-up (incident 2026-06-02). Source tick data + reports never touched." | Out-Null
Enable-ScheduledTask -TaskName $taskName | Out-Null

Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State,
    @{N='Principal';E={$_.Principal.UserId}}, @{N='LogonType';E={$_.Principal.LogonType}},
    @{N='NextRun';E={(Get-ScheduledTaskInfo $_.TaskName).NextRunTime}}
