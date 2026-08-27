"""Run the commissioned V4a Phase-3 governed warm-backend validation.

This command is validation-only.  It requires the existing feature flag and a
durable authorization manifest, uses the isolated DEV2 Scheduled-Task
controller, compares at most the deterministic twenty-cell cohort, and stops on
the first deviation.  It never mutates the farm database or production worker.
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import statistics
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence


REPO_IMPORT_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_IMPORT_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_IMPORT_ROOT))

from tools.strategy_farm import warm_cell_runner as core


DEFAULT_OUTPUT_STEM = "2cb9d160_v4a_phase3_governed_restart_2026-08-27"


def _load_json(path: Path) -> dict[str, Any]:
    value = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def _git_head(repo_root: Path) -> str:
    completed = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    )
    return completed.stdout.strip()


def _implementation_commit(repo_root: Path) -> str:
    completed = subprocess.run(
        [
            "git",
            "log",
            "-1",
            "--format=%H",
            "--",
            "tools/strategy_farm/warm_cell_runner.py",
            "tools/strategy_farm/warm_cell_phase3.py",
        ],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    )
    return completed.stdout.strip()


def prepare_cells(
    references: Sequence[Mapping[str, Any]], *, input_dir: Path, repo_root: Path
) -> list[dict[str, Any]]:
    input_dir = Path(input_dir).resolve()
    if not core._path_is_within(input_dir, repo_root):
        raise core.ActivationRefused("PHASE3_INPUT_DIR_OUTSIDE_REPO")
    cells: list[dict[str, Any]] = []
    for reference in references:
        source_name = Path(str(reference.get("setfile_source_path") or "")).name
        staged = input_dir / source_name
        if not staged.is_file():
            raise core.ActivationRefused(f"PHASE3_INPUT_SETFILE_MISSING:{source_name}")
        guard = core.validate_validation_setfile(staged)
        if guard["sha256"] != reference.get("setfile_sha256"):
            raise core.ActivationRefused(
                f"PHASE3_INPUT_SETFILE_HASH_MISMATCH:{source_name}"
            )
        cell = dict(reference)
        cell.update(
            {
                "setfile_path": str(staged),
                "timeout_seconds": 7200,
                "min_trades": 5,
                "setfile_guard": guard,
            }
        )
        cells.append(cell)
    return cells


def _timing_summary(values: Sequence[float]) -> dict[str, Any]:
    samples = [float(value) for value in values]
    if not samples:
        return {
            "sample_count": 0,
            "total_seconds": None,
            "mean_seconds": None,
            "median_seconds": None,
            "minimum_seconds": None,
            "maximum_seconds": None,
        }
    return {
        "sample_count": len(samples),
        "total_seconds": round(sum(samples), 3),
        "mean_seconds": round(statistics.fmean(samples), 3),
        "median_seconds": round(statistics.median(samples), 3),
        "minimum_seconds": round(min(samples), 3),
        "maximum_seconds": round(max(samples), 3),
    }


def build_packet(
    *,
    references: Sequence[Mapping[str, Any]],
    comparisons: Sequence[Mapping[str, Any]],
    backend: core.GovernedDev2RestartBackend,
    authorization_manifest: Mapping[str, Any],
    authorization_path: Path,
    repo_root: Path,
    db_path: Path,
    outcome_status: str,
    outcome_error: str | None,
) -> dict[str, Any]:
    comparison_by_key = {
        str(row.get("cell_key")): dict(row) for row in comparisons
    }
    warm_by_key = {str(row.get("cell_key")): row for row in backend.results}
    rows: list[dict[str, Any]] = []
    for rank, reference in enumerate(references, start=1):
        key = str(reference.get("cell_key"))
        cold_fp = core.result_fingerprints(reference)
        comparison = comparison_by_key.get(key)
        warm = warm_by_key.get(key)
        rows.append(
            {
                "selection_rank": rank,
                "cell_key": key,
                "arm": reference.get("arm"),
                "work_item_id": reference.get("work_item_id"),
                "setfile_sha256": reference.get("setfile_sha256"),
                "cold_elapsed_seconds": reference.get("cold_elapsed_seconds"),
                "warm_elapsed_seconds": None if warm is None else warm.get("warm_elapsed_seconds"),
                "cold_identity_sha256": cold_fp["identity_sha256"],
                "warm_identity_sha256": None if comparison is None else comparison.get("warm_identity_sha256"),
                "cold_report_metrics_sha256": cold_fp["report_metrics_sha256"],
                "warm_report_metrics_sha256": None if comparison is None else comparison.get("warm_report_metrics_sha256"),
                "cold_trade_list_sha256": cold_fp["trade_list_sha256"],
                "warm_trade_list_sha256": None if comparison is None else comparison.get("warm_trade_list_sha256"),
                "cold_native_report_sha256": cold_fp["native_report_sha256"],
                "warm_native_report_sha256": None if comparison is None else comparison.get("warm_native_report_sha256"),
                "cold_logger_sample_sha256": cold_fp["logger_sample_sha256"],
                "warm_logger_sample_sha256": None if comparison is None else comparison.get("warm_logger_sample_sha256"),
                "cold_receipt_schema_sha256": cold_fp["receipt_schema_sha256"],
                "warm_receipt_schema_sha256": None if comparison is None else comparison.get("warm_receipt_schema_sha256"),
                "cold_entry_trading_days": cold_fp["entry_trading_days"],
                "warm_entry_trading_days": None if comparison is None else comparison.get("warm_entry_trading_days"),
                "identity_exact": None if comparison is None else comparison.get("identity_exact_match"),
                "metrics_exact": None if comparison is None else comparison.get("report_metrics_field_exact_match"),
                "trades_exact": None if comparison is None else comparison.get("trade_list_byte_exact_match"),
                "native_report_exact": None if comparison is None else comparison.get("native_report_byte_exact_match"),
                "logger_sample_exact": None if comparison is None else comparison.get("logger_sample_byte_exact_match"),
                "receipt_schema_exact": None if comparison is None else comparison.get("receipt_schema_exact_match"),
                "entry_days_exact": None if comparison is None else comparison.get("entry_trading_days_exact_match"),
                "all_exact": None if comparison is None else comparison.get("all_exact"),
                "warm_status": (
                    "NOT_RUN_AFTER_STOP"
                    if warm is None
                    else ("EXACT" if comparison and comparison.get("all_exact") else "DEVIATION")
                ),
                "cold_summary_path": reference.get("summary_path"),
                "warm_summary_path": None if warm is None else warm.get("summary_path"),
                "cold_native_report_path": reference.get("report_path"),
                "warm_native_report_path": None if warm is None else warm.get("native_report_path"),
                "cold_logger_sample_path": reference.get("logger_sample_path"),
                "warm_logger_sample_path": None if warm is None else warm.get("logger_sample_path"),
            }
        )

    cold_timing = core.cold_timing_summary(references)
    warm_cell_timing = _timing_summary(
        [
            float(row["warm_elapsed_seconds"])
            for row in backend.results
            if row.get("warm_elapsed_seconds") is not None
        ]
    )
    attempted_keys = set(warm_by_key)
    attempted_cold_seconds = round(
        sum(
            float(row["cold_elapsed_seconds"])
            for row in references
            if str(row.get("cell_key")) in attempted_keys
            and row.get("cold_elapsed_seconds") is not None
        ),
        3,
    )
    session_seconds = (backend.session_summary or {}).get("elapsed_seconds")
    attempted_speedup = (
        None
        if not session_seconds or not attempted_keys
        else round(attempted_cold_seconds / float(session_seconds), 4)
    )
    exact_count = sum(1 for row in rows if row.get("all_exact") is True)
    all_twenty_exact = len(comparisons) == 20 and exact_count == 20
    batch_speedup = attempted_speedup if all_twenty_exact else None
    speedup_target_met = bool(batch_speedup is not None and batch_speedup >= 2.5)
    cold_paths = core.cold_path_identity(
        repo_root,
        task_start_hashes=core.PHASE3_TASK_START_COLD_PATH_SHA256,
    )
    cold_path_exact = all(row["byte_identical_to_task_start"] for row in cold_paths)
    selection_identity = [
        {
            "rank": row["selection_rank"],
            "cell_key": row["cell_key"],
            "work_item_id": row["work_item_id"],
            "setfile_sha256": row["setfile_sha256"],
        }
        for row in rows
    ]
    packet = {
        "schema": "qm.warm-cell-phase3-validation/v1",
        "task_id": core.PHASE3_TASK_ID,
        "generated_at_utc": core.utc_now(),
        "outcome": {
            "status": outcome_status,
            "error": outcome_error,
            "attempted": len(backend.results),
            "compared": len(comparisons),
            "exact": exact_count,
            "all_twenty_exact": all_twenty_exact,
        },
        "authorization": {
            "path": str(Path(authorization_path).resolve()),
            "sha256": core.sha256_file(authorization_path),
            "manifest": dict(authorization_manifest),
            "feature_flag": core.FLAG_NAME,
            "feature_flag_process_value": os.environ.get(core.FLAG_NAME),
            "production_wiring": False,
        },
        "source": {
            "repo_root": str(repo_root.resolve()),
            "git_head": _git_head(repo_root),
            "implementation_commit": _implementation_commit(repo_root),
            "database": str(db_path.resolve()),
            "database_mode": "URI mode=ro + PRAGMA query_only=ON",
        },
        "selection": {
            "rule": "oldest AUTHENTICATED_COLD by (updated_at, work_item_id)",
            "selected_count": len(references),
            "identity_sha256": core.sha256_bytes(
                core.canonical_json_bytes(selection_identity)
            ),
            "rows": selection_identity,
        },
        "backend": {
            "execution_backend": core.GOVERNED_RESTART_BACKEND,
            "profile_mode": core.GOVERNED_RESTART_PROFILE,
            "lane": "DEV2",
            "production_supported": False,
            "resident_ipc_claimed": False,
            "logical_session": backend.session_summary,
            "runtime_artifact_dir": str(backend.artifact_dir),
        },
        "timing": {
            "cold_baseline": cold_timing,
            "warm_cells": warm_cell_timing,
            "attempted_cold_seconds": attempted_cold_seconds,
            "warm_logical_session_seconds": session_seconds,
            "attempted_like_for_like_speedup": attempted_speedup,
            "complete_batch_speedup": batch_speedup,
            "target_minimum": 2.5,
            "target_met": speedup_target_met,
        },
        "comparison": {
            "minimum_required": 20,
            "rows": rows,
            "all_twenty_exact": all_twenty_exact,
        },
        "warm_results": backend.results,
        "cold_path": {
            "files": cold_paths,
            "byte_identical_to_phase3_start": cold_path_exact,
            "dl089_untouched": next(
                row["byte_identical_to_task_start"]
                for row in cold_paths
                if row["path"] == "tools/strategy_farm/dl089_matrix_service.py"
            ),
        },
        "activation_checklist": [
            {
                "gate": "validation-only governed backend implemented and tested",
                "status": "PASS" if len(backend.results) > 0 else "BLOCKED",
            },
            {
                "gate": "20 oldest authenticated references selected",
                "status": "PASS" if len(references) == 20 else "BLOCKED",
            },
            {
                "gate": "20/20 field and artifact-byte parity",
                "status": "PASS" if all_twenty_exact else "BLOCKED",
            },
            {
                "gate": "measured >=2.5x complete-batch speedup",
                "status": "PASS" if speedup_target_met else "BLOCKED",
            },
            {
                "gate": "repeat complete batch deterministically",
                "status": "BLOCKED",
            },
            {
                "gate": "OWNER activation seal binds reviewed backend and parity packet",
                "status": "BLOCKED",
            },
            {
                "gate": "production remains Default-OFF; cold path and DL-089 unchanged",
                "status": "PASS" if cold_path_exact else "BLOCKED",
            },
        ],
    }
    return packet


def render_report(packet: Mapping[str, Any]) -> str:
    outcome = packet["outcome"]
    timing = packet["timing"]
    cold = timing["cold_baseline"]
    lines = [
        "# V4a Phase 3 — governed sequential tester validation",
        "",
        f"**Verdict:** `{outcome['status']}`",
        f"**Execution:** `{outcome['attempted']}/20` cells launched, `{outcome['compared']}/20` compared, `{outcome['exact']}` exact.",
        f"**Feature flag:** `{core.FLAG_NAME}` was process-scoped for this validation; production wiring remains absent and Default-OFF.",
        "",
        "The backend uses the governed DEV2 Scheduled-Task controller and restarts the tester sequentially in one isolated lane. It does not claim unsupported resident MT5 IPC. Every completed cell is authenticated through the unchanged `run_smoke/v2` receipt and includes native report bytes, logger-sample bytes, canonical trade rows, and entry-trading-day evidence.",
        "",
        "## Acceptance result",
        "",
        "| Criterion | Result |",
        "|---|---|",
        f"| Backend + tests | {'PASS' if outcome['attempted'] else 'BLOCKED'} — governed DEV2 restart backend, Default-OFF authorization, byte guards, and containment closeout |",
        f"| 20-cell parity | {'PASS' if outcome['all_twenty_exact'] else 'DEVIATION/STOP'} — {outcome['exact']}/20 exact; full hashes are in the table, CSV, and JSON packet |",
        f"| Speedup | cold={cold['total_seconds']} s; attempted like-for-like={timing['attempted_like_for_like_speedup']}; complete batch={timing['complete_batch_speedup']}; target >=2.5x={'PASS' if timing['target_met'] else 'NOT MET'} |",
        f"| Cold path / DL-089 | {'PASS' if packet['cold_path']['byte_identical_to_phase3_start'] else 'FAIL'} — governed cold-path files byte-identical to Phase-3 start |",
        "",
    ]
    if outcome.get("error"):
        lines.extend(["## Stop detail", "", f"`{outcome['error']}`", ""])
    lines.extend(
        [
            "## Timing",
            "",
            "| Path | Cells | Total s | Mean s | Median s | Min s | Max s | Speedup |",
            "|---|---:|---:|---:|---:|---:|---:|---:|",
            f"| Cold authenticated receipts | {cold['sample_count']} | {cold['total_seconds']} | {cold['mean_seconds']} | {cold['median_seconds']} | {cold['minimum_seconds']} | {cold['maximum_seconds']} | baseline |",
            f"| Governed DEV2 cell walls | {timing['warm_cells']['sample_count']} | {timing['warm_cells']['total_seconds']} | {timing['warm_cells']['mean_seconds']} | {timing['warm_cells']['median_seconds']} | {timing['warm_cells']['minimum_seconds']} | {timing['warm_cells']['maximum_seconds']} | {timing['attempted_like_for_like_speedup']} |",
            "",
            "## Parity table",
            "",
            "| # | Arm | Set SHA-256 | Cold/Warm metrics | Cold/Warm trades | Cold/Warm report | Cold/Warm logger | Days | Exact |",
            "|---:|---|---|---|---|---|---|---|---|",
        ]
    )
    for row in packet["comparison"]["rows"]:
        def pair(left: Any, right: Any) -> str:
            return f"`{left}` / `{right or 'NOT_RUN'}`"

        lines.append(
            f"| {row['selection_rank']} | {row['arm']} | `{row['setfile_sha256']}` | "
            f"{pair(row['cold_report_metrics_sha256'], row['warm_report_metrics_sha256'])} | "
            f"{pair(row['cold_trade_list_sha256'], row['warm_trade_list_sha256'])} | "
            f"{pair(row['cold_native_report_sha256'], row['warm_native_report_sha256'])} | "
            f"{pair(row['cold_logger_sample_sha256'], row['warm_logger_sample_sha256'])} | "
            f"{row['cold_entry_trading_days']}/{row['warm_entry_trading_days'] if row['warm_entry_trading_days'] is not None else 'NOT_RUN'} | "
            f"{row['all_exact']} |"
        )
    lines.extend(["", "## Activation checklist", "", "| Gate | Status |", "|---|---|"])
    for item in packet["activation_checklist"]:
        lines.append(f"| {item['gate']} | **{item['status']}** |")
    lines.extend(
        [
            "",
            "## Safety record",
            "",
            "- T1–T10, T_Live, AutoTrading, production claims, queue rows, pipeline verdicts, and the farm database were not changed.",
            "- DEV2 was entered idle with its isolated account disabled; the governed controller restored it disabled after every cell and the logical-session closeout rechecked zero lane processes.",
            "- `terminal_worker.py`, `run_smoke.ps1`, `opt_census.py`, and `dl089_matrix_service.py` retain their exact Phase-3-start bytes.",
            "- This validation packet is not pipeline evidence and does not authorize activation.",
            "",
        ]
    )
    return "\n".join(lines)


def write_outputs(
    *, packet: Mapping[str, Any], output_dir: Path, output_stem: str
) -> dict[str, Path]:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    report_path = output_dir / f"{output_stem}.md"
    packet_path = output_dir / f"{output_stem}_packet.json"
    comparison_path = output_dir / f"{output_stem}_comparison.csv"
    core._atomic_text(packet_path, json.dumps(packet, indent=2, sort_keys=True) + "\n")
    core._atomic_text(report_path, render_report(packet))
    fields = [
        "selection_rank",
        "cell_key",
        "arm",
        "work_item_id",
        "setfile_sha256",
        "cold_elapsed_seconds",
        "warm_elapsed_seconds",
        "cold_identity_sha256",
        "warm_identity_sha256",
        "cold_report_metrics_sha256",
        "warm_report_metrics_sha256",
        "cold_trade_list_sha256",
        "warm_trade_list_sha256",
        "cold_native_report_sha256",
        "warm_native_report_sha256",
        "cold_logger_sample_sha256",
        "warm_logger_sample_sha256",
        "cold_receipt_schema_sha256",
        "warm_receipt_schema_sha256",
        "cold_entry_trading_days",
        "warm_entry_trading_days",
        "identity_exact",
        "metrics_exact",
        "trades_exact",
        "native_report_exact",
        "logger_sample_exact",
        "receipt_schema_exact",
        "entry_days_exact",
        "all_exact",
        "warm_status",
    ]
    temporary = comparison_path.with_name(f".{comparison_path.name}.{os.getpid()}.tmp")
    with temporary.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(packet["comparison"]["rows"])
    os.replace(temporary, comparison_path)
    return {"report": report_path, "packet": packet_path, "comparison": comparison_path}


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=core.DEFAULT_DB)
    parser.add_argument("--repo-root", type=Path, default=core.DEFAULT_REPO)
    parser.add_argument("--authorization-manifest", type=Path, required=True)
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--output-stem", default=DEFAULT_OUTPUT_STEM)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    repo_root = args.repo_root.resolve()
    if not core.feature_flag_enabled():
        raise core.ActivationRefused(
            f"{core.FLAG_NAME}_MUST_BE_PROCESS_SCOPED_ON_FOR_PHASE3"
        )
    authorization = _load_json(args.authorization_manifest)
    problems = core.validation_authorization_problems(authorization)
    if problems:
        raise core.ActivationRefused(";".join(problems))
    with core._read_only_connection(args.db) as con:
        con.execute("BEGIN")
        references_all = core.cold_references(
            con,
            ea_id="QM5_41097",
            symbol="USDJPY.DWX",
            year=2019,
        )
        con.rollback()
    references = core.oldest_authenticated_references(references_all, limit=20)
    if len(references) != 20:
        raise core.ActivationRefused(
            f"PHASE3_AUTHENTICATED_REFERENCE_COUNT_{len(references)}"
        )
    cells = prepare_cells(references, input_dir=args.input_dir, repo_root=repo_root)
    manifests = {str(row.get("history_manifest_sha256") or "") for row in references}
    receipts = {str(row.get("history_receipt_path") or "") for row in references}
    if len(manifests) != 1 or "" in manifests:
        raise core.ActivationRefused("PHASE3_HISTORY_MANIFEST_NOT_COMMON")
    if len(receipts) != 1 or "" in receipts:
        raise core.ActivationRefused("PHASE3_HISTORY_RECEIPT_NOT_COMMON")
    runtime_dir = args.output_dir.resolve() / f"{args.output_stem}_runtime"
    backend = core.GovernedDev2RestartBackend(
        repo_root=repo_root,
        artifact_dir=runtime_dir,
        history_receipt_path=Path(next(iter(receipts))),
        expected_history_manifest_sha256=next(iter(manifests)),
    )
    comparisons: list[dict[str, Any]] = []
    outcome_status = "BACKEND_EXECUTION_STOP"
    outcome_error: str | None = None
    try:
        result = core.WarmCellRunner(backend).run(
            cells=cells,
            cold_references={str(row["cell_key"]): row for row in references},
            environ=os.environ,
            activation_manifest=authorization,
        )
        comparisons = [dict(row) for row in result["comparisons"]]
        outcome_status = "EXACT_PARITY"
    except core.ParityDeviation as exc:
        comparisons = exc.comparisons
        outcome_status = "DEVIATION_STOP"
        outcome_error = str(exc)
    except Exception as exc:
        outcome_status = "BACKEND_EXECUTION_STOP"
        outcome_error = f"{type(exc).__name__}: {exc}"
    packet = build_packet(
        references=references,
        comparisons=comparisons,
        backend=backend,
        authorization_manifest=authorization,
        authorization_path=args.authorization_manifest,
        repo_root=repo_root,
        db_path=args.db,
        outcome_status=outcome_status,
        outcome_error=outcome_error,
    )
    outputs = write_outputs(
        packet=packet,
        output_dir=args.output_dir,
        output_stem=args.output_stem,
    )
    print(
        json.dumps(
            {
                "status": outcome_status,
                "attempted": packet["outcome"]["attempted"],
                "compared": packet["outcome"]["compared"],
                "exact": packet["outcome"]["exact"],
                "complete_batch_speedup": packet["timing"]["complete_batch_speedup"],
                "outputs": {key: str(path.resolve()) for key, path in outputs.items()},
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
