"""Release RAM_RESERVATION_44GB_NOT_WINNABLE_20260914 holds whose class became winnable
under the 2026-09-16 ticket 6cdc6811 calibration (Kimi det-repairs).

Unlike release_44gb_holds_0914.py --max-reservation-gb (written for the single-symbol
index Q04 wave), this selector classifies with the REAL multisymbol EA census
(terminal_worker._multisymbol_ea_ids) exactly like the park tool and the live claim
path, so a heavy_or_unknown_multisymbol row can never masquerade as ordinary@8.

Selection: every active hold row re-classified with the corrected reservation table
(commit c29b4196d1); release only rows whose current reservation is strictly below
44 GB (today: two_leg_metal_pair @ 24 GB - 52 rows).  SP500/NDX/GDAXI single_index_tick
@44 (measured necessity) and heavy_or_unknown_multisymbol @44 (fail-safe, n=0
measurements) stay parked.  Guards untouched: max(flat, measured, floor), the 14 GB
post-reservation floor, the drain lane and the RAM emergency reaper.

Default dry-run; --apply releases through farmctl.release_work_item_hold (factory
mutation lock, fresh SQLite backup, exact hold-code CAS, transition-ledger record,
events row).  Journal (append-only):
docs/ops/evidence/2026-09-16_deterministic_repairs/ram44_release_journal.jsonl
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
EVID = REPO / "docs" / "ops" / "evidence" / "2026-09-16_deterministic_repairs"
JOURNAL = EVID / "ram44_release_journal.jsonl"
RECEIPT = EVID / "2026-09-16_ram44_calibration_receipt.json"
MAX_RESERVATION_GB = 44.0  # strict below-release: rows at the fail-safe stay parked

sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
sys.path.insert(0, str(REPO))
os.chdir(REPO)
import farmctl  # noqa: E402


def candidates() -> list[dict]:
    import terminal_worker as tw  # noqa: E402  (worker classification, read-only)

    conn = sqlite3.connect(DB_RO, uri=True, timeout=60)
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        """
        SELECT w.* FROM work_items w
        JOIN work_item_holds h ON h.work_item_id = w.id AND h.active = 1 AND h.hold_code = ?
        WHERE w.status = 'pending'
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
        if not (float(gb) < MAX_RESERVATION_GB):
            continue
        out.append({
            "id": r["id"], "ea_id": r["ea_id"], "symbol": r["symbol"], "phase": r["phase"],
            "created_at": r["created_at"], "ram_class": cls, "reservation_gb": float(gb),
            "reservation_source": src,
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
    note = (args.note or "2026-09-16 ticket 6cdc6811 calibration (commit c29b4196d1; receipt "
            "docs/ops/evidence/2026-09-16_deterministic_repairs/2026-09-16_ram44_calibration_receipt.json): "
            "current reservation class winnable after the measured-peak recalibration; guards unchanged")
    print(f"selected {len(rows)} rows below {MAX_RESERVATION_GB} GB (mode {'apply' if args.apply else 'dry-run'})")
    for r in rows:
        print("  ", r["id"][:8], r["ea_id"], r["symbol"], r["phase"], r["ram_class"], r["reservation_gb"])
    if not args.apply:
        return 0
    EVID.mkdir(parents=True, exist_ok=True)
    n_ok = n_fail = 0
    for r in rows:
        ok = False
        res: dict = {}
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
        with JOURNAL.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps({"at_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "row": r, "ok": ok,
                                 "result": res if isinstance(res, dict) else str(res)[:500]}, default=str) + "\n")
        print(("   -> ok " if ok else "   -> FAILED "), str(res)[:160].replace("\n", " "))
    print(f"applied_ok {n_ok} failed {n_fail}")
    return 0 if n_fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
