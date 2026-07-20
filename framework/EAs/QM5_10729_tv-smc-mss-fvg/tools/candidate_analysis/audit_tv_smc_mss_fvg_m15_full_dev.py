#!/usr/bin/env python3
"""Exact, contract-bound offline full-DEV audit for QM5_10729.

The loader stops after reading only the timestamp prefix of the first row at
or after 2023-01-01.  All decision-bearing arithmetic uses ``Fraction``;
integer-cent deal commissions are the sole rounded quantities.
"""

from __future__ import annotations

import argparse
import bisect
import csv
import hashlib
import json
import os
import tempfile
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
from fractions import Fraction
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]
EVIDENCE_ROOT = EA_ROOT / "docs" / "candidate-analysis"
CONTRACT_PATH = EVIDENCE_ROOT / "tv_smc_mss_fvg_m15_two_symbol_full_dev_contract.json"
REVIEW_PATH = EVIDENCE_ROOT / "tv_smc_mss_fvg_outcome_blind_review_receipt.json"
EXPECTED_CONTRACT_SHA256 = "0b221d1c79dce4a4fef0aa635de957296511e1fc945523e8a4da556c13311d25"
EXPECTED_REVIEW_SHA256 = "2d009fa440a125514d3d6109ae00d91be295c1b052d53e9e47b5ee9121358d99"
CONTRACT_COMMIT = "3886f15e756b622f0b9cc9f9e1890bce173d653d"
ANALYSIS_ID = "QM5_10729_TV_SMC_MSS_FVG_M15_TWO_SYMBOL_FULL_DEV_001"

DEFAULT_OUTPUT = EVIDENCE_ROOT / "tv_smc_mss_fvg_m15_two_symbol_full_dev_result.json"
DEFAULT_REPORT = EVIDENCE_ROOT / "tv_smc_mss_fvg_m15_two_symbol_full_dev_report.md"
DEFAULT_NEWS_PATH = Path(r"D:\QM\data\news_calendar\news_calendar_2015_2025.csv")

EPOCH = datetime(1970, 1, 1)
UTC_EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)
START_EPOCH = int((datetime(2018, 1, 1) - EPOCH).total_seconds())
END_EPOCH = int((datetime(2023, 1, 1) - EPOCH).total_seconds())
M5_SECONDS = 300
M15_SECONDS = 900
FULL_YEARS = (2019, 2020, 2021, 2022)
ANALYSIS_YEARS = (2018, 2019, 2020, 2021, 2022)
SCENARIOS = ("CENTER", "ADVERSE")
SYMBOLS = ("EURUSD.DWX", "XAUUSD.DWX")
SESSIONS = ("LONDON_LABEL", "NEW_YORK_LABEL")
SIDES = ("LONG", "SHORT")
RISK_USD = Fraction(1000)

SYMBOL_SPEC: dict[str, dict[str, Any]] = {
    "EURUSD.DWX": {
        "source_period": 5,
        "value_per_price_lot": Fraction(100000),
        "point": Fraction(1, 100000),
        "center_points": 4,
        "adverse_points": 8,
        "expected_all_rows": 391732,
        "expected_selected_rows": 373203,
        "expected_m15_rows": 123943,
        "expected_partial_buckets": 704,
        "expected_first_excluded": "2023-01-02T00:05:00",
    },
    "XAUUSD.DWX": {
        "source_period": 15,
        "value_per_price_lot": Fraction(100),
        "point": Fraction(1, 100),
        "center_points": 59,
        "adverse_points": 118,
        "expected_all_rows": 118159,
        "expected_selected_rows": 118159,
        "expected_m15_rows": 118159,
        "expected_partial_buckets": 0,
        "expected_first_excluded": "2023-01-03T01:00:00",
    },
}


class AuditError(RuntimeError):
    """Fail-closed contract or data-integrity error."""


class DataIntegrityError(AuditError):
    """A released market path cannot support an unambiguous simulation."""


@dataclass(frozen=True)
class Bar:
    timestamp: int
    open: Fraction
    high: Fraction
    low: Fraction
    close: Fraction
    tickvol: int


@dataclass(frozen=True)
class MarketIdentity:
    path: str
    source_period: str
    raw_slice_sha256: str
    canonical_m15_sha256: str
    all_rows_before_2023: int
    selected_raw_rows: int
    m15_rows: int
    incomplete_m15_buckets: int
    first_selected_raw_time: str
    last_selected_raw_time: str
    first_m15_time: str
    last_m15_time: str
    first_excluded_timestamp: str
    future_ohlc_parsed: bool


@dataclass(frozen=True)
class MarketSlice:
    symbol: str
    bars: tuple[Bar, ...]
    identity: MarketIdentity


@dataclass(frozen=True)
class Signal:
    index: int
    direction: int
    session: str
    structural_id: str


@dataclass
class Position:
    symbol: str
    scenario: str
    direction: int
    session: str
    structural_id: str
    entry_timestamp: int
    entry: Fraction
    stop: Fraction
    target: Fraction
    lots: Fraction
    entry_commission_cents: int
    expected_next_open: int
    flat_timestamp: int


