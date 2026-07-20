#!/usr/bin/env python3
"""Outcome-fenced two-arm offline DEV screen for QM5_10253.

Arm A is the preregistered approved-card centre.  Arm B reproduces the
structural Pine-v1 pivot-sweep and FVG-to-IFVG inversion mechanism under the
same preregistered trade overlay.  The loader stops on the timestamp prefix of
the first 2023 row before parsing or hashing any future OHLC field.
"""

from __future__ import annotations

import argparse
import bisect
import csv
import hashlib
import json
import math
import os
import tempfile
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]
CONTRACT_PATH = (
    EA_ROOT
    / "docs"
    / "candidate-analysis"
    / "tv_ifvg_sweep_two_arm_full_dev_contract.json"
)
CONTRACT_COMMIT = "92ab2205c9ba815360808014313ced634d56af7b"
EXPECTED_CONTRACT_SHA256 = "172ff9133629ebbef1e50648f0e38e1b3eb39256732de854af99a9919efdd299"
SOURCE_EVIDENCE_PATH = (
    EA_ROOT / "docs" / "candidate-analysis" / "tv_ifvg_sweep_primary_source_evidence.json"
)
SPREAD_EVIDENCE_PATH = (
    EA_ROOT / "docs" / "candidate-analysis" / "tv_ifvg_sweep_spread_input_snapshot.json"
)
DEFAULT_DATA_ROOT = Path(r"D:\QM\mt5\T_Export\MQL5\Files")
DEFAULT_NEWS_PATH = Path(r"D:\QM\data\news_calendar\news_calendar_2015_2025.csv")
DEFAULT_OUTPUT = (
    EA_ROOT
    / "docs"
    / "candidate-analysis"
    / "tv_ifvg_sweep_two_arm_full_dev_result.json"
)

ANALYSIS_ID = "QM5_10253_TV_IFVG_SWEEP_TWO_ARM_FULL_DEV_001"
EPOCH = datetime(1970, 1, 1)
LOWER_EPOCH = int((datetime(2017, 10, 1) - EPOCH).total_seconds())
UPPER_EPOCH = int((datetime(2023, 1, 1) - EPOCH).total_seconds())
BAR_SECONDS = 15 * 60
FULL_YEARS = (2019, 2020, 2021, 2022)
ARMS = ("A_CARD_CENTER", "B_SOURCE_FAITHFUL")
SCENARIOS = ("CENTER", "ADVERSE")
RISK_USD = Decimal("1000")
CENT = Decimal("0.01")

SYMBOLS: dict[str, dict[str, Any]] = {
    "NDX.DWX": {
        "file": "NDX.DWX_M15.csv",
        "point": 0.1,
        "center_points": 21,
        "adverse_points": 42,
        "value_per_price_lot": 10.0,
    },
    "XAUUSD.DWX": {
        "file": "XAUUSD.DWX_M15.csv",
        "point": 0.01,
        "center_points": 59,
        "adverse_points": 118,
        "value_per_price_lot": 100.0,
    },
}

BOUND_LOCAL: dict[Path, str] = {
    CONTRACT_PATH: EXPECTED_CONTRACT_SHA256,
    SOURCE_EVIDENCE_PATH: "5c872f816aeab895d612573e42c0f8857c1b41577e89f27f579b80f33ab083e3",
    SPREAD_EVIDENCE_PATH: "f350adafa5920d16166c61089b94cf652aa093530822164ecce1f8a49fb0333a",
    EA_ROOT / "QM5_10253_tv-ifvg-sweep.mq5": "c43da3960bafad35ac4d3d7b66e3f434c58ff5b1add7b623b635daea73ee3488",
    EA_ROOT / "SPEC.md": "de9b90b95e11a6f9f9698dcfc0d7d18cdd91ce08d3d9e72a56fd32efe3d0ac5c",
    EA_ROOT / "docs" / "strategy_card.md": "5f55708e42df41b42f944e4c7caf86bbd8a6df17408c479cdac32ad45e540bd6",
    REPO_ROOT
    / "framework"
    / "EAs"
    / "QM5_20009_ict-liquidity-portfolio"
    / "tools"
    / "audit_mt5_report.py": "c9dc5106383073b50150f0edb091338181dc53470615839fb252f5bc96a46c03",
    REPO_ROOT / "framework" / "Include" / "QM" / "QM_DSTAware.mqh": "e5a78c1097ff3622f9066acc25fac41228f049853bca31b19c599e92dc61472f",
    REPO_ROOT / "framework" / "Include" / "QM" / "QM_NewsFilter.mqh": "14d6a0c57e35e4ddd15c89baf30466fb2ffb904ffa2183a91d24080510bff34e",
    REPO_ROOT / "framework" / "registry" / "live_commission.json": "119f795cefce2F819F0C7AAE3BDDB87AFFBFFA771F596DF48D182CF89989E197".lower(),
    REPO_ROOT / "framework" / "registry" / "venue_cost_model.json": "7dfafe53749e5c45be0cb37568b6e3491c109f546fafaf799f6ea82efdb688d7",
    Path(r"D:\QM\strategy_farm\artifacts\cards_approved\QM5_10253_tv-ifvg-sweep.md"): "5f55708e42df41b42f944e4c7caf86bbd8a6df17408c479cdac32ad45e540bd6",
}
EXPECTED_NEWS_SHA256 = "8e898ca1c4aed5fbc4cbe43fc176e8d8595c2e6f5f05c2984c2468527d4f5b0d"


class AuditError(RuntimeError):
    """Fail-closed audit error."""


@dataclass(frozen=True)
class Bar:
    timestamp: int
    broker_time: datetime
    open: float
    high: float
    low: float
    close: float
    tickvol: int


@dataclass(frozen=True)
class SliceIdentity:
    path: str
    selected_sha256: str
    selected_rows: int
    first_selected_broker_time: str
    last_selected_broker_time: str
    first_excluded_timestamp: str
    future_ohlc_parsed: bool


@dataclass(frozen=True)
class MarketSlice:
    symbol: str
    bars: tuple[Bar, ...]
    identity: SliceIdentity


@dataclass(frozen=True)
class Signal:
    arm: str
    direction: int
    completion_index: int
    arm_index: int
    zone_bottom: float
    zone_top: float
    sweep_index: int
    sweep_extreme: float
    stop_atr: float
    structural_id: str


@dataclass(frozen=True)
class Trade:
    arm: str
    scenario: str
    symbol: str
    side: str
    structural_id: str
    entry_time_broker: str
    exit_time_broker: str
    entry_timestamp: int
    exit_timestamp: int
    entry: float
    stop: float
    target: float
    exit_price: float
    lots: float
    gross_usd: float
    gross_r: float
    commission_usd: float
    adjusted_usd: float
    adjusted_r: float
    exit_reason: str
    same_bar_sl_tp_conflict: bool
    entry_bar_exit: bool


