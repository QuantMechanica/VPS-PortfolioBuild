"""Release RAM_RESERVATION_44GB_NOT_WINNABLE_20260914 holds whose single-index row is
winnable under the 2026-09-19 evidence-bound lowering (commit cadfb48731, Fable,
OWNER 2026-09-19 "44-GB-Klasse: dann raeum mehr frei").

Selection (read-only, exactly the live claim classification):
  * hold code RAM_RESERVATION_44GB_NOT_WINNABLE_20260914 active, row pending, not superseded
  * terminal_worker._ram_reservation_detail_for_candidate -> single_index_tick
  * reservation <= MAX_RESERVATION_GB (22 GB: claimable at >= 36 GB free with the 14 GB floor)
  * phase != Q08 (DSR-context rows must pass dsr_cohort.claimability_precheck first; the
    2026-09-15 head-of-line lesson) and base != SP500 (per-EA evidence only, never class)
Default dry-run; --apply releases through farmctl.release_work_item_hold (factory mutation
lock, fresh SQLite backup, exact hold-code CAS, transition-ledger record, events row).
Journal (append-only): docs/ops/evidence/2026-09-19_factory_unblock/ram44_release_journal.jsonl
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import random
import sqlite3
import sys
import time
from pathlib import Path

REPO = Path("C:/QM/repo")
ROOT = Path("D:/QM/strategy_farm")
DB_RO = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
HOLD_CODE = "RAM_RESERVATION_44GB_NOT_WINNABLE_20260914"
EVID = REPO / "docs" / "ops" / "evidence" / "2026-09-19_factory_unblock"
JOURNAL = EVID / "ram44_release_journal.jsonl"
MAX_RESERVATION_GB = 22.0
EXCLUDED_PHASES = {"Q08"}
EXCLUDED_BASES = {"SP500"}

sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
sys.path.insert(0, str(REPO))
os.chdir(REPO)
import farmctl  # noqa: E402


def candidates() -> list[dict]:
    import terminal_worker as tw  # noqa: E402

    conn = sqlite3.connect(DB_RO, uri=True, timeout=60)
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        """
        SELECT w.* FROM work_items w
        JOIN work_item_holds h ON h.work_item_id = w.id AND h.active = 1 AND h.hold_code = ?
        WHERE w.status = 'pending'
          AND NOT EXISTS (SELECT 1 FROM work_item_supersedes s WHERE s.work_item_id = w.id)
        ORDER BY w.created_at, w.id
        """,
        (HOLD_CODE,),
    ).fetchall()
    conn.close()
    ms = tw._multisymbol_ea_ids()
    out = []
    for r in rows:
        payload = json.loads(r["payload_json"] or "{}")
        try:
            multi = tw._work_item_is_multisymbol(r, payload, ms)
            cls, gb, src = tw._ram_reservation_detail_for_candidate(r, payload, multi)
        except Exception:
            continue
        base = str(r["symbol"] or "").split(".")[0].upper()
        if multi or cls != tw.COMMIT_CLASS_SINGLE_INDEX_TICK:
            continue
        if str(r["phase"]).upper() in EXCLUDED_PHASES or base in EXCLUDED_BASES:
            continue
        if not (float(gb) <= MAX_RESERVATION_GB):
            continue
        out.append({
            "id": r["id"], "ea_id": r["ea_id"], "symbol": r["symbol"], "phase": r["phase"],
            "created_at": r["created_at"], "ram_class": cls, "reservation_gb": float(gb),
            "reservation_source": src, "timeframe": tw._normalize_timeframe(r, payload),
        })
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--limit", type=int, default=0, help="0 = all selected")
    ap.add_argument("--note", default="")
    args = ap.parse_args()
    rows = candidates()
    if args.limit > 0:
        rows = rows[: args.limit]
    note = (args.note or "2026-09-19 evidence-bound index reservation lowering (commit cadfb48731, "
            "receipt docs/ops/evidence/2026-09-19_factory_unblock/RECEIPT.md): per-EA/class ledger "
            "evidence puts this row <= 22 GB; hold release condition met per row; guards unchanged "
            "(phase floor raise-only, RAM emergency reaper backstop)")
    print(f"selected {len(rows)} rows <= {MAX_RESERVATION_GB} GB (mode {'apply' if args.apply else 'dry-run'})")
    for r in rows:
        print("  ", r["id"][:8], r["ea_id"], r["symbol"], r["phase"], r["timeframe"], r["reservation_gb"], r["reservation_source"])
    if not args.apply:
        return 0
    EVID.mkdir(parents=True, exist_ok=True)
    n_ok = n_fail = 0
    for r in rows:
        ok = False
        res: dict = {}
        for attempt in range(1, 16):
            try:
                res = farmctl.release_work_item_hold(ROOT, r["id"], HOLD_CODE, note)
                ok = bool(isinstance(res, dict) and res.get("released") is True)
            except Exception as exc:
                res = {"error": f"{type(exc).__name__}: {exc}"[:500]}
                ok = False
            reason = str((res or {}).get("reason") or (res or {}).get("error") or "")
            if ok or not any(k in reason for k in ("factory_mutation_lock_busy", "GOVERNED_STATE_BACKUP_TIMEOUT", "database is locked")):
                break
            time.sleep(4 + random.random() * 6)
        n_ok += ok
        n_fail += (not ok)
        with JOURNAL.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps({"at_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "row": r, "ok": ok,
                                 "result": res if isinstance(res, dict) else str(res)[:500]}, default=str) + "\n")
        print(("   -> ok " if ok else "   -> FAILED "), str(res)[:160].replace("\n", " "))
    print(f"applied_ok {n_ok} failed {n_fail}")
    return 0 if n_fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
