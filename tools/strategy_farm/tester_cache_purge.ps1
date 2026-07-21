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
#  Only acts when D: free < LowWaterGB (default 150) — most runs are no-ops.
#  When it acts: stop factory -> clear caches -> restart factory via the
#  FactoryON_AtLogon task (the reliable in-session recovery). Because MT5
#  agents read these caches mid-run, the factory MUST be stopped first.
#
#  MUST run as the INTERACTIVE qm-admin user (NOT SYSTEM) so the restarted
#  worker daemons land in OWNER's visible RDP session (visible-mode policy).
#  If qm-admin is not logged on, the task doesn't fire and the factory isn't
#  running anyway — consistent.
# =====================================================================
[CmdletBinding()]
param(
    # 2026-07-21 raised 80->150: on a 1TB disk an 80GB floor let ~200GB of regenerable
    # Tester cache accumulate (it purges only below the floor, and D: hovered just above 80).
    [int]$LowWaterGB = 150,
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
function Get-FactoryTerminalFromCommandLine {
    param([string]$CommandLine)
    if (-not $CommandLine) { return $null }
    if ($CommandLine -match '\\mt5\\(T(?:[1-9]|10))\\') { return $matches[1].ToUpperInvariant() }
    if ($CommandLine -match '--terminal\s+(T(?:[1-9]|10))\b') { return $matches[1].ToUpperInvariant() }
    return $null
}
function Get-ProtectedFactoryTerminals {
    $terms = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $probe = @'
import json
import sqlite3

out = []
try:
    conn = sqlite3.connect(r"D:/QM/strategy_farm/state/farm_state.sqlite")
    conn.row_factory = sqlite3.Row
    for row in conn.execute("SELECT claimed_by, payload_json FROM work_items WHERE status='active'"):
        term = (row["claimed_by"] or "").strip().upper()
        if not term:
            try:
                payload = json.loads(row["payload_json"] or "{}")
                term = str(payload.get("terminal") or "").strip().upper()
            except Exception:
                term = ""
        if term:
            out.append(term)
except Exception:
    pass
print(json.dumps(sorted(set(out))))
'@
    try {
        $activeTerms = (($probe | & $py - 2>$null) -join '' | ConvertFrom-Json)
        foreach ($t in @($activeTerms)) {
            if ($t -match '^T(?:[1-9]|10)$') { [void]$terms.Add($t.ToUpperInvariant()) }
        }
    } catch {}
    foreach ($p in @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue)) {
        $t = Get-FactoryTerminalFromCommandLine $p.CommandLine
        if ($t) { [void]$terms.Add($t) }
    }
    return @($terms)
}

$free = FreeGB
if ($free -ge $LowWaterGB) { Log "SKIP: D: free ${free}GB >= ${LowWaterGB}GB threshold"; return }

Log "TRIGGER: D: free ${free}GB < ${LowWaterGB}GB -> purge tester caches"
$protectedTerminals = @(Get-ProtectedFactoryTerminals)
$protectedLookup = @{}
foreach ($t in $protectedTerminals) { $protectedLookup[$t.ToUpperInvariant()] = $true }
if ($DryRun) { Log "DRYRUN: would pause new dispatch, protect active/running terminals=[$($protectedTerminals -join ',')], clear only idle T*\Tester caches, restart missing workers"; return }

