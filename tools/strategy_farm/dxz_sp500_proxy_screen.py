"""Deterministic research pre-screen for SP500 signals executed on DXZ index proxies.

This is deliberately not a qualification runner.  It applies the QM5_11132
closed-bar signal to NDX and WS30 daily OHLC independently, with causal
signal-to-next-open alignment and an auditable R-multiple trade ledger.
"""

from __future__ import annotations

import argparse
import bisect
import csv
import hashlib
import io
import json
import math
import re
import sys
from dataclasses import dataclass
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Sequence


SCHEMA_VERSION = 1
TOOL_VERSION = "1.0.0"
EXPECTED_HEADER = ["time", "open", "high", "low", "close", "tickvol"]
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
UINT_RE = re.compile(r"\d+")


class InputValidationError(ValueError):
    """Raised when a CSV or requested window fails a fail-closed check."""


@dataclass(frozen=True)
class Bar:
    timestamp: int
    day: date
    open: float
    high: float
    low: float
    close: float
    tickvol: int


@dataclass(frozen=True)
class LoadedBars:
    role: str
    path: Path
    sha256: str
    byte_count: int
    bars: tuple[Bar, ...]


@dataclass(frozen=True)
class StrategyParameters:
    name: str
    rsi_period: int
    cum_window: int
    cum_rsi_entry: float
    rsi_exit: float
    sma_period: int
    atr_period: int
    atr_sl_mult: float
    max_hold_bars: int

    def as_dict(self) -> dict[str, Any]:
        return {
            "rsi_period": self.rsi_period,
            "cum_window": self.cum_window,
            "cum_rsi_entry": self.cum_rsi_entry,
            "rsi_exit": self.rsi_exit,
            "sma_period": self.sma_period,
            "atr_period": self.atr_period,
            "atr_sl_mult": self.atr_sl_mult,
            "max_hold_bars": self.max_hold_bars,
        }


CARD_DEFAULT = StrategyParameters(
    name="card_default",
    rsi_period=2,
    cum_window=2,
    cum_rsi_entry=35.0,
    rsi_exit=65.0,
    sma_period=200,
    atr_period=14,
    atr_sl_mult=2.5,
    max_hold_bars=5,
)

LEGACY_LIVE = StrategyParameters(
    name="legacy_live",
    rsi_period=2,
    cum_window=2,
    cum_rsi_entry=38.0,
    rsi_exit=66.0,
    sma_period=165,
    atr_period=12,
    atr_sl_mult=2.0,
    max_hold_bars=5,
)

VARIANTS = (CARD_DEFAULT, LEGACY_LIVE)


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def canonical_sha256(value: Any) -> str:
    payload = json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("utf-8")
    return sha256_bytes(payload)


def _parse_date(value: str, label: str) -> date:
    if DATE_RE.fullmatch(value) is None:
        raise InputValidationError(f"{label} must be strict YYYY-MM-DD: {value!r}")
    try:
        parsed = date.fromisoformat(value)
    except ValueError as exc:
        raise InputValidationError(f"invalid {label}: {value!r}") from exc
    if parsed.isoformat() != value:
        raise InputValidationError(f"invalid {label}: {value!r}")
    return parsed


def parse_window(from_value: str, to_value: str) -> tuple[date, date]:
    from_day = _parse_date(from_value, "from-date")
    to_day = _parse_date(to_value, "to-date")
    if from_day > to_day:
        raise InputValidationError("from-date must be <= to-date")
    return from_day, to_day


def _parse_positive_float(token: str, *, field: str, line_number: int) -> float:
    if not token or token != token.strip():
        raise InputValidationError(
            f"line {line_number}: {field} is missing or contains outer whitespace"
        )
    try:
        value = float(token)
    except ValueError as exc:
        raise InputValidationError(
            f"line {line_number}: {field} is not numeric: {token!r}"
        ) from exc
    if not math.isfinite(value) or value <= 0.0:
        raise InputValidationError(
            f"line {line_number}: {field} must be finite and > 0"
        )
    return value


