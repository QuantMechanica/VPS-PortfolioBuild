"""Staggered idle-worker reload chunk 76 (Orchestrator 2026-09-13 17:3xZ): ENV reload so the workers reloaded by chunk 75 before QM_NEWS_IMPACT_MAPPING_V2=1 entered the machine scope carry the news contract v2 flag (commit b9daf49ec8). Started by a detached waiter after chunk 75 exits.

Chunk-75 header follows.

Staggered idle-worker reload chunk 75 (Orchestrator 2026-09-13 16:3xZ): CODE reload for the per-EA authoritative RAM expectation (commit 96946e85ed; fleet idled at 3/10 with 27 GB free because light EAs on the metal class reserved the class p95 23.6 GB). Same env as chunk 74. Run detached.

Chunk-74 header follows.

Staggered idle-worker reload chunk 74 (Orchestrator 2026-09-13 14:5xZ): CODE reload so every worker runs the p95 class RAM expectation (commit after 8ad2a58ef0: class key reserves ledger p95 instead of the polluted all-time max; fleet was 4/10 active with 38 GB free, T8 ram_class_skipped 879). Same env as chunk 73 (all flags also in the machine scope). Run detached (Start-Process) because tool-shell background jobs are stopped after ~10 min.

Chunk-73 header follows.

Staggered idle-worker reload chunk 73 (Orchestrator 2026-09-13 13:1xZ): (a) restore the chunk-70/71 flags on the five workers that tester_cache_purge tore down and relaunched at 10:00Z through the task launcher (T2, T3, T5, T6, T9 lost QM_OPT_CENSUS_PRESCREEN_ENABLED / QM_COMPILE_GATE_HOLD_ENABLED / QM_Q08_DSR_CONTEXT_PREFLIGHT; proof: T3 refused the PRESCREEN first-claim cell d4c790e7 at 12:32Z with opt_census_prescreen_default_off); (b) activate the APPROVED lane-aware CENSUS-FIRST predicate QM_CENSUS_FIRST_LANE_AWARE=1 (c07b8653, commit 2632eb53bb, Default-OFF) on all ten workers. All four flags are now mirrored in the machine scope (set 13:1xZ) so every relaunch path (purge, watchdog, launcher) inherits them; rollback = unset in the machine scope and reload. Same discipline as chunk 72.

Original chunk-72/71 header follows.
Staggered idle-worker reload chunk 72 (Orchestrator 2026-09-13 01:0xZ): extend the DL-089 same-program allow-list (L=2) to the three census programs that currently hold ALL unheld pending cells (DL089_QM5_10403_XAUUSD 69, DL089_QM5_11660_NDX 344, DL089_QM5_13213_USDJPY pattern census 570) so the six protected census lanes can actually be filled. Measured 2026-09-13 00:34Z on T9: opt_census_slot_deferred 916 + census_lane_protection_skipped 593 with 5 of 10 workers idle and 33 GB RAM free -- CENSUS-FIRST reserves RAM for census lanes that the per-program lane limit (L=1 off-list) cannot fill (_opt_census_cells_claimable_in_txn is lane-unaware; Codex root-cause ticket enqueued). Executes OWNER-DEC-SAMEPROG-FLEET-20260831 = YES (L=2 for the DL-089 programs) for the programs with live work; the 2026-09-10 extension (3 DL089 + 2 WINSWEEP programs at L=2) ran without decline loops. Machine scope mirrors the new value (set 01:0xZ) so launcher respawns inherit it. Rollback: pop the three ids from the machine scope and reload again. Keeps every chunk-71 flag.

Original chunk-71 header follows.
Staggered idle-worker reload chunk 71 (Orchestrator 2026-09-12 16:1xZ): activate the reviewed Default-OFF compile-gate hold QM_COMPILE_GATE_HOLD_ENABLED=1 (cd1d4e3ad8 + hardening 3eabb1706a, APPROVED 57fc8b42 + 09a32b16) so spawn refusals of EAs with changed source become exact holds instead of terminal INFRA_FAIL rows; keeps the chunk-70 flags (Q08 preflight, PRESCREEN class) and the chunk-69 state. DL089_CELL_SLOTS=3 had been mirrored into the machine scope on 2026-09-10 and survived the reboot through the logon-session environment (effective_limits = K8 L2 G3, opt_census_slot_deferred 3252). Machine+user vars removed 20:1xZ; this chunk pops the inherited var so every worker runs at the code default G=6 (min with workers); L=2 + allowlist from machine scope. Same discipline as chunk 58.

Purpose: make the resident terminal workers load (a) the committed worker fixes
(containment scope 54c3e3a3fd, orphan claim 48b8e2bbcf) and (b) the
OWNER-decided DL-089 same-program parallelism environment
(OWNER-DEC-SAMEPROG-FLEET-20260831 = YES: L=2 for the eight authenticated
programs, G<=8).

Discipline (thundering-herd lesson 29.08 + SAMEPROG decision text): never the
fleet launcher, never interrupt an active claim; one terminal at a time; only
a worker whose terminal has NO active work item and whose last log event is an
idle claim attempt; wait for the watchdog-independent respawn via
start_terminal_workers.py (starts only missing workers); spacing >= 150 s.
"""
from __future__ import annotations

