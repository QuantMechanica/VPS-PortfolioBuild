#!/usr/bin/env python3
"""Generate deterministic P5b Monte Carlo trial CSV from smoke+calibration inputs."""

from __future__ import annotations

import argparse
import csv
import random
from pathlib import Path

from _phase_utils import ensure_dir, load_json, normalize_symbol, parse_float


def _noise_breach_count(rng: random.Random, *, latency_ms_p95: float, slippage_p95: float, spread_p95: float) -> int:
    score = (latency_ms_p95 / 250.0) + (slippage_p95 / 12.0) + (spread_p95 / 35.0)
    jitter = rng.uniform(-0.35, 0.35)
    final = score + jitter
    if final < 0.95:
        return 0
    if final < 1.45:
        return 1
    return 2


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--calibration-json", required=True)
    ap.add_argument("--paths", type=int, default=200)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    args = ap.parse_args()

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P5b")
    cal = load_json(Path(args.calibration_json))
    symbol_key = args.symbol if args.symbol in cal.get("symbols", {}) else f"{normalize_symbol(args.symbol)}.DWX"
    block = cal.get("symbols", {}).get(symbol_key, {})

    latency_p95 = parse_float(block.get("latency_ms", {}).get("p95", 0.0))
    slippage_p95 = parse_float(block.get("slippage_points", {}).get("p95", 0.0))
    spread_p95 = parse_float(block.get("spread_points", {}).get("p95", 0.0))
    rng = random.Random(args.seed)

    trials_path = out_dir / "p5b_trials.csv"
    with trials_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["symbol", "trial", "breach_count", "reject_rate", "remaining_cushion_pct", "recovery_fraction"],
        )
        writer.writeheader()
        for i in range(1, args.paths + 1):
            breach = _noise_breach_count(
                rng,
                latency_ms_p95=latency_p95,
                slippage_p95=slippage_p95,
                spread_p95=spread_p95,
            )
            writer.writerow(
                {
                    "symbol": args.symbol,
                    "trial": i,
                    "breach_count": breach,
                    "reject_rate": round(0.002 + (0.0007 * breach) + rng.uniform(-0.0004, 0.0004), 6),
                    "remaining_cushion_pct": round(max(0.0, 0.35 - 0.08 * breach + rng.uniform(-0.02, 0.02)), 6),
                    "recovery_fraction": round(min(1.0, 0.45 + 0.18 * breach + rng.uniform(-0.03, 0.03)), 6),
                }
            )

    print(trials_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
