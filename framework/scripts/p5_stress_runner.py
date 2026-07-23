import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Tuple


def _is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _read_json(path: Path) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _calibration_ready(calibration: Dict[str, Any], symbol: str) -> Tuple[bool, str]:
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


def _write_result(output_root: Path, ea_id: str, symbol: str, payload: Dict[str, Any]) -> Path:
    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    safe_symbol = symbol.replace("/", "_")
    target_dir = output_root / ea_id / "P5"
    target_dir.mkdir(parents=True, exist_ok=True)
    out_path = target_dir / f"P5_{ea_id}_{safe_symbol}_{ts}_result.json"
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return out_path


def run_p5_stress(
    ea_id: str,
    symbol: str,
    calibration_path: Path,
    output_root: Path,
    clean_pf: float,
    stress_pf: float,
    clean_trades: int,
    stress_trades: int,
    full_history_from: str,
    full_history_to: str,
) -> Dict[str, Any]:
    calibration = _read_json(calibration_path)
    readiness_ok, readiness_note = _calibration_ready(calibration, symbol)

    trade_retention_ratio = 0.0 if clean_trades <= 0 else float(stress_trades) / float(clean_trades)
    criterion = readiness_note
    verdict = "FAIL"

    if readiness_ok:
        if stress_pf <= 1.0:
            criterion = "Post-stress PF must be > 1.0."
        elif trade_retention_ratio < 0.5:
            criterion = "Post-stress trade count must be >= 50% of clean-run trade count."
        else:
            verdict = "PASS"
            criterion = "P5 hard gates satisfied (PF > 1.0 and trade retention >= 50%)."

    details = {
        "symbol": symbol,
        "clean_run": {"pf": clean_pf, "trade_count": clean_trades},
        "stress_run": {"pf": stress_pf, "trade_count": stress_trades},
        "delta": {
            "profit_factor": stress_pf - clean_pf,
            "trade_count": stress_trades - clean_trades,
        },
        "trade_retention_ratio": trade_retention_ratio,
        "full_history_window": {"from": full_history_from, "to": full_history_to},
        "calibration_ready": readiness_ok,
    }

    payload = {
        "phase": "P5",
        "ea_id": ea_id,
        "verdict": verdict,
        "criterion": criterion,
        "details": details,
    }
    evidence_path = _write_result(output_root, ea_id, symbol, payload)
    payload["evidence_path"] = str(evidence_path)

    print(
        json.dumps(
            {
                "phase": "P5",
                "ea_id": ea_id,
                "verdict": verdict,
                "criterion": criterion,
                "evidence_path": str(evidence_path),
            }
        )
    )
    evidence_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Run P5 stress gate checks.")
    parser.add_argument("--ea", required=True, dest="ea_id")
    parser.add_argument("--symbol", default="EURUSD.DWX")
    parser.add_argument(
        "--calibration-json",
        default="framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json",
        dest="calibration_json",
    )
    parser.add_argument("--output-root", default="D:/QM/reports/pipeline")
    parser.add_argument("--clean-pf", type=float, required=True)
    parser.add_argument("--stress-pf", type=float, required=True)
    parser.add_argument("--clean-trades", type=int, required=True)
    parser.add_argument("--stress-trades", type=int, required=True)
    parser.add_argument("--full-history-from", default="")
    parser.add_argument("--full-history-to", default="")
    args = parser.parse_args()

    result = run_p5_stress(
        ea_id=args.ea_id,
        symbol=args.symbol,
        calibration_path=Path(args.calibration_json),
        output_root=Path(args.output_root),
        clean_pf=args.clean_pf,
        stress_pf=args.stress_pf,
        clean_trades=args.clean_trades,
        stress_trades=args.stress_trades,
        full_history_from=args.full_history_from,
        full_history_to=args.full_history_to,
    )
    return 0 if result["verdict"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
