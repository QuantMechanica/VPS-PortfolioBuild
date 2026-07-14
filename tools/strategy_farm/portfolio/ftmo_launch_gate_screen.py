"""Screen causal FTMO challenge-launch gates for a locked portfolio.

The launch signal is derived from realized shadow-book PnL strictly before a
candidate start day. It does not alter trades after launch. Development and
validation windows are reported separately, and this tool never opens the
sealed holdout years.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import math
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence

import numpy as np

try:
    from . import ftmo_bar_governor_sim as governor
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_governor_sim as governor  # type: ignore


FeatureRow = Mapping[int, float]
Gate = Callable[[FeatureRow], bool]
LOOKBACKS = (5, 10, 20, 40, 60)


def gate_set() -> dict[str, Gate]:
    return {
        "pnl_05_pos": lambda row: row[5] > 0.0,
        "pnl_10_pos": lambda row: row[10] > 0.0,
        "pnl_20_pos": lambda row: row[20] > 0.0,
        "pnl_40_pos": lambda row: row[40] > 0.0,
        "pnl_60_pos": lambda row: row[60] > 0.0,
        "pnl_05_20_pos": lambda row: row[5] > 0.0 and row[20] > 0.0,
        "pnl_10_40_pos": lambda row: row[10] > 0.0 and row[40] > 0.0,
        "pnl_20_60_pos": lambda row: row[20] > 0.0 and row[60] > 0.0,
        "pnl_05_recovery": lambda row: row[5] > 0.0 and row[20] <= 0.0,
        "pnl_10_recovery": lambda row: row[10] > 0.0 and row[40] <= 0.0,
    }


def weighted_daily_pnl(
    grid,
    paths: Sequence[governor.GovernedTradePath],
    weights: Mapping[str, float],
) -> dict[dt.date, float]:
    output: collections.defaultdict[dt.date, float] = collections.defaultdict(float)
    local_dates = grid.tz_convert(governor.PRAGUE).date
    for path in paths:
        weight = float(weights.get(path.key, 0.0))
        if weight <= 0.0:
            continue
        day = local_dates[path.end_idx]
        output[day] += (path.exit_balance_delta - path.entry_commission) * weight
    return dict(output)


def trailing_pnl_features(
    start_days: Sequence[dt.date],
    daily_pnl: Mapping[dt.date, float],
    lookbacks: Sequence[int] = LOOKBACKS,
) -> dict[dt.date, dict[int, float]]:
    if any(value <= 0 for value in lookbacks):
        raise ValueError("lookbacks must be positive")
    output: dict[dt.date, dict[int, float]] = {}
    for start_day in start_days:
        output[start_day] = {
            int(lookback): sum(
                float(daily_pnl.get(start_day - dt.timedelta(days=offset), 0.0))
                for offset in range(1, int(lookback) + 1)
            )
            for lookback in lookbacks
        }
    return output


def has_unsealed_lookback(
    start_day: dt.date,
    sealed_years: set[int],
    lookback_days: int = max(LOOKBACKS),
) -> bool:
    return all(
        (start_day - dt.timedelta(days=offset)).year not in sealed_years
        for offset in range(1, lookback_days + 1)
    )


def summarize_subset(
    start_days: Sequence[dt.date],
    threshold_results: Sequence[governor.WindowResult],
    adverse_results: Sequence[governor.WindowResult],
    selected: Sequence[bool],
) -> dict[str, Any]:
    if not (
        len(start_days) == len(threshold_results) == len(adverse_results) == len(selected)
    ):
        raise ValueError("start days, results, and mask must have equal lengths")
    indices = [index for index, include in enumerate(selected) if include]
    threshold_counts = collections.Counter(threshold_results[index].outcome for index in indices)
    adverse_counts = collections.Counter(adverse_results[index].outcome for index in indices)
    eligible_days = [start_days[index] for index in indices]
    gaps = [
        (right - left).days
        for left, right in zip(eligible_days, eligible_days[1:])
        if left.year == right.year
    ]
    return {
        "eligible_starts": len(indices),
        "total_starts": len(start_days),
        "eligible_pct": 100.0 * len(indices) / len(start_days) if start_days else 0.0,
        "median_gap_calendar_days": float(np.median(gaps)) if gaps else None,
        "p95_gap_calendar_days": float(np.percentile(gaps, 95)) if gaps else None,
        "threshold_fill": governor.rates(threshold_counts),
        "adverse_bar_fill": governor.rates(adverse_counts),
    }


def preholdout_pass(
    development: Mapping[str, Any],
    validation: Mapping[str, Any],
    control_development: Mapping[str, Any],
    control_validation: Mapping[str, Any],
    *,
    minimum_floor_pct: float,
    minimum_improvement_pct: float,
) -> bool:
    if development["eligible_starts"] < 150 or validation["eligible_starts"] < 30:
        return False
    if development["eligible_pct"] < 15.0 or validation["eligible_pct"] < 15.0:
        return False
    comparisons = (
        (development, control_development, "threshold_fill"),
        (development, control_development, "adverse_bar_fill"),
        (validation, control_validation, "threshold_fill"),
        (validation, control_validation, "adverse_bar_fill"),
    )
    return all(
        float(candidate[fill]["pass_pct"]) >= minimum_floor_pct
        and float(candidate[fill]["pass_pct"])
        >= float(control[fill]["pass_pct"]) + minimum_improvement_pct
        for candidate, control, fill in comparisons
    )


def _simulate(
    grid,
    entries,
    start_days: Sequence[dt.date],
    *,
    weights: Mapping[str, float],
    horizon: int,
    risk_multiplier: float,
    daily_stop: float,
    full_risk_room: float,
    room_retention: float,
    threshold_fill: bool,
) -> list[governor.WindowResult]:
    return [
        governor.simulate_window(
            grid,
            entries,
            start_day=day,
            horizon_days=horizon,
            weights=weights,
            risk_multiplier=risk_multiplier,
            daily_stop=daily_stop,
            full_risk_room=full_risk_room,
            room_retention=room_retention,
            threshold_fill=threshold_fill,
        )
        for day in start_days
    ]


def _parse_ints(raw: str) -> set[int]:
    values = {int(value.strip()) for value in raw.split(",") if value.strip()}
    if not values:
        raise ValueError("year list is empty")
    return values


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"))
    parser.add_argument("--development-years", default="2018,2019,2021,2022")
    parser.add_argument("--validation-years", default="2023")
    parser.add_argument("--sealed-years", default="2017,2020,2024,2025")
    parser.add_argument("--horizon", type=int, default=30)
    parser.add_argument("--risk-multiplier", type=float, default=25.0)
    parser.add_argument("--daily-stop", type=float, default=4500.0)
    parser.add_argument("--full-risk-room", type=float, default=4000.0)
    parser.add_argument("--room-retention", type=float, default=0.2)
    parser.add_argument("--minimum-floor-pct", type=float, default=75.0)
    parser.add_argument("--minimum-improvement-pct", type=float, default=2.0)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    matching = [row for row in manifest.get("scenarios", []) if row.get("name") == args.scenario]
    if len(matching) != 1:
        parser.error(f"expected one scenario {args.scenario!r}, found {len(matching)}")
    weights = {str(key): float(value) for key, value in matching[0]["weights"].items()}
    if not math.isclose(sum(weights.values()), 1.0, rel_tol=0.0, abs_tol=1e-9):
        parser.error("scenario weights must sum to one")

    development_years = _parse_ints(args.development_years)
    validation_years = _parse_ints(args.validation_years)
    sealed_years = _parse_ints(args.sealed_years)
    if development_years & validation_years or (development_years | validation_years) & sealed_years:
        parser.error("development, validation, and sealed years must be disjoint")

    cases, bars = governor.load_cases(
        manifest,
        bar_paths=governor.default_bar_paths(args.data_root),
    )
    grid = governor.common_grid(cases)
    paths: list[governor.GovernedTradePath] = []
    for case in cases:
        symbol = str(case["symbol"]).upper()
        aligned, observed = governor.align_bars_to_grid(bars[symbol], grid)
        paths.extend(
            governor.build_trade_paths(
                case,
                grid=grid,
                aligned_bars=aligned,
                observed_bar_timestamps=observed,
                feature_bars=bars[symbol],
                excluded_years=sealed_years,
            )
        )
    entries = governor.index_entries(paths)
    all_starts = governor.valid_start_days(
        grid,
        horizon_days=args.horizon,
        excluded_years=sealed_years,
    )
    selected_years = development_years | validation_years
    start_days = [
        day
        for day in all_starts
        if day.year in selected_years and has_unsealed_lookback(day, sealed_years)
    ]
    threshold_results = _simulate(
        grid,
        entries,
        start_days,
        weights=weights,
        horizon=args.horizon,
        risk_multiplier=args.risk_multiplier,
        daily_stop=args.daily_stop,
        full_risk_room=args.full_risk_room,
        room_retention=args.room_retention,
        threshold_fill=True,
    )
    adverse_results = _simulate(
        grid,
        entries,
        start_days,
        weights=weights,
        horizon=args.horizon,
        risk_multiplier=args.risk_multiplier,
        daily_stop=args.daily_stop,
        full_risk_room=args.full_risk_room,
        room_retention=args.room_retention,
        threshold_fill=False,
    )
    daily_pnl = weighted_daily_pnl(grid, paths, weights)
    features = trailing_pnl_features(start_days, daily_pnl)

    dev_indices = [index for index, day in enumerate(start_days) if day.year in development_years]
    val_indices = [index for index, day in enumerate(start_days) if day.year in validation_years]

    def subset(indices: Sequence[int], mask: Sequence[bool]) -> dict[str, Any]:
        return summarize_subset(
            [start_days[index] for index in indices],
            [threshold_results[index] for index in indices],
            [adverse_results[index] for index in indices],
            [mask[index] for index in indices],
        )

    all_mask = [True] * len(start_days)
    control_development = subset(dev_indices, all_mask)
    control_validation = subset(val_indices, all_mask)
    candidates: list[dict[str, Any]] = []
    for name, gate in gate_set().items():
        mask = [bool(gate(features[day])) for day in start_days]
        development = subset(dev_indices, mask)
        validation = subset(val_indices, mask)
        fill_rates = [
            development["threshold_fill"]["pass_pct"],
            development["adverse_bar_fill"]["pass_pct"],
            validation["threshold_fill"]["pass_pct"],
            validation["adverse_bar_fill"]["pass_pct"],
        ]
        candidates.append(
            {
                "gate": name,
                "development": development,
                "validation": validation,
                "preholdout_score": min(float(value) for value in fill_rates),
                "preholdout_pass": preholdout_pass(
                    development,
                    validation,
                    control_development,
                    control_validation,
                    minimum_floor_pct=args.minimum_floor_pct,
                    minimum_improvement_pct=args.minimum_improvement_pct,
                ),
            }
        )

    survivors = [row for row in candidates if row["preholdout_pass"]]
    winner = max(survivors, key=lambda row: row["preholdout_score"], default=None)
    candidates.sort(key=lambda row: row["preholdout_score"], reverse=True)
    artifact = {
        "schema_version": 1,
        "status": "PREHOLDOUT_SURVIVOR" if winner else "NO_PREHOLDOUT_SURVIVOR",
        "basis": "causal_realized_shadow_book_pnl_strictly_before_challenge_start",
        "manifest": str(args.manifest),
        "scenario": args.scenario,
        "timestamp_basis": manifest.get("timestamp_basis", governor.TIMESTAMP_BASIS_UNIX_UTC),
        "selection_contract": {
            "development_years": sorted(development_years),
            "validation_years": sorted(validation_years),
            "sealed_years_unopened": sorted(sealed_years),
            "lookback_calendar_days": list(LOOKBACKS),
            "post_seal_lookback_days_excluded": max(LOOKBACKS),
            "minimum_floor_pct_each_fill_and_split": args.minimum_floor_pct,
            "minimum_improvement_pct_each_fill_and_split": args.minimum_improvement_pct,
            "minimum_development_starts": 150,
            "minimum_validation_starts": 30,
            "minimum_eligible_pct_each_split": 15.0,
            "selection_uses_sealed_years": False,
        },
        "policy": {
            "horizon_calendar_days": args.horizon,
            "risk_multiplier": args.risk_multiplier,
            "daily_stop": args.daily_stop,
            "full_risk_room": args.full_risk_room,
            "room_retention": args.room_retention,
        },
        "trade_paths": len(paths),
        "control": {
            "development": control_development,
            "validation": control_validation,
        },
        "candidate_count": len(candidates),
        "preholdout_survivor_count": len(survivors),
        "selected_winner": winner,
        "leaderboard": candidates,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "status": artifact["status"],
                "control_dev_threshold": control_development["threshold_fill"]["pass_pct"],
                "control_dev_adverse": control_development["adverse_bar_fill"]["pass_pct"],
                "control_val_threshold": control_validation["threshold_fill"]["pass_pct"],
                "control_val_adverse": control_validation["adverse_bar_fill"]["pass_pct"],
                "winner": winner["gate"] if winner else None,
                "out": str(args.out),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
