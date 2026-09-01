from __future__ import annotations

import math
import statistics
import unittest
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path


MIN_SESSIONS = 17
MAX_SESSIONS = 23
EPSILON = 1.0e-12


@dataclass(frozen=True)
class Signal:
    count: int
    final_close: float
    mean_close: float
    location: float
    direction: int


def previous_month(month: tuple[int, int]) -> tuple[int, int]:
    year, number = month
    return (year - 1, 12) if number == 1 else (year, number - 1)


def classify_closes(closes: list[float]) -> Signal:
    if not MIN_SESSIONS <= len(closes) <= MAX_SESSIONS:
        raise ValueError("session count")
    if not all(value > 0.0 and math.isfinite(value) for value in closes):
        raise ValueError("close validity")
    mean_close = sum(closes) / len(closes)
    final_close = closes[-1]
    location = final_close / mean_close - 1.0
    if not all(math.isfinite(value) for value in (mean_close, location)):
        raise ValueError("arithmetic validity")
    direction = 1 if location > EPSILON else -1 if location < -EPSILON else 0
    return Signal(len(closes), final_close, mean_close, location, direction)


def median_return_direction(boundary: float, closes: list[float]) -> int:
    prices = [boundary, *closes]
    returns = [
        math.log(prices[index + 1] / prices[index])
        for index in range(len(prices) - 1)
    ]
    center = statistics.median(returns)
    return 1 if center > 0.0 else -1 if center < 0.0 else 0


def raw_month_direction(boundary: float, final_close: float) -> int:
    move = math.log(final_close / boundary)
    return 1 if move > 0.0 else -1 if move < 0.0 else 0


def choose_label_offset(raw_label: date, broker_date: date) -> timedelta:
    if raw_label == broker_date:
        return timedelta(0)
    if raw_label + timedelta(days=1) == broker_date:
        return timedelta(days=1)
    raise ValueError("unsupported label offset")


def extract_completed_month(
    newest_first: list[date], current_month: tuple[int, int]
) -> tuple[list[date], date]:
    expected = previous_month(current_month)
    selected: list[date] = []
    boundary: date | None = None
    for label in newest_first:
        if label.weekday() >= 5:
            raise ValueError("weekend")
        month = (label.year, label.month)
        if month == current_month:
            raise ValueError("current-month leakage")
        if not selected:
            if month != expected:
                raise ValueError("not immediate")
            selected.append(label)
        elif month == expected:
            selected.append(label)
        else:
            if month != previous_month(expected):
                raise ValueError("non-adjacent boundary")
            boundary = label
            break
    if not MIN_SESSIONS <= len(selected) <= MAX_SESSIONS or boundary is None:
        raise ValueError("session count or boundary")
    return list(reversed(selected)), boundary


def business_days(start: date, count: int) -> list[date]:
    result: list[date] = []
    cursor = start
    while len(result) < count:
        if cursor.weekday() < 5:
            result.append(cursor)
        cursor += timedelta(days=1)
    return result


def within_grace(opened: datetime, now: datetime) -> bool:
    return timedelta(0) <= now - opened <= timedelta(minutes=180)


class AttemptLedger:
    def __init__(self) -> None:
        self.month: int | None = None

    def consume_before(self, month: int, downstream_gate: bool) -> bool:
        if self.month == month:
            return False
        self.month = month
        return downstream_gate


class WtiMonthlyDailyMeanLocationTests(unittest.TestCase):
    def test_buy_sell_and_flat(self) -> None:
        buy = classify_closes([90.0] * 19 + [101.0])
        sell = classify_closes([110.0] * 19 + [101.0])
        flat = classify_closes([100.0] * 20)
        self.assertEqual((buy.direction, sell.direction, flat.direction), (1, -1, 0))
        self.assertEqual((buy.final_close, sell.final_close), (101.0, 101.0))

    def test_raw_return_disagreement_is_load_bearing(self) -> None:
        closes = [110.0] * 19 + [101.0]
        self.assertEqual(raw_month_direction(100.0, closes[-1]), 1)
        self.assertEqual(classify_closes(closes).direction, -1)

    def test_median_return_disagreement_is_load_bearing(self) -> None:
        closes = [90.0] * 19 + [101.0]
        self.assertEqual(median_return_direction(100.0, closes), 0)
        self.assertEqual(classify_closes(closes).direction, 1)

    def test_session_bounds_and_bad_values_fail(self) -> None:
        for count in (17, 20, 23):
            self.assertEqual(classify_closes([100.0] * count).count, count)
        for count in (16, 24):
            with self.assertRaisesRegex(ValueError, "session count"):
                classify_closes([100.0] * count)
        for bad in (0.0, -1.0, math.nan, math.inf):
            with self.assertRaisesRegex(ValueError, "close validity"):
                classify_closes([100.0] * 16 + [bad])

    def test_immediately_completed_month_and_boundary_across_year(self) -> None:
        december = business_days(date(2025, 12, 1), 23)
        selected, boundary = extract_completed_month(
            list(reversed(december)) + [date(2025, 11, 28)], (2026, 1)
        )
        self.assertEqual(len(selected), 23)
        self.assertEqual((selected[-1].year, selected[-1].month), (2025, 12))
        self.assertEqual((boundary.year, boundary.month), (2025, 11))

    def test_leakage_missing_boundary_and_weekend_fail(self) -> None:
        july = business_days(date(2026, 7, 1), 20)
        with self.assertRaisesRegex(ValueError, "leakage"):
            extract_completed_month([date(2026, 8, 3), *reversed(july)], (2026, 8))
        with self.assertRaisesRegex(ValueError, "boundary"):
            extract_completed_month(list(reversed(july)), (2026, 8))
        with self.assertRaisesRegex(ValueError, "weekend"):
            extract_completed_month(list(reversed(july)) + [date(2026, 6, 27)], (2026, 8))

    def test_label_conventions_and_grace(self) -> None:
        self.assertEqual(
            choose_label_offset(date(2026, 8, 2), date(2026, 8, 3)),
            timedelta(days=1),
        )
        opened = datetime(2026, 8, 3)
        self.assertTrue(within_grace(opened, opened + timedelta(minutes=180)))
        self.assertFalse(within_grace(opened, opened + timedelta(minutes=181)))

    def test_attempt_is_consumed_before_downstream_failure(self) -> None:
        ledger = AttemptLedger()
        self.assertFalse(ledger.consume_before(202608, False))
        self.assertFalse(ledger.consume_before(202608, True))
        self.assertTrue(ledger.consume_before(202609, True))

    def test_source_contract_is_exact(self) -> None:
        source = Path(__file__).parents[1] / "QM5_41262_wti-mdaily-meanloc-tr.mq5"
        text = source.read_text(encoding="utf-8")
        for needle in (
            "qm_ea_id                      = 41262",
            "strategy_history_bars_d1      = 45",
            "strategy_direction_epsilon    = 0.000000000001",
            "final_close / mean_close - 1.0",
            "RISK_FIXED                    = 1000.0",
            "RISK_PERCENT                  = 0.0",
        ):
            self.assertIn(needle, text)
        self.assertNotIn("ArraySort", text)
        self.assertNotIn("MathLog", text)


if __name__ == "__main__":
    unittest.main()

