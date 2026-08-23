"""Farm-DB schema hardening SH-1 and SH-3.

Authority: ``docs/ops/FARM_DB_SCHEMA_HARDENING_2026-08-23.md`` (OWNER-commissioned
2026-08-23).

**SH-1 — materialize the taxonomy.** ``work_items_clean`` (MNT-016) derives the public
status and taxonomy at *read* time. Measured 2026-08-23: 9,381 rows whose STORED status
contradicts their verdict and 50,883 rows with no stored taxonomy at all. A consumer that
does not install the TEMP view reads different numbers — two surfaces can query the same
database, disagree, and both be "right". This adds two stored columns, backfills them, and
keeps the view as an independent **validator**.

**SH-3 — reference integrity.** Not what the commission assumed. Measured, the declared
foreign keys do not describe how the columns are used:

* ``work_items.parent_task_id`` declares ``REFERENCES tasks(id)`` but is **polymorphic** —
  of 71 dangling values, 39 point at ``work_items`` (parent/child lineage), 14 at
  ``agent_tasks``, 18 at nothing;
* ``tasks.source_id`` declares ``REFERENCES sources(id)`` but holds **EA ids** such as
  ``QM5_12108``.

Switching ``PRAGMA foreign_keys=ON`` would therefore fail-closed the factory on the next
write of either shape — orphans are still being created (latest 2026-08-14). So SH-3 ships
as a **monitor** here, and the schema correction (typed columns, or dropping the misleading
declarations) needs its own OFF window.

Usage::

    python tools/strategy_farm/schema_hardening.py check          # read-only, both parts
    python tools/strategy_farm/schema_hardening.py migrate --db X # SH-1 on a copy first
    python tools/strategy_farm/schema_hardening.py migrate --apply
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
import sys
import time
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT / "tools" / "strategy_farm") not in sys.path:
    sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

from work_item_clean_view import clean_status, verdict_taxonomy  # noqa: E402

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
STORED_TAXONOMY = "verdict_taxonomy_stored"
STORED_STATUS = "clean_status_stored"
CHUNK = 5000


def _columns(con: sqlite3.Connection, table: str) -> set[str]:
    return {r[1] for r in con.execute(f"PRAGMA table_info({table})")}


def add_columns(con: sqlite3.Connection) -> list[str]:
    """Idempotent, additive, metadata-only. No existing column is touched."""
    have = _columns(con, "work_items")
    added = []
    for col in (STORED_TAXONOMY, STORED_STATUS):
        if col not in have:
            con.execute(f"ALTER TABLE work_items ADD COLUMN {col} TEXT")
            added.append(col)
    return added


def backfill(con: sqlite3.Connection, limit: int | None = None) -> dict:
    """Fill the stored columns from the same functions the view uses.

    Chunked so a live factory never waits on one long write lock. A row whose stored value
    already differs from the derived one is **reported, not silently rewritten** — that is
    a finding, not a formatting problem.
    """
    con.execute("PRAGMA busy_timeout=8000")
    rows = con.execute(
        f"SELECT id, status, verdict, {STORED_TAXONOMY}, {STORED_STATUS} FROM work_items"
    ).fetchall()
    todo, drift = [], []
    for wid, status, verdict, tax_stored, status_stored in rows:
        tax = verdict_taxonomy(status, verdict)
        st = clean_status(status, verdict)
        if tax_stored is None or status_stored is None:
            todo.append((tax, st, wid))
        elif tax_stored != tax or status_stored != st:
            drift.append({"id": wid, "stored": [tax_stored, status_stored],
                          "derived": [tax, st]})
    if limit:
        todo = todo[:limit]
    written = 0
    for i in range(0, len(todo), CHUNK):
        batch = todo[i:i + CHUNK]
        con.execute("BEGIN IMMEDIATE")
        con.executemany(
            f"UPDATE work_items SET {STORED_TAXONOMY}=?, {STORED_STATUS}=? WHERE id=?", batch)
        con.commit()
        written += len(batch)
        time.sleep(0.02)          # leave the write lock to the factory between chunks
    return {"rows": len(rows), "written": written, "drift": len(drift),
            "drift_sample": drift[:5]}


def validate(con: sqlite3.Connection) -> dict:
    """Stored vs derived. Any mismatch is a defect, not a rounding difference."""
    have = _columns(con, "work_items")
    if STORED_TAXONOMY not in have:
        return {"migrated": False}
    mism = Counter()
    missing = 0
    total = 0
    for status, verdict, tax_stored, status_stored in con.execute(
        f"SELECT status, verdict, {STORED_TAXONOMY}, {STORED_STATUS} FROM work_items"
    ):
        total += 1
        if tax_stored is None or status_stored is None:
            missing += 1
            continue
        if tax_stored != verdict_taxonomy(status, verdict):
            mism["taxonomy"] += 1
        if status_stored != clean_status(status, verdict):
            mism["status"] += 1
    return {"migrated": True, "rows": total, "unfilled": missing,
            "mismatch": dict(mism), "valid": not mism and missing == 0}


# ── SH-3 · reference integrity monitor ────────────────────────────────────────

def reference_integrity(con: sqlite3.Connection) -> dict:
    """Classify dangling references instead of enforcing a wrong contract."""
    con.row_factory = None
    viol = con.execute("PRAGMA foreign_key_check").fetchall()
    by_table = Counter((r[0], r[2]) for r in viol)

    wi_rowids = [r[1] for r in viol if r[0] == "work_items"]
    kinds = Counter()
    if wi_rowids:
        q = ",".join("?" * len(wi_rowids))
        for (pid,) in con.execute(
                f"SELECT parent_task_id FROM work_items WHERE rowid IN ({q})", wi_rowids):
            if con.execute("SELECT 1 FROM work_items WHERE id=?", (pid,)).fetchone():
                kinds["points_at_work_items"] += 1
            elif con.execute("SELECT 1 FROM agent_tasks WHERE id=?", (pid,)).fetchone():
                kinds["points_at_agent_tasks"] += 1
            else:
                kinds["points_at_nothing"] += 1

    task_rowids = [r[1] for r in viol if r[0] == "tasks"]
    ea_shaped = 0
    if task_rowids:
        q = ",".join("?" * len(task_rowids))
        for (sid,) in con.execute(
                f"SELECT source_id FROM tasks WHERE rowid IN ({q})", task_rowids):
            if isinstance(sid, str) and sid.startswith("QM5_"):
                ea_shaped += 1

    return {
        "violations": len(viol),
        "by_table": {f"{a}->{b}": n for (a, b), n in by_table.items()},
        "work_items_parent_task_id_is_polymorphic": dict(kinds),
        "tasks_source_id_holding_ea_ids": ea_shaped,
        "enforcement_on": bool(con.execute("PRAGMA foreign_keys").fetchone()[0]),
        "safe_to_enforce": False,
        "why": ("parent_task_id is used polymorphically (work_items | agent_tasks | none) "
                "and tasks.source_id holds EA ids, not source ids. Enforcing the declared "
                "keys would fail-closed the next write of either shape; orphans are still "
                "being created (latest 2026-08-14). Fix the declarations first."),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Farm-DB schema hardening SH-1 / SH-3")
    ap.add_argument("command", choices=("check", "migrate"))
    ap.add_argument("--db", default=str(DB))
    ap.add_argument("--apply", action="store_true",
                    help="migrate: actually write (default is a plan-only run)")
    ap.add_argument("--limit", type=int, default=None)
    args = ap.parse_args()

    con = sqlite3.connect(args.db)
    out: dict = {"db": args.db, "at": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()}

    if args.command == "check":
        out["sh1"] = validate(con)
        out["sh3"] = reference_integrity(con)
    else:
        have = _columns(con, "work_items")
        out["already_migrated"] = STORED_TAXONOMY in have
        if not args.apply:
            out["plan"] = "would add columns and backfill; re-run with --apply"
            out["sh1_before"] = validate(con)
        else:
            t0 = time.perf_counter()
            out["added_columns"] = add_columns(con)
            out["backfill"] = backfill(con, args.limit)
            out["seconds"] = round(time.perf_counter() - t0, 1)
            out["sh1_after"] = validate(con)
    con.close()
    print(json.dumps(out, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
