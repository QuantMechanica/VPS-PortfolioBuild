from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta


MIN_SESSIONS = 17
MAX_SESSIONS = 23
HISTORY_BARS = 70


@dataclass(frozen=True)
class Signal:
    newest_count: int
    parent_count: int
    newest_ordered_log_prices: tuple[float, ...]
    parent_ordered_log_prices: tuple[float, ...]
    newest_median: float
    parent_median: float
    median_shift: float
    direction: int


def previous_month(month: tuple[int, int]) -> tuple[int, int]:
    year, number = month
    return (year - 1, 12) if number == 1 else (year, number - 1)


def month_of(value: date | datetime) -> tuple[int, int]:
    return value.year, value.month


def month_business_days(month: tuple[int, int]) -> list[date]:
    year, number = month
    cursor = date(year, number, 1)
    next_month = (
        date(year + 1, 1, 1)
        if number == 12
        else date(year, number + 1, 1)
    )
    labels: list[date] = []
    while cursor < next_month:
        if cursor.weekday() < 5:
            labels.append(cursor)
        cursor += timedelta(days=1)
    return labels


def choose_label_offset(raw_current: datetime, broker_now: datetime) -> timedelta:
    if raw_current.time() != time.min or broker_now < raw_current:
        raise ValueError("invalid current label")
    raw_date = raw_current.date()
    broker_date = broker_now.date()
    if raw_date == broker_date:
        return timedelta(0)
    if raw_date + timedelta(days=1) == broker_date:
        return timedelta(days=1)
    raise ValueError("unsupported label offset")


def normalize_label(raw_label: datetime, offset: timedelta) -> datetime:
    if raw_label.time() != time.min or offset not in (timedelta(0), timedelta(days=1)):
        raise ValueError("non-midnight or unsupported label")
    normalized = raw_label + offset
    if normalized.time() != time.min or normalized.weekday() >= 5:
        raise ValueError("weekend-ending label")
    return normalized


def ordinary_sample_median(values: list[float]) -> tuple[tuple[float, ...], float]:
    if not values or not all(math.isfinite(value) for value in values):
        raise ValueError("median values")
    ordered = tuple(sorted(values))
    middle = len(ordered) // 2
    median = (
        ordered[middle]
        if len(ordered) % 2
        else 0.5 * (ordered[middle - 1] + ordered[middle])
    )
    if not math.isfinite(median):
        raise ValueError("median arithmetic")
    return ordered, median


def classify_month_samples(
    newest_closes: list[float],
    parent_closes: list[float],
) -> Signal:
    if not MIN_SESSIONS <= len(newest_closes) <= MAX_SESSIONS:
        raise ValueError("newest session count")
    if not MIN_SESSIONS <= len(parent_closes) <= MAX_SESSIONS:
        raise ValueError("parent session count")
    if not all(
        value > 0.0 and math.isfinite(value)
        for value in [*newest_closes, *parent_closes]
    ):
        raise ValueError("close validity")

    newest_ordered, newest_median = ordinary_sample_median(
        [math.log(value) for value in newest_closes]
    )
    parent_ordered, parent_median = ordinary_sample_median(
        [math.log(value) for value in parent_closes]
    )
    shift = newest_median - parent_median
    if not math.isfinite(shift):
        raise ValueError("shift arithmetic")
    direction = 1 if newest_median > parent_median else -1 if newest_median < parent_median else 0
    return Signal(
        newest_count=len(newest_closes),
        parent_count=len(parent_closes),
        newest_ordered_log_prices=newest_ordered,
        parent_ordered_log_prices=parent_ordered,
        newest_median=newest_median,
        parent_median=parent_median,
        median_shift=shift,
        direction=direction,
    )


def build_raw_history(
    current_month: tuple[int, int],
    newest_closes: list[float],
    parent_closes: list[float],
    offset_days: int = 0,
) -> list[tuple[datetime, float]]:
    newest_month = previous_month(current_month)
    parent_month = previous_month(newest_month)
    newest_days = month_business_days(newest_month)[-len(newest_closes) :]
    parent_days = month_business_days(parent_month)[-len(parent_closes) :]
    if len(newest_days) != len(newest_closes) or len(parent_days) != len(parent_closes):
        raise ValueError("fixture month too short")

    normalized: list[tuple[datetime, float]] = [
        (datetime.combine(label, time.min), close)
        for label, close in zip(newest_days, newest_closes)
    ]
    normalized.extend(
        (datetime.combine(label, time.min), close)
        for label, close in zip(parent_days, parent_closes)
    )

    padding_month = previous_month(parent_month)
    while len(normalized) < HISTORY_BARS:
        normalized.extend(
            (datetime.combine(label, time.min), 70.0)
            for label in month_business_days(padding_month)
        )
        padding_month = previous_month(padding_month)

    raw = [
        (label - timedelta(days=offset_days), close)
        for label, close in sorted(normalized, reverse=True)
    ]
    return raw[:HISTORY_BARS]


