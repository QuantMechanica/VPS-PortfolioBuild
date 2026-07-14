"""Causal FTMO FX-M5 strategy-family screen with a sealed 2024-2025 holdout.

The screen is intentionally small and structural. It tests session-range and
session-impulse families on exported .DWX bars, selects one winner per family
using 2018-2023 only, and evaluates that locked winner once on 2024-2025.
Costs are conservative all-in price deductions because exported OHLC bars do
not contain an executable ask series.
"""

from __future__ import annotations

import argparse
import datetime as dt
import itertools
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

import numpy as np
import pandas as pd


DEV_START_YEAR = 2018
DEV_END_YEAR = 2022
VALIDATION_YEAR = 2023
HOLDOUT_START_YEAR = 2024
HOLDOUT_END_YEAR = 2025


@dataclass(frozen=True)
class Instrument:
    symbol: str
    path: Path
    timezone: str
    round_trip_cost_points: float


@dataclass(frozen=True)
class Trade:
    entry_time_utc: str
    exit_time_utc: str
    local_date: str
    year: int
    side: int
    r_multiple: float
    mae_r: float
    exit_reason: str


def _values(frame: pd.DataFrame, column: str) -> np.ndarray:
    arrays = frame.attrs.setdefault("column_arrays", {})
    if column not in arrays:
        arrays[column] = frame[column].to_numpy()
    return arrays[column]


def load_bars(instrument: Instrument) -> pd.DataFrame:
    frame = pd.read_csv(instrument.path)
    required = {"time", "open", "high", "low", "close"}
    if not required.issubset(frame.columns):
        missing = sorted(required - set(frame.columns))
        raise ValueError(f"{instrument.path}: missing columns {missing}")
    frame = frame.sort_values("time").reset_index(drop=True)
    frame["utc"] = pd.to_datetime(frame["time"], unit="s", utc=True)
    frame["local"] = frame["utc"].dt.tz_convert(instrument.timezone)
    frame["local_date"] = frame["local"].dt.date
    frame["year"] = frame["local"].dt.year
    frame["weekday"] = frame["local"].dt.weekday
    frame["minute"] = frame["local"].dt.hour * 60 + frame["local"].dt.minute
    previous_close = frame["close"].shift(1)
    true_range = np.maximum(
        frame["high"] - frame["low"],
        np.maximum(abs(frame["high"] - previous_close), abs(frame["low"] - previous_close)),
    )
    frame["atr36"] = pd.Series(true_range).rolling(36, min_periods=36).mean()
    return frame


def _day_indices(frame: pd.DataFrame) -> dict[dt.date, np.ndarray]:
    cached = frame.attrs.get("weekday_day_indices")
    if cached is not None:
        return cached
    weekdays = frame[
        (frame["weekday"] < 5)
        & (frame["year"] >= DEV_START_YEAR)
        & (frame["year"] <= HOLDOUT_END_YEAR)
    ]
    grouped = {
        date: group.index.to_numpy(dtype=np.int64)
        for date, group in weekdays.groupby("local_date", sort=True)
    }
    frame.attrs["weekday_day_indices"] = grouped
    return grouped


def _between(frame: pd.DataFrame, indices: np.ndarray, start_minute: int, end_minute: int) -> np.ndarray:
    minutes = _values(frame, "minute")[indices]
    return indices[(minutes >= start_minute) & (minutes < end_minute)]


def _at_minute(frame: pd.DataFrame, indices: np.ndarray, minute: int) -> int | None:
    matches = indices[_values(frame, "minute")[indices] == minute]
    return int(matches[0]) if len(matches) else None


def _last_before(frame: pd.DataFrame, indices: np.ndarray, minute: int) -> int | None:
    matches = indices[_values(frame, "minute")[indices] < minute]
    return int(matches[-1]) if len(matches) else None


