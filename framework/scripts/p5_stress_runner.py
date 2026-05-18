#!/usr/bin/env python3
"""P5 stress runner."""

from __future__ import annotations

import argparse
from pathlib import Path

from _phase_utils import (
    add_common_args,
    build_result,
    ensure_dir,
    load_json,
    parse_float,
    parse_int,
    update_result_with_evidence_path,
    write_phase_artifacts,
)


def _is_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _calibration_ready(calibration: dict, symbol: str) -> tuple[bool, str]:
    status = str(calibration.get("measurement_status", "")).upper()
    if status != "MEASURED":
        return False, "Calibration measurement status is pending; measured VPS data required for P5."

    symbols = calibration.get("symbols", {})
    symbol_data = symbols.get(symbol)
    if not isinstance(symbol_data, dict):
        return False, f"Calibration missing symbol block for {symbol}."

    required_paths = [
        ("commission_cents_per_lot",),
        ("latency_ms", "avg"),
        ("latency_ms", "p95"),
        ("slippage_points", "avg"),
        ("slippage_points", "p95"),
        ("spread_points", "median"),
        ("spread_points", "p95"),
    ]
    for path in required_paths:
        value = symbol_data
        for key in path:
            if not isinstance(value, dict) or key not in value:
                return False, f"Calibration missing required field: {'.'.join(path)} for {symbol}."
            value = value[key]
        if not _is_number(value):
            return False, f"Calibration field must be numeric: {'.'.join(path)} for {symbol}."

    return True, "Calibration readiness gate passed."


def _read_metrics(path: Path, default_symbol: str) -> dict[str, object]:
    metrics = load_json(path)
    if not isinstance(metrics, dict):
        raise ValueError(f"Metrics JSON must be an object: {path}")
    symbol = str(metrics.get("symbol", default_symbol)).strip() or default_symbol
    net_profit = None
    if "net_profit" in metrics or "total_net_profit" in metrics:
        net_profit = parse_float(metrics.get("net_profit", metrics.get("total_net_profit")))
    return {
        "symbol": symbol,
        "pf": parse_float(metrics.get("pf", metrics.get("profit_factor", 0.0))),
        "trade_count": parse_int(metrics.get("trade_count", metrics.get("trades", 0))),
        "net_profit": net_profit,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Run P5 stress gate checks.")
    add_common_args(parser)
    parser.add_argument("--symbol", default="EURUSD.DWX")
    parser.add_argument("--period", default="")
    parser.add_argument("--setfile", default="")
    parser.add_argument("--calibration-json")
    parser.add_argument("--clean-metrics-json")
    parser.add_argument("--stress-metrics-json")
    parser.add_argument("--full-history-from", default="")
    parser.add_argument("--full-history-to", default="")
    args = parser.parse_args()

    ea_id = args.ea
    out_dir = ensure_dir(Path(args.out_prefix) / ea_id / "P5")
    if not args.calibration_json or not args.clean_metrics_json or not args.stress_metrics_json:
        result = build_result(
            phase="P5",
            ea_id=ea_id,
            verdict="PENDING_IMPLEMENTATION",
            criterion="P5 stress runner is wired for cascade, but clean/stress evidence generation is pending.",
            evidence_path="",
            details={
                "symbol": args.symbol,
                "period": args.period,
                "setfile": args.setfile,
                "has_calibration_json": bool(args.calibration_json),
                "has_clean_metrics_json": bool(args.clean_metrics_json),
                "has_stress_metrics_json": bool(args.stress_metrics_json),
            },
        )
        result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P5", ea_id=ea_id, result=result)
        update_result_with_evidence_path(result_path, result)
        print(result_path)
        return 0

    calibration = load_json(Path(args.calibration_json))
    clean = _read_metrics(Path(args.clean_metrics_json), args.symbol)
    stress = _read_metrics(Path(args.stress_metrics_json), str(clean["symbol"]))
    symbol = str(stress["symbol"])

    readiness_ok, readiness_note = _calibration_ready(calibration, symbol)
    clean_pf = float(clean["pf"])
    stress_pf = float(stress["pf"])
    clean_trades = int(clean["trade_count"])
    stress_trades = int(stress["trade_count"])
    clean_net_profit = clean["net_profit"]
    stress_net_profit = stress["net_profit"]

    trade_retention_ratio = 0.0 if clean_trades <= 0 else float(stress_trades) / float(clean_trades)
    criterion = readiness_note
    verdict = "FAIL"

    if readiness_ok:
        if stress_pf <= 1.0:
            criterion = "Post-stress PF must be > 1.0."
        elif stress_net_profit is not None and float(stress_net_profit) <= 0.0:
            criterion = "Post-stress net profit must be > 0."
        elif trade_retention_ratio < 0.5:
            criterion = "Post-stress trade count must be >= 50% of clean-run trade count."
        else:
            verdict = "PASS"
            criterion = "P5 hard gates satisfied (PF > 1.0 and trade retention >= 50%)."

    result = build_result(
        phase="P5",
        ea_id=ea_id,
        verdict=verdict,
        criterion=criterion,
        evidence_path="",
        details={
            "symbol": symbol,
            "clean_run": {"pf": clean_pf, "trade_count": clean_trades, "net_profit": clean_net_profit},
            "stress_run": {"pf": stress_pf, "trade_count": stress_trades, "net_profit": stress_net_profit},
            "delta": {
                "profit_factor": stress_pf - clean_pf,
                "trade_count": stress_trades - clean_trades,
                "net_profit": (
                    float(stress_net_profit) - float(clean_net_profit)
                    if stress_net_profit is not None and clean_net_profit is not None
                    else None
                ),
            },
            "trade_retention_ratio": trade_retention_ratio,
            "full_history_window": {"from": args.full_history_from, "to": args.full_history_to},
            "calibration_ready": readiness_ok,
        },
    )

    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P5", ea_id=ea_id, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
