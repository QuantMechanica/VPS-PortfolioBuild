"""Reconstruct a synchronized FTMO book from report trades and .DWX OHLC bars.

This is a decision-support bridge between lifetime-trade MAE and a future
tick-capture model. Every sleeve must first reconcile its Q08 stream to the
native MT5 report. Trades are then marked to a common M15 grid using actual
co-moving bars, current FTMO costs, entry/exit commission timing, and accrued
swap. Within each M15 interval, long positions use the bar low and shorts use
the bar high simultaneously. A bar estimate is capped at the trade's measured
Q08 lifetime MAE so a partial entry/exit bar cannot create an impossible loss.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence
from zoneinfo import ZoneInfo

import numpy as np
import pandas as pd

try:
    from .ftmo_intraday_candidate_screen import broker_wall_seconds_to_utc
    from .ftmo_phase1_mae import START, TARGET, bootstrap, evaluate_window, parse_number_list
    from .ftmo_report_cost_reconcile import (
        RoundTrip,
        extract_round_trips,
        ftmo_trade_net,
    )
    from .ftmo_stream_reconciliation import reconcile_case
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_intraday_candidate_screen import broker_wall_seconds_to_utc  # type: ignore
    from ftmo_phase1_mae import START, TARGET, bootstrap, evaluate_window, parse_number_list  # type: ignore
    from ftmo_report_cost_reconcile import RoundTrip, extract_round_trips, ftmo_trade_net  # type: ignore
    from ftmo_stream_reconciliation import reconcile_case  # type: ignore


PRAGUE = ZoneInfo("Europe/Prague")
GRID_FREQUENCY = "15min"
GRID_MINUTES = 15
EPSILON = 1e-9
TIMESTAMP_BASIS_UNIX_UTC = "unix_utc"
TIMESTAMP_BASIS_DARWINEX_WALL = "darwinex_broker_wall"
VALID_TIMESTAMP_BASES = {TIMESTAMP_BASIS_UNIX_UTC, TIMESTAMP_BASIS_DARWINEX_WALL}


@dataclass(frozen=True)
class SleeveComponents:
    key: str
    ea_id: int
    symbol: str
    base_risk_fixed: float
    trades: int
    pre_low_balance_events: np.ndarray
    post_low_balance_events: np.ndarray
    adverse_floating: np.ndarray
    close_floating: np.ndarray
    opened_positions: np.ndarray
    ftmo_net: float
    ftmo_commission: float
    ftmo_swap: float
    point_value_fallbacks: int
    excluded_trades: int
    q08_mae_capped_trades: int = 0
    q08_mae_capped_bars: int = 0
    entry_price_outside_bar: int = 0
    exit_price_outside_bar: int = 0
    max_q08_cap_adjustment: float = 0.0


def sleeve_key(ea_id: int, symbol: str) -> str:
    return f"{int(ea_id)}:{str(symbol).upper()}"


def default_bar_paths(root: Path) -> dict[str, Path]:
    return {
        "GDAXI.DWX": root / "GDAXI.DWX_M15.csv",
        "SP500.DWX": root / "SP500.DWX_M15.csv",
        "XTIUSD.DWX": root / "XTIUSD.DWX_M15.csv",
        "NDX.DWX": root / "NDX.DWX_M15.csv",
        "WS30.DWX": root / "WS30.DWX_M15.csv",
        "EURUSD.DWX": root / "EURUSD.DWX_M5.csv",
        "EURGBP.DWX": root / "EURGBP.DWX_H1.csv",
        "AUDJPY.DWX": root / "AUDJPY.DWX_H1.csv",
        "USDCAD.DWX": root / "USDCAD.DWX_H1.csv",
        "USDJPY.DWX": root / "USDJPY.DWX_M5.csv",
        "GBPUSD.DWX": root / "GBPUSD.DWX_M5.csv",
        "XAUUSD.DWX": root / "XAUUSD.DWX_M15.csv",
        "XAGUSD.DWX": root / "XAGUSD.DWX_M15.csv",
    }


def _finite_number(mapping: Mapping[str, Any], key: str, default: float | None = None) -> float:
    try:
        value = float(mapping.get(key, default))
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{key} must be numeric") from exc
    if not math.isfinite(value):
        raise ValueError(f"{key} must be finite")
    return value


def _positive_number(mapping: Mapping[str, Any], key: str, default: float | None = None) -> float:
    value = _finite_number(mapping, key, default)
    if value <= 0.0:
        raise ValueError(f"{key} must be positive")
    return value


def normalize_timestamp(value: dt.datetime | pd.Timestamp, timestamp_basis: str) -> pd.Timestamp:
    """Return a real UTC timestamp from an explicitly declared source basis."""

    if timestamp_basis not in VALID_TIMESTAMP_BASES:
        raise ValueError(f"unsupported timestamp_basis: {timestamp_basis}")
    timestamp = pd.Timestamp(value)
    if timestamp.tzinfo is None:
        timestamp = timestamp.tz_localize("UTC")
    else:
        timestamp = timestamp.tz_convert("UTC")
    if timestamp_basis == TIMESTAMP_BASIS_UNIX_UTC:
        return timestamp
    seconds = pd.Series([int(timestamp.timestamp())], dtype="int64")
    return pd.Timestamp(broker_wall_seconds_to_utc(seconds).iloc[0])


def normalize_schedule(
    schedule: Sequence[tuple[pd.Timestamp, int]],
    timestamp_basis: str,
) -> list[tuple[pd.Timestamp, int]]:
    return [(normalize_timestamp(timestamp, timestamp_basis), units) for timestamp, units in schedule]


def load_resampled_bars(
    path: Path,
    *,
    timestamp_basis: str = TIMESTAMP_BASIS_UNIX_UTC,
) -> pd.DataFrame:
    frame = pd.read_csv(path, usecols=["time", "open", "high", "low", "close"])
    if frame.empty:
        raise ValueError(f"{path}: bar file is empty")
    if timestamp_basis == TIMESTAMP_BASIS_DARWINEX_WALL:
        frame["ts_utc"] = broker_wall_seconds_to_utc(frame["time"])
    elif timestamp_basis == TIMESTAMP_BASIS_UNIX_UTC:
        frame["ts_utc"] = pd.to_datetime(frame["time"], unit="s", utc=True)
    else:
        raise ValueError(f"unsupported timestamp_basis: {timestamp_basis}")
    frame = frame.drop(columns=["time"]).set_index("ts_utc").sort_index()
    if not frame.index.is_unique:
        raise ValueError(f"{path}: duplicate bar timestamps")
    bars = frame.resample(GRID_FREQUENCY, origin="epoch").agg(
        {"open": "first", "high": "max", "low": "min", "close": "last"}
    )
    bars = bars.dropna(subset=["open", "high", "low", "close"])
    if bars.empty:
        raise ValueError(f"{path}: no M15 bars after resampling")
    return bars


def load_q08_trade_rows(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open(encoding="utf-8", errors="replace") as handle:
        for line_number, line in enumerate(handle, 1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(f"{path}:{line_number}: invalid JSON") from exc
            if str(row.get("event") or "TRADE_CLOSED") != "TRADE_CLOSED":
                continue
            for field in ("time", "entry_time", "mae_acct"):
                if field not in row:
                    raise ValueError(f"{path}:{line_number}: missing {field}")
            mae = float(row["mae_acct"])
            if not math.isfinite(mae) or mae > EPSILON:
                raise ValueError(f"{path}:{line_number}: invalid mae_acct {mae}")
            rows.append(dict(row))
    if not rows:
        raise ValueError(f"{path}: no Q08 trade rows")
    return rows


def _report_path(case: Mapping[str, Any]) -> tuple[Path, dict[str, Any]]:
    ea_id = int(case["ea_id"])
    symbol = str(case["symbol"]).upper()
    reconciliation = reconcile_case(
        ea_id,
        symbol,
        Path(str(case["summary_path"])),
        stream_path=Path(str(case["stream_path"])),
    )
    if reconciliation["status"] != "PASS":
        raise ValueError(
            f"{sleeve_key(ea_id, symbol)} reconciliation failed: "
            + ",".join(reconciliation["reasons"])
        )
    return Path(str(reconciliation["report"]["report_canonical_path"])), reconciliation


def load_cases(
    manifest: Mapping[str, Any],
    *,
    bar_paths: Mapping[str, Path],
) -> tuple[list[dict[str, Any]], dict[str, pd.DataFrame]]:
    raw_cases = manifest.get("sleeves")
    if not isinstance(raw_cases, list) or not raw_cases:
        raise ValueError("manifest sleeves must be a non-empty list")
    timestamp_basis = str(manifest.get("timestamp_basis") or TIMESTAMP_BASIS_UNIX_UTC)
    if timestamp_basis not in VALID_TIMESTAMP_BASES:
        raise ValueError(f"unsupported timestamp_basis: {timestamp_basis}")
    loaded_cases: list[dict[str, Any]] = []
    bars: dict[str, pd.DataFrame] = {}
    for raw in raw_cases:
        if not isinstance(raw, Mapping):
            raise ValueError("every sleeve must be an object")
        case = dict(raw)
        symbol = str(case["symbol"]).upper()
        basket_symbols = [
            str(value).upper() for value in case.get("basket_symbols") or []
        ]
        report_path, reconciliation = _report_path(case)
        trades, report_stats = extract_round_trips(
            report_path,
            None if basket_symbols else symbol,
        )
        stream_path = Path(str(case["stream_path"]))
        q08_rows = load_q08_trade_rows(stream_path)
        if len(q08_rows) != len(trades):
            raise ValueError(
                f"{sleeve_key(int(case['ea_id']), symbol)} Q08/report trade count mismatch: "
                f"{len(q08_rows)}!={len(trades)}"
            )
        for trade_number, (trade, row) in enumerate(zip(trades, q08_rows), 1):
            if (
                int(trade.entry_time.timestamp()) != int(row["entry_time"])
                or int(trade.exit_time.timestamp()) != int(row["time"])
            ):
                raise ValueError(
                    f"{sleeve_key(int(case['ea_id']), symbol)} trade {trade_number}: "
                    "Q08/report timestamp mismatch"
                )
            row_symbol = str(row.get("symbol") or trade.symbol).upper()
            if row_symbol != trade.symbol.upper():
                raise ValueError(
                    f"{sleeve_key(int(case['ea_id']), symbol)} trade {trade_number}: "
                    f"Q08/report symbol mismatch {row_symbol}!={trade.symbol.upper()}"
                )

        if basket_symbols:
            observed_symbols = {trade.symbol.upper() for trade in trades}
            if observed_symbols != set(basket_symbols):
                raise ValueError(
                    f"{sleeve_key(int(case['ea_id']), symbol)} basket mismatch: "
                    f"observed={sorted(observed_symbols)} expected={sorted(basket_symbols)}"
                )
            cost_by_symbol = case.get("cost_by_symbol")
            if not isinstance(cost_by_symbol, Mapping):
                raise ValueError(f"{sleeve_key(int(case['ea_id']), symbol)} cost_by_symbol missing")
            bar_path_by_symbol = case.get("bar_path_by_symbol") or {}
            nominal_fractions = case.get("nominal_risk_fraction_by_symbol") or {}
            default_fraction = 1.0 / len(basket_symbols)
            resolved_fractions = {
                leg_symbol: float(nominal_fractions.get(leg_symbol, default_fraction))
                for leg_symbol in basket_symbols
            }
            if not math.isclose(
                sum(resolved_fractions.values()),
                1.0,
                rel_tol=0.0,
                abs_tol=1e-9,
            ):
                raise ValueError(
                    f"{sleeve_key(int(case['ea_id']), symbol)} nominal risk fractions "
                    f"must sum to one"
                )
            for leg_symbol in basket_symbols:
                indices = [
                    index
                    for index, trade in enumerate(trades)
                    if trade.symbol.upper() == leg_symbol
                ]
                if leg_symbol not in cost_by_symbol:
                    raise ValueError(f"{leg_symbol}: basket cost specification missing")
                path_value = bar_path_by_symbol.get(leg_symbol) or bar_paths.get(leg_symbol)
                if not path_value:
                    raise ValueError(f"{leg_symbol}: no bar path configured")
                path = Path(str(path_value))
                if not path.exists():
                    raise ValueError(f"{leg_symbol}: bar file missing: {path}")
                if leg_symbol not in bars:
                    bars[leg_symbol] = load_resampled_bars(
                        path,
                        timestamp_basis=timestamp_basis,
                    )
                fraction = resolved_fractions[leg_symbol]
                if not math.isfinite(fraction) or fraction <= 0.0:
                    raise ValueError(f"{leg_symbol}: invalid nominal risk fraction {fraction}")
                loaded_cases.append(
                    {
                        **case,
                        "symbol": leg_symbol,
                        "cost": dict(cost_by_symbol[leg_symbol]),
                        "weight_key": sleeve_key(int(case["ea_id"]), symbol),
                        "nominal_risk_per_trade": (
                            float(case.get("base_risk_fixed") or 1000.0) * fraction
                        ),
                        "timestamp_basis": timestamp_basis,
                        "report_path": report_path,
                        "reconciliation": reconciliation,
                        "report_stats": report_stats,
                        "trades": [trades[index] for index in indices],
                        "q08_rows": [q08_rows[index] for index in indices],
                        "bar_path": path,
                    }
                )
            continue

        if symbol not in bar_paths and not case.get("bar_path"):
            raise ValueError(f"{symbol}: no bar path configured")
        path = Path(str(case.get("bar_path") or bar_paths[symbol]))
        if not path.exists():
            raise ValueError(f"{symbol}: bar file missing: {path}")
        if symbol not in bars:
            bars[symbol] = load_resampled_bars(path, timestamp_basis=timestamp_basis)
        loaded_cases.append(
            {
                **case,
                "timestamp_basis": timestamp_basis,
                "report_path": report_path,
                "reconciliation": reconciliation,
                "report_stats": report_stats,
                "trades": trades,
                "q08_rows": q08_rows,
                "bar_path": path,
            }
        )
    return loaded_cases, bars


def common_grid(cases: Sequence[Mapping[str, Any]]) -> pd.DatetimeIndex:
    entries = [
        normalize_timestamp(trade.entry_time, str(case.get("timestamp_basis") or TIMESTAMP_BASIS_UNIX_UTC))
        for case in cases
        for trade in case["trades"]
    ]
    exits = [
        normalize_timestamp(trade.exit_time, str(case.get("timestamp_basis") or TIMESTAMP_BASIS_UNIX_UTC))
        for case in cases
        for trade in case["trades"]
    ]
    if not entries or not exits:
        raise ValueError("no trades available for common grid")
    start = min(entries).floor(GRID_FREQUENCY)
    end = max(exits).floor(GRID_FREQUENCY)
    return pd.date_range(start, end, freq=GRID_FREQUENCY, tz="UTC")


def align_bars_to_grid(
    bars: pd.DataFrame,
    grid: pd.DatetimeIndex,
) -> tuple[pd.DataFrame, set[pd.Timestamp]]:
    observed = set(bars.index)
    aligned = bars.reindex(grid)
    prior_close = aligned["close"].ffill()
    missing = aligned["close"].isna()
    for column in ("open", "high", "low", "close"):
        aligned.loc[missing, column] = prior_close.loc[missing]
    return aligned, observed


def trade_point_value(
    trade: RoundTrip,
    *,
    source_contract_size: float,
    fallback_account_rate: float,
) -> tuple[float, bool]:
    side = 1.0 if trade.side == "buy" else -1.0
    directional_move = side * (trade.exit_price - trade.entry_price)
    if abs(directional_move) > EPSILON:
        inferred = trade.profit / directional_move
        if math.isfinite(inferred) and inferred > 0.0:
            return inferred, False
    fallback = trade.volume * source_contract_size * fallback_account_rate
    if not math.isfinite(fallback) or fallback <= 0.0:
        raise ValueError("cannot infer a positive point value")
    return fallback, True


def rollover_schedule(
    entry_time: dt.datetime,
    exit_time: dt.datetime,
    *,
    triple_weekday: int,
) -> list[tuple[pd.Timestamp, int]]:
    if exit_time < entry_time:
        raise ValueError("exit precedes entry")
    cursor = dt.datetime.combine(
        entry_time.date() + dt.timedelta(days=1),
        dt.time.min,
        tzinfo=entry_time.tzinfo,
    )
    output: list[tuple[pd.Timestamp, int]] = []
    while cursor <= exit_time:
        session_day = cursor.date() - dt.timedelta(days=1)
        if session_day.weekday() < 5:
            units = 3 if session_day.weekday() == triple_weekday else 1
            output.append((pd.Timestamp(cursor).tz_convert("UTC"), units))
        cursor += dt.timedelta(days=1)
    return output


def cumulative_swap_for_slice(
    timestamps: pd.DatetimeIndex,
    schedule: Sequence[tuple[pd.Timestamp, int]],
    *,
    total_swap: float,
) -> np.ndarray:
    if not schedule or abs(total_swap) <= EPSILON:
        return np.zeros(len(timestamps), dtype=float)
    total_units = sum(units for _, units in schedule)
    if total_units <= 0:
        return np.zeros(len(timestamps), dtype=float)
    per_unit = total_swap / total_units
    values = np.zeros(len(timestamps), dtype=float)
    for rollover, units in schedule:
        start = int(timestamps.searchsorted(rollover, side="left"))
        if start < len(values):
            values[start:] += per_unit * units
    return values


def build_sleeve_components(
    case: Mapping[str, Any],
    *,
    grid: pd.DatetimeIndex,
    aligned_bars: pd.DataFrame,
    observed_bar_timestamps: set[pd.Timestamp],
    excluded_years: set[int] | None = None,
) -> SleeveComponents:
    ea_id = int(case["ea_id"])
    symbol = str(case["symbol"]).upper()
    cost = case.get("cost")
    if not isinstance(cost, Mapping):
        raise ValueError(f"{sleeve_key(ea_id, symbol)}: cost specification missing")
    commission_rate = _finite_number(cost, "commission_percent_per_side", 0.0) / 100.0
    flat_commission = _finite_number(cost, "flat_round_trip_commission_per_lot", 0.0)
    swap_long = _finite_number(cost, "swap_long_points")
    swap_short = _finite_number(cost, "swap_short_points", swap_long)
    contract_size = _positive_number(cost, "contract_size")
    source_size = _positive_number(cost, "source_contract_size", contract_size)
    account_rate = _positive_number(cost, "profit_currency_to_account_rate", 1.0)
    digits = int(cost["digits"])
    derive_rate = bool(cost.get("derive_profit_currency_rate_from_pnl", False))
    triple_weekday = int(cost.get("triple_weekday", 2))
    timestamp_basis = str(case.get("timestamp_basis") or TIMESTAMP_BASIS_UNIX_UTC)

    size = len(grid)
    pre = np.zeros(size, dtype=float)
    post = np.zeros(size, dtype=float)
    adverse = np.zeros(size, dtype=float)
    close_open = np.zeros(size, dtype=float)
    opens = np.zeros(size, dtype=np.int32)
    ftmo_net_total = 0.0
    commission_total = 0.0
    swap_total = 0.0
    fallbacks = 0
    excluded_trades = 0
    capped_trades = 0
    capped_bars = 0
    entry_price_outside = 0
    exit_price_outside = 0
    max_cap_adjustment = 0.0
    trades: Sequence[RoundTrip] = case["trades"]
    q08_rows: Sequence[Mapping[str, Any]] = case["q08_rows"]

    for trade_number, (trade, q08_row) in enumerate(zip(trades, q08_rows), 1):
        normalized_entry = normalize_timestamp(trade.entry_time, timestamp_basis)
        normalized_exit = normalize_timestamp(trade.exit_time, timestamp_basis)
        span_years = set(range(normalized_entry.year, normalized_exit.year + 1))
        if span_years & (excluded_years or set()):
            excluded_trades += 1
            continue
        entry_bucket = normalized_entry.floor(GRID_FREQUENCY)
        exit_bucket = normalized_exit.floor(GRID_FREQUENCY)
        if entry_bucket not in observed_bar_timestamps:
            raise ValueError(
                f"{sleeve_key(ea_id, symbol)} trade {trade_number}: entry bucket missing {entry_bucket}"
            )
        if exit_bucket not in observed_bar_timestamps:
            raise ValueError(
                f"{sleeve_key(ea_id, symbol)} trade {trade_number}: exit bucket missing {exit_bucket}"
            )
        start = int(grid.get_indexer([entry_bucket])[0])
        end = int(grid.get_indexer([exit_bucket])[0])
        if start < 0 or end < start:
            raise ValueError(f"{sleeve_key(ea_id, symbol)} trade {trade_number}: invalid grid span")

        net, commission, swap, _ = ftmo_trade_net(
            trade,
            commission_rate_per_side=commission_rate,
            flat_round_trip_commission_per_lot=flat_commission,
            swap_long_points=swap_long,
            swap_short_points=swap_short,
            contract_size=contract_size,
            source_contract_size=source_size,
            profit_currency_to_account_rate=account_rate,
            derive_profit_currency_rate_from_pnl=derive_rate,
            digits=digits,
            triple_weekday=triple_weekday,
        )
        point_value, used_fallback = trade_point_value(
            trade,
            source_contract_size=source_size,
            fallback_account_rate=account_rate,
        )
        fallbacks += int(used_fallback)
        entry_commission = commission / 2.0
        exit_commission = commission - entry_commission
        pre[start] -= entry_commission
        post[end] += trade.profit + swap - exit_commission
        opens[start] += 1

        timestamps = grid[start : end + 1]
        bars = aligned_bars.iloc[start : end + 1]
        if bars[["high", "low", "close"]].isna().any().any():
            raise ValueError(f"{sleeve_key(ea_id, symbol)} trade {trade_number}: unpriced bar span")
        side = 1.0 if trade.side == "buy" else -1.0
        entry_bar = bars.iloc[0]
        exit_bar = bars.iloc[-1]
        entry_price_outside += int(
            trade.entry_price < float(entry_bar["low"]) - EPSILON
            or trade.entry_price > float(entry_bar["high"]) + EPSILON
        )
        exit_price_outside += int(
            trade.exit_price < float(exit_bar["low"]) - EPSILON
            or trade.exit_price > float(exit_bar["high"]) + EPSILON
        )
        adverse_price = bars["low"].to_numpy() if side > 0 else bars["high"].to_numpy()
        price_adverse = side * (adverse_price - trade.entry_price) * point_value
        price_close = side * (bars["close"].to_numpy() - trade.entry_price) * point_value
        schedule = normalize_schedule(
            rollover_schedule(
                trade.entry_time,
                trade.exit_time,
                triple_weekday=triple_weekday,
            ),
            timestamp_basis,
        )
        cumulative_swap = cumulative_swap_for_slice(timestamps, schedule, total_swap=swap)
        native_cumulative_swap = cumulative_swap_for_slice(
            timestamps,
            schedule,
            total_swap=trade.native_swap,
        )
        q08_mae = min(0.0, float(q08_row["mae_acct"]))
        lifetime_floor = q08_mae + np.minimum(
            0.0,
            cumulative_swap - native_cumulative_swap,
        )
        raw_adverse = price_adverse + cumulative_swap
        cap_adjustment = np.maximum(0.0, lifetime_floor - raw_adverse)
        capped_samples = int(np.count_nonzero(cap_adjustment > 0.01))
        if capped_samples:
            capped_trades += 1
            capped_bars += capped_samples
            max_cap_adjustment = max(max_cap_adjustment, float(cap_adjustment.max()))
        adverse[start : end + 1] += np.maximum(raw_adverse, lifetime_floor)
        if end > start:
            close_open[start:end] += np.maximum(
                price_close[:-1] + cumulative_swap[:-1],
                lifetime_floor[:-1],
            )

        ftmo_net_total += net
        commission_total += commission
        swap_total += swap

    reconstructed_net = float(pre.sum() + post.sum())
    if abs(reconstructed_net - ftmo_net_total) > 0.05:
        raise ValueError(
            f"{sleeve_key(ea_id, symbol)} final net mismatch: "
            f"{reconstructed_net:.2f}!={ftmo_net_total:.2f}"
        )
    return SleeveComponents(
        key=sleeve_key(ea_id, symbol),
        ea_id=ea_id,
        symbol=symbol,
        base_risk_fixed=_positive_number(case, "base_risk_fixed", 1000.0),
        trades=len(trades) - excluded_trades,
        pre_low_balance_events=pre,
        post_low_balance_events=post,
        adverse_floating=adverse,
        close_floating=close_open,
        opened_positions=opens,
        ftmo_net=ftmo_net_total,
        ftmo_commission=commission_total,
        ftmo_swap=swap_total,
        point_value_fallbacks=fallbacks,
        excluded_trades=excluded_trades,
        q08_mae_capped_trades=capped_trades,
        q08_mae_capped_bars=capped_bars,
        entry_price_outside_bar=entry_price_outside,
        exit_price_outside_bar=exit_price_outside,
        max_q08_cap_adjustment=max_cap_adjustment,
    )


def components_to_daily(
    grid: pd.DatetimeIndex,
    components: Sequence[SleeveComponents],
    *,
    weights: Mapping[str, float],
    multiplier: float,
) -> tuple[list[dt.date], list[tuple[float, float, int]]]:
    if not math.isfinite(multiplier) or multiplier <= 0.0:
        raise ValueError("multiplier must be positive")
    size = len(grid)
    pre = np.zeros(size, dtype=float)
    post = np.zeros(size, dtype=float)
    adverse = np.zeros(size, dtype=float)
    close_open = np.zeros(size, dtype=float)
    opens = np.zeros(size, dtype=np.int32)
    for sleeve in components:
        weight = float(weights.get(sleeve.key, 0.0))
        if not math.isfinite(weight) or weight < 0.0:
            raise ValueError(f"invalid weight for {sleeve.key}")
        if weight == 0.0:
            continue
        scale = weight * multiplier
        pre += sleeve.pre_low_balance_events * scale
        post += sleeve.post_low_balance_events * scale
        adverse += sleeve.adverse_floating * scale
        close_open += sleeve.close_floating * scale
        opens += sleeve.opened_positions

    if size == 0:
        return [], []

    events = pre + post
    balance_before = np.zeros(size, dtype=float)
    if size > 1:
        balance_before[1:] = np.cumsum(events[:-1])
    balance_after_pre = balance_before + pre
    balance_after_post = balance_after_pre + post
    equity_low = np.minimum.reduce(
        (
            balance_after_pre,
            balance_after_pre + adverse,
            balance_after_post,
            balance_after_post + close_open,
        )
    )

    local_days = np.asarray(grid.tz_convert(PRAGUE).date, dtype=object)
    starts = np.concatenate(
        (
            np.asarray([0], dtype=np.int64),
            np.flatnonzero(local_days[1:] != local_days[:-1]) + 1,
        )
    )
    days = [value for value in local_days[starts]]
    realized = np.add.reduceat(events, starts)
    lows = np.minimum.reduceat(equity_low, starts) - balance_before[starts]
    day_opens = np.add.reduceat(opens, starts)
    pairs = [
        (float(day_realized), float(day_low), int(open_count))
        for day_realized, day_low, open_count in zip(realized, lows, day_opens)
    ]
    return days, pairs


def count_windows(pairs: Sequence[tuple[float, float, int]], horizon: int) -> collections.Counter[str]:
    counts: collections.Counter[str] = collections.Counter()
    if len(pairs) < horizon:
        return counts
    for start in range(len(pairs) - horizon + 1):
        counts[evaluate_window(pairs[start : start + horizon], target=TARGET)] += 1
    return counts


def evaluate_target_only_window(
    seq: Sequence[tuple[float, float, int]],
    *,
    target: float = TARGET,
) -> str:
    """Optimistic ceiling that ignores both FTMO loss objectives."""
    balance = START
    trading_days = 0
    for realized, _day_low, opens in seq:
        if opens > 0:
            trading_days += 1
        balance += realized
        if balance + EPSILON >= target and trading_days >= 4:
            return "passed"
    return "not_reached"


def count_target_only_windows(
    pairs: Sequence[tuple[float, float, int]],
    horizon: int,
) -> collections.Counter[str]:
    counts: collections.Counter[str] = collections.Counter()
    if len(pairs) < horizon:
        return counts
    for start in range(len(pairs) - horizon + 1):
        counts[evaluate_target_only_window(pairs[start : start + horizon])] += 1
    return counts


def split_valid_segments(
    days: Sequence[dt.date],
    pairs: Sequence[tuple[float, float, int]],
    *,
    excluded_years: set[int],
) -> list[list[tuple[float, float, int]]]:
    if len(days) != len(pairs):
        raise ValueError("days and pairs length mismatch")
    segments: list[list[tuple[float, float, int]]] = []
    current: list[tuple[float, float, int]] = []
    previous: dt.date | None = None
    for day, pair in zip(days, pairs):
        if day.year in excluded_years:
            if current:
                segments.append(current)
                current = []
            previous = None
            continue
        if previous is not None and day != previous + dt.timedelta(days=1):
            if current:
                segments.append(current)
            current = []
        current.append(pair)
        previous = day
    if current:
        segments.append(current)
    return segments


def count_segment_windows(
    segments: Sequence[Sequence[tuple[float, float, int]]],
    horizon: int,
) -> collections.Counter[str]:
    counts: collections.Counter[str] = collections.Counter()
    for segment in segments:
        counts.update(count_windows(segment, horizon))
    return counts


def bootstrap_segments(
    segments: Sequence[Sequence[tuple[float, float, int]]],
    *,
    horizon: int,
    block: int,
    runs: int,
    seed: int,
) -> collections.Counter[str]:
    eligible = [list(segment) for segment in segments if len(segment) >= block]
    if not eligible:
        raise ValueError("no valid segment is long enough for the bootstrap block")
    weights = [len(segment) for segment in eligible]
    rng = random.Random(seed)
    counts: collections.Counter[str] = collections.Counter()
    for _ in range(runs):
        sequence: list[tuple[float, float, int]] = []
        while len(sequence) < horizon:
            segment = rng.choices(eligible, weights=weights, k=1)[0]
            start = rng.randrange(0, len(segment) - block + 1)
            sequence.extend(segment[start : start + block])
        counts[evaluate_window(sequence[:horizon], target=TARGET)] += 1
    return counts


def bootstrap_target_only_segments(
    segments: Sequence[Sequence[tuple[float, float, int]]],
    *,
    horizon: int,
    block: int,
    runs: int,
    seed: int,
) -> collections.Counter[str]:
    eligible = [list(segment) for segment in segments if len(segment) >= block]
    if not eligible:
        raise ValueError("no valid segment is long enough for the bootstrap block")
    weights = [len(segment) for segment in eligible]
    rng = random.Random(seed)
    counts: collections.Counter[str] = collections.Counter()
    for _ in range(runs):
        sequence: list[tuple[float, float, int]] = []
        while len(sequence) < horizon:
            segment = rng.choices(eligible, weights=weights, k=1)[0]
            start = rng.randrange(0, len(segment) - block + 1)
            sequence.extend(segment[start : start + block])
        counts[evaluate_target_only_window(sequence[:horizon])] += 1
    return counts


def _wilson_interval(successes: int, total: int) -> tuple[float, float]:
    if total <= 0:
        return 0.0, 0.0
    z = 1.959963984540054
    p = successes / total
    denominator = 1.0 + z * z / total
    center = (p + z * z / (2.0 * total)) / denominator
    margin = z * math.sqrt((p * (1.0 - p) + z * z / (4.0 * total)) / total) / denominator
    return max(0.0, center - margin) * 100.0, min(1.0, center + margin) * 100.0


def rates(counts: Mapping[str, int]) -> dict[str, Any]:
    total = sum(counts.values())
    passed = int(counts.get("passed", 0))
    low, high = _wilson_interval(passed, total)
    if total == 0:
        return {
            "runs": 0,
            "pass_pct": 0.0,
            "pass_ci95_pct": [0.0, 0.0],
            "daily_breach_pct": 0.0,
            "max_breach_pct": 0.0,
            "not_reached_pct": 0.0,
        }
    return {
        "runs": total,
        "pass_pct": passed / total * 100.0,
        "pass_ci95_pct": [low, high],
        "daily_breach_pct": counts.get("daily_breach", 0) / total * 100.0,
        "max_breach_pct": counts.get("max_breach", 0) / total * 100.0,
        "not_reached_pct": counts.get("not_reached", 0) / total * 100.0,
    }


def evaluate_manifest(
    manifest: Mapping[str, Any],
    *,
    bar_paths: Mapping[str, Path],
    multipliers: Sequence[float],
    horizons: Sequence[int],
    seeds: Sequence[int],
    runs: int,
    block: int,
    excluded_years: set[int] | None = None,
) -> dict[str, Any]:
    cases, source_bars = load_cases(manifest, bar_paths=bar_paths)
    grid = common_grid(cases)
    components: list[SleeveComponents] = []
    for case in cases:
        symbol = str(case["symbol"]).upper()
        aligned, observed = align_bars_to_grid(source_bars[symbol], grid)
        components.append(
            build_sleeve_components(
                case,
                grid=grid,
                aligned_bars=aligned,
                observed_bar_timestamps=observed,
                excluded_years=excluded_years,
            )
        )
    known_keys = {sleeve.key for sleeve in components}
    raw_scenarios = manifest.get("scenarios")
    if not isinstance(raw_scenarios, list) or not raw_scenarios:
        raise ValueError("manifest scenarios must be a non-empty list")

    results: list[dict[str, Any]] = []
    for raw_scenario in raw_scenarios:
        if not isinstance(raw_scenario, Mapping):
            raise ValueError("scenario must be an object")
        name = str(raw_scenario.get("name") or "").strip()
        raw_weights = raw_scenario.get("weights")
        if not name or not isinstance(raw_weights, Mapping):
            raise ValueError("scenario needs name and weights")
        unknown = set(raw_weights) - known_keys
        if unknown:
            raise ValueError(f"scenario {name} has unknown sleeves: {sorted(unknown)}")
        weights = {key: float(raw_weights.get(key, 0.0)) for key in known_keys}
        if not any(weight > 0.0 for weight in weights.values()):
            raise ValueError(f"scenario {name} has no positive weights")
        for multiplier in multipliers:
            days, pairs = components_to_daily(
                grid,
                components,
                weights=weights,
                multiplier=multiplier,
            )
            segments = split_valid_segments(
                days,
                pairs,
                excluded_years=excluded_years or set(),
            )
            nominal_risk = sum(
                sleeve.base_risk_fixed * weights[sleeve.key] * multiplier
                for sleeve in components
            )
            for horizon in horizons:
                boot_counts: collections.Counter[str] = collections.Counter()
                target_only_boot_counts: collections.Counter[str] = collections.Counter()
                for seed in seeds:
                    boot_counts.update(
                        bootstrap_segments(
                            segments,
                            horizon=horizon,
                            block=block,
                            runs=runs,
                            seed=seed,
                        )
                    )
                    target_only_boot_counts.update(
                        bootstrap_target_only_segments(
                            segments,
                            horizon=horizon,
                            block=block,
                            runs=runs,
                            seed=seed,
                        )
                    )
                historical_counts = count_segment_windows(segments, horizon)
                target_only_historical_counts: collections.Counter[str] = collections.Counter()
                for segment in segments:
                    target_only_historical_counts.update(
                        count_target_only_windows(segment, horizon)
                    )
                valid_days = sum(len(segment) for segment in segments)
                results.append(
                    {
                        "scenario": name,
                        "weights": weights,
                        "multiplier": multiplier,
                        "nominal_risk_fixed": nominal_risk,
                        "nominal_risk_pct": nominal_risk / START * 100.0,
                        "horizon_calendar_days": horizon,
                        "data_start": days[0].isoformat(),
                        "data_end": days[-1].isoformat(),
                        "data_calendar_days": valid_days,
                        "data_segments": len(segments),
                        "bootstrap": rates(boot_counts),
                        "historical_rolling": rates(historical_counts),
                        "target_only_upper_bound": {
                            "bootstrap": rates(target_only_boot_counts),
                            "historical_rolling": rates(target_only_historical_counts),
                            "contract": "ignores_daily_and_maximum_loss_objectives",
                        },
                    }
                )

    return {
        "schema_version": 1,
        "basis": "report_reconciled_ftmo_costed_synchronized_m15_q08_capped_joint_ohlc_equity",
        "snapshot_date": manifest.get("snapshot_date"),
        "timestamp_basis": manifest.get("timestamp_basis", TIMESTAMP_BASIS_UNIX_UTC),
        "grid": {
            "frequency_minutes": GRID_MINUTES,
            "start_utc": grid[0].isoformat(),
            "end_utc": grid[-1].isoformat(),
            "samples": len(grid),
        },
        "excluded_calendar_years": sorted(excluded_years or set()),
        "rules": {
            "starting_balance": START,
            "phase1_target": TARGET,
            "daily_loss_amount": 5000.0,
            "maximum_loss_amount": 10000.0,
            "minimum_trading_days": 4,
            "timezone": "Europe/Prague",
        },
        "intrabar_contract": (
            "Within every M15 interval all long positions use their bar low and all shorts "
            "their bar high simultaneously. Per-trade floating loss is bounded by measured "
            "Q08 lifetime MAE, adjusted conservatively for worse current swap."
        ),
        "limitations": [
            "M15 bars cannot prove within-bar tick ordering or exact sub-bar co-movement.",
            "Missing no-tick intervals are forward-filled at the last close; observed trade entry and exit buckets are mandatory.",
            "Q08 lifetime MAE prevents impossible partial-bar loss but does not identify the exact tick when that MAE occurred.",
            "Current FTMO cost and swap snapshots are applied to the full historical sample.",
            "Block bootstrap preserves observed joint days but remains a research frequency estimate, not a pass guarantee.",
        ],
        "sleeves": [
            {
                "key": sleeve.key,
                "trades": sleeve.trades,
                "base_risk_fixed": sleeve.base_risk_fixed,
                "ftmo_net": round(sleeve.ftmo_net, 2),
                "ftmo_commission": round(sleeve.ftmo_commission, 2),
                "ftmo_swap": round(sleeve.ftmo_swap, 2),
                "point_value_fallbacks": sleeve.point_value_fallbacks,
                "excluded_trades": sleeve.excluded_trades,
                "q08_mae_capped_trades": sleeve.q08_mae_capped_trades,
                "q08_mae_capped_bars": sleeve.q08_mae_capped_bars,
                "entry_price_outside_bar": sleeve.entry_price_outside_bar,
                "exit_price_outside_bar": sleeve.exit_price_outside_bar,
                "max_q08_cap_adjustment": round(sleeve.max_q08_cap_adjustment, 2),
                "bar_path": str(next(case["bar_path"] for case in cases if int(case["ea_id"]) == sleeve.ea_id and str(case["symbol"]).upper() == sleeve.symbol)),
            }
            for sleeve in components
        ],
        "results": results,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument(
        "--data-root",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"),
    )
    parser.add_argument("--multipliers", default="1,2,3,4,5,6,7,8")
    parser.add_argument("--horizons", default="30")
    parser.add_argument("--seeds", default="3,7,11")
    parser.add_argument("--runs", type=int, default=5000)
    parser.add_argument("--block", type=int, default=5)
    parser.add_argument(
        "--exclude-years",
        default="",
        help="comma-separated calendar years removed from every sleeve and kept as segment gaps",
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    if args.runs <= 0 or args.block <= 0:
        parser.error("--runs and --block must be positive")
    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    try:
        excluded_years = {
            int(value.strip()) for value in args.exclude_years.split(",") if value.strip()
        }
    except ValueError as exc:
        parser.error(f"invalid --exclude-years: {exc}")
    artifact = evaluate_manifest(
        manifest,
        bar_paths=default_bar_paths(args.data_root),
        multipliers=parse_number_list(args.multipliers, float, "multipliers"),
        horizons=parse_number_list(args.horizons, int, "horizons"),
        seeds=parse_number_list(args.seeds, int, "seeds", allow_zero=True),
        runs=args.runs,
        block=args.block,
        excluded_years=excluded_years,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for row in artifact["results"]:
        result = row["bootstrap"]
        print(
            f"{row['scenario']} risk={row['nominal_risk_pct']:.2f}% "
            f"horizon={row['horizon_calendar_days']} pass={result['pass_pct']:.2f}% "
            f"daily={result['daily_breach_pct']:.2f}% max={result['max_breach_pct']:.2f}% "
            f"not_reached={result['not_reached_pct']:.2f}%"
        )
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
