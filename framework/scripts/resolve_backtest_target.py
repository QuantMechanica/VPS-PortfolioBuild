#!/usr/bin/env python3
"""Resolve target terminal for a backtest job."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from framework.scripts.pipeline_dispatcher import (
    DEFAULT_COMPLETED_RETENTION_SECONDS,
    build_matrix_jobs,
    export_phase_matrix_index,
    load_dedup_index,
    load_dispatch_state,
    prune_state,
    release_job,
    resolve_target_terminal,
    save_dedup_index,
    save_dispatch_state,
)

BACKTEST_SETFILE_ERROR = "BACKTEST_REJECTED_NO_SETFILE"


def _reject_missing_setfile(job: dict[str, Any]) -> dict[str, Any] | None:
    setfile_path = job.get("setfile_path")
    if not isinstance(setfile_path, str) or not setfile_path.strip():
        return {
            "status": "rejected",
            "error_code": BACKTEST_SETFILE_ERROR,
            "message": "Dispatch requires job.setfile_path for backtest runs.",
        }
    setfile = Path(setfile_path.strip())
    if not setfile.is_absolute():
        setfile = (REPO_ROOT / setfile).resolve()
    if not setfile.exists():
        return {
            "status": "rejected",
            "error_code": BACKTEST_SETFILE_ERROR,
            "message": f"Dispatch set file not found: {setfile}",
            "setfile_path": str(setfile),
        }
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Resolve target terminal for a backtest job.")
    parser.add_argument("--job-json", required=True, help="Path to JSON job payload.")
    parser.add_argument("--state-json", default=r"D:\QM\Reports\pipeline\dispatch_state.json", help="Dispatch state path.")
    parser.add_argument(
        "--dedup-index-json",
        default=r"D:\QM\Reports\pipeline\dedup_index.json",
        help="Phase matrix dedup index path.",
    )
    parser.add_argument("--max-per-terminal", type=int, default=3, help="Max active runs per terminal.")
    parser.add_argument("--event", choices=("start", "complete"), default="start", help="Dispatch lifecycle event.")
    parser.add_argument(
        "--matrix-symbol-count",
        type=int,
        default=None,
        help="Optional override count for matrix jobs in output summary only.",
    )
    parser.add_argument("--verdict", default=None, help="Optional completion verdict (e.g. PASS, FAIL).")
    parser.add_argument("--evidence", default=None, help="Optional evidence path/string for completion row.")
    parser.add_argument("--pass-threshold", type=int, default=1, help="PASS threshold across matrix rows.")
    parser.add_argument("--fail-phase-label", default=None, help="Phase label used for FAIL_PHASE_<label> verdict.")
    parser.add_argument(
        "--next-strategy-unblocked",
        default=None,
        help="Optional next strategy pointer to persist at matrix bucket level.",
    )
    parser.add_argument("--prune-completed", action="store_true", help="Prune stale completed dedup records.")
    parser.add_argument(
        "--retention-seconds",
        type=int,
        default=DEFAULT_COMPLETED_RETENTION_SECONDS,
        help="Retention for completed dedup records when --prune-completed is enabled.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    job_path = Path(args.job_json)
    with job_path.open("r", encoding="utf-8-sig") as handle:
        job: dict[str, Any] = json.load(handle)

    state_path = Path(args.state_json)
    state = load_dispatch_state(state_path)
    dedup_index_path = Path(args.dedup_index_json)
    dedup_index = load_dedup_index(dedup_index_path)
    should_save = False
    if args.event == "complete":
        decision = release_job(
            job,
            state,
            verdict=args.verdict,
            evidence=args.evidence,
            pass_threshold=args.pass_threshold,
            fail_phase_label=args.fail_phase_label,
            next_strategy_unblocked=args.next_strategy_unblocked,
        )
        should_save = decision.get("status") == "released"
    else:
        rejected = _reject_missing_setfile(job)
        if rejected is not None:
            decision = rejected
            print(json.dumps(decision, sort_keys=True))
            return 0
        if isinstance(job.get("symbols"), list):
            jobs = build_matrix_jobs(job)
            results = []
            for matrix_job in jobs:
                result = resolve_target_terminal(matrix_job, state, max_per_terminal=args.max_per_terminal)
                results.append(result)
                if result.get("status") == "scheduled":
                    should_save = True
            summary = {
                "scheduled": sum(1 for item in results if item.get("status") == "scheduled"),
                "duplicate": sum(1 for item in results if item.get("status") == "duplicate"),
                "no_capacity": sum(1 for item in results if item.get("status") == "no_capacity"),
            }
            decision = {
                "status": "matrix_dispatch_complete",
                "matrix_count": int(args.matrix_symbol_count or len(jobs)),
                "summary": summary,
                "results": results,
            }
        else:
            decision = resolve_target_terminal(job, state, max_per_terminal=args.max_per_terminal)
            should_save = decision.get("status") == "scheduled"
    pruned = 0
    if args.prune_completed:
        pruned = prune_state(state, retention_seconds=args.retention_seconds)
    if should_save:
        save_dispatch_state(state, state_path)
        dedup_index.update(export_phase_matrix_index(state))
        save_dedup_index(dedup_index, dedup_index_path)
    if pruned > 0 and not should_save:
        save_dispatch_state(state, state_path)
        dedup_index.update(export_phase_matrix_index(state))
        save_dedup_index(dedup_index, dedup_index_path)
    if pruned > 0:
        decision["pruned_completed"] = pruned
    print(json.dumps(decision, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