@dataclass
class OverlayResult:
    funnel: Counter[str]
    trades: list[Trade]
    integrity_issues: list[str]


@dataclass
class PivotState:
    price: float
    index: int
    broken: bool = False
    mitigated: bool = False
    taken: bool = False
    wicked: bool = False


@dataclass(frozen=True)
class NormalFvg:
    fvg_id: int
    top: float
    bottom: float
    start_index: int
    created_index: int
    is_bull: bool


@dataclass
class SourceContext:
    direction: int
    sweep_index: int
    sweep_extreme: float
    bound_fvg_id: int | None = None


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def stamp(value: datetime) -> str:
    return value.isoformat(sep="T", timespec="seconds")


def dt_from_epoch(value: int) -> datetime:
    return EPOCH + timedelta(seconds=value)


def parse_selected_market(path: Path, symbol: str) -> MarketSlice:
    """Read timestamp first and never parse the first 2023 row's OHLC tail."""
    if not path.is_file():
        raise AuditError(f"market file missing: {path}")
    bars: list[Bar] = []
    digest = hashlib.sha256()
    prior_timestamp: int | None = None
    first_excluded: str | None = None
    with path.open("r", encoding="ascii", newline="") as handle:
        header = handle.readline().strip("\r\n")
        if header != "time,open,high,low,close,tickvol":
            raise AuditError(f"unexpected market header in {path}: {header!r}")
        for row_number, raw_line in enumerate(handle, start=2):
            raw_timestamp, separator, _future_tail_not_parsed = raw_line.partition(",")
            if not separator:
                raise AuditError(f"row {row_number}: missing first delimiter")
            try:
                timestamp = int(raw_timestamp)
            except ValueError as exc:
                raise AuditError(f"row {row_number}: invalid timestamp") from exc
            if prior_timestamp is not None and timestamp <= prior_timestamp:
                raise AuditError(f"row {row_number}: timestamps not strictly increasing")
            prior_timestamp = timestamp
            if timestamp >= UPPER_EPOCH:
                first_excluded = stamp(dt_from_epoch(timestamp))
                break
            if timestamp < LOWER_EPOCH:
                continue
            if timestamp % BAR_SECONDS != 0:
                raise AuditError(f"row {row_number}: selected timestamp is not M15 aligned")
            parts = raw_line.strip("\r\n").split(",")
            if len(parts) != 6:
                raise AuditError(f"row {row_number}: malformed selected row")
            try:
                open_, high, low, close = (float(value) for value in parts[1:5])
                tickvol = int(parts[5])
            except ValueError as exc:
                raise AuditError(f"row {row_number}: nonnumeric selected OHLC") from exc
            values = (open_, high, low, close)
            if (
                not all(math.isfinite(value) and value > 0.0 for value in values)
                or high < max(open_, low, close)
                or low > min(open_, high, close)
                or tickvol < 0
            ):
                raise AuditError(f"row {row_number}: invalid selected OHLC")
            bars.append(
                Bar(
                    timestamp=timestamp,
                    broker_time=dt_from_epoch(timestamp),
                    open=open_,
                    high=high,
                    low=low,
                    close=close,
                    tickvol=tickvol,
                )
            )
            digest.update(
                f"{timestamp},{parts[1]},{parts[2]},{parts[3]},{parts[4]},{parts[5]}\n".encode(
                    "ascii"
                )
            )
    if not bars:
        raise AuditError(f"selected market slice empty: {path}")
    if first_excluded is None:
        raise AuditError(f"cannot prove future fence; no >=2023 timestamp in {path}")
    return MarketSlice(
        symbol=symbol,
        bars=tuple(bars),
        identity=SliceIdentity(
            path=str(path.resolve()),
            selected_sha256=digest.hexdigest(),
            selected_rows=len(bars),
            first_selected_broker_time=stamp(bars[0].broker_time),
            last_selected_broker_time=stamp(bars[-1].broker_time),
            first_excluded_timestamp=first_excluded,
            future_ohlc_parsed=False,
        ),
    )


def compute_atr(bars: Sequence[Bar], period: int = 14) -> list[float | None]:
    result: list[float | None] = [None] * len(bars)
    true_ranges: list[float] = []
    prior_close: float | None = None
    rma: float | None = None
    for index, bar in enumerate(bars):
        tr = bar.high - bar.low
        if prior_close is not None:
            tr = max(tr, abs(bar.high - prior_close), abs(bar.low - prior_close))
        true_ranges.append(tr)
        if len(true_ranges) == period:
            rma = sum(true_ranges) / period
        elif len(true_ranges) > period:
            assert rma is not None
            rma = ((period - 1) * rma + tr) / period
        if rma is not None:
            result[index] = rma
        prior_close = bar.close
    return result


def _ema(values: Sequence[float], period: int) -> list[float]:
    alpha = 2.0 / (period + 1.0)
    output: list[float] = []
    prior: float | None = None
    for value in values:
        prior = value if prior is None else alpha * value + (1.0 - alpha) * prior
        output.append(prior)
    return output