def load_csv(path: Path, role: str) -> LoadedBars:
    resolved = path.expanduser().resolve(strict=True)
    if not resolved.is_file():
        raise InputValidationError(f"{role} input is not a file: {resolved}")
    raw = resolved.read_bytes()
    digest = sha256_bytes(raw)
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise InputValidationError(f"{role} input is not UTF-8: {resolved}") from exc

    reader = csv.reader(io.StringIO(text, newline=""))
    try:
        header = next(reader)
    except StopIteration as exc:
        raise InputValidationError(f"{role} input is empty: {resolved}") from exc
    if header != EXPECTED_HEADER:
        raise InputValidationError(
            f"{role} schema mismatch: expected {EXPECTED_HEADER!r}, got {header!r}"
        )

    bars: list[Bar] = []
    prior_timestamp: int | None = None
    seen_days: set[date] = set()
    for line_number, row in enumerate(reader, start=2):
        if len(row) != len(EXPECTED_HEADER):
            raise InputValidationError(
                f"line {line_number}: expected {len(EXPECTED_HEADER)} fields, got {len(row)}"
            )
        time_token, open_token, high_token, low_token, close_token, volume_token = row
        if UINT_RE.fullmatch(time_token) is None:
            raise InputValidationError(
                f"line {line_number}: time must be an unsigned integer Unix timestamp"
            )
        timestamp = int(time_token)
        if timestamp <= 0:
            raise InputValidationError(f"line {line_number}: time must be > 0")
        if prior_timestamp is not None:
            if timestamp == prior_timestamp:
                raise InputValidationError(
                    f"line {line_number}: duplicate timestamp {timestamp}"
                )
            if timestamp < prior_timestamp:
                raise InputValidationError(
                    f"line {line_number}: nonmonotonic timestamp {timestamp}"
                )
        try:
            day = datetime.fromtimestamp(timestamp, tz=timezone.utc).date()
        except (OverflowError, OSError, ValueError) as exc:
            raise InputValidationError(
                f"line {line_number}: invalid Unix timestamp {timestamp}"
            ) from exc
        if day in seen_days:
            raise InputValidationError(
                f"line {line_number}: duplicate UTC D1 calendar date {day.isoformat()}"
            )

        open_price = _parse_positive_float(
            open_token, field="open", line_number=line_number
        )
        high = _parse_positive_float(high_token, field="high", line_number=line_number)
        low = _parse_positive_float(low_token, field="low", line_number=line_number)
        close = _parse_positive_float(close_token, field="close", line_number=line_number)
        if high < max(open_price, close) or low > min(open_price, close) or high < low:
            raise InputValidationError(
                f"line {line_number}: inconsistent OHLC ordering"
            )
        if UINT_RE.fullmatch(volume_token) is None:
            raise InputValidationError(
                f"line {line_number}: tickvol must be a non-negative integer"
            )
        tickvol = int(volume_token)

        bars.append(
            Bar(
                timestamp=timestamp,
                day=day,
                open=open_price,
                high=high,
                low=low,
                close=close,
                tickvol=tickvol,
            )
        )
        prior_timestamp = timestamp
        seen_days.add(day)

    if not bars:
        raise InputValidationError(f"{role} input contains no data rows: {resolved}")
    return LoadedBars(
        role=role,
        path=resolved,
        sha256=digest,
        byte_count=len(raw),
        bars=tuple(bars),
    )


def simple_moving_average(values: Sequence[float], period: int) -> list[float | None]:
    if period <= 0:
        raise ValueError("SMA period must be > 0")
    output: list[float | None] = [None] * len(values)
    rolling = 0.0
    for index, value in enumerate(values):
        rolling += value
        if index >= period:
            rolling -= values[index - period]
        if index >= period - 1:
            output[index] = rolling / period
    return output


def wilder_rsi(values: Sequence[float], period: int) -> list[float | None]:
    """Return causal Wilder RSI, seeded by the first ``period`` deltas."""

    if period <= 0:
        raise ValueError("RSI period must be > 0")
    output: list[float | None] = [None] * len(values)
    if len(values) <= period:
        return output

    gains = [max(values[i] - values[i - 1], 0.0) for i in range(1, period + 1)]
    losses = [max(values[i - 1] - values[i], 0.0) for i in range(1, period + 1)]
    average_gain = sum(gains) / period
    average_loss = sum(losses) / period

    def rsi_value(gain: float, loss: float) -> float:
        if loss == 0.0:
            return 50.0 if gain == 0.0 else 100.0
        if gain == 0.0:
            return 0.0
        return 100.0 - (100.0 / (1.0 + gain / loss))

    output[period] = rsi_value(average_gain, average_loss)
    for index in range(period + 1, len(values)):
        change = values[index] - values[index - 1]
        gain = max(change, 0.0)
        loss = max(-change, 0.0)
        average_gain = ((average_gain * (period - 1)) + gain) / period
        average_loss = ((average_loss * (period - 1)) + loss) / period
        output[index] = rsi_value(average_gain, average_loss)
    return output


