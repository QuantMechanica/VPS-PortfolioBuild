"""OWNER row-by-row release of B-prime-admissible Q10_NEWS rows (CEO loop 2026-09-07).

Uses news_calendar_taint.release_scoped_item() exactly as designed: one row per call inside a caller-owned
write transaction under the factory mutation lock; the marker + footnote are stamped into the row payload and
only this module's NEWS_CALENDAR_TAINTED hold is released.  Status, verdict and evidence are never touched.

Usage: python release_scoped_b_rows.py <receipt-tag> <work_item_id> [<work_item_id> ...]
Writes docs/ops/evidence/<date>_scoped_b_release_<tag>.json.
"""
from __future__ import annotations

import datetime
import json
import pathlib
import sqlite3
import sys

REPO = pathlib.Path(r"C:\QM\repo")
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
sys.path.insert(0, str(REPO))
import farmctl  # noqa: E402
import news_calendar_taint as taint  # noqa: E402

DB = pathlib.Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
ROOT = pathlib.Path(r"D:\QM\strategy_farm")
tag = sys.argv[1]
ids = sys.argv[2:]
receipt = {"schema": "qm.scoped-b-release-receipt/v1", "at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
           "actor": "claude-session-018mXkPPkaHQ2fPuduPCBcWc", "decisions": ["OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907", "OWNER-DEC-CALENDAR-CRITERIA-B-PRIME-20260907"],
           "pin_manifest": str(farmctl.Q09_AUTOPILOT_CALENDAR_MANIFEST), "rows": []}
with farmctl.FactoryMutationLock(farmctl.path_for_factory_flag(farmctl.factory_off_flag_path(ROOT)), owner="release_scoped_b_rows"):
    conn = sqlite3.connect(str(DB), timeout=60)
    conn.row_factory = sqlite3.Row
    try:
        for wid in ids:
            entry = {"work_item_id": wid}
            try:
                conn.execute("BEGIN IMMEDIATE")
                detail = taint.release_scoped_item(conn, wid, farmctl.Q09_AUTOPILOT_CALENDAR_MANIFEST)
                conn.commit()
                entry.update({"released": True, "detail": detail})
            except Exception as exc:  # noqa: BLE001
                conn.rollback()
                entry.update({"released": False, "error": f"{type(exc).__name__}: {exc}"})
            print(json.dumps(entry, default=str)[:300], flush=True)
            receipt["rows"].append(entry)
    finally:
        conn.close()
out = REPO / f"docs/ops/evidence/{datetime.date.today().isoformat()}_scoped_b_release_{tag}.json"
out.write_text(json.dumps(receipt, indent=1, default=str), encoding="utf-8")
print("receipt", out.name, "released", sum(1 for r in receipt["rows"] if r.get("released")), "/", len(ids))
