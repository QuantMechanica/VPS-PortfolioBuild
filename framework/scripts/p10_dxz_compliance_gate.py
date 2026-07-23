import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict


def _write_result(output_root: Path, ea_id: str, symbol: str, payload: Dict[str, Any]) -> Path:
    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    safe_symbol = symbol.replace("/", "_")
    target_dir = output_root / ea_id / "P10"
    target_dir.mkdir(parents=True, exist_ok=True)
    out_path = target_dir / f"P10_{ea_id}_{safe_symbol}_{ts}_result.json"
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return out_path


def run_p10_dxz_compliance_gate(
    ea_id: str,
    symbol: str,
    output_root: Path,
    daily_drawdown_pct: float,
    total_drawdown_pct: float,
    daily_limit_pct: float = 5.0,
    total_limit_pct: float = 20.0,
) -> Dict[str, Any]:
    checks = {
        "daily_drawdown_within_limit": daily_drawdown_pct <= daily_limit_pct,
        "total_drawdown_within_limit": total_drawdown_pct <= total_limit_pct,
    }

    verdict = "PASS"
    criterion = "P10 DXZ compliance gate passed: daily and total drawdown within limits."
    if not checks["daily_drawdown_within_limit"] and not checks["total_drawdown_within_limit"]:
        verdict = "FAIL"
        criterion = "P10 DXZ compliance failed: daily and total drawdown limits breached."
    elif not checks["daily_drawdown_within_limit"]:
        verdict = "FAIL"
        criterion = "P10 DXZ compliance failed: daily drawdown limit breached."
    elif not checks["total_drawdown_within_limit"]:
        verdict = "FAIL"
        criterion = "P10 DXZ compliance failed: total drawdown limit breached."

    payload = {
        "phase": "P10",
        "ea_id": ea_id,
        "symbol": symbol,
        "verdict": verdict,
        "criterion": criterion,
        "details": {
            "daily_drawdown_pct": daily_drawdown_pct,
            "total_drawdown_pct": total_drawdown_pct,
            "daily_limit_pct": daily_limit_pct,
            "total_limit_pct": total_limit_pct,
            "checks": checks,
        },
    }
    evidence_path = _write_result(output_root, ea_id, symbol, payload)
    payload["evidence_path"] = str(evidence_path)
    evidence_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    print(
        json.dumps(
            {
                "phase": "P10",
                "ea_id": ea_id,
                "verdict": verdict,
                "criterion": criterion,
                "evidence_path": str(evidence_path),
            }
        )
    )
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Run P10 DXZ drawdown compliance gate.")
    parser.add_argument("--ea", required=True, dest="ea_id")
    parser.add_argument("--symbol", default="EURUSD.DWX")
    parser.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    parser.add_argument("--daily-dd-pct", required=True, type=float)
    parser.add_argument("--total-dd-pct", required=True, type=float)
    parser.add_argument("--daily-limit-pct", default=5.0, type=float)
    parser.add_argument("--total-limit-pct", default=20.0, type=float)
    args = parser.parse_args()

    result = run_p10_dxz_compliance_gate(
        ea_id=args.ea_id,
        symbol=args.symbol,
        output_root=Path(args.out_prefix),
        daily_drawdown_pct=args.daily_dd_pct,
        total_drawdown_pct=args.total_dd_pct,
        daily_limit_pct=args.daily_limit_pct,
        total_limit_pct=args.total_limit_pct,
    )
    return 0 if result["verdict"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
