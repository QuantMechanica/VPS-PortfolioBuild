#!/usr/bin/env python3
"""Resolve target terminal for a backtest job."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from framework.scripts.pipeline_dispatcher import (
    DEFAULT_COMPLETED_RETENTION_SECONDS,
    build_matrix_jobs,
    export_phase_matrix_index,
    initialize_matrix_bucket_for_symbols,
    load_dedup_index,
    load_dispatch_state,
    matrix_bucket_key,
    prune_state,
    release_job,
    resolve_target_terminal,
    save_dedup_index,
    save_dispatch_state,
)
from framework.scripts.dl054_gates import apply_pre_launch_gates

BACKTEST_SETFILE_ERROR = "BACKTEST_REJECTED_NO_SETFILE"


def _drain_pending_matrix_jobs(state: dict[str, Any], max_per_terminal: int) -> dict[str, int]:
    pending_root = state.setdefault("pending_matrix_jobs", {})
    if not isinstance(pending_root, dict):
        state["pending_matrix_jobs"] = {}
        pending_root = state["pending_matrix_jobs"]
    summary = {"scheduled": 0, "duplicate": 0, "no_capacity": 0}
    keys = list(pending_root.keys())
    for key in keys:
        queued = pending_root.get(key)
        if not isinstance(queued, list) or not queued:
            pending_root.pop(key, None)
            continue
        blocked_index: int | None = None
        for idx, job in enumerate(queued):
            result = resolve_target_terminal(job, state, max_per_terminal=max_per_terminal)
            status = str(result.get("status", ""))
            if status == "scheduled":
                summary["scheduled"] += 1
            elif status == "duplicate":
                summary["duplicate"] += 1
            else:
                summary["no_capacity"] += 1
                blocked_index = idx
                break
        if blocked_index is not None:
            pending_root[key] = queued[blocked_index:]
        else:
            pending_root.pop(key, None)
    return summary


def _append_report_csv_row(
    *,
    report_csv_path: str | None,
    ea_id: str,
    phase: str,
    symbol: str,
    terminal: str,
    verdict: str,
    invalidation_reason: str,
    evidence: str = "",
) -> None:
    if not report_csv_path:
        return
    path = Path(report_csv_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    write_header = not path.exists() or path.stat().st_size == 0
    with path.open("a", encoding="utf-8", newline="") as handle:
        if write_header:
            handle.write("ea_id,phase,symbol,terminal,verdict,invalidation_reason,evidence\n")
        row = (
            ea_id,
            phase,
            symbol,
            terminal,
            verdict,
            (invalidation_reason or "").replace(",", ";").replace("\n", " "),
            evidence or "",
        )
        handle.write(",".join(row) + "\n")


def _window_bounds_from_job(job: dict[str, Any]) -> tuple[datetime, datetime]:
    year = None
    raw_hash = str(job.get("sub_gate_config_hash", ""))
    if "-" in raw_hash:
        maybe_year = raw_hash.rsplit("-", 1)[-1]
        if maybe_year.isdigit():
            year = int(maybe_year)
    if year is None:
        year = int(datetime.now(tz=timezone.utc).year)
    start = datetime(year, 1, 1, tzinfo=timezone.utc)
    end = datetime(year, 12, 31, 23, 59, 59, tzinfo=timezone.utc)
    return start, end


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
        "--enforce-dl054-prelaunch",
        action="store_true",
        help="Run DL-054 prelaunch gates (G1/G2/G5) before scheduling.",
    )
    parser.add_argument(
        "--report-csv",
        default=None,
        help="Optional report.csv path for INVALID gate rows.",
    )
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
        if should_save:
            drained = _drain_pending_matrix_jobs(state, args.max_per_terminal)
            if any(v > 0 for v in drained.values()):
                decision["pending_recovery"] = drained
    else:
        rejected = _reject_missing_setfile(job)
        if rejected is not None:
            decision = rejected
            print(json.dumps(decision, sort_keys=True))
            return 0
        if args.enforce_dl054_prelaunch:
            terminal_label = str(job.get("target_terminal", "any")).upper()
            window_start, window_end = _window_bounds_from_job(job)
            launch_config = {
                "initial_deposit": 100000,
                "deposit_currency": "USD",
                "leverage": 100,
                "setfile_path": str(job.get("setfile_path", "")),
            }
            pre = apply_pre_launch_gates(
                ea_id=str(job.get("ea_id", "")),
                phase=str(job.get("phase", "")),
                symbol=str(job.get("symbol", "")),
                terminal=terminal_label,
                window_start=window_start,
                window_end=window_end,
                launch_config=launch_config,
            )
            if pre.verdict == "INVALID":
                _append_report_csv_row(
                    report_csv_path=args.report_csv,
                    ea_id=pre.ea_id,
                    phase=pre.phase,
                    symbol=pre.symbol,
                    terminal=pre.terminal,
                    verdict="INVALID",
                    invalidation_reason=pre.invalidation_reason,
                    evidence="resolve_backtest_target.py:prelaunch",
                )
                decision = {
                    "status": "invalid_prelaunch",
                    "verdict": "INVALID",
                    "invalidation_reason": pre.invalidation_reason,
                    "terminal": None,
                }
                print(json.dumps(decision, sort_keys=True))
                return 0
        if isinstance(job.get("symbols"), list):
            jobs = build_matrix_jobs(job)
            initialize_matrix_bucket_for_symbols(state, jobs)
            should_save = True
            results = []
            pending_jobs: list[dict[str, Any]] = []
            for matrix_job in jobs:
                result = resolve_target_terminal(matrix_job, state, max_per_terminal=args.max_per_terminal)
                results.append(result)
                if result.get("status") == "scheduled":
                    should_save = True
                elif result.get("status") == "no_capacity":
                    pending_jobs.append(matrix_job)
            pending_root = state.setdefault("pending_matrix_jobs", {})
            bucket = matrix_bucket_key(jobs[0]) if jobs else "unknown"
            if pending_jobs:
                pending_root[bucket] = pending_jobs
            else:
                pending_root.pop(bucket, None)
            summary = {
                "scheduled": sum(1 for item in results if item.get("status") == "scheduled"),
                "duplicate": sum(1 for item in results if item.get("status") == "duplicate"),
                "no_capacity": sum(1 for item in results if item.get("status") == "no_capacity"),
                "pending": len(pending_jobs),
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