def wilder_atr(bars: Sequence[Bar], period: int) -> list[float | None]:
    """Return causal Wilder ATR, seeded by the first ``period`` true ranges."""

    if period <= 0:
        raise ValueError("ATR period must be > 0")
    output: list[float | None] = [None] * len(bars)
    if len(bars) < period:
        return output
    true_ranges: list[float] = []
    for index, bar in enumerate(bars):
        if index == 0:
            true_ranges.append(bar.high - bar.low)
        else:
            prior_close = bars[index - 1].close
            true_ranges.append(
                max(
                    bar.high - bar.low,
                    abs(bar.high - prior_close),
                    abs(bar.low - prior_close),
                )
            )
    average = sum(true_ranges[:period]) / period
    output[period - 1] = average
    for index in range(period, len(bars)):
        average = ((average * (period - 1)) + true_ranges[index]) / period
        output[index] = average
    return output


def _round(value: float, places: int = 10) -> float:
    rounded = round(float(value), places)
    return 0.0 if rounded == 0.0 else rounded


def _summarize_trades(trades: Sequence[dict[str, Any]]) -> dict[str, Any]:
    returns = [float(trade["r_multiple"]) for trade in trades]
    gross_profit = sum(value for value in returns if value > 0.0)
    gross_loss = -sum(value for value in returns if value < 0.0)
    if gross_loss == 0.0:
        gross_pf: float | None = None
        gross_pf_state = "NO_LOSSES"
    else:
        gross_pf = _round(gross_profit / gross_loss)
        gross_pf_state = "FINITE"

    equity = 0.0
    peak = 0.0
    maximum_drawdown = 0.0
    for value in returns:
        equity += value
        peak = max(peak, equity)
        maximum_drawdown = max(maximum_drawdown, peak - equity)

    reason_counts: dict[str, int] = {}
    for trade in trades:
        reason = str(trade["exit_reason"])
        reason_counts[reason] = reason_counts.get(reason, 0) + 1
    return {
        "trades": len(trades),
        "gross_pf": gross_pf,
        "gross_pf_state": gross_pf_state,
        "sum_r": _round(sum(returns)),
        "max_dd_r": _round(maximum_drawdown),
        "wins": sum(value > 0.0 for value in returns),
        "losses": sum(value < 0.0 for value in returns),
        "breakeven": sum(value == 0.0 for value in returns),
        "gross_profit_r": _round(gross_profit),
        "gross_loss_r": _round(gross_loss),
        "exit_reason_counts": dict(sorted(reason_counts.items())),
    }


def pairwise_calendar_summary(
    sp500_bars: Sequence[Bar],
    proxy_bars: Sequence[Bar],
    from_day: date,
    to_day: date,
) -> dict[str, Any]:
    """Summarize one SP500/proxy as-of calendar without any third symbol."""

    sp_days = [bar.day for bar in sp500_bars]
    proxy_window = [bar for bar in proxy_bars if from_day <= bar.day <= to_day]
    pairs: list[dict[str, str]] = []
    for bar in proxy_window:
        sp_index = bisect.bisect_left(sp_days, bar.day) - 1
        if sp_index >= 0:
            pairs.append(
                {
                    "proxy_open_date": bar.day.isoformat(),
                    "latest_closed_sp500_bar_date": sp500_bars[sp_index].day.isoformat(),
                }
            )
    sp_window_days = {bar.day for bar in sp500_bars if from_day <= bar.day <= to_day}
    proxy_window_days = {bar.day for bar in proxy_window}
    return {
        "method": "PAIRWISE_ASOF_STRICTLY_PRIOR_SP500_TO_PROXY_OPEN",
        "proxy_execution_bars_in_window": len(proxy_window),
        "proxy_execution_bars_with_prior_sp500": len(pairs),
        "exact_shared_utc_dates_in_window": len(sp_window_days & proxy_window_days),
        "sp500_only_utc_dates_in_window": len(sp_window_days - proxy_window_days),
        "proxy_only_utc_dates_in_window": len(proxy_window_days - sp_window_days),
        "first_pair": pairs[0] if pairs else None,
        "last_pair": pairs[-1] if pairs else None,
        "pair_stream_sha256": canonical_sha256(pairs),
        "third_symbol_used": False,
    }


