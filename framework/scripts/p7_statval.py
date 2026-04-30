#!/usr/bin/env python3
"""P7 statistical validation runner."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

from _phase_utils import (
    add_common_args,
    build_result,
    ensure_dir,
    load_csv_rows,
    load_json,
    parse_float,
    parse_int,
    update_result_with_evidence_path,
    write_phase_artifacts,
)


METRIC_KEYS: dict[str, tuple[str, ...]] = {
    "pbo": ("pbo", "pbo_prob", "pbo_probability"),
    "dsr": ("dsr", "deflated_sharpe", "deflated_sharpe_ratio"),
    "mc_pvalue": ("mc_pvalue", "mc_p_value", "permutation_pvalue", "mc_permutation_pvalue"),
    "fdr_qvalue": ("fdr_qvalue", "fdr_q_value", "fdr_q", "bh_qvalue"),
    "sample_size": ("sample_size", "trades", "trade_count", "t"),
}


def _try_float(value: Any) -> float | None:
    if value is None:
        return None
    text = str(value).strip()
    if text == "":
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _try_int(value: Any) -> int | None:
    if value is None:
        return None
    text = str(value).strip()
    if text == "":
        return None
    try:
        return int(float(text))
    except ValueError:
        return None


def _trueish(value: Any) -> bool:
    return str(value or "").strip().lower() in {"1", "true", "yes", "pass", "selected"}


def _select_sweep_row(rows: list[dict[str, str]]) -> tuple[dict[str, str] | None, str]:
    if not rows:
        return None, "NO_SWEEP_ROWS"

    for flag in ("selected", "is_selected", "chosen"):
        flagged = [row for row in rows if _trueish(row.get(flag))]
        if flagged:
            return flagged[0], f"FLAG:{flag}"

    ranked: list[tuple[int, dict[str, str]]] = []
    for row in rows:
        rank_value = _try_int(row.get("rank"))
        if rank_value is not None:
            ranked.append((rank_value, row))
    if ranked:
        ranked.sort(key=lambda item: item[0])
        return ranked[0][1], "MIN_RANK"

    return rows[0], "FIRST_ROW"


def _extract_metric(
    metric_name: str,
    *,
    sweep_row: dict[str, str] | None,
    multiseed_rows: list[dict[str, str]],
) -> tuple[float | None, str | None]:
    keys = METRIC_KEYS[metric_name]
    if sweep_row is not None:
        for key in keys:
            value = _try_float(sweep_row.get(key))
            if value is not None:
                return value, f"sweep:{key}"

    for row_index, row in enumerate(multiseed_rows):
        for key in keys:
            value = _try_float(row.get(key))
            if value is not None:
                return value, f"multiseed[{row_index}]:{key}"

    return None, None


def _derive_sample_size(
    *,
    sweep_row: dict[str, str] | None,
    multiseed_rows: list[dict[str, str]],
) -> tuple[int | None, str | None]:
    if sweep_row is not None:
        for key in METRIC_KEYS["sample_size"]:
            value = _try_int(sweep_row.get(key))
            if value is not None:
                return value, f"sweep:{key}"

    totals: list[int] = []
    for row_index, row in enumerate(multiseed_rows):
        for key in METRIC_KEYS["sample_size"]:
            value = _try_int(row.get(key))
            if value is not None:
                totals.append(value)
                break
        else:
            continue
        # Keep source deterministic while still using aggregate evidence.
        source = f"multiseed_sum_up_to_row_{row_index}"
    if totals:
        return sum(totals), source

    return None, None


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate P7 statistical validation verdict")
    add_common_args(parser)
    parser.add_argument("--sweep-pass-rows", required=False)
    parser.add_argument("--multiseed-rows", required=False)
    parser.add_argument("--stats-json", required=False)
    args = parser.parse_args()
    if bool(args.stats_json) == bool(args.sweep_pass_rows):
        parser.error("Provide exactly one of --stats-json or --sweep-pass-rows.")
    if args.sweep_pass_rows and not args.multiseed_rows:
        parser.error("--multiseed-rows is required when --sweep-pass-rows is provided.")
    if args.multiseed_rows and not args.sweep_pass_rows:
        parser.error("--sweep-pass-rows is required when --multiseed-rows is provided.")

    ea_id = args.ea
    out_dir = ensure_dir(Path(args.out_prefix) / ea_id / "P7")

    selection_basis = "STATS_JSON"
    sweep_row: dict[str, str] | None = None
    multiseed_rows: list[dict[str, str]] = []
    metric_values: dict[str, float | None] = {}
    metric_sources: dict[str, str | None] = {}

    if args.stats_json:
        stats = load_json(Path(args.stats_json))
        sample_size = parse_int(stats.get("sample_size", stats.get("trades")), 0)
        metric_values = {
            "pbo": parse_float(stats.get("pbo", 1.0)),
            "dsr": parse_float(stats.get("dsr", -1.0)),
            "mc_pvalue": parse_float(stats.get("mc_pvalue", 1.0)),
            "fdr_qvalue": parse_float(stats.get("fdr_qvalue", 1.0)),
        }
        metric_sources = {
            "pbo": "stats_json:pbo",
            "dsr": "stats_json:dsr",
            "mc_pvalue": "stats_json:mc_pvalue",
            "fdr_qvalue": "stats_json:fdr_qvalue",
            "sample_size": "stats_json:sample_size_or_trades",
        }
    else:
        sweep_rows = load_csv_rows(Path(args.sweep_pass_rows))
        multiseed_rows = load_csv_rows(Path(args.multiseed_rows))
        sweep_row, selection_basis = _select_sweep_row(sweep_rows)

        for metric in ("pbo", "dsr", "mc_pvalue", "fdr_qvalue"):
            value, source = _extract_metric(metric, sweep_row=sweep_row, multiseed_rows=multiseed_rows)
            metric_values[metric] = value
            metric_sources[metric] = source

        sample_size, sample_source = _derive_sample_size(sweep_row=sweep_row, multiseed_rows=multiseed_rows)
        metric_sources["sample_size"] = sample_source

    gate_status = {
        "pbo_lt_5pct": metric_values["pbo"] is not None and metric_values["pbo"] < 0.05,
        "dsr_gt_0": metric_values["dsr"] is not None and metric_values["dsr"] > 0.0,
        "mc_pvalue_lt_0_05": metric_values["mc_pvalue"] is not None and metric_values["mc_pvalue"] < 0.05,
        "fdr_qvalue_lt_0_10": metric_values["fdr_qvalue"] is not None and metric_values["fdr_qvalue"] < 0.10,
    }

    missing_metrics = [name for name in ("pbo", "dsr", "mc_pvalue", "fdr_qvalue") if metric_values[name] is None]
    sample_guard_failed = sample_size is None or sample_size < 200
    pbo_hard_gate_failed = not gate_status["pbo_lt_5pct"]

    if sample_guard_failed:
        verdict = "FAIL"
        criterion = "Sample-size guard failed: T >= 200 required"
    elif missing_metrics:
        verdict = "FAIL"
        criterion = "Missing required statistical metric(s)"
    elif pbo_hard_gate_failed:
        verdict = "FAIL"
        criterion = "PBO hard gate failed (requires < 5%)"
    elif all(gate_status.values()):
        verdict = "PASS"
        criterion = "All four statistical gates passed"
    else:
        verdict = "FAIL"
        criterion = "At least one non-PBO statistical gate failed"

    details = {
        "gate_status": gate_status,
        "missing_metrics": missing_metrics,
        "metric_sources": metric_sources,
        "metrics": {
            "dsr": metric_values["dsr"],
            "fdr_qvalue": metric_values["fdr_qvalue"],
            "mc_pvalue": metric_values["mc_pvalue"],
            "pbo": metric_values["pbo"],
            "sample_size": sample_size,
        },
        "pbo_hard_gate_failed": pbo_hard_gate_failed,
        "sample_guard_failed": sample_guard_failed,
        "selection_basis": selection_basis,
        "sources": {
            "multiseed_rows": str(Path(args.multiseed_rows)) if args.multiseed_rows else None,
            "stats_json": str(Path(args.stats_json)) if args.stats_json else None,
            "sweep_pass_rows": str(Path(args.sweep_pass_rows)) if args.sweep_pass_rows else None,
        },
    }

    result = build_result(
        phase="P7",
        ea_id=ea_id,
        verdict=verdict,
        criterion=criterion,
        evidence_path="",
        details=details,
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P7", ea_id=ea_id, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