@dataclass(frozen=True)
class Trade:
    trade_id: str
    scenario: str
    symbol: str
    session: str
    side: str
    structural_id: str
    entry_timestamp: int
    exit_timestamp: int
    entry: Fraction
    stop: Fraction
    target: Fraction
    exit_price: Fraction
    lots: Fraction
    gross_usd: Fraction
    gross_r: Fraction
    entry_commission_cents: int
    exit_commission_cents: int
    commission_cents: int
    adjusted_usd: Fraction
    adjusted_r: Fraction
    exit_reason: str
    same_bar_sl_tp_conflict: bool


@dataclass(frozen=True)
class Metric:
    trades: int
    gross_net_r: Fraction
    gross_profit_r: Fraction
    gross_loss_r: Fraction
    adjusted_net_r: Fraction
    adjusted_profit_r: Fraction
    adjusted_loss_r: Fraction
    external_commission_cents: int
    adjusted_expectancy_r: Fraction | None
    adjusted_pf: Fraction | str | None
    gross_pf: Fraction | str | None
    adjusted_win_rate: Fraction | None
    max_closed_balance_dd_r: Fraction
    worst_closed_day_r: Fraction
    top_two_winner_share: Fraction | None
    leave_best_trade_r: Fraction
    leave_best_year_r: Fraction
    positive_full_years: int
    yearly: Mapping[str, Fraction]
    same_bar_conflicts: int
    exit_reasons: Mapping[str, int]
    cost_burden: Fraction | None
    max_concurrent_positions: int


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def epoch_to_datetime(value: int) -> datetime:
    return EPOCH + timedelta(seconds=value)


def stamp_epoch(value: int) -> str:
    return epoch_to_datetime(value).isoformat(timespec="seconds")


def fraction_text(value: Fraction) -> str:
    return f"{value.numerator}/{value.denominator}"


def decimal_text(value: Fraction) -> str:
    """Canonical non-exponent decimal for terminating base-10 fractions."""
    numerator = value.numerator
    denominator = value.denominator
    twos = 0
    fives = 0
    while denominator % 2 == 0:
        denominator //= 2
        twos += 1
    while denominator % 5 == 0:
        denominator //= 5
        fives += 1
    if denominator != 1:
        raise AuditError(f"non-terminating decimal requested: {value}")
    scale = max(twos, fives)
    scaled = numerator * (2 ** (scale - fives)) * (5 ** (scale - twos))
    sign = "-" if scaled < 0 else ""
    digits = str(abs(scaled))
    if scale == 0:
        return sign + digits
    digits = digits.rjust(scale + 1, "0")
    rendered = sign + digits[:-scale] + "." + digits[-scale:]
    rendered = rendered.rstrip("0").rstrip(".")
    return "0" if rendered in {"-0", ""} else rendered


def parse_decimal(raw: str, row_number: int, field: str) -> Fraction:
    try:
        value = Decimal(raw)
    except InvalidOperation as exc:
        raise DataIntegrityError(f"row {row_number}: invalid {field}") from exc
    if not value.is_finite():
        raise DataIntegrityError(f"row {row_number}: non-finite {field}")
    return Fraction(value)


def round_half_up_cents(value_usd: Fraction) -> int:
    if value_usd < 0:
        raise AuditError("commission cannot be negative")
    scaled = value_usd * 100
    quotient, remainder = divmod(scaled.numerator, scaled.denominator)
    return quotient + (1 if 2 * remainder >= scaled.denominator else 0)


def _read_timestamp_prefix(handle: Any, row_number: int) -> bytes | None:
    prefix = bytearray()
    while True:
        current = handle.read(1)
        if not current:
            if not prefix:
                return None
            raise DataIntegrityError(f"row {row_number}: truncated timestamp prefix")
        if current == b",":
            if not prefix:
                raise DataIntegrityError(f"row {row_number}: empty timestamp")
            return bytes(prefix)
        if current in {b"\r", b"\n"}:
            raise DataIntegrityError(f"row {row_number}: missing comma after timestamp")
        prefix.extend(current)
        if len(prefix) > 32:
            raise DataIntegrityError(f"row {row_number}: timestamp prefix too long")


def _parse_bar(timestamp: int, raw_tail: bytes, row_number: int) -> Bar:
    try:
        tail = raw_tail.rstrip(b"\r\n").decode("utf-8")
    except UnicodeDecodeError as exc:
        raise DataIntegrityError(f"row {row_number}: non-UTF8 market row") from exc
    parts = tail.split(",")
    if len(parts) != 5:
        raise DataIntegrityError(f"row {row_number}: expected five row-tail fields")
    open_, high, low, close = (
        parse_decimal(raw, row_number, field)
        for raw, field in zip(parts[:4], ("open", "high", "low", "close"))
    )
    try:
        tickvol = int(parts[4])
    except ValueError as exc:
        raise DataIntegrityError(f"row {row_number}: invalid tickvol") from exc
    if (
        min(open_, high, low, close) <= 0
        or low > min(open_, close)
        or max(open_, close) > high
        or low > high
        or tickvol < 0
    ):
        raise DataIntegrityError(f"row {row_number}: invalid OHLC/tickvol")
    return Bar(timestamp, open_, high, low, close, tickvol)