def simulate_trade(
    frame: pd.DataFrame,
    *,
    entry_index: int,
    side: int,
    stop_distance: float,
    target_r: float,
    last_index: int,
    round_trip_cost_points: float,
    entry_price: float | None = None,
) -> Trade | None:
    if side not in (-1, 1) or stop_distance <= 0.0 or target_r <= 0.0:
        return None
    if entry_index < 0 or last_index < entry_index or last_index >= len(frame):
        return None
    opens = _values(frame, "open")
    highs = _values(frame, "high")
    lows = _values(frame, "low")
    closes = _values(frame, "close")
    entry = float(opens[entry_index] if entry_price is None else entry_price)
    stop = entry - side * stop_distance
    target = entry + side * stop_distance * target_r
    cost_r = round_trip_cost_points / stop_distance
    worst_adverse = 0.0
    exit_index = last_index

    for index in range(entry_index, last_index + 1):
        high = float(highs[index])
        low = float(lows[index])
        adverse = low - entry if side > 0 else entry - high
        worst_adverse = min(worst_adverse, adverse)
        stop_hit = low <= stop if side > 0 else high >= stop
        target_hit = high >= target if side > 0 else low <= target
        if stop_hit:
            result_r = -1.0 - cost_r
            reason = "stop_pessimistic" if target_hit else "stop"
            exit_index = index
            break
        if target_hit:
            result_r = target_r - cost_r
            reason = "target"
            exit_index = index
            break
    else:
        result_r = side * (float(closes[last_index]) - entry) / stop_distance - cost_r
        reason = "time"

    return Trade(
        entry_time_utc=_values(frame, "utc")[entry_index].isoformat(),
        exit_time_utc=_values(frame, "utc")[exit_index].isoformat(),
        local_date=_values(frame, "local_date")[entry_index].isoformat(),
        year=int(_values(frame, "year")[entry_index]),
        side=side,
        r_multiple=round(float(result_r), 8),
        mae_r=round(float(min(0.0, worst_adverse / stop_distance - cost_r)), 8),
        exit_reason=reason,
    )


def session_range_trade(
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    range_end_hour: int,
    entry_end_hour: int,
    buffer_fraction: float,
    stop_range_fraction: float,
    target_r: float,
    fade: bool,
) -> list[Trade]:
    trades: list[Trade] = []
    highs = _values(frame, "high")
    lows = _values(frame, "low")
    for indices in _day_indices(frame).values():
        range_indices = _between(frame, indices, 0, range_end_hour * 60)
        active_indices = _between(frame, indices, range_end_hour * 60, entry_end_hour * 60)
        last_index = _last_before(frame, indices, 17 * 60)
        if len(range_indices) < 48 or not len(active_indices) or last_index is None:
            continue
        range_high = float(np.max(highs[range_indices]))
        range_low = float(np.min(lows[range_indices]))
        width = range_high - range_low
        if not np.isfinite(width) or width <= 0.0:
            continue
        buffer = width * buffer_fraction
        upper = range_high + buffer
        lower = range_low - buffer
        trigger_index: int | None = None
        breakout_side = 0
        for index in active_indices:
            long_hit = float(highs[index]) >= upper
            short_hit = float(lows[index]) <= lower
            if long_hit and short_hit:
                trigger_index = None
                breakout_side = 0
                break
            if long_hit or short_hit:
                trigger_index = int(index)
                breakout_side = 1 if long_hit else -1
                break
        if trigger_index is None or breakout_side == 0:
            continue
        side = -breakout_side if fade else breakout_side
        entry_price = upper if breakout_side > 0 else lower
        trade = simulate_trade(
            frame,
            entry_index=trigger_index,
            side=side,
            stop_distance=width * stop_range_fraction,
            target_r=target_r,
            last_index=last_index,
            round_trip_cost_points=instrument.round_trip_cost_points,
            entry_price=entry_price,
        )
        if trade is not None:
            trades.append(trade)
    return trades


def confirmed_session_range_trade(
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    range_end_hour: int,
    entry_end_hour: int,
    buffer_fraction: float,
    stop_range_fraction: float,
    target_r: float,
    rejection: bool,
) -> list[Trade]:
    """Enter on the bar after a confirmed close or a false-break rejection."""
    trades: list[Trade] = []
    highs = _values(frame, "high")
    lows = _values(frame, "low")
    closes = _values(frame, "close")
    minutes = _values(frame, "minute")
    for indices in _day_indices(frame).values():
        range_indices = _between(frame, indices, 0, range_end_hour * 60)
        active_indices = _between(frame, indices, range_end_hour * 60, entry_end_hour * 60)
        last_index = _last_before(frame, indices, 17 * 60)
        if len(range_indices) < 48 or len(active_indices) < 2 or last_index is None:
            continue
        range_high = float(np.max(highs[range_indices]))
        range_low = float(np.min(lows[range_indices]))
        width = range_high - range_low
        if not np.isfinite(width) or width <= 0.0:
            continue
        buffer = width * buffer_fraction
        upper = range_high + buffer
        lower = range_low - buffer
        signal_index: int | None = None
        signal_side = 0
        for index in active_indices[:-1]:
            close = float(closes[index])
            if rejection:
                upper_signal = float(highs[index]) >= upper and close <= range_high
                lower_signal = float(lows[index]) <= lower and close >= range_low
            else:
                upper_signal = close > upper
                lower_signal = close < lower
            if upper_signal and lower_signal:
                signal_index = None
                signal_side = 0
                break
            if upper_signal or lower_signal:
                signal_index = int(index)
                signal_side = 1 if upper_signal else -1
                break
        if signal_index is None or signal_side == 0:
            continue
        day_position = int(np.searchsorted(indices, signal_index))
        if day_position + 1 >= len(indices):
            continue
        entry_index = int(indices[day_position + 1])
        if int(minutes[entry_index]) >= entry_end_hour * 60 or entry_index > last_index:
            continue
        side = -signal_side if rejection else signal_side
        trade = simulate_trade(
            frame,
            entry_index=entry_index,
            side=side,
            stop_distance=width * stop_range_fraction,
            target_r=target_r,
            last_index=last_index,
            round_trip_cost_points=instrument.round_trip_cost_points,
        )
        if trade is not None:
            trades.append(trade)
    return trades


