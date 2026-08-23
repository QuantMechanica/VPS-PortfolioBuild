from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import date, datetime, timedelta


MIN_SESSIONS = 17
MAX_SESSIONS = 23
TRIM_DIVISOR = 4
MIN_RETAINED = 9
MAX_RETAINED = 13
TOLERANCE = 1.0e-10


@dataclass(frozen=True)
class Signal:
    count: int
    ordered: tuple[float, ...]
    trim_each_tail: int
    retained: tuple[float, ...]
    retained_low: float
    retained_high: float
    central_sum: float
    central_mean: float
    raw_sum: float
    endpoint_return: float
    direction: int


def previous_month(month: tuple[int, int]) -> tuple[int, int]:
    year, number = month
    return (year - 1, 12) if number == 1 else (year, number - 1)


def choose_label_offset(raw_label: date, broker_date: date) -> timedelta:
    if raw_label == broker_date:
        return timedelta(0)
    if raw_label + timedelta(days=1) == broker_date:
        return timedelta(days=1)
    raise ValueError("unsupported label offset")


def normalize_package(
    raw_current: date,
    broker_date: date,
    raw_history_newest_first: list[date],
) -> tuple[date, list[date]]:
    offset = choose_label_offset(raw_current, broker_date)
    normalized_current = raw_current + offset
    normalized = [label + offset for label in raw_history_newest_first]
    if any(
        normalized[index - 1] <= normalized[index]
        for index in range(1, len(normalized))
    ):
        raise ValueError("mixed convention, collision, or non-decreasing history")
    return normalized_current, normalized


def extract_completed_month(
    normalized_history_newest_first: list[date],
    current_month: tuple[int, int],
) -> tuple[list[date], date]:
    if not normalized_history_newest_first:
        raise ValueError("history")
    expected = previous_month(current_month)
    selected: list[date] = []
    boundary: date | None = None
    for label in normalized_history_newest_first:
        if label.weekday() >= 5:
            raise ValueError("weekend ending label")
        label_month = (label.year, label.month)
        if label_month == current_month:
            raise ValueError("current-month leakage")
        if not selected:
            if label_month != expected:
                raise ValueError("not immediately completed month")
            selected.append(label)
        elif label_month == expected:
            selected.append(label)
        else:
            if label_month != previous_month(expected):
                raise ValueError("non-adjacent boundary")
            boundary = label
            break
    if not MIN_SESSIONS <= len(selected) <= MAX_SESSIONS or boundary is None:
        raise ValueError("session count or boundary")
    return list(reversed(selected)), boundary


def business_days(start: date, count: int) -> list[date]:
    labels: list[date] = []
    cursor = start
    while len(labels) < count:
        if cursor.weekday() < 5:
            labels.append(cursor)
        cursor += timedelta(days=1)
    return labels


def classify_daily_returns(
    returns: list[float], endpoint_return: float | None = None
) -> Signal:
    if not MIN_SESSIONS <= len(returns) <= MAX_SESSIONS:
        raise ValueError("session count")
    if not all(math.isfinite(value) for value in returns):
        raise ValueError("return validity")

    ordered = tuple(sorted(returns))
    trim_each_tail = len(ordered) // TRIM_DIVISOR
    retained = ordered[trim_each_tail : len(ordered) - trim_each_tail]
    if trim_each_tail not in (4, 5):
        raise ValueError("trim count")
    if not MIN_RETAINED <= len(retained) <= MAX_RETAINED:
        raise ValueError("retained count")

    retained_low = retained[0]
    retained_high = retained[-1]
    central_sum = sum(retained)
    central_mean = central_sum / len(retained)
    if not all(
        math.isfinite(value)
        for value in (retained_low, retained_high, central_sum, central_mean)
    ):
        raise ValueError("central mean validity")

    raw_sum = sum(returns)
    endpoint = raw_sum if endpoint_return is None else endpoint_return
    if not math.isfinite(raw_sum) or not math.isfinite(endpoint):
        raise ValueError("sum validity")
    if abs(raw_sum - endpoint) > TOLERANCE:
        raise ValueError("endpoint identity")
    direction = 1 if central_mean > 0.0 else -1 if central_mean < 0.0 else 0
    return Signal(
        count=len(returns),
        ordered=ordered,
        trim_each_tail=trim_each_tail,
        retained=retained,
        retained_low=retained_low,
        retained_high=retained_high,
        central_sum=central_sum,
        central_mean=central_mean,
        raw_sum=raw_sum,
        endpoint_return=endpoint,
        direction=direction,
    )


