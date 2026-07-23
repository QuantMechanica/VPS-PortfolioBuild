# =====================================================================
#  QuantMechanica - Factory Watchdog (in-session, self-healing)
#  Covers the gap the boot-autostart (FactoryON_AtLogon) does NOT:
#  the interactive session is alive but the worker daemons / MT5
#  terminals have died (crash, hang, OOM kill). Respawns ONLY the
#  missing workers, in THIS session, so the visible-mode factory keeps
#  producing without a manual "Factory ON" click.
#
#  RUNS AS SYSTEM (QM_StrategyFarm_FactoryWatchdog_15min, ServiceAccount) —
#  it must therefore NEVER spawn workers/terminals directly: a SYSTEM/
#  session-0 child spawn yields workers whose terminal64 die 0xC0000142
#  (2026-06-24 broken-respawn class). ALL healing is delegated via
#  Start-ScheduledTask to interactive qm-admin tasks (FactoryON_AtLogon
#  for clean-slate, QM_StrategyFarm_WorkerDedupe for surgical spawns).
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
    [int]$ExpectWorkers = 10,
    [int]$StallPendingThreshold = 50 # heal when workers are ALIVE but WEDGED: 0 active +
                                     # >= this many pending + 0 terminal64 = dispatcher stalled
)

$ErrorActionPreference = 'Continue'
$repo = 'C:\QM\repo'
$py   = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$log  = 'D:\QM\reports\state\factory_watchdog.jsonl'
$stallDumpRequest = 'D:\QM\reports\state\STALLDUMP_REQUEST'
$stallDumpDir = 'D:\QM\reports\state\worker_stalldump'
$rebootDiagnosticPending = 'D:\QM\reports\state\reboot_diagnostic_pending.json'
$resetAdmissionBlock = 'D:\QM\strategy_farm\state\WATCHDOG_RESET_PENDING.json'
. (Join-Path $PSScriptRoot 'qm_tasks.manifest.ps1')

# FACTORY_OFF.flag master switch: owner/claude sets it to suspend all automation.
# Watchdog must no-op immediately so it cannot resurrect the factory.
$factoryOffFlagPath = 'D:\QM\strategy_farm\state\FACTORY_OFF.flag'
if (Test-Path $factoryOffFlagPath) {
    $offTs = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $offRecord = [ordered]@{ ts=$offTs; action='noop_factory_off_flag'; detail='FACTORY_OFF.flag present; watchdog suspended' } | ConvertTo-Json -Compress
    try { Add-Content -Path $log -Value $offRecord -Encoding UTF8 } catch {}
    Write-Output $offRecord
    exit 0
}

$now    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$action = 'none'
$detail = ''

# -------------------------------------------------------------------
# Operator concurrency cap awareness (2026-06-22 — fixes a 5-min flap loop).
# disabled_terminals.txt removes terminals (e.g. T8,T9,T10 for the RAM cap,
# commit 050829f9b) from the fleet, so start_terminal_workers spawns only the
# remaining N. The watchdog target MUST track that cap: with the old fixed
# defaults (MinWorkers=8, ExpectWorkers=10) a capped fleet of 7 satisfies
# 7 < 8 on EVERY run -> endless "clean-slate respawn" that kills every
# in-flight terminal64 -> any backtest > 5 min (every cold-cache run after a
# reboot) is sawn off -> METATESTER_HUNG/REPORT_MISSING -> INFRA_FAIL, while
# real-verdict yield collapses to ~0. Derive the target from the cap instead.
$disabledTerminalsPath = 'D:\QM\strategy_farm\state\disabled_terminals.txt'
$disabledCount = 0
if (Test-Path $disabledTerminalsPath) {
    $disabledCount = @(Get-Content $disabledTerminalsPath -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match '^T(?:[1-9]|10)$' }).Count
}
$ExpectWorkers = [math]::Max(1, 10 - $disabledCount)
# Heal only when BELOW the capped target (workers == cap reads healthy). Never
# require more workers than the operator cap allows.
$MinWorkers = [math]::Min($MinWorkers, $ExpectWorkers)

