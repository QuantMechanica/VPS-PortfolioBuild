#!/usr/bin/env python3
"""v9 §7.0 — one-shot expedite of a named set of work-item rows, with a built-in undo.

Why this exists rather than `set_priority_track.py`: that controller is excellent and is reused
here in spirit, but its semantics are *"OWNER declares this EA a priority track"*. It blocks any row
whose EA is absent from `owner_priority_tracks.json`. Expediting 28 measurement rows spanning ~20
EAs through it would mean writing ~20 permanent registry entries that assert something untrue about
those EAs — precisely the leftover v9 §0.4 warns about: *eine Sofortmaßnahme, die im Bestand liegen
bleibt, verzerrt die Reihenfolge dauerhaft.*

So the mechanism is the same payload flag the claim order already honours, plus a distinct
`batch_expedite` marker that makes the intervention (a) visible, (b) exactly revertible, and
(c) impossible to mistake for an OWNER priority track later.

Discipline, per v9 §0.2, all of it enforced rather than intended:

* the caller supplies an expectations file naming every id with its **pre-image payload sha256**
* `BEGIN IMMEDIATE`, and every row is **re-read and revalidated inside the transaction** — status
  still pending, still unclaimed, payload sha still matching. A row that moved between planning and
  applying aborts the whole apply.
* the UPDATE is guarded (`AND status='pending' AND claimed_by IS NULL`) and the total rowcount must
  equal the id count exactly, or the transaction rolls back
* a journal is written with before/after payload hashes, and `--revert` consumes it

**Acceptance is not "priority set"** (v9 §0.3). Acceptance is that the rows are claimable against
the real claim predicate and are actually claimed — use `--verify` after the fact, which reports
row id, claim state and terminal.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
MARKER = "batch_expedite"
JOURNAL_SCHEMA = "qm.batch-expedite-journal/v1"
REASON = "v9-7.0-critical-path-2.3"


class ExpediteError(RuntimeError):
    pass


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def payload_sha256(payload_json: str | None) -> str:
    return hashlib.sha256((payload_json or "").encode("utf-8")).hexdigest()


def _mutation_lock(path: Path):
    from factory_mutation_lock import FactoryMutationLock

    return FactoryMutationLock(path, owner="expedite_batch_rows")


def load_expectations(path: Path) -> dict[str, dict[str, Any]]:
    doc = json.loads(path.read_text(encoding="utf-8"))
    rows = doc.get("rows")
    if not isinstance(rows, dict) or not rows:
        raise ExpediteError("expectations file carries no rows")
    for wid, exp in rows.items():
        for field in ("expected_status", "expected_payload_sha256"):
            if not exp.get(field):
                raise ExpediteError(f"{wid}: expectations missing {field}")
    return rows


def plan(conn: sqlite3.Connection, expectations: dict[str, dict[str, Any]]) -> dict[str, Any]:
    conn.row_factory = sqlite3.Row
    out: list[dict[str, Any]] = []
    blockers: list[str] = []
    for wid, exp in expectations.items():
        row = conn.execute(
            "SELECT id,ea_id,symbol,phase,status,claimed_by,payload_json FROM work_items WHERE id=?",
            (wid,)).fetchone()
        item: dict[str, Any] = {"work_item_id": wid}
        if row is None:
            item["blockers"] = ["row missing"]
        else:
            b: list[str] = []
            if row["status"] != exp["expected_status"]:
                b.append(f"status {row['status']!r} != {exp['expected_status']!r}")
            if row["claimed_by"] is not None:
                b.append(f"claimed_by {row['claimed_by']!r}")
            actual = payload_sha256(row["payload_json"])
            if actual != str(exp["expected_payload_sha256"]).lower():
                b.append("payload sha256 drifted")
            payload = json.loads(row["payload_json"] or "{}")
            if payload.get("priority_track") is True:
                b.append("priority_track already true")
            if payload.get("recovery_class"):
                b.append("recovery-class row")
            item.update({"ea_id": row["ea_id"], "symbol": row["symbol"], "phase": row["phase"],
                         "payload_sha256": actual, "blockers": b})
        blockers.extend(f"{wid}: {x}" for x in item.get("blockers") or [])
        out.append(item)
    return {"mode": "DRY_RUN", "at_utc": utc_now(), "rows": out,
            "count": len(out), "blockers": blockers,
            "status": "READY_FOR_APPLY" if not blockers else "BLOCKED"}


def apply(db: Path, expectations: dict[str, dict[str, Any]], journal_out: Path,
          lock_path: Path) -> dict[str, Any]:
    with _mutation_lock(lock_path):
        conn = sqlite3.connect(str(db), timeout=60)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("BEGIN IMMEDIATE")
            entries: list[dict[str, Any]] = []
            changed_total = 0
            for wid, exp in expectations.items():
                # Revalidation INSIDE the transaction. Planning read a snapshot; between then and
                # now a worker may have claimed the row. Trusting the plan here would be exactly
                # the "requeued is not delivery" failure in a different costume.
                row = conn.execute(
                    "SELECT id,status,claimed_by,payload_json FROM work_items WHERE id=?",
                    (wid,)).fetchone()
                if row is None:
                    raise ExpediteError(f"{wid}: row vanished between plan and apply")
                if row["status"] != exp["expected_status"]:
                    raise ExpediteError(f"{wid}: status moved to {row['status']!r}")
                if row["claimed_by"] is not None:
                    raise ExpediteError(f"{wid}: claimed by {row['claimed_by']!r} since planning")
                before = payload_sha256(row["payload_json"])
                if before != str(exp["expected_payload_sha256"]).lower():
                    raise ExpediteError(f"{wid}: payload changed since planning")
                payload = json.loads(row["payload_json"] or "{}")
                payload["priority_track"] = True
                payload[MARKER] = {"reason": REASON, "applied_at_utc": utc_now(),
                                   "pre_image_payload_sha256": before}
                new_json = json.dumps(payload, sort_keys=True)
                cur = conn.execute(
                    "UPDATE work_items SET payload_json=? WHERE id=? AND status='pending' "
                    "AND claimed_by IS NULL", (new_json, wid))
                changed_total += cur.rowcount
                entries.append({"work_item_id": wid, "before_payload_sha256": before,
                                "after_payload_sha256": payload_sha256(new_json)})
            if changed_total != len(expectations):
                raise ExpediteError(
                    f"rowcount assertion failed: {changed_total} != {len(expectations)}")
            journal = {"schema_version": JOURNAL_SCHEMA, "applied_at_utc": utc_now(),
                       "reason": REASON, "db": str(db), "entries": entries,
                       "changed_rows": changed_total}
            journal_out.parent.mkdir(parents=True, exist_ok=True)
            journal_out.write_text(json.dumps(journal, indent=1, sort_keys=True) + "\n",
                                   encoding="utf-8")
            conn.commit()
            return {"mode": "APPLY", "status": "APPLIED", "changed_rows": changed_total,
                    "journal": str(journal_out)}
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()


def revert(db: Path, journal_path: Path, lock_path: Path) -> dict[str, Any]:
    journal = json.loads(journal_path.read_text(encoding="utf-8"))
    entries = journal.get("entries") or []
    with _mutation_lock(lock_path):
        conn = sqlite3.connect(str(db), timeout=60)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("BEGIN IMMEDIATE")
            reverted = 0
            skipped: list[dict[str, str]] = []
            for e in entries:
                wid = e["work_item_id"]
                row = conn.execute("SELECT payload_json FROM work_items WHERE id=?",
                                   (wid,)).fetchone()
                if row is None:
                    skipped.append({"work_item_id": wid, "reason": "row missing"})
                    continue
                payload = json.loads(row["payload_json"] or "{}")
                marker = payload.get(MARKER)
                if not isinstance(marker, dict):
                    # Never strip a flag this run did not set. A row that lost the marker was
                    # touched by something else, and guessing would remove someone else's decision.
                    skipped.append({"work_item_id": wid, "reason": "marker absent; not ours"})
                    continue
                payload.pop(MARKER, None)
                payload.pop("priority_track", None)
                conn.execute("UPDATE work_items SET payload_json=? WHERE id=?",
                             (json.dumps(payload, sort_keys=True), wid))
                reverted += 1
            conn.commit()
            return {"mode": "REVERT", "reverted_rows": reverted, "skipped": skipped,
                    "journal": str(journal_path)}
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()


def verify(db: Path, journal_path: Path) -> dict[str, Any]:
    """v9 §0.3 acceptance: not 'priority set' but claimable AND actually claimed."""
    journal = json.loads(journal_path.read_text(encoding="utf-8"))
    ids = [e["work_item_id"] for e in journal.get("entries") or []]
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    try:
        states: list[dict[str, Any]] = []
        for wid in ids:
            row = conn.execute(
                "SELECT id,ea_id,symbol,status,claimed_by,verdict FROM work_items WHERE id=?",
                (wid,)).fetchone()
            if row is None:
                states.append({"work_item_id": wid, "state": "missing"})
                continue
            states.append({"work_item_id": wid, "ea_id": row["ea_id"], "symbol": row["symbol"],
                           "status": row["status"], "terminal": row["claimed_by"],
                           "verdict": row["verdict"]})
        counts: dict[str, int] = {}
        for s in states:
            counts[str(s.get("status") or s.get("state"))] = counts.get(
                str(s.get("status") or s.get("state")), 0) + 1
        claimed = [s for s in states if s.get("terminal")]
        return {"mode": "VERIFY", "rows": len(states), "by_status": counts,
                "claimed_now": [{"work_item_id": s["work_item_id"], "ea_id": s.get("ea_id"),
                                 "symbol": s.get("symbol"), "terminal": s.get("terminal")}
                                for s in claimed],
                "accepted": bool(claimed) or counts.get("done", 0) + counts.get("failed", 0) > 0}
    finally:
        conn.close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--mutation-lock", type=Path, default=DEFAULT_LOCK)
    ap.add_argument("--expectations", type=Path)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--journal-out", type=Path)
    ap.add_argument("--revert", type=Path)
    ap.add_argument("--verify", type=Path)
    args = ap.parse_args()

    if args.verify:
        print(json.dumps(verify(args.db, args.verify), indent=1))
        return 0
    if args.revert:
        print(json.dumps(revert(args.db, args.revert, args.mutation_lock), indent=1))
        return 0
    if not args.expectations:
        raise ExpediteError("--expectations is required")
    expectations = load_expectations(args.expectations)
    if args.apply:
        if not args.journal_out:
            raise ExpediteError("--apply requires --journal-out")
        conn = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True, timeout=30)
        try:
            pre = plan(conn, expectations)
        finally:
            conn.close()
        if pre["status"] != "READY_FOR_APPLY":
            print(json.dumps(pre, indent=1))
            raise ExpediteError("dry run is BLOCKED; refusing to apply")
        print(json.dumps(apply(args.db, expectations, args.journal_out, args.mutation_lock),
                         indent=1))
        return 0
    conn = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True, timeout=30)
    try:
        print(json.dumps(plan(conn, expectations), indent=1))
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
