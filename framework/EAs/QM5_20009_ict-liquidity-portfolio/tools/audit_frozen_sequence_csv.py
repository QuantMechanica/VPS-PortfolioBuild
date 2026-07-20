"""Read-only M5 CSV audit for the frozen QM5_20009 FX sequence.

The command has no default data location and never discovers files.  A caller
must provide one literal CSV path, an explicit New-York date interval, symbol
price units, and a model.  Output is one canonical JSON document on stdout;
the command never writes an evidence file or mutates MT5 state.

Two reference constructions are available while sharing one exact sequence
implementation:

* ``weekly-fx`` reproduces frozen-v4 Sleeve B: previous NY trading-week
  PWH/PWL, London then New-York cells, one consumed attempt per week.
* ``daily-london`` is the bounded diagnostic candidate: prior Asian range as
  both swept range and opposite-boundary target, London cell only, one
  consumed attempt per NY day.

The post-touch outcome section is deliberately non-binding.  It uses only M5
OHLC, resolves a same-bar SL/TP conflict as SL first, and approximates the
16:00 NY hard flat at the first available bar open.  It is not a tick backtest.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any, Iterable, Sequence


SCHEMA_VERSION = 1
ARTIFACT_TYPE = "QM5_20009_FROZEN_SEQUENCE_CSV_AUDIT"
TIMEFRAME_SECONDS = 5 * 60
REPLAY_BARS_FX = 10_000

# Frozen-v4 Sleeve-B centre.  These are intentionally not CLI dimensions.
PIVOT_WING = 2
RECLAIM_BARS = 3
MAX_BARS_TO_MSS = 12
MIN_FVG_SMA_TR14 = 0.05
SL_BUFFER_SMA_TR14 = 0.10
MIN_RR = 2.0

SESSION_LONDON = 2
SESSION_NEW_YORK = 3
LONDON_START = 2 * 60
LONDON_END = 5 * 60
NEW_YORK_START = 7 * 60
NEW_YORK_END = 10 * 60
ASIA_START = 20 * 60
ASIA_END = 24 * 60
HARD_FLAT_NY_MINUTE = 16 * 60


class AuditError(ValueError):
    """Input or audit-contract violation."""


@dataclass(frozen=True)
class Bar:
    timestamp: int
    broker_time: datetime
    ny_time: datetime
    open: float
    high: float
    low: float
    close: float
    spread_points: int

    @property
    def ny_date(self) -> date:
        return self.ny_time.date()

    @property
    def ny_minute(self) -> int:
        return self.ny_time.hour * 60 + self.ny_time.minute


@dataclass(frozen=True)
class LevelRange:
    low: float
    high: float
    bars: int
    distinct_dates: int = 0


@dataclass
class SequenceResult:
    outcome: str = "NO_EVENT"
    consumed: bool = False
    ambiguous: bool = False
    signal_valid: bool = False
    budget_key: int = 0
    session: int = 0
    ny_date: date | None = None
    session_start_minute: int = 0
    session_end_minute: int = 0
    direction: int = 0
    penetration_index: int | None = None
    reclaim_index: int | None = None
    pivot_index: int | None = None
    mss_index: int | None = None
    fvg_index: int | None = None
    swept_extreme: float = 0.0
    pivot_price: float = 0.0
    entry: float = 0.0
    stop: float = 0.0
    target: float = 0.0
    sma_tr14: float = 0.0
    observed_spread: float = 0.0
    rr: float = 0.0


@dataclass(frozen=True)
class AuditConfig:
    csv_path: Path
    symbol: str
    mode: str
    from_ny_date: date
    to_ny_date: date
    tick_size: float
    point: float
    default_spread_points: int | None


@dataclass
class Dataset:
    bars: list[Bar]
    by_ny_date: dict[date, list[int]]
    source: dict[str, Any]


def _canonical_json(payload: Any) -> str:
    return json.dumps(
        payload,
        allow_nan=False,
        ensure_ascii=True,
        separators=(",", ":"),
        sort_keys=True,
    )


def _date_key(value: date) -> int:
    return value.year * 10_000 + value.month * 100 + value.day


def _price(value: float) -> str:
    return f"{value:.8f}"


def _ratio(value: float) -> str:
    return f"{value:.8f}"


def _stamp(value: datetime) -> str:
    return value.strftime("%Y-%m-%dT%H:%M:%S")


def _parse_date(raw: str, field: str) -> date:
    try:
        return date.fromisoformat(raw)
    except ValueError as exc:
        raise AuditError(f"{field} must be YYYY-MM-DD: {raw!r}") from exc


def _parse_timestamp(raw: str, row_number: int) -> tuple[int, datetime]:
    text = raw.strip()
    if text.isdigit():
        timestamp = int(text)
        try:
            broker = datetime(1970, 1, 1) + timedelta(seconds=timestamp)
        except OverflowError as exc:
            raise AuditError(f"row {row_number}: timestamp out of range") from exc
        return timestamp, broker

    normalized = text.replace("T", " ")
    try:
        broker = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise AuditError(
            f"row {row_number}: time must be epoch seconds or a naive ISO timestamp"
        ) from exc
    if broker.tzinfo is not None:
        raise AuditError(f"row {row_number}: timezone-qualified CSV times are forbidden")
    timestamp = int((broker - datetime(1970, 1, 1)).total_seconds())
    return timestamp, broker


def _finite_float(raw: str, field: str, row_number: int) -> float:
    try:
        value = float(raw)
    except ValueError as exc:
        raise AuditError(f"row {row_number}: invalid {field}: {raw!r}") from exc
    if not math.isfinite(value):
        raise AuditError(f"row {row_number}: non-finite {field}")
    return value


def _spread_points(raw: str, row_number: int) -> int:
    value = _finite_float(raw, "spread", row_number)
    if value < 0.0 or not value.is_integer():
        raise AuditError(f"row {row_number}: spread must be a non-negative integer")
    return int(value)


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _literal_file(path: Path) -> Path:
    raw = str(path)
    if any(character in raw for character in "*?[]"):
        raise AuditError("CSV path must be literal; wildcard/glob syntax is forbidden")
    resolved = path.expanduser().resolve(strict=False)
    if not resolved.is_file():
        raise AuditError(f"CSV path is not a file: {resolved}")
    return resolved


def load_dataset(config: AuditConfig) -> Dataset:
    """Load one explicit CSV, retaining no bars after the declared NY end date."""

    path = _literal_file(config.csv_path)
    bars: list[Bar] = []
    by_date: dict[date, list[int]] = defaultdict(list)
    rows_total = 0
    rows_after_end = 0
    previous_timestamp: int | None = None
    spread_column = ""

    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise AuditError("CSV has no header")
        normalized: dict[str, str] = {}
        for original in reader.fieldnames:
            key = original.strip().lower()
            if key in normalized:
                raise AuditError(f"duplicate normalized CSV column: {key}")
            normalized[key] = original
        required = {"time", "open", "high", "low", "close"}
        missing = sorted(required - normalized.keys())
        if missing:
            raise AuditError(f"CSV missing required columns: {', '.join(missing)}")
        if "spread" in normalized:
            spread_column = normalized["spread"]
        elif "spread_points" in normalized:
            spread_column = normalized["spread_points"]
        elif config.default_spread_points is None:
            raise AuditError(
                "CSV has no spread column; --default-spread-points must be explicit"
            )

        for row_number, row in enumerate(reader, start=2):
            rows_total += 1
            timestamp, broker = _parse_timestamp(row[normalized["time"]], row_number)
            if previous_timestamp is not None and timestamp <= previous_timestamp:
                raise AuditError(f"row {row_number}: timestamps are not strictly increasing")
            previous_timestamp = timestamp
            if timestamp % TIMEFRAME_SECONDS != 0:
                raise AuditError(f"row {row_number}: timestamp is not aligned to M5")

            open_price = _finite_float(row[normalized["open"]], "open", row_number)
            high = _finite_float(row[normalized["high"]], "high", row_number)
            low = _finite_float(row[normalized["low"]], "low", row_number)
            close = _finite_float(row[normalized["close"]], "close", row_number)
            if min(open_price, high, low, close) <= 0.0:
                raise AuditError(f"row {row_number}: OHLC prices must be positive")
            if high < max(open_price, close, low) or low > min(open_price, close, high):
                raise AuditError(f"row {row_number}: invalid OHLC ordering")

            if spread_column and row.get(spread_column, "").strip() != "":
                spread = _spread_points(row[spread_column], row_number)
            elif config.default_spread_points is not None:
                spread = config.default_spread_points
            else:
                raise AuditError(f"row {row_number}: spread is blank and no fallback was supplied")

            # Frozen Darwinex convention: broker time is always NY + 7 hours
            # because broker UTC+2/+3 follows the same US-DST boundary as NY.
            ny_time = broker - timedelta(hours=7)
            if ny_time.date() > config.to_ny_date:
                rows_after_end += 1
                continue
            index = len(bars)
            bars.append(
                Bar(
                    timestamp=timestamp,
                    broker_time=broker,
                    ny_time=ny_time,
                    open=open_price,
                    high=high,
                    low=low,
                    close=close,
                    spread_points=spread,
                )
            )
            by_date[ny_time.date()].append(index)

    if not bars:
        raise AuditError("CSV contains no bars on or before the requested end date")
    return Dataset(
        bars=bars,
        by_ny_date=dict(by_date),
        source={
            "csv_path": str(path),
            "csv_sha256": _sha256_file(path),
            "csv_rows_total": rows_total,
            "csv_rows_loaded_through_end_date": len(bars),
            "csv_rows_after_end_date_not_used": rows_after_end,
            "first_loaded_broker_time": _stamp(bars[0].broker_time),
            "last_loaded_broker_time": _stamp(bars[-1].broker_time),
            "spread_source": (
                f"CSV_COLUMN:{spread_column}"
                if spread_column
                else f"EXPLICIT_DEFAULT_POINTS:{config.default_spread_points}"
            ),
        },
    )


def _event_bar_in_session(
    bar: Bar,
    ny_date: date,
    start_minute: int,
    end_minute: int,
) -> bool:
    if bar.ny_date != ny_date:
        return False
    close_time = bar.ny_time + timedelta(seconds=TIMEFRAME_SECONDS)
    if close_time.date() != ny_date:
        return False
    close_minute = close_time.hour * 60 + close_time.minute
    # Exact frozen rule: a decision whose bar closes exactly at the half-open
    # session end is outside the event window.
    return bar.ny_minute >= start_minute and close_minute < end_minute


def _window_indices(
    dataset: Dataset,
    ny_date: date,
    start_minute: int,
    end_minute: int,
    *,
    event_window: bool,
) -> list[int]:
    indices = dataset.by_ny_date.get(ny_date, [])
    if event_window:
        return [
            index
            for index in indices
            if _event_bar_in_session(dataset.bars[index], ny_date, start_minute, end_minute)
        ]
    return [
        index
        for index in indices
        if start_minute <= dataset.bars[index].ny_minute < end_minute
    ]


def _collect_range(
    dataset: Dataset,
    ny_date: date,
    start_minute: int,
    end_minute: int,
    expected_bars: int,
) -> LevelRange | None:
    indices = _window_indices(
        dataset,
        ny_date,
        start_minute,
        end_minute,
        event_window=False,
    )
    if len(indices) != expected_bars:
        return None
    low = min(dataset.bars[index].low for index in indices)
    high = max(dataset.bars[index].high for index in indices)
    if low <= 0.0 or high <= low:
        return None
    return LevelRange(low=low, high=high, bars=len(indices), distinct_dates=1)


def _trading_week_key(bar: Bar) -> date:
    # Python weekday: Monday=0, Sunday=6.
    days_back = (bar.ny_time.weekday() + 1) % 7
    if bar.ny_time.weekday() == 6 and bar.ny_minute < 17 * 60:
        days_back = 7
    return bar.ny_date - timedelta(days=days_back)


def _observed_trading_week_bar(bar: Bar) -> bool:
    weekday = bar.ny_time.weekday()
    if weekday == 6:
        return bar.ny_minute >= 17 * 60
    if weekday <= 3:
        return True
    if weekday == 4:
        return bar.ny_minute < 17 * 60
    return False


def _collect_previous_week(dataset: Dataset, week_key: date) -> LevelRange | None:
    indices = [
        index
        for index, bar in enumerate(dataset.bars)
        if _trading_week_key(bar) == week_key and _observed_trading_week_bar(bar)
    ]
    distinct_dates = {dataset.bars[index].ny_date for index in indices}
    if not indices or len(distinct_dates) < 3:
        return None
    low = min(dataset.bars[index].low for index in indices)
    high = max(dataset.bars[index].high for index in indices)
    if low <= 0.0 or high <= low:
        return None
    return LevelRange(
        low=low,
        high=high,
        bars=len(indices),
        distinct_dates=len(distinct_dates),
    )


def _strict_pivot(
    bars: Sequence[Bar],
    count: int,
    index: int,
    wing: int,
    *,
    want_high: bool,
) -> bool:
    if wing < 1 or index - wing < 0 or index + wing >= count:
        return False
    value = bars[index].high if want_high else bars[index].low
    for distance in range(1, wing + 1):
        before = bars[index - distance].high if want_high else bars[index - distance].low
        after = bars[index + distance].high if want_high else bars[index + distance].low
        if want_high:
            if value <= before or value <= after:
                return False
        elif value >= before or value >= after:
            return False
    return True


def _latest_pre_penetration_pivot(
    bars: Sequence[Bar],
    count: int,
    penetration_index: int,
    *,
    want_high: bool,
    history_first_index: int,
) -> int | None:
    first_pivot = max(PIVOT_WING, history_first_index + PIVOT_WING)
    for index in range(penetration_index - PIVOT_WING - 1, first_pivot - 1, -1):
        if _strict_pivot(
            bars,
            count,
            index,
            PIVOT_WING,
            want_high=want_high,
        ):
            return index
    return None


def _sma_tr14(
    bars: Sequence[Bar],
    count: int,
    index: int,
    history_first_index: int,
) -> float | None:
    if index - history_first_index < 14 or index >= count:
        return None
    total = 0.0
    for cursor in range(index - 13, index + 1):
        previous_close = bars[cursor - 1].close
        true_range = max(
            bars[cursor].high - bars[cursor].low,
            abs(bars[cursor].high - previous_close),
            abs(bars[cursor].low - previous_close),
        )
        if true_range < 0.0 or not math.isfinite(true_range):
            return None
        total += true_range
    average = total / 14.0
    return average if average > 0.0 and math.isfinite(average) else None


def _find_reclaim(
    bars: Sequence[Bar],
    penetration_index: int,
    direction: int,
    frozen_low: float,
    frozen_high: float,
    ny_date: date,
    session_start: int,
    session_end: int,
    event_last_index: int,
) -> tuple[int, float] | None:
    swept_extreme = (
        bars[penetration_index].low if direction > 0 else bars[penetration_index].high
    )
    last = min(event_last_index, penetration_index + RECLAIM_BARS)
    for index in range(penetration_index, last + 1):
        if not _event_bar_in_session(bars[index], ny_date, session_start, session_end):
            break
        if direction > 0:
            swept_extreme = min(swept_extreme, bars[index].low)
            if bars[index].close > frozen_low:
                return index, swept_extreme
        else:
            swept_extreme = max(swept_extreme, bars[index].high)
            if bars[index].close < frozen_high:
                return index, swept_extreme
    return None


def build_sequence(
    dataset: Dataset,
    *,
    ny_date: date,
    budget_key: int,
    session: int,
    session_start: int,
    session_end: int,
    frozen_low: float,
    frozen_high: float,
    target_long: float,
    target_short: float,
    tick_size: float,
    point: float,
    event_indices: Sequence[int],
) -> SequenceResult:
    """Port of ICT_BuildSequence for the frozen Sleeve-B centre parameters."""

    result = SequenceResult(
        budget_key=budget_key,
        session=session,
        ny_date=ny_date,
        session_start_minute=session_start,
        session_end_minute=session_end,
    )
    if not event_indices:
        return result
    event_first = event_indices[0]
    event_last = event_indices[-1]
    count = event_last + 1  # only bars closed by the end of this session exist to the EA
    history_first = max(0, count - REPLAY_BARS_FX)
    if (
        count < 20
        or event_first > event_last
        or frozen_low <= 0.0
        or frozen_high <= frozen_low
        or target_long <= 0.0
        or target_short <= 0.0
        or tick_size <= 0.0
        or point <= 0.0
    ):
        result.outcome = "INVALID_FROZEN_LEVELS"
        return result

    bars = dataset.bars
    best_penetration: int | None = None
    best_reclaim: int | None = None
    best_direction = 0
    best_extreme = 0.0

    for penetration in range(event_first, event_last + 1):
        if not _event_bar_in_session(
            bars[penetration], ny_date, session_start, session_end
        ):
            continue
        low_penetration = bars[penetration].low <= frozen_low - tick_size
        high_penetration = bars[penetration].high >= frozen_high + tick_size
        if low_penetration and high_penetration:
            if best_reclaim is None or penetration <= best_reclaim:
                result.consumed = True
                result.ambiguous = True
                result.penetration_index = penetration
                result.outcome = "AMBIGUOUS_DOUBLE_PENETRATION"
                return result
            break

        for direction, penetrated in ((1, low_penetration), (-1, high_penetration)):
            if not penetrated:
                continue
            reclaim = _find_reclaim(
                bars,
                penetration,
                direction,
                frozen_low,
                frozen_high,
                ny_date,
                session_start,
                session_end,
                event_last,
            )
            if reclaim is None:
                continue
            reclaim_index, swept_extreme = reclaim
            if best_reclaim is None or reclaim_index < best_reclaim:
                best_penetration = penetration
                best_reclaim = reclaim_index
                best_direction = direction
                best_extreme = swept_extreme
            elif reclaim_index == best_reclaim and direction != best_direction:
                result.consumed = True
                result.ambiguous = True
                result.reclaim_index = reclaim_index
                result.outcome = "AMBIGUOUS_RECLAIM_TIE"
                return result

    if best_reclaim is None or best_penetration is None:
        return result

    result.consumed = True
    result.direction = best_direction
    result.penetration_index = best_penetration
    result.reclaim_index = best_reclaim
    result.swept_extreme = best_extreme
    result.outcome = "RECLAIM_CONSUMED"

    pivot_index = _latest_pre_penetration_pivot(
        bars,
        count,
        best_penetration,
        want_high=best_direction > 0,
        history_first_index=history_first,
    )
    if pivot_index is None:
        result.outcome = "NO_CONFIRMED_PRE_SWEEP_PIVOT"
        return result
    result.pivot_index = pivot_index
    result.pivot_price = bars[pivot_index].high if best_direction > 0 else bars[pivot_index].low

    last_mss = min(event_last, best_reclaim + MAX_BARS_TO_MSS)
    for index in range(best_reclaim + 1, last_mss + 1):
        if not _event_bar_in_session(bars[index], ny_date, session_start, session_end):
            break
        shifted = (
            bars[index].close > result.pivot_price
            if best_direction > 0
            else bars[index].close < result.pivot_price
        )
        if shifted:
            result.mss_index = index
            break
    if result.mss_index is None:
        result.outcome = "NO_LATER_MSS"
        return result

    proximal_edge = 0.0
    for index in range(result.mss_index + 1, event_last + 1):
        if not _event_bar_in_session(bars[index], ny_date, session_start, session_end):
            break
        average = _sma_tr14(bars, count, index, history_first)
        if average is None:
            continue
        gap = (
            bars[index].low - bars[index - 2].high
            if best_direction > 0
            else bars[index - 2].low - bars[index].high
        )
        minimum_gap = MIN_FVG_SMA_TR14 * average
        epsilon = max(1.0, abs(minimum_gap)) * 1e-12
        if gap <= 0.0 or gap + epsilon < minimum_gap:
            continue
        result.fvg_index = index
        result.sma_tr14 = average
        proximal_edge = bars[index].low if best_direction > 0 else bars[index].high
        break
    if result.fvg_index is None:
        result.outcome = "NO_POST_MSS_FVG"
        return result

    result.observed_spread = max(
        bars[index].spread_points * point
        for index in range(best_penetration, result.fvg_index + 1)
    )
    stop_padding = max(
        2.0 * result.observed_spread,
        SL_BUFFER_SMA_TR14 * result.sma_tr14,
    )
    result.entry = proximal_edge
    result.stop = (
        best_extreme - stop_padding if best_direction > 0 else best_extreme + stop_padding
    )
    result.target = target_long if best_direction > 0 else target_short
    risk = abs(result.entry - result.stop)
    reward = (
        result.target - result.entry
        if best_direction > 0
        else result.entry - result.target
    )
    result.rr = reward / risk if risk > 0.0 else 0.0
    if risk <= 0.0 or reward <= 0.0 or result.rr + 1e-12 < MIN_RR:
        result.outcome = "INVALID_FIXED_TARGET_OR_R"
        return result

    result.signal_valid = True
    result.outcome = "EARLIEST_FVG_READY"
    return result


def _session_name(session: int) -> str:
    return "LONDON" if session == SESSION_LONDON else "NEW_YORK"


def _signal_identity(dataset: Dataset, result: SequenceResult) -> dict[str, Any]:
    assert result.ny_date is not None
    assert result.penetration_index is not None
    assert result.reclaim_index is not None
    assert result.pivot_index is not None
    assert result.mss_index is not None
    assert result.fvg_index is not None
    bars = dataset.bars
    return {
        "budget_key": result.budget_key,
        "direction": "LONG" if result.direction > 0 else "SHORT",
        "entry": _price(result.entry),
        "fvg_bar_open_broker": _stamp(bars[result.fvg_index].broker_time),
        "fvg_bar_open_ny": _stamp(bars[result.fvg_index].ny_time),
        "mss_bar_open_broker": _stamp(bars[result.mss_index].broker_time),
        "ny_date": result.ny_date.isoformat(),
        "observed_spread_price": _price(result.observed_spread),
        "penetration_bar_open_broker": _stamp(
            bars[result.penetration_index].broker_time
        ),
        "pivot_bar_open_broker": _stamp(bars[result.pivot_index].broker_time),
        "reclaim_bar_open_broker": _stamp(bars[result.reclaim_index].broker_time),
        "rr": _ratio(result.rr),
        "session": _session_name(result.session),
        "session_code": result.session,
        "sma_tr14": _price(result.sma_tr14),
        "stop": _price(result.stop),
        "swept_extreme": _price(result.swept_extreme),
        "target": _price(result.target),
    }


def _post_touch_outcome(
    dataset: Dataset,
    result: SequenceResult,
    touch_index: int,
    point: float,
) -> dict[str, Any]:
    assert result.ny_date is not None
    bars = dataset.bars
    risk = abs(result.entry - result.stop)
    for index in range(touch_index, len(bars)):
        bar = bars[index]
        if bar.ny_date != result.ny_date:
            break
        if bar.ny_minute >= HARD_FLAT_NY_MINUTE:
            exit_price = (
                bar.open
                if result.direction > 0
                else bar.open + bar.spread_points * point
            )
            r_multiple = (
                (exit_price - result.entry) / risk
                if result.direction > 0
                else (result.entry - exit_price) / risk
            )
            return {
                "exit_bar_open_broker": _stamp(bar.broker_time),
                "exit_price": _price(exit_price),
                "r_multiple": _ratio(r_multiple),
                "same_bar_sl_tp_conflict": False,
                "status": "HARD_FLAT_16_NY",
            }

        spread = bar.spread_points * point
        if result.direction > 0:
            stop_hit = bar.low <= result.stop
            target_hit = bar.high >= result.target
        else:
            stop_hit = bar.high + spread >= result.stop
            target_hit = bar.low + spread <= result.target
        if stop_hit:
            return {
                "exit_bar_open_broker": _stamp(bar.broker_time),
                "exit_price": _price(result.stop),
                "r_multiple": _ratio(-1.0),
                "same_bar_sl_tp_conflict": bool(target_hit),
                "status": "SL",
            }
        if target_hit:
            return {
                "exit_bar_open_broker": _stamp(bar.broker_time),
                "exit_price": _price(result.target),
                "r_multiple": _ratio(result.rr),
                "same_bar_sl_tp_conflict": False,
                "status": "TP",
            }
    return {
        "exit_bar_open_broker": None,
        "exit_price": None,
        "r_multiple": None,
        "same_bar_sl_tp_conflict": False,
        "status": "UNRESOLVED_BEFORE_DATA_END",
    }


def _touch_diagnostic(
    dataset: Dataset,
    result: SequenceResult,
    point: float,
) -> dict[str, Any]:
    assert result.signal_valid and result.fvg_index is not None and result.ny_date is not None
    bars = dataset.bars
    eligibility_index = result.fvg_index + 1
    base: dict[str, Any] = {
        "eligibility_bar_open_broker": None,
        "fresh_at_eligibility_ohlc": False,
        "touch_bar_open_broker": None,
        "touched_ohlc": False,
    }
    if eligibility_index >= len(bars):
        base["fresh_status"] = "NO_SUBSEQUENT_BAR"
        return base
    eligibility = bars[eligibility_index]
    if (
        eligibility.ny_date != result.ny_date
        or eligibility.ny_minute >= result.session_end_minute
    ):
        base["fresh_status"] = "SESSION_CLOSED_BEFORE_ELIGIBILITY_BAR"
        return base

    base["eligibility_bar_open_broker"] = _stamp(eligibility.broker_time)
    spread = eligibility.spread_points * point
    fresh = (
        eligibility.open + spread > result.entry
        if result.direction > 0
        else eligibility.open < result.entry
    )
    base["fresh_at_eligibility_ohlc"] = fresh
    if not fresh:
        base["fresh_status"] = "EDGE_ALREADY_TOUCHED_AT_ELIGIBILITY_OPEN"
        return base
    base["fresh_status"] = "FRESH"

    for index in range(eligibility_index, len(bars)):
        bar = bars[index]
        if bar.ny_date != result.ny_date or bar.ny_minute >= result.session_end_minute:
            break
        spread = bar.spread_points * point
        touched = (
            bar.low + spread <= result.entry
            if result.direction > 0
            else bar.high >= result.entry
        )
        if not touched:
            continue
        base["touch_bar_open_broker"] = _stamp(bar.broker_time)
        base["touched_ohlc"] = True
        base["approximate_outcome"] = _post_touch_outcome(dataset, result, index, point)
        return base
    return base


def _daily_results(
    dataset: Dataset,
    config: AuditConfig,
) -> tuple[list[SequenceResult], dict[str, int]]:
    results: list[SequenceResult] = []
    counters: Counter[str] = Counter()
    current = config.from_ny_date
    while current <= config.to_ny_date:
        if current.weekday() < 5:
            counters["budgets_total"] += 1
            reference = _collect_range(
                dataset,
                current - timedelta(days=1),
                ASIA_START,
                ASIA_END,
                48,
            )
            if reference is None:
                results.append(
                    SequenceResult(
                        outcome="ASIAN_REFERENCE_INCOMPLETE",
                        budget_key=_date_key(current),
                        ny_date=current,
                        session=SESSION_LONDON,
                    )
                )
                counters["reference_incomplete"] += 1
            else:
                counters["reference_ready"] += 1
                event_indices = _window_indices(
                    dataset,
                    current,
                    LONDON_START,
                    LONDON_END,
                    event_window=True,
                )
                counters["sessions_evaluated"] += int(bool(event_indices))
                results.append(
                    build_sequence(
                        dataset,
                        ny_date=current,
                        budget_key=_date_key(current),
                        session=SESSION_LONDON,
                        session_start=LONDON_START,
                        session_end=LONDON_END,
                        frozen_low=reference.low,
                        frozen_high=reference.high,
                        target_long=reference.high,
                        target_short=reference.low,
                        tick_size=config.tick_size,
                        point=config.point,
                        event_indices=event_indices,
                    )
                )
        current += timedelta(days=1)
    return results, dict(counters)


def _first_sunday_on_or_after(value: date) -> date:
    return value + timedelta(days=(6 - value.weekday()) % 7)


def _weekly_results(
    dataset: Dataset,
    config: AuditConfig,
) -> tuple[list[SequenceResult], dict[str, int]]:
    results: list[SequenceResult] = []
    counters: Counter[str] = Counter()
    week_key = _first_sunday_on_or_after(config.from_ny_date)
    while week_key <= config.to_ny_date:
        counters["budgets_total"] += 1
        previous = _collect_previous_week(dataset, week_key - timedelta(days=7))
        if previous is None:
            results.append(
                SequenceResult(
                    outcome="PREVIOUS_WEEK_INCOMPLETE",
                    budget_key=_date_key(week_key),
                    ny_date=week_key,
                )
            )
            counters["reference_incomplete"] += 1
            week_key += timedelta(days=7)
            continue
        counters["reference_ready"] += 1

        consumed: SequenceResult | None = None
        for day_offset in range(1, 6):
            session_date = week_key + timedelta(days=day_offset)
            if session_date > config.to_ny_date:
                break

            asian = _collect_range(
                dataset,
                session_date - timedelta(days=1),
                ASIA_START,
                ASIA_END,
                48,
            )
            london_events = _window_indices(
                dataset,
                session_date,
                LONDON_START,
                LONDON_END,
                event_window=True,
            )
            if asian is not None and london_events:
                counters["sessions_evaluated"] += 1
                candidate = build_sequence(
                    dataset,
                    ny_date=session_date,
                    budget_key=_date_key(week_key),
                    session=SESSION_LONDON,
                    session_start=LONDON_START,
                    session_end=LONDON_END,
                    frozen_low=previous.low,
                    frozen_high=previous.high,
                    target_long=asian.high,
                    target_short=asian.low,
                    tick_size=config.tick_size,
                    point=config.point,
                    event_indices=london_events,
                )
                if candidate.consumed:
                    consumed = candidate
                    break

            london_reference = _collect_range(
                dataset,
                session_date,
                LONDON_START,
                LONDON_END,
                36,
            )
            new_york_events = _window_indices(
                dataset,
                session_date,
                NEW_YORK_START,
                NEW_YORK_END,
                event_window=True,
            )
            if london_reference is not None and new_york_events:
                counters["sessions_evaluated"] += 1
                candidate = build_sequence(
                    dataset,
                    ny_date=session_date,
                    budget_key=_date_key(week_key),
                    session=SESSION_NEW_YORK,
                    session_start=NEW_YORK_START,
                    session_end=NEW_YORK_END,
                    frozen_low=previous.low,
                    frozen_high=previous.high,
                    target_long=london_reference.high,
                    target_short=london_reference.low,
                    tick_size=config.tick_size,
                    point=config.point,
                    event_indices=new_york_events,
                )
                if candidate.consumed:
                    consumed = candidate
                    break

        if consumed is None:
            consumed = SequenceResult(
                outcome="NO_ELIGIBLE_WEEKLY_RECLAIM",
                budget_key=_date_key(week_key),
                ny_date=week_key,
            )
        results.append(consumed)
        week_key += timedelta(days=7)
    return results, dict(counters)


def _funnel(
    results: Sequence[SequenceResult],
    base: dict[str, int],
    touches: Sequence[dict[str, Any]],
) -> dict[str, int]:
    return {
        "ambiguous": sum(result.ambiguous for result in results),
        "budgets_total": base.get("budgets_total", len(results)),
        "consumed": sum(result.consumed for result in results),
        "fresh_at_eligibility_ohlc": sum(
            bool(touch["fresh_at_eligibility_ohlc"]) for touch in touches
        ),
        "fvg": sum(result.fvg_index is not None for result in results),
        "mss": sum(result.mss_index is not None for result in results),
        "pivot_confirmed": sum(result.pivot_index is not None for result in results),
        "ready": sum(result.signal_valid for result in results),
        "reference_incomplete": base.get("reference_incomplete", 0),
        "reference_ready": base.get("reference_ready", 0),
        "sessions_evaluated": base.get("sessions_evaluated", 0),
        "touched_ohlc": sum(bool(touch["touched_ohlc"]) for touch in touches),
    }


def audit(config: AuditConfig) -> dict[str, Any]:
    if config.mode not in {"weekly-fx", "daily-london"}:
        raise AuditError(f"unsupported mode: {config.mode}")
    if config.from_ny_date > config.to_ny_date:
        raise AuditError("from date must not be after to date")
    if config.tick_size <= 0.0 or config.point <= 0.0:
        raise AuditError("tick size and point must be positive")
    if config.default_spread_points is not None and config.default_spread_points < 0:
        raise AuditError("default spread points must be non-negative")

    dataset = load_dataset(config)
    if config.mode == "weekly-fx":
        results, base = _weekly_results(dataset, config)
    else:
        results, base = _daily_results(dataset, config)

    ready_results = [result for result in results if result.signal_valid]
    touch_rows = [_touch_diagnostic(dataset, result, config.point) for result in ready_results]
    ready: list[dict[str, Any]] = []
    touched: list[dict[str, Any]] = []
    approximate_counts: Counter[str] = Counter()
    approximate_r_total = 0.0
    for result, touch in zip(ready_results, touch_rows, strict=True):
        row = _signal_identity(dataset, result)
        row.update(touch)
        ready.append(row)
        if touch["touched_ohlc"]:
            touched.append(row)
            approximate = touch.get("approximate_outcome")
            if approximate:
                approximate_counts[approximate["status"]] += 1
                if approximate["r_multiple"] is not None:
                    approximate_r_total += float(approximate["r_multiple"])

    outcomes = Counter(result.outcome for result in results)
    return {
        "approximate_post_touch": {
            "basis": (
                "NON_BINDING_M5_OHLC; SAME_BAR_SL_TP_EQUALS_SL_FIRST; "
                "HARD_FLAT_AT_FIRST_BAR_OPEN_AT_OR_AFTER_16:00_NY; "
                "EXTERNAL_COMMISSION_EXCLUDED"
            ),
            "counts": dict(sorted(approximate_counts.items())),
            "resolved_r_multiple_sum": _ratio(approximate_r_total),
        },
        "artifact_type": ARTIFACT_TYPE,
        "audit_mode": config.mode,
        "final_outcomes": dict(sorted(outcomes.items())),
        "frozen_parameters": {
            "max_bars_to_mss": MAX_BARS_TO_MSS,
            "min_fvg_sma_tr14": _ratio(MIN_FVG_SMA_TR14),
            "min_rr": _ratio(MIN_RR),
            "pivot_wing": PIVOT_WING,
            "reclaim_bars": RECLAIM_BARS,
            "replay_bars_fx": REPLAY_BARS_FX,
            "sl_buffer_sma_tr14": _ratio(SL_BUFFER_SMA_TR14),
        },
        "funnel": _funnel(results, base, touch_rows),
        "input": {
            **dataset.source,
            "from_ny_date": config.from_ny_date.isoformat(),
            "point": _price(config.point),
            "symbol": config.symbol,
            "tick_size": _price(config.tick_size),
            "time_basis": "BROKER_MINUS_7_HOURS_FROZEN_DARWINEX_US_DST",
            "to_ny_date": config.to_ny_date.isoformat(),
        },
        "limitations": [
            "READ_ONLY_DIAGNOSTIC_NOT_A_STRATEGY_VERDICT",
            "TOUCH_AND_POST_TOUCH_OUTCOMES_USE_M5_OHLC_NOT_TICKS",
            "NEWS_GOVERNOR_SLIPPAGE_AND_EXTERNAL_COMMISSION_NOT_APPLIED",
            "ONLY_THE_LITERAL_CLI_CSV_PATH_WAS_OPENED",
        ],
        "ready": ready,
        "schema_version": SCHEMA_VERSION,
        "status": "PASS",
        "touched": touched,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", required=True, type=Path, help="literal M5 CSV path")
    parser.add_argument("--symbol", required=True, help="explicit audited symbol label")
    parser.add_argument(
        "--mode",
        required=True,
        choices=("weekly-fx", "daily-london"),
    )
    parser.add_argument("--from-ny-date", required=True)
    parser.add_argument("--to-ny-date", required=True)
    parser.add_argument("--tick-size", required=True, type=float)
    parser.add_argument("--point", required=True, type=float)
    parser.add_argument(
        "--default-spread-points",
        type=int,
        default=None,
        help="explicit fallback required when the CSV has no spread column",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        config = AuditConfig(
            csv_path=args.csv,
            symbol=args.symbol,
            mode=args.mode,
            from_ny_date=_parse_date(args.from_ny_date, "--from-ny-date"),
            to_ny_date=_parse_date(args.to_ny_date, "--to-ny-date"),
            tick_size=args.tick_size,
            point=args.point,
            default_spread_points=args.default_spread_points,
        )
        payload = audit(config)
    except (AuditError, OSError, csv.Error) as exc:
        error = {
            "artifact_type": ARTIFACT_TYPE,
            "error": str(exc),
            "schema_version": SCHEMA_VERSION,
            "status": "ERROR",
        }
        print(_canonical_json(error), file=sys.stderr)
        return 2
    print(_canonical_json(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
