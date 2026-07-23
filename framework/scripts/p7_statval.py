import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict


def _write_result(output_root: Path, ea_id: str, symbol: str, payload: Dict[str, Any]) -> Path:
    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    safe_symbol = symbol.replace("/", "_")
    target_dir = output_root / ea_id / "P7"
    target_dir.mkdir(parents=True, exist_ok=True)
    out_path = target_dir / f"P7_{ea_id}_{safe_symbol}_{ts}_result.json"
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return out_path


def run_p7_statval(
    ea_id: str,
    symbol: str,
    output_root: Path,
    trade_count: int,
    pbo_pct: float,
    dsr: float,
    mc_pvalue: float,
    fdr_q: float,
) -> Dict[str, Any]:
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

    payload = {
        "phase": "P7",
        "ea_id": ea_id,
        "symbol": symbol,
        "verdict": verdict,
        "criterion": criterion,
        "details": {
            "trade_count": trade_count,
            "pbo_pct": pbo_pct,
            "dsr": dsr,
            "mc_pvalue": mc_pvalue,
            "fdr_q": fdr_q,
            "checks": checks,
        },
    }

    evidence_path = _write_result(output_root, ea_id, symbol, payload)
    payload["evidence_path"] = str(evidence_path)
    evidence_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    print(
        json.dumps(
            {
                "phase": "P7",
                "ea_id": ea_id,
                "verdict": verdict,
                "criterion": criterion,
                "evidence_path": str(evidence_path),
            }
        )
    )
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Run P7 statistical validation hard-gate checks.")
    parser.add_argument("--ea", required=True, dest="ea_id")
    parser.add_argument("--symbol", default="EURUSD.DWX")
    parser.add_argument("--output-root", default="D:/QM/reports/pipeline")
    parser.add_argument("--trade-count", required=True, type=int)
    parser.add_argument("--pbo-pct", required=True, type=float)
    parser.add_argument("--dsr", required=True, type=float)
    parser.add_argument("--mc-pvalue", required=True, type=float)
    parser.add_argument("--fdr-q", required=True, type=float)
    args = parser.parse_args()

    result = run_p7_statval(
        ea_id=args.ea_id,
        symbol=args.symbol,
        output_root=Path(args.output_root),
        trade_count=args.trade_count,
        pbo_pct=args.pbo_pct,
        dsr=args.dsr,
        mc_pvalue=args.mc_pvalue,
        fdr_q=args.fdr_q,
    )
    return 0 if result["verdict"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
