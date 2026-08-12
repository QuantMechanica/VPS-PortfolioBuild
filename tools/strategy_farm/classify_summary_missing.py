#!/usr/bin/env python3
"""Reclassify the Q02 `summary_missing_retries_exhausted` graveyard IN PLACE.

Census rank 1 (docs/ops/evidence/2026-07-27_factory_loose_ends_census.md): a single
`summary_missing_retries_exhausted` label carried under `verdict=INFRA_FAIL` dominates
every factory failure statistic (43,736 Q02 rows on 2026-07-27, 68% of all Q02 rows).
It conflates a terminal-side fault, a deterministic EA/build defect, and a genuine
transient into one bucket, so historical evidence production overwhelms strategy
measurement in every count.

This tool splits that population into disjoint, ACTIONABLE classes using ONLY row-bound
evidence — each row's own payload, its `(ea_id, symbol)` key resolved against the same
work_items table, and its current on-disk set file / registry status. For ~99% of these
historical rows the run log and report root have been purged by the log/cache pruners
(measured 1.1% logs, 1.2% report roots survive), so the DB join is the only surviving
evidence; the forward classifier in farmctl.classify_summary_missing_run reads the fresh
log instead, and both emit the SAME action vocabulary (farmctl.SM_CLASS_*).

Disjoint cascade (first match wins), measured 2026-07-27:

    LOG_BOMB          ~0  DETERMINISTIC  genuine journal-flood marker ONLY (verdict_reason=
                          LOG_BOMB / reason_classes / log_bomb_journal_*). The former bare
                          attempt_count>=99 trigger was removed 2026-07-27: it mislabelled
                          4,236 summary-missing transport rows carrying NO genuine marker,
                          which now re-bucket to SUPERSEDED / NEVER_WORKED / IN_FLIGHT below
                          (docs/ops/evidence/2026-07-27_logbomb_family_diagnosis.md).
    SUPERSEDED     26651  SUPERSEDED     the (ea,symbol) pair already has a real Q02 verdict
    INPUT_MISSING    181  DETERMINISTIC  set file absent or EA registry status != active
    IN_FLIGHT       4517  IN_FLIGHT      the pair still has a pending/active successor
    TRANSIENT_TOKEN   33  TRANSIENT      verdict_reason carries an explicit transient token
    NEVER_WORKED    8118  DETERMINISTIC  pair has ONLY ever INFRA_FAILed (the "119/119" cohort)

WHAT THIS TOOL WRITES: only three payload keys — `failure_class` (action axis),
`failure_subclass` (specific cause) and `failure_class_evidence`. It does NOT touch
`verdict`, `status`, `attempt_count`, `evidence_path`, `claimed_by` or `updated_at`, and
it NEVER requeues a row. Reclassification is therefore invisible to the claim path and
has zero throughput/capacity impact — it only makes the honest cause visible to reason
histograms, dashboards and the new health detectors. Promoting the DETERMINISTIC class's
`verdict` from INFRA_FAIL to the non-retryable INVALID (the going-forward behaviour) is a
separate, OWNER-gated decision and is deliberately NOT done here.

Safety (mirrors backfill_verdict_reason.py, ratified WP-3 pattern):
  * --dry-run is the DEFAULT. Nothing is written without --apply.
  * --apply writes a timestamped reversible snapshot (id + exact prior payload_json)
    under D:/QM/reports/state/ BEFORE the first row is touched.
  * Each UPDATE is guarded on the EXACT expected prior payload_json, so a row a worker
    changed out from under the snapshot is skipped, never clobbered.
  * --revert <snapshot> restores every row to its exact prior payload_json.
  * Inspection is read-only (mode=ro). Apply commits in bounded batches so it never
    holds one long write lock against the live fleet.

The apply path should still run in a quiescent window; the guard makes a concurrent
write safe (skip, never clobber) but a long contended write wastes claim-lock time.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import re
import sqlite3
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REGISTRY = Path(r"C:\QM\repo\framework\registry\ea_id_registry.csv")
SNAPSHOT_DIR = Path(r"D:\QM\reports\state")

# The graveyard tag the terminal worker stamps at summary-missing exhaustion.
GRAVEYARD_TAG = "summary_missing_retries_exhausted"

# Action classes — kept identical to farmctl.SM_CLASS_* so the historical reclassifier
# and the forward classifier can never disagree on vocabulary.
CLASS_DETERMINISTIC = "DETERMINISTIC_NO_SUMMARY"
CLASS_TRANSIENT = "TRANSIENT"
CLASS_SUPERSEDED = "SUPERSEDED"
CLASS_IN_FLIGHT = "IN_FLIGHT"

# NOTE: a bare attempt_count>=99 was formerly treated as log_bomb here. It is NOT
# log-bomb-specific (the older exhaustion/poison paths stamped 99 for ~8 different causes),
# and it mislabelled 4,236 summary-missing transport rows that carried no genuine journal
# marker. _has_log_bomb now requires a genuine kill marker; the sentinel is gone.
# See docs/ops/evidence/2026-07-27_logbomb_family_diagnosis.md.

# Explicit transient run_smoke tokens (kept in sync with farmctl.SM_TRANSIENT_TOKENS;
# INCOMPLETE_RUNS is intentionally excluded — it discriminates nothing).
TRANSIENT_TOKENS = (
    "ACTIVE_TIMEOUT", "NO_HISTORY", "METATESTER_HUNG", "NO_REAL_TICKS", "TIMEOUT",
    "LAUNCH_FAULT",
)


def _connect_ro(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    return conn


def _ea_int(ea_id: Any) -> int | None:
    m = re.fullmatch(r"(?:QM5_)?(\d+)", str(ea_id).strip())
    return int(m.group(1)) if m else None


def _load_registry_status(path: Path) -> dict[int, str]:
    reg: dict[int, str] = {}
    try:
        fh = path.open(encoding="utf-8-sig")
    except OSError:
        return reg
    with fh:
        for row in csv.DictReader(fh):
            num = _ea_int(row.get("ea_id") or "")
            if num is not None:
                reg[num] = (row.get("status") or "").strip().lower()
    return reg


def _has_log_bomb(payload: dict[str, Any], attempt_count: int) -> bool:
    # A genuine journal-flood kill stamps a distinctive record (terminal_worker.py:2595-2633):
    # verdict_reason='LOG_BOMB', reason_classes+=['LOG_BOMB'], log_bomb_journal_gb=<size>.
    # attempt_count>=99 ALONE is NOT one of those markers, so it is deliberately no longer a
    # trigger (see the census note above): require a genuine marker and let every other
    # summary-missing row fall through to the honest SUPERSEDED / never_worked / IN_FLIGHT
    # rules. `attempt_count` is retained in the signature for call-site parity only.
    if str(payload.get("verdict_reason") or "").upper() == "LOG_BOMB":
        return True
    if any(str(x).upper() == "LOG_BOMB" for x in (payload.get("reason_classes") or [])):
        return True
    return any(str(k).startswith("log_bomb_journal") for k in payload)


def _classify_row(
    payload: dict[str, Any],
    attempt_count: int,
    ea_id: str,
    symbol: str,
    setfile_path: str | None,
    *,
    resolved_pairs: set[tuple[str, str]],
    open_pairs: set[tuple[str, str]],
    registry_status: dict[int, str],
    setfile_cache: dict[str, bool],
) -> tuple[str, str]:
    """Return (failure_class, failure_subclass) for one graveyard row. Disjoint cascade."""
    if _has_log_bomb(payload, attempt_count):
        return CLASS_DETERMINISTIC, "log_bomb"
    key = (ea_id, symbol)
    if key in resolved_pairs:
        return CLASS_SUPERSEDED, "pair_has_verdict"
    status = registry_status.get(_ea_int(ea_id))
    sf_ok = False
    if setfile_path:
        if setfile_path not in setfile_cache:
            setfile_cache[setfile_path] = os.path.isfile(setfile_path)
        sf_ok = setfile_cache[setfile_path]
    if status != "active" or not sf_ok:
        return CLASS_DETERMINISTIC, "input_missing"
    if key in open_pairs:
        return CLASS_IN_FLIGHT, "pair_open"
    vr = str(payload.get("verdict_reason") or "").upper()
    if any(tok in vr for tok in TRANSIENT_TOKENS):
        return CLASS_TRANSIENT, "transient_token"
    return CLASS_DETERMINISTIC, "never_worked"


def _build_pair_maps(conn: sqlite3.Connection, phase: str) -> tuple[set, set]:
    """resolved_pairs = pair has any phase verdict that is not NULL and not INFRA_FAIL;
    open_pairs = pair has a pending/active row in the phase."""
    resolved: set[tuple[str, str]] = set()
    open_pairs: set[tuple[str, str]] = set()
    for r in conn.execute(
        "SELECT ea_id, symbol, status, verdict FROM work_items WHERE phase=?", (phase,)
    ):
        key = (r["ea_id"], r["symbol"])
        if r["verdict"] and r["verdict"] != "INFRA_FAIL":
            resolved.add(key)
        if r["status"] in ("pending", "active"):
            open_pairs.add(key)
    return resolved, open_pairs


def _iter_graveyard(conn: sqlite3.Connection, phase: str):
    sql = (
        "SELECT id, ea_id, symbol, attempt_count, setfile_path, payload_json "
        "FROM work_items WHERE phase=? AND verdict='INFRA_FAIL' "
        "AND json_extract(payload_json, '$.final_failure')=?"
    )
    for row in conn.execute(sql, (phase, GRAVEYARD_TAG)):
        text = row["payload_json"]
        if not text:
            continue
        try:
            payload = json.loads(text)
        except (json.JSONDecodeError, TypeError):
            continue
        if not isinstance(payload, dict):
            continue
        yield row, payload, text


def _plan(db: Path, phase: str, registry: Path, limit: int | None) -> dict[str, Any]:
    registry_status = _load_registry_status(registry)
    conn = _connect_ro(db)
    try:
        resolved, open_pairs = _build_pair_maps(conn, phase)
        setfile_cache: dict[str, bool] = {}
        by_class: Counter = Counter()
        by_subclass: Counter = Counter()
        already: Counter = Counter()
        rows: list[dict[str, Any]] = []
        for row, payload, text in _iter_graveyard(conn, phase):
            cls, sub = _classify_row(
                payload, int(row["attempt_count"] or 0), row["ea_id"], row["symbol"],
                row["setfile_path"], resolved_pairs=resolved, open_pairs=open_pairs,
                registry_status=registry_status, setfile_cache=setfile_cache,
            )
            by_class[cls] += 1
            by_subclass[sub] += 1
            existing = payload.get("failure_class")
            needs_write = existing != cls or payload.get("failure_subclass") != sub
            if isinstance(existing, str) and existing:
                already[existing] += 1
            if needs_write:
                rows.append({
                    "id": row["id"], "prior_text": text, "payload": payload,
                    "failure_class": cls, "failure_subclass": sub,
                })
                if limit is not None and len(rows) >= limit:
                    break
    finally:
        conn.close()
    return {
        "tool": "classify_summary_missing.py",
        "db": str(db),
        "phase": phase,
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "population": sum(by_class.values()),
        "by_class": dict(by_class),
        "by_subclass": dict(by_subclass),
        "already_classified": dict(already),
        "rows_needing_write": len(rows),
        "rows": rows,
    }


def _print_plan(plan: dict[str, Any]) -> None:
    print(f"summary-missing reclassification  (phase={plan['phase']})")
    print(f"population (verdict=INFRA_FAIL, final_failure={GRAVEYARD_TAG!r}): {plan['population']}")
    print("\naction class:")
    for k, n in sorted(plan["by_class"].items(), key=lambda kv: -kv[1]):
        pct = 100 * n / plan["population"] if plan["population"] else 0
        print(f"  {k:24} {n:7} ({pct:.1f}%)")
    print("\nsubclass:")
    for k, n in sorted(plan["by_subclass"].items(), key=lambda kv: -kv[1]):
        print(f"  {k:20} {n:7}")
    det = plan["by_class"].get(CLASS_DETERMINISTIC, 0)
    print(f"\nDETERMINISTIC (non-retryable) = {det}   "
          f"SUPERSEDED = {plan['by_class'].get(CLASS_SUPERSEDED, 0)}   "
          f"IN_FLIGHT = {plan['by_class'].get(CLASS_IN_FLIGHT, 0)}   "
          f"TRANSIENT = {plan['by_class'].get(CLASS_TRANSIENT, 0)}")
    print(f"rows needing a failure_class write: {plan['rows_needing_write']} "
          f"(already classified: {sum(plan['already_classified'].values())})")


def _write_snapshot(rows: list[dict[str, Any]], db: Path, phase: str, stamp: str) -> Path:
    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    snap_path = SNAPSHOT_DIR / f"classify_summary_missing_{phase}_{stamp}.json"
    entries = [
        {
            "id": r["id"],
            "failure_class": r["failure_class"],
            "failure_subclass": r["failure_subclass"],
            "payload_json": r["prior_text"],  # exact prior text -> exact revert
        }
        for r in rows
    ]
    snap = {
        "tool": "classify_summary_missing.py",
        "db": str(db),
        "phase": phase,
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "row_count": len(entries),
        "entries": entries,
    }
    snap_path.write_text(json.dumps(snap, indent=2), encoding="utf-8")
    return snap_path


def _apply(db: Path, rows: list[dict[str, Any]], batch: int) -> tuple[int, int]:
    """Payload-only stamp of failure_class/subclass/evidence. Guarded on prior payload.

    Commits in bounded batches so the live claim path never waits on one long write lock.
    """
    conn = sqlite3.connect(str(db), timeout=30)
    conn.row_factory = sqlite3.Row
    changed = 0
    skipped = 0
    try:
        pending = 0
        for r in rows:
            updated = dict(r["payload"])
            updated["failure_class"] = r["failure_class"]
            updated["failure_subclass"] = r["failure_subclass"]
            updated["failure_class_evidence"] = "historical_reclassify:db_join"
            new_text = json.dumps(updated, sort_keys=True)
            cur = conn.execute(
                "UPDATE work_items SET payload_json=? WHERE id=? AND payload_json=?",
                (new_text, r["id"], r["prior_text"]),
            )
            if cur.rowcount == 1:
                changed += 1
            else:
                skipped += 1  # row changed since inspection — never clobber
            pending += 1
            if pending >= batch:
                conn.commit()
                pending = 0
        conn.commit()
    finally:
        conn.close()
    return changed, skipped


def _revert(db: Path, snap_path: Path, batch: int) -> tuple[int, int]:
    snap = json.loads(snap_path.read_text(encoding="utf-8"))
    conn = sqlite3.connect(str(db), timeout=30)
    conn.row_factory = sqlite3.Row
    restored = 0
    skipped = 0
    try:
        pending = 0
        for entry in snap.get("entries", []):
            prior = entry["payload_json"]
            payload = json.loads(prior)
            payload["failure_class"] = entry["failure_class"]
            payload["failure_subclass"] = entry["failure_subclass"]
            payload["failure_class_evidence"] = "historical_reclassify:db_join"
            expected_after = json.dumps(payload, sort_keys=True)
            cur = conn.execute(
                "UPDATE work_items SET payload_json=? WHERE id=? AND payload_json=?",
                (prior, entry["id"], expected_after),
            )
            if cur.rowcount == 1:
                restored += 1
            else:
                skipped += 1
            pending += 1
            if pending >= batch:
                conn.commit()
                pending = 0
        conn.commit()
    finally:
        conn.close()
    return restored, skipped


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    ap.add_argument("--phase", default="Q02")
    ap.add_argument("--apply", action="store_true", help="write failure_class (default: dry-run)")
    ap.add_argument("--dry-run", action="store_true", help="explicit dry-run (default)")
    ap.add_argument("--revert", type=Path, metavar="SNAPSHOT", help="restore rows from a snapshot")
    ap.add_argument("--limit", type=int, default=None, help="cap rows written (canary)")
    ap.add_argument("--batch", type=int, default=500, help="rows per commit (lock friendliness)")
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
        restored, skipped = _revert(args.db, args.revert, args.batch)
        print(f"revert: restored={restored} skipped(changed_or_already_reverted)={skipped}")
        return 0

    plan = _plan(args.db, args.phase, args.registry, args.limit if args.apply else None)
    _print_plan(plan)

    if not args.apply:
        print("\nDRY-RUN (default). No rows written. Re-run with --apply to stamp failure_class.")
        return 0

    rows = plan["rows"]
    if not rows:
        print("\nnothing to write: every graveyard row already carries its failure_class.")
        return 0
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    snap_path = _write_snapshot(rows, args.db, args.phase, stamp)
    print(f"\nsnapshot written (revert with --revert): {snap_path}")
    changed, skipped = _apply(args.db, rows, args.batch)
    print(f"apply: changed={changed} skipped(row_changed_since_inspection)={skipped}")
    print(f"revert command: python classify_summary_missing.py --revert \"{snap_path}\"")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