function Invoke-StallDumpCapture {
    param(
        [string]$RequestPath,
        [string]$DumpDir
    )

    $requestStarted = (Get-Date).ToUniversalTime()
    try {
        if (-not (Test-Path $DumpDir)) { New-Item -ItemType Directory -Path $DumpDir -Force | Out-Null }
        Get-ChildItem -Path $DumpDir -Filter '*.txt' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -Skip 50 |
            Remove-Item -Force -ErrorAction SilentlyContinue

        Set-Content -Path $RequestPath -Value $requestStarted.ToString('yyyy-MM-ddTHH:mm:ssZ') -Encoding ASCII
        Start-Sleep -Seconds 8

        $files = @(Get-ChildItem -Path $DumpDir -Filter '*.txt' -ErrorAction SilentlyContinue |
                   Where-Object { $_.LastWriteTimeUtc -ge $requestStarted.AddSeconds(-1) } |
                   Sort-Object LastWriteTimeUtc -Descending)
        $sample = ($files | Select-Object -First 10 | ForEach-Object { $_.Name }) -join ','
        $summary = "stalldump_request files=$($files.Count) dir=$DumpDir"
        if ($sample) { $summary += " sample=$sample" }
        return $summary
    } catch {
        return "stalldump_request_error=$($_.Exception.Message)"
    } finally {
        Remove-Item -Path $RequestPath -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $DumpDir -Filter '*.txt' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -Skip 50 |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# Parse a 'yyyy-MM-ddTHH:mm:ssZ' stamp as UTC. PowerShell's `[datetime]"...Z"` cast
# converts the value to LOCAL time (Kind=Local); subtracting that from a UTC `$nowDt`
# (Get-Date).ToUniversalTime() compares mismatched frames and skews cooldowns by the
# local UTC offset (observed 2026-06-24: a 6h realstall cooldown effectively became 8h,
# blocking auto-heal for a ~6.5h launch_fault wedge). Always parse stored stamps as UTC.
function ConvertFrom-UtcStamp {
    param([string]$Stamp)
    if (-not $Stamp) { return $null }
    try {
        return [datetime]::ParseExact($Stamp, 'yyyy-MM-ddTHH:mm:ssZ',
            [Globalization.CultureInfo]::InvariantCulture,
            ([Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal))
    } catch { return $null }
}

function Set-WatchdogResetAdmissionBlock {
    param([string]$Reason)

    $requested = (Get-Date).ToUniversalTime()
    # Exact process identity is part of stale-marker recovery. If it cannot be
    # captured, abort reset admission instead of inventing an identity.
    $ownerStarted = (Get-Process -Id $PID -ErrorAction Stop).StartTime.ToUniversalTime()
    $payload = [ordered]@{
        schema_version   = 1
        requested_at_utc = $requested.ToString('yyyy-MM-ddTHH:mm:ssZ')
        owner_started_at_utc = $ownerStarted.ToString('yyyy-MM-ddTHH:mm:ssZ')
        reason           = $Reason
        watchdog_pid     = $PID
    } | ConvertTo-Json -Compress
    $directory = Split-Path $resetAdmissionBlock -Parent
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
    }
    $temporary = "$resetAdmissionBlock.tmp.$PID.$([guid]::NewGuid().ToString('N'))"
    try {
        [IO.File]::WriteAllText(
            $temporary,
            $payload,
            (New-Object Text.UTF8Encoding($false))
        )
        if ([IO.File]::Exists($resetAdmissionBlock)) {
            [IO.File]::Replace($temporary, $resetAdmissionBlock, $null, $true)
        } else {
            [IO.File]::Move($temporary, $resetAdmissionBlock)
        }
    } finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

function Clear-WatchdogResetAdmissionBlock {
    try {
        if (Test-Path -LiteralPath $resetAdmissionBlock -ErrorAction Stop) {
            Remove-Item -LiteralPath $resetAdmissionBlock -Force -ErrorAction Stop
        }
        if (Test-Path -LiteralPath $resetAdmissionBlock -ErrorAction Stop) {
            throw 'reset admission marker still exists after removal'
        }
    } catch {
        throw
    }
}

function Get-WatchdogResetAdmissionState {
    try {
        $markerPresent = Test-Path -LiteralPath $resetAdmissionBlock -PathType Leaf -ErrorAction Stop
    } catch {
        return [pscustomobject]@{
            present = $true
            valid = $false
            owner_alive = $true
            task_probe_ok = $false
            task_state = 'Unknown'
            task_error = ''
            reason = "reset marker path probe failed: $($_.Exception.Message)"
        }
    }
    if (-not $markerPresent) {
        return [pscustomobject]@{
            present = $false
            valid = $true
            owner_alive = $false
            task_probe_ok = $true
            task_state = ''
            task_error = ''
            reason = ''
        }
    }

    $taskProbeOk = $false
    $taskState = 'Unknown'
    $taskError = ''
    try {
        $factoryOnTask = Get-ScheduledTask -TaskName 'QM_StrategyFarm_FactoryON_AtLogon' -ErrorAction Stop
        if ($null -eq $factoryOnTask) {
            throw 'Task Scheduler returned no FactoryON task object'
        }
        $taskState = [string]$factoryOnTask.State
        $taskProbeOk = $true
    } catch {
        # Missing task and Scheduler/RPC failures are both fail-closed. A
        # positive, current task-state response is required before cleanup.
        $taskError = $_.Exception.Message
    }
    try {
        $marker = Get-Content -LiteralPath $resetAdmissionBlock -Raw -ErrorAction Stop |
            ConvertFrom-Json -ErrorAction Stop
        $ownerPid = [int]$marker.watchdog_pid
        $ownerStarted = ConvertFrom-UtcStamp ([string]$marker.owner_started_at_utc)
        if ($ownerPid -le 0 -or $null -eq $ownerStarted) {
            throw 'marker lacks a valid watchdog process identity'
        }
        $ownerAlive = $false
        try {
            $owner = Get-Process -Id $ownerPid -ErrorAction Stop
            $actualStarted = $owner.StartTime.ToUniversalTime()
            $ownerAlive = [math]::Abs(($actualStarted - $ownerStarted).TotalSeconds) -le 2
        } catch {
            $ownerAlive = $false
        }
        return [pscustomobject]@{
            present = $true
            valid = $true
            owner_alive = $ownerAlive
            task_probe_ok = $taskProbeOk
            task_state = $taskState
            task_error = $taskError
            reason = [string]$marker.reason
        }
    } catch {
        # A malformed marker is fail-closed. Factory_ON can still acknowledge
        # and remove it after clearing the old fleet.
        return [pscustomobject]@{
            present = $true
            valid = $false
            owner_alive = $true
            task_probe_ok = $taskProbeOk
            task_state = $taskState
            task_error = $taskError
            reason = "unreadable reset marker: $($_.Exception.Message)"
        }
    }
}

function Get-RebootDiagnosticResourceSnapshot {
    # Persist a compact five-minute resource history for post-reboot causality.
    # Never persist command lines: they can contain sensitive arguments.
    $captured = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    try {
        $memory = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory -ErrorAction Stop
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $pageFiles = @(Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue)
        $committed = [double]$memory.CommittedBytes
        $commitLimit = [double]$memory.CommitLimit
        $pageAllocated = [double](($pageFiles | Measure-Object AllocatedBaseSize -Sum).Sum)
        $pageCurrent = [double](($pageFiles | Measure-Object CurrentUsage -Sum).Sum)
        $pagePeak = [double](($pageFiles | Measure-Object PeakUsage -Sum).Sum)

        $top = @(
            Get-Process -ErrorAction SilentlyContinue |
                Sort-Object PrivateMemorySize64 -Descending |
                Select-Object -First 12 |
                ForEach-Object {
                    try {
                        [ordered]@{
                            name           = $_.ProcessName
                            pid            = $_.Id
                            session_id     = $_.SessionId
                            private_gb     = [math]::Round($_.PrivateMemorySize64 / 1GB, 2)
                            working_set_gb = [math]::Round($_.WorkingSet64 / 1GB, 2)
                        }
                    } catch {}
                }
        )

        return [ordered]@{
            captured_at_utc       = $captured
            physical_total_gb     = [math]::Round(([double]$os.TotalVisibleMemorySize * 1KB) / 1GB, 2)
            physical_available_gb = [math]::Round(([double]$os.FreePhysicalMemory * 1KB) / 1GB, 2)
            committed_gb          = [math]::Round($committed / 1GB, 2)
            commit_limit_gb       = [math]::Round($commitLimit / 1GB, 2)
            commit_headroom_gb    = if ($commitLimit -gt 0) { [math]::Round(($commitLimit - $committed) / 1GB, 2) } else { $null }
            commit_percent        = if ($commitLimit -gt 0) { [math]::Round(($committed / $commitLimit) * 100, 1) } else { $null }
            available_gb          = [math]::Round(([double]$memory.AvailableBytes) / 1GB, 2)
            pages_per_sec         = [int64]$memory.PagesPersec
            pagefile_allocated_mb = [math]::Round($pageAllocated, 0)
            pagefile_current_mb   = [math]::Round($pageCurrent, 0)
            pagefile_peak_mb      = [math]::Round($pagePeak, 0)
            pagefile_percent      = if ($pageAllocated -gt 0) { [math]::Round(($pageCurrent / $pageAllocated) * 100, 1) } else { $null }
            top_processes         = $top
        }
    } catch {
        return [ordered]@{
            captured_at_utc = $captured
            error           = $_.Exception.Message
            top_processes   = @()
        }
    }
}

function Get-ActiveBacktestProtection {
    param([string]$PythonExe)

    $probe = @'
import json
import os
import sqlite3
import time

db = r"D:/QM/strategy_farm/state/farm_state.sqlite"
multisym_registry = r"D:/QM/strategy_farm/state/multisymbol_eas.txt"
now = time.time()
recent_cutoff = now - 600
out = {
    "probe_ok": False,
    "registry_ok": False,
    "active_count": 0,
    "active_multisym_count": 0,
    "active_recent_progress_count": 0,
    "protected_terminals": [],
    "details": [],
}

try:
    with open(multisym_registry, "r", encoding="utf-8") as handle:
        multisym_ea_ids = {
            line.strip().split()[0]
            for line in handle
            if line.strip() and not line.lstrip().startswith("#")
        }
    if not multisym_ea_ids:
        raise RuntimeError("multisymbol registry is empty")
    out["registry_ok"] = True
except Exception as exc:
    out["registry_error"] = repr(exc)
    multisym_ea_ids = set()


def payload_dict(text):
    try:
        value = json.loads(text or "{}")
        return value if isinstance(value, dict) else {}
    except Exception:
        return {}


def is_multisym(ea_id, symbol, payload):
    if str(ea_id or "").strip() in multisym_ea_ids:
        return True
    if str(payload.get("portfolio_scope") or "").strip().lower() == "basket":
        return True
    if str(payload.get("basket_manifest") or "").strip():
        return True
    try:
        if int(payload.get("basket_symbol_count") or 0) > 1:
            return True
    except Exception:
        pass
    return "BASKET" in str(symbol or "").upper()


def path_recent(path):
    try:
        return os.path.exists(path) and os.path.getmtime(path) >= recent_cutoff
    except Exception:
        return False


def tree_recent(path):
    if not path or not os.path.isdir(path):
        return False
    seen = 0
    try:
        for root, _dirs, files in os.walk(path):
            for name in files:
                seen += 1
                try:
                    if os.path.getmtime(os.path.join(root, name)) >= recent_cutoff:
                        return True
                except Exception:
                    pass
                if seen >= 2000:
                    return False
    except Exception:
        return False
    return False


def terminal_journal_recent(terminal):
    if not terminal:
        return False
    log_dir = fr"D:/QM/mt5/{terminal}/logs"
    if not os.path.isdir(log_dir):
        return False
    try:
        files = [
            os.path.join(log_dir, name)
            for name in os.listdir(log_dir)
            if name.lower().endswith(".log")
        ]
        files.sort(key=lambda p: os.path.getmtime(p), reverse=True)
        return any(path_recent(path) for path in files[:3])
    except Exception:
        return False


conn = None
try:
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    conn.execute("BEGIN IMMEDIATE")
    rows = conn.execute(
        "SELECT id, ea_id, symbol, phase, claimed_by, payload_json "
        "FROM work_items WHERE status='active'"
    ).fetchall()
    conn.commit()
    out["probe_ok"] = True
    out["active_count"] = len(rows)
    protected = set()
    for row in rows:
        payload = payload_dict(row["payload_json"])
        terminal = str(row["claimed_by"] or payload.get("terminal") or "").strip().upper()
        if terminal:
            protected.add(terminal)
        multisym = is_multisym(row["ea_id"], row["symbol"], payload)
        if multisym:
            out["active_multisym_count"] += 1
        recent = (
            path_recent(str(payload.get("log_path") or ""))
            or tree_recent(str(payload.get("report_root") or ""))
            or terminal_journal_recent(terminal)
        )
        if recent:
            out["active_recent_progress_count"] += 1
        out["details"].append({
            "id": row["id"],
            "ea_id": row["ea_id"],
            "phase": row["phase"],
            "terminal": terminal,
            "multisym": multisym,
            "recent_progress": recent,
        })
    out["protected_terminals"] = sorted(protected)
except Exception as exc:
    out["probe_ok"] = False
    out["error"] = str(exc)
    if conn is not None:
        try:
            conn.rollback()
        except Exception:
            pass
finally:
    if conn is not None:
        try:
            conn.close()
        except Exception:
            pass

print(json.dumps(out, separators=(",", ":")))
'@

    try {
        return (($probe | & $PythonExe - 2>$null) -join '' | ConvertFrom-Json)
    } catch {
        return [pscustomobject]@{
            probe_ok = $false
            registry_ok = $false
            active_count = 0
            active_multisym_count = 0
            active_recent_progress_count = 0
            protected_terminals = @()
            details = @()
            error = $_.Exception.Message
        }
    }
}

function Enter-GuardedFactoryReset {
    param(
        [string]$Reason,
        [string]$PythonExe
    )

    try {
        # The marker is written before taking SQLite's write lock. Workers
        # inspect it inside their own BEGIN IMMEDIATE claim transaction. Thus a
        # claim already in flight finishes before this fresh snapshot, while a
        # later claim is refused until Factory_ON completes the handover.
        Set-WatchdogResetAdmissionBlock -Reason $Reason
        $fresh = Get-ActiveBacktestProtection -PythonExe $PythonExe
        $probeOk = [bool]($fresh.probe_ok | Select-Object -First 1)
        $registryOk = [bool]($fresh.registry_ok | Select-Object -First 1)
        $multisymCount = [int]($fresh.active_multisym_count | Select-Object -First 1)
        $recentCount = [int]($fresh.active_recent_progress_count | Select-Object -First 1)
        $blockReason = ''
        if (-not $probeOk) {
            $blockReason = "fresh active-work probe failed: $($fresh.error)"
        } elseif (-not $registryOk) {
            $blockReason = "multisymbol registry unavailable: $($fresh.registry_error)"
        } elseif ($multisymCount -gt 0) {
            $blockReason = "active multisymbol/basket work_item present"
        } elseif ($recentCount -gt 0) {
            $blockReason = "active work_item progressed in the last 10m"
        }
        if ($blockReason) {
            Clear-WatchdogResetAdmissionBlock
            return [pscustomobject]@{
                allowed = $false
                reason = $blockReason
                protection = $fresh
            }
        }
        return [pscustomobject]@{
            allowed = $true
            reason = ''
            protection = $fresh
        }
    } catch {
        Clear-WatchdogResetAdmissionBlock
        return [pscustomobject]@{
            allowed = $false
            reason = "reset admission interlock failed: $($_.Exception.Message)"
            protection = $null
        }
    }
}

# A reset marker has no time-based expiry: only Factory_ON's post-kill
# acknowledgement releases workers. If a watchdog died before dispatching the
# task, the next watchdog run may clear the marker only when the exact owner
# process is gone and Task Scheduler explicitly reports Factory_ON Ready or
# Disabled. Unreadable/Unknown/ambiguous state remains blocked.
$existingResetAdmission = Get-WatchdogResetAdmissionState
if ($existingResetAdmission.present) {
    $factoryOnSafeForCleanup = $existingResetAdmission.task_state -in @('Ready', 'Disabled')
    if ($existingResetAdmission.valid -and
        -not $existingResetAdmission.owner_alive -and
        $existingResetAdmission.task_probe_ok -and
        $factoryOnSafeForCleanup) {
        try {
            Clear-WatchdogResetAdmissionBlock
            $staleRecord = [ordered]@{
                ts = $now
                action = 'stale_reset_admission_block_cleared'
                detail = "orphaned marker reason=$($existingResetAdmission.reason) task_state=$($existingResetAdmission.task_state)"
            } | ConvertTo-Json -Compress
            try { Add-Content -Path $log -Value $staleRecord -Encoding UTF8 } catch {}
        } catch {
            $handoverRecord = [ordered]@{
                ts = $now
                action = 'noop_reset_handover_in_progress'
                detail = "claim admission remains blocked; orphan cleanup failed: $($_.Exception.Message)"
            } | ConvertTo-Json -Compress
            try { Add-Content -Path $log -Value $handoverRecord -Encoding UTF8 } catch {}
            Write-Output $handoverRecord
            exit 0
        }
    } else {
        $handoverRecord = [ordered]@{
            ts = $now
            action = 'noop_reset_handover_in_progress'
            detail = "claim admission remains blocked; marker_valid=$($existingResetAdmission.valid) owner_alive=$($existingResetAdmission.owner_alive) task_probe_ok=$($existingResetAdmission.task_probe_ok) task_state=$($existingResetAdmission.task_state) task_error=$($existingResetAdmission.task_error) reason=$($existingResetAdmission.reason)"
        } | ConvertTo-Json -Compress
        try { Add-Content -Path $log -Value $handoverRecord -Encoding UTF8 } catch {}
        Write-Output $handoverRecord
        exit 0
    }
}

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

# 2a. Disk free on the runtime drive (2026-06-19 meltdown awareness). When D: is
# critically low MT5 cannot generate ticks; the worker disk circuit-breaker pauses
# rather than burning items as INFRA. The watchdog must treat that as a disk problem
# to purge, NOT a worker wedge to respawn (respawned workers would also just pause).
$diskFreeGb = try { [math]::Round((Get-PSDrive D -ErrorAction Stop).Free / 1GB, 1) } catch { 999.0 }

# 2b. DISPATCH-STALL detection (added 2026-06-09 after an ~8.5h wedge stall).
# Worker COUNT alone misses the case where workers are alive but WEDGED: after an
# RDP disconnect/reconnect they hold a dead session handle, so they claim work but
# cannot launch terminal64 ("released_stale_claims") -> the queue has work but 0
# runs. Signal: factory ON, 0 active work_items, >= StallPendingThreshold pending,
# and 0 terminal64 procs. The same clean-slate respawn fixes it (fresh workers get
# a live session handle via CreateProcessAsUser, even into a disconnected session).
$dispatchStalled = $false
$stallInfo = ''
$nTerm = 0
$nActive = 0
$nPending = 0
if ($factoryEnabled) {
    try {
        # Count ONLY factory T1-T10 terminals, not every terminal64 on the box. A
        # dedicated analysis terminal (D:\QM\mt5\T_Export) or the live T_Live terminal
        # must NOT count here, else they MASK a real dispatch stall (observed 2026-06-09:
        # a T_Export export run showed term64=1 and the watchdog read 'healthy' while the
        # factory was wedged 0-active).
        $nTerm = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
                   Where-Object { $_.CommandLine -match '\\mt5\\T(?:[1-9]|10)\\' }).Count
        # single-quoted here-string + stdin pipe avoids all PowerShell/SQL quote escaping
        $q = @'
import sqlite3
c = sqlite3.connect(r"D:/QM/strategy_farm/state/farm_state.sqlite")
a = c.execute("SELECT COUNT(*) FROM work_items WHERE status='active'").fetchone()[0]
p = c.execute("SELECT COUNT(*) FROM work_items WHERE status='pending'").fetchone()[0]
print(str(a) + " " + str(p))
'@
        $out = ($q | & $py - 2>$null) -join ' '
        $m = [regex]::Match($out, '(\d+)\s+(\d+)')
        if ($m.Success) {
            $nActive = [int]$m.Groups[1].Value
            $nPending = [int]$m.Groups[2].Value
            $stallInfo = "active=$nActive pending=$nPending term64=$nTerm"
            if ($nActive -eq 0 -and $nPending -ge $StallPendingThreshold -and $nTerm -eq 0) {
                $dispatchStalled = $true
            }
        }
    } catch { $stallInfo = "stall-probe-error: $_" }
}

$activeProtection = [pscustomobject]@{
    probe_ok = $false
    registry_ok = $false
    active_count = 0
    active_multisym_count = 0
    active_recent_progress_count = 0
    protected_terminals = @()
    details = @()
}
if ($factoryEnabled) {
    $activeProtection = Get-ActiveBacktestProtection -PythonExe $py
}
$activeProtectionProbeOk = [bool]($activeProtection.probe_ok | Select-Object -First 1)
$multisymRegistryOk = [bool]($activeProtection.registry_ok | Select-Object -First 1)
$activeMultisymCount = [int]($activeProtection.active_multisym_count | Select-Object -First 1)
$activeRecentProgressCount = [int]($activeProtection.active_recent_progress_count | Select-Object -First 1)
$activeProtectionDetail = ''
try {
    $activeProtectionDetail = (($activeProtection.details | ForEach-Object {
        "$($_.id):$($_.ea_id):$($_.phase):$($_.terminal):multisym=$($_.multisym):recent=$($_.recent_progress)"
    }) -join ';')
} catch {}
$realStallSuppressedReason = ''
$resourceSnapshot = Get-RebootDiagnosticResourceSnapshot

# 2c. SESSION-LOSS detection + reboot-heal (added 2026-06-11).
# The one case neither respawn nor tscon can fix: the interactive session itself is
# DESTROYED (observed 3x 2026-06-10/11: LSM event 40 reason 23, per-session user
# services killed, no logoff event; one death preceded by an 0xc0000142 desktop-heap
# burst, two more correlate with dxgkrnl LiveKernelEvents). With NO qm-admin session,
# WTSQueryUserToken has no token to spawn into -> factory stays dead until OWNER logs
# in. Heal: controlled reboot -> autologon (LSA DefaultPassword secret, verified
# 2026-06-11) recreates the console session -> FactoryON_AtLogon restores the factory.
# Guards: confirm on 2 consecutive runs (~15 min), 6h cooldown, autologon secret must
# exist, never while any T_Live terminal runs (Hard Rule: live trading untouchable).
$sessionLost        = $false
$lsmDegraded        = $false   # FIX 2: qwinsta failed/missing but worker evidence proves session alive
$qwinstaError       = $null    # FIX 2: error string from qwinsta failure (for jsonl)
$secretBasis        = ''       # FIX 1: 'lsa_secret' | 'winlogon_fallback_nonsystem' (for jsonl)
$rebootDiagnosticEventId = $null
$targetUser = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultUserName
if (-not $targetUser) { $targetUser = 'qm-admin' }
if ($factoryEnabled) {
    $hasSession    = $false
    $qwinstaOutput = @()
    try {
        $qwinstaOutput   = @(qwinsta 2>$null)
        $qwinstaExitCode = $LASTEXITCODE
        if ($qwinstaExitCode -ne 0) { $qwinstaError = "exitcode=$qwinstaExitCode" }
    } catch {
        $qwinstaError = "exception=$($_.Exception.Message)"
    }
    foreach ($line in $qwinstaOutput) {
        if (($line -match "\b$([regex]::Escape($targetUser))\b") -and
            ($line -match "\s\d+\s+(Active|Disc|Conn)\b")) { $hasSession = $true }
    }
    # FIX 2: Worker-process evidence cross-check. Terminal_worker daemons run inside
    # the interactive session; if >=1 is alive the session cannot be gone regardless
    # of qwinsta status. qwinsta exit-code 87 (or any non-zero) during LSM degradation
    # does NOT prove session loss. session_lost requires BOTH signals to agree.
    $workerDaemonsAlive = $nWorkers  # already collected: python.exe|pythonw.exe + terminal_worker.py
    if ((-not $hasSession) -and ($workerDaemonsAlive -ge 1)) {
        # qwinsta says no session but workers are running inside it -> LSM masked the session
        $lsmDegraded = $true
    } elseif ($qwinstaError -and ($workerDaemonsAlive -ge 1)) {
        # qwinsta failed entirely but workers are alive -> LSM degradation
        $lsmDegraded = $true
    }
    # session_lost: BOTH session enumeration says gone AND zero worker-daemon process evidence
    $sessionLost = (-not $hasSession) -and ($workerDaemonsAlive -eq 0)
}

if ($factoryEnabled -and $sessionLost) {
    $healState = 'D:\QM\reports\state\watchdog_session_heal.json'
    $st = $null
    try { $st = Get-Content $healState -Raw -ErrorAction Stop | ConvertFrom-Json } catch {}
    $nowDt = (Get-Date).ToUniversalTime()
    $pendingSince = ConvertFrom-UtcStamp $st.pending_since
    $lastReboot   = ConvertFrom-UtcStamp $st.last_reboot

    # FIX 1: HKLM\SECURITY is SYSTEM-only; an admin-context read always throws access-denied,
    # making secretOk=false a FALSE NEGATIVE from any non-SYSTEM caller. If the read fails
    # AND the current identity is not SYSTEM, fall back to the admin-readable Winlogon keys
    # (AutoAdminLogon + DefaultUserName) rather than treating the ACL error as "no secret".
    # secret_basis is emitted in the jsonl record so the evidence path is auditable.
    # The action 'session_lost_no_autologon' MUST NOT fire solely because the SYSTEM-only
    # read failed from a non-SYSTEM context (that was the LSM-degradation false-positive).
    $isSystem    = [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem
    $secretOk    = $false
    $secretBasis = 'lsa_secret'
    try {
        $secretOk    = $null -ne [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine','Default').OpenSubKey('SECURITY\Policy\Secrets\DefaultPassword')
        $secretBasis = 'lsa_secret'
    } catch {
        if (-not $isSystem) {
            # Non-SYSTEM caller: SECURITY hive access-denied is expected; fall back to Winlogon.
            $wl          = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue
            $secretOk    = ($wl.AutoAdminLogon -eq '1') -and ($null -ne $wl.DefaultUserName) -and ('' -ne $wl.DefaultUserName)
            $secretBasis = 'winlogon_fallback_nonsystem'
        }
        # IS SYSTEM but read still failed -> genuine absent/inaccessible secret; $secretOk stays $false
    }
    $autologonOn = ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).AutoAdminLogon -eq '1')
    $tLiveRunning = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
                      Where-Object { $_.CommandLine -match 'T_Live' }).Count -gt 0

    if (-not ($secretOk -and $autologonOn)) {
        $action = 'session_lost_no_autologon'
        $detail = "NO interactive $targetUser session, but autologon not usable (secret=$secretOk basis=$secretBasis autoadmin=$autologonOn) - reboot would strand at logon screen; OWNER must log in"
    } elseif ($tLiveRunning) {
        $action = 'session_lost_tlive_guard'
        $detail = "NO interactive $targetUser session but a T_Live terminal is running - refusing auto-reboot (Hard Rule)"
    } elseif ($lastReboot -and ($nowDt - $lastReboot).TotalHours -lt 6) {
        $action = 'session_lost_cooldown'
        $detail = "NO interactive $targetUser session; auto-reboot suppressed (last heal-reboot $($st.last_reboot), 6h cooldown)"
    } elseif (-not $pendingSince) {
        $action = 'session_lost_pending_confirm'
        $detail = "NO interactive $targetUser session detected; confirming on next run before reboot-heal"
        @{ pending_since = $nowDt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); last_reboot = $st.last_reboot } |
            ConvertTo-Json -Compress | Set-Content -Path $healState -Encoding UTF8
    } else {
        $action = 'healed_session_reboot'
        $detail = "NO interactive $targetUser session for 2 consecutive checks (since $($st.pending_since)) while factory ON -> controlled reboot to restore autologon session + FactoryON_AtLogon"
        @{ pending_since = $null; last_reboot = $nowDt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') } |
            ConvertTo-Json -Compress | Set-Content -Path $healState -Encoding UTF8
        $shutdownComment = 'QM factory_watchdog: interactive session lost - auto-reboot to restore autologon session'
        $rebootDiagnosticEventId = [guid]::NewGuid().ToString()
        $pendingRecord = [ordered]@{
            schema                = 1
            event_id              = $rebootDiagnosticEventId
            source                = 'QM_StrategyFarm_FactoryWatchdog_15min'
            kind                  = 'session_loss_heal'
            requested_at_utc      = $nowDt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            pending_since_utc     = $st.pending_since
            shutdown_comment      = $shutdownComment
            factory_enabled       = $factoryEnabled
            target_user           = $targetUser
            workers               = $nWorkers
            expected_workers      = $ExpectWorkers
            session_lost          = $sessionLost
            qwinsta_error         = $qwinstaError
            active_count          = $nActive
            pending_count         = $nPending
            terminal_count        = $nTerm
            active_items          = @($activeProtection.details)
            resource_snapshot     = $resourceSnapshot
        }
        try {
            $pendingDir = Split-Path $rebootDiagnosticPending -Parent
            if (-not (Test-Path -LiteralPath $pendingDir)) {
                New-Item -ItemType Directory -Path $pendingDir -Force | Out-Null
            }
            $pendingTmp = "$rebootDiagnosticPending.$PID.tmp"
            $pendingRecord | ConvertTo-Json -Depth 8 |
                Set-Content -LiteralPath $pendingTmp -Encoding UTF8
            if (Test-Path -LiteralPath $rebootDiagnosticPending) {
                [IO.File]::Replace($pendingTmp, $rebootDiagnosticPending, $null)
            } else {
                [IO.File]::Move($pendingTmp, $rebootDiagnosticPending)
            }
            $detail += " | reboot_diagnostic_event=$rebootDiagnosticEventId staged"
        } catch {
            $detail += " | reboot_diagnostic_stage_error=$($_.Exception.Message)"
        }
        & shutdown.exe /r /t 60 /d p:4:1 /c $shutdownComment
    }
    # clear stale pending flag once a session exists again
} elseif (Test-Path 'D:\QM\reports\state\watchdog_session_heal.json') {
    try {
        $st = Get-Content 'D:\QM\reports\state\watchdog_session_heal.json' -Raw | ConvertFrom-Json
        if ($st.pending_since) {
            @{ pending_since = $null; last_reboot = $st.last_reboot } | ConvertTo-Json -Compress |
                Set-Content -Path 'D:\QM\reports\state\watchdog_session_heal.json' -Encoding UTF8
        }
    } catch {}
}

# 2b2. REAL-VERDICT-STALL detection (2026-06-22, after a ~3h launch_fault wedge).
# The dispatch-stall check (2b) misses the launch_fault wedge: workers are ALIVE and DO
# spawn terminal64, but every launch instant-exits (~0.05s — RAM exhaustion, or leaked OS
# resources after repeated purge force-kills), so terminal64 + active oscillate >0 and the
# watchdog reads 'noop_healthy' for hours while 0 real verdicts complete. Signal: factory
# ON, workers healthy, NOT a dispatch stall, disk+RAM OK, queue has work, but ZERO real
# (non-INFRA) verdicts in the last 15 min AND no cache-purge fired recently (a purge ->
# cold-cache window self-heals; never escalate into it). Confirmed on 2 consecutive runs
# (~30 min) -> full OFF/ON-equivalent reset (the only thing that cleared the wedge).
$realStall = $false
$realStallInfo = ''
if ($factoryEnabled -and -not $dispatchStalled -and -not $sessionLost -and $nWorkers -ge $MinWorkers -and $diskFreeGb -ge 40) {
    $ramFreeGb = 999.0
    try { $ramFreeGb = [math]::Round((Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).FreePhysicalMemory/1MB,1) } catch {}
    $recentPurge = $false
    try {
        $plog = 'D:\QM\reports\state\tester_cache_purge.log'
        if (Test-Path $plog) {
            foreach ($ln in (Get-Content $plog -Tail 6 -ErrorAction SilentlyContinue)) {
                if ($ln -match 'TRIGGER' -and $ln -match '(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)') {
                    try {
                        $pt = [datetime]::ParseExact($matches[1],'yyyy-MM-ddTHH:mm:ssZ',[Globalization.CultureInfo]::InvariantCulture,([Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal))
                        if (((Get-Date).ToUniversalTime() - $pt).TotalMinutes -lt 15) { $recentPurge = $true }
                    } catch {}
                }
            }
        }
    } catch {}
    # RAM critically low => workers correctly self-pausing (RAM guard), not wedged.
    if ($ramFreeGb -ge 3 -and -not $recentPurge) {
        $rq = @'
import sqlite3
c=sqlite3.connect(r"D:/QM/strategy_farm/state/farm_state.sqlite")
n=c.execute("SELECT COUNT(*) FROM work_items WHERE status='done' AND attempt_count<99 AND verdict IN ('PASS','FAIL','FAIL_SOFT') AND datetime(updated_at)>=datetime('now','-15 minutes')").fetchone()[0]
print(n)
'@
        $realN = -1
        try { $realN = [int](($rq | & $py - 2>$null) -join '').Trim() } catch {}
        # Fresh-backtest-progress signal (2026-06-25): realDone15m above is MASKED when the
        # funnel processes late gates -- Q04 pooled / Q05/Q06 derived verdicts + delayed
        # aggregation of pre-wedge Q02/Q03 results keep realN>0 while FRESH backtests are
        # wedged (launch_fault, no metatester64). So ALSO detect 'no compute': metatester64.exe
        # (the agent doing the actual tick crunch) absent across 2 samples ~4s apart while the
        # queue has work. Max() of the 2 samples ignores a brief between-runs gap; the 2-run
        # confirm + 45min cooldown guard against a transient. This is what made the 2026-06-25
        # wedge invisible to the watchdog (real_stall:false) so the auto-heal never fired.
        $mt = 99
        try {
            $m1 = @(Get-CimInstance Win32_Process -Filter "Name='metatester64.exe'" -ErrorAction SilentlyContinue).Count
            Start-Sleep -Seconds 4
            $m2 = @(Get-CimInstance Win32_Process -Filter "Name='metatester64.exe'" -ErrorAction SilentlyContinue).Count
            $mt = [math]::Max($m1, $m2)
        } catch {}
        # PARTIAL-WEDGE detection (2026-06-26, OWNER "harden"). The realN==0 / mt==0 checks miss
        # the case where SOME terminals work but MOST are stuck: the 22:00 restart launch_fault
        # left 4 of 7 worker daemons idle (metatester64=3) for 40+ min while 875 items pended.
        # Daemon COUNT read healthy (7) so the worker-shortage heal never fired; the 3 working
        # terminals kept realN>0 so the realN==0/mt==0 checks never fired -> the fleet ran at ~43%
        # indefinitely until a manual restart. Add: metatester64 stuck below (ExpectWorkers-2)
        # while the queue is deep = most of the fleet wedged. Tolerates up to 2 idle terminals
        # (normal between-backtest churn); the SAME 2-run (~30 min) confirm + 45-min cooldown +
        # FactoryON_AtLogon recovery below guards against a transient dip or post-restart ramp.
        $mtFloor = [math]::Max(1, $ExpectWorkers - 2)
        $realStallInfo = "realDone15m=$realN metatester64=$mt/$ExpectWorkers (floor=$mtFloor) terminal64=$nTerm ramFreeGb=$ramFreeGb pending=$nPending recentPurge=$recentPurge activeMultisym=$activeMultisymCount activeRecentProgress=$activeRecentProgressCount"
        $realStallCandidate = ((($realN -eq 0) -or ($mt -lt $mtFloor)) -and $nPending -ge $StallPendingThreshold)
        if ($realStallCandidate) {
            if (-not $activeProtectionProbeOk) {
                $realStallSuppressedReason = "active-work protection probe failed; refusing full reset"
            } elseif (-not $multisymRegistryOk) {
                $realStallSuppressedReason = "multisymbol registry unavailable; refusing full reset"
            } elseif ($activeMultisymCount -gt 0) {
                $realStallSuppressedReason = "active multisymbol/basket work_item present; refusing full reset"
            } elseif ($activeRecentProgressCount -gt 0) {
                $realStallSuppressedReason = "active work_item log/report/journal progressed in last 10m"
            } else {
                $realStall = $true
            }
        }
    }
}

if ($factoryEnabled -and $sessionLost) {
    # handled above; fall through to logging
}
elseif ($factoryEnabled -and $lsmDegraded) {
    # FIX 2: LSM-degradation guard. qwinsta failed or found no session, but at least one
    # terminal_worker daemon is alive — proving the interactive session is not destroyed.
    # (qwinsta error 87 / LSM service degradation gives a false "no session" result.)
    # Emit a diagnostic record and take NO destructive or heal action; condition should
    # self-clear on the next run once LSM recovers.
    $action = 'lsm_degraded_suspected'
    $detail = "qwinsta_error=$qwinstaError worker_daemons_alive=$nWorkers; session not confirmed lost - no destructive action taken"
}
elseif (-not $factoryEnabled) {
    $action = 'noop_factory_off'
    $detail = "FACTORY tasks disabled (OWNER OFF); workers=$nWorkers - leaving alone"
}
elseif ($diskFreeGb -lt 40) {
    # Disk circuit-breaker awareness: workers correctly pause when D: is low, so a
    # respawn here would just loop fresh workers that also pause. Kick the cache
    # purge and wait for it to free space; the next run heals workers if needed.
    $action = 'noop_disk_low_purge'
    $detail = "D: free ${diskFreeGb}GB < 40GB while factory ON - workers pausing by design; kicking cache purge, NOT respawning"
    try { Start-ScheduledTask -TaskName 'QM_StrategyFarm_TesterCachePurge' -ErrorAction SilentlyContinue } catch {}
}
elseif ($factoryEnabled -and $realStallSuppressedReason) {
    $action = 'realstall_guarded'
    $detail = "REAL-STALL candidate suppressed: $realStallSuppressedReason ($realStallInfo); active=$activeProtectionDetail"
    $rsState = 'D:\QM\reports\state\watchdog_realstall.json'
    if (Test-Path $rsState) {
        try {
            $rst = Get-Content $rsState -Raw | ConvertFrom-Json
            if ($rst.pending_since) { @{ pending_since = $null; last_reset = $rst.last_reset } | ConvertTo-Json -Compress | Set-Content -Path $rsState -Encoding UTF8 }
        } catch {}
    }
}
elseif ($factoryEnabled -and $realStall) {
    # REAL-VERDICT-STALL (launch_fault wedge): workers look healthy but 0 real verdicts.
    # A plain respawn may not clear a leaked-resource wedge -> do the full OFF/ON-equiv
    # (disable factory tasks + kill all + longer settle + re-enable + farmctl repair +
    # clean respawn). 2-run confirm + 45min cooldown to avoid acting on a transient lull
    # (45min: a cheap/safe OFF/ON-equiv, not a VPS reboot, so it may retry far sooner than
    # the 6h session-reboot heal; long enough to clear the post-reset cold-cache warm-up).
    $rsState = 'D:\QM\reports\state\watchdog_realstall.json'
    $rst = $null; try { $rst = Get-Content $rsState -Raw -ErrorAction Stop | ConvertFrom-Json } catch {}
    $nowDt = (Get-Date).ToUniversalTime()
    $rsSince = ConvertFrom-UtcStamp $rst.pending_since
    $rsLast  = ConvertFrom-UtcStamp $rst.last_reset
    if ($rsLast -and ($nowDt - $rsLast).TotalMinutes -lt 45) {
        $action = 'realstall_cooldown'
        $detail = "REAL-STALL ($realStallInfo) but full-reset on 45min cooldown (last $($rst.last_reset))"
    } elseif (-not $rsSince) {
        $action = 'realstall_confirm'
        $detail = "REAL-STALL suspected ($realStallInfo); confirming on next run (~15min) before full reset"
        @{ pending_since = $nowDt.ToString('yyyy-MM-ddTHH:mm:ssZ'); last_reset = $rst.last_reset } | ConvertTo-Json -Compress | Set-Content -Path $rsState -Encoding UTF8
    } else {
        # 2026-06-24 (diagnostic A): the OLD self-respawn (run_in_console_session /
        # CreateProcessAsUser as SYSTEM) was conclusively found to produce worker
        # daemons whose terminal64 children instant-exit 0xC0000142 (degraded
        # winsta/desktop-access state since the Hetzner hard reset) -> metatester64=0,
        # recovery silently failed EVERY cycle all day while the log still said
        # 'healed_full_reset'. A kernel time-series proved it's NOT a resource leak
        # (handles/pool/threads flat over 2 resets). A manual Factory_ON.ps1 (direct
        # in-session interactive spawn as qm-admin) recovers instantly. So delegate
        # recovery to the QM_StrategyFarm_FactoryON_AtLogon task (RunAs qm-admin,
        # Interactive, RunLevel Highest): with qm-admin logged on, Start-ScheduledTask
        # runs Factory_ON.ps1 -NoPause in that interactive session = the WORKING path
        # (enable tasks + kill stale daemons/terminals + spawn workers in-session +
        # farmctl repair + trigger pump).
        # 2026-06-30 (T_Live guard CORRECTED, OWNER-verified): the prior guard REFUSED to
        # auto-recover whenever a T_Live terminal was running, on the premise that Factory_ON
        # "kills ALL terminal64 incl T_Live". That premise is FALSE: Factory_ON.ps1:113 filters
        # `notmatch 'T_Live'` (the T_Live-isolation Hard-Rule line itself) BEFORE killing any
        # terminal64 -- it provably spares the live terminal. The watchdog detected T_Live with
        # the IDENTICAL `CommandLine -match 'T_Live'` test Factory_ON uses to spare it, so the
        # guard was 100% redundant: whenever it fired, Factory_ON would spare that same terminal
        # anyway. The only effect of the bad guard was that every worker-death DURING LIVE
        # TRADING sat un-recovered until a MANUAL Factory_ON. Fix: always delegate to the
        # T_Live-sparing FactoryON_AtLogon; keep T_Live detection for the audit record only.
        $tLiveRunning = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
                          Where-Object { $_.CommandLine -match 'T_Live' }).Count -gt 0
        $resetGuard = Enter-GuardedFactoryReset -Reason 'realstall' -PythonExe $py
        if (-not $resetGuard.allowed) {
            $action = 'realstall_guarded_fresh'
            $detail = "REAL-STALL reset suppressed by fresh interlocked check: $($resetGuard.reason) ($realStallInfo)"
            @{ pending_since = $null; last_reset = $rst.last_reset } | ConvertTo-Json -Compress | Set-Content -Path $rsState -Encoding UTF8
        } else {
            $action = 'healed_full_reset'
            $detail = "REAL-STALL confirmed 2x (since $($rst.pending_since)) ($realStallInfo) -> Start FactoryON_AtLogon (interactive, T_Live-sparing recovery; tLiveRunning=$tLiveRunning)"
            @{ pending_since = $null; last_reset = $nowDt.ToString('yyyy-MM-ddTHH:mm:ssZ') } | ConvertTo-Json -Compress | Set-Content -Path $rsState -Encoding UTF8
            try {
                Start-ScheduledTask -TaskName 'QM_StrategyFarm_FactoryON_AtLogon' -ErrorAction Stop
                Start-Sleep -Seconds 25
                $after = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" -ErrorAction SilentlyContinue |
                           Where-Object { $_.CommandLine -match 'terminal_worker\.py' }).Count
                $detail += " -> after=$after workers (via FactoryON_AtLogon)"
            } catch {
                Clear-WatchdogResetAdmissionBlock
                $action = 'heal_failed'
                $detail += " -> ERROR: $_"
            }
        }
    }
}
elseif ($nWorkers -ge $MinWorkers -and -not $dispatchStalled) {
    $action = 'noop_healthy'
    $detail = "workers=$nWorkers/$ExpectWorkers (>= $MinWorkers); $stallInfo; activeMultisym=$activeMultisymCount activeRecentProgress=$activeRecentProgressCount"
    # clear any stale real-stall confirm flag once real verdicts are flowing again
    $rsState = 'D:\QM\reports\state\watchdog_realstall.json'
    if (Test-Path $rsState) {
        try {
            $rst = Get-Content $rsState -Raw | ConvertFrom-Json
            if ($rst.pending_since) { @{ pending_since = $null; last_reset = $rst.last_reset } | ConvertTo-Json -Compress | Set-Content -Path $rsState -Encoding UTF8 }
        } catch {}
    }
}
else {
    # 3. heal: factory meant ON but workers are dead/short OR alive-but-wedged (dispatch stalled).
    # FIX 3: DISPATCH STALL (dead session handle, 0 active + many pending + 0 terminal64) ->
    #   clean-slate FactoryON_AtLogon (existing path, unchanged).
    # PURE WORKER SHORTAGE (session alive, no stall, no launch_fault wedge) ->
    #   surgical --dedupe spawn: fills only the missing worker slots, NEVER kills in-flight
    #   terminals or backtests. The clean-slate path is reserved for dispatch stall and the
    #   launch_fault-wedge class (realStall branch above) only.
    if ($dispatchStalled) {
        $detail = "DISPATCH STALL: workers=$nWorkers alive but wedged ($stallInfo) while factory ON -> clean-slate respawn"
    } else {
        $detail = "workers=$nWorkers/$ExpectWorkers (< $MinWorkers) while factory ON -> surgical dedupe spawn"
    }
    # ESCALATION (2026-06-09): a dispatch stall on a DISCONNECTED session is the case the
    # plain respawn CANNOT fix -- workers respawn fine, but terminal64 (a GUI app) has no
    # live desktop to render in on a disconnected session, so 0 runs persist (observed:
    # 6 failed heals 13:30-14:45Z, then OWNER's manual reconnect+ON fixed it). Reattach the
    # session to the physical console with tscon -> a persistent ACTIVE desktop that needs
    # NO RDP connection -> the respawned terminals run headless. SAFETY: only when the
    # session is DISCONNECTED (Disc); never tscon an Active RDP view (would disrupt OWNER).
    if ($dispatchStalled) {
        try {
            $targetUser = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultUserName
            if (-not $targetUser) { $targetUser = 'qm-admin' }
            $sid = $null; $sstate = ''
            foreach ($line in (qwinsta 2>$null)) {
                if (($line -match "\b$([regex]::Escape($targetUser))\b") -and
                    ($line -match "\s(\d+)\s+(Active|Disc|Conn|Listen)\b")) { $sid = $matches[1]; $sstate = $matches[2] }
            }
            if ($sstate -eq 'Disc' -and $sid) {
                & tscon.exe $sid /dest:console 2>$null
                Start-Sleep -Seconds 3
                $detail += " | tscon->console(sid=$sid) to restore desktop"
            } else {
                $detail += " | tscon_skip(state='$sstate')"
            }
        } catch { $detail += " | tscon_err=$($_.Exception.Message)" }
    }
    # 2026-06-26 (OWNER "harden the watchdog"): the old clean-slate respawn here used
    # run_in_console_session (CreateProcessAsUser as SYSTEM) -- the SAME mechanism the realStall
    # path was moved OFF on 2026-06-24 because it yields worker daemons whose terminal64 children
    # instant-exit 0xC0000142, so metatester64 stays 0 and the factory never actually recovers
    # while the log reads 'healed_respawn_workers'. That asymmetry was the 2026-06-26 stall:
    # workers fell to 1, the worker-shortage heal "succeeded" cleanly, yet 0 compute -> needed a
    # MANUAL FactoryON kick. Unify the worker-shortage / dispatch-stall heal onto the SAME
    # working recovery as realStall: delegate to QM_StrategyFarm_FactoryON_AtLogon (RunAs
    # qm-admin, Interactive, RunLevel Highest) = a direct in-session Factory_ON.ps1 (kill stale
    # daemons/terminals + spawn workers in-session + farmctl repair + trigger pump) that recovers
    # instantly.
    # 2026-06-30 (T_Live guard CORRECTED, OWNER-verified): the prior guard REFUSED auto-recovery
    # whenever a T_Live terminal was running, on the FALSE premise that Factory_ON "kills ALL
    # terminal64 incl T_Live". Factory_ON.ps1:113 filters `notmatch 'T_Live'` (the T_Live-isolation
    # Hard-Rule line) BEFORE any kill -- it provably spares the live terminal -- and the watchdog
    # detected T_Live with the IDENTICAL `-match 'T_Live'` test, so the guard was 100% redundant
    # and merely blocked recovery: both 2026-06-30 worker-deaths sat in 'heal_tlive_guard' until a
    # MANUAL Factory_ON. Fix: always delegate to the T_Live-sparing FactoryON_AtLogon; keep T_Live
    # detection for the audit record only.
    $tLiveRunning = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
                      Where-Object { $_.CommandLine -match 'T_Live' }).Count -gt 0
    if ($dispatchStalled -and (-not $activeProtectionProbeOk -or -not $multisymRegistryOk)) {
        $action = 'heal_deferred_protection_unknown'
        $detail += " | active-work protection unavailable (probe_ok=$activeProtectionProbeOk registry_ok=$multisymRegistryOk); refusing full reset"
    } elseif ($dispatchStalled -and $activeMultisymCount -gt 0) {
        # Multisym guard: dispatch stall needs clean-slate FactoryON (kills terminals), but
        # an active basket/multisym backtest must not be interrupted. Defer the full reset;
        # a pure worker shortage with an active multisym is safe to dedupe-spawn below.
        $action = 'heal_deferred_active_multisym'
        $detail += " | active multisymbol/basket work_item guard: refusing full reset while protected=$($activeProtection.protected_terminals -join ',') active=$activeProtectionDetail"
    } elseif ($dispatchStalled) {
        # DISPATCH STALL path: needs clean-slate FactoryON_AtLogon (dead session handle;
        # dedupe-only spawn would inherit the same broken handle and still produce 0 runs).
        try {
            $dumpDetail = Invoke-StallDumpCapture -RequestPath $stallDumpRequest -DumpDir $stallDumpDir
            $detail += " | $dumpDetail"
            $resetGuard = Enter-GuardedFactoryReset -Reason 'dispatch_stall' -PythonExe $py
            if (-not $resetGuard.allowed) {
                $action = 'heal_deferred_fresh_protection'
                $detail += " | reset suppressed by fresh interlocked check: $($resetGuard.reason)"
            } else {
                Start-ScheduledTask -TaskName 'QM_StrategyFarm_FactoryON_AtLogon' -ErrorAction Stop
                Start-Sleep -Seconds 25
                $after = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" -ErrorAction SilentlyContinue |
                           Where-Object { $_.CommandLine -match 'terminal_worker\.py' }).Count
                $action = 'healed_via_factoryon'
                $detail += " -> Start FactoryON_AtLogon (dispatch stall, interactive, T_Live-sparing; tLiveRunning=$tLiveRunning) -> after=$after/$ExpectWorkers"
            }
        } catch {
            Clear-WatchdogResetAdmissionBlock
            $action = 'heal_failed'
            $detail += " -> ERROR: $_"
        }
    } else {
        # FIX 3: PURE WORKER SHORTAGE — session alive, no stall, no launch_fault wedge.
        # Surgical dedupe spawn: only fills the missing worker slots; never kills
        # in-flight terminals or interrupts running backtests.
        # This watchdog runs as SYSTEM: a direct child spawn here would put workers in
        # session 0 and their terminal64 dies 0xC0000142 (2026-06-24 broken-respawn
        # class). Delegate to the on-demand interactive task (qm-admin, Interactive,
        # Highest) exactly like the FactoryON_AtLogon escalation path.
        # Emits action 'worker_dedupe_heal' with workers_before / workers_after counts.
        $workersBefore = $nWorkers
        try {
            Start-ScheduledTask -TaskName 'QM_StrategyFarm_WorkerDedupe' -ErrorAction Stop
            Start-Sleep -Seconds 20
            $workersAfter = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" -ErrorAction SilentlyContinue |
                              Where-Object { $_.CommandLine -match 'terminal_worker\.py' }).Count
            $action = 'worker_dedupe_heal'
            $detail += " -> dedupe via QM_StrategyFarm_WorkerDedupe: workers_before=$workersBefore workers_after=$workersAfter/$ExpectWorkers tLiveRunning=$tLiveRunning"
        } catch {
            $action = 'heal_failed'
            $detail += " -> ERROR: $_ (QM_StrategyFarm_WorkerDedupe task missing? register via install_hygiene_and_lsm_tasks.ps1)"
        }
    }
}