# 1. stop factory (caches are read by running agents). Preserve the operator's
# enable-state: a maintenance purge must never turn a deliberately disabled
# dispatcher back on when it exits.
$pumpTask = Get-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue
$tickTask = Get-ScheduledTask -TaskName 'QM_StrategyFarm_Tick_5min' -ErrorAction SilentlyContinue
$pumpWasEnabled = ($null -ne $pumpTask -and $pumpTask.State -ne 'Disabled')
$tickWasEnabled = ($null -ne $tickTask -and $tickTask.State -ne 'Disabled')
Stop-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue | Out-Null
Disable-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue | Out-Null
Stop-ScheduledTask -TaskName 'QM_StrategyFarm_Tick_5min' -ErrorAction SilentlyContinue | Out-Null
Disable-ScheduledTask -TaskName 'QM_StrategyFarm_Tick_5min' -ErrorAction SilentlyContinue | Out-Null
# Gentler teardown (2026-06-22): verify a TRUE clean slate before clearing/restarting.
# Repeated abrupt force-kills in quick succession leaked OS resources (handles /
# window-station / single-instance state) and eventually wedged terminal64 launches
# (instant-exit ~0.06s) for hours — a state only Factory_OFF/ON could clear. Killing in
# a verify-loop + a longer settle lets Windows fully release those resources, and
# guarantees 0 survivors so the respawn can't over-provision on top of stragglers.
function Kill-FactoryProcs {
    param([hashtable]$Protected)
    @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
        Where-Object CommandLine -match 'terminal_worker\.py') | ForEach-Object {
            $tname = Get-FactoryTerminalFromCommandLine $_.CommandLine
            if ($tname -and -not $Protected.ContainsKey($tname)) {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
    # ONLY idle factory T1-T10 terminals — NEVER active/running protected terminals,
    # T_Live (live trading), or T_Export.
    @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match '\\mt5\\T(?:[1-9]|10)\\' }) | ForEach-Object {
            $tname = Get-FactoryTerminalFromCommandLine $_.CommandLine
            if ($tname -and -not $Protected.ContainsKey($tname)) {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
}
$killPass = 0
while ($killPass -lt 4) {
    Kill-FactoryProcs -Protected $protectedLookup
    Start-Sleep -Seconds 3
    $liveW = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'terminal_worker\.py' -and (Get-FactoryTerminalFromCommandLine $_.CommandLine) -and -not $protectedLookup.ContainsKey((Get-FactoryTerminalFromCommandLine $_.CommandLine)) }).Count
    $liveT = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match '\\mt5\\T(?:[1-9]|10)\\' -and (Get-FactoryTerminalFromCommandLine $_.CommandLine) -and -not $protectedLookup.ContainsKey((Get-FactoryTerminalFromCommandLine $_.CommandLine)) }).Count
    if ($liveW -eq 0 -and $liveT -eq 0) { break }
    $killPass++
}
Start-Sleep -Seconds 5   # extra settle so the OS releases handles before respawn
Log "idle factory slots stopped ($killPass extra kill pass(es); protected active/running terminals=[$($protectedTerminals -join ',')])"

# 2. clear regenerable tester caches
$purgedTerminals = @()
foreach ($n in 1..10) {
    $terminalName = "T$n"
    if ($protectedLookup.ContainsKey($terminalName)) {
        Log "SKIP_PROTECTED: $terminalName has active work_item or running terminal64; cache left intact"
        continue
    }
    $t = "D:\QM\mt5\T$n"
    if (-not (Test-Path $t)) { continue }
    Get-ChildItem "$t\Tester\bases" -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    Get-ChildItem "$t\Tester" -Directory -Filter "Agent-*" -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    $purgedTerminals += $terminalName
}
Start-Sleep -Seconds 2
$after = FreeGB
Log "idle caches cleared terminals=[$($purgedTerminals -join ',')]: D: ${free}GB -> ${after}GB (reclaimed $([math]::Round($after-$free,1))GB)"

# 3. restart the factory via the PROVEN interactive recovery task. The OLD
#    run_in_console_session / CreateProcessAsUser-as-SYSTEM launcher is UNRELIABLE:
#    it yields worker daemons whose terminal64 children instant-exit 0xC0000142, so
#    metatester64 stays 0 and the factory never actually recovers. The factory_watchdog
#    was migrated OFF this exact mechanism on 2026-06-24 for that reason; tester_cache_purge
#    kept it and consequently STRANDED the factory OFF after a purge on 2026-07-21.
#    Delegate to the SAME task the watchdog uses: QM_StrategyFarm_FactoryON_AtLogon
#    (RunAs qm-admin, Interactive, RunLevel Highest) -> Factory_ON.ps1 -NoPause in-session:
#    removes any FACTORY_OFF.flag, enables Factory/AI + respawn tasks, kills stale
#    daemons/terminals, spawns exactly one worker per enabled terminal IN-SESSION, runs
#    farmctl repair, triggers the pump. Enable first (a prior Factory_OFF disables it).
try {
    Enable-ScheduledTask -TaskName 'QM_StrategyFarm_FactoryON_AtLogon' -ErrorAction SilentlyContinue | Out-Null
    Start-ScheduledTask -TaskName 'QM_StrategyFarm_FactoryON_AtLogon' -ErrorAction Stop
    Start-Sleep -Seconds 25
    $daemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
                 Where-Object { $_.CommandLine -match 'terminal_worker\.py' })
    Log "factory restarted via FactoryON_AtLogon: $($daemons.Count) worker daemon(s); D: free $(FreeGB)GB"
} catch {
    Log "factory RESTART FAILED (FactoryON_AtLogon): $($_.Exception.Message) - factory may be OFF, needs manual Factory_ON"
}