def session_impulse_trade(
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    measure_start_minute: int,
    entry_minute: int,
    exit_minute: int,
    threshold_atr: float,
    stop_atr: float,
    target_r: float,
    continuation: bool,
) -> list[Trade]:
    trades: list[Trade] = []
    opens = _values(frame, "open")
    closes = _values(frame, "close")
    atrs = _values(frame, "atr36")
    for indices in _day_indices(frame).values():
        measure_indices = _between(frame, indices, measure_start_minute, entry_minute)
        entry_index = _at_minute(frame, indices, entry_minute)
        last_index = _last_before(frame, indices, exit_minute)
        if not len(measure_indices) or entry_index is None or last_index is None:
            continue
        if last_index < entry_index or entry_index <= 0:
            continue
        atr = float(atrs[entry_index - 1])
        if not np.isfinite(atr) or atr <= 0.0:
            continue
        move = float(closes[measure_indices[-1]] - opens[measure_indices[0]])
        if abs(move) < threshold_atr * atr:
            continue
        side = 1 if move > 0.0 else -1
        if not continuation:
            side *= -1
        trade = simulate_trade(
            frame,
            entry_index=entry_index,
            side=side,
            stop_distance=stop_atr * atr,
            target_r=target_r,
            last_index=last_index,
            round_trip_cost_points=instrument.round_trip_cost_points,
        )
        if trade is not None:
            trades.append(trade)
    return trades


def summarize(trades: Sequence[Trade]) -> dict[str, Any]:
    values = [trade.r_multiple for trade in trades]
    gross_profit = sum(value for value in values if value > 0.0)
    gross_loss = sum(value for value in values if value < 0.0)
    profit_factor = None if gross_loss == 0.0 else gross_profit / abs(gross_loss)
    equity = 0.0
    peak = 0.0
    max_drawdown = 0.0
    for value in values:
        equity += value
        peak = max(peak, equity)
        max_drawdown = max(max_drawdown, peak - equity)
    return {
        "trades": len(values),
        "net_r": round(sum(values), 6),
        "profit_factor": None if profit_factor is None else round(profit_factor, 6),
        "max_drawdown_r": round(max_drawdown, 6),
        "win_rate": None if not values else round(sum(value > 0.0 for value in values) / len(values), 6),
        "mean_mae_r": None if not trades else round(float(np.mean([trade.mae_r for trade in trades])), 6),
    }


def preholdout_metrics(trades: Sequence[Trade]) -> dict[str, Any]:
    in_scope = [trade for trade in trades if DEV_START_YEAR <= trade.year <= VALIDATION_YEAR]
    annual = {
        str(year): summarize([trade for trade in in_scope if trade.year == year])
        for year in range(DEV_START_YEAR, VALIDATION_YEAR + 1)
    }
    return {
        "dev_2018_2022": summarize([trade for trade in in_scope if trade.year <= DEV_END_YEAR]),
        "validation_2023": summarize(
            [trade for trade in in_scope if trade.year == VALIDATION_YEAR]
        ),
        "annual": annual,
    }


def sealed_holdout_metrics(trades: Sequence[Trade]) -> dict[str, Any]:
    in_scope = [
        trade for trade in trades if HOLDOUT_START_YEAR <= trade.year <= HOLDOUT_END_YEAR
    ]
    return {
        "holdout_2024_2025": summarize(in_scope),
        "annual": {
            str(year): summarize([trade for trade in in_scope if trade.year == year])
            for year in range(HOLDOUT_START_YEAR, HOLDOUT_END_YEAR + 1)
        },
    }


