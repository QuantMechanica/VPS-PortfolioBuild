"""Research-only HYP-1 feature core. No file loading, P&L or admission logic.

Callers must supply an independently authenticated daily calendar, including
explicit CLOSED and MISSING days. This module cannot certify archive coverage.
The implementation remains subject to independent review before empirical use.
"""
from __future__ import annotations

from bisect import bisect_left
from collections import deque
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from math import hypot, isfinite, log
from statistics import median
from typing import Iterable
from zoneinfo import ZoneInfo

UTC = timezone.utc
NY = ZoneInfo("America/New_York")
TARGETS = frozenset({13213, 10706, 10700})
WARMUP_START = date(2018, 1, 1)
OBSERVATION_START = date(2019, 2, 6)
OBSERVATION_END = date(2024, 12, 31)


@dataclass(frozen=True)
class DailyClose:
    day: date
    close: float | None
    quality: str  # VALID, CLOSED, or MISSING; never infer CLOSED from absence.


@dataclass(frozen=True)
class Evaluation:
    day: date
    available_at_utc: datetime
    regime: str
    rv5: float | None
    prior60_median: float | None
    hold: int
    signal_available: bool
    nominal_multiplier: float
    gap: bool


@dataclass(frozen=True)
class EntryTag:
    ea_id: int
    entry_at_utc: datetime
    source_day: date | None
    nominal_multiplier: float | None
    signal_available: bool
    reason: str
    feature_gap: bool


def server_to_utc(value: datetime) -> datetime:
    """Convert naive server wall time under the evidenced NY+7 convention.

    Ambiguous/nonexistent wall times fail rather than silently selecting a DST
    fold. Do not import book_exposure.py: its top level reads real trade files.
    """
    if value.tzinfo is not None:
        raise ValueError("server wall time must be naive; UTC is a different input")
    ny_wall = value - timedelta(hours=7)
    possibilities = set()
    for fold in (0, 1):
        utc = ny_wall.replace(tzinfo=NY, fold=fold).astimezone(UTC)
        if utc.astimezone(NY).replace(tzinfo=None) == ny_wall:
            possibilities.add(utc)
    if len(possibilities) != 1:
        raise ValueError("ambiguous or nonexistent server wall time")
    return possibilities.pop()


def bar_available_at(day: date) -> datetime:
    # The last observed minute is not proof that the calendar-day bar is closed.
    return server_to_utc(datetime.combine(day + timedelta(days=1), datetime.min.time()))


def transition(hold: int, regime: str) -> int:
    if hold not in (0, 1, 2, 3):
        raise ValueError("invalid HYP-1 hold counter")
    if regime == "HIGH":
        return 3
    if regime == "LOW":
        return 0
    if regime == "NORMAL":
        return max(hold - 1, 0)
    if regime in {"UNAVAILABLE", "CLOSED"}:
        return hold
    raise ValueError("unknown regime")


def classify(rv5: float, prior60_median: float) -> str:
    if not all(isfinite(v) and v >= 0 for v in (rv5, prior60_median)):
        raise ValueError("volatility measures must be finite and nonnegative")
    if rv5 > 1.5 * prior60_median:
        return "HIGH"
    if rv5 < 0.8 * prior60_median:
        return "LOW"
    return "NORMAL"


def evaluate(rows: Iterable[DailyClose]) -> tuple[Evaluation, ...]:
    """Evaluate the fixed RV5/prior60 contract on qualified daily closes.

    Missing or invalid observations invalidate windows crossing that gap;
    neither prices nor returns are imputed. The latent hold counter persists.
    Known closed days do not create returns or consume evaluation intervals.
    """
    closes: deque[float] = deque(maxlen=6)
    prior_rvs: deque[float] = deque(maxlen=60)
    out: list[Evaluation] = []
    previous: date | None = None
    hold, available, gap = 0, False, False
    for row in rows:
        if not WARMUP_START <= row.day <= OBSERVATION_END:
            raise ValueError("price date outside the frozen 2018-2024 input window")
        if previous is not None and row.day != previous + timedelta(days=1):
            raise ValueError("calendar must be contiguous, unique and ordered")
        previous = row.day
        if row.quality not in {"VALID", "CLOSED", "MISSING"}:
            raise ValueError("unqualified daily close")
        if row.quality != "VALID" and row.close is not None:
            raise ValueError("CLOSED/MISSING cannot carry a price")
        rv = med = None
        if row.quality == "CLOSED":
            regime = "CLOSED"
        elif (row.quality == "MISSING" or row.close is None
              or not isfinite(row.close) or row.close <= 0):
            closes.clear()
            prior_rvs.clear()
            regime, available, gap = "UNAVAILABLE", False, True
        else:
            closes.append(row.close)
            regime, available = "UNAVAILABLE", False
            if len(closes) == 6:
                values = tuple(closes)
                rv = hypot(*(log(values[i]) - log(values[i - 1]) for i in range(1, 6)))
                if len(prior_rvs) == 60:
                    med = median(prior_rvs)
                    regime, available, gap = classify(rv, med), True, False
                # Append AFTER evaluating so the current RV cannot enter MED60.
                prior_rvs.append(rv)
        hold = transition(hold, regime)
        out.append(Evaluation(row.day, bar_available_at(row.day), regime, rv, med,
                              hold, available, 0.5 if hold else 1.0, gap))
    return tuple(out)


def tag_entry(ea_id: int, entry_server: datetime,
              evaluations: tuple[Evaluation, ...]) -> EntryTag:
    """Tag an entry only. No outcome fields, lot rounding or open-position resize.

    Nominal size persists during missing evaluations as the accepted HYP-1
    contract specifies, but signal_available=False and feature_gap=True expose
    unresolved observations. Such tags are not complete account evidence.
    """
    if not OBSERVATION_START <= entry_server.date() <= OBSERVATION_END:
        raise ValueError("entry outside the frozen descriptive window")
    entry = server_to_utc(entry_server)
    cutoffs = tuple(e.available_at_utc for e in evaluations)
    if any(a >= b for a, b in zip(cutoffs, cutoffs[1:])):
        raise ValueError("feature cutoffs must be strictly ordered")
    index = bisect_left(cutoffs, entry) - 1  # Strict cutoff < entry, including midnight.
    covered = bool(evaluations) and (
        evaluations[0].day < entry_server.date() <= evaluations[-1].day + timedelta(days=1)
    )
    source = evaluations[index] if index >= 0 and covered else None
    if ea_id not in TARGETS:
        return EntryTag(ea_id, entry, source.day if source else None, 1.0,
                        bool(source and source.signal_available), "UNTARGETED", bool(source and source.gap))
    if source is None:
        return EntryTag(ea_id, entry, None, None, False, "OUTSIDE_FEATURE_COVERAGE", True)
    return EntryTag(ea_id, entry, source.day, source.nominal_multiplier,
                    source.signal_available,
                    "AVAILABLE" if source.signal_available else "UNAVAILABLE",
                    source.gap)