def canonical_m15_bytes(bar: Bar) -> bytes:
    return (
        "{"
        f'"time":{bar.timestamp},'
        f'"open":"{decimal_text(bar.open)}",'
        f'"high":"{decimal_text(bar.high)}",'
        f'"low":"{decimal_text(bar.low)}",'
        f'"close":"{decimal_text(bar.close)}",'
        f'"tickvol":{bar.tickvol}'
        "}\n"
    ).encode("utf-8")


def _aggregate_m15(raw_bars: Sequence[Bar]) -> tuple[list[Bar], int]:
    output: list[Bar] = []
    partial = 0
    bucket: int | None = None
    slots: dict[int, Bar] = {}

    def finish() -> None:
        nonlocal partial
        if bucket is None:
            return
        if set(slots) != {0, 1, 2}:
            partial += 1
            return
        rows = [slots[index] for index in (0, 1, 2)]
        output.append(
            Bar(
                bucket,
                rows[0].open,
                max(row.high for row in rows),
                min(row.low for row in rows),
                rows[2].close,
                sum(row.tickvol for row in rows),
            )
        )

    for bar in raw_bars:
        current_bucket = bar.timestamp - (bar.timestamp % M15_SECONDS)
        slot = (bar.timestamp - current_bucket) // M5_SECONDS
        if bucket is None:
            bucket = current_bucket
        elif current_bucket != bucket:
            finish()
            bucket = current_bucket
            slots = {}
        if slot in slots or slot not in {0, 1, 2}:
            raise DataIntegrityError(f"invalid/duplicate M5 slot at {bar.timestamp}")
        slots[slot] = bar
    finish()
    return output, partial


def parse_market(path: Path, symbol: str, source_period: int) -> MarketSlice:
    if not path.is_file():
        raise AuditError(f"market file missing: {path}")
    raw_digest = hashlib.sha256()
    raw_selected: list[Bar] = []
    prior_timestamp: int | None = None
    first_selected_raw: int | None = None
    last_selected_raw: int | None = None
    first_excluded: int | None = None
    all_rows = 0
    selected_rows = 0
    alignment = M5_SECONDS if source_period == 5 else M15_SECONDS

    with path.open("rb", buffering=0) as handle:
        header = handle.readline().rstrip(b"\r\n")
        if header != b"time,open,high,low,close,tickvol":
            raise DataIntegrityError(f"unexpected header: {header!r}")
        row_number = 2
        while True:
            prefix = _read_timestamp_prefix(handle, row_number)
            if prefix is None:
                break
            try:
                raw_timestamp = prefix.decode("ascii")
                timestamp = int(raw_timestamp)
            except (UnicodeDecodeError, ValueError) as exc:
                raise DataIntegrityError(f"row {row_number}: invalid timestamp") from exc
            if prior_timestamp is not None and timestamp <= prior_timestamp:
                raise DataIntegrityError(f"row {row_number}: timestamps not increasing")
            prior_timestamp = timestamp
            if timestamp >= END_EPOCH:
                first_excluded = timestamp
                break  # Critical: the future OHLC tail remains unread.
            all_rows += 1
            tail = handle.readline()
            if not tail:
                raise DataIntegrityError(f"row {row_number}: missing row tail")
            if timestamp < START_EPOCH:
                row_number += 1
                continue
            if timestamp % alignment != 0:
                raise DataIntegrityError(f"row {row_number}: off-grid timestamp")
            bar = _parse_bar(timestamp, tail, row_number)
            raw_selected.append(bar)
            selected_rows += 1
            first_selected_raw = timestamp if first_selected_raw is None else first_selected_raw
            last_selected_raw = timestamp
            raw_digest.update(prefix + b"," + tail.rstrip(b"\r\n") + b"\n")
            row_number += 1

    if first_excluded is None:
        raise DataIntegrityError("cannot prove future fence: no >=2023 timestamp")
    if not raw_selected or first_selected_raw is None or last_selected_raw is None:
        raise DataIntegrityError("selected market slice is empty")

    if source_period == 5:
        m15, partial = _aggregate_m15(raw_selected)
    elif source_period == 15:
        m15, partial = list(raw_selected), 0
    else:
        raise AuditError(f"unsupported source period: {source_period}")
    if not m15:
        raise DataIntegrityError("constructed M15 slice is empty")
    m15_digest = hashlib.sha256()
    for bar in m15:
        m15_digest.update(canonical_m15_bytes(bar))

    spec = SYMBOL_SPEC[symbol]
    observed = {
        "all": all_rows,
        "selected": selected_rows,
        "m15": len(m15),
        "partial": partial,
        "excluded": stamp_epoch(first_excluded),
    }
    expected = {
        "all": spec["expected_all_rows"],
        "selected": spec["expected_selected_rows"],
        "m15": spec["expected_m15_rows"],
        "partial": spec["expected_partial_buckets"],
        "excluded": spec["expected_first_excluded"],
    }
    if observed != expected:
        raise DataIntegrityError(f"availability drift for {symbol}: {observed} != {expected}")

    return MarketSlice(
        symbol=symbol,
        bars=tuple(m15),
        identity=MarketIdentity(
            path=str(path.resolve()),
            source_period=f"M{source_period}",
            raw_slice_sha256=raw_digest.hexdigest(),
            canonical_m15_sha256=m15_digest.hexdigest(),
            all_rows_before_2023=all_rows,
            selected_raw_rows=selected_rows,
            m15_rows=len(m15),
            incomplete_m15_buckets=partial,
            first_selected_raw_time=stamp_epoch(first_selected_raw),
            last_selected_raw_time=stamp_epoch(last_selected_raw),
            first_m15_time=stamp_epoch(m15[0].timestamp),
            last_m15_time=stamp_epoch(m15[-1].timestamp),
            first_excluded_timestamp=stamp_epoch(first_excluded),
            future_ohlc_parsed=False,
        ),
    )