def preholdout_gate_checks(metrics: Mapping[str, Any]) -> dict[str, bool]:
    dev = metrics["dev_2018_2022"]
    validation = metrics["validation_2023"]
    annual = metrics["annual"]
    positive_dev_years = sum(annual[str(year)]["net_r"] > 0.0 for year in range(2018, 2023))
    return {
        "dev_trades": dev["trades"] >= 500,
        "dev_profit_factor": dev["profit_factor"] is not None and dev["profit_factor"] >= 1.12,
        "validation_trades": validation["trades"] >= 80,
        "validation_profit_factor": (
            validation["profit_factor"] is not None and validation["profit_factor"] >= 1.05
        ),
        "validation_net": validation["net_r"] > 0.0,
        "positive_dev_years": positive_dev_years >= 3,
    }


def preholdout_pass(metrics: Mapping[str, Any]) -> bool:
    return all(preholdout_gate_checks(metrics).values())


def holdout_pass(metrics: Mapping[str, Any]) -> bool:
    holdout = metrics["holdout_2024_2025"]
    annual = metrics["annual"]
    return bool(
        holdout["trades"] >= 160
        and holdout["profit_factor"] is not None
        and holdout["profit_factor"] >= 1.08
        and holdout["net_r"] > 0.0
        and annual["2024"]["net_r"] > 0.0
        and annual["2025"]["net_r"] > 0.0
    )


def candidate_score(metrics: Mapping[str, Any]) -> float:
    dev = metrics["dev_2018_2022"]
    validation = metrics["validation_2023"]
    return (
        min(float(dev["profit_factor"]), float(validation["profit_factor"]))
        + min(float(validation["trades"]) / 1000.0, 0.20)
        - min(float(dev["max_drawdown_r"]) / 1000.0, 0.10)
    )


def diagnostic_rank(metrics: Mapping[str, Any]) -> tuple[int, float, int]:
    checks = preholdout_gate_checks(metrics)
    dev_pf = metrics["dev_2018_2022"]["profit_factor"] or 0.0
    validation_pf = metrics["validation_2023"]["profit_factor"] or 0.0
    return (
        sum(checks.values()),
        min(float(dev_pf), float(validation_pf)),
        int(metrics["validation_2023"]["trades"]),
    )


def generate_candidates(
    frame: pd.DataFrame, instrument: Instrument
) -> Iterable[tuple[str, dict[str, Any], list[Trade]]]:
    for fade in (False, True):
        family = "asia_range_fade" if fade else "asia_range_breakout"
        for range_end, entry_end, buffer, stop_fraction, target_r in itertools.product(
            (7, 8), (10, 11), (0.0, 0.05), (0.75, 1.0), (1.0, 1.5)
        ):
            params = {
                "range_end_hour": range_end,
                "entry_end_hour": entry_end,
                "buffer_fraction": buffer,
                "stop_range_fraction": stop_fraction,
                "target_r": target_r,
                "fade": fade,
            }
            yield family, params, session_range_trade(frame, instrument, **params)

    for rejection in (False, True):
        family = "asia_range_rejection" if rejection else "asia_range_close_breakout"
        for range_end, entry_end, buffer, stop_fraction, target_r in itertools.product(
            (7, 8), (10, 11), (0.0, 0.05), (0.75, 1.0), (1.0, 1.5)
        ):
            params = {
                "range_end_hour": range_end,
                "entry_end_hour": entry_end,
                "buffer_fraction": buffer,
                "stop_range_fraction": stop_fraction,
                "target_r": target_r,
                "rejection": rejection,
            }
            yield family, params, confirmed_session_range_trade(frame, instrument, **params)

    windows = (
        ("london_open", 7 * 60, 9 * 60, 12 * 60, (1.0, 2.0)),
        ("ny_overlap", 8 * 60, 13 * 60, 17 * 60, (2.0, 4.0)),
        ("london_fix", 13 * 60, 16 * 60, 18 * 60, (1.5, 3.0)),
    )
    for label, start_minute, entry_minute, exit_minute, thresholds in windows:
        for continuation in (False, True):
            family = f"{label}_{'continuation' if continuation else 'fade'}"
            for threshold, stop_atr, target_r in itertools.product(
                thresholds, (2.0, 3.0), (1.0, 1.5)
            ):
                params = {
                    "measure_start_minute": start_minute,
                    "entry_minute": entry_minute,
                    "exit_minute": exit_minute,
                    "threshold_atr": threshold,
                    "stop_atr": stop_atr,
                    "target_r": target_r,
                    "continuation": continuation,
                }
                yield family, params, session_impulse_trade(frame, instrument, **params)


