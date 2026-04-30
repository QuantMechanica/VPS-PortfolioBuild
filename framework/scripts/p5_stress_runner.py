#!/usr/bin/env python3
"""P5 stress verdict runner from clean/stress metrics inputs."""

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


REQUIRED_CALIBRATION_KEYS = {
    "measurement_status",
    "symbols",
}

REQUIRED_SYMBOL_CALIBRATION_PATHS = (
    ("commission_cents_per_lot",),
    ("latency_ms", "avg"),
    ("latency_ms", "p95"),
    ("slippage_points", "avg"),
    ("slippage_points", "p95"),
    ("spread_points", "median"),
    ("spread_points", "p95"),
)

PENDING_MEASUREMENT_TOKENS = {
    "",
    "PENDING",
    "PENDING_MEASUREMENT",
    "TODO",
    "TBD",
    "UNKNOWN",
}


def metric(payload: dict, key: str, fallback_key: str | None = None) -> float:
    if key in payload:
        return parse_float(payload[key])
    if fallback_key and fallback_key in payload:
        return parse_float(payload[fallback_key])
    return 0.0


def nested_value(payload: dict, path: tuple[str, ...]) -> object:
    current: object = payload
    for part in path:
        if not isinstance(current, dict) or part not in current:
            return None
        current = current[part]
    return current


def numeric_like(value: object) -> bool:
    try:
        parse_float(value)
    except (TypeError, ValueError):
        return False
    return True


def validate_calibration(calibration: dict) -> tuple[list[str], bool]:
    issues: list[str] = []
    measurement_status = str(calibration.get("measurement_status", "")).strip().upper()
    status_ready = measurement_status not in PENDING_MEASUREMENT_TOKENS

    symbols = calibration.get("symbols")
    if not isinstance(symbols, dict) or not symbols:
        issues.append("symbols map missing or empty")
        return issues, status_ready

    for symbol, payload in symbols.items():
        if not isinstance(payload, dict):
            issues.append(f"{symbol}: calibration payload is not an object")
            continue
        for path in REQUIRED_SYMBOL_CALIBRATION_PATHS:
            value = nested_value(payload, path)
            if value is None:
                issues.append(f"{symbol}: missing {'.'.join(path)}")
            elif not numeric_like(value):
                issues.append(f"{symbol}: non-numeric {'.'.join(path)}")
    return issues, status_ready


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate P5 stress verdict")
    add_common_args(parser)
    parser.add_argument("--calibration-json", required=True)
    parser.add_argument("--clean-metrics-json", required=True)
    parser.add_argument("--stress-metrics-json", required=True)
    parser.add_argument("--full-history-from", default="")
    parser.add_argument("--full-history-to", default="")
    parser.add_argument("--stress-profile", default="HARSH")
    args = parser.parse_args()

    ea_id = args.ea
    out_dir = ensure_dir(Path(args.out_prefix) / ea_id / "P5")

    calibration = load_json(Path(args.calibration_json))
    missing_keys = sorted(REQUIRED_CALIBRATION_KEYS - set(calibration.keys()))
    calibration_issues, status_ready = validate_calibration(calibration)
    calibration_ready = (not missing_keys) and status_ready and (not calibration_issues)

    clean = load_json(Path(args.clean_metrics_json))
    stress = load_json(Path(args.stress_metrics_json))

    clean_pf = metric(clean, "profit_factor", "pf")
    stress_pf = metric(stress, "profit_factor", "pf")
    clean_trades = parse_int(clean.get("trades"), 0)
    stress_trades = parse_int(stress.get("trades"), 0)
    clean_sharpe = metric(clean, "sharpe")
    stress_sharpe = metric(stress, "sharpe")
    clean_dd = metric(clean, "drawdown_pct")
    stress_dd = metric(stress, "drawdown_pct")
    drawdown_delta_pct = stress_dd - clean_dd
    pf_delta = stress_pf - clean_pf

    retention = (stress_trades / clean_trades) if clean_trades > 0 else 0.0
    pf_ok = stress_pf > 1.0
    retention_ok = retention >= 0.5

    if missing_keys:
        verdict = "FAIL"
        criterion = "Calibration JSON missing required keys"
    elif not status_ready:
        verdict = "FAIL"
        criterion = "Calibration measurement status is pending; measured VPS data required for P5"
    elif calibration_issues:
        verdict = "FAIL"
        criterion = "Calibration JSON missing required per-symbol numeric fields"
    elif pf_ok and retention_ok:
        verdict = "PASS"
        criterion = "Post-stress PF > 1.0 and trade retention >= 50%"
    else:
        verdict = "FAIL"
        criterion = "P5 acceptance failed (PF <= 1.0 or trade retention < 50%)"

    details = {
        "calibration_issue_count": len(calibration_issues),
        "calibration_issues": calibration_issues,
        "calibration_measurement_status": str(calibration.get("measurement_status", "UNKNOWN")),
        "calibration_missing_keys": missing_keys,
        "calibration_ready": calibration_ready,
        "calibration_symbol_count": len(calibration.get("symbols", {}))
        if isinstance(calibration.get("symbols"), dict)
        else 0,
        "clean": {
            "drawdown_pct": clean_dd,
            "profit_factor": clean_pf,
            "sharpe": clean_sharpe,
            "trades": clean_trades,
        },
        "stress": {
            "drawdown_pct": stress_dd,
            "profit_factor": stress_pf,
            "sharpe": stress_sharpe,
            "trades": stress_trades,
        },
        "delta": {
            "drawdown_pct": round(drawdown_delta_pct, 6),
            "profit_factor": round(pf_delta, 6),
            "trade_count": stress_trades - clean_trades,
        },
        "full_history_window": {
            "from": args.full_history_from,
            "to": args.full_history_to,
        },
        "stress_profile": args.stress_profile,
        "trade_retention": round(retention, 6),
        "trade_retention_ok": retention_ok,
        "stress_pf_ok": pf_ok,
    }

    result = build_result(
        phase="P5",
        ea_id=ea_id,
        verdict=verdict,
        criterion=criterion,
        evidence_path="",
        details=details,
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P5", ea_id=ea_id, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
