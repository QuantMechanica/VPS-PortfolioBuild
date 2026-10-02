"""Research-only HYP-2 oil-volatility sizing feature core. No file loading, P&L or admission logic.

Implements the binding corrections in ``docs/ops/evidence/2026-09-26_astra_takeover/
hyp2_mechanization/REVIEW.md`` over ``AUTHOR_DELIVERY.md``'s draft contract, for
engineering task ``3aabfc7e-9d1a-4426-b162-d751ea62a364``. Where REVIEW.md and
AUTHOR_DELIVERY.md/its JSON disagree, REVIEW.md governs this implementation:

* RV20 is the root-mean-square of 20 completed log returns (explicitly RMS,
  divisor 20; never a demeaned standard deviation). The exclusive prior median
  uses RV20[t-60..t-1]. Their union requires 81 closes C[t-80..t] inclusive;
  with the first close at index 0, the first eligible state is index 80, not
  79 (REVIEW.md Section 1).
* Daily state machine ("HYS-C" minimum-hold/hysteretic-hold/re-trigger-reset,
  REVIEW.md Section 2) -- distinct from HYP-1's countdown
  (``hyp1_causal_tags.transition``): a HIGH signal always restarts the timer
  at age=0 (including a retrigger while already active); otherwise, while
  active, age advances (capped at 5) and only a LOW signal at age==5 releases
  the floor; a NORMAL (neutral) signal can hold the floor past five intervals
  without releasing it.
* A required missing/nonpositive close, incomplete window or ambiguous
  calendar leaves that evaluation UNAVAILABLE. REVIEW.md Section 3 rejects
  the author's "no modifier applied (default 1.0x)" framing for this case:
  the latent active/age state is retained WITHOUT advancing, and the latent
  multiplier (0.5x if active, else 1.0x) is still reported, exactly mirroring
  ``hyp1_causal_tags.evaluate``'s existing, already-reviewed carry-through
  mechanism for its own countdown counter. ``signal_available=False`` and
  ``gap=True`` separately expose that the day's own evaluation was unresolved;
  every affected day is retained in output, never dropped.
* Reuses ``hyp1_causal_tags.DailyClose``/``server_to_utc``/``bar_available_at``
  (the NY+7 custom-history server-midnight convention is identical across both
  hypotheses, task d4f0b5c5-b65b-426b-aa49-739014353375) instead of
  re-deriving a second clock/record engine (no duplicate engines).

Callers must supply an independently authenticated daily calendar, including
explicit CLOSED and MISSING days (see ``hyp1_inputs.DayCoverage``/
``aggregate_daily``, reused unmodified). This module cannot certify archive
coverage, and computes no trade outcome, P&L or admission verdict. It remains
subject to independent code/protocol review before any outcome calculation;
see ``docs/ops/evidence/task_3aabfc7e-9d1a-4426-b162-d751ea62a364/DELIVERY.md``.
"""
from __future__ import annotations

from bisect import bisect_left
from collections import deque
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from math import isfinite, log, sqrt
from statistics import median
from typing import Iterable

from tools.strategy_farm.research.hyp1_causal_tags import (
    DailyClose, OBSERVATION_START, OBSERVATION_END, WARMUP_START,
    bar_available_at, server_to_utc,
)

GATED_EA_ID = 11422  # QM5_11422 USDCAD.DWX; the sole sized sleeve (AUTHOR_DELIVERY.md Section 5).
RV_LOOKBACK = 20
MEDIAN_WINDOW = 60
HIGH_MULT = 1.5
RESTORE_MULT = 1.0
STANDDOWN_K = 5
SIZE_FLOOR = 0.5
WARMUP_CLOSES_REQUIRED = RV_LOOKBACK + MEDIAN_WINDOW + 1  # 81 closes: C[t-80..t] inclusive.


@dataclass(frozen=True)
class Evaluation:
    day: date
    available_at_utc: datetime
    regime: str  # HIGH, LOW, NORMAL, UNAVAILABLE, or CLOSED
    rv20: float | None
    prior60_median: float | None
    active: bool
    age: int
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


def rv20(returns: tuple[float, ...]) -> float:
    """Root-mean-square of exactly 20 completed log returns (REVIEW.md Section 1).

    Explicitly RMS (divisor 20, mean-zero assumption, not a demeaned sample
    standard deviation). Always >= 0; 20 flat sessions (all-zero returns) is a
    valid value of 0.0, never treated as missing.
    """
    if len(returns) != RV_LOOKBACK:
        raise ValueError("RV20 requires exactly 20 completed log returns")
    if not all(isfinite(r) for r in returns):
        raise ValueError("log returns must be finite")
    return sqrt(sum(r * r for r in returns) / RV_LOOKBACK)


def median60(prior: tuple[float, ...]) -> float:
    """Median of the 60 strictly-prior RV20 values (average of order statistics 30/31 for an even set)."""
    if len(prior) != MEDIAN_WINDOW:
        raise ValueError("median60 requires exactly 60 strictly-prior RV20 values")
    return median(prior)


