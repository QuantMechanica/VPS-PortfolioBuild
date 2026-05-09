import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict


def _is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _write_result(output_root: Path, ea_id: str, symbol: str, payload: Dict[str, Any]) -> Path:
    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    safe_symbol = symbol.replace("/", "_")
    target_dir = output_root / ea_id / "P4"
    target_dir.mkdir(parents=True, exist_ok=True)
    out_path = target_dir / f"P4_{ea_id}_{safe_symbol}_{ts}_result.json"
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return out_path


def run_p4_montecarlo(
    ea_id: str,
    symbol: str,
    output_root: Path,
    baseline_pf: float,
    baseline_max_dd_pct: float,
    mc_pf_p05: float,
    mc_net_profit_p05: float,
    mc_max_dd_pct_p95: float,
    min_pf_p05: float,
    max_dd_multiplier: float,
) -> Dict[str, Any]:
    numeric_values = {
        "baseline_pf": baseline_pf,
        "baseline_max_dd_pct": baseline_max_dd_pct,
        "mc_pf_p05": mc_pf_p05,
        "mc_net_profit_p05": mc_net_profit_p05,
        "mc_max_dd_pct_p95": mc_max_dd_pct_p95,
        "min_pf_p05": min_pf_p05,
        "max_dd_multiplier": max_dd_multiplier,
    }
    for key, value in numeric_values.items():
        if not _is_number(value):
            raise ValueError(f"{key} must be numeric.")

    verdict = "PASS"
    reasons = []

    if mc_pf_p05 < min_pf_p05:
        verdict = "FAIL"
        reasons.append(f"MC PF p05 {mc_pf_p05:.4f} < required minimum {min_pf_p05:.4f}.")

    if mc_net_profit_p05 <= 0.0:
        verdict = "FAIL"
        reasons.append(f"MC net profit p05 {mc_net_profit_p05:.2f} must be > 0.")

    allowed_dd = baseline_max_dd_pct * max_dd_multiplier
    if mc_max_dd_pct_p95 > allowed_dd:
        verdict = "FAIL"
        reasons.append(
            f"MC max DD p95 {mc_max_dd_pct_p95:.4f}% > allowed {allowed_dd:.4f}% "
            f"({baseline_max_dd_pct:.4f}% baseline * {max_dd_multiplier:.2f})."
        )

    criterion = (
        "P4 Monte Carlo hard gates satisfied."
        if verdict == "PASS"
        else " ".join(reasons)
    )

    payload = {
        "phase": "P4",
        "ea_id": ea_id,
        "verdict": verdict,
        "criterion": criterion,
        "details": {
            "symbol": symbol,
            "baseline": {
                "profit_factor": baseline_pf,
                "max_drawdown_pct": baseline_max_dd_pct,
            },
            "monte_carlo": {
                "profit_factor_p05": mc_pf_p05,
                "net_profit_p05": mc_net_profit_p05,
                "max_drawdown_pct_p95": mc_max_dd_pct_p95,
            },
            "thresholds": {
                "min_pf_p05": min_pf_p05,
                "max_dd_multiplier": max_dd_multiplier,
                "max_allowed_dd_pct": allowed_dd,
            },
        },
    }

    evidence_path = _write_result(output_root, ea_id, symbol, payload)
    payload["evidence_path"] = str(evidence_path)
    evidence_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    print(
        json.dumps(
            {
                "phase": "P4",
                "ea_id": ea_id,
                "verdict": verdict,
                "criterion": criterion,
                "evidence_path": str(evidence_path),
            }
        )
    )
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Run P4 Monte Carlo robustness gate checks.")
    parser.add_argument("--ea", required=True, dest="ea_id")
    parser.add_argument("--symbol", default="EURUSD.DWX")
    parser.add_argument("--output-root", default="D:/QM/reports/pipeline")
    parser.add_argument("--baseline-pf", type=float, required=True)
    parser.add_argument("--baseline-max-dd-pct", type=float, required=True)
    parser.add_argument("--mc-pf-p05", type=float, required=True)
    parser.add_argument("--mc-net-profit-p05", type=float, required=True)
    parser.add_argument("--mc-max-dd-pct-p95", type=float, required=True)
    parser.add_argument("--min-pf-p05", type=float, default=1.00)
    parser.add_argument("--max-dd-multiplier", type=float, default=1.50)
    args = parser.parse_args()

    result = run_p4_montecarlo(
        ea_id=args.ea_id,
        symbol=args.symbol,
        output_root=Path(args.output_root),
        baseline_pf=args.baseline_pf,
        baseline_max_dd_pct=args.baseline_max_dd_pct,
        mc_pf_p05=args.mc_pf_p05,
        mc_net_profit_p05=args.mc_net_profit_p05,
        mc_max_dd_pct_p95=args.mc_max_dd_pct_p95,
        min_pf_p05=args.min_pf_p05,
        max_dd_multiplier=args.max_dd_multiplier,
    )
    return 0 if result["verdict"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