def simulate_proxy(
    sp500_bars: Sequence[Bar],
    proxy_bars: Sequence[Bar],
    parameters: StrategyParameters,
    *,
    friday_close: bool,
    from_day: date,
    to_day: date,
) -> dict[str, Any]:
    """Simulate one proxy causally; all prices and stops come from that proxy."""

    if parameters.cum_window != 2:
        raise ValueError("this audit screen implements the fixed two-RSI cumulative rule")
    sp_closes = [bar.close for bar in sp500_bars]
    sp_days = [bar.day for bar in sp500_bars]
    proxy_days = [bar.day for bar in proxy_bars]
    rsi = wilder_rsi(sp_closes, parameters.rsi_period)
    sma = simple_moving_average(sp_closes, parameters.sma_period)
    atr = wilder_atr(proxy_bars, parameters.atr_period)

    signal_indices: list[int] = []
    for index, bar in enumerate(sp500_bars):
        if index == 0 or rsi[index] is None or rsi[index - 1] is None or sma[index] is None:
            continue
        if (
            bar.close > float(sma[index])
            and float(rsi[index]) + float(rsi[index - 1])
            < parameters.cum_rsi_entry
        ):
            signal_indices.append(index)

    signals_by_proxy_index: dict[int, list[int]] = {}
    unmapped_signal_count = 0
    for sp_index in signal_indices:
        proxy_index = bisect.bisect_right(proxy_days, sp500_bars[sp_index].day)
        if proxy_index >= len(proxy_bars):
            unmapped_signal_count += 1
            continue
        signals_by_proxy_index.setdefault(proxy_index, []).append(sp_index)

    trades: list[dict[str, Any]] = []
    open_position: dict[str, Any] | None = None
    ignored_signals_while_open = 0
    atr_warmup_skips = 0
    mapped_signals_in_window = 0

    def close_position(
        *,
        exit_bar: Bar,
        exit_price: float,
        reason: str,
        exit_signal_day: date | None,
    ) -> None:
        nonlocal open_position
        assert open_position is not None
        risk_distance = float(open_position["risk_distance"])
        r_multiple = (exit_price - float(open_position["entry_price"])) / risk_distance
        if reason == "stop":
            r_multiple = -1.0
        trades.append(
            {
                "entry_signal_date": open_position["entry_signal_date"],
                "entry_date": open_position["entry_date"],
                "entry_price": _round(float(open_position["entry_price"])),
                "initial_stop": _round(float(open_position["stop"])),
                "risk_distance": _round(risk_distance),
                "exit_signal_date": exit_signal_day.isoformat() if exit_signal_day else None,
                "exit_date": exit_bar.day.isoformat(),
                "exit_price": _round(exit_price),
                "exit_reason": reason,
                "completed_proxy_bars_before_exit": int(open_position["bars_held"]),
                "r_multiple": _round(r_multiple),
            }
        )
        open_position = None

    for proxy_index, proxy_bar in enumerate(proxy_bars):
        if proxy_bar.day < from_day or proxy_bar.day > to_day:
            continue

        prior_sp_index = bisect.bisect_left(sp_days, proxy_bar.day) - 1

        # Open/time-or-RSI exits are decided from information already closed at
        # this proxy open and therefore precede this bar's intraday stop test.
        if open_position is not None:
            exit_signal_day: date | None = None
            exit_reason: str | None = None
            if prior_sp_index >= 0 and rsi[prior_sp_index] is not None:
                if float(rsi[prior_sp_index]) > parameters.rsi_exit:
                    exit_reason = "rsi_exit_at_open"
                    exit_signal_day = sp500_bars[prior_sp_index].day
            if exit_reason is None and int(open_position["bars_held"]) >= parameters.max_hold_bars:
                exit_reason = "time_exit_at_open"
            if exit_reason is not None:
                close_position(
                    exit_bar=proxy_bar,
                    exit_price=proxy_bar.open,
                    reason=exit_reason,
                    exit_signal_day=exit_signal_day,
                )

        mapped_here = signals_by_proxy_index.get(proxy_index, [])
        mapped_signals_in_window += len(mapped_here)
        if mapped_here and open_position is not None:
            ignored_signals_while_open += len(mapped_here)
        elif mapped_here and open_position is None:
            # Multiple closed signals can map to the same next available open;
            # execute once and bind the most recent signal known at that open.
            signal_index = mapped_here[-1]
            prior_atr_index = proxy_index - 1
            atr_value = atr[prior_atr_index] if prior_atr_index >= 0 else None
            if atr_value is None or float(atr_value) <= 0.0:
                atr_warmup_skips += len(mapped_here)
            else:
                risk_distance = float(atr_value) * parameters.atr_sl_mult
                open_position = {
                    "entry_signal_date": sp500_bars[signal_index].day.isoformat(),
                    "entry_date": proxy_bar.day.isoformat(),
                    "entry_price": proxy_bar.open,
                    "stop": proxy_bar.open - risk_distance,
                    "risk_distance": risk_distance,
                    "bars_held": 0,
                }

        # A same-day stop is possible after a next-open entry.  Gap-through is
        # intentionally simplified to an exact stop fill for this screen.
        if open_position is not None and proxy_bar.low <= float(open_position["stop"]):
            close_position(
                exit_bar=proxy_bar,
                exit_price=float(open_position["stop"]),
                reason="stop",
                exit_signal_day=None,
            )

        # Stop has priority within a Friday bar; only survivors close at close.
        if open_position is not None and friday_close and proxy_bar.day.weekday() == 4:
            close_position(
                exit_bar=proxy_bar,
                exit_price=proxy_bar.close,
                reason="friday_close",
                exit_signal_day=None,
            )

        if open_position is not None:
            open_position["bars_held"] = int(open_position["bars_held"]) + 1

    open_at_end: dict[str, Any] | None = None
    if open_position is not None:
        open_at_end = {
            "entry_signal_date": open_position["entry_signal_date"],
            "entry_date": open_position["entry_date"],
            "entry_price": _round(float(open_position["entry_price"])),
            "initial_stop": _round(float(open_position["stop"])),
            "risk_distance": _round(float(open_position["risk_distance"])),
            "completed_proxy_bars": int(open_position["bars_held"]),
            "excluded_from_realized_metrics": True,
        }

    return {
        "parameters": parameters.as_dict(),
        "friday_close_enabled": friday_close,
        "metrics": _summarize_trades(trades),
        "data_counts": {
            "sp500_entry_signal_events_full_input": len(signal_indices),
            "entry_signal_events_mapped_to_proxy_open_in_window": mapped_signals_in_window,
            "entry_signal_events_ignored_while_position_open": ignored_signals_while_open,
            "entry_signal_events_skipped_for_proxy_atr_warmup": atr_warmup_skips,
            "entry_signal_events_without_any_later_proxy_bar": unmapped_signal_count,
            "realized_trades": len(trades),
            "open_position_at_window_end": 1 if open_at_end else 0,
        },
        "open_position_at_window_end": open_at_end,
        "trade_stream_sha256": canonical_sha256(trades),
        "trades": trades,
        "non_qualification": True,
        "cost_certified": False,
    }