def _nth_sunday(year: int, month: int, nth: int) -> date:
    cursor = date(year, month, 1)
    seen = 0
    while True:
        if cursor.weekday() == 6:
            seen += 1
            if seen == nth:
                return cursor
        cursor += timedelta(days=1)


def broker_offset_for_utc(value: datetime) -> int:
    if value.tzinfo is None:
        raise AuditError("UTC datetime must be timezone-aware")
    value = value.astimezone(timezone.utc)
    start_day = _nth_sunday(value.year, 3, 2)
    end_day = _nth_sunday(value.year, 11, 1)
    start = datetime(value.year, 3, start_day.day, 7, tzinfo=timezone.utc)
    end = datetime(value.year, 11, end_day.day, 6, tzinfo=timezone.utc)
    return 3 if start <= value < end else 2


def broker_to_utc_epoch(broker_timestamp: int) -> int:
    broker = epoch_to_datetime(broker_timestamp)
    candidate_standard = (broker - timedelta(hours=2)).replace(tzinfo=timezone.utc)
    candidate_dst = (broker - timedelta(hours=3)).replace(tzinfo=timezone.utc)
    if broker_offset_for_utc(candidate_standard) == 2:
        selected = candidate_standard
    elif broker_offset_for_utc(candidate_dst) == 3:
        selected = candidate_dst
    else:
        selected = candidate_standard
    return int((selected - UTC_EPOCH).total_seconds())


def news_affects_symbol(currency: str, symbol: str) -> bool:
    currency = currency.strip().upper().strip('"')
    if not currency or currency == "ALL":
        return True
    normalized = symbol.upper().replace(".DWX", "")
    base = normalized[:3]
    quote = normalized[3:6]
    return base in currency or quote in currency


class NewsBook:
    def __init__(self, events_by_symbol: Mapping[str, Iterable[int]]):
        self.events = {
            symbol: tuple(sorted(events)) for symbol, events in events_by_symbol.items()
        }

    def blocks(self, symbol: str, broker_entry_timestamp: int) -> bool:
        entry_utc = broker_to_utc_epoch(broker_entry_timestamp)
        events = self.events[symbol]
        index = bisect.bisect_left(events, entry_utc - 1800)
        return index < len(events) and events[index] <= entry_utc + 1800


def load_news(path: Path, expected_sha256: str) -> tuple[NewsBook, dict[str, Any]]:
    observed_sha = sha256_file(path)
    if observed_sha != expected_sha256:
        raise AuditError(f"news hash drift: {observed_sha}")
    events_by_symbol: dict[str, list[int]] = {symbol: [] for symbol in SYMBOLS}
    first: datetime | None = None
    last: datetime | None = None
    high_rows = 0
    flag_disagreements = 0
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        required = {"datetime", "currency", "event_name", "impact", "is_high_impact"}
        if not required.issubset(reader.fieldnames or []):
            raise AuditError("news header missing required fields")
        for row_number, row in enumerate(reader, start=2):
            raw_time = (row.get("datetime") or "").strip()
            currency = (row.get("currency") or "").strip().upper()
            event_name = (row.get("event_name") or "").strip()
            impact = (row.get("impact") or "").strip().upper()
            high_flag = (row.get("is_high_impact") or "").strip()
            if not raw_time or not event_name or high_flag not in {"0", "1"}:
                raise AuditError(f"malformed news row {row_number}")
            try:
                event_utc = datetime.strptime(raw_time, "%Y-%m-%d %H:%M:%S").replace(
                    tzinfo=timezone.utc
                )
            except ValueError as exc:
                raise AuditError(f"invalid news timestamp row {row_number}") from exc
            first = event_utc if first is None or event_utc < first else first
            last = event_utc if last is None or event_utc > last else last
            if (impact == "HIGH") != (high_flag == "1"):
                flag_disagreements += 1
            if impact != "HIGH":
                continue
            high_rows += 1
            event_epoch = int((event_utc - UTC_EPOCH).total_seconds())
            for symbol in SYMBOLS:
                if news_affects_symbol(currency, symbol):
                    events_by_symbol[symbol].append(event_epoch)
    if first is None or last is None or first.year > 2018 or last.year < 2022:
        raise AuditError("news calendar does not cover analysis")
    book = NewsBook(events_by_symbol)
    return book, {
        "path": str(path.resolve()),
        "sha256": observed_sha,
        "first_utc": first.isoformat(),
        "last_utc": last.isoformat(),
        "high_impact_rows_by_impact_field": high_rows,
        "impact_flag_disagreements": flag_disagreements,
        "selected_events_by_symbol": {
            symbol: len(book.events[symbol]) for symbol in SYMBOLS
        },
        "matching": "QM_NewsEventAffectsSymbol base/quote plus empty/ALL",
        "blackout": "entry timestamp only, inclusive UTC +/-30 minutes",
    }


