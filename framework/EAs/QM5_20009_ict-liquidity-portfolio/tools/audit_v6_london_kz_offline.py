#!/usr/bin/env python3
"""Outcome-fenced offline screen for the preregistered v6 London-KZ candidate.

This is deliberately separate from the EA, v5 freeze, launcher, and MT5.  It reads
only the preregistered M5 interval, aggregates causally to M15, and emits a JSON
mechanism audit.  It is not pipeline or qualification evidence.
"""

from __future__ import annotations

import argparse
import bisect
import csv
import hashlib
import json
import math
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from statistics import mean, median
from typing import Any, Iterable, Mapping, Sequence
from zoneinfo import ZoneInfo


TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parent.parent
DEFAULT_CONTRACT = EA_ROOT / "docs" / "candidates" / "v6_london_kz_cable_sweep_offline_contract.json"
EXPECTED_CONTRACT_SHA256 = "63d4033bc0bf8a727c2e31ae3a01a2387acf941233199557cbb6132a0c71cee6"
CONTRACT_COMMIT = "7edc617ca7651bdd3de6f8ff15bda96f26ba82a0"
DEFAULT_NEWS = Path(r"D:\QM\data\news_calendar\news_calendar_2015_2025.csv")
DEFAULT_DATA_ROOT = Path(r"D:\QM\mt5\T_Export\MQL5\Files")
START = datetime(2017, 10, 1)
END = datetime(2023, 1, 1)
M5_SECONDS = 300
M15_SECONDS = 900
RISK_USD = Decimal("1000")
CENT = Decimal("0.01")
NY = ZoneInfo("America/New_York")


class AuditError(RuntimeError):
    """Fail-closed input or contract error."""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_decimal(value: Decimal | float) -> str:
    dec = value if isinstance(value, Decimal) else Decimal(str(value))
    text = format(dec, "f")
    if "." in text:
        text = text.rstrip("0").rstrip(".")
    return text or "0"


@dataclass(frozen=True)
class Bar:
    epoch: int
    open: float
    high: float
    low: float
    close: float
    tickvol: int

    @property
    def dt(self) -> datetime:
        # MT5-export integer is deliberately interpreted as naive broker time.
        return datetime.fromtimestamp(self.epoch, tz=timezone.utc).replace(tzinfo=None)

    @property
    def close_dt(self) -> datetime:
        return self.dt + timedelta(minutes=15)


@dataclass(frozen=True)
class InputIdentity:
    path: str
    selected_sha256: str
    selected_rows: int
    first_selected: str
    last_selected: str
    first_excluded_timestamp: str | None
    future_ohlc_parsed: bool


@dataclass(frozen=True)
class Trade:
    symbol: str
    side: str
    day: str
    entry_time: str
    exit_time: str
    entry: float
    stop: float
    tp1: float
    tp3: float
    risk_price: float
    lots: float
    gross_r: float
    commission_usd: float
    adjusted_r: float
    exit_reason: str
    partial_done: bool


@dataclass
class SymbolResult:
    symbol: str
    input_identity: InputIdentity
    m5_rows: int
    m15_bars: int
    m15_invalid_groups: int
    funnel: Counter[str]
    terminal: Counter[str]
    ambiguity: Counter[str]
    trades: list[Trade]
    integrity_issues: list[str]


class Blackouts:
    def __init__(self, intervals: Mapping[str, Sequence[tuple[datetime, datetime]]]):
        self.intervals: dict[str, list[tuple[datetime, datetime]]] = {}
        self.starts: dict[str, list[datetime]] = {}
        for symbol, raw in intervals.items():
            merged: list[list[datetime]] = []
            for start, end in sorted(raw):
                if merged and start <= merged[-1][1]:
                    if end > merged[-1][1]:
                        merged[-1][1] = end
                else:
                    merged.append([start, end])
            rows = [(row[0], row[1]) for row in merged]
            self.intervals[symbol] = rows
            self.starts[symbol] = [row[0] for row in rows]

    def overlaps(self, symbol: str, start: datetime, end: datetime) -> bool:
        rows = self.intervals.get(symbol, [])
        if not rows:
            return False
        idx = bisect.bisect_right(self.starts[symbol], end) - 1
        return idx >= 0 and rows[idx][1] >= start