def _input_summary(data: LoadedBars, from_day: date, to_day: date) -> dict[str, Any]:
    in_window = sum(from_day <= bar.day <= to_day for bar in data.bars)
    return {
        "role": data.role,
        "path": str(data.path),
        "sha256": data.sha256,
        "bytes": data.byte_count,
        "rows_total": len(data.bars),
        "rows_before_window": sum(bar.day < from_day for bar in data.bars),
        "rows_in_window": in_window,
        "rows_after_window": sum(bar.day > to_day for bar in data.bars),
        "first_utc_date": data.bars[0].day.isoformat(),
        "last_utc_date": data.bars[-1].day.isoformat(),
        "first_unix_time": data.bars[0].timestamp,
        "last_unix_time": data.bars[-1].timestamp,
    }


def build_report(
    sp500: LoadedBars,
    ndx: LoadedBars,
    ws30: LoadedBars,
    *,
    from_day: date,
    to_day: date,
) -> dict[str, Any]:
    resolved_paths = {sp500.path, ndx.path, ws30.path}
    if len(resolved_paths) != 3:
        raise InputValidationError("SP500, NDX and WS30 inputs must be three distinct paths")
    for data in (sp500, ndx, ws30):
        if not any(from_day <= bar.day <= to_day for bar in data.bars):
            raise InputValidationError(
                f"{data.role} has no rows in requested inclusive window"
            )

    proxy_results: dict[str, Any] = {}
    for role, proxy in (("NDX", ndx), ("WS30", ws30)):
        simulations: dict[str, Any] = {}
        for parameters in VARIANTS:
            for friday_close in (False, True):
                key = f"{parameters.name}__friday_{'on' if friday_close else 'off'}"
                simulations[key] = simulate_proxy(
                    sp500.bars,
                    proxy.bars,
                    parameters,
                    friday_close=friday_close,
                    from_day=from_day,
                    to_day=to_day,
                )
        proxy_results[role] = {
            "proxy_input_role": role,
            "calendar": pairwise_calendar_summary(
                sp500.bars, proxy.bars, from_day, to_day
            ),
            "variants": simulations,
        }

    implementation_path = Path(__file__).resolve()
    return {
        "schema_version": SCHEMA_VERSION,
        "tool": "dxz_sp500_proxy_screen",
        "tool_version": TOOL_VERSION,
        "implementation_path": str(implementation_path),
        "implementation_sha256": sha256_bytes(implementation_path.read_bytes()),
        "status": "RESEARCH_SCREEN_COMPLETE_NON_QUALIFYING",
        "qualification_status": "NON_QUALIFICATION",
        "non_qualification": True,
        "cost_certified": False,
        "deployment_eligible": False,
        "prominent_warning": (
            "RESEARCH PRE-SCREEN ONLY: no costs, contract sizing, MT5 execution, "
            "broker routing, qualification cascade, or portfolio admission is certified."
        ),
        "requested_window": {
            "from": from_day.isoformat(),
            "to": to_day.isoformat(),
            "inclusive": True,
            "entry_book_state_at_start": "FLAT",
            "synthetic_end_of_window_liquidation": False,
        },
        "inputs": {
            "SP500": _input_summary(sp500, from_day, to_day),
            "NDX": _input_summary(ndx, from_day, to_day),
            "WS30": _input_summary(ws30, from_day, to_day),
        },
        "research_assumptions": {
            "signal_indicators": (
                "Wilder RSI and SMA use the complete SP500 series only; each "
                "signal uses that SP500 bar's close with no future bar."
            ),
            "execution_indicator": (
                "Wilder ATR uses the complete selected proxy series only; stop "
                "distance at entry uses the prior closed proxy bar ATR."
            ),
            "pairing": (
                "Each SP500 signal maps strictly to the next available open of "
                "that proxy. NDX and WS30 are paired independently; no triple "
                "calendar intersection is used."
            ),
            "entry": "Long at the mapped proxy D1 open after a closed SP500 signal.",
            "open_exit_priority": (
                "At each later proxy open, prior closed SP500 RSI>threshold or "
                "five completed proxy bars exits at that open before intrabar stop."
            ),
            "stop": (
                "If proxy low<=initial stop, fill exactly at stop (-1R), including "
                "gap-through; no intraday path beyond OHLC is inferred."
            ),
            "friday_on": (
                "If still open after the Friday bar's stop test, exit at that "
                "proxy Friday close."
            ),
            "friday_off": "No forced Friday liquidation.",
            "end_of_window": (
                "Any open position remains open and is excluded from realized metrics."
            ),
            "costs": (
                "Spread, commission, slippage, financing, dividends, and gap-through "
                "loss beyond the stop are all excluded."
            ),
            "calendar_timezone": "Unix timestamps interpreted as UTC calendar dates.",
        },
        "variants": {
            parameters.name: parameters.as_dict() for parameters in VARIANTS
        },
        "proxy_results": proxy_results,
    }


