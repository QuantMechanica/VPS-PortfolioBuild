"""Staggered idle-worker reload chunk 87 (Kimi det-repairs 2026-09-16): CODE reload for the
corrected per-symbol index-tick RAM reservation table (terminal_worker INDEX_TICK_RESERVATION_GB_BY_BASE:
NDX 12 -> 44 GB and GDAXI 24 -> 44 GB after the 2026-09-15 ledger recorded full-window D1 index
monsters at 39.5 / 39.2 / 35.4 GB admitted under those smaller reservations; WS30 12 -> 24 GB
reverted to provisional).  Ticket 6cdc6811 class calibration; receipt
docs/ops/evidence/2026-09-16_deterministic_repairs/2026-09-16_ram44_calibration_receipt.json.
Rule: never below a measured peak; max(flat, measured, floor), the 14 GB post-reservation floor,
the drain lane and the RAM emergency reaper are unchanged; rollback env
QM_INDEX_TICK_RESERVATION_TABLE=0 (every index base back to the flat 44 GB).  Same env as chunk 86.
Run detached; all ten terminals.

Chunk-86 header follows.

Staggered idle-worker reload chunk 86"""

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
TERMINALS = ["T8", "T2", "T9", "T1", "T3", "T5", "T7", "T6", "T10", "T4"]  # chunk 82: T3/T5 first (they also need the lever-3 code)  # chunk 77: all ten  # chunk 76: reloaded by chunk 75 before the flag

import ctypes
os.environ.pop("DL089_CELL_SLOTS", None)  # chunk 69: census cap rollback (OWNER 2026-09-10 cap was 48 h; OWNER window 2026-09-11)
os.environ["QM_DSR_V2"] = "1"
os.environ["QM_Q08_DSR_CONTEXT_PREFLIGHT"] = "1"  # chunk 70: Q08 DSR-context claim preflight (APPROVED c955da7f)
os.environ["QM_OPT_CENSUS_PRESCREEN_ENABLED"] = "1"  # chunk 70: OHLC-M1 PRESCREEN class (APPROVED 519c11fe; OWNER 2026-09-11)  # decision-bound: new workers inherit the V2 flag
os.environ["QM_COMPILE_GATE_HOLD_ENABLED"] = "1"  # chunk 71: compile-gate exact hold (APPROVED 57fc8b42 + hardening 09a32b16)
os.environ["QM_CENSUS_FIRST_LANE_AWARE"] = "1"  # chunk 73: lane-aware CENSUS-FIRST (APPROVED c07b8653)
os.environ["QM_NEWS_IMPACT_MAPPING_V2"] = "1"  # chunk 76: news contract v2 consumers
os.environ["DL089_LANES_PER_PROGRAM"] = "2"  # OWNER 2026-09-10 "Winsweep ja": L=2 for allow-listed programs
os.environ["DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST"] = "DL089_QM5_21507_XAUUSD_DWX_2019_2025,DL089_QM5_12710_XTIUSD_DWX_2019_2025,DL089_QM5_11910_NZDUSD_DWX_2019_2025,WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025,WINSWEEP_QM5_41405_USDJPY_DWX_2019_2025,DL089_QM5_10403_XAUUSD_DWX_2019_2025,DL089_QM5_11660_NDX_DWX_2019_2025,DL089_QM5_13213_USDJPY_DWX_2019_2025,WINSWEEP_QM5_41405_PRESCREEN_DRYRUN_2019_2025"  # 2026-09-13 20:5xZ: PRESCREEN program added (317 Model-1 cells were serialised by opt_census_slot_deferred; machine scope updated too)  # chunk 72: + 10403/11660/13213 census programs (machine scope mirrors, set 2026-09-13 01:0xZ)
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
