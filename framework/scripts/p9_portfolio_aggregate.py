#!/usr/bin/env python3
"""P9 portfolio aggregate DXZ compliance runner."""

from __future__ import annotations

import argparse
from pathlib import Path

from _phase_utils import build_result, ensure_dir, load_json, update_result_with_evidence_path, write_phase_artifacts
from portfolio_aggregate_gate import check_portfolio_aggregate_compliance


def main() -> int:
    parser = argparse.ArgumentParser(description="Run P9 portfolio aggregate DXZ gate.")
    parser.add_argument("--ea", required=True, help="EA id for artifact routing (portfolio gate owner key)")
    parser.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    parser.add_argument("--basket-json", required=True)
    parser.add_argument("--daily-dd-threshold-pct", type=float, default=5.0)
    parser.add_argument("--total-dd-threshold-pct", type=float, default=20.0)
    parser.add_argument("--correlation-warn-threshold", type=float, default=0.7)
    args = parser.parse_args()

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P9")
    basket = load_json(Path(args.basket_json))
    payload = check_portfolio_aggregate_compliance(
        basket,
        daily_dd_threshold_pct=args.daily_dd_threshold_pct,
        total_dd_threshold_pct=args.total_dd_threshold_pct,
        correlation_warn_threshold=args.correlation_warn_threshold,
        evidence_path=out_dir / "portfolio_aggregate_evidence.json",
    )

    verdict = "PASS" if payload["verdict"] == "BASKET_PASS" else "FAIL"
    result = build_result(
        phase="P9",
        ea_id=args.ea,
        verdict=verdict,
        criterion=f"P9 portfolio gate {payload['verdict']}",
        evidence_path="",
        details=payload,
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P9", ea_id=args.ea, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0 if verdict == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
