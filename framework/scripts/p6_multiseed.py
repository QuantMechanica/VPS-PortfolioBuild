#!/usr/bin/env python3
"""P6 multi-seed runner."""

from __future__ import annotations

import argparse
from pathlib import Path

from _phase_utils import (
    add_common_args,
    build_result,
    ensure_dir,
    load_csv_rows,
    parse_bool_like,
    parse_float,
    parse_int,
    update_result_with_evidence_path,
    write_phase_artifacts,
)


def _parse_seed_csv(seed_csv: str) -> list[int]:
    seeds: list[int] = []
    for raw in (seed_csv or "").split(","):
        token = raw.strip()
        if token:
            seeds.append(int(token))
    return seeds


def main() -> int:
    parser = argparse.ArgumentParser(description="Run P6 multi-seed stability checks.")
    add_common_args(parser)
    parser.add_argument("--seeds-csv", required=True)
    parser.add_argument("--seeds", default="42,17,99,7,2026")
    args = parser.parse_args()

    ea_id = args.ea
    out_dir = ensure_dir(Path(args.out_prefix) / ea_id / "P6")
    requested_seeds = _parse_seed_csv(args.seeds)

    rows = load_csv_rows(Path(args.seeds_csv))
    per_seed_metrics: list[dict[str, object]] = []
    for row in rows:
        seed = parse_int(row.get("seed"), -1)
        if requested_seeds and seed not in requested_seeds:
            continue
        per_seed_metrics.append(
            {
                "seed": seed,
                "seed_pass": parse_bool_like(row.get("seed_pass", row.get("pass", row.get("verdict", "")))),
                "profit_factor": parse_float(row.get("profit_factor", row.get("pf", 0.0))),
                "trade_count": parse_int(row.get("trade_count", row.get("trades", 0))),
            }
        )

    pass_count = sum(1 for m in per_seed_metrics if bool(m["seed_pass"]))
    has_pf_below_one = any(float(m["profit_factor"]) < 1.0 for m in per_seed_metrics)

    if not per_seed_metrics:
        verdict = "MULTI_SEED_WAIVER"
        criterion = "No seed rows matched requested seeds."
    elif pass_count >= 3 and not has_pf_below_one:
        verdict = "MULTI_SEED_PASS"
        criterion = ">= 3 seeds passed and no seed has PF < 1.0."
    elif pass_count >= 3 and has_pf_below_one:
        verdict = "MULTI_SEED_FAIL"
        criterion = "Mixed seed outcome is not promotable: >= 3 seeds passed but at least one seed has PF < 1.0."
    else:
        verdict = "MULTI_SEED_FAIL"
        criterion = "< 3 seeds passed."

    result = build_result(
        phase="P6",
        ea_id=ea_id,
        verdict=verdict,
        criterion=criterion,
        evidence_path="",
        details={
            "seeds": requested_seeds,
            "pass_count": pass_count,
            "has_pf_below_one": has_pf_below_one,
            "missing_evidence_count": 0,
            "per_seed_metrics": per_seed_metrics,
        },
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P6", ea_id=ea_id, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