def extract_two_completed_months(
    raw_current: datetime,
    broker_now: datetime,
    raw_history_newest_first: list[tuple[datetime, float]],
) -> Signal:
    if len(raw_history_newest_first) < HISTORY_BARS:
        raise ValueError("history length")
    offset = choose_label_offset(raw_current, broker_now)
    normalized_current = normalize_label(raw_current, offset)
    if normalized_current.date() != broker_now.date() or normalized_current > broker_now:
        raise ValueError("current clock")

    expected_newest = previous_month(month_of(normalized_current))
    expected_parent = previous_month(expected_newest)
    expected_older = previous_month(expected_parent)
    newest: list[float] = []
    parent: list[float] = []
    older_boundary_seen = False
    last_label = normalized_current

    for raw_label, close in raw_history_newest_first[:HISTORY_BARS]:
        normalized = normalize_label(raw_label, offset)
        observed_month = month_of(normalized)
        if observed_month == month_of(normalized_current):
            raise ValueError("current-month leakage")
        if normalized >= last_label:
            raise ValueError("collision, future, or non-decreasing labels")
        last_label = normalized
        if observed_month == expected_newest:
            if parent:
                raise ValueError("month identity reversal")
            newest.append(close)
            continue
        if observed_month == expected_parent:
            if not MIN_SESSIONS <= len(newest) <= MAX_SESSIONS:
                raise ValueError("newest session count")
            parent.append(close)
            continue
        if observed_month == expected_older:
            if not MIN_SESSIONS <= len(parent) <= MAX_SESSIONS:
                raise ValueError("parent session count")
            older_boundary_seen = True
            break
        raise ValueError("non-adjacent month identity")

    if not older_boundary_seen:
        raise ValueError("older boundary")
    return classify_month_samples(newest, parent)


def first_business_day(month: tuple[int, int]) -> date:
    return month_business_days(month)[0]


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
    if month_of(entry_time) != normalized_current_month:
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

    def reconcile_entry_month(self, month: int) -> None:
        if self.month is None or month > self.month:
            self.month = month


