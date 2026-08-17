[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [int]$EveryMinutes = 20   # 2026-06-21: 60->20min after a fast cache-burn breached 40GB between hourly runs
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$taskName = "QM_StrategyFarm_TesterCachePurge"
$script   = Join-Path $RepoRoot "tools\strategy_farm\tester_cache_purge.ps1"
$launcher = Join-Path $RepoRoot "tools\strategy_farm\run_in_console_session.ps1"
$starter  = Join-Path $RepoRoot "tools\strategy_farm\start_terminal_workers.py"
if (-not (Test-Path -LiteralPath $script)) { throw "purge script not found: $script" }
if (-not (Test-Path -LiteralPath $launcher)) { throw "interactive-session launcher not found: $launcher" }
if (-not (Test-Path -LiteralPath $starter)) { throw "worker starter not found: $starter" }
$tokens = $null
$parseErrors = $null
[Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count) { throw "purge script parse failed: $(($parseErrors.Message) -join '; ')" }
$launcherTokens = $null
$launcherParseErrors = $null
[Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$launcherTokens, [ref]$launcherParseErrors) | Out-Null
if ($launcherParseErrors.Count) { throw "interactive-session launcher parse failed: $(($launcherParseErrors.Message) -join '; ')" }

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
# SYSTEM performs disk/cache maintenance. Missing workers are spawned with the
# logged-on user's token through the validated interactive-session launcher.
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`"" `
    -WorkingDirectory $RepoRoot

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force `
    -Description "Every ${EveryMinutes}min: reclaim only aged, exclusively-openable bar*.tmp scratch from T1-T10 agent temp; then, if D: free < 150GB, preserve active slots and captured Factory ON/OFF state, purge only idle regenerable T* tester caches, and request only missing workers. Never touches T_Live/FTMO/source ticks/reports." | Out-Null
Enable-ScheduledTask -TaskName $taskName | Out-Null

Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State,
    @{N='Principal';E={$_.Principal.UserId}}, @{N='LogonType';E={$_.Principal.LogonType}},
    @{N='NextRun';E={(Get-ScheduledTaskInfo $_.TaskName).NextRunTime}}
