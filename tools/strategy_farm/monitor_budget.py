"""Monitor-budget evidence, separate from EA defects and transient launch faults."""
from __future__ import annotations

import argparse
import json
import math
from collections import Counter
from pathlib import Path

FAILURE_CLASS = "MONITOR_BUDGET_REVIEW"
SUBCLASS = "monitor_budget_exhausted"
HOLD_CODE = "MONITOR_BUDGET_REVIEW_REQUIRED"


def classify(payload: dict) -> dict | None:
    record = payload.get("worker_exit_record")
    record = record if isinstance(record, dict) else payload
    marker = record.get("monitor_kill", payload.get("monitor_kill"))
    if isinstance(marker, dict):
        if marker.get("reason") != SUBCLASS:
            return None
        # Ignore a retained marker from a different attempt.
        expected_start = payload.get("started_at_iso")
        if expected_start and marker.get("started_at_iso") != expected_start:
            return None
        record = {**record, **marker}
    if payload.get("started_at_iso") and record.get("started_at_iso") != payload["started_at_iso"]:
        return None
    explicit = marker is True or isinstance(marker, dict)
    try:
        runtime = float(record.get("tester_runtime_seconds"))
        budget = float(record.get("effective_monitor_budget_seconds"))
        close = (math.isfinite(runtime) and math.isfinite(budget) and budget > 0
                 and runtime >= 0 and abs(runtime - budget) <= .02 * budget)
    except (TypeError, ValueError, OverflowError):
        runtime = budget = None
        close = False
    if not explicit and not close:
        return None
    return {"failure_class": FAILURE_CLASS, "failure_subclass": SUBCLASS,
            "retryable": True, "deterministic": True, "retry_requires_budget_review": True,
            "evidence": "explicit monitor_kill" if explicit else "worker runtime within 2% of recorded effective monitor budget",
            "tester_runtime_seconds": runtime, "effective_monitor_budget_seconds": budget}


def inspect_logs(paths: list[Path], legacy_budget_seconds: float | None = None) -> dict:
    """Read-only backfill inventory; an explicit legacy budget is a hypothesis.

    Current budget defaults must never be retroactively applied to older runs.
    One occurrence key deduplicates marker/run_result/child-exit representations.
    """
    rows, seen = [], set()
    for path in paths:
        with path.open(encoding="utf-8-sig", errors="replace") as stream:
            for number, line in enumerate(stream, 1):
                try:
                    record = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(record, dict): continue
                event = record.get("event")
                if event not in ("monitor_kill", "run_result", "target_run_result", "next_cell_prestage"):
                    continue
                if event == "next_cell_prestage" and record.get("stage_event") != "current_child_exit": continue
                marker = record.get("monitor_kill")
                key = (record.get("item_id"), record.get("terminal"),
                       (marker.get("killed_at_utc") if isinstance(marker, dict) else None)
                       or record.get("at_utc") or f"{path}:{number}")
                if key in seen: continue
                candidate = dict(record)
                assumed = False
                if candidate.get("effective_monitor_budget_seconds") is None and legacy_budget_seconds is not None:
                    candidate["effective_monitor_budget_seconds"] = legacy_budget_seconds
                    assumed = True
                classification = classify(candidate)
                if classification:
                    seen.add(key)
                    rows.append({"path": str(path), "line": number, "item_id": record.get("item_id"),
                                 "terminal": record.get("terminal"), "at_utc": record.get("at_utc"),
                                 "legacy_budget_assumed": assumed, "source_record": record, **classification})
    return {"read_only": True, "legacy_budget_seconds": legacy_budget_seconds,
            "count": len(rows), "by_utc_day": dict(Counter(str(r["at_utc"] or "unknown")[:10] for r in rows)),
            "rows": rows}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--log", type=Path, action="append", required=True)
    ap.add_argument("--legacy-budget-seconds", type=float)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    if args.legacy_budget_seconds is not None and (not math.isfinite(args.legacy_budget_seconds) or args.legacy_budget_seconds <= 0):
        ap.error("legacy budget must be finite and positive")
    result = inspect_logs(args.log, args.legacy_budget_seconds)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: result[k] for k in ("read_only", "count", "by_utc_day")}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
