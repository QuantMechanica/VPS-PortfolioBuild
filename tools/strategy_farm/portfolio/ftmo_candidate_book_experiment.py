"""Evaluate candidate sleeves added to the current FTMO book at a safer base scale."""
from __future__ import annotations

import argparse
import collections
import csv
import json
from pathlib import Path

try:
    from .ftmo_phase1_mae import (
        START,
        bootstrap,
        bootstrap_two_phase,
        build_daily,
        load_ftmo_book,
        parse_number_list,
    )
except ImportError:  # direct script execution
    from ftmo_phase1_mae import (
        START,
        bootstrap,
        bootstrap_two_phase,
        build_daily,
        load_ftmo_book,
        parse_number_list,
    )


def parse_scenario(raw: str) -> tuple[str, list[tuple[int, str, float]]]:
    name, separator, additions_raw = raw.partition("=")
    if not name.strip():
        raise argparse.ArgumentTypeError("scenario needs a name")
    if not separator or not additions_raw.strip():
        return name.strip(), []
    additions = []
    for token in additions_raw.split(","):
        try:
            ea_raw, symbol, risk_raw = token.split(":", 2)
            ea_id = int(ea_raw.removeprefix("QM5_"))
            risk_fixed = float(risk_raw)
        except ValueError as exc:
            raise argparse.ArgumentTypeError(
                "scenario sleeves must be EA_ID:SYMBOL.DWX:RISK_FIXED"
            ) from exc
        if risk_fixed <= 0.0:
            raise argparse.ArgumentTypeError("candidate RISK_FIXED must be positive")
        additions.append((ea_id, symbol, risk_fixed))
    return name.strip(), additions


def evaluate_scenarios(
    base_book,
    scenarios,
    *,
    base_scale,
    horizons,
    seeds,
    block,
    runs,
    target_pct=10.0,
    phase2_target_pct=None,
):
    preset_scale = sum(meta["risk_fixed"] for meta in base_book.values()) / 1000.0
    if preset_scale <= 0.0:
        raise ValueError("base book scale is not positive")
    base_multiplier = base_scale / preset_scale
    results = []
    for name, additions in scenarios:
        book = {key: dict(meta) for key, meta in base_book.items()}
        for ea_id, symbol, risk_fixed in additions:
            key = (ea_id, symbol)
            if key in book:
                raise ValueError(f"candidate already exists in base book: {ea_id}/{symbol}")
            book[key] = {"risk_fixed": risk_fixed / base_multiplier, "tf": "candidate"}
        days, realized, open_mae, trade_opens, loaded, stale = build_daily(
            book, risk_multiplier=base_multiplier
        )
        if stale:
            raise ValueError(f"scenario {name} has stale streams: {stale}")
        pairs = [
            (realized.get(day, 0.0), open_mae.get(day, 0.0), trade_opens.get(day, 0))
            for day in days
        ]
        for horizon in horizons:
            counts = collections.Counter()
            for seed in seeds:
                if phase2_target_pct is None:
                    counts.update(
                        bootstrap(
                            pairs,
                            horizon,
                            block,
                            runs,
                            seed,
                            target=START * (1.0 + target_pct / 100.0),
                        )
                    )
                else:
                    counts.update(
                        bootstrap_two_phase(
                            pairs,
                            horizon,
                            block,
                            runs,
                            seed,
                            phase1_target=START * (1.0 + target_pct / 100.0),
                            phase2_target=START * (1.0 + phase2_target_pct / 100.0),
                        )
                    )
            total = sum(counts.values())
            if phase2_target_pct is None:
                daily_breach = counts["daily_breach"]
                max_breach = counts["max_breach"]
                not_reached = counts["not_reached"]
            else:
                daily_breach = counts["phase1_daily_breach"] + counts["phase2_daily_breach"]
                max_breach = counts["phase1_max_breach"] + counts["phase2_max_breach"]
                not_reached = counts["phase1_not_reached"] + counts["phase2_not_reached"]
            results.append(
                {
                    "scenario": name,
                    "mode": "two_phase" if phase2_target_pct is not None else "single_phase",
                    "target_pct": target_pct,
                    "phase2_target_pct": phase2_target_pct,
                    "base_scale": base_scale,
                    "candidate_risk_fixed_total": sum(item[2] for item in additions),
                    "candidate_sleeves": ",".join(
                        f"{ea}:{symbol}:{risk:.2f}" for ea, symbol, risk in additions
                    ),
                    "horizon_days": horizon,
                    "runs": total,
                    "seeds": ",".join(str(seed) for seed in seeds),
                    "pass_pct": counts["passed"] / total * 100.0,
                    "daily_breach_pct": daily_breach / total * 100.0,
                    "max_breach_pct": max_breach / total * 100.0,
                    "not_reached_pct": not_reached / total * 100.0,
                    "fresh_streams": len(loaded),
                }
            )
    return results


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-scale", type=float, default=2.0)
    parser.add_argument("--base-scales", help="optional comma-separated base-scale grid")
    parser.add_argument("--scenario", action="append", type=parse_scenario, required=True)
    parser.add_argument("--horizons", default="30,60,180,365")
    parser.add_argument("--seeds", default="3,7,11")
    parser.add_argument("--runs", type=int, default=2_000)
    parser.add_argument("--block", type=int, default=5)
    parser.add_argument("--target-pct", type=float, default=10.0)
    parser.add_argument("--phase2-target-pct", type=float)
    parser.add_argument("--csv", type=Path)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    if args.base_scale <= 0.0:
        parser.error("--base-scale must be positive")
    if args.target_pct <= 0.0:
        parser.error("--target-pct must be positive")
    if args.phase2_target_pct is not None and args.phase2_target_pct <= 0.0:
        parser.error("--phase2-target-pct must be positive")

    base_scales = (
        parse_number_list(args.base_scales, float, "base scales")
        if args.base_scales
        else [args.base_scale]
    )
    results = []
    base_book = load_ftmo_book()
    for base_scale in base_scales:
        results.extend(
            evaluate_scenarios(
                base_book,
                args.scenario,
                base_scale=base_scale,
                horizons=parse_number_list(args.horizons, int, "horizons"),
                seeds=parse_number_list(args.seeds, int, "seeds", allow_zero=True),
                block=args.block,
                runs=args.runs,
                target_pct=args.target_pct,
                phase2_target_pct=args.phase2_target_pct,
            )
        )
    if args.csv:
        args.csv.parent.mkdir(parents=True, exist_ok=True)
        with args.csv.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(results[0]))
            writer.writeheader()
            writer.writerows(results)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
