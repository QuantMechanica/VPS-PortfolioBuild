[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [int]$EveryMinutes = 20   # 2026-06-21: 60->20min after a fast cache-burn breached 40GB between hourly runs
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$taskName = "QM_StrategyFarm_TesterCachePurge"
$script   = Join-Path $RepoRoot "tools\strategy_farm\tester_cache_purge.ps1"
if (-not (Test-Path -LiteralPath $script)) { throw "purge script not found: $script" }
$tokens = $null
$parseErrors = $null
[Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count) { throw "purge script parse failed: $(($parseErrors.Message) -join '; ')" }
$dedupe = Get-ScheduledTask -TaskName 'QM_StrategyFarm_WorkerDedupe' -ErrorAction Stop
if ([string]$dedupe.Principal.LogonType -ne 'Interactive' -or $dedupe.Actions[0].Arguments -notlike '*start_terminal_workers.py*--dedupe*') {
    throw 'QM_StrategyFarm_WorkerDedupe contract invalid; refusing to install purge recovery'
}

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
# SYSTEM performs disk/cache maintenance; it never launches a worker directly.
# Missing workers are delegated to the validated qm-admin InteractiveToken task.
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`"" `
    -WorkingDirectory $RepoRoot

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force `
    -Description "Every ${EveryMinutes}min: if D: free < 150GB, preserve active slots and captured Factory ON/OFF state, purge only idle regenerable T* tester caches, then start only missing workers through qm-admin Interactive WorkerDedupe. Never touches T_Live/FTMO/source ticks/reports." | Out-Null
Enable-ScheduledTask -TaskName $taskName | Out-Null

Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State,
    @{N='Principal';E={$_.Principal.UserId}}, @{N='LogonType';E={$_.Principal.LogonType}},
    @{N='NextRun';E={(Get-ScheduledTaskInfo $_.TaskName).NextRunTime}}