def screen(instruments: Sequence[Instrument]) -> dict[str, Any]:
    preholdout: list[dict[str, Any]] = []
    diagnostic_rows: list[dict[str, Any]] = []
    evaluated = 0
    for instrument in instruments:
        frame = load_bars(instrument)
        for family, parameters, trades in generate_candidates(frame, instrument):
            evaluated += 1
            metrics = preholdout_metrics(trades)
            diagnostic_rows.append(
                {
                    "symbol": instrument.symbol,
                    "family": family,
                    "parameters": parameters,
                    "metrics": metrics,
                    "gate_checks": preholdout_gate_checks(metrics),
                }
            )
            if not preholdout_pass(metrics):
                continue
            preholdout.append(
                {
                    "symbol": instrument.symbol,
                    "family": family,
                    "parameters": parameters,
                    "preholdout_score": round(candidate_score(metrics), 6),
                    "metrics": metrics,
                    "trades": trades,
                }
            )

    selected: list[dict[str, Any]] = []
    for family in sorted({row["family"] for row in preholdout}):
        family_rows = [row for row in preholdout if row["family"] == family]
        winner = max(family_rows, key=lambda row: row["preholdout_score"])
        holdout = sealed_holdout_metrics(winner["trades"])
        winner["sealed_holdout_metrics"] = holdout
        winner["holdout_verdict"] = "PASS" if holdout_pass(holdout) else "FAIL"
        winner["trades"] = [asdict(trade) for trade in winner["trades"]]
        selected.append(winner)

    family_diagnostics: list[dict[str, Any]] = []
    for family in sorted({row["family"] for row in diagnostic_rows}):
        rows = [row for row in diagnostic_rows if row["family"] == family]
        best = max(rows, key=lambda row: diagnostic_rank(row["metrics"]))
        family_diagnostics.append(best)

    return {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "sealed_holdout": "2024-2025",
            "preholdout_gate": (
                "DEV trades>=500 PF>=1.12; VAL trades>=80 PF>=1.05 net>0; "
                ">=3 positive DEV years"
            ),
            "holdout_gate": "trades>=160 PF>=1.08 net>0 and both 2024/2025 positive",
            "selection_rule": "one preholdout winner per family across all symbols",
            "collision_rule": "stop_first_if_stop_and_target_touch_same_M5_bar",
            "ambiguous_dual_range_break": "skip_day",
            "daily_position_limit_per_candidate": 1,
            "overnight_positions": 0,
            "cost_basis": "conservative all-in round-trip price deduction",
        },
        "instruments": [
            {
                "symbol": instrument.symbol,
                "path": str(instrument.path),
                "timezone": instrument.timezone,
                "round_trip_cost_points": instrument.round_trip_cost_points,
            }
            for instrument in instruments
        ],
        "evaluated_configurations": evaluated,
        "preholdout_pass_count": len(preholdout),
        "preholdout_family_diagnostics": family_diagnostics,
        "selected_family_winners": selected,
        "holdout_pass_count": sum(row["holdout_verdict"] == "PASS" for row in selected),
    }


def default_instruments(root: Path) -> list[Instrument]:
    return [
        Instrument("EURUSD.DWX", root / "EURUSD.DWX_M5.csv", "Europe/London", 0.00016),
        Instrument("GBPUSD.DWX", root / "GBPUSD.DWX_M5.csv", "Europe/London", 0.00020),
        Instrument("USDJPY.DWX", root / "USDJPY.DWX_M5.csv", "Europe/London", 0.018),
        Instrument("GBPJPY.DWX", root / "GBPJPY.DWX_M5.csv", "Europe/London", 0.030),
    ]


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"),
    )
    parser.add_argument("--symbol", action="append", help="limit to exact .DWX symbols")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    instruments = default_instruments(args.data_root)
    if args.symbol:
        requested = set(args.symbol)
        instruments = [instrument for instrument in instruments if instrument.symbol in requested]
        missing = requested - {instrument.symbol for instrument in instruments}
        if missing:
            parser.error(f"unknown symbols: {', '.join(sorted(missing))}")
    missing_files = [str(instrument.path) for instrument in instruments if not instrument.path.exists()]
    if missing_files:
        parser.error("missing export files: " + ", ".join(missing_files))
    artifact = screen(instruments)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "evaluated": artifact["evaluated_configurations"],
                "preholdout_pass": artifact["preholdout_pass_count"],
                "family_winners": len(artifact["selected_family_winners"]),
                "holdout_pass": artifact["holdout_pass_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
