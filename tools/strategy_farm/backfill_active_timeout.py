#!/usr/bin/env python3
"""QuantMechanica - one-shot ACTIVE_TIMEOUT verdict backfill (WP-4, gate-repair programme).

The active-age reaper in farmctl (`_detect_active_age_timeout`) historically stamped
a killed work item with `verdict='FAIL'` — recording a harness timeout as a strategy
rejection. WP-4's write-time fix maps the reap to `verdict='INFRA_FAIL'` (the
`verdict_reason` stays 'ACTIVE_TIMEOUT'); this script backfills the historical rows the
old code already froze.

Why it matters: a reaped FAIL inflates the apparent strategy-rejection rate AND freezes
the (ea, symbol) pair — the stranded-INFRA sweep (`sweep_enqueue_built_eas.py` Part 2)
only requeues rows with `verdict='INFRA_FAIL'`, so a FAIL-labelled timeout is never
retried. Reclassifying it to INFRA_FAIL makes those pairs requeue-eligible again.

Selection signature (authoritative): `verdict='FAIL'` AND
`payload_json.verdict_reason == 'ACTIVE_TIMEOUT'`. This is the exact key/value the reaper
writes; it is the canonical reason location (NOT `reason` and NOT
`ea_metrics.detail_json`). Rows that merely list ACTIVE_TIMEOUT inside `reason_classes`
while carrying a *different* terminal `verdict_reason` are a real later verdict and are
deliberately left untouched (they are reported, never mutated).

Mutation: `verdict` FAIL -> INFRA_FAIL only. `payload_json` (incl. verdict_reason and
reason_classes) and `updated_at` are left byte-for-byte unchanged, so the kill-time
evidence and the stranded-sweep's oldest-first ordering are preserved and the operation
is exactly reversible from the snapshot.

Safety:
  - --dry-run is the DEFAULT. Nothing is written without --apply.
  - --apply writes a timestamped snapshot (id + prior verdict + prior payload_json) under
    D:/QM/reports/state/ BEFORE the first row is touched, then applies.
  - --revert <snapshot> restores every row in that snapshot to verdict='FAIL'.
  - Inspection reads the DB read-only (mode=ro). Only --apply / --revert open a writable
    connection.

Factory must be OFF while applying (no concurrent writers). Each UPDATE is guarded on the
exact expected prior state, so a row changed out from under the snapshot is skipped,
never clobbered.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

DEFAULT_DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
SNAPSHOT_DIR = Path("D:/QM/reports/state")

# The reaper's canonical stamp. Matched case-insensitively though the writer is uppercase.
ACTIVE_TIMEOUT = "ACTIVE_TIMEOUT"
OLD_VERDICT = "FAIL"
NEW_VERDICT = "INFRA_FAIL"


def _connect_ro(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def _connect_rw(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(str(db))
    conn.row_factory = sqlite3.Row
    return conn


def _verdict_reason(payload: dict[str, Any]) -> str:
    return str(payload.get("verdict_reason") or "")


def _iter_candidates(conn: sqlite3.Connection, limit: int | None):
    """Yield (id, phase, ea_id, symbol, payload_text) for reaper-killed FAIL rows.

    A candidate is verdict='FAIL' with payload_json.verdict_reason == 'ACTIVE_TIMEOUT'.
    """
    sql = (
        "SELECT id, phase, ea_id, symbol, payload_json "
        "FROM work_items WHERE verdict=?"
    )
    count = 0
    for row in conn.execute(sql, (OLD_VERDICT,)):
        text = row["payload_json"]
        if not text:
            continue
        try:
            payload = json.loads(text)
        except (json.JSONDecodeError, TypeError):
            continue
        if not isinstance(payload, dict):
            continue
        if _verdict_reason(payload).upper() != ACTIVE_TIMEOUT:
            continue
        yield row["id"], row["phase"], row["ea_id"], row["symbol"], text
        count += 1
        if limit is not None and count >= limit:
            break


def _reason_classes_only(conn: sqlite3.Connection) -> list[tuple]:
    """FAIL rows with ACTIVE_TIMEOUT only in reason_classes, a *different* verdict_reason.

    Reported for transparency; NEVER mutated (their verdict_reason is a real verdict).
    """
    out: list[tuple] = []
    for row in conn.execute(
        "SELECT id, phase, ea_id, symbol, payload_json FROM work_items WHERE verdict=?",
        (OLD_VERDICT,),
    ):
        text = row["payload_json"]
        if not text:
            continue
        try:
            payload = json.loads(text)
        except (json.JSONDecodeError, TypeError):
            continue
        if not isinstance(payload, dict):
            continue
        rc = [str(x).upper() for x in (payload.get("reason_classes") or [])]
        if ACTIVE_TIMEOUT in rc and _verdict_reason(payload).upper() != ACTIVE_TIMEOUT:
            out.append((row["id"], row["phase"], _verdict_reason(payload) or "<empty>"))
    return out


def _report(rows: list[tuple], reason_classes_only: list[tuple]) -> None:
    per_phase: Counter = Counter()
    pairs_per_phase: dict[str, set] = defaultdict(set)
    for _id, phase, ea_id, symbol, _text in rows:
        per_phase[phase] += 1
        pairs_per_phase[str(phase)].add((ea_id, symbol))
    print(f"\ncandidate rows (verdict='FAIL' AND verdict_reason='ACTIVE_TIMEOUT'): {len(rows)}")
    print("\nper phase (rows / distinct ea+symbol pairs):")
    for phase, n in sorted(per_phase.items(), key=lambda kv: (-kv[1], str(kv[0]))):
        print(f"  {str(phase):8} rows={n:5}  pairs={len(pairs_per_phase[str(phase)])}")

    print(f"\nNOT touched -- FAIL rows with ACTIVE_TIMEOUT only in reason_classes "
          f"(a different terminal verdict_reason): {len(reason_classes_only)}")
    rc_phase: Counter = Counter(p for _i, p, _r in reason_classes_only)
    rc_reason: Counter = Counter(r for _i, _p, r in reason_classes_only)
    if reason_classes_only:
        print("  per phase:", dict(rc_phase))
        print("  their actual verdict_reason values:")
        for reason, n in rc_reason.most_common():
            print(f"    {n:4}  {reason}")


def _write_snapshot(rows: list[tuple], db: Path, stamp: str) -> Path:
    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    snap_path = SNAPSHOT_DIR / f"active_timeout_backfill_{stamp}.json"
    entries = [
        {
            "id": _id,
            "phase": phase,
            "ea_id": ea_id,
            "symbol": symbol,
            "prior_verdict": OLD_VERDICT,
            "new_verdict": NEW_VERDICT,
            "payload_json": text,  # unchanged by apply; recorded for an exact guard
        }
        for _id, phase, ea_id, symbol, text in rows
    ]
    snap = {
        "tool": "backfill_active_timeout.py",
        "db": str(db),
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "selection": "verdict='FAIL' AND payload_json.verdict_reason='ACTIVE_TIMEOUT'",
        "mutation": f"verdict {OLD_VERDICT} -> {NEW_VERDICT} (payload_json / updated_at unchanged)",
        "row_count": len(entries),
        "entries": entries,
    }
    snap_path.write_text(json.dumps(snap, indent=2), encoding="utf-8")
    return snap_path


def _apply(conn: sqlite3.Connection, rows: list[tuple]) -> tuple[int, int]:
    """Flip verdict FAIL -> INFRA_FAIL. Guard on prior verdict + exact prior payload."""
    changed = 0
    skipped = 0
    for _id, _phase, _ea, _sym, text in rows:
        cur = conn.execute(
            "UPDATE work_items SET verdict=? WHERE id=? AND verdict=? AND payload_json=?",
            (NEW_VERDICT, _id, OLD_VERDICT, text),
        )
        if cur.rowcount == 1:
            changed += 1
        else:
            skipped += 1  # row changed since inspection -> never clobber
    conn.commit()
    return changed, skipped


def _revert(conn: sqlite3.Connection, snap_path: Path) -> tuple[int, int]:
    snap = json.loads(snap_path.read_text(encoding="utf-8"))
    restored = 0
    skipped = 0
    for entry in snap.get("entries", []):
        _id = entry["id"]
        prior_verdict = entry.get("prior_verdict", OLD_VERDICT)
        new_verdict = entry.get("new_verdict", NEW_VERDICT)
        prior_payload = entry["payload_json"]
        # Only revert a row still carrying exactly what we wrote (INFRA_FAIL + same payload).
        cur = conn.execute(
            "UPDATE work_items SET verdict=? WHERE id=? AND verdict=? AND payload_json=?",
            (prior_verdict, _id, new_verdict, prior_payload),
        )
        if cur.rowcount == 1:
            restored += 1
        else:
            skipped += 1
    conn.commit()
    return restored, skipped


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Reclassify reaper ACTIVE_TIMEOUT kills from strategy FAIL to INFRA_FAIL."
    )
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
        reason_classes_only = _reason_classes_only(ro)
    finally:
        ro.close()

    _report(rows, reason_classes_only)

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
    print(f"revert command: python backfill_active_timeout.py --revert \"{snap_path}\"")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