import json
import os
import subprocess
import sqlite3
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(r"C:\QM\repo")
ROOT = Path(r"D:\QM\strategy_farm")
DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
LOGS = ROOT / "logs"
PIDS = ROOT / "state" / "worker_pids.json"
TERMINALS = ["T8", "T3", "T5", "T6", "T2", "T9", "T1", "T4"]  # chunk 76: reloaded by chunk 75 before the flag

import ctypes
os.environ.pop("DL089_CELL_SLOTS", None)  # chunk 69: census cap rollback (OWNER 2026-09-10 cap was 48 h; OWNER window 2026-09-11)
os.environ["QM_DSR_V2"] = "1"
os.environ["QM_Q08_DSR_CONTEXT_PREFLIGHT"] = "1"  # chunk 70: Q08 DSR-context claim preflight (APPROVED c955da7f)
os.environ["QM_OPT_CENSUS_PRESCREEN_ENABLED"] = "1"  # chunk 70: OHLC-M1 PRESCREEN class (APPROVED 519c11fe; OWNER 2026-09-11)  # decision-bound: new workers inherit the V2 flag
os.environ["QM_COMPILE_GATE_HOLD_ENABLED"] = "1"  # chunk 71: compile-gate exact hold (APPROVED 57fc8b42 + hardening 09a32b16)
os.environ["QM_CENSUS_FIRST_LANE_AWARE"] = "1"  # chunk 73: lane-aware CENSUS-FIRST (APPROVED c07b8653)
os.environ["QM_NEWS_IMPACT_MAPPING_V2"] = "1"  # chunk 76: news contract v2 consumers
os.environ["DL089_LANES_PER_PROGRAM"] = "2"  # OWNER 2026-09-10 "Winsweep ja": L=2 for allow-listed programs
os.environ["DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST"] = "DL089_QM5_21507_XAUUSD_DWX_2019_2025,DL089_QM5_12710_XTIUSD_DWX_2019_2025,DL089_QM5_11910_NZDUSD_DWX_2019_2025,WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025,WINSWEEP_QM5_41405_USDJPY_DWX_2019_2025,DL089_QM5_10403_XAUUSD_DWX_2019_2025,DL089_QM5_11660_NDX_DWX_2019_2025,DL089_QM5_13213_USDJPY_DWX_2019_2025"  # chunk 72: + 10403/11660/13213 census programs (machine scope mirrors, set 2026-09-13 01:0xZ)
def _pid_alive(pid: int) -> bool:
    h = ctypes.windll.kernel32.OpenProcess(0x1000, False, pid)
    if not h:
        return False
    ctypes.windll.kernel32.CloseHandle(h)
    return True
SPACING = 150
IDLE_EVENTS = {"claim_declined", "next_cell_prestage", "custom_history_lease_busy", "sqlite_locked", "ram_low_pause", "heartbeat"}

def log(msg: str) -> None:
    print(f"{datetime.now(timezone.utc).isoformat(timespec='seconds')} {msg}", flush=True)

