#!/usr/bin/env python3
"""Review-SLA tracker for the versioned target rulepacks (SP-E3).

``target_rulepacks.py`` already gives every Darwinex Zero / FTMO rulepack a
canonical, hash-pinned ``official_sources`` array with ``url`` +
``retrieved_on`` per source -- that is the "Quelle/Abrufdatum" half of SP-E3's
acceptance criterion. Its schema is a hard-bounded, hash-sensitive contract
(``QM_CANONICAL_JSON_V1``, exact-key validation everywhere); adding a new
required root field there would force every existing rulepack through a
version bump for a purely operational concern. This module adds the missing
"Review-SLA... regelmaessig geprueft" half as a separate, additive tracker
that never touches the rulepack files, their schema, or their canonical hash.

The tracker is a small JSON state file (``config/target_rulepack_review_sla.json``)
mapping each known ``rulepack_id`` to a review cadence and the last confirmed
check. It never invents a review: a rulepack with no entry is reported as
overdue immediately (fail closed), and recording a check requires an explicit
caller-supplied ``checked_on`` date plus a free-text note describing what was
actually compared against the official source -- there is no auto-fetch path
here that could silently mark a rulepack "reviewed" without a human/agent
having actually read the official page.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path
from typing import Any

try:
    from tools.strategy_farm import target_rulepacks
except ImportError:  # running as a standalone script (sys.path[0] == this dir)
    import target_rulepacks  # type: ignore[no-redef]

STATE_SCHEMA = "target-rulepack-review-sla/v1"
DEFAULT_STATE_PATH = (
    Path(__file__).resolve().parent / "config" / "target_rulepack_review_sla.json"
)
DEFAULT_INTERVAL_DAYS = 90


class ReviewSlaError(RuntimeError):
    pass


@dataclass(frozen=True)
class ReviewEntry:
    rulepack_id: str
    interval_days: int
    last_reviewed_on: str
    next_review_due_on: str
    last_check_result: str
    note: str


def _load_state(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {"schema_version": STATE_SCHEMA, "entries": {}}
    if payload.get("schema_version") != STATE_SCHEMA:
        raise ReviewSlaError(f"unsupported schema_version: {payload.get('schema_version')!r}")
    if not isinstance(payload.get("entries"), dict):
        raise ReviewSlaError("entries must be an object")
    return payload


def _save_state(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    document = json.dumps(state, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    tmp = path.with_suffix(".tmp")
    tmp.write_text(document, encoding="utf-8", newline="\n")
    tmp.replace(path)


def record_review(
    rulepack_id: str,
    *,
    checked_on: str,
    result: str,
    note: str,
    interval_days: int = DEFAULT_INTERVAL_DAYS,
    state_path: Path = DEFAULT_STATE_PATH,
) -> ReviewEntry:
    """Persist that ``rulepack_id`` was actually checked against its official
    sources on ``checked_on``. Never called automatically -- the caller must
    have performed (or delegated and verified) the real comparison."""

    if result not in {"CONFIRMED_UNCHANGED", "DISCREPANCY_FOUND"}:
        raise ReviewSlaError(f"result must be CONFIRMED_UNCHANGED or DISCREPANCY_FOUND, got {result!r}")
    if not note.strip():
        raise ReviewSlaError("note must describe what was actually compared")
    checked = date.fromisoformat(checked_on)
    if interval_days <= 0:
        raise ReviewSlaError("interval_days must be positive")
    due = checked + timedelta(days=interval_days)

    state = _load_state(state_path)
    entry = {
        "interval_days": interval_days,
        "last_reviewed_on": checked.isoformat(),
        "next_review_due_on": due.isoformat(),
        "last_check_result": result,
        "note": note,
    }
    state["entries"][rulepack_id] = entry
    _save_state(state_path, state)
    return ReviewEntry(
        rulepack_id=rulepack_id,
        interval_days=interval_days,
        last_reviewed_on=entry["last_reviewed_on"],
        next_review_due_on=entry["next_review_due_on"],
        last_check_result=result,
        note=note,
    )


def status(
    *,
    today: date,
    rulepack_dir: Path = target_rulepacks.DEFAULT_RULEPACK_DIR,
    state_path: Path = DEFAULT_STATE_PATH,
) -> list[dict[str, Any]]:
    """Report every known rulepack's review status. A rulepack present on
    disk with no tracker entry is reported overdue with ``days_overdue=None``
    (never reviewed) rather than silently skipped -- fail closed."""

    state = _load_state(state_path)
    entries: dict[str, Any] = state["entries"]
    rows: list[dict[str, Any]] = []
    for rulepack_id in target_rulepacks.list_rulepack_ids(rulepack_dir=rulepack_dir):
        entry = entries.get(rulepack_id)
        if entry is None:
            rows.append(
                {
                    "rulepack_id": rulepack_id,
                    "reviewed": False,
                    "overdue": True,
                    "days_overdue": None,
                    "next_review_due_on": None,
                    "last_check_result": None,
                }
            )
            continue
        due = date.fromisoformat(entry["next_review_due_on"])
        overdue = today > due
        rows.append(
            {
                "rulepack_id": rulepack_id,
                "reviewed": True,
                "overdue": overdue,
                "days_overdue": (today - due).days if overdue else 0,
                "next_review_due_on": entry["next_review_due_on"],
                "last_check_result": entry["last_check_result"],
            }
        )
    return sorted(rows, key=lambda row: row["rulepack_id"])


def _cli() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    status_parser = sub.add_parser("status", help="report overdue/current rulepacks")
    status_parser.add_argument("--as-of-today", help="override today's date (YYYY-MM-DD)")
    status_parser.add_argument("--json", action="store_true")

    record_parser = sub.add_parser("record", help="record a real review")
    record_parser.add_argument("rulepack_id")
    record_parser.add_argument("--checked-on", required=True)
    record_parser.add_argument("--result", required=True, choices=["CONFIRMED_UNCHANGED", "DISCREPANCY_FOUND"])
    record_parser.add_argument("--note", required=True)
    record_parser.add_argument("--interval-days", type=int, default=DEFAULT_INTERVAL_DAYS)

    args = parser.parse_args()
    if args.command == "record":
        entry = record_review(
            args.rulepack_id,
            checked_on=args.checked_on,
            result=args.result,
            note=args.note,
            interval_days=args.interval_days,
        )
        print(json.dumps(entry.__dict__, indent=2, sort_keys=True))
        return 0

    today = date.fromisoformat(args.as_of_today) if args.as_of_today else date.today()
    rows = status(today=today)
    if args.json:
        print(json.dumps(rows, indent=2, sort_keys=True))
    else:
        for row in rows:
            flag = "OVERDUE" if row["overdue"] else "OK"
            print(f"{row['rulepack_id']} {flag} due={row['next_review_due_on']} result={row['last_check_result']}")
    return 1 if any(row["overdue"] for row in rows) else 0


if __name__ == "__main__":
    raise SystemExit(_cli())