def _write_new_json(path: Path, report: dict[str, Any]) -> str:
    path = path.expanduser().resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(report, indent=2, sort_keys=True) + "\n").encode("utf-8")
    try:
        with path.open("xb") as handle:
            handle.write(payload)
    except FileExistsError as exc:
        raise InputValidationError(f"refusing to overwrite existing output: {path}") from exc
    return sha256_bytes(payload)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sp500-csv", type=Path, required=True)
    parser.add_argument("--ndx-csv", type=Path, required=True)
    parser.add_argument("--ws30-csv", type=Path, required=True)
    parser.add_argument("--from-date", required=True)
    parser.add_argument("--to-date", required=True)
    parser.add_argument("--output-json", type=Path, required=True)
    args = parser.parse_args(argv)

    try:
        if args.output_json.expanduser().resolve().exists():
            raise InputValidationError(
                f"refusing to overwrite existing output: {args.output_json.expanduser().resolve()}"
            )
        from_day, to_day = parse_window(args.from_date, args.to_date)
        sp500 = load_csv(args.sp500_csv, "SP500")
        ndx = load_csv(args.ndx_csv, "NDX")
        ws30 = load_csv(args.ws30_csv, "WS30")
        report = build_report(
            sp500, ndx, ws30, from_day=from_day, to_day=to_day
        )
        output_sha256 = _write_new_json(args.output_json, report)
    except (InputValidationError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    print(
        json.dumps(
            {
                "status": report["status"],
                "non_qualification": True,
                "cost_certified": False,
                "output": str(args.output_json.expanduser().resolve()),
                "output_sha256": output_sha256,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