def active_terminals() -> set[str]:
    conn = sqlite3.connect(DB, uri=True, timeout=5)
    conn.execute("PRAGMA busy_timeout=5000")
    rows = conn.execute("SELECT claimed_by FROM work_items WHERE status='active' AND claimed_by IS NOT NULL").fetchall()
    conn.close()
    return {str(r[0]).upper() for r in rows}

def worker_pids() -> dict[str, int]:
    try:
        return {k.upper(): int(v) for k, v in json.loads(PIDS.read_text(encoding="utf-8")).items()}
    except Exception:
        return {}

def last_event(term: str) -> str:
    path = LOGS / f"terminal_worker_{term}.log"
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()[-3:]
    except OSError:
        return "?"
    for line in reversed(lines):
        try:
            return str(json.loads(line).get("event") or "?")
        except Exception:
            continue
    return "?"

def pid_alive(pid: int) -> bool:
    out = subprocess.run(["powershell", "-NoProfile", "-Command", f"(Get-Process -Id {pid} -ErrorAction SilentlyContinue) -ne $null"], capture_output=True, text=True)
    return "True" in (out.stdout or "")

LOCK = Path(r"D:/QM/strategy_farm/state/FACTORY_MUTATION.lock")

def lock_owner() -> str:
    try:
        return str(json.loads(LOCK.read_text(encoding="utf-8")).get("owner") or "")
    except Exception:
        return ""

def lock_held_by(term: str, pid: int | None) -> bool:
    """True while the factory mutation lock names this worker (claim in flight)."""
    try:
        d = json.loads(LOCK.read_text(encoding="utf-8"))
    except Exception:
        return False
    owner = str(d.get("owner") or "")
    return owner.endswith(":" + term) or (pid is not None and int(d.get("pid") or 0) == int(pid))

def stop(pid: int) -> None:
    subprocess.run(["powershell", "-NoProfile", "-Command", f"Stop-Process -Id {pid} -Force -ErrorAction SilentlyContinue"], capture_output=True, text=True)

def start_missing() -> str:
    p = subprocess.run([sys.executable, str(REPO / "tools/strategy_farm/start_terminal_workers.py")], capture_output=True, text=True, cwd=str(REPO), timeout=300)
    return ((p.stdout or "") + (p.stderr or ""))[-400:].replace("\n", " | ")

def _chunk40b_alive() -> bool:
    out = subprocess.run(["powershell", "-NoProfile", "-Command", "(Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { $_.CommandLine -like '*reload_chunk40b.py*' }) -ne $null"], capture_output=True, text=True)
    return "True" in (out.stdout or "")


done: list[str] = []
pending = list(TERMINALS)
deadline = time.time() + 360 * 60
while pending and time.time() < deadline:
    act = active_terminals()
    pids = worker_pids()
    picked = None
    for term in pending:
        if term in act:
            continue
        ev = last_event(term)
        if ev in IDLE_EVENTS or ev == "?":
            picked = (term, ev)
            break
    if not picked:
        log(f"no idle worker among {pending}; active={sorted(act)}; waiting 10s")
        time.sleep(10)
        continue
    term, ev = picked
    pid = pids.get(term)
    log(f"reload {term}: pid={pid} last_event={ev} active={sorted(act)}")
    # CEO 2026-09-05: never kill a worker that holds the factory mutation lock (T1 was
    # stopped mid-claim by chunk 40 at 00:03:29Z and left a stale lock for ~2 min).
    waited = 0
    while lock_held_by(term, pid) and waited < 90:
        log(f"{term} holds FACTORY_MUTATION.lock (owner={lock_owner()}); waiting")
        time.sleep(3); waited += 3
    if lock_held_by(term, pid) or term in active_terminals():
        log(f"{term} busy after wait (lock/active); deferring this round")
        time.sleep(10)
        continue
    if pid and pid_alive(pid):
        stop(pid)
        time.sleep(5)
    log(f"start_missing -> {start_missing()}")
    time.sleep(20)
    new = worker_pids().get(term)
    log(f"{term} new pid={new}")
    done.append(term)
    pending.remove(term)
    time.sleep(SPACING)
log(f"finished: reloaded={done} not_reloaded={pending}")
