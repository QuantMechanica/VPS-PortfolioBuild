#!/usr/bin/env python3
"""QuantMechanica - one-shot verdict_reason backfill (WP-3, gate-repair programme).

`verdict_reason` is the canonical key every reason survey reads. Historically the
terminal write paths only stamped a sibling key (`final_failure`, `prior_failure`,
`transient_infra_signature`) and left `verdict_reason` NULL — which is how the
summary_missing_retries_exhausted class (~44k rows, the factory's single largest
failure mode) stayed invisible to every reason histogram. WP-3's write-time fix
(`farmctl._ensure_verdict_reason`) stops NEW rows going NULL; this script backfills
the historical ones.

For each row with a settled (terminal) verdict and a NULL/empty `verdict_reason`
but a populated sibling key, it copies the sibling in the ratified fallback order
`verdict_reason -> final_failure -> prior_failure -> transient_infra_signature`.
Only `payload_json.verdict_reason` is touched; every other key and column (incl.
`updated_at`) is left byte-for-byte unchanged, so the operation is exactly
reversible from the snapshot.

Safety:
  - --dry-run is the DEFAULT. Nothing is written without --apply.
  - --apply writes a timestamped snapshot (id + original payload_json) under
    D:/QM/reports/state/ BEFORE the first row is touched, then applies.
  - --revert <snapshot> restores every row in that snapshot to its exact prior
    payload_json.
  - Inspection reads the DB read-only (mode=ro). Only --apply / --revert open a
    writable connection.

Factory must be OFF while applying (no concurrent writers). Backfill/revert guard
each UPDATE on the exact expected prior payload, so a row changed out from under
the snapshot is skipped, never clobbered.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
import sys
from collections import Counter
from pathlib import Path
from typing import Any

DEFAULT_DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
SNAPSHOT_DIR = Path("D:/QM/reports/state")

# Fallback order, ratified in the WP-3 plan. Mirrors farmctl._ensure_verdict_reason
# so the write-time fix and this backfill can never disagree.
SIBLING_KEYS = ("final_failure", "prior_failure", "transient_infra_signature")

# A "terminal" verdict = a settled row that has already been graded. Rows that are
# pending/active carry verdict NULL by design and are in flight — never backfill them.
TERMINAL_SQL = (
    "status IN ('done','failed') AND verdict IS NOT NULL AND TRIM(verdict) <> ''"
)


def _connect_ro(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def _connect_rw(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(str(db))
    conn.row_factory = sqlite3.Row
    return conn


def _nonempty_str(value: Any) -> str | None:
    if isinstance(value, str) and value.strip():
        return value
    return None


def _chosen_reason(payload: dict[str, Any]) -> tuple[str, str] | None:
    """Return (source_key, reason) for a row needing backfill, else None."""
    if _nonempty_str(payload.get("verdict_reason")) is not None:
        return None  # already has a canonical reason
    for key in SIBLING_KEYS:
        val = _nonempty_str(payload.get(key))
        if val is not None:
            return key, val
    return None


def _iter_candidates(conn: sqlite3.Connection, limit: int | None):
    """Yield (id, phase, verdict, payload_dict, payload_text, source_key, reason)."""
    sql = f"SELECT id, phase, verdict, payload_json FROM work_items WHERE {TERMINAL_SQL}"
    count = 0
    for row in conn.execute(sql):
        text = row["payload_json"]
        if not text:
            continue
        try:
            payload = json.loads(text)
        except (json.JSONDecodeError, TypeError):
            continue
        if not isinstance(payload, dict):
            continue
        picked = _chosen_reason(payload)
        if picked is None:
            continue
        source_key, reason = picked
        yield row["id"], row["phase"], row["verdict"], payload, text, source_key, reason
        count += 1
        if limit is not None and count >= limit:
            break


def _report(rows: list[tuple]) -> None:
    per_phase: Counter = Counter()
    per_phase_source: Counter = Counter()
    for _id, phase, _verdict, _payload, _text, source_key, _reason in rows:
        per_phase[phase] += 1
        per_phase_source[(phase, source_key)] += 1
    print(f"\ncandidate rows (terminal, NULL verdict_reason, sibling present): {len(rows)}")
    print("\nper phase:")
    for phase, n in sorted(per_phase.items(), key=lambda kv: (-kv[1], str(kv[0]))):
        print(f"  {str(phase):16} {n}")
    print("\nper (phase, source key):")
    for (phase, src), n in sorted(per_phase_source.items(), key=lambda kv: (str(kv[0][0]), -kv[1])):
        print(f"  {str(phase):16} {src:28} {n}")


def _write_snapshot(rows: list[tuple], db: Path, stamp: str) -> Path:
    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    snap_path = SNAPSHOT_DIR / f"verdict_reason_backfill_{stamp}.json"
    entries = [
        {
            "id": _id,
            "phase": phase,
            "verdict": verdict,
            "source_key": source_key,
            "new_verdict_reason": reason,
            "payload_json": text,  # exact prior text -> exact revert
        }
        for _id, phase, verdict, _payload, text, source_key, reason in rows
    ]
    snap = {
        "tool": "backfill_verdict_reason.py",
        "db": str(db),
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "fallback_order": ("verdict_reason", *SIBLING_KEYS),
        "row_count": len(entries),
        "entries": entries,
    }
    snap_path.write_text(json.dumps(snap, indent=2), encoding="utf-8")
    return snap_path


def _apply(conn: sqlite3.Connection, rows: list[tuple]) -> tuple[int, int]:
    """Set verdict_reason from the chosen sibling. Guard on exact prior payload."""
    changed = 0
    skipped = 0
    for _id, _phase, _verdict, payload, text, _source_key, reason in rows:
        updated = dict(payload)
        updated["verdict_reason"] = reason
        new_text = json.dumps(updated, sort_keys=True)
        cur = conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id=? AND payload_json=?",
            (new_text, _id, text),
        )
        if cur.rowcount == 1:
            changed += 1
        else:
            skipped += 1  # row changed since inspection — never clobber
    conn.commit()
    return changed, skipped


def _revert(conn: sqlite3.Connection, snap_path: Path) -> tuple[int, int]:
    snap = json.loads(snap_path.read_text(encoding="utf-8"))
    restored = 0
    skipped = 0
    for entry in snap.get("entries", []):
        _id = entry["id"]
        prior = entry["payload_json"]
        payload = json.loads(prior)
        payload["verdict_reason"] = entry["new_verdict_reason"]
        expected_after = json.dumps(payload, sort_keys=True)
        # Only revert a row still carrying exactly the value we wrote.
        cur = conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id=? AND payload_json=?",
            (prior, _id, expected_after),
        )
        if cur.rowcount == 1:
            restored += 1
        else:
            skipped += 1
    conn.commit()
    return restored, skipped


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Backfill work_items.payload_json.verdict_reason from sibling keys.")
    ap.add_argument("--db", type=Path, default=DEFAULT_DB, help="farm_state.sqlite path")
    ap.add_argument("--apply", action="store_true", help="write changes (default: dry-run)")
    ap.add_argument("--dry-run", action="store_true", help="explicit dry-run (default behaviour)")
    ap.add_argument("--revert", type=Path, metavar="SNAPSHOT", help="restore rows from a snapshot json")
    ap.add_argument("--limit", type=int, default=None, help="cap candidate rows (canary)")
    args = ap.parse_args(argv)

    if args.apply and args.revert:
        ap.error("--apply and --revert are mutually exclusive")

    if not args.db.exists():
        print(f"ERROR: DB not found: {args.db}", file=sys.stderr)
        return 2

    if args.revert:
        if not args.revert.exists():
            print(f"ERROR: snapshot not found: {args.revert}", file=sys.stderr)
            return 2
        conn = _connect_rw(args.db)
        try:
            restored, skipped = _revert(conn, args.revert)
        finally:
            conn.close()
        print(f"revert: restored={restored} skipped(already_reverted_or_changed)={skipped}")
        return 0

    # Inspect read-only.
    ro = _connect_ro(args.db)
    try:
        rows = list(_iter_candidates(ro, args.limit))
    finally:
        ro.close()

    _report(rows)

    if not args.apply:
        print("\nDRY-RUN (default). No rows written. Re-run with --apply to write.")
        return 0

    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    snap_path = _write_snapshot(rows, args.db, stamp)
    print(f"\nsnapshot written (revert with --revert): {snap_path}")

    conn = _connect_rw(args.db)
    try:
        changed, skipped = _apply(conn, rows)
    finally:
        conn.close()
    print(f"apply: changed={changed} skipped(row_changed_since_inspection)={skipped}")
    print(f"revert command: python backfill_verdict_reason.py --revert \"{snap_path}\"")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
