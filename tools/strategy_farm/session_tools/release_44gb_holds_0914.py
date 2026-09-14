"""Release RAM_RESERVATION_44GB_NOT_WINNABLE_20260914 holds in governed waves (Orchestrator 2026-09-14).

Lever 1 of the 2026-09-14 control review (OWNER: "Los gehts, alles freigegeben und gemaess
Vorschlag entschieden").  After commit 08b494d9b7 (per-symbol index-tick reservation table:
SP500 stays 44 GB, NDX/GDAXI/WS30/UK100 provisional 24 GB) the parked index rows become
winnable again.  Releases go through ``farmctl.release_work_item_hold`` (factory mutation
lock, SQLite backup, exact hold-code compare-and-swap, hold-release record) one row at a
time, filtered by symbol base / phase / limit so the first NDX row is a supervised
MEASUREMENT (ledger peak) before any wave.  SP500 rows and the multisymbol
(heavy_or_unknown_multisymbol) rows are never selected here: their 44 GB reservation is a
measured / fail-safe value and stays unwinnable until the RAM decision.

Default = dry-run listing; ``--apply`` releases.  Journal (append-only):
docs/ops/evidence/2026-09-14_index_ram_table/release_journal.jsonl
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import random
import re
import sqlite3
import sys
import time
from pathlib import Path

REPO = Path("C:/QM/repo")
ROOT = Path("D:/QM/strategy_farm")
DB_RO = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
HOLD_CODE = "RAM_RESERVATION_44GB_NOT_WINNABLE_20260914"
EVID = REPO / "docs" / "ops" / "evidence" / "2026-09-14_index_ram_table"
JOURNAL = EVID / "release_journal.jsonl"
NEVER = {"SP500"}  # measured 44 GB; unwinnable by design until the RAM decision
PHASE_ORDER = {"Q11": 0, "Q09": 1, "Q08": 2, "Q07": 3, "Q06": 4, "Q05": 5, "Q04": 6, "Q03": 7, "Q02": 8}

sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
sys.path.insert(0, str(REPO))
os.chdir(REPO)
import farmctl  # noqa: E402


def _tf(setfile_path: str) -> str:
    m = re.search(r"_(M1|M5|M15|M30|H1|H4|D1|W1)_", setfile_path or "")
    return m.group(1) if m else "?"


def candidates(bases: set[str], phases: set[str], ids: set[str]) -> list[dict]:
    conn = sqlite3.connect(DB_RO, uri=True, timeout=60)
    rows = conn.execute(
        """
        SELECT w.id, w.ea_id, w.symbol, w.phase, w.setfile_path, w.created_at
        FROM work_items w
        JOIN work_item_holds h ON h.work_item_id = w.id AND h.active = 1 AND h.hold_code = ?
        WHERE w.status = 'pending'
        ORDER BY w.created_at
        """,
        (HOLD_CODE,),
    ).fetchall()
    conn.close()
    out = []
    for wid, ea, sym, phase, setfile, created in rows:
        base = str(sym or "").split(".")[0].upper()
        if ids and wid not in ids and wid[:8] not in ids:
            continue
        if not ids:
            if base in NEVER or base not in bases:
                continue
            if phases and phase not in phases:
                continue
        out.append({"id": wid, "ea_id": ea, "symbol": sym, "base": base, "phase": phase, "tf": _tf(setfile), "created_at": created})
    out.sort(key=lambda r: (PHASE_ORDER.get(r["phase"], 99), r["created_at"]))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", action="append", default=[], help="index base(s) to release, e.g. NDX (repeatable)")
    ap.add_argument("--phase", action="append", default=[], help="phase filter (repeatable)")
    ap.add_argument("--id", action="append", default=[], help="explicit work item id(s) / 8-char prefixes")
    ap.add_argument("--limit", type=int, default=1)
    ap.add_argument("--note", default="")
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    bases = {b.upper() for b in args.base}
    phases = {p.upper() for p in args.phase}
    ids = set(args.id)
    if not bases and not ids:
        print("nothing selected: pass --base NDX (and/or --phase Q04) or --id <work_item_id>")
        return 2
    rows = candidates(bases, phases, ids)[: max(0, args.limit)]
    note = (args.note or "2026-09-14 lever 1: per-symbol index-tick reservation table (commit 08b494d9b7) makes this row winnable; released in a governed wave")
    n_ok = n_fail = 0
    for r in rows:
        print(("APPLY " if args.apply else "DRY   "), r["id"][:8], r["ea_id"], r["symbol"], r["phase"], r["tf"], r["created_at"][:10])
        if not args.apply:
            continue
        res, ok = {}, False
        for attempt in range(1, 16):  # the governed release competes with worker claims for the factory mutation lock
            try:
                res = farmctl.release_work_item_hold(ROOT, r["id"], HOLD_CODE, note)
                ok = bool(isinstance(res, dict) and res.get("released") is True)
            except Exception as exc:  # governed tool refusals are the evidence
                res = {"error": f"{type(exc).__name__}: {exc}"[:500]}
                ok = False
            reason = str((res or {}).get("reason") or (res or {}).get("error") or "")
            if ok or not any(k in reason for k in ("factory_mutation_lock_busy", "GOVERNED_STATE_BACKUP_TIMEOUT", "database is locked")):
                break
            time.sleep(4 + random.random() * 6)
        n_ok += ok
        n_fail += (not ok)
        EVID.mkdir(parents=True, exist_ok=True)
        with JOURNAL.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps({"at_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "row": r, "ok": ok,
                                 "result": res if isinstance(res, dict) else str(res)[:500]}, default=str) + "\n")
        print("   ->", "ok" if ok else "FAILED", str(res)[:200].replace("\n", " "))
    print(f"selected {len(rows)} applied_ok {n_ok} failed {n_fail} mode {'apply' if args.apply else 'dry-run'}")
    return 0 if n_fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
