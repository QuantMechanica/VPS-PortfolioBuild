from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import date, datetime, timedelta


MIN_SESSIONS = 17
MAX_SESSIONS = 23
WEEKDAY_BUCKETS = 5
MIN_BUCKET_OBSERVATIONS = 3
MAX_BUCKET_OBSERVATIONS = 5
TOLERANCE = 1.0e-10


@dataclass(frozen=True)
class Signal:
    count: int
    bucket_counts: tuple[int, ...]
    bucket_means: tuple[float, ...]
    sorted_means: tuple[float, ...]
    median: float
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
        if cursor.weekday() < WEEKDAY_BUCKETS:
            labels.append(cursor)
        cursor += timedelta(days=1)
    return labels


def labels_for_counts(counts: tuple[int, ...]) -> list[date]:
    if len(counts) != WEEKDAY_BUCKETS:
        raise ValueError("bucket count vector")
    used = [0] * WEEKDAY_BUCKETS
    labels: list[date] = []
    cursor = date(2026, 1, 5)
    while used != list(counts):
        bucket = cursor.weekday()
        if bucket < WEEKDAY_BUCKETS and used[bucket] < counts[bucket]:
            labels.append(cursor)
            used[bucket] += 1
        cursor += timedelta(days=1)
    return labels


def classify_weekday_returns(
    ending_dates: list[date],
    returns: list[float],
    endpoint_return: float | None = None,
) -> Signal:
    if len(ending_dates) != len(returns):
        raise ValueError("path lengths")
    if not MIN_SESSIONS <= len(returns) <= MAX_SESSIONS:
        raise ValueError("session count")
    if any(
        ending_dates[index - 1] >= ending_dates[index]
        for index in range(1, len(ending_dates))
    ):
        raise ValueError("chronology or duplicate")
    if not all(math.isfinite(value) for value in returns):
        raise ValueError("return validity")

    bucket_values: list[list[float]] = [[] for _ in range(WEEKDAY_BUCKETS)]
    for ending_date, value in zip(ending_dates, returns, strict=True):
        bucket = ending_date.weekday()
        if bucket >= WEEKDAY_BUCKETS:
            raise ValueError("weekend ending label")
        bucket_values[bucket].append(value)

    counts = tuple(len(values) for values in bucket_values)
    if any(
        count < MIN_BUCKET_OBSERVATIONS or count > MAX_BUCKET_OBSERVATIONS
        for count in counts
    ):
        raise ValueError("weekday bucket observations")
    means = tuple(sum(values) / len(values) for values in bucket_values)
    if not all(math.isfinite(value) for value in means):
        raise ValueError("weekday mean")
    ordered = tuple(sorted(means))
    median = ordered[2]

    raw_sum = sum(returns)
    endpoint = raw_sum if endpoint_return is None else endpoint_return
    if not math.isfinite(raw_sum) or not math.isfinite(endpoint):
        raise ValueError("sum validity")
    if abs(raw_sum - endpoint) > TOLERANCE:
        raise ValueError("endpoint identity")
    direction = 1 if median > 0.0 else -1 if median < 0.0 else 0
    return Signal(
        count=len(returns),
        bucket_counts=counts,
        bucket_means=means,
        sorted_means=ordered,
        median=median,
        raw_sum=raw_sum,
        endpoint_return=endpoint,
        direction=direction,
    )


def signal_from_closes(
    boundary_close: float,
    ending_dates: list[date],
    month_closes: list[float],
) -> Signal:
    prices = [boundary_close, *month_closes]
    if len(ending_dates) != len(month_closes):
        raise ValueError("path lengths")
    if not all(value > 0.0 and math.isfinite(value) for value in prices):
        raise ValueError("prices")
    returns = [
        math.log(prices[index + 1]) - math.log(prices[index])
        for index in range(len(prices) - 1)
    ]
    endpoint = math.log(prices[-1]) - math.log(prices[0])
    return classify_weekday_returns(ending_dates, returns, endpoint)


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
    risk_fixed: float,
    stop_risk_per_lot: float,
    lot_step: float,
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