def session_for_timestamp(timestamp: int) -> str | None:
    value = epoch_to_datetime(timestamp)
    minute = value.hour * 60 + value.minute
    if 14 * 60 <= minute < 17 * 60:
        return "LONDON_LABEL"
    if 19 * 60 + 30 <= minute < 23 * 60:
        return "NEW_YORK_LABEL"
    return None


def session_end_timestamp(timestamp: int, session: str) -> int:
    value = epoch_to_datetime(timestamp)
    if session == "LONDON_LABEL":
        end = value.replace(hour=17, minute=0, second=0, microsecond=0)
    elif session == "NEW_YORK_LABEL":
        end = value.replace(hour=23, minute=0, second=0, microsecond=0)
    else:
        raise AuditError(f"unknown session {session}")
    return int((end - EPOCH).total_seconds())


def friday_cutoff_timestamp(timestamp: int) -> int | None:
    value = epoch_to_datetime(timestamp)
    if value.weekday() != 4:
        return None
    cutoff = value.replace(hour=21, minute=0, second=0, microsecond=0)
    return int((cutoff - EPOCH).total_seconds())


def generate_signals(
    symbol: str, bars: Sequence[Bar]
) -> tuple[dict[int, Signal], dict[str, int]]:
    signals: dict[int, Signal] = {}
    funnel: Counter[str] = Counter(bars=len(bars))
    last_high: Fraction | None = None
    last_low: Fraction | None = None
    for index, bar in enumerate(bars):
        if index >= 10:
            center = index - 5
            candidate = bars[center]
            neighbors = [*bars[center - 5 : center], *bars[center + 1 : center + 6]]
            if all(candidate.high > other.high for other in neighbors):
                last_high = candidate.high
                funnel["pivot_high_confirmations"] += 1
            if all(candidate.low < other.low for other in neighbors):
                last_low = candidate.low
                funnel["pivot_low_confirmations"] += 1
        if index < 2:
            continue
        bull_sweep = last_low is not None and bar.low < last_low and bar.close > last_low
        bear_sweep = last_high is not None and bar.high > last_high and bar.close < last_high
        if bull_sweep:
            funnel["raw_long_sweep_reclaim"] += 1
        if bear_sweep:
            funnel["raw_short_sweep_reclaim"] += 1
        bull_mss = bull_sweep and bar.close > bars[index - 1].high
        bear_mss = bear_sweep and bar.close < bars[index - 1].low
        if bull_mss:
            funnel["raw_long_same_bar_mss"] += 1
        if bear_mss:
            funnel["raw_short_same_bar_mss"] += 1
        bull_fvg = bar.low > bars[index - 2].high
        bear_fvg = bar.high < bars[index - 2].low
        if bull_fvg:
            funnel["raw_bull_fvg"] += 1
        if bear_fvg:
            funnel["raw_bear_fvg"] += 1
        session = session_for_timestamp(bar.timestamp)
        direction = 1 if bull_mss and bull_fvg else -1 if bear_mss and bear_fvg else 0
        if not direction or session is None:
            continue
        if index in signals:
            raise AuditError(f"both signal directions at {symbol} {bar.timestamp}")
        side = "LONG" if direction > 0 else "SHORT"
        structural_id = f"{symbol}|{bar.timestamp}|{side}"
        signals[index] = Signal(index, direction, session, structural_id)
        funnel[f"complete_source_signal_{side}"] += 1
        funnel[f"complete_source_signal_{session}"] += 1
        funnel[f"complete_source_signal_{side}_{session}"] += 1
    funnel["complete_source_signals"] = len(signals)
    return signals, dict(sorted(funnel.items()))


def spread_for(symbol: str, scenario: str) -> Fraction:
    spec = SYMBOL_SPEC[symbol]
    points = spec["center_points"] if scenario == "CENTER" else spec["adverse_points"]
    return spec["point"] * points


def commission_side_cents(symbol: str, lots: Fraction, price: Fraction) -> int:
    if symbol == "EURUSD.DWX":
        rate = max(Fraction(5, 2), Fraction(5, 2) * price)
        raw = rate * lots
    elif symbol == "XAUUSD.DWX":
        raw = price * 100 * lots * Fraction(25, 1_000_000)
    else:
        raise AuditError(f"no commission rule for {symbol}")
    return round_half_up_cents(raw)


