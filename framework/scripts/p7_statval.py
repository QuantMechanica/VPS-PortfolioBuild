#!/usr/bin/env python3
"""P7 statistical validation runner."""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from _phase_utils import (
    add_common_args,
    build_result,
    ensure_dir,
    load_csv_rows,
    parse_float,
    parse_int,
    update_result_with_evidence_path,
    write_phase_artifacts,
)


def _first_metric(rows: list[dict[str, str]], keys: tuple[str, ...], default_num: float = 0.0) -> float:
    for row in rows:
        for key in keys:
            if key in row and str(row[key]).strip() != "":
                return parse_float(row[key], default_num)
    return default_num


def _has_metric(rows: list[dict[str, str]], keys: tuple[str, ...]) -> bool:
    for row in rows:
        for key in keys:
            if key in row and str(row[key]).strip() != "":
                return True
    return False


def _seed_pass_count(rows: list[dict[str, str]]) -> tuple[int, int]:
    pass_count = 0
    seed_count = 0
    for row in rows:
        raw = str(row.get("seed_pass") or "").strip().upper()
        if not raw:
            continue
        seed_count += 1
        if raw in {"PASS", "1", "TRUE", "YES"}:
            pass_count += 1
    return pass_count, seed_count


def _binomial_upper_tail(pass_count: int, seed_count: int) -> float:
    if seed_count <= 0:
        return 1.0
    return sum(math.comb(seed_count, k) for k in range(pass_count, seed_count + 1)) / (2 ** seed_count)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run P7 statistical validation hard-gate checks.")
    add_common_args(parser)
    parser.add_argument("--sweep-pass-rows", required=True)
    parser.add_argument("--multiseed-rows", required=True)
    args = parser.parse_args()

    ea_id = args.ea
    out_dir = ensure_dir(Path(args.out_prefix) / ea_id / "P7")

    sweep_rows = load_csv_rows(Path(args.sweep_pass_rows))
    multiseed_rows = load_csv_rows(Path(args.multiseed_rows))

    if any(str(row.get("proxy_only") or "").strip().upper() in {"1", "TRUE", "YES"} for row in sweep_rows):
        result = build_result(
            phase="P7",
            ea_id=args.ea,
            verdict="WAITING_INPUT",
            criterion="P7 requires real statistical metrics; proxy pass-row counts are not accepted.",
            evidence_path="",
            details={"sweep_pass_rows": str(Path(args.sweep_pass_rows)), "multiseed_rows": str(Path(args.multiseed_rows))},
        )
        result_path, _ = write_phase_artifacts(out_dir=ensure_dir(Path(args.out_prefix) / args.ea / "P7"), phase="P7", ea_id=args.ea, result=result)
        update_result_with_evidence_path(result_path, result)
        print(result_path)
        return 0

    trade_count = parse_int(_first_metric(sweep_rows, ("trade_count", "trades", "T"), 0.0), 0)
    if not _has_metric(sweep_rows, ("trade_count", "trades", "T")):
        result = build_result(
            phase="P7",
            ea_id=args.ea,
            verdict="WAITING_INPUT",
            criterion="P7 requires real trade_count/T metric; missing statistical evidence.",
            evidence_path="",
            details={"sweep_pass_rows": str(Path(args.sweep_pass_rows)), "multiseed_rows": str(Path(args.multiseed_rows))},
        )
        result_path, _ = write_phase_artifacts(out_dir=ensure_dir(Path(args.out_prefix) / args.ea / "P7"), phase="P7", ea_id=args.ea, result=result)
        update_result_with_evidence_path(result_path, result)
        print(result_path)
        return 0
    pbo_pct = _first_metric(sweep_rows, ("pbo_pct", "pbo", "PBO"), 100.0)
    dsr = _first_metric(sweep_rows, ("dsr", "DSR"), -1.0)
    mc_keys = ("mc_pvalue", "mc_p", "pvalue")
    fdr_keys = ("fdr_q", "fdr", "q_value")
    if _has_metric(multiseed_rows, mc_keys):
        mc_pvalue = _first_metric(multiseed_rows, mc_keys, 1.0)
    else:
        pass_count, seed_count = _seed_pass_count(multiseed_rows)
        mc_pvalue = _binomial_upper_tail(pass_count, seed_count)
    if _has_metric(multiseed_rows, fdr_keys):
        fdr_q = _first_metric(multiseed_rows, fdr_keys, 1.0)
    else:
        fdr_q = min(1.0, mc_pvalue * 2.0)

    checks = {
        "sample_size_t_ge_200": trade_count >= 200,
        "pbo_lt_5pct": pbo_pct < 5.0,
        "dsr_gt_0": dsr > 0.0,
        "mc_pvalue_lt_0_05": mc_pvalue < 0.05,
        "fdr_q_lt_0_10": fdr_q < 0.10,
    }

    verdict = "PASS"
    criterion = "P7 hard gates satisfied."
    if not checks["sample_size_t_ge_200"]:
        verdict = "FAIL"
        criterion = "Sample-size guard failed: T < 200."
    elif not checks["pbo_lt_5pct"]:
        verdict = "FAIL"
        criterion = "PBO hard gate failed: PBO must be < 5%."
    elif not checks["dsr_gt_0"]:
        verdict = "FAIL"
        criterion = "DSR hard gate failed: DSR must be > 0."
    elif not checks["mc_pvalue_lt_0_05"]:
        verdict = "FAIL"
        criterion = "MC permutation hard gate failed: p-value must be < 0.05."
    elif not checks["fdr_q_lt_0_10"]:
        verdict = "FAIL"
        criterion = "FDR hard gate failed: q-value must be < 0.10."

    result = build_result(
        phase="P7",
        ea_id=ea_id,
        verdict=verdict,
        criterion=criterion,
        evidence_path="",
        details={
            "trade_count": trade_count,
            "pbo_pct": pbo_pct,
            "dsr": dsr,
            "mc_pvalue": mc_pvalue,
            "fdr_q": fdr_q,
            "checks": checks,
        },
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P7", ea_id=ea_id, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