def load_news(path: Path) -> tuple[Blackouts, dict[str, Any]]:
    if not path.is_file():
        raise AuditError(f"news file missing: {path}")
    intervals: dict[str, list[tuple[datetime, datetime]]] = {
        "GBPUSD.DWX": [],
        "EURUSD.DWX": [],
    }
    currencies = {
        "GBPUSD.DWX": {"GBP", "USD"},
        "EURUSD.DWX": {"EUR", "USD"},
    }
    min_utc: datetime | None = None
    max_utc: datetime | None = None
    high_events = 0
    seen: dict[tuple[str, str, str], tuple[str, str]] = {}
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        required = {"datetime", "currency", "event_name", "is_high_impact"}
        if not required.issubset(reader.fieldnames or []):
            raise AuditError("news header missing required fields")
        for row_number, row in enumerate(reader, start=2):
            raw_dt = (row.get("datetime") or "").strip()
            currency = (row.get("currency") or "").strip().upper()
            event_name = (row.get("event_name") or "").strip()
            high = (row.get("is_high_impact") or "").strip()
            if not raw_dt or not currency or not event_name or high not in {"0", "1"}:
                raise AuditError(f"malformed news row {row_number}")
            key = (raw_dt, currency, event_name)
            prior = seen.get(key)
            material = (high, (row.get("impact") or "").strip().lower())
            if prior is not None and prior != material:
                raise AuditError(f"conflicting duplicate news row: {key}")
            seen[key] = material
            try:
                utc = datetime.strptime(raw_dt, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
            except ValueError as exc:
                raise AuditError(f"invalid news datetime row {row_number}: {raw_dt}") from exc
            min_utc = utc if min_utc is None or utc < min_utc else min_utc
            max_utc = utc if max_utc is None or utc > max_utc else max_utc
            if high != "1":
                continue
            high_events += 1
            broker = (utc.astimezone(NY).replace(tzinfo=None) + timedelta(hours=7))
            start = broker - timedelta(minutes=30)
            end = broker + timedelta(minutes=30)
            for symbol, relevant in currencies.items():
                if currency in relevant:
                    intervals[symbol].append((start, end))
    if min_utc is None or max_utc is None:
        raise AuditError("empty news calendar")
    # Coverage is tested in UTC with a generous boundary because the source is global.
    if min_utc.date() > START.date() or max_utc.date() < (END - timedelta(days=1)).date():
        raise AuditError(f"news coverage does not span evaluation: {min_utc} .. {max_utc}")
    return Blackouts(intervals), {
        "path": str(path),
        "sha256": sha256_file(path),
        "first_utc": min_utc.isoformat(),
        "last_utc": max_utc.isoformat(),
        "high_impact_rows": high_events,
        "merged_intervals": {symbol: len(Blackouts(intervals).intervals[symbol]) for symbol in intervals},
    }


def load_selected_m5(path: Path) -> tuple[list[Bar], InputIdentity]:
    """Read only the preregistered slice; inspect no future OHLC fields."""
    if not path.is_file():
        raise AuditError(f"market CSV missing: {path}")
    selected: list[Bar] = []
    digest = hashlib.sha256()
    first_excluded: str | None = None
    prior_epoch: int | None = None
    start_epoch = int(START.replace(tzinfo=timezone.utc).timestamp())
    end_epoch = int(END.replace(tzinfo=timezone.utc).timestamp())
    with path.open("r", encoding="ascii", newline="") as handle:
        header = handle.readline().strip("\r\n")
        if header != "time,open,high,low,close,tickvol":
            raise AuditError(f"unexpected market header in {path}: {header!r}")
        for row_number, raw_line in enumerate(handle, start=2):
            # Deliberately parse only the timestamp before applying the 2023 fence.
            first_field, separator, _future_unparsed = raw_line.partition(",")
            if not separator:
                raise AuditError(f"malformed market row {row_number}: no delimiter")
            try:
                epoch = int(first_field)
            except ValueError as exc:
                raise AuditError(f"invalid market epoch row {row_number}") from exc
            if epoch >= end_epoch:
                first_excluded = datetime.fromtimestamp(epoch, tz=timezone.utc).replace(tzinfo=None).isoformat(sep=" ")
                break
            if epoch < start_epoch:
                continue
            if prior_epoch is not None and epoch <= prior_epoch:
                raise AuditError(f"non-monotone/duplicate selected market epoch row {row_number}")
            prior_epoch = epoch
            parts = raw_line.strip("\r\n").split(",")
            if len(parts) != 6:
                raise AuditError(f"malformed selected market row {row_number}")
            try:
                values = [float(part) for part in parts[1:5]]
                tickvol = int(parts[5])
            except ValueError as exc:
                raise AuditError(f"non-numeric selected market row {row_number}") from exc
            open_, high, low, close = values
            if (
                not all(math.isfinite(value) and value > 0 for value in values)
                or high < max(open_, low, close)
                or low > min(open_, high, close)
                or tickvol < 0
            ):
                raise AuditError(f"invalid OHLC selected market row {row_number}")
            canonical = f"{epoch},{parts[1]},{parts[2]},{parts[3]},{parts[4]},{tickvol}\n".encode("ascii")
            digest.update(canonical)
            selected.append(Bar(epoch, open_, high, low, close, tickvol))
    if not selected:
        raise AuditError(f"no selected M5 rows in {path}")
    if first_excluded is None:
        raise AuditError(f"future fence cannot be proven (no >=2023 timestamp encountered): {path}")
    identity = InputIdentity(
        path=str(path),
        selected_sha256=digest.hexdigest(),
        selected_rows=len(selected),
        first_selected=selected[0].dt.isoformat(sep=" "),
        last_selected=selected[-1].dt.isoformat(sep=" "),
        first_excluded_timestamp=first_excluded,
        future_ohlc_parsed=False,
    )
    return selected, identity


def aggregate_m15(rows: Sequence[Bar]) -> tuple[list[Bar], int]:
    groups: dict[int, list[Bar]] = defaultdict(list)
    for bar in rows:
        groups[bar.epoch - (bar.epoch % M15_SECONDS)].append(bar)
    result: list[Bar] = []
    invalid = 0
    for bucket in sorted(groups):
        parts = sorted(groups[bucket], key=lambda row: row.epoch)
        if [row.epoch for row in parts] != [bucket, bucket + M5_SECONDS, bucket + 2 * M5_SECONDS]:
            invalid += 1
            continue
        result.append(
            Bar(
                epoch=bucket,
                open=parts[0].open,
                high=max(row.high for row in parts),
                low=min(row.low for row in parts),
                close=parts[-1].close,
                tickvol=sum(row.tickvol for row in parts),
            )
        )
    return result, invalid


def is_pivot(bars: Sequence[Bar], index: int, kind: str) -> bool:
    if index <= 0 or index >= len(bars) - 1:
        return False
    left, center, right = bars[index - 1], bars[index], bars[index + 1]
    if center.epoch - left.epoch != M15_SECONDS or right.epoch - center.epoch != M15_SECONDS:
        return False
    if kind == "high":
        return center.high > left.high and center.high > right.high
    if kind == "low":
        return center.low < left.low and center.low < right.low
    raise ValueError(kind)


def most_recent_pivot(bars: Sequence[Bar], before_index: int, close_epoch: int, kind: str) -> float | None:
    for index in range(before_index - 1, 0, -1):
        if bars[index].epoch >= bars[before_index].epoch:
            continue
        if bars[index + 1].epoch + M15_SECONDS > close_epoch:
            continue
        if is_pivot(bars, index, kind):
            return bars[index].high if kind == "high" else bars[index].low
    return None


def choose_pool(candidates: Sequence[tuple[str, float | None]], anchor: float, direction: str) -> float | None:
    priority = {"ASIA": 0, "PD": 1, "PIVOT": 2}
    eligible: list[tuple[float, int, float]] = []
    seen_prices: set[float] = set()
    for source, raw in candidates:
        if raw is None or not math.isfinite(raw) or raw in seen_prices:
            continue
        seen_prices.add(raw)
        if direction == "below" and raw < anchor:
            eligible.append((anchor - raw, priority[source], raw))
        elif direction == "above" and raw > anchor:
            eligible.append((raw - anchor, priority[source], raw))
    return min(eligible)[2] if eligible else None


def nearest_target(candidates: Iterable[float], entry: float, side: str) -> float | None:
    if side == "long":
        rows = [value for value in candidates if value > entry]
        return min(rows) if rows else None
    rows = [value for value in candidates if value < entry]
    return max(rows) if rows else None


def atr_sma_tr14(bars: Sequence[Bar], through_index: int) -> float | None:
    if through_index < 14:
        return None
    trs: list[float] = []
    for index in range(through_index - 13, through_index + 1):
        bar = bars[index]
        prior_close = bars[index - 1].close
        trs.append(max(bar.high - bar.low, abs(bar.high - prior_close), abs(bar.low - prior_close)))
    return sum(trs) / 14.0


def find_mss_index(
    bars: Sequence[Bar],
    by_epoch: Mapping[int, int],
    sweep_index: int,
    level: float,
    side: str,
    cutoff: datetime,
) -> int | None:
    """Return the first strict pivot break in post-sweep bars #1..#8."""
    for step in range(1, 9):
        epoch = bars[sweep_index].epoch + step * M15_SECONDS
        index = by_epoch.get(epoch)
        if index is None or bars[index].close_dt > cutoff:
            break
        if (side == "long" and bars[index].close > level) or (
            side == "short" and bars[index].close < level
        ):
            return index
    return None


def find_post_mss_fvg_index(
    bars: Sequence[Bar],
    by_epoch: Mapping[int, int],
    mss_index: int,
    side: str,
    cutoff: datetime,
) -> int | None:
    """Return C of the first strict FVG whose A/B/C are wholly post-MSS."""
    a_epoch = bars[mss_index].epoch + M15_SECONDS
    while True:
        triple = [by_epoch.get(a_epoch + offset * M15_SECONDS) for offset in range(3)]
        if any(index is None for index in triple):
            return None
        a_index, _b_index, c_index = (int(index) for index in triple)
        if bars[c_index].close_dt >= cutoff:
            return None
        if (side == "long" and bars[a_index].high < bars[c_index].low) or (
            side == "short" and bars[a_index].low > bars[c_index].high
        ):
            return c_index
        a_epoch += M15_SECONDS


def find_virtual_limit_result(
    bars: Sequence[Bar],
    by_epoch: Mapping[int, int],
    symbol: str,
    side: str,
    entry: float,
    arm_time: datetime,
    deadline: datetime,
    blackouts: Blackouts,
) -> tuple[str, int | None]:
    """Apply exclusive expiry/cutoff before examining each possible touch bar."""
    epoch = int(arm_time.replace(tzinfo=timezone.utc).timestamp())
    while datetime.fromtimestamp(epoch, timezone.utc).replace(tzinfo=None) < deadline:
        index = by_epoch.get(epoch)
        if index is None:
            return "DATA_GAP", None
        bar = bars[index]
        if touched(bar, entry, side):
            if blackouts.overlaps(symbol, bar.dt, bar.close_dt):
                return "NEWS_TOUCH_VOID", index
            return "FILLED", index
        epoch += M15_SECONDS
    return "EXPIRED", None


def touched(bar: Bar, price: float, side: str) -> bool:
    return bar.low <= price if side == "long" else bar.high >= price


def stop_touched(bar: Bar, stop: float, side: str) -> bool:
    return bar.low <= stop if side == "long" else bar.high >= stop


def target_touched(bar: Bar, target: float, side: str) -> bool:
    return bar.high >= target if side == "long" else bar.low <= target


def deal_commission(volume: Decimal, price: Decimal) -> Decimal:
    value = max(Decimal("2.5") * volume * price, Decimal("2.5") * volume)
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def complete_trade(
    symbol: str,
    side: str,
    day_key: date,
    bars: Sequence[Bar],
    by_epoch: Mapping[int, int],
    fill_index: int,
    entry: float,
    stop: float,
    tp1: float,
    tp3: float,
    ambiguity: Counter[str],
    integrity: list[str],
) -> Trade | None:
    risk = abs(entry - stop)
    lots = float(RISK_USD / (Decimal(str(risk)) * Decimal("100000")))
    volume = Decimal(str(lots))
    commissions = deal_commission(volume, Decimal(str(entry)))
    realized_r = 0.0
    remaining = 1.0
    partial = False
    exit_reason = ""
    exit_time: datetime | None = None

    fill_bar = bars[fill_index]
    favorable_on_fill = target_touched(fill_bar, tp1, side) or target_touched(fill_bar, tp3, side)
    if stop_touched(fill_bar, stop, side):
        if favorable_on_fill:
            ambiguity["FILL_BAR_STOP_AND_TARGET_STOP_FIRST"] += 1
        ambiguity["FILL_BAR_STOP"] += 1
        realized_r = -1.0
        commissions += deal_commission(volume, Decimal(str(stop)))
        exit_reason = "STOP_FILL_BAR"
        exit_time = fill_bar.close_dt
        remaining = 0.0
    elif favorable_on_fill:
        ambiguity["FILL_BAR_FAVORABLE_IGNORED"] += 1

    flat_epoch = int(datetime.combine(day_key, time(17, 0), tzinfo=timezone.utc).timestamp())
    if remaining > 0:
        expected = fill_bar.epoch + M15_SECONDS
        while expected < flat_epoch:
            index = by_epoch.get(expected)
            if index is None:
                issue = f"{symbol} {day_key}: missing M15 while position open at {datetime.fromtimestamp(expected, timezone.utc)}"
                integrity.append(issue)
                return None
            bar = bars[index]
            stop_hit = stop_touched(bar, stop, side)
            tp1_hit = (not partial) and target_touched(bar, tp1, side)
            tp3_hit = target_touched(bar, tp3, side)
            if stop_hit:
                if tp1_hit or tp3_hit:
                    ambiguity["LATER_BAR_STOP_AND_TARGET_STOP_FIRST"] += 1
                realized_r -= remaining
                commissions += deal_commission(volume * Decimal(str(remaining)), Decimal(str(stop)))
                remaining = 0.0
                exit_reason = "STOP_AFTER_TP1" if partial else "STOP"
                exit_time = bar.close_dt
                break
            if tp1_hit:
                tp1_r = abs(tp1 - entry) / risk
                realized_r += 0.5 * tp1_r
                commissions += deal_commission(volume * Decimal("0.5"), Decimal(str(tp1)))
                remaining = 0.5
                partial = True
                if tp3_hit:
                    ambiguity["TP1_AND_TP3_SAME_BAR"] += 1
                    realized_r += 0.5 * 3.0
                    commissions += deal_commission(volume * Decimal("0.5"), Decimal(str(tp3)))
                    remaining = 0.0
                    exit_reason = "TP1_TP3"
                    exit_time = bar.close_dt
                    break
            elif partial and tp3_hit:
                realized_r += 0.5 * 3.0
                commissions += deal_commission(volume * Decimal("0.5"), Decimal(str(tp3)))
                remaining = 0.0
                exit_reason = "TP3_AFTER_TP1"
                exit_time = bar.close_dt
                break
            expected += M15_SECONDS

    if remaining > 0:
        flat_index = by_epoch.get(flat_epoch)
        if flat_index is not None:
            flat_price = bars[flat_index].open
            exit_time = bars[flat_index].dt
            exit_reason = "HARD_FLAT_AFTER_TP1" if partial else "HARD_FLAT"
        else:
            prior_index: int | None = None
            probe = flat_epoch - M15_SECONDS
            while probe >= fill_bar.epoch:
                prior_index = by_epoch.get(probe)
                if prior_index is not None:
                    break
                probe -= M15_SECONDS
            if prior_index is None:
                integrity.append(f"{symbol} {day_key}: no price for 17:00 forced flat")
                return None
            prior = bars[prior_index]
            flat_price = prior.close
            exit_time = datetime.combine(day_key, time(17, 0))
            exit_reason = "DATA_FORCED_FLAT_AFTER_TP1" if partial else "DATA_FORCED_FLAT"
            ambiguity["DATA_FORCED_FLAT"] += 1
        move_r = ((flat_price - entry) / risk) if side == "long" else ((entry - flat_price) / risk)
        realized_r += remaining * move_r
        commissions += deal_commission(volume * Decimal(str(remaining)), Decimal(str(flat_price)))
        remaining = 0.0

    adjusted = realized_r - float(commissions / RISK_USD)
    return Trade(
        symbol=symbol,
        side=side,
        day=day_key.isoformat(),
        entry_time=fill_bar.dt.isoformat(sep=" "),
        exit_time=(exit_time or fill_bar.close_dt).isoformat(sep=" "),
        entry=entry,
        stop=stop,
        tp1=tp1,
        tp3=tp3,
        risk_price=risk,
        lots=lots,
        gross_r=realized_r,
        commission_usd=float(commissions),
        adjusted_r=adjusted,
        exit_reason=exit_reason,
        partial_done=partial,
    )


def evaluate_symbol(
    symbol: str,
    rows: Sequence[Bar],
    identity: InputIdentity,
    blackouts: Blackouts,
) -> SymbolResult:
    bars, invalid_groups = aggregate_m15(rows)
    by_epoch = {bar.epoch: index for index, bar in enumerate(bars)}
    day_indices: dict[date, list[int]] = defaultdict(list)
    for index, bar in enumerate(bars):
        day_indices[bar.dt.date()].append(index)
    ordered_dates = sorted(day_indices)
    previous_date: dict[date, date | None] = {}
    prior: date | None = None
    for current in ordered_dates:
        previous_date[current] = prior
        prior = current

    funnel: Counter[str] = Counter()
    terminal: Counter[str] = Counter()
    ambiguity: Counter[str] = Counter()
    trades: list[Trade] = []
    integrity: list[str] = []

    def finish(code: str) -> None:
        terminal[code] += 1

    for day_key in ordered_dates:
        if day_key < START.date() or day_key >= END.date():
            continue
        funnel["DAY_OBSERVED"] += 1
        indices = day_indices[day_key]
        date_map = {bars[index].dt.time(): index for index in indices}
        asia_times = [(datetime.combine(day_key, time(1, 0)) + timedelta(minutes=15 * n)).time() for n in range(32)]
        london_times = [(datetime.combine(day_key, time(9, 0)) + timedelta(minutes=15 * n)).time() for n in range(12)]
        if any(value not in date_map for value in asia_times):
            finish("ASIA_INCOMPLETE")
            continue
        funnel["ASIA_COMPLETE"] += 1
        if any(value not in date_map for value in london_times):
            finish("LONDON_INCOMPLETE")
            continue
        funnel["LONDON_COMPLETE"] += 1
        pd_date = previous_date[day_key]
        if pd_date is None:
            finish("PD_INCOMPLETE")
            continue
        pd_bars = [bars[index] for index in day_indices[pd_date]]
        pdh = max(bar.high for bar in pd_bars)
        pdl = min(bar.low for bar in pd_bars)
        asia_bars = [bars[date_map[value]] for value in asia_times]
        asia_high = max(bar.high for bar in asia_bars)
        asia_low = min(bar.low for bar in asia_bars)
        anchor_index = date_map[time(8, 45)]
        anchor = bars[anchor_index].close
        # anchor is the 08:45 bar and closes exactly at the 09:00 freeze.  The
        # sorted series therefore makes the preceding window a bounded slice;
        # rescanning the entire history per day would be quadratic.
        centers = range(max(0, anchor_index - 95), anchor_index + 1)
        pool_freeze = datetime.combine(day_key, time(9, 0))
        pivot_lows = [
            bars[index].low
            for index in centers
            if index + 1 < len(bars)
            and bars[index + 1].close_dt <= pool_freeze
            and is_pivot(bars, index, "low")
        ]
        pivot_highs = [
            bars[index].high
            for index in centers
            if index + 1 < len(bars)
            and bars[index + 1].close_dt <= pool_freeze
            and is_pivot(bars, index, "high")
        ]
        pivot_low = min(pivot_lows) if pivot_lows else None
        pivot_high = max(pivot_highs) if pivot_highs else None
        pool_low = choose_pool([("ASIA", asia_low), ("PD", pdl), ("PIVOT", pivot_low)], anchor, "below")
        pool_high = choose_pool([("ASIA", asia_high), ("PD", pdh), ("PIVOT", pivot_high)], anchor, "above")
        if pool_low is None or pool_high is None:
            finish("POOL_INCOMPLETE")
            continue
        funnel["POOLS_FROZEN"] += 1

        sweep_index: int | None = None
        side: str | None = None
        for value in london_times:
            index = date_map[value]
            bar = bars[index]
            long_sweep = bar.low < pool_low and bar.close > pool_low
            short_sweep = bar.high > pool_high and bar.close < pool_high
            if long_sweep and short_sweep:
                funnel["SWEEP_CONSUMED"] += 1
                finish("DUAL_SWEEP_VOID")
                sweep_index = -1
                break
            if long_sweep or short_sweep:
                sweep_index = index
                side = "long" if long_sweep else "short"
                funnel["SWEEP_CONSUMED"] += 1
                funnel[f"SWEEP_{side.upper()}"] += 1
                break
        if sweep_index == -1:
            continue
        if sweep_index is None or side is None:
            finish("NO_SWEEP")
            continue

        pivot_kind = "high" if side == "long" else "low"
        mss_level = most_recent_pivot(bars, sweep_index, bars[sweep_index].epoch + M15_SECONDS, pivot_kind)
        if mss_level is None:
            finish("NO_MSS_REFERENCE_PIVOT")
            continue
        funnel["MSS_REFERENCE_FROZEN"] += 1
        mss_index = find_mss_index(
            bars,
            by_epoch,
            sweep_index,
            mss_level,
            side,
            datetime.combine(day_key, time(12, 0)),
        )
        if mss_index is None:
            finish("NO_MSS_WITHIN_8")
            continue
        funnel["MSS_CONFIRMED"] += 1

        fvg_index = find_post_mss_fvg_index(
            bars,
            by_epoch,
            mss_index,
            side,
            datetime.combine(day_key, time(12, 0)),
        )
        if fvg_index is None:
            finish("NO_STRICT_POST_MSS_FVG")
            continue
        funnel["EARLIEST_FVG_LATCHED"] += 1
        c_bar = bars[fvg_index]
        arm_time = c_bar.close_dt
        if blackouts.overlaps(symbol, arm_time, arm_time):
            finish("NEWS_ARM_VOID")
            continue
        funnel["NEWS_ARM_PASS"] += 1
        a_index = fvg_index - 2
        if side == "long":
            entry = (bars[a_index].high + c_bar.low) / 2.0
            if not c_bar.close > entry:
                finish("EARLIEST_FVG_NOT_LIMIT_VOID")
                continue
        else:
            entry = (bars[a_index].low + c_bar.high) / 2.0
            if not c_bar.close < entry:
                finish("EARLIEST_FVG_NOT_LIMIT_VOID")
                continue
        atr = atr_sma_tr14(bars, fvg_index)
        if atr is None or atr <= 0:
            finish("ATR_INCOMPLETE")
            continue
        sweep_extreme = bars[sweep_index].low if side == "long" else bars[sweep_index].high
        stop = sweep_extreme - 0.3 * atr if side == "long" else sweep_extreme + 0.3 * atr
        risk = abs(entry - stop)
        if risk <= 0 or (side == "long" and stop >= entry) or (side == "short" and stop <= entry):
            finish("INVALID_DIRECTIONAL_RISK")
            continue
        if risk > 2.5 * atr:
            finish("RISK_GT_2_5_ATR")
            continue
        target_pool = nearest_target([asia_high, pdh] if side == "long" else [asia_low, pdl], entry, side)
        if target_pool is None:
            finish("NO_OPPOSITE_TARGET")
            continue
        rr2 = entry + 2.0 * risk if side == "long" else entry - 2.0 * risk
        tp1 = min(target_pool, rr2) if side == "long" else max(target_pool, rr2)
        if (side == "long" and tp1 <= entry) or (side == "short" and tp1 >= entry):
            finish("INVALID_OPPOSITE_TARGET")
            continue
        tp3 = entry + 3.0 * risk if side == "long" else entry - 3.0 * risk
        funnel["VIRTUAL_LIMIT_ARMED"] += 1

        deadline = min(arm_time + timedelta(minutes=120), datetime.combine(day_key, time(12, 0)))
        limit_result, fill_index = find_virtual_limit_result(
            bars,
            by_epoch,
            symbol,
            side,
            entry,
            arm_time,
            deadline,
            blackouts,
        )
        if limit_result == "NEWS_TOUCH_VOID":
            funnel["VIRTUAL_LIMIT_TOUCHED"] += 1
            finish("NEWS_TOUCH_VOID")
            continue
        if limit_result == "DATA_GAP":
            integrity.append(f"{symbol} {day_key}: M15 gap while virtual limit armed")
            finish("VIRTUAL_LIMIT_DATA_INVALID")
            continue
        if limit_result == "EXPIRED" or fill_index is None:
            finish("VIRTUAL_LIMIT_EXPIRED")
            continue
        funnel["VIRTUAL_LIMIT_TOUCHED"] += 1
        funnel["FILLED"] += 1
        trade = complete_trade(
            symbol,
            side,
            day_key,
            bars,
            by_epoch,
            fill_index,
            entry,
            stop,
            tp1,
            tp3,
            ambiguity,
            integrity,
        )
        if trade is None:
            finish("FILLED_DATA_INVALID")
            continue
        trades.append(trade)
        finish(f"FILLED_{trade.exit_reason}")

    return SymbolResult(
        symbol=symbol,
        input_identity=identity,
        m5_rows=len(rows),
        m15_bars=len(bars),
        m15_invalid_groups=invalid_groups,
        funnel=funnel,
        terminal=terminal,
        ambiguity=ambiguity,
        trades=trades,
        integrity_issues=integrity,
    )


def profit_factor(values: Sequence[float]) -> float | None:
    positive = sum(value for value in values if value > 0)
    negative = -sum(value for value in values if value < 0)
    if negative == 0:
        return None
    return positive / negative


def max_drawdown(values: Sequence[float]) -> float:
    equity = 0.0
    peak = 0.0
    drawdown = 0.0
    for value in values:
        equity += value
        peak = max(peak, equity)
        drawdown = max(drawdown, peak - equity)
    return drawdown


def metrics(trades: Sequence[Trade]) -> dict[str, Any]:
    adjusted = [trade.adjusted_r for trade in trades]
    gross = [trade.gross_r for trade in trades]
    winners = sorted((value for value in adjusted if value > 0), reverse=True)
    gross_wins = sum(winners)
    top_one = winners[0] / gross_wins if winners and gross_wins else None
    top_two = sum(winners[:2]) / gross_wins if winners and gross_wins else None
    return {
        "fills": len(trades),
        "gross_net_r": sum(gross),
        "gross_pf": profit_factor(gross),
        "commission_usd": sum(trade.commission_usd for trade in trades),
        "adjusted_net_r": sum(adjusted),
        "adjusted_pf": profit_factor(adjusted),
        "adjusted_expectancy_r": mean(adjusted) if adjusted else None,
        "adjusted_median_r": median(adjusted) if adjusted else None,
        "win_rate": sum(value > 0 for value in adjusted) / len(adjusted) if adjusted else None,
        "max_adjusted_drawdown_r": max_drawdown(adjusted),
        "top_one_winner_share": top_one,
        "top_two_winner_share": top_two,
        "leave_best_out_adjusted_net_r": sum(adjusted) - max(adjusted) if adjusted else None,
    }


def grouped_metrics(trades: Sequence[Trade], key_fn: Any) -> dict[str, dict[str, Any]]:
    groups: dict[str, list[Trade]] = defaultdict(list)
    for trade in trades:
        groups[str(key_fn(trade))].append(trade)
    return {key: metrics(rows) for key, rows in sorted(groups.items())}


def evaluate_merit(all_trades: Sequence[Trade], integrity_pass: bool) -> dict[str, Any]:
    pooled = metrics(all_trades)
    by_symbol = grouped_metrics(all_trades, lambda trade: trade.symbol)
    by_side = grouped_metrics(all_trades, lambda trade: trade.side)
    by_year = grouped_metrics(all_trades, lambda trade: trade.day[:4])
    checks: dict[str, bool] = {
        "integrity_pass": integrity_pass,
        "pooled_fills_min_80": pooled["fills"] >= 80,
        "fills_per_symbol_min_25": all(by_symbol.get(symbol, {}).get("fills", 0) >= 25 for symbol in ("GBPUSD.DWX", "EURUSD.DWX")),
        "fills_per_side_min_15": all(by_side.get(side, {}).get("fills", 0) >= 15 for side in ("long", "short")),
        "pooled_adjusted_pf_min_1_2": pooled["adjusted_pf"] is not None and pooled["adjusted_pf"] >= 1.2,
        "pooled_adjusted_net_positive": pooled["adjusted_net_r"] > 0,
        "each_symbol_adjusted_net_positive": all(by_symbol.get(symbol, {}).get("adjusted_net_r", 0) > 0 for symbol in ("GBPUSD.DWX", "EURUSD.DWX")),
        "each_side_adjusted_net_positive": all(by_side.get(side, {}).get("adjusted_net_r", 0) > 0 for side in ("long", "short")),
        "pooled_positive_full_years_min_3": sum(by_year.get(str(year), {}).get("adjusted_net_r", 0) > 0 for year in range(2018, 2023)) >= 3,
        "each_symbol_positive_full_years_min_2": all(
            sum(
                sum(trade.adjusted_r for trade in all_trades if trade.symbol == symbol and trade.day.startswith(str(year))) > 0
                for year in range(2018, 2023)
            ) >= 2
            for symbol in ("GBPUSD.DWX", "EURUSD.DWX")
        ),
        "pooled_max_drawdown_r_max_10": pooled["max_adjusted_drawdown_r"] <= 10.0,
        "top_two_winner_share_max_0_5": pooled["top_two_winner_share"] is not None and pooled["top_two_winner_share"] <= 0.5,
        "leave_best_out_positive": pooled["leave_best_out_adjusted_net_r"] is not None and pooled["leave_best_out_adjusted_net_r"] > 0,
    }
    return {
        "decision": "MERIT" if all(checks.values()) else "NO_MERIT",
        "checks": checks,
        "failed": [name for name, passed in checks.items() if not passed],
    }


def result_document(
    contract_path: Path,
    news_identity: Mapping[str, Any],
    results: Sequence[SymbolResult],
) -> dict[str, Any]:
    all_trades = sorted(
        (trade for result in results for trade in result.trades),
        key=lambda trade: (trade.exit_time, trade.symbol),
    )
    integrity_issues = [issue for result in results for issue in result.integrity_issues]
    integrity_pass = not integrity_issues
    return {
        "schema_version": 1,
        "candidate_id": "QM5_20009_V6_LONDON_KZ_CABLE_SWEEP_001",
        "status": "DEV_OFFLINE_MECHANISM_SCREEN",
        "admissibility": "NOT_PIPELINE_NOT_QUALIFICATION_NOT_FTMO_NOT_LIVE",
        "identity": {
            "contract_commit": CONTRACT_COMMIT,
            "contract_path": str(contract_path),
            "contract_sha256": sha256_file(contract_path),
            "tool_path": str(TOOL_PATH),
            "tool_sha256": sha256_file(TOOL_PATH),
            "news": news_identity,
            "market": {result.symbol: vars(result.input_identity) for result in results},
            "outcome_fence": "No OHLC field at or after 2023-01-01 was parsed.",
        },
        "integrity": {
            "status": "PASS" if integrity_pass else "FAIL",
            "issues": integrity_issues,
            "m15_invalid_groups": {result.symbol: result.m15_invalid_groups for result in results},
        },
        "funnel": {result.symbol: dict(sorted(result.funnel.items())) for result in results},
        "terminal_states": {result.symbol: dict(sorted(result.terminal.items())) for result in results},
        "same_bar_and_proxy_ordering": {result.symbol: dict(sorted(result.ambiguity.items())) for result in results},
        "performance": {
            "pooled": metrics(all_trades),
            "by_symbol": grouped_metrics(all_trades, lambda trade: trade.symbol),
            "by_year": grouped_metrics(all_trades, lambda trade: trade.day[:4]),
            "by_side": grouped_metrics(all_trades, lambda trade: trade.side),
            "by_symbol_year": grouped_metrics(all_trades, lambda trade: f"{trade.symbol}:{trade.day[:4]}"),
            "by_symbol_side": grouped_metrics(all_trades, lambda trade: f"{trade.symbol}:{trade.side}"),
        },
        "merit": evaluate_merit(all_trades, integrity_pass),
        "trades": [vars(trade) for trade in all_trades],
        "limitations": [
            "Single-price OHLC proxy cannot recover historical bid/ask spread or slippage.",
            "Commission is externally applied dealwise under the preregistered DXZ/FTMO worst-case rule.",
            "Conservative M15 same-bar ordering is a lower-bound proxy, not tick execution.",
            "2017 is partial; only 2018-2022 count toward annual-stability gates.",
        ],
    }


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    parser.add_argument("--data-root", type=Path, default=DEFAULT_DATA_ROOT)
    parser.add_argument("--news", type=Path, default=DEFAULT_NEWS)
    parser.add_argument("--output", type=Path)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        if sha256_file(args.contract) != EXPECTED_CONTRACT_SHA256:
            raise AuditError("contract differs from preregistered SHA256")
        contract = json.loads(args.contract.read_text(encoding="utf-8"))
        if contract.get("candidate_id") != "QM5_20009_V6_LONDON_KZ_CABLE_SWEEP_001":
            raise AuditError("candidate id drift")
        blackouts, news_identity = load_news(args.news)
        results: list[SymbolResult] = []
        for symbol in ("GBPUSD.DWX", "EURUSD.DWX"):
            path = args.data_root / f"{symbol}_M5.csv"
            rows, identity = load_selected_m5(path)
            results.append(evaluate_symbol(symbol, rows, identity, blackouts))
        document = result_document(args.contract, news_identity, results)
        payload = json.dumps(document, indent=2, sort_keys=True, allow_nan=False) + "\n"
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(payload, encoding="utf-8", newline="\n")
        else:
            sys.stdout.write(payload)
        return 0 if document["integrity"]["status"] == "PASS" else 2
    except (AuditError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"REJECT: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
