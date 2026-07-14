"""Replay an FTMO portfolio with an entry-time, portfolio-wide M15 governor.

Unlike the daily governor upper bound, this simulator sizes each trade only at
its actual entry, closes active positions when the portfolio stop is crossed,
cancels their later report exits, and blocks new entries for the rest of that
Prague calendar day. Every rolling challenge window starts flat.

The default threshold-fill mode is still optimistic: it assumes the portfolio
can be liquidated exactly at the configured equity floor inside an M15 bar.
Use the result as a feasibility gate, not deployment evidence.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import math
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np
import pandas as pd

try:
    from .ftmo_bar_joint_book_sim import (
        EPSILON,
        GRID_FREQUENCY,
        PRAGUE,
        TIMESTAMP_BASIS_UNIX_UTC,
        _finite_number,
        _positive_number,
        align_bars_to_grid,
        common_grid,
        cumulative_swap_for_slice,
        default_bar_paths,
        load_cases,
        normalize_schedule,
        normalize_timestamp,
        rates,
        rollover_schedule,
        sleeve_key,
        trade_point_value,
    )
    from .ftmo_report_cost_reconcile import RoundTrip, ftmo_trade_net
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_bar_joint_book_sim import (  # type: ignore
        EPSILON,
        GRID_FREQUENCY,
        PRAGUE,
        TIMESTAMP_BASIS_UNIX_UTC,
        _finite_number,
        _positive_number,
        align_bars_to_grid,
        common_grid,
        cumulative_swap_for_slice,
        default_bar_paths,
        load_cases,
        normalize_schedule,
        normalize_timestamp,
        rates,
        rollover_schedule,
        sleeve_key,
        trade_point_value,
    )
    from ftmo_report_cost_reconcile import RoundTrip, ftmo_trade_net  # type: ignore


START_BALANCE = 100_000.0
TARGET_BALANCE = 110_000.0
MAX_LOSS_FLOOR = 90_000.0
OFFICIAL_DAILY_LOSS = 5_000.0


@dataclass(frozen=True)
class GovernedTradePath:
    trade_id: str
    key: str
    start_idx: int
    end_idx: int
    entry_commission: float
    exit_commission: float
    exit_balance_delta: float
    adverse_pnl: np.ndarray
    close_pnl: np.ndarray
    nominal_risk: float = 1000.0


@dataclass(frozen=True)
class ActiveTrade:
    path: GovernedTradePath
    scale: float


def entry_filter_accepts(
    case: Mapping[str, Any],
    trade: RoundTrip,
    normalized_entry: pd.Timestamp,
    feature_bars: pd.DataFrame | None,
) -> bool:
    """Apply a manifest-declared causal filter using only pre-entry data."""

    filter_name = str(case.get("entry_filter") or "").strip()
    if not filter_name:
        return True
    if filter_name == "long_only":
        return trade.side == "buy"
    if filter_name == "short_only":
        return trade.side == "sell"
    if filter_name == "exclude_weekdays":
        raw_weekdays = case.get("entry_filter_excluded_weekdays") or []
        if not isinstance(raw_weekdays, Sequence) or isinstance(raw_weekdays, (str, bytes)):
            raise ValueError("entry_filter_excluded_weekdays must be a list")
        excluded_weekdays = {int(value) for value in raw_weekdays}
        if any(value < 0 or value > 6 for value in excluded_weekdays):
            raise ValueError("entry_filter_excluded_weekdays values must be in 0..6")
        return normalized_entry.tz_convert(PRAGUE).weekday() not in excluded_weekdays
    if filter_name == "asia_only":
        return normalized_entry.tz_convert(PRAGUE).hour < 7
    if filter_name.startswith("shadow_pnl_last_"):
        return True
    trend_lookbacks = {
        "trend_24h_align": 97,
        "trend_24h_fade": 97,
        "trend_5d_align": 481,
        "trend_5d_fade": 481,
    }
    if filter_name in trend_lookbacks:
        if feature_bars is None:
            raise ValueError(f"{filter_name} requires observed feature bars")
        lookback = trend_lookbacks[filter_name]
        entry_bucket = normalized_entry.floor(GRID_FREQUENCY)
        position = int(feature_bars.index.searchsorted(entry_bucket, side="left"))
        if position < lookback:
            return False
        closes = feature_bars.iloc[position - lookback : position]["close"].to_numpy(
            dtype=float
        )
        if (
            len(closes) != lookback
            or not np.isfinite(closes).all()
            or closes[0] <= 0.0
        ):
            return False
        side = 1.0 if trade.side == "buy" else -1.0
        signed_return = side * (float(closes[-1]) / float(closes[0]) - 1.0)
        return signed_return > 0.0 if filter_name.endswith("_align") else signed_return < 0.0
    if filter_name in {"trend_consensus_align", "trend_consensus_fade"}:
        if feature_bars is None:
            raise ValueError(f"{filter_name} requires observed feature bars")
        entry_bucket = normalized_entry.floor(GRID_FREQUENCY)
        position = int(feature_bars.index.searchsorted(entry_bucket, side="left"))
        if position < 97:
            return False
        closes = feature_bars.iloc[position - 97 : position]["close"].to_numpy(dtype=float)
        if (
            len(closes) != 97
            or not np.isfinite(closes).all()
            or closes[-1] <= 0.0
            or closes[-17] <= 0.0
            or closes[-97] <= 0.0
        ):
            return False
        side = 1.0 if trade.side == "buy" else -1.0
        signed_return_4h = side * (float(closes[-1]) / float(closes[-17]) - 1.0)
        signed_return_24h = side * (float(closes[-1]) / float(closes[-97]) - 1.0)
        if filter_name == "trend_consensus_align":
            return signed_return_4h > 0.0 and signed_return_24h > 0.0
        return signed_return_4h < 0.0 and signed_return_24h < 0.0
    if filter_name in {"trend_20d_align", "trend_20d_fade"}:
        if feature_bars is None:
            raise ValueError("trend_20d_align requires observed feature bars")
        entry_bucket = normalized_entry.floor(GRID_FREQUENCY)
        position = int(feature_bars.index.searchsorted(entry_bucket, side="left"))
        if position < 1921:
            return False
        closes = feature_bars.iloc[position - 1921 : position]["close"].to_numpy(dtype=float)
        if len(closes) != 1921 or not np.isfinite(closes).all() or closes[0] <= 0.0:
            return False
        side = 1.0 if trade.side == "buy" else -1.0
        signed_return = side * (float(closes[-1]) / float(closes[0]) - 1.0)
        return signed_return > 0.0 if filter_name == "trend_20d_align" else signed_return < 0.0
    if filter_name != "volatility_active":
        raise ValueError(f"unsupported entry_filter: {filter_name}")
    if feature_bars is None:
        raise ValueError("volatility_active requires observed feature bars")
    entry_bucket = normalized_entry.floor(GRID_FREQUENCY)
    position = int(feature_bars.index.searchsorted(entry_bucket, side="left"))
    if position < 97:
        return False
    history = feature_bars.iloc[position - 97 : position]
    if len(history) != 97 or history[["high", "low"]].isna().any().any():
        return False
    ranges = (history["high"] - history["low"]).to_numpy(dtype=float)
    long_range = float(np.mean(ranges[-96:]))
    recent_range = float(np.mean(ranges[-16:]))
    if not math.isfinite(long_range) or long_range <= 0.0:
        return False
    return recent_range / long_range >= 1.0


@dataclass(frozen=True)
class WindowResult:
    outcome: str
    ending_balance: float
    minimum_equity: float
    trading_days: int
    accepted_entries: int
    blocked_entries: int
    stop_events: int


def _cost_spec(case: Mapping[str, Any]) -> dict[str, Any]:
    cost = case.get("cost")
    if not isinstance(cost, Mapping):
        raise ValueError(f"{case.get('ea_id')}:{case.get('symbol')}: cost specification missing")
    contract_size = _positive_number(cost, "contract_size")
    return {
        "commission_rate": _finite_number(cost, "commission_percent_per_side", 0.0) / 100.0,
        "flat_commission": _finite_number(cost, "flat_round_trip_commission_per_lot", 0.0),
        "swap_long": _finite_number(cost, "swap_long_points"),
        "swap_short": _finite_number(cost, "swap_short_points", cost.get("swap_long_points")),
        "contract_size": contract_size,
        "source_size": _positive_number(cost, "source_contract_size", contract_size),
        "account_rate": _positive_number(cost, "profit_currency_to_account_rate", 1.0),
        "derive_rate": bool(cost.get("derive_profit_currency_rate_from_pnl", False)),
        "digits": int(cost["digits"]),
        "triple_weekday": int(cost.get("triple_weekday", 2)),
    }


def shadow_entry_acceptance(case: Mapping[str, Any]) -> list[bool]:
    """Return causal same-year shadow-PnL decisions in original trade order."""

    trades: Sequence[RoundTrip] = case["trades"]
    filter_name = str(case.get("entry_filter") or "").strip()
    if not filter_name.startswith("shadow_pnl_last_"):
        return [True] * len(trades)
    match = re.fullmatch(r"shadow_pnl_last_(\d+)_pos_same_year", filter_name)
    if match is None:
        raise ValueError(f"unsupported shadow entry_filter: {filter_name}")
    lookback = int(match.group(1))
    if lookback <= 0:
        raise ValueError("shadow PnL lookback must be positive")

    cost = _cost_spec(case)
    timestamp_basis = str(case.get("timestamp_basis") or TIMESTAMP_BASIS_UNIX_UTC)
    rows: list[dict[str, Any]] = []
    for index, trade in enumerate(trades):
        entry = normalize_timestamp(trade.entry_time, timestamp_basis)
        exit_time = normalize_timestamp(trade.exit_time, timestamp_basis)
        net, _commission, _swap, _units = ftmo_trade_net(
            trade,
            commission_rate_per_side=cost["commission_rate"],
            flat_round_trip_commission_per_lot=cost["flat_commission"],
            swap_long_points=cost["swap_long"],
            swap_short_points=cost["swap_short"],
            contract_size=cost["contract_size"],
            source_contract_size=cost["source_size"],
            profit_currency_to_account_rate=cost["account_rate"],
            derive_profit_currency_rate_from_pnl=cost["derive_rate"],
            digits=cost["digits"],
            triple_weekday=cost["triple_weekday"],
        )
        rows.append(
            {
                "index": index,
                "entry": entry,
                "exit": exit_time,
                "entry_year": int(entry.tz_convert(PRAGUE).year),
                "exit_year": int(exit_time.tz_convert(PRAGUE).year),
                "net": float(net),
            }
        )

    completed = sorted(rows, key=lambda row: (row["exit"], row["index"]))
    entries = sorted(rows, key=lambda row: (row["entry"], row["index"]))
    accepted = [True] * len(rows)
    realized_by_year: collections.defaultdict[int, list[float]] = collections.defaultdict(list)
    exit_position = 0
    for row in entries:
        while exit_position < len(completed) and completed[exit_position]["exit"] < row["entry"]:
            prior = completed[exit_position]
            realized_by_year[int(prior["exit_year"])].append(float(prior["net"]))
            exit_position += 1
        history = realized_by_year[int(row["entry_year"])]
        if len(history) >= lookback:
            accepted[int(row["index"])] = sum(history[-lookback:]) > 0.0
    return accepted


def build_trade_paths(
    case: Mapping[str, Any],
    *,
    grid: pd.DatetimeIndex,
    aligned_bars: pd.DataFrame,
    observed_bar_timestamps: set[pd.Timestamp],
    feature_bars: pd.DataFrame | None = None,
    excluded_years: set[int] | None = None,
) -> list[GovernedTradePath]:
    ea_id = int(case["ea_id"])
    symbol = str(case["symbol"]).upper()
    key = str(case.get("weight_key") or sleeve_key(ea_id, symbol))
    cost = _cost_spec(case)
    report_pnl_scale = _positive_number(case, "report_pnl_scale", 1.0)
    timestamp_basis = str(case.get("timestamp_basis") or TIMESTAMP_BASIS_UNIX_UTC)
    trades: Sequence[RoundTrip] = case["trades"]
    q08_rows: Sequence[Mapping[str, Any]] = case["q08_rows"]
    shadow_acceptance = shadow_entry_acceptance(case)
    output: list[GovernedTradePath] = []

    for trade_number, (trade, q08_row) in enumerate(zip(trades, q08_rows), 1):
        normalized_entry = normalize_timestamp(trade.entry_time, timestamp_basis)
        normalized_exit = normalize_timestamp(trade.exit_time, timestamp_basis)
        if not shadow_acceptance[trade_number - 1]:
            continue
        if not entry_filter_accepts(case, trade, normalized_entry, feature_bars):
            continue
        span_years = set(range(normalized_entry.year, normalized_exit.year + 1))
        if span_years & (excluded_years or set()):
            continue
        entry_bucket = normalized_entry.floor(GRID_FREQUENCY)
        exit_bucket = normalized_exit.floor(GRID_FREQUENCY)
        if entry_bucket not in observed_bar_timestamps:
            raise ValueError(f"{key} trade {trade_number}: entry bucket missing {entry_bucket}")
        if exit_bucket not in observed_bar_timestamps:
            raise ValueError(f"{key} trade {trade_number}: exit bucket missing {exit_bucket}")
        start = int(grid.get_indexer([entry_bucket])[0])
        end = int(grid.get_indexer([exit_bucket])[0])
        if start < 0 or end < start:
            raise ValueError(f"{key} trade {trade_number}: invalid grid span")

        _net, commission, swap, _ = ftmo_trade_net(
            trade,
            commission_rate_per_side=cost["commission_rate"],
            flat_round_trip_commission_per_lot=cost["flat_commission"],
            swap_long_points=cost["swap_long"],
            swap_short_points=cost["swap_short"],
            contract_size=cost["contract_size"],
            source_contract_size=cost["source_size"],
            profit_currency_to_account_rate=cost["account_rate"],
            derive_profit_currency_rate_from_pnl=cost["derive_rate"],
            digits=cost["digits"],
            triple_weekday=cost["triple_weekday"],
        )
        point_value, _ = trade_point_value(
            trade,
            source_contract_size=cost["source_size"],
            fallback_account_rate=cost["account_rate"],
        )
        entry_commission = commission / 2.0
        exit_commission = commission - entry_commission
        timestamps = grid[start : end + 1]
        priced = aligned_bars.iloc[start : end + 1]
        if priced[["high", "low", "close"]].isna().any().any():
            raise ValueError(f"{key} trade {trade_number}: unpriced bar span")

        side = 1.0 if trade.side == "buy" else -1.0
        adverse_price = priced["low"].to_numpy() if side > 0 else priced["high"].to_numpy()
        raw_adverse = side * (adverse_price - trade.entry_price) * point_value
        raw_close = side * (priced["close"].to_numpy() - trade.entry_price) * point_value
        schedule = normalize_schedule(
            rollover_schedule(
                trade.entry_time,
                trade.exit_time,
                triple_weekday=cost["triple_weekday"],
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
        lifetime_floor = q08_mae + np.minimum(0.0, cumulative_swap - native_cumulative_swap)
        adverse = np.maximum(raw_adverse + cumulative_swap, lifetime_floor)
        close = np.maximum(raw_close + cumulative_swap, lifetime_floor)
        output.append(
            GovernedTradePath(
                trade_id=f"{key}:{symbol}:{trade_number}",
                key=key,
                start_idx=start,
                end_idx=end,
                entry_commission=entry_commission * report_pnl_scale,
                exit_commission=exit_commission * report_pnl_scale,
                exit_balance_delta=(trade.profit + swap - exit_commission) * report_pnl_scale,
                adverse_pnl=adverse * report_pnl_scale,
                close_pnl=close * report_pnl_scale,
                nominal_risk=float(
                    case.get("nominal_risk_per_trade")
                    or case.get("base_risk_fixed")
                    or 1000.0
                ),
            )
        )
    return output


def index_entries(paths: Sequence[GovernedTradePath]) -> dict[int, list[GovernedTradePath]]:
    output: collections.defaultdict[int, list[GovernedTradePath]] = collections.defaultdict(list)
    for path in paths:
        output[path.start_idx].append(path)
    return dict(output)


def entry_scale_factor(
    equity: float, effective_floor: float, full_risk_room: float
) -> float:
    if (
        not math.isfinite(equity)
        or not math.isfinite(effective_floor)
        or not math.isfinite(full_risk_room)
        or full_risk_room <= 0.0
    ):
        raise ValueError(
            "equity, effective_floor, and full_risk_room must be finite; "
            "full_risk_room must be positive"
        )
    room = max(0.0, equity - effective_floor)
    return min(1.0, room / full_risk_room)


def realized_volatility_scale(
    completed_daily_changes: Sequence[float],
    *,
    lookback_days: int,
    target_rms: float,
    minimum_scale: float,
    maximum_scale: float,
) -> float:
    """Return a causal scale from completed marked-equity day changes."""

    if lookback_days == 0 and target_rms == 0.0:
        return 1.0
    if lookback_days <= 0 or not math.isfinite(target_rms) or target_rms <= 0.0:
        raise ValueError("realized-vol lookback and target RMS must both be positive")
    if (
        not math.isfinite(minimum_scale)
        or not math.isfinite(maximum_scale)
        or minimum_scale <= 0.0
        or maximum_scale < minimum_scale
    ):
        raise ValueError("realized-vol scales must be positive and ordered")
    if len(completed_daily_changes) < lookback_days:
        return 1.0
    recent = [float(value) for value in completed_daily_changes[-lookback_days:]]
    if any(not math.isfinite(value) for value in recent):
        raise ValueError("completed daily equity changes must be finite")
    rms = math.sqrt(sum(value * value for value in recent) / lookback_days)
    if rms <= EPSILON:
        return maximum_scale
    return min(maximum_scale, max(minimum_scale, target_rms / rms))


def risk_multiplier_for_equity(
    equity: float,
    base_multiplier: float,
    profit_steps: Sequence[tuple[float, float]] = (),
) -> float:
    """Select a non-decreasing anti-martingale risk step from current equity."""

    if not math.isfinite(equity) or not math.isfinite(base_multiplier) or base_multiplier <= 0.0:
        raise ValueError("equity must be finite and base_multiplier must be positive")
    selected = base_multiplier
    previous_threshold = -1.0
    previous_multiplier = base_multiplier
    profit = equity - START_BALANCE
    for threshold, multiplier in profit_steps:
        if (
            not math.isfinite(threshold)
            or threshold < 0.0
            or threshold <= previous_threshold
            or not math.isfinite(multiplier)
            or multiplier < previous_multiplier
        ):
            raise ValueError(
                "profit risk steps require increasing non-negative thresholds "
                "and non-decreasing positive multipliers"
            )
        if profit + EPSILON >= threshold:
            selected = multiplier
        previous_threshold = threshold
        previous_multiplier = multiplier
    return selected


def risk_multiplier_for_elapsed_day(
    elapsed_days: int,
    base_multiplier: float,
    elapsed_steps: Sequence[tuple[int, float]] = (),
) -> float:
    """Select a causal risk step from calendar days elapsed since launch."""

    if elapsed_days < 0 or not math.isfinite(base_multiplier) or base_multiplier <= 0.0:
        raise ValueError("elapsed days must be non-negative and base multiplier positive")
    selected = base_multiplier
    previous_day = -1
    for day, multiplier in elapsed_steps:
        if (
            day < 0
            or day <= previous_day
            or not math.isfinite(multiplier)
            or multiplier <= 0.0
        ):
            raise ValueError(
                "elapsed risk steps require increasing non-negative days and positive multipliers"
            )
        if elapsed_days >= day:
            selected = multiplier
        previous_day = day
    return selected


def risk_multiplier_for_conditional_deadline(
    elapsed_days: int,
    equity: float,
    base_multiplier: float,
    conditional_steps: Sequence[tuple[int, float, float, float]] = (),
) -> float:
    """Accelerate only inside declared elapsed-day and current-profit bands."""

    if (
        elapsed_days < 0
        or not math.isfinite(equity)
        or not math.isfinite(base_multiplier)
        or base_multiplier <= 0.0
    ):
        raise ValueError("elapsed days, equity, and base multiplier are invalid")
    selected = base_multiplier
    previous_day = -1
    profit = equity - START_BALANCE
    for day, minimum_profit, maximum_profit, multiplier in conditional_steps:
        if (
            day < 0
            or day <= previous_day
            or not math.isfinite(minimum_profit)
            or not math.isfinite(maximum_profit)
            or maximum_profit <= minimum_profit
            or not math.isfinite(multiplier)
            or multiplier <= 0.0
        ):
            raise ValueError(
                "conditional deadline steps require increasing days, ordered "
                "finite profit bands, and positive multipliers"
            )
        if elapsed_days >= day and minimum_profit <= profit < maximum_profit:
            selected = multiplier
        previous_day = day
    return selected


def _relative_index(path: GovernedTradePath, grid_idx: int) -> int:
    return min(max(grid_idx - path.start_idx, 0), path.end_idx - path.start_idx)


def liquidation_equity(
    balance: float,
    active: Mapping[str, ActiveTrade],
    grid_idx: int,
    *,
    adverse: bool,
) -> float:
    equity = balance
    for item in active.values():
        rel = _relative_index(item.path, grid_idx)
        pnl = item.path.adverse_pnl[rel] if adverse else item.path.close_pnl[rel]
        equity += (float(pnl) - item.path.exit_commission) * item.scale
    return equity


def _local_midnight_utc(day: dt.date) -> pd.Timestamp:
    return pd.Timestamp(dt.datetime.combine(day, dt.time.min), tz=PRAGUE).tz_convert("UTC")


def simulate_window(
    grid: pd.DatetimeIndex,
    entries: Mapping[int, Sequence[GovernedTradePath]],
    *,
    start_day: dt.date,
    horizon_days: int,
    weights: Mapping[str, float],
    risk_multiplier: float,
    daily_stop: float,
    full_risk_room: float,
    room_retention: float = 0.2,
    open_risk_limit_ratio: float = 0.0,
    symbol_open_risk_limit_ratio: float = 0.0,
    cluster_open_risk_limit_ratio: float = 0.0,
    risk_cluster_by_symbol: Mapping[str, str] | None = None,
    threshold_fill: bool = True,
    profit_risk_steps: Sequence[tuple[float, float]] = (),
    elapsed_risk_steps: Sequence[tuple[int, float]] = (),
    conditional_deadline_steps: Sequence[tuple[int, float, float, float]] = (),
    realized_vol_lookback_days: int = 0,
    realized_vol_target_rms: float = 0.0,
    realized_vol_minimum_scale: float = 0.5,
    realized_vol_maximum_scale: float = 1.25,
) -> WindowResult:
    if horizon_days <= 0 or risk_multiplier <= 0.0:
        raise ValueError("horizon_days and risk_multiplier must be positive")
    if not 0.0 <= room_retention < 1.0:
        raise ValueError("room_retention must be in [0, 1)")
    if not 0.0 < daily_stop <= OFFICIAL_DAILY_LOSS:
        raise ValueError("daily_stop must be in (0, 5000]")
    if full_risk_room <= 0.0:
        raise ValueError("full_risk_room must be positive")
    if not math.isfinite(open_risk_limit_ratio) or open_risk_limit_ratio < 0.0:
        raise ValueError("open_risk_limit_ratio must be finite and non-negative")
    if (
        not math.isfinite(symbol_open_risk_limit_ratio)
        or symbol_open_risk_limit_ratio < 0.0
    ):
        raise ValueError("symbol_open_risk_limit_ratio must be finite and non-negative")
    if (
        not math.isfinite(cluster_open_risk_limit_ratio)
        or cluster_open_risk_limit_ratio < 0.0
    ):
        raise ValueError("cluster_open_risk_limit_ratio must be finite and non-negative")
    cluster_by_symbol = {
        str(symbol).upper(): str(cluster)
        for symbol, cluster in (risk_cluster_by_symbol or {}).items()
    }
    risk_multiplier_for_elapsed_day(0, risk_multiplier, elapsed_risk_steps)
    risk_multiplier_for_conditional_deadline(
        0,
        START_BALANCE,
        risk_multiplier,
        conditional_deadline_steps,
    )
    realized_volatility_scale(
        (),
        lookback_days=realized_vol_lookback_days,
        target_rms=realized_vol_target_rms,
        minimum_scale=realized_vol_minimum_scale,
        maximum_scale=realized_vol_maximum_scale,
    )
    schedule_count = sum(
        bool(schedule)
        for schedule in (
            profit_risk_steps,
            elapsed_risk_steps,
            conditional_deadline_steps,
        )
    )
    if schedule_count > 1:
        raise ValueError("risk schedules cannot be combined")

    start_idx = int(grid.searchsorted(_local_midnight_utc(start_day), side="left"))
    end_day = start_day + dt.timedelta(days=horizon_days)
    end_idx = int(grid.searchsorted(_local_midnight_utc(end_day), side="left"))
    end_idx = min(end_idx, len(grid))
    if start_idx >= end_idx:
        return WindowResult("not_reached", START_BALANCE, START_BALANCE, 0, 0, 0, 0)

    balance = START_BALANCE
    minimum_equity = START_BALANCE
    active: dict[str, ActiveTrade] = {}
    current_day: dt.date | None = None
    midnight_balance = START_BALANCE
    policy_floor = MAX_LOSS_FLOOR
    locked = False
    target_lock = False
    traded_days: set[dt.date] = set()
    accepted_entries = 0
    blocked_entries = 0
    stop_events = 0
    completed_daily_changes: list[float] = []
    daily_marked_start = START_BALANCE
    latest_marked_equity = START_BALANCE
    current_realized_vol_scale = 1.0

    local_days = grid[start_idx:end_idx].tz_convert(PRAGUE).date
    for offset, grid_idx in enumerate(range(start_idx, end_idx)):
        local_day = local_days[offset]
        if local_day != current_day:
            if current_day is not None:
                completed_daily_changes.append(latest_marked_equity - daily_marked_start)
                daily_marked_start = latest_marked_equity
            current_day = local_day
            midnight_balance = balance
            retained_room_floor = MAX_LOSS_FLOOR + room_retention * max(
                0.0,
                midnight_balance - MAX_LOSS_FLOOR,
            )
            policy_floor = max(midnight_balance - daily_stop, retained_room_floor)
            locked = False
            current_realized_vol_scale = realized_volatility_scale(
                completed_daily_changes,
                lookback_days=realized_vol_lookback_days,
                target_rms=realized_vol_target_rms,
                minimum_scale=realized_vol_minimum_scale,
                maximum_scale=realized_vol_maximum_scale,
            )

        opportunities = entries.get(grid_idx, ())
        if opportunities:
            if locked or target_lock:
                blocked_entries += len(opportunities)
            elif (
                open_risk_limit_ratio <= 0.0
                and symbol_open_risk_limit_ratio <= 0.0
                and cluster_open_risk_limit_ratio <= 0.0
            ):
                for path in opportunities:
                    weight = float(weights.get(path.key, 0.0))
                    if weight <= 0.0:
                        continue
                    prior_idx = max(start_idx, grid_idx - 1)
                    sizing_equity = liquidation_equity(
                        balance,
                        active,
                        prior_idx,
                        adverse=False,
                    )
                    throttle = entry_scale_factor(
                        sizing_equity, policy_floor, full_risk_room
                    )
                    if conditional_deadline_steps:
                        entry_risk_multiplier = risk_multiplier_for_conditional_deadline(
                            (local_day - start_day).days,
                            sizing_equity,
                            risk_multiplier,
                            conditional_deadline_steps,
                        )
                    else:
                        elapsed_multiplier = risk_multiplier_for_elapsed_day(
                            (local_day - start_day).days,
                            risk_multiplier,
                            elapsed_risk_steps,
                        )
                        entry_risk_multiplier = risk_multiplier_for_equity(
                            sizing_equity, elapsed_multiplier, profit_risk_steps
                        )
                    scale = (
                        weight
                        * entry_risk_multiplier
                        * throttle
                        * current_realized_vol_scale
                    )
                    if scale <= EPSILON:
                        blocked_entries += 1
                        continue
                    balance -= path.entry_commission * scale
                    active[path.trade_id] = ActiveTrade(path=path, scale=scale)
                    accepted_entries += 1
                    traded_days.add(local_day)
            else:
                prior_idx = max(start_idx, grid_idx - 1)
                sizing_equity = liquidation_equity(
                    balance,
                    active,
                    prior_idx,
                    adverse=False,
                )
                throttle = entry_scale_factor(
                    sizing_equity, policy_floor, full_risk_room
                )
                if conditional_deadline_steps:
                    entry_risk_multiplier = risk_multiplier_for_conditional_deadline(
                        (local_day - start_day).days,
                        sizing_equity,
                        risk_multiplier,
                        conditional_deadline_steps,
                    )
                else:
                    elapsed_multiplier = risk_multiplier_for_elapsed_day(
                        (local_day - start_day).days,
                        risk_multiplier,
                        elapsed_risk_steps,
                    )
                    entry_risk_multiplier = risk_multiplier_for_equity(
                        sizing_equity, elapsed_multiplier, profit_risk_steps
                    )
                desired = [
                    (
                        path,
                        float(weights.get(path.key, 0.0))
                        * entry_risk_multiplier
                        * throttle
                        * current_realized_vol_scale,
                    )
                    for path in opportunities
                    if float(weights.get(path.key, 0.0)) > 0.0
                ]
                allocation = 1.0
                if open_risk_limit_ratio > 0.0 and desired:
                    open_nominal_risk = sum(
                        item.path.nominal_risk * item.scale for item in active.values()
                    )
                    risk_limit = max(
                        0.0,
                        sizing_equity - policy_floor,
                    ) * open_risk_limit_ratio
                    available_risk = max(0.0, risk_limit - open_nominal_risk)
                    desired_risk = sum(
                        path.nominal_risk * scale for path, scale in desired
                    )
                    allocation = (
                        min(1.0, available_risk / desired_risk)
                        if desired_risk > EPSILON
                        else 0.0
                    )
                symbol_allocations: dict[str, float] = {}
                if symbol_open_risk_limit_ratio > 0.0 and desired:
                    symbol_risk_limit = max(
                        0.0,
                        sizing_equity - policy_floor,
                    ) * symbol_open_risk_limit_ratio
                    active_symbol_risk: collections.Counter[str] = collections.Counter()
                    desired_symbol_risk: collections.Counter[str] = collections.Counter()
                    for item in active.values():
                        symbol = item.path.key.split(":", 1)[-1]
                        active_symbol_risk[symbol] += item.path.nominal_risk * item.scale
                    for path, scale in desired:
                        symbol = path.key.split(":", 1)[-1]
                        desired_symbol_risk[symbol] += path.nominal_risk * scale
                    for symbol, desired_risk in desired_symbol_risk.items():
                        available_risk = max(
                            0.0,
                            symbol_risk_limit - active_symbol_risk[symbol],
                        )
                        symbol_allocations[symbol] = (
                            min(1.0, available_risk / desired_risk)
                            if desired_risk > EPSILON
                            else 0.0
                        )
                cluster_allocations: dict[str, float] = {}
                if cluster_open_risk_limit_ratio > 0.0 and desired:
                    cluster_risk_limit = max(
                        0.0,
                        sizing_equity - policy_floor,
                    ) * cluster_open_risk_limit_ratio
                    active_cluster_risk: collections.Counter[str] = collections.Counter()
                    desired_cluster_risk: collections.Counter[str] = collections.Counter()
                    for item in active.values():
                        symbol = item.path.key.split(":", 1)[-1].upper()
                        cluster = cluster_by_symbol.get(symbol)
                        if cluster is not None:
                            active_cluster_risk[cluster] += (
                                item.path.nominal_risk * item.scale
                            )
                    for path, scale in desired:
                        symbol = path.key.split(":", 1)[-1].upper()
                        cluster = cluster_by_symbol.get(symbol)
                        if cluster is not None:
                            desired_cluster_risk[cluster] += path.nominal_risk * scale
                    for cluster, desired_risk in desired_cluster_risk.items():
                        available_risk = max(
                            0.0,
                            cluster_risk_limit - active_cluster_risk[cluster],
                        )
                        cluster_allocations[cluster] = (
                            min(1.0, available_risk / desired_risk)
                            if desired_risk > EPSILON
                            else 0.0
                        )
                for path, desired_scale in desired:
                    symbol = path.key.split(":", 1)[-1].upper()
                    cluster = cluster_by_symbol.get(symbol)
                    scale = desired_scale * min(
                        allocation,
                        symbol_allocations.get(symbol, 1.0),
                        cluster_allocations.get(cluster, 1.0),
                    )
                    if scale <= EPSILON:
                        blocked_entries += 1
                        continue
                    balance -= path.entry_commission * scale
                    active[path.trade_id] = ActiveTrade(path=path, scale=scale)
                    accepted_entries += 1
                    traded_days.add(local_day)

        exiting = [trade_id for trade_id, item in active.items() if item.path.end_idx == grid_idx]
        low_equity = liquidation_equity(balance, active, grid_idx, adverse=True)
        if exiting:
            post_exit_balance = balance + sum(
                active[trade_id].path.exit_balance_delta * active[trade_id].scale
                for trade_id in exiting
            )
            remaining = {
                trade_id: item for trade_id, item in active.items() if trade_id not in exiting
            }
            low_equity = min(
                low_equity,
                liquidation_equity(post_exit_balance, remaining, grid_idx, adverse=True),
            )
        minimum_equity = min(minimum_equity, low_equity)
        if active and low_equity <= policy_floor + EPSILON:
            stop_events += 1
            if threshold_fill:
                balance = policy_floor
                minimum_equity = min(minimum_equity, policy_floor)
            else:
                balance = low_equity
            active.clear()
            locked = True
            latest_marked_equity = balance
            if balance < MAX_LOSS_FLOOR - EPSILON:
                return WindowResult(
                    "max_breach",
                    balance,
                    minimum_equity,
                    len(traded_days),
                    accepted_entries,
                    blocked_entries,
                    stop_events,
                )
            if balance < midnight_balance - OFFICIAL_DAILY_LOSS - EPSILON:
                return WindowResult(
                    "daily_breach",
                    balance,
                    minimum_equity,
                    len(traded_days),
                    accepted_entries,
                    blocked_entries,
                    stop_events,
                )
            continue

        for trade_id in exiting:
            item = active.pop(trade_id)
            balance += item.path.exit_balance_delta * item.scale

        close_equity = liquidation_equity(balance, active, grid_idx, adverse=False)
        latest_marked_equity = close_equity
        minimum_equity = min(minimum_equity, balance, close_equity)
        if close_equity < MAX_LOSS_FLOOR - EPSILON:
            return WindowResult(
                "max_breach",
                close_equity,
                minimum_equity,
                len(traded_days),
                accepted_entries,
                blocked_entries,
                stop_events,
            )
        if close_equity < midnight_balance - OFFICIAL_DAILY_LOSS - EPSILON:
            return WindowResult(
                "daily_breach",
                close_equity,
                minimum_equity,
                len(traded_days),
                accepted_entries,
                blocked_entries,
                stop_events,
            )
        if close_equity >= TARGET_BALANCE - EPSILON:
            # Runtime parity: capture target equity by flattening first. Normal
            # entries remain locked if four trading days are not yet complete.
            balance = close_equity
            active.clear()
            target_lock = True
            latest_marked_equity = balance
            if len(traded_days) >= 4:
                return WindowResult(
                    "passed",
                    balance,
                    minimum_equity,
                    len(traded_days),
                    accepted_entries,
                    blocked_entries,
                    stop_events,
                )

    return WindowResult(
        "not_reached",
        balance,
        minimum_equity,
        len(traded_days),
        accepted_entries,
        blocked_entries,
        stop_events,
    )


def valid_start_days(
    grid: pd.DatetimeIndex,
    *,
    horizon_days: int,
    excluded_years: set[int],
) -> list[dt.date]:
    all_days = sorted(set(grid.tz_convert(PRAGUE).date))
    valid = [day for day in all_days if day.year not in excluded_years]
    valid_set = set(valid)
    return [
        day
        for day in valid
        if all(day + dt.timedelta(days=offset) in valid_set for offset in range(horizon_days))
    ]


def evaluate_policy(
    grid: pd.DatetimeIndex,
    entries: Mapping[int, Sequence[GovernedTradePath]],
    *,
    start_days: Sequence[dt.date],
    horizon_days: int,
    weights: Mapping[str, float],
    risk_multiplier: float,
    daily_stop: float,
    full_risk_room: float,
    room_retention: float,
    open_risk_limit_ratio: float,
    threshold_fill: bool,
    symbol_open_risk_limit_ratio: float = 0.0,
    cluster_open_risk_limit_ratio: float = 0.0,
    risk_cluster_by_symbol: Mapping[str, str] | None = None,
    profit_risk_steps: Sequence[tuple[float, float]] = (),
    elapsed_risk_steps: Sequence[tuple[int, float]] = (),
    conditional_deadline_steps: Sequence[tuple[int, float, float, float]] = (),
    realized_vol_lookback_days: int = 0,
    realized_vol_target_rms: float = 0.0,
    realized_vol_minimum_scale: float = 0.5,
    realized_vol_maximum_scale: float = 1.25,
) -> dict[str, Any]:
    results = [
        simulate_window(
            grid,
            entries,
            start_day=day,
            horizon_days=horizon_days,
            weights=weights,
            risk_multiplier=risk_multiplier,
            daily_stop=daily_stop,
            full_risk_room=full_risk_room,
            room_retention=room_retention,
            open_risk_limit_ratio=open_risk_limit_ratio,
            symbol_open_risk_limit_ratio=symbol_open_risk_limit_ratio,
            cluster_open_risk_limit_ratio=cluster_open_risk_limit_ratio,
            risk_cluster_by_symbol=risk_cluster_by_symbol,
            threshold_fill=threshold_fill,
            profit_risk_steps=profit_risk_steps,
            elapsed_risk_steps=elapsed_risk_steps,
            conditional_deadline_steps=conditional_deadline_steps,
            realized_vol_lookback_days=realized_vol_lookback_days,
            realized_vol_target_rms=realized_vol_target_rms,
            realized_vol_minimum_scale=realized_vol_minimum_scale,
            realized_vol_maximum_scale=realized_vol_maximum_scale,
        )
        for day in start_days
    ]
    counts = collections.Counter(row.outcome for row in results)
    return {
        "historical_rolling": rates(counts),
        "start_windows": len(results),
        "mean_ending_balance": (
            sum(row.ending_balance for row in results) / len(results) if results else START_BALANCE
        ),
        "mean_minimum_equity": (
            sum(row.minimum_equity for row in results) / len(results) if results else START_BALANCE
        ),
        "mean_trading_days": (
            sum(row.trading_days for row in results) / len(results) if results else 0.0
        ),
        "mean_accepted_entries": (
            sum(row.accepted_entries for row in results) / len(results) if results else 0.0
        ),
        "mean_blocked_entries": (
            sum(row.blocked_entries for row in results) / len(results) if results else 0.0
        ),
        "mean_stop_events": (
            sum(row.stop_events for row in results) / len(results) if results else 0.0
        ),
    }


def _parse_numbers(raw: str, kind: type[float] | type[int]) -> list[float] | list[int]:
    output = [kind(value.strip()) for value in raw.split(",") if value.strip()]
    if not output:
        raise ValueError("number list is empty")
    return output


def _parse_risk_clusters(raw: str) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for cluster_raw in raw.split(";"):
        cluster_raw = cluster_raw.strip()
        if not cluster_raw:
            continue
        name, separator, symbols_raw = cluster_raw.partition("=")
        name = name.strip()
        symbols = [value.strip().upper() for value in symbols_raw.split("|") if value.strip()]
        if not separator or not name or not symbols:
            raise ValueError(f"invalid risk cluster: {cluster_raw!r}")
        for symbol in symbols:
            if symbol in mapping:
                raise ValueError(f"symbol appears in multiple risk clusters: {symbol}")
            mapping[symbol] = name
    return mapping


def _parse_profit_risk_schedules(raw: str) -> list[tuple[tuple[float, float], ...]]:
    schedules: list[tuple[tuple[float, float], ...]] = []
    for schedule_raw in raw.split(";"):
        schedule_raw = schedule_raw.strip()
        if not schedule_raw or schedule_raw.lower() == "none":
            schedules.append(())
            continue
        steps: list[tuple[float, float]] = []
        for step_raw in schedule_raw.split("|"):
            pieces = [value.strip() for value in step_raw.split(":")]
            if len(pieces) != 2:
                raise ValueError(f"invalid profit risk step: {step_raw!r}")
            steps.append((float(pieces[0]), float(pieces[1])))
        schedules.append(tuple(steps))
    if not schedules:
        raise ValueError("profit risk schedule list is empty")
    return schedules


def _parse_elapsed_risk_schedules(raw: str) -> list[tuple[tuple[int, float], ...]]:
    schedules: list[tuple[tuple[int, float], ...]] = []
    for schedule_raw in raw.split(";"):
        schedule_raw = schedule_raw.strip()
        if not schedule_raw or schedule_raw.lower() == "none":
            schedules.append(())
            continue
        steps: list[tuple[int, float]] = []
        for step_raw in schedule_raw.split("|"):
            pieces = [value.strip() for value in step_raw.split(":")]
            if len(pieces) != 2:
                raise ValueError(f"invalid elapsed risk step: {step_raw!r}")
            steps.append((int(pieces[0]), float(pieces[1])))
        schedules.append(tuple(steps))
    if not schedules:
        raise ValueError("elapsed risk schedule list is empty")
    return schedules


def _parse_risk_room_pairs(raw: str) -> list[tuple[float, float]]:
    pairs: list[tuple[float, float]] = []
    for pair_raw in raw.split(","):
        pair_raw = pair_raw.strip()
        if not pair_raw:
            continue
        pieces = [value.strip() for value in pair_raw.split(":")]
        if len(pieces) != 2:
            raise ValueError(f"invalid risk/full-room pair: {pair_raw!r}")
        risk, full_room = (float(pieces[0]), float(pieces[1]))
        if risk <= 0.0 or full_room <= 0.0:
            raise ValueError("risk/full-room pairs must be positive")
        pairs.append((risk, full_room))
    if not pairs:
        raise ValueError("risk/full-room pair list is empty")
    return pairs


def _format_profit_risk_steps(steps: Sequence[tuple[float, float]]) -> str:
    if not steps:
        return "none"
    return "|".join(f"{threshold:g}:{multiplier:g}" for threshold, multiplier in steps)


def _format_elapsed_risk_steps(steps: Sequence[tuple[int, float]]) -> str:
    if not steps:
        return "none"
    return "|".join(f"{day}:{multiplier:g}" for day, multiplier in steps)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"))
    parser.add_argument("--scenarios", default="six_sleeve_scout_balanced")
    parser.add_argument("--risk-multipliers", default="75,100,150")
    parser.add_argument("--daily-stops", default="1000")
    parser.add_argument("--full-risk-rooms", default="2000")
    parser.add_argument(
        "--risk-room-pairs",
        default="",
        help=(
            "optional comma-separated risk_multiplier:full_risk_room pairs; "
            "when present, replaces the risk/full-room Cartesian product"
        ),
    )
    parser.add_argument("--room-retentions", default="0.2")
    parser.add_argument(
        "--open-risk-limit-ratios",
        default="0",
        help=(
            "multiples of current equity room to the active policy floor used as a "
            "causal cap on aggregate nominal open risk; zero disables the cap"
        ),
    )
    parser.add_argument(
        "--symbol-open-risk-limit-ratios",
        default="0",
        help=(
            "multiples of current equity room to the active policy floor used as a "
            "causal cap on aggregate nominal risk for each traded symbol; zero disables it"
        ),
    )
    parser.add_argument(
        "--cluster-open-risk-limit-ratios",
        default="0",
        help=(
            "multiples of current equity room to the active policy floor used as a "
            "causal cap for each explicitly declared risk cluster; zero disables it"
        ),
    )
    parser.add_argument(
        "--risk-clusters",
        default="",
        help=(
            "semicolon-separated NAME=SYMBOL|SYMBOL declarations; symbols not listed "
            "remain uncapped by the cluster policy"
        ),
    )
    parser.add_argument(
        "--profit-risk-schedules",
        default="none",
        help=(
            "semicolon-separated schedules; each schedule uses "
            "profit_dollars:risk_multiplier steps joined by |"
        ),
    )
    parser.add_argument(
        "--elapsed-risk-schedules",
        default="none",
        help=(
            "semicolon-separated schedules; each schedule uses "
            "elapsed_calendar_days:risk_multiplier steps joined by |; "
            "cannot be combined with a profit-risk schedule"
        ),
    )
    parser.add_argument("--realized-vol-lookback-days", type=int, default=0)
    parser.add_argument("--realized-vol-target-rms", type=float, default=0.0)
    parser.add_argument("--realized-vol-minimum-scale", type=float, default=0.5)
    parser.add_argument("--realized-vol-maximum-scale", type=float, default=1.25)
    parser.add_argument("--horizon", type=int, default=30)
    parser.add_argument("--exclude-years", default="2020")
    parser.add_argument("--adverse-bar-fill", action="store_true")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    excluded_years = {int(value) for value in args.exclude_years.split(",") if value.strip()}
    risk_cluster_by_symbol = _parse_risk_clusters(args.risk_clusters)
    cases, bars = load_cases(manifest, bar_paths=default_bar_paths(args.data_root))
    grid = common_grid(cases)
    trade_paths: list[GovernedTradePath] = []
    for case in cases:
        symbol = str(case["symbol"]).upper()
        aligned, observed = align_bars_to_grid(bars[symbol], grid)
        trade_paths.extend(
            build_trade_paths(
                case,
                grid=grid,
                aligned_bars=aligned,
                observed_bar_timestamps=observed,
                feature_bars=bars[symbol],
                excluded_years=excluded_years,
            )
        )
    entries = index_entries(trade_paths)
    starts = valid_start_days(grid, horizon_days=args.horizon, excluded_years=excluded_years)
    selected_names = {value.strip() for value in args.scenarios.split(",") if value.strip()}
    scenarios = [row for row in manifest["scenarios"] if row["name"] in selected_names]
    if len(scenarios) != len(selected_names):
        missing = selected_names - {row["name"] for row in scenarios}
        parser.error(f"unknown scenarios: {sorted(missing)}")

    policy_pairs = (
        _parse_risk_room_pairs(args.risk_room_pairs)
        if args.risk_room_pairs.strip()
        else [
            (float(risk), float(full_room))
            for risk in _parse_numbers(args.risk_multipliers, float)
            for full_room in _parse_numbers(args.full_risk_rooms, float)
        ]
    )
    schedule_pairs = [
        (profit_steps, elapsed_steps)
        for profit_steps in _parse_profit_risk_schedules(args.profit_risk_schedules)
        for elapsed_steps in _parse_elapsed_risk_schedules(args.elapsed_risk_schedules)
    ]
    results: list[dict[str, Any]] = []
    for scenario in scenarios:
        for risk, full_room in policy_pairs:
            for daily_stop in _parse_numbers(args.daily_stops, float):
                for retention in _parse_numbers(args.room_retentions, float):
                    for open_risk_ratio in _parse_numbers(
                        args.open_risk_limit_ratios, float
                    ):
                        for symbol_risk_ratio in _parse_numbers(
                            args.symbol_open_risk_limit_ratios, float
                        ):
                            for cluster_risk_ratio in _parse_numbers(
                                args.cluster_open_risk_limit_ratios, float
                            ):
                                for profit_steps, elapsed_steps in schedule_pairs:
                                    if profit_steps and elapsed_steps:
                                        raise ValueError(
                                            "profit and elapsed risk schedules cannot be combined"
                                        )
                                    # Validate every schedule against this grid's base risk even
                                    # when no simulated window reaches its first threshold.
                                    risk_multiplier_for_equity(
                                        START_BALANCE,
                                        float(risk),
                                        profit_steps,
                                    )
                                    risk_multiplier_for_elapsed_day(
                                        args.horizon,
                                        float(risk),
                                        elapsed_steps,
                                    )
                                    evaluation = evaluate_policy(
                                        grid,
                                        entries,
                                        start_days=starts,
                                        horizon_days=args.horizon,
                                        weights=scenario["weights"],
                                        risk_multiplier=float(risk),
                                        daily_stop=float(daily_stop),
                                        full_risk_room=float(full_room),
                                        room_retention=float(retention),
                                        open_risk_limit_ratio=float(open_risk_ratio),
                                        symbol_open_risk_limit_ratio=float(symbol_risk_ratio),
                                        cluster_open_risk_limit_ratio=float(cluster_risk_ratio),
                                        risk_cluster_by_symbol=risk_cluster_by_symbol,
                                        threshold_fill=not args.adverse_bar_fill,
                                        profit_risk_steps=profit_steps,
                                        elapsed_risk_steps=elapsed_steps,
                                        realized_vol_lookback_days=args.realized_vol_lookback_days,
                                        realized_vol_target_rms=args.realized_vol_target_rms,
                                        realized_vol_minimum_scale=args.realized_vol_minimum_scale,
                                        realized_vol_maximum_scale=args.realized_vol_maximum_scale,
                                    )
                                    base_nominal_risk = sum(
                                        float(sleeve["base_risk_fixed"])
                                        * float(
                                            scenario["weights"].get(
                                                sleeve_key(
                                                    sleeve["ea_id"], sleeve["symbol"]
                                                ),
                                                0.0,
                                            )
                                        )
                                        for sleeve in manifest["sleeves"]
                                    ) / 1000.0
                                    peak_risk = max(
                                        [
                                            float(risk),
                                            *(multiplier for _, multiplier in profit_steps),
                                            *(multiplier for _, multiplier in elapsed_steps),
                                        ]
                                    )
                                    if args.realized_vol_lookback_days > 0:
                                        peak_risk *= args.realized_vol_maximum_scale
                                    row = {
                                        "scenario": scenario["name"],
                                        "risk_multiplier": risk,
                                        "peak_risk_multiplier": peak_risk,
                                        "profit_risk_steps": [
                                            {
                                                "profit_threshold": threshold,
                                                "risk_multiplier": multiplier,
                                            }
                                            for threshold, multiplier in profit_steps
                                        ],
                                        "elapsed_risk_steps": [
                                            {
                                                "elapsed_calendar_days": day,
                                                "risk_multiplier": multiplier,
                                            }
                                            for day, multiplier in elapsed_steps
                                        ],
                                        "nominal_risk_pct": base_nominal_risk * float(risk),
                                        "nominal_peak_risk_pct": base_nominal_risk * peak_risk,
                                        "daily_stop": daily_stop,
                                        "full_risk_room": full_room,
                                        "room_retention": retention,
                                        "open_risk_limit_ratio": open_risk_ratio,
                                        "symbol_open_risk_limit_ratio": symbol_risk_ratio,
                                        "cluster_open_risk_limit_ratio": cluster_risk_ratio,
                                        "risk_cluster_by_symbol": risk_cluster_by_symbol,
                                        "realized_vol_lookback_days": args.realized_vol_lookback_days,
                                        "realized_vol_target_rms": args.realized_vol_target_rms,
                                        "realized_vol_minimum_scale": args.realized_vol_minimum_scale,
                                        "realized_vol_maximum_scale": args.realized_vol_maximum_scale,
                                        **evaluation,
                                    }
                                    results.append(row)
                                    print(
                                        f"{scenario['name']} risk={risk:g} "
                                        f"ladder={_format_profit_risk_steps(profit_steps)} "
                                        f"elapsed={_format_elapsed_risk_steps(elapsed_steps)} "
                                        f"stop={daily_stop:g} room={full_room:g} "
                                        f"retention={retention:g} open_risk={open_risk_ratio:g} "
                                        f"symbol_risk={symbol_risk_ratio:g} "
                                        f"cluster_risk={cluster_risk_ratio:g} "
                                        f"rv={args.realized_vol_lookback_days}:"
                                        f"{args.realized_vol_target_rms:g}:"
                                        f"{args.realized_vol_minimum_scale:g}:"
                                        f"{args.realized_vol_maximum_scale:g} "
                                        f"pass={evaluation['historical_rolling']['pass_pct']:.2f}%"
                                    )

    artifact = {
        "schema_version": 1,
        "status": "RESEARCH_ONLY",
        "basis": "fresh_start_entry_sized_m15_trade_cancellation_governor",
        "timestamp_basis": manifest.get("timestamp_basis", TIMESTAMP_BASIS_UNIX_UTC),
        "fill_contract": "adverse_bar" if args.adverse_bar_fill else "ideal_threshold_inside_m15_bar",
        "manifest": str(args.manifest),
        "horizon_calendar_days": args.horizon,
        "excluded_years": sorted(excluded_years),
        "trade_paths": len(trade_paths),
        "start_windows": len(starts),
        "results": results,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