def signal_from_closes(boundary_close: float, month_closes: list[float]) -> Signal:
    prices = [boundary_close, *month_closes]
    if not all(value > 0.0 and math.isfinite(value) for value in prices):
        raise ValueError("prices")
    returns = [
        math.log(prices[index + 1]) - math.log(prices[index])
        for index in range(len(prices) - 1)
    ]
    endpoint = math.log(prices[-1]) - math.log(prices[0])
    return classify_daily_returns(returns, endpoint)


def within_raw_bar_grace(raw_bar_open: datetime, broker_now: datetime) -> bool:
    elapsed = broker_now - raw_bar_open
    return timedelta(0) <= elapsed <= timedelta(minutes=180)


def lifecycle_close(
    entry_time: datetime,
    broker_now: datetime,
    normalized_current_month: tuple[int, int],
    position_valid: bool = True,
) -> bool:
    if not position_valid or entry_time > broker_now:
        return True
    if (entry_time.year, entry_time.month) != normalized_current_month:
        return True
    return broker_now - entry_time >= timedelta(days=40)


def aggregate_risk_lots(
    risk_fixed: float, stop_risk_per_lot: float, lot_step: float
) -> float:
    if risk_fixed <= 0.0 or stop_risk_per_lot <= 0.0 or lot_step <= 0.0:
        raise ValueError("risk inputs")
    raw = risk_fixed / stop_risk_per_lot
    return math.floor((raw + 1.0e-12) / lot_step) * lot_step


class AttemptLedger:
    def __init__(self) -> None:
        self.month: int | None = None

    def consume_before(self, month: int, downstream_gate: bool) -> bool:
        if self.month == month:
            return False
        self.month = month
        return downstream_gate


