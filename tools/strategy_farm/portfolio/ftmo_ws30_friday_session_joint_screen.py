"""Screen the frozen WS30 Friday session premium against the locked FTMO book.

The candidate has no EA id and no native-deployment permission. This tool
therefore keeps it under a named research key and builds its M15 path directly
from the frozen bar rule. It is an admission screen, not a pipeline shortcut.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np
import pandas as pd

try:
    from . import ftmo_m15_causal_strategy_screen as m15
    from .ftmo_bar_governor_sim import (
        GovernedTradePath,
        build_trade_paths,
        evaluate_policy,
        index_entries,
        valid_start_days,
    )
    from .ftmo_bar_joint_book_sim import (
        GRID_FREQUENCY,
        align_bars_to_grid,
        common_grid,
        default_bar_paths,
        load_cases,
    )
    from .ftmo_secret_joint_bar_mae_screen import (
        candidate_weights,
        select_development_winner,
        sha256,
        stage_excluded,
    )
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore
    from ftmo_bar_governor_sim import (  # type: ignore
        GovernedTradePath,
        build_trade_paths,
        evaluate_policy,
        index_entries,
        valid_start_days,
    )
    from ftmo_bar_joint_book_sim import (  # type: ignore
        GRID_FREQUENCY,
        align_bars_to_grid,
        common_grid,
        default_bar_paths,
        load_cases,
    )
    from ftmo_secret_joint_bar_mae_screen import (  # type: ignore
        candidate_weights,
        select_development_winner,
        sha256,
        stage_excluded,
    )


DATA_ROOT = Path(r"D:\QM\mt5\T_Export\MQL5\Files")
CANDIDATE_KEY = "RESEARCH:WS30_FRIDAY_SESSION_LONG"
ENTRY_OFFSET_BARS = 16
HOLD_BARS = 16
STOP_ATR = 1.0
ROUND_TRIP_COST_POINTS = 4.0
NOMINAL_RISK = 1000.0


def targeted_transfer_weights(
    control: Mapping[str, float],
    *,
    donor_key: str,
    candidate_weight: float,
) -> dict[str, float]:
    if donor_key not in control:
        raise ValueError(f"unknown donor key: {donor_key}")
    if not 0.0 < candidate_weight < float(control[donor_key]):
        raise ValueError("candidate transfer must be positive and below donor weight")
    weights = {str(key): float(value) for key, value in control.items()}
    weights[donor_key] -= candidate_weight
    weights[CANDIDATE_KEY] = candidate_weight
    if not math.isclose(sum(weights.values()), 1.0, abs_tol=1e-10):
        raise AssertionError("targeted transfer weights do not sum to one")
    return weights


def candidate_instrument(root: Path = DATA_ROOT) -> m15.Instrument:
    return next(
        instrument
        for instrument in m15.default_instruments(root)
        if instrument.symbol == "WS30.DWX"
    )


def build_candidate_paths(
    frame: pd.DataFrame,
    instrument: m15.Instrument,
    *,
    grid: pd.DatetimeIndex,
    excluded_years: set[int],
) -> list[GovernedTradePath]:
    opens = m15._values(frame, "open")
    highs = m15._values(frame, "high")
    lows = m15._values(frame, "low")
    closes = m15._values(frame, "close")
    atrs = m15._values(frame, "atr56")
    weekdays = m15._values(frame, "weekday")
    years = m15._values(frame, "year")
    utc_values = m15._values(frame, "utc")
    paths: list[GovernedTradePath] = []

    for trade_number, indices in enumerate(m15.session_days(frame, instrument), 1):
        if len(indices) <= ENTRY_OFFSET_BARS:
            continue
        entry_index = indices[ENTRY_OFFSET_BARS]
        year = int(years[entry_index])
        if year in excluded_years or int(weekdays[entry_index]) != 4:
            continue
        atr_index = entry_index - 1
        atr = float(atrs[atr_index])
        entry = float(opens[entry_index])
        if not np.isfinite(atr) or atr <= 0.0 or entry <= 0.0:
            continue

        stop_distance = STOP_ATR * atr
        stop_price = entry - stop_distance
        end_position = min(len(indices) - 1, ENTRY_OFFSET_BARS + HOLD_BARS - 1)
        source_path = list(indices[ENTRY_OFFSET_BARS : end_position + 1])
        stop_position = next(
            (position for position, index in enumerate(source_path) if float(lows[index]) <= stop_price),
            None,
        )
        stopped = stop_position is not None
        if stopped:
            source_path = source_path[: int(stop_position) + 1]

        buckets = pd.DatetimeIndex(
            [pd.Timestamp(utc_values[index]).floor(GRID_FREQUENCY) for index in source_path]
        )
        positions = grid.get_indexer(buckets)
        if (positions < 0).any() or not np.array_equal(
            positions, np.arange(positions[0], positions[0] + len(positions))
        ):
            raise ValueError(f"WS30 Friday trade {trade_number}: path is not on the common grid")

        point_value = NOMINAL_RISK / stop_distance
        total_cost = ROUND_TRIP_COST_POINTS * point_value
        entry_commission = total_cost / 2.0
        exit_commission = total_cost - entry_commission
        adverse = (np.asarray([float(lows[index]) for index in source_path]) - entry) * point_value
        close = (np.asarray([float(closes[index]) for index in source_path]) - entry) * point_value
        gross_exit = (
            -NOMINAL_RISK
            if stopped
            else (float(closes[source_path[-1]]) - entry) * point_value
        )
        paths.append(
            GovernedTradePath(
                trade_id=f"{CANDIDATE_KEY}:{trade_number}",
                key=CANDIDATE_KEY,
                start_idx=int(positions[0]),
                end_idx=int(positions[-1]),
                entry_commission=entry_commission,
                exit_commission=exit_commission,
                exit_balance_delta=gross_exit - exit_commission,
                adverse_pnl=adverse,
                close_pnl=close,
                nominal_risk=NOMINAL_RISK,
            )
        )
    return paths


def _stage_paths(
    cases: Sequence[Mapping[str, Any]],
    incumbent_bars: Mapping[str, pd.DataFrame],
    candidate_frame: pd.DataFrame,
    instrument: m15.Instrument,
    grid: pd.DatetimeIndex,
    excluded_years: set[int],
) -> list[GovernedTradePath]:
    paths: list[GovernedTradePath] = []
    for case in cases:
        symbol = str(case["symbol"]).upper()
        aligned, observed = align_bars_to_grid(incumbent_bars[symbol], grid)
        paths.extend(
            build_trade_paths(
                case,
                grid=grid,
                aligned_bars=aligned,
                observed_bar_timestamps=observed,
                feature_bars=incumbent_bars[symbol],
                excluded_years=excluded_years,
            )
        )
    paths.extend(
        build_candidate_paths(
            candidate_frame,
            instrument,
            grid=grid,
            excluded_years=excluded_years,
        )
    )
    return paths


def _evaluate(
    grid: pd.DatetimeIndex,
    paths: Sequence[GovernedTradePath],
    *,
    excluded_years: set[int],
    weights: Mapping[str, float],
    adverse: bool,
) -> dict[str, Any]:
    return evaluate_policy(
        grid,
        index_entries(paths),
        start_days=valid_start_days(grid, horizon_days=30, excluded_years=excluded_years),
        horizon_days=30,
        weights=weights,
        risk_multiplier=25.0,
        daily_stop=4500.0,
        full_risk_room=4000.0,
        room_retention=0.2,
        open_risk_limit_ratio=0.0,
        threshold_fill=not adverse,
    )


def _pass_pct(result: Mapping[str, Any]) -> float:
    return float(result["historical_rolling"]["pass_pct"])


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--scenario", default="path_01_11095_gbpusd_down2")
    parser.add_argument("--weights-pct", default="0.5,1,2,3,5,7.5,10")
    parser.add_argument("--donor-key")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    scenarios = {row["name"]: row for row in manifest["scenarios"]}
    if args.scenario not in scenarios:
        parser.error(f"unknown scenario: {args.scenario}")
    control_weights = {
        str(key): float(value) for key, value in scenarios[args.scenario]["weights"].items()
    }
    candidate_grid = [float(value) for value in args.weights_pct.split(",") if value.strip()]
    if not candidate_grid or any(value <= 0.0 or value >= 100.0 for value in candidate_grid):
        parser.error("--weights-pct must contain values in (0, 100)")

    cases, incumbent_bars = load_cases(manifest, bar_paths=default_bar_paths(DATA_ROOT))
    grid = common_grid(cases)
    instrument = candidate_instrument(DATA_ROOT)
    candidate_frame = m15.load_bars(instrument)

    development_excluded = stage_excluded([2018, 2019, 2021, 2022])
    development_paths = _stage_paths(
        cases,
        incumbent_bars,
        candidate_frame,
        instrument,
        grid,
        development_excluded,
    )
    control_normal = _evaluate(
        grid, development_paths, excluded_years=development_excluded, weights=control_weights, adverse=False
    )
    control_adverse = _evaluate(
        grid, development_paths, excluded_years=development_excluded, weights=control_weights, adverse=True
    )
    control_normal_pct = _pass_pct(control_normal)
    control_adverse_pct = _pass_pct(control_adverse)
    rows: list[dict[str, Any]] = []
    for weight_pct in candidate_grid:
        if args.donor_key:
            weights = targeted_transfer_weights(
                control_weights,
                donor_key=args.donor_key,
                candidate_weight=weight_pct / 100.0,
            )
        else:
            weights = candidate_weights(
                control_weights, {"WS30_FRIDAY_SESSION_LONG": 1.0}, weight_pct / 100.0
            )
            weights[CANDIDATE_KEY] = weights.pop("SECRET:WS30_FRIDAY_SESSION_LONG")
        normal = _evaluate(
            grid, development_paths, excluded_years=development_excluded, weights=weights, adverse=False
        )
        normal_pct = _pass_pct(normal)
        adverse = None
        adverse_pct = None
        skipped_reason = None
        if normal_pct > control_normal_pct:
            adverse = _evaluate(
                grid, development_paths, excluded_years=development_excluded, weights=weights, adverse=True
            )
            adverse_pct = _pass_pct(adverse)
        else:
            skipped_reason = "normal_development_did_not_strictly_improve_control"
        row = {
            "representation": "ws30_friday_session_long",
            "candidate_weight_pct": weight_pct,
            "normal_pass_pct": normal_pct,
            "adverse_pass_pct": adverse_pct,
            "normal": normal,
            "adverse": adverse,
            "adverse_skipped_reason": skipped_reason,
        }
        rows.append(row)
        print(
            f"weight={weight_pct:g}% normal={normal_pct:.4f}% "
            + (f"adverse={adverse_pct:.4f}%" if adverse_pct is not None else "adverse=SKIPPED_NORMAL_GATE"),
            flush=True,
        )

    winner = select_development_winner(
        rows, control_normal=control_normal_pct, control_adverse=control_adverse_pct
    )
    validation = None
    confirmation = None
    status = "NO_DEVELOPMENT_SURVIVOR"
    if winner is not None:
        selected_weight = float(winner["candidate_weight_pct"]) / 100.0
        if args.donor_key:
            selected_weights = targeted_transfer_weights(
                control_weights,
                donor_key=args.donor_key,
                candidate_weight=selected_weight,
            )
        else:
            selected_weights = candidate_weights(
                control_weights, {"WS30_FRIDAY_SESSION_LONG": 1.0}, selected_weight
            )
            selected_weights[CANDIDATE_KEY] = selected_weights.pop("SECRET:WS30_FRIDAY_SESSION_LONG")
        validation_excluded = stage_excluded([2023])
        validation_paths = _stage_paths(
            cases, incumbent_bars, candidate_frame, instrument, grid, validation_excluded
        )
        validation = {
            "included_years": [2023],
            "control_normal": _evaluate(grid, validation_paths, excluded_years=validation_excluded, weights=control_weights, adverse=False),
            "control_adverse": _evaluate(grid, validation_paths, excluded_years=validation_excluded, weights=control_weights, adverse=True),
            "candidate_normal": _evaluate(grid, validation_paths, excluded_years=validation_excluded, weights=selected_weights, adverse=False),
            "candidate_adverse": _evaluate(grid, validation_paths, excluded_years=validation_excluded, weights=selected_weights, adverse=True),
        }
        validation["normal_delta_pct_points"] = _pass_pct(validation["candidate_normal"]) - _pass_pct(validation["control_normal"])
        validation["adverse_delta_pct_points"] = _pass_pct(validation["candidate_adverse"]) - _pass_pct(validation["control_adverse"])
        if validation["normal_delta_pct_points"] >= 0.0 and validation["adverse_delta_pct_points"] >= 0.0:
            status = "VALIDATION_SURVIVOR_RESEARCH_ONLY"
            confirmation_excluded = stage_excluded([2024, 2025])
            confirmation_paths = _stage_paths(
                cases, incumbent_bars, candidate_frame, instrument, grid, confirmation_excluded
            )
            confirmation = {
                "label": "CONTAMINATED_CONFIRMATION_NOT_HOLDOUT_NOT_DEPLOYMENT_EVIDENCE",
                "included_years": [2024, 2025],
                "control_normal": _evaluate(grid, confirmation_paths, excluded_years=confirmation_excluded, weights=control_weights, adverse=False),
                "control_adverse": _evaluate(grid, confirmation_paths, excluded_years=confirmation_excluded, weights=control_weights, adverse=True),
                "candidate_normal": _evaluate(grid, confirmation_paths, excluded_years=confirmation_excluded, weights=selected_weights, adverse=False),
                "candidate_adverse": _evaluate(grid, confirmation_paths, excluded_years=confirmation_excluded, weights=selected_weights, adverse=True),
            }
        else:
            status = "VALIDATION_FAIL"

    candidate_path_count = sum(path.key == CANDIDATE_KEY for path in development_paths)
    artifact = {
        "schema_version": 1,
        "status": status,
        "label": "RESEARCH_ONLY_NO_GO",
        "deployment_allowed": False,
        "manifest": str(args.manifest),
        "manifest_sha256": sha256(args.manifest),
        "scenario": args.scenario,
        "weight_contract": (
            {"type": "targeted_absolute_transfer", "donor_key": args.donor_key}
            if args.donor_key
            else {"type": "proportional_incumbent_scale"}
        ),
        "candidate_key": CANDIDATE_KEY,
        "native_ea_exists": False,
        "timestamp_basis": "darwinex_broker_wall_to_utc_to_america_new_york",
        "path_contract": {
            "candidate_adverse_fill": "uncapped_observed_ws30_m15_low",
            "candidate_close_fill": "observed_ws30_m15_close",
            "nominal_risk": NOMINAL_RISK,
            "round_trip_cost_points": ROUND_TRIP_COST_POINTS,
        },
        "development": {
            "included_years": [2018, 2019, 2021, 2022],
            "candidate_trade_paths": candidate_path_count,
            "control_normal": control_normal,
            "control_adverse": control_adverse,
            "rows": rows,
            "winner": winner,
        },
        "validation": validation,
        "confirmation": confirmation,
        "sealed_holdout_opened": False,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {args.out} status={status}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