def close_trade(
    position: Position,
    *,
    exit_timestamp: int,
    exit_price: Fraction,
    exit_reason: str,
    conflict: bool,
) -> Trade:
    value_per_price = SYMBOL_SPEC[position.symbol]["value_per_price_lot"]
    gross_usd = (
        position.direction
        * (exit_price - position.entry)
        * value_per_price
        * position.lots
    )
    exit_commission = commission_side_cents(position.symbol, position.lots, exit_price)
    total_commission = position.entry_commission_cents + exit_commission
    adjusted_usd = gross_usd - Fraction(total_commission, 100)
    side = "LONG" if position.direction > 0 else "SHORT"
    trade_id = (
        f"{position.scenario}|{position.symbol}|{position.entry_timestamp}|"
        f"{side}|{position.structural_id}"
    )
    return Trade(
        trade_id=trade_id,
        scenario=position.scenario,
        symbol=position.symbol,
        session=position.session,
        side=side,
        structural_id=position.structural_id,
        entry_timestamp=position.entry_timestamp,
        exit_timestamp=exit_timestamp,
        entry=position.entry,
        stop=position.stop,
        target=position.target,
        exit_price=exit_price,
        lots=position.lots,
        gross_usd=gross_usd,
        gross_r=gross_usd / RISK_USD,
        entry_commission_cents=position.entry_commission_cents,
        exit_commission_cents=exit_commission,
        commission_cents=total_commission,
        adjusted_usd=adjusted_usd,
        adjusted_r=adjusted_usd / RISK_USD,
        exit_reason=exit_reason,
        same_bar_sl_tp_conflict=conflict,
    )


def _process_position_bar(
    position: Position, bar: Bar, spread: Fraction
) -> Trade | None:
    if bar.timestamp != position.expected_next_open:
        raise DataIntegrityError(
            f"{position.scenario} {position.symbol}: missing expected M15 bar "
            f"{stamp_epoch(position.expected_next_open)} while position open; "
            f"next={stamp_epoch(bar.timestamp)}"
        )
    conflict = False
    if position.direction > 0:
        if bar.open <= position.stop:
            return close_trade(
                position,
                exit_timestamp=bar.timestamp,
                exit_price=bar.open,
                exit_reason="SL_GAP",
                conflict=False,
            )
        if bar.open >= position.target:
            return close_trade(
                position,
                exit_timestamp=bar.timestamp,
                exit_price=position.target,
                exit_reason="TP_GAP",
                conflict=False,
            )
        stop_hit = bar.low <= position.stop
        target_hit = bar.high >= position.target
    else:
        ask_open = bar.open + spread
        if ask_open >= position.stop:
            return close_trade(
                position,
                exit_timestamp=bar.timestamp,
                exit_price=ask_open,
                exit_reason="SL_GAP",
                conflict=False,
            )
        if ask_open <= position.target:
            return close_trade(
                position,
                exit_timestamp=bar.timestamp,
                exit_price=position.target,
                exit_reason="TP_GAP",
                conflict=False,
            )
        stop_hit = bar.high + spread >= position.stop
        target_hit = bar.low + spread <= position.target
    conflict = stop_hit and target_hit
    if stop_hit:
        return close_trade(
            position,
            exit_timestamp=bar.timestamp + M15_SECONDS,
            exit_price=position.stop,
            exit_reason="SL" if not conflict else "SL_CONSERVATIVE_CONFLICT",
            conflict=conflict,
        )
    if target_hit:
        return close_trade(
            position,
            exit_timestamp=bar.timestamp + M15_SECONDS,
            exit_price=position.target,
            exit_reason="TP",
            conflict=False,
        )
    bar_close = bar.timestamp + M15_SECONDS
    if bar_close > position.flat_timestamp:
        raise DataIntegrityError(
            f"{position.scenario} {position.symbol}: crossed flat boundary without bar"
        )
    if bar_close == position.flat_timestamp:
        exit_price = bar.close if position.direction > 0 else bar.close + spread
        friday = epoch_to_datetime(position.flat_timestamp).weekday() == 4 and (
            epoch_to_datetime(position.flat_timestamp).hour == 21
        )
        return close_trade(
            position,
            exit_timestamp=bar_close,
            exit_price=exit_price,
            exit_reason="FRIDAY_FLAT" if friday else "SESSION_FLAT",
            conflict=False,
        )
    position.expected_next_open = bar_close
    return None


