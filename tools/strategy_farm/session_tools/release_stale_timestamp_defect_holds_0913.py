"""Release the 12 stale NEWS_CALENDAR_TIMESTAMP_DEFECT holds (Orchestrator 2026-09-13, OWNER order "alles Veraltete neu machen").

Why they are stale: the holds were applied on 2026-09-05 "pending OWNER decision" on the news-calendar timestamp
defect (OWNER_VORLAGE_2026-09-05_news_calendar_defect.md). That decision was taken on 2026-09-07 as
OWNER-DEC-CALENDAR-CRITERIA-B-PRIME-20260907 (corrected candidate calendar as adjudication basis) and
OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907 (scoped consumer B activated for Q10_NEWS). Since then the
governed taint sweep (news_calendar_taint.sweep, every 10 min) is the single hold authority for calendar-related
rows: its preview lists these 12 rows as PRESERVE_OTHER_HOLD, i.e. it would re-hold any tainted row itself.

Governed path only: farmctl.release_work_item_hold (factory mutation lock, fresh backup, CAS on hold_code/active,
ledger + events rows; work_items.status never changed). Dry-run by default; --apply releases.
Journal: docs/ops/evidence/2026-09-13_timestamp_defect_hold_release_journal.jsonl (append-only).
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
DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
HOLD = "NEWS_CALENDAR_TIMESTAMP_DEFECT"
NOTE = (
    "Orchestrator 2026-09-13 ({mode}): stale hold released - the pending OWNER decision it waited for was taken on "
    "2026-09-07 (OWNER-DEC-CALENDAR-CRITERIA-B-PRIME-20260907 + OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907); "
    "news_calendar_taint.sweep is the single hold authority for calendar rows (preview 2026-09-13: PRESERVE_OTHER_HOLD "
    "for these rows). Reversible via farmctl hold re-apply."
)
JOURNAL = REPO / "docs" / "ops" / "evidence" / "2026-09-13_timestamp_defect_hold_release_journal.jsonl"


def held_rows() -> list[dict]:
    c = sqlite3.connect(DB, uri=True)
    c.row_factory = sqlite3.Row
    rows = c.execute(
        """SELECT w.id, w.ea_id, w.symbol, w.phase, w.status FROM work_items w
           JOIN work_item_holds h ON h.work_item_id = w.id AND h.active = 1 AND h.hold_code = ?
           ORDER BY w.created_at""",
        (HOLD,),
    ).fetchall()
    c.close()
    return [dict(r) for r in rows]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    mode = "applied" if args.apply else "dry-run"
    rows = held_rows()
    print(f"held rows: {len(rows)}")
    released = 0
    for r in rows:
        if r["status"] != "pending":
            print(" skip non-pending", r["id"], r["status"])
            continue
        res = farmctl.release_work_item_hold(ROOT, r["id"], HOLD, NOTE.format(mode=mode), dry_run=not args.apply)
        ok = bool(res.get("released") or res.get("applied") or res.get("ok")) if isinstance(res, dict) else bool(res)
        print(" ", r["id"], r["ea_id"], r["symbol"], r["phase"], "->", (json.dumps(res)[:160] if isinstance(res, dict) else res))
        with JOURNAL.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps({"at_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "mode": mode, "work_item_id": r["id"],
                                 "ea_id": r["ea_id"], "symbol": r["symbol"], "phase": r["phase"], "result": res}, default=str) + "\n")
        released += 1 if (args.apply and ok) else 0
    print(f"released {released}/{len(rows)} ({mode}); journal {JOURNAL}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
