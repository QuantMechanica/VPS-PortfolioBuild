#!/usr/bin/env python3
"""P4 Monte Carlo robustness runner."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import random
from pathlib import Path

from _phase_utils import ensure_dir


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Run P4 Monte Carlo robustness checks.")
    p.add_argument("--ea", required=True, help="EA identifier, e.g. QM5_1004")
    p.add_argument("--returns-csv", required=True, help="CSV with per-trade returns in column return_pct")
    p.add_argument("--iterations", type=int, default=1000)
    p.add_argument("--path-length", type=int, default=250)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--max-dd-cap-pct", type=float, default=20.0)
    p.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    p.add_argument("--run-tag", default="")
    return p.parse_args()


def load_returns(path: Path) -> list[float]:
    values: list[float] = []
    with path.open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            raw = (row.get("return_pct") or "").strip()
            if raw:
                values.append(float(raw))
    if not values:
        raise ValueError("returns-csv contains no return_pct values")
    return values


def max_drawdown_pct(equity_points: list[float]) -> float:
    peak = equity_points[0]
    worst = 0.0
    for v in equity_points:
        if v > peak:
            peak = v
        dd = 100.0 * (peak - v) / peak if peak > 0 else 0.0
        if dd > worst:
            worst = dd
    return worst


def short_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    args = parse_args()
    rng = random.Random(args.seed)
    returns = load_returns(Path(args.returns_csv))
    run_tag = args.run_tag.strip() or f"seed{args.seed}_n{args.iterations}"

    out_dir = ensure_dir(Path(args.out_prefix) / "P4" / args.ea / run_tag)
    mc_csv = out_dir / "mc_distribution.csv"
    paths_csv = out_dir / "equity_paths.csv"
    summary_json = out_dir / "summary.json"

    failures = 0
    dist_rows: list[dict[str, float | int]] = []
    sampled_paths: list[tuple[int, int, float]] = []

    with mc_csv.open("w", encoding="utf-8", newline="") as mc_handle:
        mc_writer = csv.DictWriter(
            mc_handle,
            fieldnames=["iteration", "final_equity", "total_return_pct", "max_dd_pct", "breach_dd_cap"],
        )
        mc_writer.writeheader()

        for i in range(1, args.iterations + 1):
            equity = 1.0
            points = [equity]
            for step in range(1, args.path_length + 1):
                r = rng.choice(returns)
                equity *= 1.0 + (r / 100.0)
                points.append(equity)
                if i <= 10:
                    sampled_paths.append((i, step, equity))

            dd_pct = max_drawdown_pct(points)
            total_ret = 100.0 * (equity - 1.0)
            breach = dd_pct > args.max_dd_cap_pct
            if breach:
                failures += 1

            row = {
                "iteration": i,
                "final_equity": round(equity, 10),
                "total_return_pct": round(total_ret, 6),
                "max_dd_pct": round(dd_pct, 6),
                "breach_dd_cap": int(breach),
            }
            mc_writer.writerow(row)
            dist_rows.append(row)

    with paths_csv.open("w", encoding="utf-8", newline="") as path_handle:
        path_writer = csv.DictWriter(path_handle, fieldnames=["iteration", "step", "equity"])
        path_writer.writeheader()
        for it, step, eq in sampled_paths:
            path_writer.writerow({"iteration": it, "step": step, "equity": round(eq, 10)})

    failure_rate = 100.0 * failures / args.iterations if args.iterations else 100.0
    verdict = "FAIL" if failure_rate > 5.0 else "PASS"
    summary = {
        "ea_id": args.ea,
        "phase": "P4",
        "run_tag": run_tag,
        "seed": args.seed,
        "iterations": args.iterations,
        "path_length": args.path_length,
        "max_dd_cap_pct": args.max_dd_cap_pct,
        "failure_count": failures,
        "failure_rate_pct": round(failure_rate, 4),
        "criterion": "MC failure if >5% iterations breach max_dd cap",
        "verdict": verdict,
        "artifacts": {
            "summary_json": str(summary_json),
            "mc_distribution_csv": str(mc_csv),
            "equity_paths_csv": str(paths_csv),
            "mc_distribution_sha256": short_hash(mc_csv),
        },
    }
    summary_json.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
