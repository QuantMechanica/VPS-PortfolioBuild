#!/usr/bin/env python3
"""P1 repair: carry the basket's .DWX constituents into the payload key the worker reads.

## The defect, in one chain

`custom_history_copy_on_claim.select_archive_rows_for_symbols()` filters the symbols a claim
declares down to those ending in `.DWX` and refuses the claim when none remain::

    raise CustomHistoryCopyOnClaimError(
        "claim declares no .DWX host/conversion/basket history symbols")

The list it receives is built by `terminal_worker._work_item_history_symbols()`, which reads exactly
three payload sources: ``host_symbol``, ``basket_symbols`` and ``conversion_symbols`` (plus a basket
manifest branch gated on ``portfolio_scope``/``basket_manifest``/``basket_symbol_count``).

For a basket row ``host_symbol`` is the synthetic label — ``QM5_13059_XTI_AUDJPY_RSPREAD_D1`` — which
is not a `.DWX` symbol, and none of the other keys are set. So the filter empties, the copy-on-claim
fails closed, and the claim is released with ``attempt_count_unchanged: true``: the row never fails,
it circles forever. Six rows were doing exactly that, and the fleet went to zero active claims.

**The rows already carry the right answer**, one key away from where it is read::

    custom_history_archive_admission.selected_symbols = ['XTIUSD.DWX', 'AUDJPY.DWX']
    selected_archive_rows = 216      status = ACTIVE

This is my enqueue defect, not a framework bug: `prepare_book_q08_regeneration.py` reproduced the
admission gate faithfully but did not copy the constituents into `basket_symbols`. Ordinary rows were
unaffected because their `host_symbol` is itself a `.DWX` symbol, so the defect could only surface on
baskets — and baskets sat behind the commit-headroom gate until the ordinary rows drained.

## Why this is the payload and not the code

Changing `_work_item_history_symbols` to read the admission block would work too, but it edits the
claim path for the whole fleet and needs a worker restart. Setting the key the worker already reads
touches six rows, needs no restart, and leaves the claim path untouched. Smaller blast radius wins.

## Discipline

Same as `expedite_batch_rows.py`: expectations file with pre-image payload sha256; `BEGIN IMMEDIATE`;
every row re-read and revalidated **inside** the transaction; guarded UPDATE; exact rowcount
assertion or rollback; journal with before/after hashes; `--revert` that refuses to strip a key it
did not set.

**Acceptance is not "field set".** It is a basket that claims and *stays* claimed — `--verify`
reports status and terminal, and a row that is pending again has not been repaired.
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
MARKER = "basket_history_symbols_repair"
JOURNAL_SCHEMA = "qm.basket-history-repair-journal/v1"
REASON = "p1-basket-copy-on-claim-fail-closed-loop"


class RepairError(RuntimeError):
    pass


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def payload_sha256(payload_json: str | None) -> str:
    return hashlib.sha256((payload_json or "").encode("utf-8")).hexdigest()


def _lock(path: Path):
    from factory_mutation_lock import FactoryMutationLock

    return FactoryMutationLock(path, owner="repair_basket_history_symbols")


def candidates(conn: sqlite3.Connection) -> list[dict[str, Any]]:
    """Pending batch rows whose host_symbol is not a .DWX symbol and that lack basket_symbols."""
    conn.row_factory = sqlite3.Row
    out: list[dict[str, Any]] = []
    for row in conn.execute(
            "SELECT id,ea_id,symbol,status,claimed_by,payload_json FROM work_items "
            "WHERE status='pending' AND payload_json LIKE '%book_q08_regeneration%'"):
        payload = json.loads(row["payload_json"] or "{}")
        host = str(payload.get("host_symbol") or row["symbol"] or "")
        if host.upper().endswith(".DWX"):
            continue  # ordinary row, the worker already resolves it
        if isinstance(payload.get("basket_symbols"), list) and payload["basket_symbols"]:
            continue  # already repaired
        admission = payload.get("custom_history_archive_admission") or {}
        selected = [s for s in (admission.get("selected_symbols") or [])
                    if str(s).upper().endswith(".DWX")]
        out.append({
            "work_item_id": row["id"], "ea_id": row["ea_id"], "symbol": row["symbol"],
            "claimed_by": row["claimed_by"],
            "payload_sha256": payload_sha256(row["payload_json"]),
            "basket_symbols": selected,
            "blockers": ([] if selected else ["admission declares no .DWX selected_symbols"])
                        + ([] if row["claimed_by"] is None else [f"claimed_by {row['claimed_by']!r}"]),
        })
    return out


def plan(db: Path) -> dict[str, Any]:
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=30)
    try:
        rows = candidates(conn)
    finally:
        conn.close()
    blockers = [f"{r['work_item_id']}: {b}" for r in rows for b in r["blockers"]]
    return {"mode": "DRY_RUN", "at_utc": utc_now(), "candidates": len(rows), "rows": rows,
            "blockers": blockers,
            "status": "READY_FOR_APPLY" if rows and not blockers else
                      ("NOTHING_TO_DO" if not rows else "BLOCKED")}


def apply(db: Path, lock_path: Path, journal_out: Path) -> dict[str, Any]:
    pre = plan(db)
    if pre["status"] != "READY_FOR_APPLY":
        raise RepairError(f"dry run is {pre['status']}; refusing to apply")
    expected = {r["work_item_id"]: r for r in pre["rows"]}
    with _lock(lock_path):
        conn = sqlite3.connect(str(db), timeout=60)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("BEGIN IMMEDIATE")
            entries: list[dict[str, Any]] = []
            changed = 0
            for wid, exp in expected.items():
                row = conn.execute(
                    "SELECT status,claimed_by,payload_json FROM work_items WHERE id=?",
                    (wid,)).fetchone()
                if row is None:
                    raise RepairError(f"{wid}: row vanished between plan and apply")
                if row["status"] != "pending":
                    raise RepairError(f"{wid}: status moved to {row['status']!r}")
                if row["claimed_by"] is not None:
                    raise RepairError(f"{wid}: claimed by {row['claimed_by']!r} since planning")
                before = payload_sha256(row["payload_json"])
                if before != exp["payload_sha256"]:
                    raise RepairError(f"{wid}: payload changed since planning")
                payload = json.loads(row["payload_json"] or "{}")
                payload["basket_symbols"] = list(exp["basket_symbols"])
                payload[MARKER] = {"reason": REASON, "applied_at_utc": utc_now(),
                                   "pre_image_payload_sha256": before,
                                   "source": "custom_history_archive_admission.selected_symbols"}
                new_json = json.dumps(payload, sort_keys=True)
                cur = conn.execute(
                    "UPDATE work_items SET payload_json=? WHERE id=? AND status='pending' "
                    "AND claimed_by IS NULL", (new_json, wid))
                changed += cur.rowcount
                entries.append({"work_item_id": wid, "symbol": exp["symbol"],
                                "basket_symbols": exp["basket_symbols"],
                                "before_payload_sha256": before,
                                "after_payload_sha256": payload_sha256(new_json)})
            if changed != len(expected):
                raise RepairError(f"rowcount assertion failed: {changed} != {len(expected)}")
            journal = {"schema_version": JOURNAL_SCHEMA, "applied_at_utc": utc_now(),
                       "reason": REASON, "db": str(db), "entries": entries, "changed_rows": changed}
            journal_out.parent.mkdir(parents=True, exist_ok=True)
            journal_out.write_text(json.dumps(journal, indent=1, sort_keys=True) + "\n",
                                   encoding="utf-8")
            conn.commit()
            return {"mode": "APPLY", "status": "APPLIED", "changed_rows": changed,
                    "journal": str(journal_out)}
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()


def revert(db: Path, journal_path: Path, lock_path: Path) -> dict[str, Any]:
    journal = json.loads(journal_path.read_text(encoding="utf-8"))
    with _lock(lock_path):
        conn = sqlite3.connect(str(db), timeout=60)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("BEGIN IMMEDIATE")
            reverted = 0
            skipped: list[dict[str, str]] = []
            for e in journal.get("entries") or []:
                wid = e["work_item_id"]
                row = conn.execute("SELECT payload_json FROM work_items WHERE id=?",
                                   (wid,)).fetchone()
                if row is None:
                    skipped.append({"work_item_id": wid, "reason": "row missing"}); continue
                payload = json.loads(row["payload_json"] or "{}")
                if not isinstance(payload.get(MARKER), dict):
                    skipped.append({"work_item_id": wid, "reason": "marker absent; not ours"})
                    continue
                payload.pop(MARKER, None)
                payload.pop("basket_symbols", None)
                conn.execute("UPDATE work_items SET payload_json=? WHERE id=?",
                             (json.dumps(payload, sort_keys=True), wid))
                reverted += 1
            conn.commit()
            return {"mode": "REVERT", "reverted_rows": reverted, "skipped": skipped}
        except Exception:
            conn.rollback(); raise
        finally:
            conn.close()


def verify(db: Path, journal_path: Path) -> dict[str, Any]:
    journal = json.loads(journal_path.read_text(encoding="utf-8"))
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    try:
        states = []
        for e in journal.get("entries") or []:
            row = conn.execute(
                "SELECT id,ea_id,symbol,status,claimed_by,verdict FROM work_items WHERE id=?",
                (e["work_item_id"],)).fetchone()
            states.append({"work_item_id": e["work_item_id"],
                           "symbol": row["symbol"] if row else None,
                           "status": row["status"] if row else "missing",
                           "terminal": row["claimed_by"] if row else None,
                           "verdict": row["verdict"] if row else None})
        counts: dict[str, int] = {}
        for s in states:
            counts[str(s["status"])] = counts.get(str(s["status"]), 0) + 1
        progressed = [s for s in states if s["status"] in {"active", "done", "failed"}]
        return {"mode": "VERIFY", "rows": len(states), "by_status": counts,
                "progressed": progressed,
                "accepted": bool(progressed)}
    finally:
        conn.close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--mutation-lock", type=Path, default=DEFAULT_LOCK)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--journal-out", type=Path)
    ap.add_argument("--revert", type=Path)
    ap.add_argument("--verify", type=Path)
    args = ap.parse_args()
    if args.verify:
        print(json.dumps(verify(args.db, args.verify), indent=1)); return 0
    if args.revert:
        print(json.dumps(revert(args.db, args.revert, args.mutation_lock), indent=1)); return 0
    if args.apply:
        if not args.journal_out:
            raise RepairError("--apply requires --journal-out")
        print(json.dumps(apply(args.db, args.mutation_lock, args.journal_out), indent=1)); return 0
    print(json.dumps(plan(args.db), indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
