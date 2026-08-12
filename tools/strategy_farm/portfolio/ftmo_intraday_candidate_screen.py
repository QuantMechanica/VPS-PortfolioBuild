from __future__ import annotations

import argparse
import datetime as dt
import itertools
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Iterable, Sequence

import numpy as np
import pandas as pd


DEV_END_YEAR = 2022
VALIDATION_YEAR = 2023
HOLDOUT_START_YEAR = 2024


@dataclass(frozen=True)
class Instrument:
    symbol: str
    path: Path
    timezone: str
    open_hour: int
    close_hour: int
    shock_hours: tuple[int, ...]
    round_trip_cost_points: float


@dataclass(frozen=True)
class Trade:
    entry_time_utc: str
    local_date: str
    year: int
    side: int
    r_multiple: float
    exit_reason: str


def _values(frame: pd.DataFrame, column: str) -> np.ndarray:
    arrays = frame.attrs.setdefault("column_arrays", {})
    if column not in arrays:
        arrays[column] = frame[column].to_numpy()
    return arrays[column]


def broker_wall_seconds_to_utc(values: pd.Series) -> pd.Series:
    """Convert Darwinex GMT+2/+3 broker-wall epochs to real UTC instants.

    MT5 exports its wall-clock ``datetime`` integer. Interpreting that integer
    directly as Unix UTC shifts all sessions by the broker offset. Darwinex
    follows US DST: UTC+3 while New York is on daylight time, UTC+2 otherwise.
    """

    broker_wall = pd.to_datetime(values, unit="s", utc=True)
    dst_candidate = broker_wall - pd.Timedelta(hours=3)
    dst_valid = np.fromiter(
        (
            timestamp.dst() is not None and timestamp.dst() != dt.timedelta(0)
            for timestamp in dst_candidate.dt.tz_convert("America/New_York")
        ),
        dtype=bool,
        count=len(dst_candidate),
    )
    standard_candidate = broker_wall - pd.Timedelta(hours=2)
    return dst_candidate.where(dst_valid, standard_candidate)


def load_bars(instrument: Instrument) -> pd.DataFrame:
    frame = pd.read_csv(instrument.path)
    required = {"time", "open", "high", "low", "close"}
    if not required.issubset(frame.columns):
        raise ValueError(f"{instrument.path}: missing columns {sorted(required - set(frame.columns))}")
    frame = frame.sort_values("time").reset_index(drop=True)
    frame["utc"] = broker_wall_seconds_to_utc(frame["time"])
    frame["local"] = frame["utc"].dt.tz_convert(instrument.timezone)
    frame["local_date"] = frame["local"].dt.date
    frame["year"] = frame["local"].dt.year
    frame["hour"] = frame["local"].dt.hour
    frame["weekday"] = frame["local"].dt.weekday
    previous_close = frame["close"].shift(1)
    true_range = np.maximum(
        frame["high"] - frame["low"],
        np.maximum(abs(frame["high"] - previous_close), abs(frame["low"] - previous_close)),
    )
    frame["atr14"] = pd.Series(true_range).rolling(14, min_periods=14).mean()
    return frame


