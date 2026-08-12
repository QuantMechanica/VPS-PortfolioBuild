"""Screen causal market-regime gates for launching a locked FTMO book."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence

import numpy as np
import pandas as pd

try:
    from . import ftmo_bar_governor_sim as governor
    from .ftmo_calendar_launch_gate_screen import preholdout_pass
    from .ftmo_launch_gate_screen import _parse_ints, _simulate, summarize_subset
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_governor_sim as governor  # type: ignore
    from ftmo_calendar_launch_gate_screen import preholdout_pass  # type: ignore
    from ftmo_launch_gate_screen import _parse_ints, _simulate, summarize_subset  # type: ignore


CORE_SYMBOLS = ("NDX.DWX", "XAUUSD.DWX", "USDJPY.DWX", "XTIUSD.DWX")
FeatureRow = Mapping[str, Mapping[str, float]]
MarketGate = Callable[[FeatureRow], bool]


def market_features(
    start_day: dt.date,
    bars_by_symbol: Mapping[str, pd.DataFrame],
    symbols: Sequence[str] = CORE_SYMBOLS,
) -> dict[str, dict[str, float]] | None:
    start = governor._local_midnight_utc(start_day)
    output: dict[str, dict[str, float]] = {}
    for symbol in symbols:
        bars = bars_by_symbol[symbol]
        position = int(bars.index.searchsorted(start, side="left"))
        history = bars.iloc[max(0, position - 1921) : position]
        if len(history) < 1921 or history[["high", "low", "close"]].isna().any().any():
            return None
        closes = history["close"].to_numpy(dtype=float)
        ranges = (history["high"] - history["low"]).to_numpy(dtype=float)
        if closes[-1] <= 0.0 or closes[-481] <= 0.0 or closes[-1921] <= 0.0:
            return None
        prior_range = float(np.mean(ranges[-1920:-480]))
        recent_range = float(np.mean(ranges[-480:]))
        if not math.isfinite(prior_range) or prior_range <= 0.0:
            return None
        output[symbol] = {
            "return_5d": float(closes[-1] / closes[-481] - 1.0),
            "return_20d": float(closes[-1] / closes[-1921] - 1.0),
            "volatility_ratio": recent_range / prior_range,
        }
    return output


def market_gate_set() -> dict[str, MarketGate]:
    gates: dict[str, MarketGate] = {}
    for symbol in CORE_SYMBOLS:
        prefix = symbol.split(".")[0].lower()
        gates[f"{prefix}_20d_up"] = lambda row, symbol=symbol: row[symbol]["return_20d"] > 0.0
        gates[f"{prefix}_20d_down"] = lambda row, symbol=symbol: row[symbol]["return_20d"] < 0.0
        gates[f"{prefix}_trend_consensus_up"] = (
            lambda row, symbol=symbol: row[symbol]["return_5d"] > 0.0
            and row[symbol]["return_20d"] > 0.0
        )
        gates[f"{prefix}_trend_consensus_down"] = (
            lambda row, symbol=symbol: row[symbol]["return_5d"] < 0.0
            and row[symbol]["return_20d"] < 0.0
        )
        gates[f"{prefix}_volatility_active"] = (
            lambda row, symbol=symbol: row[symbol]["volatility_ratio"] >= 1.0
        )
        gates[f"{prefix}_volatility_calm"] = (
            lambda row, symbol=symbol: row[symbol]["volatility_ratio"] < 1.0
        )
    gates.update(
        {
            "risk_on_ndx_usdjpy_up": lambda row: row["NDX.DWX"]["return_20d"] > 0.0
            and row["USDJPY.DWX"]["return_20d"] > 0.0,
            "defensive_ndx_down_xau_up": lambda row: row["NDX.DWX"]["return_20d"] < 0.0
            and row["XAUUSD.DWX"]["return_20d"] > 0.0,
            "inflation_xau_xti_up": lambda row: row["XAUUSD.DWX"]["return_20d"] > 0.0
            and row["XTIUSD.DWX"]["return_20d"] > 0.0,
            "disinflation_xau_xti_down": lambda row: row["XAUUSD.DWX"]["return_20d"] < 0.0
            and row["XTIUSD.DWX"]["return_20d"] < 0.0,
            "usd_strength_usdjpy_up_xau_down": lambda row: row["USDJPY.DWX"]["return_20d"]
            > 0.0
            and row["XAUUSD.DWX"]["return_20d"] < 0.0,
            "usd_weak_usdjpy_down_xau_up": lambda row: row["USDJPY.DWX"]["return_20d"] < 0.0
            and row["XAUUSD.DWX"]["return_20d"] > 0.0,
        }
    )
    return gates


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--scenario", required=True)
    parser.add_argument(
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--development-years", default="2018,2019,2021,2022")
    parser.add_argument("--validation-years", default="2023")
    parser.add_argument("--sealed-years", default="2017,2020,2024,2025")
    parser.add_argument("--horizon", type=int, default=30)
    parser.add_argument("--risk-multiplier", type=float, default=25.0)
    parser.add_argument("--daily-stop", type=float, default=4500.0)
    parser.add_argument("--full-risk-room", type=float, default=4000.0)
    parser.add_argument("--room-retention", type=float, default=0.2)
    parser.add_argument("--minimum-floor-pct", type=float, default=60.0)
    parser.add_argument("--minimum-improvement-pct", type=float, default=5.0)
    parser.add_argument("--minimum-development-starts", type=int, default=150)
    parser.add_argument("--minimum-validation-starts", type=int, default=30)
    parser.add_argument("--minimum-eligible-pct", type=float, default=15.0)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    matching = [
        row for row in manifest.get("scenarios", []) if row.get("name") == args.scenario
    ]
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
    missing_symbols = sorted(set(CORE_SYMBOLS) - set(bars))
    if missing_symbols:
        parser.error(f"missing core market bars: {missing_symbols}")
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
    selected_years = development_years | validation_years
    candidate_starts = [
        day
        for day in governor.valid_start_days(
            grid,
            horizon_days=args.horizon,
            excluded_years=sealed_years,
        )
        if day.year in selected_years
    ]
    feature_rows = {day: market_features(day, bars) for day in candidate_starts}
    start_days = [day for day in candidate_starts if feature_rows[day] is not None]
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
    dev_indices = [index for index, day in enumerate(start_days) if day.year in development_years]
    val_indices = [index for index, day in enumerate(start_days) if day.year in validation_years]

    def subset(indices: Sequence[int], mask: Sequence[bool]) -> dict[str, Any]:
        return summarize_subset(
            [start_days[index] for index in indices],
            [threshold_results[index] for index in indices],
            [adverse_results[index] for index in indices],
            [mask[index] for index in indices],
        )

    control_mask = [True] * len(start_days)
    control_development = subset(dev_indices, control_mask)
    control_validation = subset(val_indices, control_mask)
    candidates: list[dict[str, Any]] = []
    for name, gate in market_gate_set().items():
        mask = [bool(gate(feature_rows[day])) for day in start_days]  # type: ignore[arg-type]
        development = subset(dev_indices, mask)
        validation = subset(val_indices, mask)
        rates = [
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
                "preholdout_score": min(float(value) for value in rates),
                "preholdout_pass": preholdout_pass(
                    development,
                    validation,
                    control_development,
                    control_validation,
                    minimum_floor_pct=args.minimum_floor_pct,
                    minimum_improvement_pct=args.minimum_improvement_pct,
                    minimum_development_starts=args.minimum_development_starts,
                    minimum_validation_starts=args.minimum_validation_starts,
                    minimum_eligible_pct=args.minimum_eligible_pct,
                ),
            }
        )

    survivors = [row for row in candidates if row["preholdout_pass"]]
    winner = max(
        survivors,
        key=lambda row: (row["preholdout_score"], row["validation"]["eligible_starts"]),
        default=None,
    )
    candidates.sort(key=lambda row: row["preholdout_score"], reverse=True)
    artifact = {
        "schema_version": 1,
        "status": "PREHOLDOUT_SURVIVOR" if winner else "NO_PREHOLDOUT_SURVIVOR",
        "basis": "market_features_from_completed_bars_strictly_before_challenge_launch",
        "manifest": str(args.manifest),
        "scenario": args.scenario,
        "timestamp_basis": manifest.get("timestamp_basis", governor.TIMESTAMP_BASIS_UNIX_UTC),
        "selection_contract": {
            "candidate_gates": list(market_gate_set()),
            "feature_symbols": list(CORE_SYMBOLS),
            "return_lookbacks_observed_m15_bars": [481, 1921],
            "volatility_windows_observed_m15_bars": [480, 1440],
            "development_years": sorted(development_years),
            "validation_years": sorted(validation_years),
            "sealed_years_unopened": sorted(sealed_years),
            "minimum_floor_pct_each_fill_and_split": args.minimum_floor_pct,
            "minimum_improvement_pct_each_fill_and_split": args.minimum_improvement_pct,
            "minimum_development_starts": args.minimum_development_starts,
            "minimum_validation_starts": args.minimum_validation_starts,
            "minimum_eligible_pct_each_split": args.minimum_eligible_pct,
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
        "feature_complete_starts": len(start_days),
        "control": {"development": control_development, "validation": control_validation},
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
                "out": str(args.out),
                "status": artifact["status"],
                "candidate_count": len(candidates),
                "survivor_count": len(survivors),
                "winner": winner["gate"] if winner else None,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