class MonthlyMedianShiftReferenceTests(unittest.TestCase):
    def test_ordinary_odd_even_medians_and_full_sort(self) -> None:
        odd_ordered, odd = ordinary_sample_median([4.0, 1.0, 3.0, 2.0, 5.0])
        even_ordered, even = ordinary_sample_median([4.0, 1.0, 3.0, 2.0])
        self.assertEqual(odd_ordered, (1.0, 2.0, 3.0, 4.0, 5.0))
        self.assertEqual(even_ordered, (1.0, 2.0, 3.0, 4.0))
        self.assertEqual((odd, even), (3.0, 2.5))

    def test_strict_continuation_and_exact_equality(self) -> None:
        long_signal = classify_month_samples([85.0] * 20, [80.0] * 20)
        short_signal = classify_month_samples([75.0] * 20, [80.0] * 20)
        flat_signal = classify_month_samples([80.0] * 20, [80.0] * 20)
        self.assertEqual(
            (long_signal.direction, short_signal.direction, flat_signal.direction),
            (1, -1, 0),
        )
        self.assertGreater(long_signal.median_shift, 0.0)
        self.assertLess(short_signal.median_shift, 0.0)
        self.assertEqual(flat_signal.median_shift, 0.0)

    def test_endpoint_and_outlier_do_not_gate_median_direction(self) -> None:
        newest = [100.0] * 19 + [1.0]
        signal = classify_month_samples(newest, [90.0] * 20)
        self.assertEqual(signal.direction, 1)
        self.assertEqual(newest[-1], 1.0)
        self.assertGreater(signal.newest_median, signal.parent_median)

    def test_month_samples_are_sorted_independently(self) -> None:
        newest = [82.0, 79.0, 85.0, 81.0] * 5
        parent = [74.0, 77.0, 73.0, 76.0] * 5
        signal = classify_month_samples(newest, parent)
        self.assertEqual(
            signal.newest_ordered_log_prices,
            tuple(sorted(math.log(value) for value in newest)),
        )
        self.assertEqual(
            signal.parent_ordered_log_prices,
            tuple(sorted(math.log(value) for value in parent)),
        )
        self.assertEqual(signal.direction, 1)

    def test_session_bounds_and_invalid_closes_fail(self) -> None:
        for count in range(MIN_SESSIONS, MAX_SESSIONS + 1):
            signal = classify_month_samples([81.0] * count, [80.0] * count)
            self.assertEqual((signal.newest_count, signal.parent_count), (count, count))
        for count in (16, 24):
            with self.assertRaisesRegex(ValueError, "newest session count"):
                classify_month_samples([81.0] * count, [80.0] * 20)
        for value in (0.0, -1.0, math.nan, math.inf):
            with self.assertRaisesRegex(ValueError, "close validity"):
                classify_month_samples([value] + [81.0] * 19, [80.0] * 20)

    def test_two_completed_adjacent_months_across_year(self) -> None:
        current_month = (2026, 1)
        current = datetime.combine(first_business_day(current_month), time.min)
        history = build_raw_history(current_month, [81.0] * 20, [80.0] * 20)
        signal = extract_two_completed_months(
            current,
            current + timedelta(hours=1),
            history,
        )
        self.assertEqual((signal.newest_count, signal.parent_count), (20, 20))
        self.assertEqual(signal.direction, 1)

    def test_zero_and_plus_one_energy_labels_are_equivalent(self) -> None:
        current_month = (2026, 8)
        normalized_current = datetime.combine(first_business_day(current_month), time.min)
        zero = extract_two_completed_months(
            normalized_current,
            normalized_current + timedelta(hours=1),
            build_raw_history(current_month, [84.0] * 20, [80.0] * 20, 0),
        )
        lagged = extract_two_completed_months(
            normalized_current - timedelta(days=1),
            normalized_current + timedelta(hours=1),
            build_raw_history(current_month, [84.0] * 20, [80.0] * 20, 1),
        )
        self.assertEqual(zero, lagged)

    def test_current_month_leakage_and_non_adjacent_month_fail(self) -> None:
        current_month = (2026, 8)
        current = datetime.combine(first_business_day(current_month), time.min)
        history = build_raw_history(current_month, [84.0] * 20, [80.0] * 20)
        leaked = [(current, 85.0), *history[:-1]]
        with self.assertRaisesRegex(ValueError, "current-month leakage"):
            extract_two_completed_months(current, current + timedelta(hours=1), leaked)
        gap = list(history)
        first_parent = next(
            index for index, (label, _) in enumerate(gap) if month_of(label) == (2026, 6)
        )
        gap[first_parent] = (datetime(2026, 5, 29), gap[first_parent][1])
        with self.assertRaisesRegex(ValueError, "parent session count|non-adjacent"):
            extract_two_completed_months(current, current + timedelta(hours=1), gap)

    def test_label_collision_weekend_non_midnight_and_offset_fail(self) -> None:
        current_month = (2026, 8)
        current = datetime.combine(first_business_day(current_month), time.min)
        history = build_raw_history(current_month, [84.0] * 20, [80.0] * 20)
        collided = list(history)
        collided[1] = collided[0]
        with self.assertRaisesRegex(ValueError, "collision"):
            extract_two_completed_months(current, current + timedelta(hours=1), collided)
        weekend = list(history)
        weekend[0] = (datetime(2026, 7, 25), weekend[0][1])
        with self.assertRaisesRegex(ValueError, "weekend"):
            extract_two_completed_months(current, current + timedelta(hours=1), weekend)
        non_midnight = list(history)
        non_midnight[0] = (non_midnight[0][0] + timedelta(hours=1), non_midnight[0][1])
        with self.assertRaisesRegex(ValueError, "non-midnight"):
            extract_two_completed_months(current, current + timedelta(hours=1), non_midnight)
        with self.assertRaisesRegex(ValueError, "unsupported"):
            choose_label_offset(current - timedelta(days=2), current + timedelta(hours=1))

    def test_history_length_and_parent_boundary_fail_closed(self) -> None:
        current_month = (2026, 8)
        current = datetime.combine(first_business_day(current_month), time.min)
        history = build_raw_history(current_month, [84.0] * 20, [80.0] * 20)
        with self.assertRaisesRegex(ValueError, "history length"):
            extract_two_completed_months(
                current,
                current + timedelta(hours=1),
                history[: HISTORY_BARS - 1],
            )
        no_boundary = [
            row for row in history if month_of(row[0]) in ((2026, 7), (2026, 6))
        ]
        no_boundary.extend(no_boundary[-1:] * (HISTORY_BARS - len(no_boundary)))
        with self.assertRaisesRegex(ValueError, "collision|older boundary"):
            extract_two_completed_months(
                current,
                current + timedelta(hours=1),
                no_boundary,
            )

    def test_raw_entry_grace_does_not_wrap(self) -> None:
        opened = datetime(2026, 8, 3, 0, 0)
        self.assertTrue(within_raw_bar_grace(opened, opened + timedelta(minutes=180)))
        self.assertFalse(within_raw_bar_grace(opened, opened + timedelta(minutes=181)))
        self.assertFalse(within_raw_bar_grace(opened, opened + timedelta(days=1)))

    def test_attempt_consumption_and_restart_reconciliation(self) -> None:
        ledger = AttemptLedger()
        self.assertFalse(ledger.consume_before(202608, downstream_gate=False))
        self.assertFalse(ledger.consume_before(202608, downstream_gate=True))
        ledger.reconcile_entry_month(202609)
        self.assertEqual(ledger.month, 202609)
        self.assertFalse(ledger.consume_before(202609, downstream_gate=True))
        self.assertTrue(ledger.consume_before(202610, downstream_gate=True))

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
