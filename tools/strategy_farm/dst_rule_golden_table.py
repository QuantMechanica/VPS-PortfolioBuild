#!/usr/bin/env python3
"""Independent golden-table generator for ``qm.dst_rule.us.v1`` (contract section 8).

This is deliberately a *from-scratch* re-implementation of the rule in
``docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md#2`` / ``framework/include/QM/
QM_DSTAware.mqh``, written without importing or copying
``tools/strategy_farm/news_impact_mapping.py``'s ``_nth_weekday_of_month`` (which uses
``calendar.weekday`` + ``calendar.monthrange``). This module instead walks forward from
the 1st of the month in whole-day steps. Two independently-coded implementations of the
same textual rule agreeing on every row is stronger evidence than one implementation
checked against itself.

Rule (verbatim from the contract):
    - US DST starts 07:00 UTC on the 2nd Sunday of March.
    - US DST ends 06:00 UTC on the 1st Sunday of November.
    - Broker offset = UTC+3 while [start, end) (DST active), else UTC+2.

Produces a dense CSV: for each year in ``YEARS``, a per-minute sweep spanning
``BOUNDARY_WINDOW`` around both the start and end boundary, columns
``utc_iso,is_us_dst,offset_hours,broker_time_iso``. This is the single reference table
both the Python (``news_impact_mapping.py``) and MQL5 (``QM_DSTAware.mqh``) sides are
checked against - see ``tools/strategy_farm/tests/test_dst_rule_cross_language_parity.py``
(Python) and ``framework/tests/unit/dst_aware_transition_tests.mq5`` (MQL5, boundary
values for each year taken from this same table, documented as generated not hand-picked).
"""
from __future__ import annotations

import csv
from datetime import datetime, timedelta, timezone
from pathlib import Path

#: Spans a leap year (2024) and non-leap years (2023, 2025, 2026, 2027) - contract
#: section 8's "at least 3 consecutive years spanning a leap year and a non-leap year".
YEARS = (2023, 2024, 2025, 2026, 2027)

#: Dense per-minute sweep radius around each boundary instant.
BOUNDARY_WINDOW = timedelta(hours=3)
STEP = timedelta(minutes=1)

OUT_PATH = Path(__file__).resolve().parents[2] / (
    "docs/ops/evidence/2026-09-14_dst_cross_language_parity/golden_table.csv"
)


def _first_sunday_on_or_after(day: datetime) -> datetime:
    """Walk forward one day at a time to the first Sunday at/after ``day`` (00:00)."""

    cursor = day
    while cursor.weekday() != 6:  # Python: Monday=0 .. Sunday=6
        cursor += timedelta(days=1)
    return cursor


def nth_sunday_of_month(year: int, month: int, nth: int) -> int:
    """Day-of-month of the ``nth`` Sunday, found by forward day-walking (not modulo math)."""

    first = _first_sunday_on_or_after(datetime(year, month, 1))
    target = first + timedelta(days=7 * (nth - 1))
    if target.month != month:
        raise ValueError(f"no {nth}th Sunday in {year}-{month:02d}")
    return target.day


def us_dst_start_utc(year: int) -> datetime:
    day = nth_sunday_of_month(year, 3, 2)
    return datetime(year, 3, day, 7, 0, tzinfo=timezone.utc)


def us_dst_end_utc(year: int) -> datetime:
    day = nth_sunday_of_month(year, 11, 1)
    return datetime(year, 11, day, 6, 0, tzinfo=timezone.utc)


def is_us_dst(moment: datetime) -> bool:
    start = us_dst_start_utc(moment.year)
    end = us_dst_end_utc(moment.year)
    return start <= moment < end


def offset_hours(moment: datetime) -> int:
    return 3 if is_us_dst(moment) else 2


def broker_time(moment: datetime) -> datetime:
    return moment + timedelta(hours=offset_hours(moment))


def _iso(moment: datetime) -> str:
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def generate_rows():
    for year in YEARS:
        for anchor in (us_dst_start_utc(year), us_dst_end_utc(year)):
            moment = anchor - BOUNDARY_WINDOW
            stop = anchor + BOUNDARY_WINDOW
            while moment <= stop:
                yield {
                    "utc_iso": _iso(moment),
                    "is_us_dst": int(is_us_dst(moment)),
                    "offset_hours": offset_hours(moment),
                    "broker_time_iso": broker_time(moment).strftime("%Y-%m-%dT%H:%M:%S"),
                }
                moment += STEP


def main() -> int:
    rows = list(generate_rows())
    # De-duplicate (start/end windows never overlap for this rule, but stay safe).
    seen = {}
    for row in rows:
        seen[row["utc_iso"]] = row
    ordered = [seen[key] for key in sorted(seen)]

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=["utc_iso", "is_us_dst", "offset_hours", "broker_time_iso"]
        )
        writer.writeheader()
        writer.writerows(ordered)

    print(f"wrote {len(ordered)} rows to {OUT_PATH}")
    for year in YEARS:
        print(
            f"  {year}: start={_iso(us_dst_start_utc(year))} end={_iso(us_dst_end_utc(year))}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