class MonthlyDailyIqrMeanReferenceTests(unittest.TestCase):
    def test_positive_negative_and_exact_zero_directions(self) -> None:
        positive = classify_daily_returns([-0.2] * 5 + [0.01] * 10 + [0.02] * 5)
        negative = classify_daily_returns([-0.02] * 5 + [-0.01] * 10 + [0.2] * 5)
        zero = classify_daily_returns([-0.2] * 5 + [0.0] * 10 + [0.2] * 5)
        self.assertEqual(
            (positive.direction, negative.direction, zero.direction), (1, -1, 0)
        )

    def test_integer_trim_and_retained_boundaries(self) -> None:
        expected = {17: (4, 9), 20: (5, 10), 23: (5, 13)}
        for count, pair in expected.items():
            signal = classify_daily_returns([0.001] * count)
            self.assertEqual((signal.trim_each_tail, len(signal.retained)), pair)

    def test_exact_retained_membership_and_duplicate_values(self) -> None:
        returns = [-0.05] * 5 + [0.001] * 10 + [0.05] * 5
        signal = classify_daily_returns(list(reversed(returns)))
        self.assertEqual(signal.ordered, tuple(sorted(returns)))
        self.assertEqual(signal.retained, (0.001,) * 10)
        self.assertEqual((signal.retained_low, signal.retained_high), (0.001, 0.001))
        self.assertAlmostEqual(signal.central_mean, 0.001, places=15)

    def test_tail_magnitude_does_not_change_retained_direction(self) -> None:
        mild = classify_daily_returns([-0.02] * 5 + [0.003] * 10 + [0.02] * 5)
        extreme = classify_daily_returns([-200.0] * 5 + [0.003] * 10 + [300.0] * 5)
        self.assertEqual(mild.retained, extreme.retained)
        self.assertEqual((mild.direction, extreme.direction), (1, 1))

    def test_endpoint_disagreement_is_diagnostic_only(self) -> None:
        long_signal = classify_daily_returns(
            [-0.2] * 5 + [0.01] * 10 + [0.02] * 5
        )
        short_signal = classify_daily_returns(
            [-0.02] * 5 + [-0.01] * 10 + [0.2] * 5
        )
        self.assertLess(long_signal.raw_sum, 0.0)
        self.assertEqual(long_signal.direction, 1)
        self.assertGreater(short_signal.raw_sum, 0.0)
        self.assertEqual(short_signal.direction, -1)

    def test_session_bounds_and_nonfinite_values_fail(self) -> None:
        for count in (17, 18, 19, 20, 21, 22, 23):
            self.assertEqual(classify_daily_returns([0.001] * count).count, count)
        for count in (16, 24):
            with self.assertRaisesRegex(ValueError, "session count"):
                classify_daily_returns([0.001] * count)
        with self.assertRaisesRegex(ValueError, "return validity"):
            classify_daily_returns([0.001] * 16 + [math.nan])

    def test_endpoint_mismatch_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "endpoint identity"):
            classify_daily_returns([0.001] * 20, endpoint_return=0.02 + 2.0e-10)

    def test_close_path_preserves_endpoint_and_central_direction(self) -> None:
        increments = [-0.2] * 5 + [0.01] * 10 + [0.02] * 5
        closes: list[float] = []
        price = 80.0
        for increment in increments:
            price *= math.exp(increment)
            closes.append(price)
        signal = signal_from_closes(80.0, closes)
        self.assertAlmostEqual(signal.raw_sum, math.log(closes[-1] / 80.0), places=12)
        self.assertEqual(signal.direction, 1)

    def test_immediately_completed_month_and_boundary_across_year(self) -> None:
        december = business_days(date(2025, 12, 1), 23)
        history = list(reversed(december)) + [date(2025, 11, 28)]
        selected, boundary = extract_completed_month(history, (2026, 1))
        self.assertEqual(len(selected), 23)
        self.assertEqual((selected[0].year, selected[0].month), (2025, 12))
        self.assertEqual((boundary.year, boundary.month), (2025, 11))

    def test_leakage_missing_boundary_and_weekend_fail(self) -> None:
        valid = business_days(date(2026, 7, 1), 20)
        with self.assertRaisesRegex(ValueError, "current-month leakage"):
            extract_completed_month([date(2026, 8, 3), *reversed(valid)], (2026, 8))
        with self.assertRaisesRegex(ValueError, "boundary"):
            extract_completed_month(list(reversed(valid)), (2026, 8))
        weekend = list(reversed(valid)) + [date(2026, 6, 27)]
        with self.assertRaisesRegex(ValueError, "weekend"):
            extract_completed_month(weekend, (2026, 8))

    def test_zero_and_plus_one_label_conventions_match(self) -> None:
        labels = [date(2026, 6, 30), *business_days(date(2026, 7, 1), 20)]
        zero_current, zero_history = normalize_package(
            date(2026, 8, 3), date(2026, 8, 3), list(reversed(labels))
        )
        lag_current, lag_history = normalize_package(
            date(2026, 8, 2),
            date(2026, 8, 3),
            [label - timedelta(days=1) for label in reversed(labels)],
        )
        self.assertEqual(zero_current, lag_current)
        self.assertEqual(zero_history, lag_history)

    def test_label_collision_and_unsupported_offset_fail(self) -> None:
        with self.assertRaisesRegex(ValueError, "collision"):
            normalize_package(
                date(2026, 8, 3),
                date(2026, 8, 3),
                [date(2026, 7, 31), date(2026, 7, 31)],
            )
        with self.assertRaisesRegex(ValueError, "unsupported"):
            choose_label_offset(date(2026, 8, 1), date(2026, 8, 3))

    def test_raw_entry_grace_does_not_wrap(self) -> None:
        opened = datetime(2026, 8, 3, 0, 0)
        self.assertTrue(within_raw_bar_grace(opened, opened + timedelta(minutes=180)))
        self.assertFalse(within_raw_bar_grace(opened, opened + timedelta(minutes=181)))
        self.assertFalse(within_raw_bar_grace(opened, opened + timedelta(days=1)))

    def test_attempt_is_consumed_before_downstream_failure(self) -> None:
        ledger = AttemptLedger()
        self.assertFalse(ledger.consume_before(202608, downstream_gate=False))
        self.assertFalse(ledger.consume_before(202608, downstream_gate=True))
        self.assertTrue(ledger.consume_before(202609, downstream_gate=True))

    def test_later_month_stale_and_malformed_lifecycle(self) -> None:
        entry = datetime(2026, 8, 3, 1, 0)
        self.assertFalse(lifecycle_close(entry, datetime(2026, 8, 20), (2026, 8)))
        self.assertTrue(lifecycle_close(entry, datetime(2026, 9, 1), (2026, 9)))
        self.assertTrue(lifecycle_close(entry, entry + timedelta(days=40), (2026, 8)))
        self.assertTrue(
            lifecycle_close(entry, datetime(2026, 8, 4), (2026, 8), False)
        )

    def test_fixed_risk_lots_do_not_exceed_budget(self) -> None:
        lots = aggregate_risk_lots(1000.0, 240.0, 0.01)
        self.assertLessEqual(lots * 240.0, 1000.0 + 1.0e-9)


if __name__ == "__main__":
    unittest.main()
