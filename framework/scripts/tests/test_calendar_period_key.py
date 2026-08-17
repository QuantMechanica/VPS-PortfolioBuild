from __future__ import annotations

from collections import defaultdict
from datetime import date, timedelta
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
INDICATORS = REPO / "framework" / "include" / "QM" / "QM_Indicators.mqh"


def monday_key(value: date) -> int:
    monday = value - timedelta(days=value.weekday())
    return monday.year * 10_000 + monday.month * 100 + monday.day


def dates(start: date, end: date):
    value = start
    while value <= end:
        yield value
        value += timedelta(days=1)


def test_w1_implementation_remains_d1_derived_and_monday_anchored() -> None:
    source = INDICATORS.read_text(encoding="utf-8")
    assert "iTime(symbol, PERIOD_D1, shift)" in source
    assert "iTime(symbol, PERIOD_W1" not in source
    assert "days_since_monday = (d.day_of_week + 6) % 7" in source
    assert "StructToTime(d) - days_since_monday * 86400" in source
    assert "d.day_of_year / 7" not in source
    assert "if(period == PERIOD_MN1)\n      return d.year * 100 + d.mon" in source


def test_non_leap_year_boundary_uses_real_monday_weeks() -> None:
    expected = {
        date(2023, 12, 29): 20231225,
        date(2023, 12, 30): 20231225,
        date(2023, 12, 31): 20231225,
        date(2024, 1, 1): 20240101,
        date(2024, 1, 2): 20240101,
    }
    assert {value: monday_key(value) for value in expected} == expected


def test_leap_year_boundary_uses_real_monday_weeks() -> None:
    expected = {
        date(2024, 12, 29): 20241223,
        date(2024, 12, 30): 20241230,
        date(2024, 12, 31): 20241230,
        date(2025, 1, 1): 20241230,
        date(2025, 1, 2): 20241230,
    }
    assert {value: monday_key(value) for value in expected} == expected


def test_full_year_sweep_has_only_seven_day_internal_buckets() -> None:
    for year in (2023, 2024):
        start = date(year, 1, 1)
        end = date(year, 12, 31)
        grouped: dict[int, list[date]] = defaultdict(list)
        keys: list[int] = []
        for value in dates(start, end):
            key = monday_key(value)
            grouped[key].append(value)
            keys.append(key)

        assert keys == sorted(keys)
        distinct = list(dict.fromkeys(keys))
        assert all(left < right for left, right in zip(distinct, distinct[1:]))
        for key in distinct[1:-1]:
            bucket = grouped[key]
            assert len(bucket) == 7
            assert bucket[-1] - bucket[0] == timedelta(days=6)

