"""Train and validate a causal FTMO challenge-launch model.

All features stop strictly before the candidate start day. Models are fitted
on development years only; validation selects at most one frozen model. This
tool never evaluates the sealed holdout years.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np

try:
    from . import ftmo_bar_governor_sim as governor
    from .ftmo_launch_gate_screen import (
        _parse_ints,
        _simulate,
        has_unsealed_lookback,
        summarize_subset,
        weighted_daily_pnl,
    )
    from .ftmo_market_launch_gate_screen import CORE_SYMBOLS, market_features
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_governor_sim as governor  # type: ignore
    from ftmo_launch_gate_screen import (  # type: ignore
        _parse_ints,
        _simulate,
        has_unsealed_lookback,
        summarize_subset,
        weighted_daily_pnl,
    )
    from ftmo_market_launch_gate_screen import CORE_SYMBOLS, market_features  # type: ignore


PNL_LOOKBACKS = (5, 10, 20, 40, 60, 120)
DISPERSION_LOOKBACKS = (10, 20, 60)
DRAWDOWN_LOOKBACKS = (20, 60, 120)
RIDGE_PENALTIES = (0.1, 1.0, 10.0, 100.0)
TOP_FRACTIONS = (0.15, 0.20, 0.25, 0.33, 0.50)
SCORE_MODES = ("joint", "minimum", "mean")
MAX_LOOKBACK = max(PNL_LOOKBACKS + DISPERSION_LOOKBACKS + DRAWDOWN_LOOKBACKS)


@dataclass(frozen=True)
class FrozenRidge:
    feature_names: tuple[str, ...]
    means: tuple[float, ...]
    scales: tuple[float, ...]
    intercept: float
    coefficients: tuple[float, ...]

    def score(self, row: Mapping[str, float]) -> float:
        values = np.asarray([float(row[name]) for name in self.feature_names], dtype=float)
        means = np.asarray(self.means, dtype=float)
        scales = np.asarray(self.scales, dtype=float)
        coefficients = np.asarray(self.coefficients, dtype=float)
        return float(self.intercept + np.dot((values - means) / scales, coefficients))

    def to_json(self) -> dict[str, Any]:
        return {
            "feature_names": list(self.feature_names),
            "means": list(self.means),
            "scales": list(self.scales),
            "intercept": self.intercept,
            "coefficients": list(self.coefficients),
        }

    @classmethod
    def from_json(cls, payload: Mapping[str, Any]) -> "FrozenRidge":
        names = tuple(str(value) for value in payload["feature_names"])
        means = tuple(float(value) for value in payload["means"])
        scales = tuple(float(value) for value in payload["scales"])
        coefficients = tuple(float(value) for value in payload["coefficients"])
        if not (len(names) == len(means) == len(scales) == len(coefficients)):
            raise ValueError("frozen ridge arrays must have equal lengths")
        if not names or any(not math.isfinite(value) for value in means + coefficients):
            raise ValueError("frozen ridge contains invalid values")
        if any(not math.isfinite(value) or value <= 0.0 for value in scales):
            raise ValueError("frozen ridge scales must be finite and positive")
        intercept = float(payload["intercept"])
        if not math.isfinite(intercept):
            raise ValueError("frozen ridge intercept must be finite")
        return cls(names, means, scales, intercept, coefficients)


def shadow_book_features(
    start_day: dt.date,
    daily_pnl: Mapping[dt.date, float],
) -> dict[str, float]:
    prior = {
        offset: float(daily_pnl.get(start_day - dt.timedelta(days=offset), 0.0))
        for offset in range(1, MAX_LOOKBACK + 1)
    }
    output: dict[str, float] = {}
    for lookback in PNL_LOOKBACKS:
        values = [prior[offset] for offset in range(1, lookback + 1)]
        output[f"book_pnl_sum_{lookback:03d}"] = float(sum(values))
    for lookback in DISPERSION_LOOKBACKS:
        values = np.asarray([prior[offset] for offset in range(1, lookback + 1)], dtype=float)
        output[f"book_pnl_std_{lookback:03d}"] = float(np.std(values))
        output[f"book_positive_ratio_{lookback:03d}"] = float(np.mean(values > 0.0))
    for lookback in DRAWDOWN_LOOKBACKS:
        chronological = np.asarray(
            [prior[offset] for offset in range(lookback, 0, -1)], dtype=float
        )
        curve = np.concatenate(([0.0], np.cumsum(chronological)))
        running_peak = np.maximum.accumulate(curve)
        output[f"book_drawdown_{lookback:03d}"] = float(np.max(running_peak - curve))
    return output


def feature_row(
    start_day: dt.date,
    daily_pnl: Mapping[dt.date, float],
    bars_by_symbol,
) -> dict[str, float] | None:
    market = market_features(start_day, bars_by_symbol, CORE_SYMBOLS)
    if market is None:
        return None
    output = shadow_book_features(start_day, daily_pnl)
    for symbol in CORE_SYMBOLS:
        prefix = symbol.split(".")[0].lower()
        for name in ("return_5d", "return_20d", "volatility_ratio"):
            output[f"market_{prefix}_{name}"] = float(market[symbol][name])
    for month in range(1, 13):
        output[f"calendar_month_{month:02d}"] = float(start_day.month == month)
    for weekday in range(7):
        output[f"calendar_weekday_{weekday}"] = float(start_day.weekday() == weekday)
    return output


def fit_ridge(
    rows: Sequence[Mapping[str, float]],
    targets: Sequence[float],
    penalty: float,
) -> FrozenRidge:
    if not rows or len(rows) != len(targets):
        raise ValueError("rows and targets must be non-empty and equal length")
    if not math.isfinite(penalty) or penalty <= 0.0:
        raise ValueError("ridge penalty must be finite and positive")
    names = tuple(sorted(rows[0]))
    if not names or any(tuple(sorted(row)) != names for row in rows):
        raise ValueError("feature rows must have identical non-empty keys")
    matrix = np.asarray([[float(row[name]) for name in names] for row in rows], dtype=float)
    target = np.asarray(targets, dtype=float)
    if not np.isfinite(matrix).all() or not np.isfinite(target).all():
        raise ValueError("training data must be finite")
    means = np.mean(matrix, axis=0)
    scales = np.std(matrix, axis=0)
    scales = np.where(scales > 1e-12, scales, 1.0)
    standardized = (matrix - means) / scales
    design = np.column_stack((np.ones(len(rows)), standardized))
    regularizer = np.eye(design.shape[1], dtype=float) * penalty
    regularizer[0, 0] = 0.0
    gram = design.T @ design + regularizer
    rhs = design.T @ target
    try:
        beta = np.linalg.solve(gram, rhs)
    except np.linalg.LinAlgError:
        beta = np.linalg.lstsq(gram, rhs, rcond=None)[0]
    return FrozenRidge(
        feature_names=names,
        means=tuple(float(value) for value in means),
        scales=tuple(float(value) for value in scales),
        intercept=float(beta[0]),
        coefficients=tuple(float(value) for value in beta[1:]),
    )


def model_score(
    row: Mapping[str, float],
    models: Mapping[str, FrozenRidge],
    mode: str,
) -> float:
    if mode == "joint":
        return models["joint"].score(row)
    threshold = models["threshold"].score(row)
    adverse = models["adverse"].score(row)
    if mode == "minimum":
        return min(threshold, adverse)
    if mode == "mean":
        return 0.5 * (threshold + adverse)
    raise ValueError(f"unknown score mode: {mode}")


def score_threshold(scores: Sequence[float], top_fraction: float) -> float:
    if not scores or not 0.0 < top_fraction <= 1.0:
        raise ValueError("scores must be non-empty and top_fraction must be in (0, 1]")
    rank = max(1, int(math.ceil(len(scores) * top_fraction)))
    ordered = sorted((float(value) for value in scores), reverse=True)
    return ordered[rank - 1]


def preholdout_pass(
    development: Mapping[str, Any],
    validation: Mapping[str, Any],
    control_development: Mapping[str, Any],
    control_validation: Mapping[str, Any],
    *,
    minimum_floor_pct: float,
    minimum_improvement_pct: float,
    minimum_development_starts: int,
    minimum_validation_starts: int,
    minimum_eligible_pct: float,
) -> bool:
    if development["eligible_starts"] < minimum_development_starts:
        return False
    if validation["eligible_starts"] < minimum_validation_starts:
        return False
    if development["eligible_pct"] < minimum_eligible_pct:
        return False
    if validation["eligible_pct"] < minimum_eligible_pct:
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


def _frozen_models_json(
    models: Mapping[str, FrozenRidge],
    mode: str,
) -> dict[str, Any]:
    required = ("joint",) if mode == "joint" else ("threshold", "adverse")
    return {name: models[name].to_json() for name in required}


def _parse_floats(raw: str) -> tuple[float, ...]:
    values = tuple(float(value.strip()) for value in raw.split(",") if value.strip())
    if not values:
        raise ValueError("float list is empty")
    return values


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
    parser.add_argument("--ridge-penalties", default="0.1,1,10,100")
    parser.add_argument("--top-fractions", default="0.15,0.20,0.25,0.33,0.50")
    parser.add_argument("--minimum-floor-pct", type=float, default=60.0)
    parser.add_argument("--minimum-improvement-pct", type=float, default=5.0)
    parser.add_argument("--minimum-development-starts", type=int, default=150)
    parser.add_argument("--minimum-validation-starts", type=int, default=30)
    parser.add_argument("--minimum-eligible-pct", type=float, default=10.0)
    parser.add_argument("--predeclaration", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    predeclaration = json.loads(args.predeclaration.read_text(encoding="utf-8-sig"))
    if predeclaration.get("selection_uses_holdout") is not False:
        parser.error("predeclaration does not prove holdout exclusion")

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
    penalties = _parse_floats(args.ridge_penalties)
    fractions = _parse_floats(args.top_fractions)
    if any(value <= 0.0 for value in penalties):
        parser.error("ridge penalties must be positive")
    if any(value <= 0.0 or value > 1.0 for value in fractions):
        parser.error("top fractions must be in (0, 1]")

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
        and has_unsealed_lookback(day, sealed_years, MAX_LOOKBACK)
    ]
    daily_pnl = weighted_daily_pnl(grid, paths, weights)
    feature_rows = {day: feature_row(day, daily_pnl, bars) for day in candidate_starts}
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
    dev_rows = [feature_rows[start_days[index]] for index in dev_indices]
    val_rows = [feature_rows[start_days[index]] for index in val_indices]
    if any(row is None for row in dev_rows + val_rows):
        raise AssertionError("feature-complete rows unexpectedly contain None")
    dev_threshold_targets = [
        float(threshold_results[index].outcome == "passed") for index in dev_indices
    ]
    dev_adverse_targets = [
        float(adverse_results[index].outcome == "passed") for index in dev_indices
    ]
    dev_joint_targets = [
        float(threshold_results[index].outcome == "passed" and adverse_results[index].outcome == "passed")
        for index in dev_indices
    ]

    candidates: list[dict[str, Any]] = []
    winner_models: dict[tuple[float, str], Mapping[str, FrozenRidge]] = {}
    for penalty in penalties:
        models = {
            "threshold": fit_ridge(dev_rows, dev_threshold_targets, penalty),  # type: ignore[arg-type]
            "adverse": fit_ridge(dev_rows, dev_adverse_targets, penalty),  # type: ignore[arg-type]
            "joint": fit_ridge(dev_rows, dev_joint_targets, penalty),  # type: ignore[arg-type]
        }
        for mode in SCORE_MODES:
            dev_scores = [model_score(row, models, mode) for row in dev_rows]  # type: ignore[arg-type]
            val_scores = [model_score(row, models, mode) for row in val_rows]  # type: ignore[arg-type]
            winner_models[(penalty, mode)] = models
            for fraction in fractions:
                threshold = score_threshold(dev_scores, fraction)
                mask = [False] * len(start_days)
                for index, score in zip(dev_indices, dev_scores):
                    mask[index] = score >= threshold
                for index, score in zip(val_indices, val_scores):
                    mask[index] = score >= threshold
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
                        "model_id": f"ridge_{penalty:g}_{mode}_top_{fraction:.2f}",
                        "ridge_penalty": penalty,
                        "score_mode": mode,
                        "development_top_fraction": fraction,
                        "score_threshold": threshold,
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
        key=lambda row: (
            row["preholdout_score"],
            row["validation"]["eligible_starts"],
            row["development"]["eligible_starts"],
        ),
        default=None,
    )
    selected_winner = None
    if winner is not None:
        selected_winner = dict(winner)
        models = winner_models[(winner["ridge_penalty"], winner["score_mode"])]
        selected_winner["frozen_models"] = _frozen_models_json(
            models, winner["score_mode"]
        )
    candidates.sort(
        key=lambda row: (row["preholdout_score"], row["validation"]["eligible_starts"]),
        reverse=True,
    )
    artifact = {
        "schema_version": 1,
        "status": "PREHOLDOUT_SURVIVOR" if selected_winner else "NO_PREHOLDOUT_SURVIVOR",
        "basis": "ridge_launch_model_using_only_features_available_before_start_day",
        "manifest": str(args.manifest),
        "scenario": args.scenario,
        "predeclaration": str(args.predeclaration),
        "timestamp_basis": manifest.get("timestamp_basis", governor.TIMESTAMP_BASIS_UNIX_UTC),
        "selection_contract": {
            "development_years": sorted(development_years),
            "validation_years": sorted(validation_years),
            "sealed_years_unopened": sorted(sealed_years),
            "maximum_causal_lookback_calendar_days": MAX_LOOKBACK,
            "score_modes": list(SCORE_MODES),
            "ridge_penalties": list(penalties),
            "development_top_fractions": list(fractions),
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
        "feature_names": sorted(next(row for row in feature_rows.values() if row is not None)),
        "control": {"development": control_development, "validation": control_validation},
        "candidate_count": len(candidates),
        "preholdout_survivor_count": len(survivors),
        "selected_winner": selected_winner,
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
                "winner": selected_winner["model_id"] if selected_winner else None,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