def simulate_symbol_scenario(
    market: MarketSlice,
    signals: Mapping[int, Signal],
    structural_funnel: Mapping[str, int],
    news: NewsBook,
    scenario: str,
) -> tuple[list[Trade], dict[str, int]]:
    symbol = market.symbol
    bars = market.bars
    spread = spread_for(symbol, scenario)
    funnel: Counter[str] = Counter(structural_funnel)
    trades: list[Trade] = []
    position: Position | None = None

    for index, bar in enumerate(bars):
        if position is not None:
            completed = _process_position_bar(position, bar, spread)
            if completed is not None:
                trades.append(completed)
                funnel[f"exit_{completed.exit_reason}"] += 1
                position = None

        signal = signals.get(index)
        if signal is None:
            continue
        entry_timestamp = bar.timestamp + M15_SECONDS
        session_end = session_end_timestamp(bar.timestamp, signal.session)
        friday_cutoff = friday_cutoff_timestamp(bar.timestamp)
        if friday_cutoff is not None and entry_timestamp >= friday_cutoff:
            funnel["rejected_friday_cutoff"] += 1
            continue
        if entry_timestamp >= session_end:
            funnel["rejected_final_session_bar"] += 1
            continue
        if position is not None:
            funnel["ignored_while_position_open"] += 1
            continue
        if news.blocks(symbol, entry_timestamp):
            funnel["rejected_news_entry_timestamp"] += 1
            continue

        if signal.direction > 0:
            entry = bar.close + spread
            stop = bar.low
            risk_distance = entry - stop
            target = entry + 2 * risk_distance
        else:
            entry = bar.close
            stop = bar.high + spread
            risk_distance = stop - entry
            target = entry - 2 * risk_distance
        if risk_distance <= 0 or target <= 0:
            funnel["invalid_risk"] += 1
            continue
        lots = RISK_USD / (
            risk_distance * SYMBOL_SPEC[symbol]["value_per_price_lot"]
        )
        entry_commission = commission_side_cents(symbol, lots, entry)
        flat_timestamp = session_end
        if friday_cutoff is not None:
            flat_timestamp = min(flat_timestamp, friday_cutoff)
        position = Position(
            symbol=symbol,
            scenario=scenario,
            direction=signal.direction,
            session=signal.session,
            structural_id=signal.structural_id,
            entry_timestamp=entry_timestamp,
            entry=entry,
            stop=stop,
            target=target,
            lots=lots,
            entry_commission_cents=entry_commission,
            expected_next_open=entry_timestamp,
            flat_timestamp=flat_timestamp,
        )
        funnel["filled"] += 1
        funnel[f"filled_{signal.session}"] += 1
        funnel[f"filled_{'LONG' if signal.direction > 0 else 'SHORT'}"] += 1

    if position is not None:
        raise DataIntegrityError(
            f"{scenario} {symbol}: data ended with position open at "
            f"{stamp_epoch(position.entry_timestamp)}"
        )
    if funnel["filled"] != len(trades):
        raise AuditError(
            f"{scenario} {symbol}: filled/trade mismatch {funnel['filled']} != {len(trades)}"
        )
    return trades, dict(sorted(funnel.items()))


def trade_sort_key(trade: Trade) -> tuple[Any, ...]:
    return (
        trade.exit_timestamp,
        0 if trade.adjusted_r < 0 else 1,
        trade.adjusted_r,
        trade.symbol,
        trade.session,
        trade.entry_timestamp,
        trade.trade_id,
    )


def _profit_factor(profit: Fraction, loss: Fraction) -> Fraction | str | None:
    if profit <= 0:
        return None
    if loss == 0:
        return "INF"
    return profit / abs(loss)


def _max_concurrency(trades: Sequence[Trade]) -> int:
    events: list[tuple[int, int]] = []
    for trade in trades:
        events.append((trade.entry_timestamp, 1))
        events.append((trade.exit_timestamp, -1))
    current = 0
    maximum = 0
    for _timestamp, delta in sorted(events, key=lambda item: (item[0], item[1])):
        current += delta
        if current < 0:
            raise AuditError("negative concurrency")
        maximum = max(maximum, current)
    return maximum


def compute_metric(trades: Sequence[Trade]) -> Metric:
    ordered = sorted(trades, key=trade_sort_key)
    gross_net = sum((trade.gross_r for trade in ordered), Fraction(0))
    gross_profit = sum(
        (trade.gross_r for trade in ordered if trade.gross_r > 0), Fraction(0)
    )
    gross_loss = sum(
        (trade.gross_r for trade in ordered if trade.gross_r < 0), Fraction(0)
    )
    adjusted_net = sum((trade.adjusted_r for trade in ordered), Fraction(0))
    adjusted_profit = sum(
        (trade.adjusted_r for trade in ordered if trade.adjusted_r > 0), Fraction(0)
    )
    adjusted_loss = sum(
        (trade.adjusted_r for trade in ordered if trade.adjusted_r < 0), Fraction(0)
    )
    commission_cents = sum(trade.commission_cents for trade in ordered)
    winners = sorted(
        (trade.adjusted_r for trade in ordered if trade.adjusted_r > 0), reverse=True
    )
    balance = Fraction(0)
    peak = Fraction(0)
    drawdown = Fraction(0)
    daily: dict[str, Fraction] = defaultdict(Fraction)
    yearly: dict[str, Fraction] = defaultdict(Fraction)
    for trade in ordered:
        balance += trade.adjusted_r
        peak = max(peak, balance)
        drawdown = max(drawdown, peak - balance)
        exit_dt = epoch_to_datetime(trade.exit_timestamp)
        daily[exit_dt.date().isoformat()] += trade.adjusted_r
        yearly[str(exit_dt.year)] += trade.adjusted_r
    top_two = (
        sum(winners[:2], Fraction(0)) / sum(winners, Fraction(0)) if winners else None
    )
    best_trade = max((trade.adjusted_r for trade in ordered), default=Fraction(0))
    best_year = max((yearly.get(str(year), Fraction(0)) for year in ANALYSIS_YEARS), default=Fraction(0))
    cost_burden = (
        Fraction(commission_cents, 100_000) / gross_profit
        if gross_profit > 0
        else None
    )
    return Metric(
        trades=len(ordered),
        gross_net_r=gross_net,
        gross_profit_r=gross_profit,
        gross_loss_r=gross_loss,
        adjusted_net_r=adjusted_net,
        adjusted_profit_r=adjusted_profit,
        adjusted_loss_r=adjusted_loss,
        external_commission_cents=commission_cents,
        adjusted_expectancy_r=adjusted_net / len(ordered) if ordered else None,
        adjusted_pf=_profit_factor(adjusted_profit, adjusted_loss),
        gross_pf=_profit_factor(gross_profit, gross_loss),
        adjusted_win_rate=Fraction(len(winners), len(ordered)) if ordered else None,
        max_closed_balance_dd_r=drawdown,
        worst_closed_day_r=min(daily.values(), default=Fraction(0)),
        top_two_winner_share=top_two,
        leave_best_trade_r=adjusted_net - best_trade,
        leave_best_year_r=adjusted_net - best_year,
        positive_full_years=sum(
            yearly.get(str(year), Fraction(0)) > 0 for year in FULL_YEARS
        ),
        yearly={str(year): yearly.get(str(year), Fraction(0)) for year in ANALYSIS_YEARS},
        same_bar_conflicts=sum(trade.same_bar_sl_tp_conflict for trade in ordered),
        exit_reasons=dict(sorted(Counter(trade.exit_reason for trade in ordered).items())),
        cost_burden=cost_burden,
        max_concurrent_positions=_max_concurrency(ordered),
    )