class MonthlyWeekdayMedianReferenceTests(unittest.TestCase):
    def test_positive_negative_and_zero_medians(self) -> None:
        labels = business_days(date(2026, 6, 1), 20)
        positive = classify_weekday_returns(labels, [0.01] * 20)
        negative = classify_weekday_returns(labels, [-0.01] * 20)
        by_weekday = (-0.02, -0.01, 0.0, 0.01, 0.02)
        zero = classify_weekday_returns(
            labels, [by_weekday[label.weekday()] for label in labels]
        )
        self.assertEqual((positive.direction, negative.direction, zero.direction), (1, -1, 0))

    def test_raw_endpoint_disagreement_is_diagnostic_only(self) -> None:
        labels = business_days(date(2026, 6, 1), 20)
        long_returns = [-1.0 if label.weekday() == 0 else 0.1 for label in labels]
        short_returns = [1.0 if label.weekday() == 0 else -0.1 for label in labels]
        long_signal = classify_weekday_returns(labels, long_returns)
        short_signal = classify_weekday_returns(labels, short_returns)
        self.assertLess(long_signal.raw_sum, 0.0)
        self.assertEqual(long_signal.direction, 1)
        self.assertGreater(short_signal.raw_sum, 0.0)
        self.assertEqual(short_signal.direction, -1)

    def test_bucket_means_sort_and_exact_median_index_two(self) -> None:
        labels = business_days(date(2026, 6, 1), 20)
        weekday_values = (0.04, -0.02, 0.01, 0.03, -0.01)
        signal = classify_weekday_returns(
            labels, [weekday_values[label.weekday()] for label in labels]
        )
        self.assertEqual(signal.bucket_counts, (4, 4, 4, 4, 4))
        self.assertEqual(signal.bucket_means, weekday_values)
        self.assertEqual(signal.sorted_means, tuple(sorted(weekday_values)))
        self.assertAlmostEqual(signal.median, 0.01, places=15)

    def test_three_four_and_five_observation_buckets_are_accepted(self) -> None:
        seventeen = business_days(date(2026, 6, 1), 17)
        twenty_three = business_days(date(2026, 6, 1), 23)
        self.assertEqual(classify_weekday_returns(seventeen, [0.001] * 17).bucket_counts, (4, 4, 3, 3, 3))
        self.assertEqual(classify_weekday_returns(twenty_three, [0.001] * 23).bucket_counts, (5, 5, 5, 4, 4))

    def test_missing_two_and_six_observation_buckets_fail(self) -> None:
        for counts in ((0, 5, 5, 5, 5), (2, 4, 4, 4, 4), (6, 3, 3, 3, 3)):
            labels = labels_for_counts(counts)
            with self.assertRaisesRegex(ValueError, "weekday bucket observations"):
                classify_weekday_returns(labels, [0.001] * len(labels))

    def test_weekend_and_duplicate_endings_fail(self) -> None:
        labels = business_days(date(2026, 6, 1), 20)
        weekend = labels.copy()
        weekend[0] = date(2026, 5, 31)
        with self.assertRaisesRegex(ValueError, "weekend"):
            classify_weekday_returns(weekend, [0.001] * 20)
        duplicate = labels.copy()
        duplicate[1] = duplicate[0]
        with self.assertRaisesRegex(ValueError, "duplicate"):
            classify_weekday_returns(duplicate, [0.001] * 20)

    def test_close_path_is_chronological_and_preserves_endpoint(self) -> None:
        labels = business_days(date(2026, 6, 1), 20)
        increments = [-1.0 if label.weekday() == 0 else 0.1 for label in labels]
        closes: list[float] = []
        price = 80.0
        for increment in increments:
            price *= math.exp(increment)
            closes.append(price)
        signal = signal_from_closes(80.0, labels, closes)
        self.assertAlmostEqual(signal.raw_sum, math.log(closes[-1] / 80.0), places=12)
        self.assertEqual(signal.direction, 1)

    def test_endpoint_mismatch_fails_closed(self) -> None:
        labels = business_days(date(2026, 6, 1), 20)
        with self.assertRaisesRegex(ValueError, "endpoint identity"):
            classify_weekday_returns(labels, [0.001] * 20, endpoint_return=0.02 + 2.0e-10)

    def test_session_bounds_are_exact(self) -> None:
        for count in (17, 20, 23):
            labels = business_days(date(2026, 6, 1), count)
            self.assertEqual(classify_weekday_returns(labels, [0.001] * count).count, count)
        for count in (16, 24):
            labels = business_days(date(2026, 6, 1), count)
            with self.assertRaisesRegex(ValueError, "session count"):
                classify_weekday_returns(labels, [0.001] * count)

    def test_immediately_completed_month_and_boundary_across_year(self) -> None:
        december = business_days(date(2025, 12, 1), 23)
        history = list(reversed(december)) + [date(2025, 11, 28)]
        selected, boundary = extract_completed_month(history, (2026, 1))
        self.assertEqual(len(selected), 23)
        self.assertEqual((selected[0].year, selected[0].month), (2025, 12))
        self.assertEqual((boundary.year, boundary.month), (2025, 11))

    def test_current_month_leakage_and_missing_boundary_fail(self) -> None:
        valid = business_days(date(2026, 7, 1), 20)
        with self.assertRaisesRegex(ValueError, "current-month leakage"):
            extract_completed_month([date(2026, 8, 3), *reversed(valid)], (2026, 8))
        with self.assertRaisesRegex(ValueError, "boundary"):
            extract_completed_month(list(reversed(valid)), (2026, 8))

    def test_zero_and_plus_one_label_conventions_preserve_weekdays(self) -> None:
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
        self.assertEqual(
            [label.weekday() for label in zero_history],
            [label.weekday() for label in lag_history],
        )

    def test_mixed_label_collision_and_unsupported_offset_fail(self) -> None:
        with self.assertRaisesRegex(ValueError, "collision"):
            normalize_package(
                date(2026, 8, 3),
                date(2026, 8, 3),
                [date(2026, 7, 31), date(2026, 7, 31)],
            )
        with self.assertRaisesRegex(ValueError, "unsupported"):
            choose_label_offset(date(2026, 8, 1), date(2026, 8, 3))

    def test_raw_entry_grace_does_not_wrap_at_twenty_four_hours(self) -> None:
        opened = datetime(2026, 8, 3, 0, 0)
        self.assertTrue(within_raw_bar_grace(opened, opened + timedelta(minutes=180)))
        self.assertFalse(within_raw_bar_grace(opened, opened + timedelta(minutes=181)))
        self.assertFalse(within_raw_bar_grace(opened, opened + timedelta(days=1, minutes=30)))

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
        self.assertTrue(lifecycle_close(entry, datetime(2026, 8, 4), (2026, 8), False))

    def test_fixed_risk_lots_do_not_exceed_budget(self) -> None:
        lots = aggregate_risk_lots(1000.0, 240.0, 0.01)
        self.assertLessEqual(lots * 240.0, 1000.0 + 1.0e-9)


if __name__ == "__main__":
    unittest.main()
