"""Sealed M15 screen for current-cost overnight session premia."""

from __future__ import annotations

import argparse
import itertools
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Sequence

import numpy as np
import pandas as pd

try:
    from . import ftmo_intraday_candidate_screen as base
    from . import ftmo_m15_causal_strategy_screen as m15
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_intraday_candidate_screen as base  # type: ignore
    import ftmo_m15_causal_strategy_screen as m15  # type: ignore


@dataclass(frozen=True)
class OvernightInstrument:
    instrument: m15.Instrument
    swap_long_points: float
    swap_short_points: float
    digits: int


def overnight_trades(
    frame: pd.DataFrame,
    spec: OvernightInstrument,
    *,
    entry_bars_before_close: int,
    exit_bars_after_next_open: int,
    stop_atr: float,
    target_r: float,
    direction: int,
    entry_weekday: int,
    end_year: int,
) -> list[base.Trade]:
    instrument = spec.instrument
    sessions = m15.session_days(frame, instrument)
    opens = m15._values(frame, "open")
    highs = m15._values(frame, "high")
    lows = m15._values(frame, "low")
    atrs = m15._values(frame, "atr56")
    weekdays = m15._values(frame, "weekday")
    years = m15._values(frame, "year")
    utc_values = m15._values(frame, "utc")
    local_dates = m15._values(frame, "local_date")
    trades: list[base.Trade] = []

    if direction not in (-1, 1) or entry_bars_before_close <= 0:
        return trades

    for session_number in range(len(sessions) - 1):
        indices = sessions[session_number]
        next_indices = sessions[session_number + 1]
        if len(indices) < entry_bars_before_close or not next_indices:
            continue
        entry_index = indices[-entry_bars_before_close]
        weekday = int(weekdays[entry_index])
        year = int(years[entry_index])
        if year > end_year or weekday >= 4:
            continue
        if entry_weekday >= 0 and weekday != entry_weekday:
            continue
        if exit_bars_after_next_open < 0 or exit_bars_after_next_open >= len(next_indices):
            continue
        exit_index = next_indices[exit_bars_after_next_open]
        entry_timestamp = pd.Timestamp(utc_values[entry_index])
        exit_timestamp = pd.Timestamp(utc_values[exit_index])
        elapsed_days = (exit_timestamp.date() - entry_timestamp.date()).days
        if elapsed_days <= 0 or elapsed_days > 4 or exit_index <= entry_index:
            continue

        atr_index = entry_index - 1
        if atr_index < 0:
            continue
        atr = float(atrs[atr_index])
        entry = float(opens[entry_index])
        stop_distance = stop_atr * atr
        if not np.isfinite(atr) or atr <= 0.0 or entry <= 0.0 or stop_distance <= 0.0:
            continue

        stop = entry - direction * stop_distance
        target = entry + direction * stop_distance * target_r if target_r > 0.0 else 0.0
        result_r: float | None = None
        reason = "next_open"
        for index in range(entry_index, exit_index):
            high = float(highs[index])
            low = float(lows[index])
            stop_hit = low <= stop if direction > 0 else high >= stop
            target_hit = target_r > 0.0 and (
                high >= target if direction > 0 else low <= target
            )
            if stop_hit:
                result_r = -1.0
                reason = "stop_pessimistic" if target_hit else "stop"
                break
            if target_hit:
                result_r = target_r
                reason = "target"
                break
        if result_r is None:
            result_r = direction * (float(opens[exit_index]) - entry) / stop_distance

        cost_r = instrument.round_trip_cost_points / stop_distance
        swap_points = spec.swap_long_points if direction > 0 else spec.swap_short_points
        rollover_units = 3 if weekday == 2 else 1
        # Never credit positive swap in the research screen, and charge negative
        # swap even if a stop or target might have exited before midnight.
        conservative_swap_price = min(0.0, swap_points) * (10.0 ** -spec.digits) * rollover_units
        result_r = result_r - cost_r + conservative_swap_price / stop_distance
        trades.append(
            base.Trade(
                entry_time_utc=entry_timestamp.isoformat(),
                local_date=str(local_dates[entry_index]),
                year=year,
                side=direction,
                r_multiple=float(result_r),
                exit_reason=f"overnight:{reason}",
            )
        )
    return trades


def preholdout_pass(metrics: dict[str, Any]) -> bool:
    dev = metrics["dev_2018_2022"]
    validation = metrics["validation_2023"]
    positive_dev_years = sum(
        metrics["annual"].get(str(year), {}).get("net_r", 0.0) > 0.0
        for year in range(2018, 2023)
    )
    return bool(
        dev["trades"] >= 200
        and dev["net_r"] > 0.0
        and (dev["profit_factor"] or 0.0) >= 1.18
        and validation["trades"] >= 40
        and validation["net_r"] > 0.0
        and (validation["profit_factor"] or 0.0) >= 1.10
        and positive_dev_years >= 4
    )


def holdout_pass(metrics: dict[str, Any]) -> bool:
    holdout = metrics["holdout_2024_2025"]
    annual = metrics["annual"]
    return bool(
        holdout["trades"] >= 80
        and holdout["net_r"] > 0.0
        and (holdout["profit_factor"] or 0.0) >= 1.10
        and annual.get("2024", {}).get("net_r", 0.0) > 0.0
        and annual.get("2025", {}).get("net_r", 0.0) > 0.0
    )


def score(row: dict[str, Any]) -> float:
    metrics = row["metrics"]
    return min(
        float(metrics["dev_2018_2022"]["profit_factor"] or 0.0),
        float(metrics["validation_2023"]["profit_factor"] or 0.0),
    )