def simulate_market_trade(
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

    for index in range(entry_index, last_index + 1):
        high = float(highs[index])
        low = float(lows[index])
        stop_hit = low <= stop if side > 0 else high >= stop
        target_hit = high >= target if side > 0 else low <= target
        if stop_hit:
            result_r = -1.0 - cost_r
            reason = "stop_pessimistic" if target_hit else "stop"
            break
        if target_hit:
            result_r = target_r - cost_r
            reason = "target"
            break
    else:
        exit_price = float(closes[last_index])
        result_r = side * (exit_price - entry) / stop_distance - cost_r
        reason = "time"

    return Trade(
        entry_time_utc=_values(frame, "utc")[entry_index].isoformat(),
        local_date=_values(frame, "local_date")[entry_index].isoformat(),
        year=int(_values(frame, "year")[entry_index]),
        side=side,
        r_multiple=round(float(result_r), 8),
        exit_reason=reason,
    )


def _day_indices(frame: pd.DataFrame) -> dict[dt.date, list[int]]:
    cached = frame.attrs.get("weekday_day_indices")
    if cached is not None:
        return cached
    weekdays = frame[frame["weekday"] < 5]
    grouped = {
        date: [int(index) for index in group.index]
        for date, group in weekdays.groupby("local_date", sort=True)
    }
    frame.attrs["weekday_day_indices"] = grouped
    return grouped


def _hour_index(frame: pd.DataFrame, indices: Sequence[int], hour: int) -> int | None:
    hours = _values(frame, "hour")
    matches = [index for index in indices if int(hours[index]) == hour]
    return matches[0] if matches else None


def _last_exit_index(frame: pd.DataFrame, indices: Sequence[int], close_hour: int) -> int | None:
    hours = _values(frame, "hour")
    eligible = [index for index in indices if int(hours[index]) <= close_hour]
    return eligible[-1] if eligible else None


def shock_fade(
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    decision_hour: int,
    shock_atr: float,
    stop_atr: float,
    target_r: float,
    hold_bars: int,
) -> list[Trade]:
    trades: list[Trade] = []
    local_dates = _values(frame, "local_date")
    atr_values = _values(frame, "atr14")
    opens = _values(frame, "open")
    closes = _values(frame, "close")
    highs = _values(frame, "high")
    lows = _values(frame, "low")
    for indices in _day_indices(frame).values():
        entry_index = _hour_index(frame, indices, decision_hour)
        if entry_index is None or entry_index <= 0:
            continue
        previous_index = entry_index - 1
        if local_dates[previous_index] != local_dates[entry_index]:
            continue
        atr = float(atr_values[previous_index])
        if not np.isfinite(atr) or atr <= 0.0:
            continue
        open_price = float(opens[previous_index])
        close_price = float(closes[previous_index])
        high = float(highs[previous_index])
        low = float(lows[previous_index])
        body = close_price - open_price
        bar_range = high - low
        if abs(body) < shock_atr * atr or bar_range <= 0.0:
            continue
        close_location = (close_price - low) / bar_range
        if body > 0.0 and close_location < 0.70:
            continue
        if body < 0.0 and close_location > 0.30:
            continue
        day_exit = _last_exit_index(frame, indices, instrument.close_hour)
        if day_exit is None:
            continue
        last_index = min(day_exit, entry_index + hold_bars - 1)
        trade = simulate_market_trade(
            frame,
            entry_index=entry_index,
            side=-1 if body > 0.0 else 1,
            stop_distance=stop_atr * atr,
            target_r=target_r,
            last_index=last_index,
            round_trip_cost_points=instrument.round_trip_cost_points,
        )
        if trade is not None:
            trades.append(trade)
    return trades


def opening_impulse(
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    entry_hour: int,
    impulse_atr: float,
    stop_atr: float,
    target_r: float,
    continuation: bool,
) -> list[Trade]:
    trades: list[Trade] = []
    atr_values = _values(frame, "atr14")
    opens = _values(frame, "open")
    closes = _values(frame, "close")
    for indices in _day_indices(frame).values():
        open_index = _hour_index(frame, indices, instrument.open_hour)
        entry_index = _hour_index(frame, indices, entry_hour)
        day_exit = _last_exit_index(frame, indices, instrument.close_hour)
        if open_index is None or entry_index is None or day_exit is None or entry_index <= open_index:
            continue
        prior_indices = [index for index in indices if open_index <= index < entry_index]
        if not prior_indices:
            continue
        atr = float(atr_values[entry_index - 1])
        if not np.isfinite(atr) or atr <= 0.0:
            continue
        impulse = float(closes[prior_indices[-1]] - opens[open_index])
        if abs(impulse) < impulse_atr * atr:
            continue
        side = 1 if impulse > 0.0 else -1
        if not continuation:
            side *= -1
        trade = simulate_market_trade(
            frame,
            entry_index=entry_index,
            side=side,
            stop_distance=stop_atr * atr,
            target_r=target_r,
            last_index=day_exit,
            round_trip_cost_points=instrument.round_trip_cost_points,
        )
        if trade is not None:
            trades.append(trade)
    return trades


def opening_range_breakout(
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    range_bars: int,
    buffer_atr: float,
    target_r: float,
    max_range_atr: float,
) -> list[Trade]:
    trades: list[Trade] = []
    atr_values = _values(frame, "atr14")
    highs = _values(frame, "high")
    lows = _values(frame, "low")
    for indices in _day_indices(frame).values():
        open_index = _hour_index(frame, indices, instrument.open_hour)
        day_exit = _last_exit_index(frame, indices, instrument.close_hour)
        if open_index is None or day_exit is None:
            continue
        range_indices = list(range(open_index, open_index + range_bars))
        trigger_index = open_index + range_bars
        if trigger_index > day_exit or any(index not in indices for index in range_indices + [trigger_index]):
            continue
        atr = float(atr_values[range_indices[-1]])
        if not np.isfinite(atr) or atr <= 0.0:
            continue
        range_high = float(max(highs[index] for index in range_indices))
        range_low = float(min(lows[index] for index in range_indices))
        range_width = range_high - range_low
        if range_width <= 0.0 or range_width > max_range_atr * atr:
            continue
        buffer = buffer_atr * atr
        long_entry = range_high + buffer
        short_entry = range_low - buffer
        trigger_high = float(highs[trigger_index])
        trigger_low = float(lows[trigger_index])
        long_hit = trigger_high >= long_entry
        short_hit = trigger_low <= short_entry
        if not long_hit and not short_hit:
            continue
        # H1 cannot identify which pending side fired first when both levels
        # trade. A live OCO pair will still fill one side and, because price
        # also crossed the opposite range boundary, that first position can
        # stop. Count the day as a pessimistic long-stop instead of silently
        # deleting the hardest trigger bars from the sample.
        side = 1 if long_hit else -1
        entry_price = long_entry if long_hit else short_entry
        stop_distance = range_width + buffer
        trade = simulate_market_trade(
            frame,
            entry_index=trigger_index,
            side=side,
            stop_distance=stop_distance,
            target_r=target_r,
            last_index=day_exit,
            round_trip_cost_points=instrument.round_trip_cost_points,
            entry_price=entry_price,
        )
        if trade is not None:
            trades.append(trade)
    return trades


def session_gap(
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    gap_atr: float,
    stop_atr: float,
    target_r: float,
    continuation: bool,
) -> list[Trade]:
    trades: list[Trade] = []
    atr_values = _values(frame, "atr14")
    opens = _values(frame, "open")
    closes = _values(frame, "close")
    grouped = list(_day_indices(frame).items())
    for position in range(1, len(grouped)):
        _, previous_indices = grouped[position - 1]
        _, indices = grouped[position]
        open_index = _hour_index(frame, indices, instrument.open_hour)
        previous_close_index = _last_exit_index(frame, previous_indices, instrument.close_hour)
        day_exit = _last_exit_index(frame, indices, instrument.close_hour)
        if open_index is None or previous_close_index is None or day_exit is None:
            continue
        atr = float(atr_values[open_index])
        if not np.isfinite(atr) or atr <= 0.0:
            continue
        gap = float(opens[open_index] - closes[previous_close_index])
        if abs(gap) < gap_atr * atr:
            continue
        side = 1 if gap > 0.0 else -1
        if not continuation:
            side *= -1
        trade = simulate_market_trade(
            frame,
            entry_index=open_index,
            side=side,
            stop_distance=stop_atr * atr,
            target_r=target_r,
            last_index=day_exit,
            round_trip_cost_points=instrument.round_trip_cost_points,
        )
        if trade is not None:
            trades.append(trade)
    return trades


def previous_session_move(
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    move_atr: float,
    stop_atr: float,
    target_r: float,
    continuation: bool,
    weekday: int | None,
) -> list[Trade]:
    trades: list[Trade] = []
    atr_values = _values(frame, "atr14")
    opens = _values(frame, "open")
    closes = _values(frame, "close")
    grouped = list(_day_indices(frame).items())
    for position in range(1, len(grouped)):
        date, indices = grouped[position]
        _, previous_indices = grouped[position - 1]
        if weekday is not None and date.weekday() != weekday:
            continue
        entry_index = _hour_index(frame, indices, instrument.open_hour)
        day_exit = _last_exit_index(frame, indices, instrument.close_hour)
        previous_open = _hour_index(frame, previous_indices, instrument.open_hour)
        previous_close = _last_exit_index(frame, previous_indices, instrument.close_hour)
        if None in (entry_index, day_exit, previous_open, previous_close):
            continue
        assert entry_index is not None and day_exit is not None
        assert previous_open is not None and previous_close is not None
        atr = float(atr_values[previous_close])
        if not np.isfinite(atr) or atr <= 0.0:
            continue
        move = float(closes[previous_close] - opens[previous_open])
        if abs(move) < move_atr * atr:
            continue
        side = 1 if move > 0.0 else -1
        if not continuation:
            side *= -1
        trade = simulate_market_trade(
            frame,
            entry_index=entry_index,
            side=side,
            stop_distance=stop_atr * atr,
            target_r=target_r,
            last_index=day_exit,
            round_trip_cost_points=instrument.round_trip_cost_points,
        )
        if trade is not None:
            trades.append(trade)
    return trades


def prior_close_location(
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    range_atr: float,
    location_tail: float,
    stop_atr: float,
    target_r: float,
    continuation: bool,
) -> list[Trade]:
    trades: list[Trade] = []
    atr_values = _values(frame, "atr14")
    highs = _values(frame, "high")
    lows = _values(frame, "low")
    closes = _values(frame, "close")
    grouped = list(_day_indices(frame).items())
    for position in range(1, len(grouped)):
        _, previous_indices = grouped[position - 1]
        _, indices = grouped[position]
        entry_index = _hour_index(frame, indices, instrument.open_hour)
        day_exit = _last_exit_index(frame, indices, instrument.close_hour)
        previous_close = _last_exit_index(frame, previous_indices, instrument.close_hour)
        if entry_index is None or day_exit is None or previous_close is None:
            continue
        session_high = float(max(highs[index] for index in previous_indices))
        session_low = float(min(lows[index] for index in previous_indices))
        session_range = session_high - session_low
        atr = float(atr_values[previous_close])
        if not np.isfinite(atr) or atr <= 0.0 or session_range < range_atr * atr:
            continue
        location = (float(closes[previous_close]) - session_low) / session_range
        if location >= 1.0 - location_tail:
            side = 1
        elif location <= location_tail:
            side = -1
        else:
            continue
        if not continuation:
            side *= -1
        trade = simulate_market_trade(
            frame,
            entry_index=entry_index,
            side=side,
            stop_distance=stop_atr * atr,
            target_r=target_r,
            last_index=day_exit,
            round_trip_cost_points=instrument.round_trip_cost_points,
        )
        if trade is not None:
            trades.append(trade)
    return trades


def inside_day_breakout(
    frame: pd.DataFrame,
    instrument: Instrument,
    *,
    buffer_atr: float,
    target_r: float,
    max_range_atr: float,
) -> list[Trade]:
    trades: list[Trade] = []
    atr_values = _values(frame, "atr14")
    highs = _values(frame, "high")
    lows = _values(frame, "low")
    grouped = list(_day_indices(frame).items())
    for position in range(2, len(grouped)):
        _, outer_indices = grouped[position - 2]
        _, inside_indices = grouped[position - 1]
        _, indices = grouped[position]
        day_open = _hour_index(frame, indices, instrument.open_hour)
        day_exit = _last_exit_index(frame, indices, instrument.close_hour)
        inside_close = _last_exit_index(frame, inside_indices, instrument.close_hour)
        if day_open is None or day_exit is None or inside_close is None:
            continue
        outer_high = float(max(highs[index] for index in outer_indices))
        outer_low = float(min(lows[index] for index in outer_indices))
        inside_high = float(max(highs[index] for index in inside_indices))
        inside_low = float(min(lows[index] for index in inside_indices))
        if not (inside_high < outer_high and inside_low > outer_low):
            continue
        atr = float(atr_values[inside_close])
        range_width = inside_high - inside_low
        if (
            not np.isfinite(atr)
            or atr <= 0.0
            or range_width <= 0.0
            or range_width > max_range_atr * atr
        ):
            continue
        buffer = buffer_atr * atr
        long_entry = inside_high + buffer
        short_entry = inside_low - buffer
        trigger_index = None
        side = 0
        for index in indices:
            if index < day_open or index > day_exit:
                continue
            long_hit = float(highs[index]) >= long_entry
            short_hit = float(lows[index]) <= short_entry
            if long_hit and short_hit:
                trigger_index = None
                side = 0
                break
            if long_hit or short_hit:
                trigger_index = index
                side = 1 if long_hit else -1
                break
        if trigger_index is None or side == 0:
            continue
        trade = simulate_market_trade(
            frame,
            entry_index=trigger_index,
            side=side,
            stop_distance=range_width + buffer,
            target_r=target_r,
            last_index=day_exit,
            round_trip_cost_points=instrument.round_trip_cost_points,
            entry_price=long_entry if side > 0 else short_entry,
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
    }


def split_metrics(trades: Sequence[Trade]) -> dict[str, Any]:
    dev = [trade for trade in trades if trade.year <= DEV_END_YEAR]
    validation = [trade for trade in trades if trade.year == VALIDATION_YEAR]
    holdout = [trade for trade in trades if trade.year >= HOLDOUT_START_YEAR]
    annual = {
        str(year): summarize([trade for trade in trades if trade.year == year])
        for year in sorted({trade.year for trade in trades})
    }
    return {
        "dev_2018_2022": summarize(dev),
        "validation_2023": summarize(validation),
        "holdout_2024_2025": summarize(holdout),
        "annual": annual,
    }


def preholdout_pass(metrics: dict[str, Any]) -> bool:
    dev = metrics["dev_2018_2022"]
    validation = metrics["validation_2023"]
    dev_years = [metrics["annual"].get(str(year), summarize([])) for year in range(2018, 2023)]
    positive_dev_years = sum(year["net_r"] > 0.0 for year in dev_years)
    return bool(
        dev["trades"] >= 100
        and dev["profit_factor"] is not None
        and dev["profit_factor"] >= 1.15
        and validation["trades"] >= 15
        and validation["profit_factor"] is not None
        and validation["profit_factor"] >= 1.05
        and validation["net_r"] > 0.0
        and positive_dev_years >= 3
    )


def holdout_pass(metrics: dict[str, Any]) -> bool:
    holdout = metrics["holdout_2024_2025"]
    annual = metrics["annual"]
    return bool(
        holdout["trades"] >= 30
        and holdout["profit_factor"] is not None
        and holdout["profit_factor"] >= 1.10
        and holdout["net_r"] > 0.0
        and annual.get("2024", {}).get("net_r", 0.0) > 0.0
        and annual.get("2025", {}).get("net_r", 0.0) > 0.0
    )


def candidate_score(metrics: dict[str, Any]) -> float:
    dev = metrics["dev_2018_2022"]
    validation = metrics["validation_2023"]
    return min(float(dev["profit_factor"]), float(validation["profit_factor"])) + min(
        validation["trades"] / 200.0, 0.25
    )


def generate_candidates(frame: pd.DataFrame, instrument: Instrument) -> Iterable[tuple[str, dict[str, Any], list[Trade]]]:
    for decision_hour, shock_atr, stop_atr, target_r, hold_bars in itertools.product(
        instrument.shock_hours, (0.8, 1.2), (1.0,), (1.0, 1.5), (3,)
    ):
        params = {
            "decision_hour": decision_hour,
            "shock_atr": shock_atr,
            "stop_atr": stop_atr,
            "target_r": target_r,
            "hold_bars": hold_bars,
        }
        yield "shock_fade", params, shock_fade(frame, instrument, **params)

    for entry_offset, impulse_atr, stop_atr, target_r, continuation in itertools.product(
        (2, 3), (0.5, 1.0), (1.0,), (1.0, 1.5), (False, True)
    ):
        params = {
            "entry_hour": instrument.open_hour + entry_offset,
            "impulse_atr": impulse_atr,
            "stop_atr": stop_atr,
            "target_r": target_r,
            "continuation": continuation,
        }
        family = "opening_impulse_continuation" if continuation else "opening_impulse_fade"
        yield family, params, opening_impulse(frame, instrument, **params)

    for range_bars, buffer_atr, target_r, max_range_atr in itertools.product(
        (1, 2), (0.05,), (1.0, 1.5), (1.75,)
    ):
        params = {
            "range_bars": range_bars,
            "buffer_atr": buffer_atr,
            "target_r": target_r,
            "max_range_atr": max_range_atr,
        }
        yield "opening_range_breakout", params, opening_range_breakout(frame, instrument, **params)

    for gap_atr, stop_atr, target_r, continuation in itertools.product(
        (0.5, 1.0), (1.0,), (1.0, 1.5), (False, True)
    ):
        params = {
            "gap_atr": gap_atr,
            "stop_atr": stop_atr,
            "target_r": target_r,
            "continuation": continuation,
        }
        family = "session_gap_continuation" if continuation else "session_gap_fade"
        yield family, params, session_gap(frame, instrument, **params)

    for weekday, move_atr, target_r, continuation in itertools.product(
        (None, 1, 4), (0.25, 0.75), (1.0, 1.5), (False, True)
    ):
        params = {
            "move_atr": move_atr,
            "stop_atr": 1.0,
            "target_r": target_r,
            "continuation": continuation,
            "weekday": weekday,
        }
        family = "previous_session_continuation" if continuation else "previous_session_fade"
        yield family, params, previous_session_move(frame, instrument, **params)

    for range_atr, target_r, continuation in itertools.product(
        (0.75, 1.25), (1.0, 1.5), (False, True)
    ):
        params = {
            "range_atr": range_atr,
            "location_tail": 0.20,
            "stop_atr": 1.0,
            "target_r": target_r,
            "continuation": continuation,
        }
        family = "prior_close_continuation" if continuation else "prior_close_fade"
        yield family, params, prior_close_location(frame, instrument, **params)

    for target_r, max_range_atr in itertools.product((1.0, 1.5), (1.5, 2.5)):
        params = {
            "buffer_atr": 0.05,
            "target_r": target_r,
            "max_range_atr": max_range_atr,
        }
        yield "inside_day_breakout", params, inside_day_breakout(frame, instrument, **params)


def screen(instruments: Sequence[Instrument]) -> dict[str, Any]:
    preholdout: list[dict[str, Any]] = []
    evaluated = 0
    for instrument in instruments:
        frame = load_bars(instrument)
        for family, params, trades in generate_candidates(frame, instrument):
            evaluated += 1
            metrics = split_metrics(trades)
            if not preholdout_pass(metrics):
                continue
            preholdout.append(
                {
                    "symbol": instrument.symbol,
                    "family": family,
                    "parameters": params,
                    "preholdout_score": round(candidate_score(metrics), 6),
                    "metrics": metrics,
                    "trades": trades,
                }
            )

    # One locked winner per family enters holdout; variants of the same family
    # do not get repeated looks at 2024-2025.
    selected: list[dict[str, Any]] = []
    for family in sorted({row["family"] for row in preholdout}):
        family_rows = [row for row in preholdout if row["family"] == family]
        winner = max(family_rows, key=lambda row: row["preholdout_score"])
        winner["holdout_verdict"] = "PASS" if holdout_pass(winner["metrics"]) else "FAIL"
        winner["trades"] = [asdict(trade) for trade in winner["trades"]]
        selected.append(winner)

    return {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "selection_contract": {
            "development": "2018-2022",
            "validation": "2023",
            "holdout": "2024-2025",
            "preholdout_gate": "DEV trades>=100 PF>=1.15; VAL trades>=15 PF>=1.05 net>0; >=3 positive DEV years",
            "holdout_gate": "trades>=30 PF>=1.10 net>0 and both 2024/2025 positive",
            "collision_rule": "stop_first_if_stop_and_target_touch_same_H1_bar",
            "dual_pending_touch_rule": "count_as_pessimistic_stop",
            "daily_position_limit": 1,
            "overnight_positions": 0,
        },
        "evaluated_configurations": evaluated,
        "preholdout_pass_count": len(preholdout),
        "selected_family_winners": selected,
        "holdout_pass_count": sum(row["holdout_verdict"] == "PASS" for row in selected),
    }


def default_instruments(root: Path) -> list[Instrument]:
    return [
        Instrument("NDX.DWX", root / "NDX.DWX_H1.csv", "America/New_York", 9, 15, (10, 11, 13, 14), 4.0),
        Instrument("SP500.DWX", root / "SP500.DWX_H1.csv", "America/New_York", 9, 15, (10, 11, 13, 14), 1.0),
        Instrument("GDAXI.DWX", root / "GDAXI.DWX_H1.csv", "Europe/Berlin", 8, 17, (9, 10, 13, 14), 3.0),
        Instrument("XAUUSD.DWX", root / "XAUUSD.DWX_H1.csv", "America/New_York", 8, 16, (9, 10, 13, 14), 0.8),
    ]


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Causal FTMO intraday strategy-family screen")
    parser.add_argument(
        "--data-root",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"),
    )
    parser.add_argument("--symbol", action="append", help="Limit the screen to one or more exact .DWX symbols")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    instruments = default_instruments(args.data_root)
    if args.symbol:
        requested = set(args.symbol)
        instruments = [instrument for instrument in instruments if instrument.symbol in requested]
        missing = requested - {instrument.symbol for instrument in instruments}
        if missing:
            parser.error(f"unknown symbols: {', '.join(sorted(missing))}")
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
