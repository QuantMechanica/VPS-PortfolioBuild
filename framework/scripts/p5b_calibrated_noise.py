#!/usr/bin/env python3
"""P5b calibrated noise runner."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from _phase_utils import (
    add_common_args,
    build_result,
    ensure_dir,
    load_csv_rows,
    load_json,
    normalize_symbol,
    parse_float,
    parse_int,
    update_result_with_evidence_path,
    write_phase_artifacts,
)


REQUIRED_CALIBRATION_KEYS = {
    "measurement_status",
    "symbols",
}


def compliance_pct(breaches: list[int], allowed_breaches: int) -> float:
    total = len(breaches)
    if total == 0:
        return 0.0
    hits = sum(1 for b in breaches if b <= allowed_breaches)
    return hits / total


def extract_symbol_payload(calibration: dict, symbol_hint: str) -> tuple[str, dict]:
    symbols = calibration.get("symbols", {})
    if not isinstance(symbols, dict):
        return "", {}

    if not symbols:
        return "", {}

    if symbol_hint:
        candidates = []
        normalized = normalize_symbol(symbol_hint)
        candidates.append(symbol_hint.strip().upper())
        candidates.append(normalized)
        candidates.append(f"{normalized}.DWX")
        for candidate in candidates:
            if candidate in symbols and isinstance(symbols[candidate], dict):
                return candidate, symbols[candidate]

    first_key = next(iter(symbols.keys()))
    first_payload = symbols.get(first_key, {})
    if isinstance(first_payload, dict):
        return first_key, first_payload
    return first_key, {}


def row_float_values(rows: list[dict[str, str]], columns: tuple[str, ...]) -> list[float]:
    values: list[float] = []
    for row in rows:
        for col in columns:
            if col in row and str(row[col]).strip() != "":
                values.append(parse_float(row[col]))
                break
    return values


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate P5b calibrated-noise compliance")
    add_common_args(parser)
    parser.add_argument("--trials-csv", "--mc-trials", dest="trials_csv", required=True)
    parser.add_argument("--calibration-json", required=True)
    parser.add_argument("--symbol", default="")
    parser.add_argument("--paths", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--reject-rate-floor", type=float, default=0.001)
    parser.add_argument("--strict-threshold", type=float, default=0.70)
    parser.add_argument("--proxy-threshold", type=float, default=0.70)
    parser.add_argument("--proxy-max-breaches", type=int, default=1)
    parser.add_argument("--compliance-thresholds", default="50,60,70")
    parser.add_argument("--breach-rules", default="0,1,2")
    args = parser.parse_args()

    ea_id = args.ea
    out_dir = ensure_dir(Path(args.out_prefix) / ea_id / "P5b")

    calibration = load_json(Path(args.calibration_json))
    missing_calibration_keys = sorted(REQUIRED_CALIBRATION_KEYS - set(calibration.keys()))
    trials = load_csv_rows(Path(args.trials_csv))
    breaches = [parse_int(row.get("breach_count", row.get("breaches", 0)), 0) for row in trials]
    trial_symbol = args.symbol
    if not trial_symbol and trials:
        trial_symbol = str(trials[0].get("symbol", "")).strip()

    strict_pct = compliance_pct(breaches, 0)
    proxy_pct = compliance_pct(breaches, args.proxy_max_breaches)

    selected_symbol_key, selected_symbol_payload = extract_symbol_payload(calibration, trial_symbol)
    min_remaining_cushion_pct = selected_symbol_payload.get("min_remaining_cushion_pct")
    recovery_fraction_limit = selected_symbol_payload.get("recovery_fraction_limit")

    reject_rates = row_float_values(trials, ("reject_rate", "reject_rate_pct"))
    remaining_cushions = row_float_values(trials, ("remaining_cushion_pct",))
    recovery_fractions = row_float_values(trials, ("recovery_fraction",))

    reject_rate_floor_breached = bool(reject_rates) and any(rate < args.reject_rate_floor for rate in reject_rates)
    cushion_floor_breached = (
        min_remaining_cushion_pct is not None
        and bool(remaining_cushions)
        and any(value < parse_float(min_remaining_cushion_pct) for value in remaining_cushions)
    )
    recovery_limit_breached = (
        recovery_fraction_limit is not None
        and bool(recovery_fractions)
        and any(value > parse_float(recovery_fraction_limit) for value in recovery_fractions)
    )

    path_count = len(breaches)
    path_count_matches_default = path_count == args.paths
    trial_outcomes = []
    for idx, breach_count in enumerate(breaches, start=1):
        trial_outcomes.append(
            {
                "proxy_pass": breach_count <= args.proxy_max_breaches,
                "strict_pass": breach_count <= 0,
                "trial": idx,
                "breach_count": breach_count,
            }
        )

    if missing_calibration_keys:
        verdict = "FAIL"
        criterion = "Calibration JSON missing required keys"
    elif reject_rate_floor_breached or cushion_floor_breached or recovery_limit_breached:
        verdict = "FAIL"
        criterion = "Path risk features breached configured floors/limits"
    elif strict_pct >= args.strict_threshold:
        verdict = "PASS"
        criterion = "strict-70 compliance >= 70%"
    elif proxy_pct >= args.proxy_threshold:
        verdict = "YELLOW"
        criterion = "strict failed; proxy <=1 breach compliance >= 70%"
    else:
        verdict = "FAIL"
        criterion = "Both strict and proxy compliance failed"

    details = {
        "breach_rules": args.breach_rules,
        "calibration_measurement_status": calibration.get("measurement_status", "UNKNOWN"),
        "calibration_missing_keys": missing_calibration_keys,
        "compliance_thresholds": args.compliance_thresholds,
        "configured_paths": args.paths,
        "configured_seed": args.seed,
        "min_remaining_cushion_pct": min_remaining_cushion_pct,
        "path_count": path_count,
        "path_count_matches_default": path_count_matches_default,
        "proxy_compliance_pct": round(proxy_pct, 6),
        "proxy_max_breaches": args.proxy_max_breaches,
        "proxy_threshold": args.proxy_threshold,
        "recovery_fraction_limit": recovery_fraction_limit,
        "recovery_limit_breached": recovery_limit_breached,
        "reject_rate_floor": args.reject_rate_floor,
        "reject_rate_floor_breached": reject_rate_floor_breached,
        "remaining_cushion_floor_breached": cushion_floor_breached,
        "selected_symbol_key": selected_symbol_key,
        "strict_compliance_pct": round(strict_pct, 6),
        "strict_threshold": args.strict_threshold,
        "trial_outcomes": trial_outcomes,
        "trials_with_recovery_fraction": len(recovery_fractions),
        "trials_with_reject_rate": len(reject_rates),
        "trials_with_remaining_cushion": len(remaining_cushions),
    }

    result = build_result(
        phase="P5b",
        ea_id=ea_id,
        verdict=verdict,
        criterion=criterion,
        evidence_path="",
        details=details,
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P5b", ea_id=ea_id, result=result)
    update_result_with_evidence_path(result_path, result)
    report_path = out_dir / "report.csv"
    with report_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["trial", "breach_count", "strict_pass", "proxy_pass", "dxz_verdict"],
        )
        writer.writeheader()
        for item in trial_outcomes:
            writer.writerow(
                {
                    "trial": item["trial"],
                    "breach_count": item["breach_count"],
                    "strict_pass": item["strict_pass"],
                    "proxy_pass": item["proxy_pass"],
                    "dxz_verdict": "SOFT_SIGNAL_ONLY",
                }
            )
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
