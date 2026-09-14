"""Supervised RAM measurement of the first full-window index row after commit 08b494d9b7 (Orchestrator 2026-09-14).

Read-only watcher: polls every 20 s which terminal holds the given work item, the working
set of that terminal's terminal64/metatester64 subtree (Win32_Process, path-anchored, T_Live
excluded) and host free RAM, and appends samples to
docs/ops/evidence/2026-09-14_index_ram_table/measurement_<id8>.jsonl.  Stops when the row
leaves status=active (records the final verdict) or after --max-minutes.  Never touches a
process or the DB.  The ledger row written by the worker (tester_memory_ledger.jsonl) is the
authoritative peak; this file is the live trace behind it.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
import subprocess
import time
from pathlib import Path

DB_RO = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
EVID = Path("C:/QM/repo/docs/ops/evidence/2026-09-14_index_ram_table")
PS = (
    "$ps = Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'terminal64.exe' -or $_.Name -eq 'metatester64.exe') "
    "-and $_.ExecutablePath -like 'D:\\QM\\mt5\\{T}\\*' }; "
    "$ws = ($ps | Measure-Object -Property WorkingSetSize -Sum).Sum; "
    "$free = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory; "
    "'{0}|{1}|{2}' -f [int64]$ws, [int64]$free, ($ps | Measure-Object).Count"
)


def status(wid: str) -> tuple[str, str, str]:
    c = sqlite3.connect(DB_RO, uri=True, timeout=30)
    r = c.execute("select status, coalesce(claimed_by,''), coalesce(verdict,'') from work_items where id=?", (wid,)).fetchone()
    c.close()
    return (r[0], r[1], r[2]) if r else ("?", "", "")


def sample(term: str) -> dict:
    out = subprocess.run(["powershell", "-NoProfile", "-Command", PS.replace("{T}", term)], capture_output=True, text=True, timeout=60).stdout.strip()
    try:
        ws, free_kb, n = out.split("|")
        return {"subtree_ws_gb": round(int(ws) / 2**30, 2), "host_free_gb": round(int(free_kb) / 2**20, 1), "procs": int(n)}
    except Exception:
        return {"raw": out[:120]}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True)
    ap.add_argument("--max-minutes", type=int, default=240)
    ap.add_argument("--interval", type=int, default=20)
    args = ap.parse_args()
    wid = args.id
    EVID.mkdir(parents=True, exist_ok=True)
    out = EVID / f"measurement_{wid[:8]}.jsonl"
    peak = 0.0
    t0 = time.time()
    seen_active = False
    while time.time() - t0 < args.max_minutes * 60:
        st, term, verdict = status(wid)
        rec = {"at_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"), "status": st, "terminal": term}
        if st == "active" and term:
            seen_active = True
            rec.update(sample(term))
            peak = max(peak, float(rec.get("subtree_ws_gb") or 0.0))
            rec["peak_so_far_gb"] = peak
        elif seen_active:
            rec["verdict"] = verdict
            rec["peak_gb"] = peak
            with out.open("a", encoding="utf-8") as fh:
                fh.write(json.dumps(rec) + "\n")
            print("FINAL", rec, flush=True)
            return 0
        with out.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(rec) + "\n")
        print(rec, flush=True)
        time.sleep(args.interval)
    print("TIMEOUT peak_gb", peak, flush=True)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