def _htf_closes(bars: Sequence[Bar], seconds: int) -> tuple[list[int], list[float]]:
    ends: list[int] = []
    closes: list[float] = []
    bucket: int | None = None
    last_close = 0.0
    for bar in bars:
        current = (bar.timestamp // seconds) * seconds
        if bucket is None:
            bucket = current
        elif current != bucket:
            ends.append(bucket + seconds)
            closes.append(last_close)
            bucket = current
        last_close = bar.close
    if bucket is not None:
        ends.append(bucket + seconds)
        closes.append(last_close)
    return ends, closes


def compute_mtf_bias(bars: Sequence[Bar]) -> list[int]:
    h4_ends, h4_close = _htf_closes(bars, 4 * 3600)
    h1_ends, h1_close = _htf_closes(bars, 3600)
    h4_13, h4_21, h4_34 = (_ema(h4_close, period) for period in (13, 21, 34))
    h1_13, h1_21 = (_ema(h1_close, period) for period in (13, 21))
    output: list[int] = []
    for bar in bars:
        h4_index = bisect.bisect_right(h4_ends, bar.timestamp) - 1
        h1_index = bisect.bisect_right(h1_ends, bar.timestamp) - 1
        if h4_index < 33 or h1_index < 20:
            output.append(0)
            continue
        h4_direction = 0
        if h4_13[h4_index] > h4_21[h4_index] > h4_34[h4_index]:
            h4_direction = 1
        elif h4_13[h4_index] < h4_21[h4_index] < h4_34[h4_index]:
            h4_direction = -1
        h1_direction = 0
        if h1_close[h1_index] > h1_21[h1_index] and h1_13[h1_index] > h1_21[h1_index]:
            h1_direction = 1
        elif h1_close[h1_index] < h1_21[h1_index] and h1_13[h1_index] < h1_21[h1_index]:
            h1_direction = -1
        output.append(h4_direction if h4_direction == h1_direction else 0)
    return output


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
    start_day = _nth_sunday(value.year, 3, 2)
    end_day = _nth_sunday(value.year, 11, 1)
    start = datetime(value.year, 3, start_day.day, 7, tzinfo=timezone.utc)
    end = datetime(value.year, 11, end_day.day, 6, tzinfo=timezone.utc)
    return 3 if start <= value < end else 2


def utc_to_broker_epoch(value: datetime) -> int:
    if value.tzinfo is None:
        raise AuditError("UTC conversion requires timezone-aware datetime")
    naive = value.astimezone(timezone.utc).replace(tzinfo=None) + timedelta(
        hours=broker_offset_for_utc(value.astimezone(timezone.utc))
    )
    return int((naive - EPOCH).total_seconds())


class BlackoutBook:
    def __init__(self, intervals: Iterable[tuple[int, int]]):
        merged: list[list[int]] = []
        for start, end in sorted(intervals):
            if merged and start <= merged[-1][1]:
                merged[-1][1] = max(merged[-1][1], end)
            else:
                merged.append([start, end])
        self.intervals = tuple((row[0], row[1]) for row in merged)
        self.starts = tuple(row[0] for row in self.intervals)

    def contains(self, timestamp: int) -> bool:
        index = bisect.bisect_right(self.starts, timestamp) - 1
        return index >= 0 and self.intervals[index][1] >= timestamp

    def next_start_after(self, timestamp: int) -> int | None:
        index = bisect.bisect_right(self.starts, timestamp)
        return self.starts[index] if index < len(self.starts) else None


def load_news(path: Path) -> tuple[BlackoutBook, dict[str, Any]]:
    observed_sha = sha256_file(path)
    if observed_sha != EXPECTED_NEWS_SHA256:
        raise AuditError(f"news SHA drift: {observed_sha}")
    intervals: list[tuple[int, int]] = []
    seen: dict[tuple[str, str, str], tuple[str, str]] = {}
    first: datetime | None = None
    last: datetime | None = None
    selected = 0
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        required = {"datetime", "currency", "event_name", "impact", "is_high_impact"}
        if not required.issubset(reader.fieldnames or []):
            raise AuditError("news header missing required fields")
        for row_number, row in enumerate(reader, start=2):
            raw_time = (row.get("datetime") or "").strip()
            currency = (row.get("currency") or "").strip().upper()
            event = (row.get("event_name") or "").strip()
            impact = (row.get("impact") or "").strip().lower()
            high = (row.get("is_high_impact") or "").strip()
            if not raw_time or not currency or not event or high not in {"0", "1"}:
                raise AuditError(f"malformed news row {row_number}")
            key = (raw_time, currency, event)
            material = (impact, high)
            if key in seen and seen[key] != material:
                raise AuditError(f"conflicting news duplicate {key}")
            seen[key] = material
            try:
                utc = datetime.strptime(raw_time, "%Y-%m-%d %H:%M:%S").replace(
                    tzinfo=timezone.utc
                )
            except ValueError as exc:
                raise AuditError(f"invalid news timestamp row {row_number}") from exc
            first = utc if first is None or utc < first else first
            last = utc if last is None or utc > last else last
            if high != "1" or currency != "USD":
                continue
            selected += 1
            intervals.append(
                (
                    utc_to_broker_epoch(utc - timedelta(minutes=30)),
                    utc_to_broker_epoch(utc + timedelta(minutes=30)),
                )
            )
    if first is None or last is None or first.year > 2017 or last.year < 2022:
        raise AuditError("news calendar does not cover DEV interval")
    book = BlackoutBook(intervals)
    return book, {
        "path": str(path.resolve()),
        "sha256": observed_sha,
        "first_utc": first.isoformat(),
        "last_utc": last.isoformat(),
        "selected_usd_high_rows": selected,
        "merged_intervals": len(book.intervals),
    }


def generate_card_signals(
    bars: Sequence[Bar], atr: Sequence[float | None]
) -> tuple[list[Signal], Counter[str]]:
    signals: list[Signal] = []
    funnel: Counter[str] = Counter(bars=len(bars))
    for completion in range(22, len(bars) - 1):
        sweep = completion - 2
        displacement = completion - 1
        prior = bars[sweep - 20 : sweep]
        prior_low = min(bar.low for bar in prior)
        prior_high = max(bar.high for bar in prior)
        long_sweep = bars[sweep].low < prior_low and bars[sweep].close > prior_low
        short_sweep = bars[sweep].high > prior_high and bars[sweep].close < prior_high
        if not long_sweep and not short_sweep:
            continue
        funnel["sweeps"] += 1
        direction = 1 if long_sweep else -1
        disp_atr = atr[displacement]
        if disp_atr is None:
            funnel["atr_unavailable"] += 1
            continue
        directional_body = (
            bars[displacement].close > bars[displacement].open
            if direction > 0
            else bars[displacement].close < bars[displacement].open
        )
        if not directional_body or abs(bars[displacement].close - bars[displacement].open) < disp_atr:
            funnel["displacement_fail"] += 1
            continue
        funnel["displacement_pass"] += 1
        gap = (
            bars[completion].low > bars[sweep].high
            if direction > 0
            else bars[completion].high < bars[sweep].low
        )
        if not gap:
            funnel["gap_fail"] += 1
            continue
        stop_atr = atr[completion]
        if stop_atr is None:
            funnel["atr_unavailable"] += 1
            continue
        funnel["gap_pass"] += 1
        zone_bottom = bars[sweep].high if direction > 0 else bars[completion].high
        zone_top = bars[completion].low if direction > 0 else bars[sweep].low
        if not zone_bottom < zone_top:
            funnel["invalid_zone"] += 1
            continue
        signals.append(
            Signal(
                arm="A_CARD_CENTER",
                direction=direction,
                completion_index=completion,
                arm_index=completion + 1,
                zone_bottom=zone_bottom,
                zone_top=zone_top,
                sweep_index=sweep,
                sweep_extreme=bars[sweep].low if direction > 0 else bars[sweep].high,
                stop_atr=stop_atr,
                structural_id=f"A:{bars[sweep].timestamp}:{'L' if direction > 0 else 'S'}",
            )
        )
        funnel["signals"] += 1
        funnel["long_signals" if direction > 0 else "short_signals"] += 1
    return signals, funnel


def _strict_pivot_high(bars: Sequence[Bar], index: int, wing: int = 5) -> bool:
    center = bars[index].high
    return all(
        center > bars[candidate].high
        for candidate in range(index - wing, index + wing + 1)
        if candidate != index
    )


def _strict_pivot_low(bars: Sequence[Bar], index: int, wing: int = 5) -> bool:
    center = bars[index].low
    return all(
        center < bars[candidate].low
        for candidate in range(index - wing, index + wing + 1)
        if candidate != index
    )


def generate_source_signals(
    bars: Sequence[Bar], atr: Sequence[float | None]
) -> tuple[list[Signal], Counter[str]]:
    """Reproduce Pine-v1 structures and the preregistered causal bridge."""
    high_pivots: list[PivotState] = []  # newest first, like Pine unshift
    low_pivots: list[PivotState] = []
    active_fvgs: list[NormalFvg] = []  # Pine push order
    contexts: dict[int, SourceContext | None] = {1: None, -1: None}
    next_fvg_id = 1
    signals: list[Signal] = []
    funnel: Counter[str] = Counter(bars=len(bars))

    for index, bar in enumerate(bars):
        pivot_index = index - 5
        if pivot_index >= 5:
            if _strict_pivot_high(bars, pivot_index):
                high_pivots.insert(0, PivotState(bars[pivot_index].high, pivot_index))
                funnel["pivot_high_confirmed"] += 1
            if _strict_pivot_low(bars, pivot_index):
                low_pivots.insert(0, PivotState(bars[pivot_index].low, pivot_index))
                funnel["pivot_low_confirmed"] += 1

        raw_events: list[tuple[int, str]] = []
        kept_high_oldest: list[PivotState] = []
        for pivot in reversed(high_pivots):
            if not pivot.mitigated:
                if not pivot.broken:
                    if bar.close > pivot.price:
                        pivot.broken = True
                    if not pivot.wicked and bar.high > pivot.price and bar.close < pivot.price:
                        raw_events.append((-1, "HIGH_WICK"))
                        pivot.wicked = True
                else:
                    if bar.close < pivot.price:
                        pivot.mitigated = True
                    if bar.low < pivot.price and bar.close > pivot.price:
                        raw_events.append((1, "HIGH_OUTBREAK_RETEST"))
                        pivot.taken = True
            if index - pivot.index > 2000 or pivot.mitigated or pivot.taken:
                funnel["pivot_high_removed"] += 1
            else:
                kept_high_oldest.append(pivot)
        high_pivots = list(reversed(kept_high_oldest))

        kept_low_oldest: list[PivotState] = []
        for pivot in reversed(low_pivots):
            if not pivot.mitigated:
                if not pivot.broken:
                    if bar.close < pivot.price:
                        pivot.broken = True
                    if not pivot.wicked and bar.low < pivot.price and bar.close > pivot.price:
                        raw_events.append((1, "LOW_WICK"))
                        pivot.wicked = True
                else:
                    if bar.close > pivot.price:
                        pivot.mitigated = True
                    if bar.high > pivot.price and bar.close < pivot.price:
                        raw_events.append((-1, "LOW_OUTBREAK_RETEST"))
                        pivot.taken = True
            if index - pivot.index > 2000 or pivot.mitigated or pivot.taken:
                funnel["pivot_low_removed"] += 1
            else:
                kept_low_oldest.append(pivot)
        low_pivots = list(reversed(kept_low_oldest))

        for direction, event_type in raw_events:
            funnel["raw_sweeps"] += 1
            funnel[f"raw_{event_type.lower()}"] += 1
            funnel["raw_long_sweeps" if direction > 0 else "raw_short_sweeps"] += 1
        dedup_directions = sorted({event[0] for event in raw_events})

        for direction in (1, -1):
            context = contexts[direction]
            if context is not None and index - context.sweep_index > 300:
                funnel["context_expired_300"] += 1
                contexts[direction] = None

        for direction in dedup_directions:
            funnel["dedup_sweeps"] += 1
            if contexts[direction] is None:
                contexts[direction] = SourceContext(
                    direction=direction,
                    sweep_index=index,
                    sweep_extreme=bar.low if direction > 0 else bar.high,
                )
                funnel["contexts_started"] += 1
            else:
                funnel["sweep_ignored_context_occupied"] += 1

        created: list[NormalFvg] = []
        current_atr = atr[index]
        if index >= 2 and current_atr is not None:
            if bar.low > bars[index - 2].high:
                gap_size = bar.low - bars[index - 2].high
                if gap_size > 0.6 * current_atr:
                    created.append(
                        NormalFvg(
                            fvg_id=next_fvg_id,
                            top=bar.low,
                            bottom=bars[index - 2].high,
                            start_index=index - 2,
                            created_index=index,
                            is_bull=True,
                        )
                    )
                    next_fvg_id += 1
            if bar.high < bars[index - 2].low:
                gap_size = bars[index - 2].low - bar.high
                if gap_size > 0.6 * current_atr:
                    created.append(
                        NormalFvg(
                            fvg_id=next_fvg_id,
                            top=bars[index - 2].low,
                            bottom=bar.high,
                            start_index=index - 2,
                            created_index=index,
                            is_bull=False,
                        )
                    )
                    next_fvg_id += 1
        active_fvgs.extend(created)
        funnel["ordinary_fvgs_created"] += len(created)
        funnel["bullish_fvgs_created"] += sum(item.is_bull for item in created)
        funnel["bearish_fvgs_created"] += sum(not item.is_bull for item in created)

        for direction in (1, -1):
            context = contexts[direction]
            if context is None or context.bound_fvg_id is not None:
                continue
            compatible = [
                item
                for item in created
                if item.created_index > context.sweep_index
                and ((direction > 0 and not item.is_bull) or (direction < 0 and item.is_bull))
            ]
            if compatible:
                context.bound_fvg_id = compatible[0].fvg_id
                funnel["contexts_bound_first_fvg"] += 1

        completed: list[tuple[NormalFvg, int]] = []
        expired_ids: set[int] = set()
        kept_fvgs_reversed: list[NormalFvg] = []
        for item in reversed(active_fvgs):
            direction = 0
            if item.is_bull and bar.close < item.bottom:
                direction = -1
            elif not item.is_bull and bar.close > item.top:
                direction = 1
            if direction:
                completed.append((item, direction))
                funnel["ifvg_completions"] += 1
                funnel["bullish_ifvg_completions" if direction > 0 else "bearish_ifvg_completions"] += 1
            elif index - item.start_index > 1000:
                expired_ids.add(item.fvg_id)
                funnel["ordinary_fvg_expired_1000"] += 1
            else:
                kept_fvgs_reversed.append(item)
        active_fvgs = list(reversed(kept_fvgs_reversed))

        for direction in (1, -1):
            context = contexts[direction]
            if context is not None and context.bound_fvg_id in expired_ids:
                contexts[direction] = None
                funnel["bound_fvg_expired"] += 1

        for item, direction in completed:
            context = contexts[direction]
            if context is None or context.bound_fvg_id != item.fvg_id:
                funnel["ifvg_completion_unbound_to_context"] += 1
                continue
            if index - context.sweep_index > 300 or index + 1 >= len(bars):
                funnel["linked_completion_expired_or_no_arm_bar"] += 1
                contexts[direction] = None
                continue
            if current_atr is None:
                funnel["atr_unavailable"] += 1
                contexts[direction] = None
                continue
            signals.append(
                Signal(
                    arm="B_SOURCE_FAITHFUL",
                    direction=direction,
                    completion_index=index,
                    arm_index=index + 1,
                    zone_bottom=item.bottom,
                    zone_top=item.top,
                    sweep_index=context.sweep_index,
                    sweep_extreme=context.sweep_extreme,
                    stop_atr=current_atr,
                    structural_id=(
                        f"B:{bars[context.sweep_index].timestamp}:{item.fvg_id}:"
                        f"{'L' if direction > 0 else 'S'}"
                    ),
                )
            )
            funnel["signals"] += 1
            funnel["long_signals" if direction > 0 else "short_signals"] += 1
            contexts[direction] = None
    return signals, funnel


def session_deadline(timestamp: int) -> tuple[str, int] | None:
    value = dt_from_epoch(timestamp)
    minute = value.hour * 60 + value.minute
    if 8 * 60 <= minute < 11 * 60:
        end = value.replace(hour=11, minute=0, second=0, microsecond=0)
        return "LONDON", int((end - EPOCH).total_seconds())
    if 13 * 60 <= minute < 16 * 60:
        end = value.replace(hour=16, minute=0, second=0, microsecond=0)
        return "NEW_YORK", int((end - EPOCH).total_seconds())
    return None


def friday_21(timestamp: int) -> int | None:
    value = dt_from_epoch(timestamp)
    if value.weekday() != 4:
        return None
    boundary = value.replace(hour=21, minute=0, second=0, microsecond=0)
    return int((boundary - EPOCH).total_seconds())


def scenario_spread(symbol: str, scenario: str) -> float:
    spec = SYMBOLS[symbol]
    points = spec["center_points"] if scenario == "CENTER" else spec["adverse_points"]
    return float(points) * float(spec["point"])


def commission_side(symbol: str, volume: Decimal, price: Decimal) -> Decimal:
    if symbol == "NDX.DWX":
        raw = Decimal("2.75") * volume
    elif symbol == "XAUUSD.DWX":
        raw = price * Decimal("100") * volume * Decimal("0.000025")
    else:
        raise AuditError(f"no commission contract for {symbol}")
    return raw.quantize(CENT, rounding=ROUND_HALF_UP)


def execute_trade(
    *,
    bars: Sequence[Bar],
    signal: Signal,
    entry_index: int,
    entry: float,
    stop: float,
    target: float,
    spread: float,
    scenario: str,
    symbol: str,
) -> Trade:
    direction = signal.direction
    value_per_price_lot = float(SYMBOLS[symbol]["value_per_price_lot"])
    risk_price = abs(entry - stop)
    if risk_price <= 0.0:
        raise AuditError(f"nonpositive risk for {signal.structural_id}")
    lots = 1000.0 / (risk_price * value_per_price_lot)
    entry_timestamp = bars[entry_index].timestamp
    time_deadline = entry_timestamp + 32 * BAR_SECONDS
    friday_deadline = friday_21(entry_timestamp)
    exit_price: float | None = None
    exit_timestamp: int | None = None
    exit_reason = ""
    conflict = False
    entry_bar_exit = False

    for index in range(entry_index, len(bars)):
        bar = bars[index]
        if bar.timestamp >= time_deadline:
            exit_price = bar.open if direction > 0 else bar.open + spread
            exit_timestamp = bar.timestamp
            exit_reason = "TIME_STOP_32"
            entry_bar_exit = index == entry_index
            break
        if friday_deadline is not None and bar.timestamp >= friday_deadline:
            exit_price = bar.open if direction > 0 else bar.open + spread
            exit_timestamp = bar.timestamp
            exit_reason = "FRIDAY_21_FLAT"
            entry_bar_exit = index == entry_index
            break
        if direction > 0:
            if bar.open <= stop:
                exit_price = bar.open
                exit_timestamp = bar.timestamp
                exit_reason = "SL_GAP"
                entry_bar_exit = index == entry_index
                break
            stop_hit = bar.low <= stop
            target_hit = bar.high >= target
        else:
            ask_open = bar.open + spread
            if ask_open >= stop:
                exit_price = ask_open
                exit_timestamp = bar.timestamp
                exit_reason = "SL_GAP"
                entry_bar_exit = index == entry_index
                break
            stop_hit = bar.high + spread >= stop
            target_hit = bar.low + spread <= target
        if stop_hit:
            exit_price = stop
            exit_timestamp = bar.timestamp + BAR_SECONDS
            exit_reason = "SL"
            conflict = bool(target_hit)
            entry_bar_exit = index == entry_index
            break
        if target_hit:
            exit_price = target
            exit_timestamp = bar.timestamp + BAR_SECONDS
            exit_reason = "TP_2R"
            entry_bar_exit = index == entry_index
            break
    if exit_price is None or exit_timestamp is None:
        raise AuditError(f"unresolved trade {signal.structural_id}")

    gross_usd = (
        (exit_price - entry) * value_per_price_lot * lots
        if direction > 0
        else (entry - exit_price) * value_per_price_lot * lots
    )
    volume_dec = Decimal(str(lots))
    commission = commission_side(symbol, volume_dec, Decimal(str(entry))) + commission_side(
        symbol, volume_dec, Decimal(str(exit_price))
    )
    adjusted_usd = gross_usd - float(commission)
    return Trade(
        arm=signal.arm,
        scenario=scenario,
        symbol=symbol,
        side="LONG" if direction > 0 else "SHORT",
        structural_id=signal.structural_id,
        entry_time_broker=stamp(dt_from_epoch(entry_timestamp)),
        exit_time_broker=stamp(dt_from_epoch(exit_timestamp)),
        entry_timestamp=entry_timestamp,
        exit_timestamp=exit_timestamp,
        entry=entry,
        stop=stop,
        target=target,
        exit_price=exit_price,
        lots=lots,
        gross_usd=gross_usd,
        gross_r=gross_usd / 1000.0,
        commission_usd=float(commission),
        adjusted_usd=adjusted_usd,
        adjusted_r=adjusted_usd / 1000.0,
        exit_reason=exit_reason,
        same_bar_sl_tp_conflict=conflict,
        entry_bar_exit=entry_bar_exit,
    )


def apply_overlay(
    *,
    market: MarketSlice,
    signals: Sequence[Signal],
    biases: Sequence[int],
    blackouts: BlackoutBook,
    scenario: str,
) -> OverlayResult:
    bars = market.bars
    spread = scenario_spread(market.symbol, scenario)
    funnel: Counter[str] = Counter(signals=len(signals))
    trades: list[Trade] = []
    issues: list[str] = []
    busy_until = -1
    for signal in signals:
        if signal.arm_index >= len(bars):
            funnel["no_arm_bar"] += 1
            continue
        arm_bar = bars[signal.arm_index]
        if arm_bar.timestamp < busy_until:
            funnel["ignored_active_state"] += 1
            continue
        if biases[signal.arm_index] != signal.direction:
            funnel["htf_bias_fail"] += 1
            continue
        funnel["htf_bias_pass"] += 1
        session = session_deadline(arm_bar.timestamp)
        if session is None:
            funnel["session_fail"] += 1
            continue
        session_name, window_end = session
        funnel[f"session_{session_name.lower()}"] += 1
        if blackouts.contains(arm_bar.timestamp):
            funnel["news_arm_void"] += 1
            continue
        funnel["news_arm_pass"] += 1
        next_news = blackouts.next_start_after(arm_bar.timestamp)
        deadline = min(arm_bar.timestamp + 8 * BAR_SECONDS, window_end)
        if next_news is not None:
            deadline = min(deadline, next_news)
        friday_deadline = friday_21(arm_bar.timestamp)
        if friday_deadline is not None:
            deadline = min(deadline, friday_deadline)
        if deadline <= arm_bar.timestamp:
            funnel["deadline_at_arm"] += 1
            continue

        stop = (
            signal.sweep_extreme - 0.25 * signal.stop_atr
            if signal.direction > 0
            else signal.sweep_extreme + 0.25 * signal.stop_atr
        )
        open_price = arm_bar.open + spread if signal.direction > 0 else arm_bar.open
        market_entry = False
        if signal.direction > 0:
            if open_price < signal.zone_bottom:
                funnel["arm_open_already_traversed"] += 1
                continue
            if open_price <= signal.zone_top:
                entry = open_price
                market_entry = True
            else:
                entry = signal.zone_top
        else:
            if open_price > signal.zone_top:
                funnel["arm_open_already_traversed"] += 1
                continue
            if open_price >= signal.zone_bottom:
                entry = open_price
                market_entry = True
            else:
                entry = signal.zone_bottom
        if (signal.direction > 0 and entry <= stop) or (signal.direction < 0 and entry >= stop):
            funnel["invalid_stop"] += 1
            continue
        target = (
            entry + 2.0 * (entry - stop)
            if signal.direction > 0
            else entry - 2.0 * (stop - entry)
        )
        entry_index: int | None = signal.arm_index if market_entry else None
        if market_entry:
            funnel["market_entries"] += 1
        else:
            funnel["limit_armed"] += 1
            for index in range(signal.arm_index, len(bars)):
                bar = bars[index]
                if bar.timestamp + BAR_SECONDS > deadline:
                    break
                touched = (
                    bar.low + spread <= entry
                    if signal.direction > 0
                    else bar.high >= entry
                )
                if touched:
                    entry_index = index
                    break
            if entry_index is None:
                funnel["pending_expired"] += 1
                busy_until = deadline
                continue
            funnel["limit_filled"] += 1
        try:
            trade = execute_trade(
                bars=bars,
                signal=signal,
                entry_index=entry_index,
                entry=entry,
                stop=stop,
                target=target,
                spread=spread,
                scenario=scenario,
                symbol=market.symbol,
            )
        except AuditError as exc:
            issues.append(str(exc))
            continue
        trades.append(trade)
        busy_until = trade.exit_timestamp
        funnel["trades"] += 1
        funnel[f"exit_{trade.exit_reason.lower()}"] += 1
        funnel["same_bar_sl_tp_conflicts"] += int(trade.same_bar_sl_tp_conflict)
        funnel["entry_bar_exits"] += int(trade.entry_bar_exit)
    return OverlayResult(funnel=funnel, trades=trades, integrity_issues=issues)


def _pf(profit: float, loss: float) -> dict[str, Any]:
    if loss < 0.0:
        return {"state": "FINITE", "value": profit / abs(loss)}
    if profit > 0.0:
        return {"state": "NO_LOSS", "value": None}
    return {"state": "NO_PROFIT_OR_LOSS", "value": None}


def pf_at_least(metric: Mapping[str, Any], threshold: float) -> bool:
    return metric["state"] == "NO_LOSS" or (
        metric["state"] == "FINITE" and float(metric["value"]) >= threshold
    )


def dynamic_pf_floor(count: int) -> float | None:
    if count <= 0:
        return None
    u = 2.241402727604947 / math.sqrt(count)
    d = u / math.sqrt(1.0 + u * u)
    return max(1.20, (1.0 + d) / (1.0 - d))


def performance(trades: Sequence[Trade]) -> dict[str, Any]:
    ordered = sorted(
        trades,
        key=lambda row: (row.exit_timestamp, row.symbol, row.entry_timestamp, row.structural_id),
    )
    gross_profit = sum(max(row.gross_r, 0.0) for row in ordered)
    gross_loss = sum(min(row.gross_r, 0.0) for row in ordered)
    adjusted_profit = sum(max(row.adjusted_r, 0.0) for row in ordered)
    adjusted_loss = sum(min(row.adjusted_r, 0.0) for row in ordered)
    gross_net = sum(row.gross_r for row in ordered)
    adjusted_net = sum(row.adjusted_r for row in ordered)
    commission_usd = sum(row.commission_usd for row in ordered)
    balance = 0.0
    peak = 0.0
    drawdown = 0.0
    daily: dict[str, float] = defaultdict(float)
    yearly: dict[str, float] = defaultdict(float)
    for row in ordered:
        balance += row.adjusted_r
        peak = max(peak, balance)
        drawdown = max(drawdown, peak - balance)
        exit_dt = dt_from_epoch(row.exit_timestamp)
        daily[exit_dt.date().isoformat()] += row.adjusted_r
        yearly[str(exit_dt.year)] += row.adjusted_r
    winners = sorted((row.adjusted_r for row in ordered if row.adjusted_r > 0.0), reverse=True)
    top_two_share = sum(winners[:2]) / sum(winners) if winners else 0.0
    leave_best_trade = adjusted_net - (max((row.adjusted_r for row in ordered), default=0.0))
    leave_best_year = adjusted_net - max(yearly.values(), default=0.0)
    cost_burden = commission_usd / 1000.0 / gross_profit if gross_profit > 0.0 else None
    count = len(ordered)
    return {
        "trades": count,
        "gross_net_r": gross_net,
        "gross_net_usd": gross_net * 1000.0,
        "gross_profit_r": gross_profit,
        "gross_loss_r": gross_loss,
        "gross_profit_factor": _pf(gross_profit, gross_loss),
        "external_commission_usd": commission_usd,
        "external_commission_r": commission_usd / 1000.0,
        "cost_burden_fraction_of_gross_positive_r": cost_burden,
        "adjusted_net_r": adjusted_net,
        "adjusted_net_usd": adjusted_net * 1000.0,
        "adjusted_profit_r": adjusted_profit,
        "adjusted_loss_r": adjusted_loss,
        "adjusted_profit_factor": _pf(adjusted_profit, adjusted_loss),
        "adjusted_expectancy_r": adjusted_net / count if count else None,
        "adjusted_win_rate": len(winners) / count if count else None,
        "max_adjusted_closed_balance_drawdown_r": drawdown,
        "worst_closed_exit_broker_day_r": min(daily.values(), default=0.0),
        "top_two_adjusted_winner_share": top_two_share,
        "leave_best_trade_out_adjusted_net_r": leave_best_trade,
        "leave_best_year_out_adjusted_net_r": leave_best_year,
        "positive_full_common_years": sum(yearly.get(str(year), 0.0) > 0.0 for year in FULL_YEARS),
        "full_common_year_adjusted_net_r": {
            str(year): yearly.get(str(year), 0.0) for year in FULL_YEARS
        },
        "same_bar_sl_tp_conflicts": sum(row.same_bar_sl_tp_conflict for row in ordered),
        "entry_bar_exits": sum(row.entry_bar_exit for row in ordered),
        "exit_reasons": dict(sorted(Counter(row.exit_reason for row in ordered).items())),
        "dynamic_familywise_pf_floor": dynamic_pf_floor(count),
    }


def breakdown(trades: Sequence[Trade], attribute: str) -> dict[str, dict[str, Any]]:
    groups: dict[str, list[Trade]] = defaultdict(list)
    for trade in trades:
        if attribute == "year":
            key = str(dt_from_epoch(trade.exit_timestamp).year)
        elif attribute == "symbol_year":
            key = f"{trade.symbol}|{dt_from_epoch(trade.exit_timestamp).year}"
        else:
            key = str(getattr(trade, attribute))
        groups[key].append(trade)
    return {key: performance(groups[key]) for key in sorted(groups)}


def gate_row(gate_id: str, observed: Any, rule: str, passed: bool) -> dict[str, Any]:
    return {"gate": gate_id, "observed": observed, "rule": rule, "pass": bool(passed)}


def evaluate_gates(
    center: Sequence[Trade], adverse: Sequence[Trade]
) -> tuple[list[dict[str, Any]], str]:
    pooled = performance(center)
    adverse_pooled = performance(adverse)
    symbol_center = {symbol: performance([row for row in center if row.symbol == symbol]) for symbol in sorted(SYMBOLS)}
    symbol_adverse = {symbol: performance([row for row in adverse if row.symbol == symbol]) for symbol in sorted(SYMBOLS)}
    side_center = {side: performance([row for row in center if row.side == side]) for side in ("LONG", "SHORT")}
    floor = pooled["dynamic_familywise_pf_floor"]
    gates: list[dict[str, Any]] = []
    gates.append(gate_row("CENTER_POOLED_FILLS", pooled["trades"], ">=120", pooled["trades"] >= 120))
    for symbol in sorted(SYMBOLS):
        gates.append(gate_row(f"CENTER_{symbol}_FILLS", symbol_center[symbol]["trades"], ">=40", symbol_center[symbol]["trades"] >= 40))
    for side in ("LONG", "SHORT"):
        gates.append(gate_row(f"CENTER_{side}_FILLS", side_center[side]["trades"], ">=30", side_center[side]["trades"] >= 30))
    gates.append(gate_row("CENTER_POOLED_ADJ_NET", pooled["adjusted_net_r"], ">0", pooled["adjusted_net_r"] > 0.0))
    gates.append(gate_row("CENTER_POOLED_EXPECTANCY", pooled["adjusted_expectancy_r"], ">=0.05R", pooled["adjusted_expectancy_r"] is not None and pooled["adjusted_expectancy_r"] >= 0.05))
    gates.append(gate_row("CENTER_POOLED_FAMILYWISE_PF", {"pf": pooled["adjusted_profit_factor"], "floor": floor}, ">=dynamic Bonferroni floor", floor is not None and pf_at_least(pooled["adjusted_profit_factor"], floor)))
    for symbol in sorted(SYMBOLS):
        metric = symbol_center[symbol]
        gates.append(gate_row(f"CENTER_{symbol}_ADJ_NET", metric["adjusted_net_r"], ">0", metric["adjusted_net_r"] > 0.0))
        gates.append(gate_row(f"CENTER_{symbol}_PF", metric["adjusted_profit_factor"], ">=1.20", pf_at_least(metric["adjusted_profit_factor"], 1.20)))
    for side in ("LONG", "SHORT"):
        metric = side_center[side]
        gates.append(gate_row(f"CENTER_{side}_ADJ_NET", metric["adjusted_net_r"], ">0", metric["adjusted_net_r"] > 0.0))
        gates.append(gate_row(f"CENTER_{side}_PF", metric["adjusted_profit_factor"], ">=1.00", pf_at_least(metric["adjusted_profit_factor"], 1.0)))
    gates.append(gate_row("CENTER_POOLED_POSITIVE_YEARS", pooled["positive_full_common_years"], ">=3 of 4", pooled["positive_full_common_years"] >= 3))
    for symbol in sorted(SYMBOLS):
        gates.append(gate_row(f"CENTER_{symbol}_POSITIVE_YEARS", symbol_center[symbol]["positive_full_common_years"], ">=2 of 4", symbol_center[symbol]["positive_full_common_years"] >= 2))
    gates.append(gate_row("CENTER_POOLED_DD", pooled["max_adjusted_closed_balance_drawdown_r"], "<=10R", pooled["max_adjusted_closed_balance_drawdown_r"] <= 10.0))
    for symbol in sorted(SYMBOLS):
        gates.append(gate_row(f"CENTER_{symbol}_DD", symbol_center[symbol]["max_adjusted_closed_balance_drawdown_r"], "<=10R", symbol_center[symbol]["max_adjusted_closed_balance_drawdown_r"] <= 10.0))
    gates.append(gate_row("CENTER_WORST_CLOSED_DAY", pooled["worst_closed_exit_broker_day_r"], ">=-5R", pooled["worst_closed_exit_broker_day_r"] >= -5.0))
    gates.append(gate_row("CENTER_TOP2_SHARE", pooled["top_two_adjusted_winner_share"], "<=0.50", pooled["top_two_adjusted_winner_share"] <= 0.50))
    gates.append(gate_row("CENTER_LEAVE_BEST_TRADE", pooled["leave_best_trade_out_adjusted_net_r"], ">0", pooled["leave_best_trade_out_adjusted_net_r"] > 0.0))
    gates.append(gate_row("CENTER_LEAVE_BEST_YEAR", pooled["leave_best_year_out_adjusted_net_r"], ">0", pooled["leave_best_year_out_adjusted_net_r"] > 0.0))
    burden = pooled["cost_burden_fraction_of_gross_positive_r"]
    gates.append(gate_row("CENTER_COST_BURDEN", burden, "<=0.25", burden is not None and burden <= 0.25))
    gates.append(gate_row("ADVERSE_POOLED_ADJ_NET", adverse_pooled["adjusted_net_r"], ">0", adverse_pooled["adjusted_net_r"] > 0.0))
    gates.append(gate_row("ADVERSE_POOLED_PF", adverse_pooled["adjusted_profit_factor"], ">=1.00", pf_at_least(adverse_pooled["adjusted_profit_factor"], 1.0)))
    for symbol in sorted(SYMBOLS):
        gates.append(gate_row(f"ADVERSE_{symbol}_ADJ_NET", symbol_adverse[symbol]["adjusted_net_r"], ">0", symbol_adverse[symbol]["adjusted_net_r"] > 0.0))
    verdict = "MERIT" if all(row["pass"] for row in gates) else "NO_MERIT"
    return gates, verdict


def verify_bindings() -> dict[str, str]:
    observed: dict[str, str] = {}
    for path, expected in BOUND_LOCAL.items():
        if not path.is_file():
            raise AuditError(f"bound source missing: {path}")
        digest = sha256_file(path)
        observed[str(path.resolve())] = digest
        if digest != expected:
            raise AuditError(f"bound source SHA drift: {path}: {digest} != {expected}")
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    if contract.get("analysis_id") != ANALYSIS_ID:
        raise AuditError("analysis_id drift in contract")
    return dict(sorted(observed.items()))


def canonical_json(payload: Mapping[str, Any]) -> bytes:
    return (json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode(
        "utf-8"
    )


def write_atomic(path: Path, payload: Mapping[str, Any]) -> None:
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    data = canonical_json(payload)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


def run_analysis(data_root: Path, news_path: Path) -> dict[str, Any]:
    bindings = verify_bindings()
    blackouts, news_identity = load_news(news_path)
    markets = {
        symbol: parse_selected_market(data_root / spec["file"], symbol)
        for symbol, spec in sorted(SYMBOLS.items())
    }
    structural: dict[str, dict[str, Any]] = {}
    all_trades: dict[str, dict[str, list[Trade]]] = {
        arm: {scenario: [] for scenario in SCENARIOS} for arm in ARMS
    }
    overlays: dict[str, dict[str, dict[str, Any]]] = {
        arm: {scenario: {} for scenario in SCENARIOS} for arm in ARMS
    }
    integrity_issues: list[str] = []

    for symbol, market in markets.items():
        atr = compute_atr(market.bars)
        biases = compute_mtf_bias(market.bars)
        card_signals, card_funnel = generate_card_signals(market.bars, atr)
        source_signals, source_funnel = generate_source_signals(market.bars, atr)
        by_arm = {
            "A_CARD_CENTER": (card_signals, card_funnel),
            "B_SOURCE_FAITHFUL": (source_signals, source_funnel),
        }
        structural[symbol] = {
            arm: {
                "funnel": dict(sorted(funnel.items())),
                "signals": len(signals),
            }
            for arm, (signals, funnel) in by_arm.items()
        }
        for arm, (signals, _funnel) in by_arm.items():
            for scenario in SCENARIOS:
                result = apply_overlay(
                    market=market,
                    signals=signals,
                    biases=biases,
                    blackouts=blackouts,
                    scenario=scenario,
                )
                all_trades[arm][scenario].extend(result.trades)
                integrity_issues.extend(result.integrity_issues)
                overlays[arm][scenario][symbol] = {
                    "funnel": dict(sorted(result.funnel.items())),
                    "trades": len(result.trades),
                }

    arm_reports: dict[str, Any] = {}
    arm_verdicts: dict[str, str] = {}
    for arm in ARMS:
        scenarios: dict[str, Any] = {}
        for scenario in SCENARIOS:
            trades = all_trades[arm][scenario]
            scenarios[scenario] = {
                "pooled": performance(trades),
                "by_symbol": breakdown(trades, "symbol"),
                "by_side": breakdown(trades, "side"),
                "by_year": breakdown(trades, "year"),
                "by_symbol_year": breakdown(trades, "symbol_year"),
                "trades": [asdict(row) for row in sorted(trades, key=lambda item: (item.entry_timestamp, item.symbol, item.structural_id))],
            }
        gates, verdict = evaluate_gates(all_trades[arm]["CENTER"], all_trades[arm]["ADVERSE"])
        arm_reports[arm] = {"scenarios": scenarios, "gates": gates, "verdict": verdict}
        arm_verdicts[arm] = verdict

    future_flags = {
        symbol: market.identity.future_ohlc_parsed for symbol, market in markets.items()
    }
    integrity_status = (
        "PASS"
        if not integrity_issues and not any(future_flags.values())
        else "REJECT"
    )
    family_verdict = "FAMILYWISE_MERIT" if any(value == "MERIT" for value in arm_verdicts.values()) else "NO_FAMILYWISE_MERIT"
    return {
        "analysis_id": ANALYSIS_ID,
        "artifact_type": "QM5_10253_TWO_ARM_OFFLINE_FULL_DEV_RESULT",
        "contract": {
            "path": str(CONTRACT_PATH.resolve()),
            "commit": CONTRACT_COMMIT,
            "sha256": EXPECTED_CONTRACT_SHA256,
        },
        "integrity": {
            "status": integrity_status,
            "issues": integrity_issues,
            "future_ohlc_parsed": any(future_flags.values()),
            "future_ohlc_parsed_by_symbol": future_flags,
            "tool_sha256": sha256_file(TOOL_PATH),
            "source_bindings": bindings,
        },
        "market_slices": {
            symbol: asdict(market.identity) for symbol, market in markets.items()
        },
        "news": news_identity,
        "fixed_inputs": {
            "arms": list(ARMS),
            "scenarios": list(SCENARIOS),
            "symbols": SYMBOLS,
            "risk_usd": 1000,
            "full_common_years": list(FULL_YEARS),
            "familywise_z": 2.241402727604947,
        },
        "structural_funnels": structural,
        "execution_funnels": overlays,
        "arms": arm_reports,
        "arm_verdicts": arm_verdicts,
        "family_verdict": family_verdict,
        "selection": "NONE_PREREGISTERED_ARMS_REPORTED_SEPARATELY",
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", type=Path, default=DEFAULT_DATA_ROOT)
    parser.add_argument("--news", type=Path, default=DEFAULT_NEWS_PATH)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        payload = run_analysis(args.data_root, args.news)
        if payload["integrity"]["status"] != "PASS":
            raise AuditError(f"integrity rejected: {payload['integrity']['issues']}")
        write_atomic(args.output, payload)
        print(json.dumps({
            "status": "PASS",
            "output": str(args.output.resolve()),
            "sha256": sha256_file(args.output),
            "family_verdict": payload["family_verdict"],
            "arm_verdicts": payload["arm_verdicts"],
            "future_ohlc_parsed": payload["integrity"]["future_ohlc_parsed"],
        }, sort_keys=True))
        return 0
    except (AuditError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"status": "REJECT", "error_type": type(exc).__name__, "error": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