def default_overnight_instruments(root: Path) -> list[OvernightInstrument]:
    instruments = {item.symbol: item for item in m15.default_instruments(root)}
    return [
        OvernightInstrument(instruments["GDAXI.DWX"], -424.13, -27.07, 2),
        OvernightInstrument(instruments["NDX.DWX"], -626.88, 19.57, 2),
        OvernightInstrument(instruments["SP500.DWX"], -86.56, -68.93, 2),
        OvernightInstrument(instruments["WS30.DWX"], -1135.86, 47.27, 2),
        OvernightInstrument(instruments["XAUUSD.DWX"], -75.93, -23.55, 2),
    ]


def _parameter_grid() -> list[dict[str, Any]]:
    return [
        {
            "entry_bars_before_close": entry_before,
            "exit_bars_after_next_open": exit_after,
            "stop_atr": stop_atr,
            "target_r": target_r,
            "direction": direction,
            "entry_weekday": weekday,
        }
        for entry_before, exit_after, stop_atr, target_r, direction, weekday in itertools.product(
            (1, 4, 8),
            (0, 2, 4),
            (1.0, 2.0, 3.0),
            (0.0, 3.0),
            (-1, 1),
            (-1, 0, 1, 2, 3),
        )
    ]


def _path_parameter_grid() -> list[dict[str, Any]]:
    return [
        {
            "entry_bars_before_close": entry_before,
            "exit_bars_after_next_open": exit_after,
            "stop_atr": stop_atr,
            "target_r": target_r,
            "direction": direction,
        }
        for entry_before, exit_after, stop_atr, target_r, direction in itertools.product(
            (1, 4, 8),
            (0, 2, 4),
            (1.0, 2.0, 3.0),
            (0.0, 3.0),
            (-1, 1),
        )
    ]


def screen(data_root: Path) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    parameter_grid = _parameter_grid()
    path_parameter_grid = _path_parameter_grid()
    frames: dict[str, pd.DataFrame] = {}
    specs = default_overnight_instruments(data_root)
    for spec in specs:
        symbol = spec.instrument.symbol
        frame = frames.setdefault(symbol, m15.load_bars(spec.instrument))
        for path_parameters in path_parameter_grid:
            all_trades = overnight_trades(
                frame, spec, **path_parameters, entry_weekday=-1, end_year=2023
            )
            trade_weekdays = [
                pd.Timestamp(trade.entry_time_utc).tz_convert(spec.instrument.timezone).weekday()
                for trade in all_trades
            ]
            for weekday in (-1, 0, 1, 2, 3):
                trades = (
                    all_trades
                    if weekday < 0
                    else [
                        trade
                        for trade, trade_weekday in zip(all_trades, trade_weekdays)
                        if trade_weekday == weekday
                    ]
                )
                rows.append(
                    {
                        "symbol": symbol,
                        "parameters": {**path_parameters, "entry_weekday": weekday},
                        "metrics": base.split_metrics(trades),
                    }
                )
        print(
            json.dumps(
                {"stage": "evaluated", "symbol": symbol, "configurations": len(parameter_grid)}
            ),
            flush=True,
        )

    eligible = [row for row in rows if preholdout_pass(row["metrics"])]
    winner = max(
        eligible,
        key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]),
        default=None,
    )
    selected: dict[str, Any] | None = None
    if winner is not None:
        spec = next(item for item in specs if item.instrument.symbol == winner["symbol"])
        trades = overnight_trades(
            frames[winner["symbol"]], spec, **winner["parameters"], end_year=2025
        )
        metrics = base.split_metrics(trades)
        selected = {
            "symbol": winner["symbol"],
            "parameters": winner["parameters"],
            "preholdout_score": score(winner),
            "metrics": metrics,
            "holdout_verdict": "PASS" if holdout_pass(metrics) else "FAIL",
            "trades": [asdict(trade) for trade in trades],
        }

    leaders = sorted(
        rows,
        key=lambda row: (score(row), row["metrics"]["dev_2018_2022"]["trades"]),
        reverse=True,
    )[:20]
    return {
        "schema_version": 1,
        "status": (
            "HOLDOUT_SURVIVOR_FOUND"
            if selected is not None and selected["holdout_verdict"] == "PASS"
            else "NO_HOLDOUT_SURVIVOR"
        ),
        "predeclaration": "artifacts/ftmo_m15_overnight_session_premium_predeclaration_2026-07-12.json",
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "selection_uses_holdout": False,
            "winner_count": 1,
            "holdout_opened": selected is not None,
            "same_bar_rule": "stop_first",
            "positive_swap_credit": False,
        },
        "evaluated_configurations": len(rows),
        "preholdout_pass_count": len(eligible),
        "preholdout_leaderboard": [
            {
                "symbol": row["symbol"],
                "parameters": row["parameters"],
                "preholdout_score": score(row),
                "dev_2018_2022": row["metrics"]["dev_2018_2022"],
                "validation_2023": row["metrics"]["validation_2023"],
                "positive_development_years": sum(
                    row["metrics"]["annual"].get(str(year), {}).get("net_r", 0.0) > 0.0
                    for year in range(2018, 2023)
                ),
            }
            for row in leaders
        ],
        "selected_global_winner": selected,
        "holdout_pass_count": int(
            selected is not None and selected["holdout_verdict"] == "PASS"
        ),
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    output = screen(args.data_root)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": output["status"],
                "evaluated": output["evaluated_configurations"],
                "preholdout_pass": output["preholdout_pass_count"],
                "holdout_pass": output["holdout_pass_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
