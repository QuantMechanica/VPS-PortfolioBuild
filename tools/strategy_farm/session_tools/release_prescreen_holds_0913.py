"""Release the PRESCREEN_SCHEMA_FIX_PENDING holds (Orchestrator 2026-09-13 13:4xZ).

Ticket 519c11fe closed APPROVED (commit 7636241a08 + fce66ab4d4: SH-3 CHECK admits
prescreen_measurement, run_smoke.ps1 no longer trips the real-ticks marker for Model=1). The 347 cells of
WINSWEEP_QM5_41405_PRESCREEN_DRYRUN_2019_2025 were held on 2026-09-12 08:22Z after the first claim crashed
(work item 62538f30). Lesson from that day: a first-claim proof must include the VERDICT WRITE, so this tool
releases exactly one cell first (``--first``), the orchestrator watches it reach a PRESCREEN verdict, and only
then releases the rest (``--all``). Uses farmctl.release_work_item_hold (factory mutation lock, fresh backup,
CAS on hold_code/active, ledger + events rows; work_items.status never changed). Journal: append-only JSONL.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
import sys
from pathlib import Path

REPO = Path("C:/QM/repo")
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
import farmctl  # noqa: E402

ROOT = Path("D:/QM/strategy_farm")
DB = ROOT / "state" / "farm_state.sqlite"
HOLD = "PRESCREEN_SCHEMA_FIX_PENDING"
JOURNAL = REPO / "docs" / "ops" / "evidence" / "2026-09-13_prescreen_hold_release_journal.jsonl"
NOTE = ("519c11fe APPROVED 2026-09-13 (commits fce66ab4d4 + 7636241a08; 107 tests; live SH-3 CHECK admits "
        "prescreen_measurement) - orchestrator release {mode}")


def held_cells(limit: int | None) -> list[tuple[str, str]]:
    conn = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    try:
        rows = conn.execute(
            """SELECT w.id, w.setfile_path FROM work_items w
               JOIN work_item_holds h ON h.work_item_id=w.id AND h.active=1 AND h.hold_code=?
               WHERE w.status='pending' ORDER BY w.setfile_path""",
            (HOLD,),
        ).fetchall()
    finally:
        conn.close()
    return rows[:limit] if limit else rows


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--first", action="store_true", help="release exactly one held cell (first-claim proof)")
    g.add_argument("--all", action="store_true", help="release every remaining held cell")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    mode = "first-claim proof (one cell)" if args.first else "full release after first-claim proof"
    targets = held_cells(1 if args.first else None)
    print(f"held cells selected: {len(targets)}")
    done = 0
    JOURNAL.parent.mkdir(parents=True, exist_ok=True)
    with JOURNAL.open("a", encoding="utf-8") as journal:
        for wid, setfile in targets:
            res = farmctl.release_work_item_hold(ROOT, wid, HOLD, NOTE.format(mode=mode), dry_run=args.dry_run)
            ok = bool(res.get("released"))
            done += int(ok)
            journal.write(json.dumps({"at_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
                                      "work_item_id": wid, "setfile": setfile, "mode": mode,
                                      "dry_run": args.dry_run, "result": res}, default=str) + "\n")
            if not ok or args.first:
                print(wid, Path(setfile).name, res.get("released"), res.get("reason", ""))
    print(f"released {done}/{len(targets)} ({'dry-run' if args.dry_run else 'applied'}); journal {JOURNAL}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
