# =====================================================================
#  QuantMechanica - Tester-Cache Purge (permanent fix for D: fill-up)
#  Periodically reclaims the regenerable MT5 tester history caches that
#  otherwise fill D: over ~days of backtesting (incident 2026-06-02).
#
#  Clears ONLY regenerable caches:
#    D:\QM\mt5\T<n>\Tester\bases\*   (tester history .hcc cache)
#    D:\QM\mt5\T<n>\Tester\Agent-*   (per-agent working dirs; MT5 recreates)
#  NEVER touches source tick data (T<n>\Bases top-level) or reports (D:\QM\reports).
#
#  Only acts when D: free < LowWaterGB (default 80) — most runs are no-ops.
#  When it acts: stop factory -> clear caches -> restart factory. Because MT5
#  agents read these caches mid-run, the factory MUST be stopped first.
#
#  MUST run as the INTERACTIVE qm-admin user (NOT SYSTEM) so the restarted
#  worker daemons land in OWNER's visible RDP session (visible-mode policy).
#  If qm-admin is not logged on, the task doesn't fire and the factory isn't
#  running anyway — consistent.
# =====================================================================
[CmdletBinding()]
param(
    [int]$LowWaterGB = 80,
    [string]$RepoRoot = "C:\QM\repo",
    [string]$FarmRoot = "D:\QM\strategy_farm",
    [switch]$DryRun
)
$ErrorActionPreference = 'Continue'
$py = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$log = "D:\QM\reports\state\tester_cache_purge.log"
function Now { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
function FreeGB { [math]::Round((Get-PSDrive D).Free/1GB,2) }
function Log($m) { $line = "$(Now) $m"; Write-Output $line; try { Add-Content -Path $log -Value $line -Encoding UTF8 } catch {} }

$free = FreeGB
if ($free -ge $LowWaterGB) { Log "SKIP: D: free ${free}GB >= ${LowWaterGB}GB threshold"; return }

Log "TRIGGER: D: free ${free}GB < ${LowWaterGB}GB -> purge tester caches"
if ($DryRun) { Log "DRYRUN: would stop factory, clear T*\Tester\bases + Agent-*, restart"; return }

# 1. stop factory (caches are read by running agents)
Stop-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue | Out-Null
Disable-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue | Out-Null
Stop-ScheduledTask -TaskName 'QM_StrategyFarm_Tick_5min' -ErrorAction SilentlyContinue | Out-Null
Disable-ScheduledTask -TaskName 'QM_StrategyFarm_Tick_5min' -ErrorAction SilentlyContinue | Out-Null
@(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" |
    Where-Object CommandLine -match 'terminal_worker\.py') | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
@(Get-Process terminal64 -ErrorAction SilentlyContinue) | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 3
Log "factory stopped (workers + terminal64 killed; in-flight backtests re-queue)"

# 2. clear regenerable tester caches
foreach ($n in 1..10) {
    $t = "D:\QM\mt5\T$n"
    if (-not (Test-Path $t)) { continue }
    Get-ChildItem "$t\Tester\bases" -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    Get-ChildItem "$t\Tester" -Directory -Filter "Agent-*" -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
}
Start-Sleep -Seconds 2
$after = FreeGB
Log "caches cleared: D: ${free}GB -> ${after}GB (reclaimed $([math]::Round($after-$free,1))GB)"

# 3. restart factory INTO the autologon console session (visible-mode) via the
#    console-session launcher. This task runs as SYSTEM (SeTcb) so the launcher
#    can CreateProcessAsUser into qm-admin's session even when RDP is DISCONNECTED.
#    A plain `& $py ...` here would land workers in SYSTEM's session-0 (hazard).
#    Workers were all killed above, so start_terminal_workers spawns a clean 10
#    (its --dedupe CIM scan is irrelevant with nothing to dedupe).
Enable-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue | Out-Null
Enable-ScheduledTask -TaskName 'QM_StrategyFarm_Tick_5min' -ErrorAction SilentlyContinue | Out-Null
$launcher = Join-Path $RepoRoot 'tools\strategy_farm\run_in_console_session.ps1'
$swArgs = '"' + (Join-Path $RepoRoot 'tools\strategy_farm\start_terminal_workers.py') + '" --repo-root "' + $RepoRoot + '" --farm-root "' + $FarmRoot + '" --dedupe'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher -Exe $py -Arguments $swArgs -WorkDir $RepoRoot | Out-Null
Start-Sleep -Seconds 12
$daemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" | Where-Object CommandLine -match 'terminal_worker\.py')
Start-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue
Log "factory restarted: $($daemons.Count)/10 workers (console-session launcher); pump triggered; D: free $(FreeGB)GB"