def classify(rv: float, med: float) -> str:
    """HIGH iff rv > 1.5*med (strict); LOW iff rv < 1.0*med (strict); else NORMAL.

    Equality at either boundary is neutral (REVIEW.md Section 1): exact
    1.5x median does not engage HIGH; exact 1.0x median does not count as a
    LOW/restore signal. Zero current with zero median is NORMAL (neither
    fires); a positive current with a zero median is HIGH.
    """
    if not (isfinite(rv) and rv >= 0 and isfinite(med) and med >= 0):
        raise ValueError("RV20 and median60 must be finite and nonnegative")
    if rv > HIGH_MULT * med:
        return "HIGH"
    if rv < RESTORE_MULT * med:
        return "LOW"
    return "NORMAL"


def transition(active: bool, age: int, regime: str) -> tuple[bool, int]:
    """HYS-C minimum-hold / hysteretic-hold / re-trigger-reset (REVIEW.md Section 2).

    Applied only to a resolved HIGH/LOW/NORMAL regime for a day whose own
    evaluation is available; UNAVAILABLE/CLOSED days must not reach this
    function -- callers retain the latent (active, age) pair unchanged for
    those days instead (REVIEW.md Section 3). Transition order, exactly:
      - HIGH: active=True, age=0 (including a retrigger while already active).
      - Otherwise, if active: age=min(5, age+1); if age==5 and LOW,
        active=False, age=0; otherwise retain active at the new age.
      - Otherwise (inactive, non-HIGH): remain inactive, age=0.
    """
    if age not in range(0, STANDDOWN_K + 1):
        raise ValueError("invalid HYP-2 age counter")
    if regime == "HIGH":
        return True, 0
    if regime not in {"LOW", "NORMAL"}:
        raise ValueError("transition requires a resolved HIGH/LOW/NORMAL regime")
    if active:
        new_age = min(STANDDOWN_K, age + 1)
        if new_age == STANDDOWN_K and regime == "LOW":
            return False, 0
        return True, new_age
    return False, 0


def evaluate(rows: Iterable[DailyClose]) -> tuple[Evaluation, ...]:
    """Evaluate the fixed RV20/MEDIAN60/HYS-C contract on qualified daily closes.

    Missing or invalid observations invalidate windows crossing that gap;
    neither prices nor returns are imputed. The latent (active, age) pair
    persists through UNAVAILABLE and CLOSED days without advancing, and its
    implied multiplier is still reported for those days (REVIEW.md Section 3
    rejects silently defaulting an active floor to 1.0x merely because the
    day's own evaluation was unresolved) -- this mirrors
    ``hyp1_causal_tags.evaluate``'s already-reviewed carry-through of its own
    countdown counter across gaps and closures. Known CLOSED days do not
    create returns or consume a stand-down interval.
    """
    closes: deque[float] = deque(maxlen=RV_LOOKBACK + 1)
    prior_rvs: deque[float] = deque(maxlen=MEDIAN_WINDOW)
    out: list[Evaluation] = []
    previous: date | None = None
    active, age, available, gap = False, 0, False, False
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
            if len(closes) == RV_LOOKBACK + 1:
                values = tuple(closes)
                returns = tuple(log(values[i]) - log(values[i - 1]) for i in range(1, len(values)))
                rv = rv20(returns)
                if len(prior_rvs) == MEDIAN_WINDOW:
                    med = median60(tuple(prior_rvs))
                    regime, available, gap = classify(rv, med), True, False
                # Append AFTER evaluating so the current RV20 cannot enter its own MEDIAN60.
                prior_rvs.append(rv)
        if regime not in {"UNAVAILABLE", "CLOSED"}:
            active, age = transition(active, age, regime)
        out.append(Evaluation(row.day, bar_available_at(row.day), regime, rv, med,
                              active, age, available, SIZE_FLOOR if active else 1.0, gap))
    return tuple(out)


def tag_entry(ea_id: int, entry_server: datetime,
              evaluations: tuple[Evaluation, ...]) -> EntryTag:
    """Tag an entry only. No outcome fields, lot rounding or open-position resize.

    The multiplier applies only to new entries generated by the incumbent
    QM5_11422 logic (AUTHOR_DELIVERY.md Section 5); any other ea_id is tagged
    UNTARGETED at 1.0x. ``feature_gap``/``signal_available=False`` expose an
    unresolved observation without forcing the multiplier to 1.0x -- the
    latent state's own multiplier (as carried by ``evaluate``) is what is
    reported. Such tags are not complete account evidence.
    """
    if not OBSERVATION_START <= entry_server.date() <= OBSERVATION_END:
        raise ValueError("entry outside the frozen descriptive window")
    entry = server_to_utc(entry_server)
    cutoffs = tuple(e.available_at_utc for e in evaluations)
    if any(a >= b for a, b in zip(cutoffs, cutoffs[1:])):
        raise ValueError("feature cutoffs must be strictly ordered")
    index = bisect_left(cutoffs, entry) - 1  # Strict cutoff < entry, including exact midnight.
    covered = bool(evaluations) and (
        evaluations[0].day < entry_server.date() <= evaluations[-1].day + timedelta(days=1)
    )
    source = evaluations[index] if index >= 0 and covered else None
    if ea_id != GATED_EA_ID:
        return EntryTag(ea_id, entry, source.day if source else None, 1.0,
                        bool(source and source.signal_available), "UNTARGETED", bool(source and source.gap))
    if source is None:
        return EntryTag(ea_id, entry, None, None, False, "OUTSIDE_FEATURE_COVERAGE", True)
    return EntryTag(ea_id, entry, source.day, source.nominal_multiplier,
                    source.signal_available,
                    "AVAILABLE" if source.signal_available else "UNAVAILABLE",
                    source.gap)