# 4. record (rolling JSONL, keep last 500). No email.
$record = [ordered]@{
    ts               = $now
    factory_enabled  = $factoryEnabled
    workers          = $nWorkers
    expect           = $ExpectWorkers
    disk_free_gb     = $diskFreeGb
    dispatch_stalled = $dispatchStalled
    real_stall       = $realStall
    session_lost     = $sessionLost
    lsm_degraded     = $lsmDegraded        # FIX 2: true when qwinsta failed but worker daemons alive
    qwinsta_error    = $qwinstaError        # FIX 2: error string from qwinsta failure (null = ok)
    secret_basis     = $secretBasis         # FIX 1: 'lsa_secret' | 'winlogon_fallback_nonsystem' | ''
    active_multisym  = $activeMultisymCount
    active_progress  = $activeRecentProgressCount
    active_items     = @($activeProtection.details)
    resource         = $resourceSnapshot
    reboot_diagnostic_event_id = $rebootDiagnosticEventId
    action           = $action
    detail           = $detail
} | ConvertTo-Json -Compress -Depth 4

try {
    $dir = Split-Path $log -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -Path $log -Value $record -Encoding UTF8
    $lines = Get-Content $log -ErrorAction SilentlyContinue
    if ($lines -and $lines.Count -gt 500) { Set-Content -Path $log -Value ($lines | Select-Object -Last 500) -Encoding UTF8 }
} catch { }

# FIX 4: heartbeat record — appended after every run so downstream monitors can detect
# a frozen jsonl. Without this a monitor re-reading the last 'session_lost_no_autologon'
# line has no way to tell if the watchdog is still cycling or has stopped. A monitor
# should check the most-recent heartbeat ts; if stale (e.g. > 30 min) the watchdog itself
# is frozen and needs investigation. The heartbeat ts field is UTC ISO-8601.
$hbRecord = [ordered]@{ ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); action = 'heartbeat' } | ConvertTo-Json -Compress
try { Add-Content -Path $log -Value $hbRecord -Encoding UTF8 } catch {}

Write-Output $record
