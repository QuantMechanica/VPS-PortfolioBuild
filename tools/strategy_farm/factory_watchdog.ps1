# =====================================================================
#  QuantMechanica - Factory Watchdog (in-session, self-healing)
#  Covers the gap the boot-autostart (FactoryON_AtLogon) does NOT:
#  the interactive session is alive but the worker daemons / MT5
#  terminals have died (crash, hang, OOM kill). Respawns ONLY the
#  missing workers, in THIS session, so the visible-mode factory keeps
#  producing without a manual "Factory ON" click.
#
#  MUST run in the interactive (autologon) session, RunLevel=Highest -
#  a SYSTEM/session-0 task cannot spawn visible terminals (that is the
#  exact reason the hourly_monitor only ESCALATES "factory down" and
#  Repair_Hourly/TerminalWorkers are ENFORCE_DISABLED). This watchdog is
#  the in-session complement to that session-0 triage monitor.
#
#  Deterministic + respects OWNER's ON/OFF:
#    - OWNER intent is read from the FACTORY tasks' enable-state
#      (Factory ON enables Pump/Tick, Factory OFF disables them).
#      If the factory is intentionally OFF -> do NOTHING.
#    - If ON and live workers < MinWorkers -> run start_terminal_workers
#      --dedupe (idempotent: fills only the missing slots, never doubles,
#      never interrupts a running backtest).
#    - NEVER toggles FACTORY/AI enable-state, NEVER touches T_Live,
#      no email (NO ping-mail policy). One JSON line to the triage log.
# =====================================================================

param(
    [int]$MinWorkers = 8,            # heal when fewer than this many worker daemons are alive
    [int]$ExpectWorkers = 10
)

$ErrorActionPreference = 'Continue'
$repo = 'C:\QM\repo'
$py   = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$log  = 'D:\QM\reports\state\factory_watchdog.jsonl'
. (Join-Path $PSScriptRoot 'qm_tasks.manifest.ps1')

$now    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$action = 'none'
$detail = ''

# 1. OWNER intent: is the factory meant to be ON? (FACTORY tasks enabled?)
$factoryEnabled = $false
foreach ($t in $QM_FACTORY_TASKS) {
    $task = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($task -and $task.State -ne 'Disabled') { $factoryEnabled = $true }
}

# 2. how many worker daemons are alive right now?
$daemons = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -match 'terminal_worker\.py' })
$nWorkers = $daemons.Count

if (-not $factoryEnabled) {
    $action = 'noop_factory_off'
    $detail = "FACTORY tasks disabled (OWNER OFF); workers=$nWorkers - leaving alone"
}
elseif ($nWorkers -ge $MinWorkers) {
    $action = 'noop_healthy'
    $detail = "workers=$nWorkers/$ExpectWorkers (>= $MinWorkers)"
}
else {
    # 3. heal: factory is meant ON but workers are dead/short -> respawn the missing ones
    $detail = "workers=$nWorkers/$ExpectWorkers (< $MinWorkers) while factory ON -> respawning missing"
    try {
        & $py (Join-Path $repo 'tools\strategy_farm\start_terminal_workers.py') `
            --repo-root $repo --farm-root 'D:\QM\strategy_farm' --dedupe 2>$null | Out-Null
        Start-Sleep -Seconds 10
        $after = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" -ErrorAction SilentlyContinue |
                   Where-Object { $_.CommandLine -match 'terminal_worker\.py' }).Count
        $action = 'healed_respawn_workers'
        $detail += " -> after=$after/$ExpectWorkers"
    } catch {
        $action = 'heal_failed'
        $detail += " -> ERROR: $_"
    }
}

# 4. record (rolling JSONL, keep last 500). No email.
$record = [ordered]@{
    ts              = $now
    factory_enabled = $factoryEnabled
    workers         = $nWorkers
    expect          = $ExpectWorkers
    action          = $action
    detail          = $detail
} | ConvertTo-Json -Compress -Depth 4

try {
    $dir = Split-Path $log -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -Path $log -Value $record -Encoding UTF8
    $lines = Get-Content $log -ErrorAction SilentlyContinue
    if ($lines -and $lines.Count -gt 500) { Set-Content -Path $log -Value ($lines | Select-Object -Last 500) -Encoding UTF8 }
} catch { }

Write-Output $record
