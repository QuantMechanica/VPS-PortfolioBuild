"""Screen the five research-only secret strategies against the locked FTMO book.

The secret cards do not have EA ids or deployment permission. This tool keeps
them as named research groups, parses their native MT5 reports directly, applies
the current FTMO cost snapshot, and reconstructs synchronized bar equity. It is
an admission screen, not a pipeline or deployment shortcut.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np
import pandas as pd

try:
    from .ftmo_bar_governor_sim import (
        GovernedTradePath,
        build_trade_paths,
        evaluate_policy,
        index_entries,
        valid_start_days,
    )
    from .ftmo_bar_joint_book_sim import (
        GRID_FREQUENCY,
        TIMESTAMP_BASIS_DARWINEX_WALL,
        align_bars_to_grid,
        common_grid,
        cumulative_swap_for_slice,
        default_bar_paths,
        load_cases,
        load_resampled_bars,
        normalize_schedule,
        normalize_timestamp,
        rollover_schedule,
        sleeve_key,
        trade_point_value,
    )
    from .ftmo_report_cost_reconcile import (
        RoundTrip,
        extract_round_trips,
        ftmo_trade_net,
    )
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_bar_governor_sim import (  # type: ignore
        GovernedTradePath,
        build_trade_paths,
        evaluate_policy,
        index_entries,
        valid_start_days,
    )
    from ftmo_bar_joint_book_sim import (  # type: ignore
        GRID_FREQUENCY,
        TIMESTAMP_BASIS_DARWINEX_WALL,
        align_bars_to_grid,
        common_grid,
        cumulative_swap_for_slice,
        default_bar_paths,
        load_cases,
        load_resampled_bars,
        normalize_schedule,
        normalize_timestamp,
        rollover_schedule,
        sleeve_key,
        trade_point_value,
    )
    from ftmo_report_cost_reconcile import (  # type: ignore
        RoundTrip,
        extract_round_trips,
        ftmo_trade_net,
    )


ROOT = Path(__file__).resolve().parents[3]
LAB = ROOT / ".private" / "secret_strategy_lab"
DATA_ROOT = Path(r"D:\QM\mt5\T_Export\MQL5\Files")
YEARS = set(range(2017, 2026))

STRATEGIES = (
    "pre_fomc_event_flat",
    "xau_sma50_impulse_hold",
    "jpy_cross_sma20_risk_on",
    "breadth_turnaround_tuesday",
    "xau_m5_ema20_impulse_harvest",
)

REPRESENTATIONS: dict[str, dict[str, float]] = {
    **{name: {name: 1.0} for name in STRATEGIES},
    "five_equal": {name: 0.2 for name in STRATEGIES},
    "five_segment_b_frozen": {
        "pre_fomc_event_flat": 0.1,
        "xau_sma50_impulse_hold": 0.1,
        "jpy_cross_sma20_risk_on": 0.6,
        "breadth_turnaround_tuesday": 0.1,
        "xau_m5_ema20_impulse_harvest": 0.1,
    },
}

COSTS: dict[str, dict[str, Any]] = {
    "XAUUSD.DWX": {
        "commission_percent_per_side": 0.0014,
        "flat_round_trip_commission_per_lot": 0.0,
        "swap_long_points": -75.93,
        "swap_short_points": -23.55,
        "contract_size": 100.0,
        "source_contract_size": 100.0,
        "profit_currency_to_account_rate": 1.0,
        "derive_profit_currency_rate_from_pnl": False,
        "digits": 2,
        "triple_weekday": 2,
    },
    "SP500.DWX": {
        "commission_percent_per_side": 0.0,
        "flat_round_trip_commission_per_lot": 0.0,
        "swap_long_points": -86.56,
        "swap_short_points": -68.93,
        "contract_size": 1.0,
        "source_contract_size": 1.0,
        "profit_currency_to_account_rate": 1.0,
        "derive_profit_currency_rate_from_pnl": False,
        "digits": 2,
        "triple_weekday": 2,
    },
    "WS30.DWX": {
        "commission_percent_per_side": 0.0,
        "flat_round_trip_commission_per_lot": 0.0,
        "swap_long_points": -1135.86,
        "swap_short_points": 47.27,
        "contract_size": 1.0,
        "source_contract_size": 1.0,
        "profit_currency_to_account_rate": 1.0,
        "derive_profit_currency_rate_from_pnl": False,
        "digits": 2,
        "triple_weekday": 2,
    },
    "AUDJPY.DWX": {
        "commission_percent_per_side": 0.0,
        "flat_round_trip_commission_per_lot": 5.0,
        "swap_long_points": 2.54,
        "swap_short_points": -16.39,
        "contract_size": 100000.0,
        "source_contract_size": 100000.0,
        "profit_currency_to_account_rate": 1.0,
        "derive_profit_currency_rate_from_pnl": True,
        "digits": 3,
        "triple_weekday": 2,
    },
    "GBPJPY.DWX": {
        "commission_percent_per_side": 0.0,
        "flat_round_trip_commission_per_lot": 5.0,
        "swap_long_points": 3.61,
        "swap_short_points": -27.58,
        "contract_size": 100000.0,
        "source_contract_size": 100000.0,
        "profit_currency_to_account_rate": 1.0,
        "derive_profit_currency_rate_from_pnl": True,
        "digits": 3,
        "triple_weekday": 2,
    },
}

SECRET_BAR_PATHS = {
    "XAUUSD.DWX": DATA_ROOT / "XAUUSD.DWX_M15.csv",
    "SP500.DWX": DATA_ROOT / "SP500.DWX_M15.csv",
    "WS30.DWX": DATA_ROOT / "WS30.DWX_M15.csv",
    "AUDJPY.DWX": DATA_ROOT / "AUDJPY.DWX_H1.csv",
    "GBPJPY.DWX": DATA_ROOT / "GBPJPY.DWX_M5.csv",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def stage_excluded(included_years: Sequence[int]) -> set[int]:
    included = {int(year) for year in included_years}
    if not included or not included <= YEARS:
        raise ValueError("included years must be a non-empty subset of 2017-2025")
    return YEARS - included


def candidate_weights(
    control: Mapping[str, float],
    mix: Mapping[str, float],
    candidate_weight: float,
) -> dict[str, float]:
    if not 0.0 < candidate_weight < 1.0:
        raise ValueError("candidate weight must be in (0, 1)")
    mix_total = sum(float(value) for value in mix.values())
    if not math.isclose(mix_total, 1.0, abs_tol=1e-12):
        raise ValueError("secret representation weights must sum to one")
    output = {key: float(value) * (1.0 - candidate_weight) for key, value in control.items()}
    output.update(
        {
            f"SECRET:{name}": candidate_weight * float(value)
            for name, value in mix.items()
            if float(value) > 0.0
        }
    )
    if not math.isclose(sum(output.values()), 1.0, abs_tol=1e-10):
        raise AssertionError("combined weights do not sum to one")
    return output


def select_development_winner(
    rows: Sequence[Mapping[str, Any]],
    *,
    control_normal: float,
    control_adverse: float,
) -> dict[str, Any] | None:
    eligible: list[dict[str, Any]] = []
    for source in rows:
        row = dict(source)
        normal_delta = float(row["normal_pass_pct"]) - control_normal
        if normal_delta <= 0.0 or row.get("adverse_pass_pct") is None:
            continue
        adverse_delta = float(row["adverse_pass_pct"]) - control_adverse
        row["normal_delta_pct_points"] = normal_delta
        row["adverse_delta_pct_points"] = adverse_delta
        if normal_delta > 0.0 and adverse_delta > 0.0:
            eligible.append(row)
    if not eligible:
        return None
    eligible.sort(
        key=lambda row: (
            -min(row["normal_delta_pct_points"], row["adverse_delta_pct_points"]),
            -(row["normal_delta_pct_points"] + row["adverse_delta_pct_points"]),
            float(row["candidate_weight_pct"]),
            str(row["representation"]),
        )
    )
    return eligible[0]


def load_secret_runs() -> list[dict[str, Any]]:
    central = json.loads((LAB / "exact_mt5" / "exact_results.json").read_text(encoding="utf-8"))
    m5 = json.loads(
        (LAB / "xau_m5_ema20_impulse_harvest" / "exact_result.json").read_text(
            encoding="utf-8"
        )
    )
    selected = [
        {
            "strategy": run["strategy"],
            "window": run["window"],
            "sleeve": run["sleeve"],
            "symbol": run["symbol"],
            "component_scale": float(run["weight"]),
            "report": Path(run["report"]),
        }
        for run in central["runs"]
        if run["strategy"]
        in {
            "xau_sma50_impulse_hold",
            "jpy_cross_sma20_risk_on",
            "breadth_turnaround_tuesday",
        }
    ]
    selected.extend(
        {
            "strategy": run["strategy"],
            "window": run["window"],
            "sleeve": run["sleeve"],
            "symbol": run["symbol"],
            "component_scale": float(run["weight"]),
            "report": Path(run["report"]),
        }
        for run in m5["runs"]
    )
    fomc = {
        "segment_a": LAB / "pre_fomc_flat" / "runs" / "dev2018_2021" / "report.htm",
        "segment_b": LAB / "pre_fomc_flat" / "runs" / "validation2022_2023" / "report.htm",
        "segment_c": LAB / "pre_fomc_flat" / "runs" / "oos2024_2025" / "report.htm",
    }
    selected.extend(
        {
            "strategy": "pre_fomc_event_flat",
            "window": window,
            "sleeve": "sp500_pre_fomc",
            "symbol": "SP500.DWX",
            "component_scale": 4.0,
            "report": report,
        }
        for window, report in fomc.items()
    )
    return selected


def _costed_trade_values(trade: RoundTrip, cost: Mapping[str, Any]) -> tuple[float, float]:
    _net, commission, swap, _units = ftmo_trade_net(
        trade,
        commission_rate_per_side=float(cost["commission_percent_per_side"]) / 100.0,
        flat_round_trip_commission_per_lot=float(cost["flat_round_trip_commission_per_lot"]),
        swap_long_points=float(cost["swap_long_points"]),
        swap_short_points=float(cost["swap_short_points"]),
        contract_size=float(cost["contract_size"]),
        source_contract_size=float(cost["source_contract_size"]),
        profit_currency_to_account_rate=float(cost["profit_currency_to_account_rate"]),
        derive_profit_currency_rate_from_pnl=bool(cost["derive_profit_currency_rate_from_pnl"]),
        digits=int(cost["digits"]),
        triple_weekday=int(cost["triple_weekday"]),
    )
    return commission, swap


def build_secret_trade_paths(
    runs: Sequence[Mapping[str, Any]],
    *,
    grid: pd.DatetimeIndex,
    bars: Mapping[str, pd.DataFrame],
    excluded_years: set[int],
) -> tuple[list[GovernedTradePath], list[dict[str, Any]]]:
    aligned = {symbol: align_bars_to_grid(frame, grid)[0] for symbol, frame in bars.items()}
    paths: list[GovernedTradePath] = []
    evidence: list[dict[str, Any]] = []
    for run_number, run in enumerate(runs, 1):
        strategy = str(run["strategy"])
        symbol = str(run["symbol"]).upper()
        report = Path(run["report"])
        scale = float(run["component_scale"])
        trades, stats = extract_round_trips(report, symbol)
        evidence.append(
            {
                "strategy": strategy,
                "window": run["window"],
                "sleeve": run["sleeve"],
                "symbol": symbol,
                "component_scale": scale,
                "report": str(report),
                "report_sha256": sha256(report),
                "native_trades": len(trades),
                "native_profit_factor": stats.get("pf"),
                "native_net_profit": stats.get("net"),
            }
        )
        cost = COSTS[symbol]
        priced_all = aligned[symbol]
        for trade_number, trade in enumerate(trades, 1):
            entry = normalize_timestamp(trade.entry_time, TIMESTAMP_BASIS_DARWINEX_WALL)
            exit_time = normalize_timestamp(trade.exit_time, TIMESTAMP_BASIS_DARWINEX_WALL)
            if set(range(entry.year, exit_time.year + 1)) & excluded_years:
                continue
            entry_bucket = entry.floor(GRID_FREQUENCY)
            exit_bucket = exit_time.floor(GRID_FREQUENCY)
            start = int(grid.get_indexer([entry_bucket])[0])
            end = int(grid.get_indexer([exit_bucket])[0])
            if start < 0 or end < start:
                raise ValueError(
                    f"{strategy}/{symbol} trade {trade_number}: invalid grid span "
                    f"{entry_bucket}/{exit_bucket}"
                )
            timestamps = grid[start : end + 1]
            priced = priced_all.iloc[start : end + 1]
            if priced[["high", "low", "close"]].isna().any().any():
                raise ValueError(f"{strategy}/{symbol} trade {trade_number}: unpriced span")
            commission, swap = _costed_trade_values(trade, cost)
            point_value, _fallback = trade_point_value(
                trade,
                source_contract_size=float(cost["source_contract_size"]),
                fallback_account_rate=float(cost["profit_currency_to_account_rate"]),
            )
            side = 1.0 if trade.side == "buy" else -1.0
            adverse_price = priced["low"].to_numpy() if side > 0.0 else priced["high"].to_numpy()
            raw_adverse = side * (adverse_price - trade.entry_price) * point_value
            raw_close = side * (priced["close"].to_numpy() - trade.entry_price) * point_value
            schedule = normalize_schedule(
                rollover_schedule(
                    trade.entry_time,
                    trade.exit_time,
                    triple_weekday=int(cost["triple_weekday"]),
                ),
                TIMESTAMP_BASIS_DARWINEX_WALL,
            )
            cumulative_swap = cumulative_swap_for_slice(timestamps, schedule, total_swap=swap)
            entry_commission = commission / 2.0
            exit_commission = commission - entry_commission
            paths.append(
                GovernedTradePath(
                    trade_id=f"SECRET:{strategy}:{run_number}:{trade_number}",
                    key=f"SECRET:{strategy}",
                    start_idx=start,
                    end_idx=end,
                    entry_commission=entry_commission * scale,
                    exit_commission=exit_commission * scale,
                    exit_balance_delta=(trade.profit + swap - exit_commission) * scale,
                    adverse_pnl=(raw_adverse + cumulative_swap) * scale,
                    close_pnl=(raw_close + cumulative_swap) * scale,
                    nominal_risk=1000.0,
                )
            )
    return paths, evidence


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


def _stage_paths(
    manifest: Mapping[str, Any],
    cases: Sequence[Mapping[str, Any]],
    incumbent_bars: Mapping[str, pd.DataFrame],
    secret_runs: Sequence[Mapping[str, Any]],
    secret_bars: Mapping[str, pd.DataFrame],
    grid: pd.DatetimeIndex,
    excluded_years: set[int],
) -> tuple[list[GovernedTradePath], list[dict[str, Any]]]:
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
    secret_paths, evidence = build_secret_trade_paths(
        secret_runs,
        grid=grid,
        bars=secret_bars,
        excluded_years=excluded_years,
    )
    paths.extend(secret_paths)
    return paths, evidence


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--scenario", default="path_01_11095_gbpusd_down2")
    parser.add_argument("--weights-pct", default="0.5,1,2,3,5,7.5,10")
    parser.add_argument(
        "--representations",
        default=",".join(REPRESENTATIONS),
        help="comma-separated subset of predeclared secret representations",
    )
    parser.add_argument(
        "--stop-after-development",
        action="store_true",
        help="write a development shard without opening validation",
    )
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
    representation_names = [
        value.strip() for value in args.representations.split(",") if value.strip()
    ]
    if not representation_names:
        parser.error("--representations must not be empty")
    unknown_representations = set(representation_names) - set(REPRESENTATIONS)
    if unknown_representations:
        parser.error(f"unknown representations: {sorted(unknown_representations)}")

    cases, incumbent_bars = load_cases(manifest, bar_paths=default_bar_paths(DATA_ROOT))
    grid = common_grid(cases)
    secret_runs = load_secret_runs()
    secret_bars = {
        symbol: load_resampled_bars(path, timestamp_basis=TIMESTAMP_BASIS_DARWINEX_WALL)
        for symbol, path in SECRET_BAR_PATHS.items()
    }

    development_excluded = stage_excluded([2018, 2019, 2021, 2022])
    development_paths, report_evidence = _stage_paths(
        manifest,
        cases,
        incumbent_bars,
        secret_runs,
        secret_bars,
        grid,
        development_excluded,
    )
    control_normal = _evaluate(
        grid,
        development_paths,
        excluded_years=development_excluded,
        weights=control_weights,
        adverse=False,
    )
    control_adverse = _evaluate(
        grid,
        development_paths,
        excluded_years=development_excluded,
        weights=control_weights,
        adverse=True,
    )
    control_normal_pct = _pass_pct(control_normal)
    control_adverse_pct = _pass_pct(control_adverse)
    rows: list[dict[str, Any]] = []
    for representation in representation_names:
        mix = REPRESENTATIONS[representation]
        for weight_pct in candidate_grid:
            weights = candidate_weights(control_weights, mix, weight_pct / 100.0)
            normal = _evaluate(
                grid,
                development_paths,
                excluded_years=development_excluded,
                weights=weights,
                adverse=False,
            )
            normal_pct = _pass_pct(normal)
            adverse = None
            adverse_pct = None
            skipped_reason = None
            if normal_pct > control_normal_pct:
                adverse = _evaluate(
                    grid,
                    development_paths,
                    excluded_years=development_excluded,
                    weights=weights,
                    adverse=True,
                )
                adverse_pct = _pass_pct(adverse)
            else:
                skipped_reason = "normal_development_did_not_strictly_improve_control"
            row = {
                "representation": representation,
                "candidate_weight_pct": weight_pct,
                "normal_pass_pct": normal_pct,
                "adverse_pass_pct": adverse_pct,
                "normal": normal,
                "adverse": adverse,
                "adverse_skipped_reason": skipped_reason,
            }
            rows.append(row)
            print(
                f"{representation} weight={weight_pct:g}% "
                f"normal={row['normal_pass_pct']:.4f}% "
                + (
                    f"adverse={row['adverse_pass_pct']:.4f}%"
                    if row["adverse_pass_pct"] is not None
                    else "adverse=SKIPPED_NORMAL_GATE"
                ),
                flush=True,
            )

    winner = select_development_winner(
        rows,
        control_normal=control_normal_pct,
        control_adverse=control_adverse_pct,
    )
    validation: dict[str, Any] | None = None
    confirmation: dict[str, Any] | None = None
    status = "NO_DEVELOPMENT_SURVIVOR"
    if winner is not None and args.stop_after_development:
        status = "DEVELOPMENT_SURVIVOR_PENDING_GLOBAL_SELECTION"
    elif winner is not None:
        representation = str(winner["representation"])
        weight = float(winner["candidate_weight_pct"]) / 100.0
        selected_weights = candidate_weights(control_weights, REPRESENTATIONS[representation], weight)
        validation_excluded = stage_excluded([2023])
        validation_paths, _ = _stage_paths(
            manifest,
            cases,
            incumbent_bars,
            secret_runs,
            secret_bars,
            grid,
            validation_excluded,
        )
        validation_control_normal = _evaluate(
            grid,
            validation_paths,
            excluded_years=validation_excluded,
            weights=control_weights,
            adverse=False,
        )
        validation_control_adverse = _evaluate(
            grid,
            validation_paths,
            excluded_years=validation_excluded,
            weights=control_weights,
            adverse=True,
        )
        validation_candidate_normal = _evaluate(
            grid,
            validation_paths,
            excluded_years=validation_excluded,
            weights=selected_weights,
            adverse=False,
        )
        validation_candidate_adverse = _evaluate(
            grid,
            validation_paths,
            excluded_years=validation_excluded,
            weights=selected_weights,
            adverse=True,
        )
        validation = {
            "included_years": [2023],
            "control_normal": validation_control_normal,
            "control_adverse": validation_control_adverse,
            "candidate_normal": validation_candidate_normal,
            "candidate_adverse": validation_candidate_adverse,
            "normal_delta_pct_points": _pass_pct(validation_candidate_normal)
            - _pass_pct(validation_control_normal),
            "adverse_delta_pct_points": _pass_pct(validation_candidate_adverse)
            - _pass_pct(validation_control_adverse),
        }
        if (
            validation["normal_delta_pct_points"] >= 0.0
            and validation["adverse_delta_pct_points"] >= 0.0
        ):
            status = "VALIDATION_SURVIVOR_RESEARCH_ONLY"
            confirmation_excluded = stage_excluded([2024, 2025])
            confirmation_paths, _ = _stage_paths(
                manifest,
                cases,
                incumbent_bars,
                secret_runs,
                secret_bars,
                grid,
                confirmation_excluded,
            )
            confirmation = {
                "label": "CONTAMINATED_CONFIRMATION_NOT_HOLDOUT_NOT_DEPLOYMENT_EVIDENCE",
                "included_years": [2024, 2025],
                "control_normal": _evaluate(
                    grid,
                    confirmation_paths,
                    excluded_years=confirmation_excluded,
                    weights=control_weights,
                    adverse=False,
                ),
                "control_adverse": _evaluate(
                    grid,
                    confirmation_paths,
                    excluded_years=confirmation_excluded,
                    weights=control_weights,
                    adverse=True,
                ),
                "candidate_normal": _evaluate(
                    grid,
                    confirmation_paths,
                    excluded_years=confirmation_excluded,
                    weights=selected_weights,
                    adverse=False,
                ),
                "candidate_adverse": _evaluate(
                    grid,
                    confirmation_paths,
                    excluded_years=confirmation_excluded,
                    weights=selected_weights,
                    adverse=True,
                ),
            }
        else:
            status = "VALIDATION_FAIL"

    artifact = {
        "schema_version": 1,
        "status": status,
        "label": "RESEARCH_ONLY_NO_GO",
        "deployment_allowed": False,
        "manifest": str(args.manifest),
        "manifest_sha256": sha256(args.manifest),
        "scenario": args.scenario,
        "representations_screened": representation_names,
        "stopped_after_development": bool(args.stop_after_development),
        "timestamp_basis": TIMESTAMP_BASIS_DARWINEX_WALL,
        "path_contract": {
            "secret_adverse_fill": "uncapped_observed_bar_high_low",
            "secret_close_fill": "observed_bar_close",
            "audjpy_bar_resolution": "H1_coarse_disclosed",
            "other_secret_bar_resolution": "M15_or_finer_resampled_to_M15",
            "ftmo_cost_snapshot": "2026-07-11",
        },
        "development": {
            "included_years": [2018, 2019, 2021, 2022],
            "control_normal": control_normal,
            "control_adverse": control_adverse,
            "rows": rows,
            "winner": winner,
        },
        "validation": validation,
        "confirmation": confirmation,
        "sealed_holdout_opened": False,
        "report_evidence": report_evidence,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {args.out} status={status}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
