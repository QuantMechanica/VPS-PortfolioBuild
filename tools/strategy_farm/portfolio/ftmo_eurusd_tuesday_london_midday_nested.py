"""Nested causal filters for the EURUSD Tuesday London-midday near miss.

The source session screen already used 2018-2023, so those years are research
here. 2024 is opened once for a frozen filter, and 2025 is loaded into the
trade simulator only after the 2024 gate passes.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any, Mapping, Sequence

import pandas as pd

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m5_fx_session_screen as session
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m5_fx_session_screen as session  # type: ignore


RESEARCH_YEARS = tuple(range(2018, 2024))
VALIDATION_YEAR = 2024
HOLDOUT_YEAR = 2025
FILTERS = (
    "none",
    "prior_day_return_positive",
    "prior_day_return_nonpositive",
    "prior_week_return_positive",
    "prior_week_return_nonpositive",
    "overnight_return_positive",
    "overnight_return_nonpositive",
    "above_20d_sma",
    "below_or_equal_20d_sma",
)


def _local_year(frame: pd.DataFrame) -> pd.Series:
    return frame["utc"].dt.tz_convert("Europe/London").dt.year


def through_year(frame: pd.DataFrame, year: int) -> pd.DataFrame:
    """Return a stable copy ending at the requested London calendar year."""

    return frame.loc[_local_year(frame) <= year].copy().reset_index(drop=True)


def daily_feature_map(frame: pd.DataFrame) -> dict[str, dict[str, float]]:
    """Build entry-time features using only completed prior London days."""

    local = frame["utc"].dt.tz_convert("Europe/London")
    working = frame.assign(local_date=local.dt.date)
    daily = working.groupby("local_date", sort=True).agg(
        day_open=("open", "first"),
        day_close=("close", "last"),
    )
    daily["prior_close"] = daily["day_close"].shift(1)
    daily["prior_day_return"] = daily["day_close"].shift(1) / daily["day_open"].shift(1) - 1.0
    daily["prior_week_return"] = daily["day_close"].shift(1) / daily["day_close"].shift(6) - 1.0
    daily["overnight_return"] = daily["day_open"] / daily["prior_close"] - 1.0
    daily["sma20"] = daily["day_close"].shift(1).rolling(20, min_periods=20).mean()

    entry_rows = working.loc[
        (local.dt.weekday == 1)
        & (local.dt.hour == 11)
        & (local.dt.minute == 0),
        ["utc", "local_date", "open"],
    ]
    output: dict[str, dict[str, float]] = {}
    for row in entry_rows.itertuples(index=False):
        values = daily.loc[row.local_date]
        output[pd.Timestamp(row.utc).isoformat()] = {
            "prior_day_return": float(values["prior_day_return"]),
            "prior_week_return": float(values["prior_week_return"]),
            "overnight_return": float(values["overnight_return"]),
            "entry_price": float(row.open),
            "sma20": float(values["sma20"]),
        }
    return output


def filter_accepts(name: str, features: Mapping[str, float]) -> bool:
    if name == "none":
        return True

    required_keys = {
        "prior_day_return_positive": ("prior_day_return",),
        "prior_day_return_nonpositive": ("prior_day_return",),
        "prior_week_return_positive": ("prior_week_return",),
        "prior_week_return_nonpositive": ("prior_week_return",),
        "overnight_return_positive": ("overnight_return",),
        "overnight_return_nonpositive": ("overnight_return",),
        "above_20d_sma": ("entry_price", "sma20"),
        "below_or_equal_20d_sma": ("entry_price", "sma20"),
    }
    if name not in required_keys:
        raise ValueError(f"unknown filter: {name}")
    if any(key not in features or pd.isna(features[key]) for key in required_keys[name]):
        return False

    if name == "prior_day_return_positive":
        return features["prior_day_return"] > 0.0
    if name == "prior_day_return_nonpositive":
        return features["prior_day_return"] <= 0.0
    if name == "prior_week_return_positive":
        return features["prior_week_return"] > 0.0
    if name == "prior_week_return_nonpositive":
        return features["prior_week_return"] <= 0.0
    if name == "overnight_return_positive":
        return features["overnight_return"] > 0.0
    if name == "overnight_return_nonpositive":
        return features["overnight_return"] <= 0.0
    if name == "above_20d_sma":
        return features["entry_price"] > features["sma20"]
    if name == "below_or_equal_20d_sma":
        return features["entry_price"] <= features["sma20"]
    raise AssertionError(f"unhandled filter: {name}")


def filtered_trades(
    trades: Sequence[base.Trade],
    feature_map: Mapping[str, Mapping[str, float]],
    name: str,
) -> list[base.Trade]:
    if name == "none":
        return list(trades)

    accepted: list[base.Trade] = []
    for trade in trades:
        features = feature_map.get(pd.Timestamp(trade.entry_time_utc).isoformat())
        if features is None:
            continue
        if filter_accepts(name, features):
            accepted.append(trade)
    return accepted


def metrics_for_years(trades: Sequence[base.Trade], years: Sequence[int]) -> dict[str, Any]:
    selected = [trade for trade in trades if trade.year in years]
    annual = {
        str(year): base.summarize([trade for trade in selected if trade.year == year])
        for year in years
    }
    return {
        **base.summarize(selected),
        "positive_years": sum(row["net_r"] > 0.0 for row in annual.values()),
        "annual": annual,
    }


def research_pass(metrics: Mapping[str, Any], control_pf: float) -> bool:
    profit_factor = metrics.get("profit_factor")
    return bool(
        metrics.get("trades", 0) >= 150
        and profit_factor is not None
        and float(profit_factor) >= 1.2
        and float(profit_factor) > control_pf
        and float(metrics.get("net_r", 0.0)) > 0.0
        and int(metrics.get("positive_years", 0)) >= 5
    )


def year_gate(metrics: Mapping[str, Any]) -> bool:
    profit_factor = metrics.get("profit_factor")
    return bool(
        metrics.get("trades", 0) >= 20
        and profit_factor is not None
        and float(profit_factor) >= 1.1
        and float(metrics.get("net_r", 0.0)) > 0.0
    )


def select_research_winner(rows: Sequence[Mapping[str, Any]]) -> Mapping[str, Any] | None:
    eligible = [row for row in rows if bool(row.get("passes_research_gate"))]
    if not eligible:
        return None
    return sorted(
        eligible,
        key=lambda row: (
            -float(row["metrics"]["profit_factor"]),
            -int(row["metrics"]["trades"]),
            str(row["filter"]),
        ),
    )[0]


def generate_base_trades(frame: pd.DataFrame) -> list[base.Trade]:
    instrument = session.Instrument("EURUSD.DWX", Path("unused.csv"), 0.00015)
    spec = session.SessionSpec("london_midday", "Europe/London", 11 * 60, 15 * 60)
    trades = session.fixed_session_trades(
        frame,
        instrument,
        spec,
        stop_range_multiple=16.0,
        target_r=2.0,
        direction=-1,
    )
    return session.weekday_filter(trades, 1)


def evaluate_stage(frame: pd.DataFrame, filter_name: str, years: Sequence[int]) -> tuple[dict[str, Any], list[base.Trade]]:
    trades = filtered_trades(generate_base_trades(frame), daily_feature_map(frame), filter_name)
    return metrics_for_years(trades, years), trades


def run_screen(data_path: Path) -> dict[str, Any]:
    instrument = session.Instrument("EURUSD.DWX", data_path, 0.00015)
    full_frame = session.load_bars(instrument)

    research_frame = through_year(full_frame, max(RESEARCH_YEARS))
    research_trades = generate_base_trades(research_frame)
    research_features = daily_feature_map(research_frame)
    control_metrics = metrics_for_years(
        filtered_trades(research_trades, research_features, "none"),
        RESEARCH_YEARS,
    )
    control_pf = float(control_metrics["profit_factor"] or 0.0)
    research_rows: list[dict[str, Any]] = []
    for name in FILTERS:
        metrics = metrics_for_years(
            filtered_trades(research_trades, research_features, name),
            RESEARCH_YEARS,
        )
        research_rows.append(
            {
                "filter": name,
                "metrics": metrics,
                "passes_research_gate": name != "none" and research_pass(metrics, control_pf),
            }
        )

    winner = select_research_winner(research_rows)
    artifact: dict[str, Any] = {
        "schema_version": 1,
        "status": "RESEARCH_GATE_FAIL",
        "selection_contract": {
            "research_years": list(RESEARCH_YEARS),
            "validation_year": VALIDATION_YEAR,
            "sealed_holdout_year": HOLDOUT_YEAR,
            "filters": list(FILTERS),
            "timestamp_basis": "Darwinex broker wall converted to UTC then Europe/London",
            "same_bar_rule": "stop_first",
            "round_trip_cost_points": 0.00015,
        },
        "base_parameters": {
            "symbol": "EURUSD.DWX",
            "weekday": 1,
            "entry_minute": 660,
            "exit_minute": 900,
            "direction": -1,
            "stop_atr288_multiple": 16.0,
            "target_r": 2.0,
        },
        "research_control": control_metrics,
        "research_rows": research_rows,
        "selected_filter": None,
        "validation_2024": None,
        "validation_opened": False,
        "holdout_2025": None,
        "holdout_opened": False,
        "trades": None,
    }
    if winner is None:
        return artifact

    selected_filter = str(winner["filter"])
    artifact["selected_filter"] = selected_filter
    artifact["validation_opened"] = True
    validation_frame = through_year(full_frame, VALIDATION_YEAR)
    validation_metrics, _ = evaluate_stage(
        validation_frame,
        selected_filter,
        [VALIDATION_YEAR],
    )
    artifact["validation_2024"] = validation_metrics
    if not year_gate(validation_metrics):
        artifact["status"] = "VALIDATION_2024_FAIL"
        return artifact

    artifact["holdout_opened"] = True
    holdout_frame = through_year(full_frame, HOLDOUT_YEAR)
    holdout_metrics, all_selected_trades = evaluate_stage(
        holdout_frame,
        selected_filter,
        [HOLDOUT_YEAR],
    )
    artifact["holdout_2025"] = holdout_metrics
    artifact["status"] = "HOLDOUT_SURVIVOR_FOUND" if year_gate(holdout_metrics) else "HOLDOUT_2025_FAIL"
    artifact["trades"] = [asdict(trade) for trade in all_selected_trades]
    return artifact


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-path",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\MQL5\Files\EURUSD.DWX_M5.csv"),
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    artifact = run_screen(args.data_path)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": artifact["status"],
                "selected_filter": artifact["selected_filter"],
                "validation_opened": artifact["validation_opened"],
                "holdout_opened": artifact["holdout_opened"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