def encode_exact(value: Any) -> Any:
    if isinstance(value, Fraction):
        return fraction_text(value)
    if isinstance(value, Mapping):
        return {str(key): encode_exact(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [encode_exact(item) for item in value]
    return value


def metric_payload(metric: Metric) -> dict[str, Any]:
    return encode_exact(
        {
            "trades": metric.trades,
            "gross_net_r": metric.gross_net_r,
            "gross_net_usd": metric.gross_net_r * RISK_USD,
            "gross_profit_r": metric.gross_profit_r,
            "gross_loss_r": metric.gross_loss_r,
            "gross_profit_factor": metric.gross_pf or "UNDEFINED",
            "external_commission_cents": metric.external_commission_cents,
            "external_commission_usd": Fraction(metric.external_commission_cents, 100),
            "external_commission_r": Fraction(metric.external_commission_cents, 100_000),
            "cost_burden_fraction_of_gross_positive_r": metric.cost_burden
            if metric.cost_burden is not None
            else "UNDEFINED",
            "adjusted_net_r": metric.adjusted_net_r,
            "adjusted_net_usd": metric.adjusted_net_r * RISK_USD,
            "adjusted_profit_r": metric.adjusted_profit_r,
            "adjusted_loss_r": metric.adjusted_loss_r,
            "adjusted_profit_factor": metric.adjusted_pf or "UNDEFINED",
            "adjusted_expectancy_r": metric.adjusted_expectancy_r
            if metric.adjusted_expectancy_r is not None
            else "UNDEFINED",
            "adjusted_win_rate": metric.adjusted_win_rate
            if metric.adjusted_win_rate is not None
            else "UNDEFINED",
            "max_adjusted_closed_balance_drawdown_r": metric.max_closed_balance_dd_r,
            "worst_closed_exit_broker_day_r": metric.worst_closed_day_r,
            "top_two_adjusted_winner_share": metric.top_two_winner_share
            if metric.top_two_winner_share is not None
            else "UNDEFINED",
            "leave_best_trade_out_adjusted_net_r": metric.leave_best_trade_r,
            "leave_best_year_out_adjusted_net_r": metric.leave_best_year_r,
            "positive_full_common_years": metric.positive_full_years,
            "analysis_year_adjusted_net_r": metric.yearly,
            "same_bar_sl_tp_conflicts": metric.same_bar_conflicts,
            "exit_reasons": metric.exit_reasons,
            "max_concurrent_positions": metric.max_concurrent_positions,
        }
    )


def trade_payload(trade: Trade) -> dict[str, Any]:
    return encode_exact(
        {
            "trade_id": trade.trade_id,
            "scenario": trade.scenario,
            "symbol": trade.symbol,
            "session": trade.session,
            "side": trade.side,
            "structural_id": trade.structural_id,
            "entry_timestamp": trade.entry_timestamp,
            "entry_time_broker": stamp_epoch(trade.entry_timestamp),
            "exit_timestamp": trade.exit_timestamp,
            "exit_time_broker": stamp_epoch(trade.exit_timestamp),
            "entry": trade.entry,
            "stop": trade.stop,
            "target": trade.target,
            "exit_price": trade.exit_price,
            "lots": trade.lots,
            "gross_usd": trade.gross_usd,
            "gross_r": trade.gross_r,
            "entry_commission_cents": trade.entry_commission_cents,
            "exit_commission_cents": trade.exit_commission_cents,
            "commission_cents": trade.commission_cents,
            "adjusted_usd": trade.adjusted_usd,
            "adjusted_r": trade.adjusted_r,
            "exit_reason": trade.exit_reason,
            "same_bar_sl_tp_conflict": trade.same_bar_sl_tp_conflict,
            "entry_bar_exit": False,
        }
    )
