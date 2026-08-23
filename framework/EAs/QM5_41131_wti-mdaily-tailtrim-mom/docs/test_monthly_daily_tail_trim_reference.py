from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import date, datetime, timedelta


MIN_SESSIONS = 17
MAX_SESSIONS = 23
TRIM_EACH_TAIL = 1
TOLERANCE = 1.0e-10


@dataclass(frozen=True)
class Signal:
    count: int
    retained_count: int
    returns: tuple[float, ...]
    sorted_returns: tuple[float, ...]
    raw_sum: float
    endpoint_return: float
    minimum: float
    maximum: float
    inner_sum: float
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


def classify_returns(
    returns: list[float],
    endpoint_return: float | None = None,
) -> Signal:
    if not MIN_SESSIONS <= len(returns) <= MAX_SESSIONS:
        raise ValueError("session count")
    if TRIM_EACH_TAIL != 1 or not all(math.isfinite(value) for value in returns):
        raise ValueError("return validity")
    raw_sum = sum(returns)
    endpoint = raw_sum if endpoint_return is None else endpoint_return
    if not math.isfinite(raw_sum) or not math.isfinite(endpoint):
        raise ValueError("sum validity")
    if abs(raw_sum - endpoint) > TOLERANCE:
        raise ValueError("endpoint identity")

    ordered = sorted(returns)
    retained = ordered[TRIM_EACH_TAIL:-TRIM_EACH_TAIL]
    if len(retained) != len(returns) - 2:
        raise AssertionError("wrong retained indexes")
    inner_sum = sum(retained)
    if not math.isfinite(inner_sum):
        raise ValueError("inner sum")
    direction = 1 if inner_sum > 0.0 else -1 if inner_sum < 0.0 else 0
    return Signal(
        count=len(returns),
        retained_count=len(retained),
        returns=tuple(returns),
        sorted_returns=tuple(ordered),
        raw_sum=raw_sum,
        endpoint_return=endpoint,
        minimum=ordered[0],
        maximum=ordered[-1],
        inner_sum=inner_sum,
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
    return classify_returns(returns, endpoint)


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
    entry_month = (entry_time.year, entry_time.month)
    if entry_month != normalized_current_month:
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


class MonthlyDailyTailTrimReferenceTests(unittest.TestCase):
    def test_positive_negative_and_zero_inner_sums(self) -> None:
        positive = classify_returns([-0.20, 0.30, *([0.01] * 15)])
        negative = classify_returns([-0.30, 0.20, *([-0.01] * 15)])
        zero = classify_returns([-0.50, 0.50, *([0.0] * 15)])
        self.assertEqual((positive.direction, negative.direction, zero.direction), (1, -1, 0))

    def test_raw_endpoint_disagreement_is_diagnostic_only(self) -> None:
        long_signal = classify_returns([-0.50, 0.02, *([0.01] * 15)])
        short_signal = classify_returns([0.50, -0.02, *([-0.01] * 15)])
        self.assertLess(long_signal.raw_sum, 0.0)
        self.assertEqual(long_signal.direction, 1)
        self.assertGreater(short_signal.raw_sum, 0.0)
        self.assertEqual(short_signal.direction, -1)

    def test_endpoint_agreement_is_also_accepted(self) -> None:
        signal = classify_returns([-0.02, 0.03, *([0.01] * 15)])
        self.assertGreater(signal.raw_sum, 0.0)
        self.assertEqual(signal.direction, 1)

    def test_sort_and_exact_one_element_per_tail_deletion(self) -> None:
        values = [0.03, -0.20, 0.0, 0.40, *([0.01] * 13)]
        signal = classify_returns(values)
        self.assertEqual(signal.sorted_returns, tuple(sorted(values)))
        self.assertEqual(signal.minimum, -0.20)
        self.assertEqual(signal.maximum, 0.40)
        self.assertEqual(signal.retained_count, 15)
        self.assertAlmostEqual(signal.inner_sum, sum(sorted(values)[1:-1]), places=15)

    def test_tied_extremes_delete_one_array_element_each(self) -> None:
        values = [-0.10, -0.10, 0.20, 0.20, *([0.0] * 13)]
        signal = classify_returns(values)
        self.assertEqual(signal.retained_count, 15)
        self.assertIn(-0.10, signal.sorted_returns[1:-1])
        self.assertIn(0.20, signal.sorted_returns[1:-1])
        self.assertAlmostEqual(signal.inner_sum, 0.10, places=15)

    def test_zero_constituents_are_valid(self) -> None:
        signal = classify_returns([-0.02, 0.04, 0.0, *([0.001] * 14)])
        self.assertIn(0.0, signal.returns)
        self.assertEqual(signal.direction, 1)

    def test_close_path_is_chronological_and_preserves_endpoint(self) -> None:
        increments = [-0.30, 0.02, *([0.01] * 15)]
        closes: list[float] = []
        price = 80.0
        for increment in increments:
            price *= math.exp(increment)
            closes.append(price)
        signal = signal_from_closes(80.0, closes)
        self.assertEqual(signal.count, len(closes))
        self.assertAlmostEqual(signal.raw_sum, math.log(closes[-1] / 80.0), places=12)
        self.assertEqual(signal.direction, 1)

    def test_endpoint_mismatch_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "endpoint identity"):
            classify_returns([0.001] * 17, endpoint_return=0.017 + 2.0e-10)

    def test_session_bounds_are_exact(self) -> None:
        for count in (17, 20, 23):
            self.assertEqual(classify_returns([0.001] * count).count, count)
        for count in (16, 24):
            with self.assertRaisesRegex(ValueError, "session count"):
                classify_returns([0.001] * count)

    def test_immediately_completed_month_and_boundary_across_year(self) -> None:
        december = [date(2025, 12, day) for day in range(1, 24)]
        history = list(reversed(december)) + [date(2025, 11, 28)]
        selected, boundary = extract_completed_month(history, (2026, 1))
        self.assertEqual(len(selected), 23)
        self.assertEqual((selected[0].year, selected[0].month), (2025, 12))
        self.assertEqual((boundary.year, boundary.month), (2025, 11))

    def test_current_month_leakage_and_missing_boundary_fail(self) -> None:
        valid = [date(2026, 7, day) for day in range(1, 21)]
        with self.assertRaisesRegex(ValueError, "current-month leakage"):
            extract_completed_month([date(2026, 8, 1), *reversed(valid)], (2026, 8))
        with self.assertRaisesRegex(ValueError, "boundary"):
            extract_completed_month(list(reversed(valid)), (2026, 8))

    def test_zero_and_plus_one_label_conventions_are_equivalent(self) -> None:
        labels = [date(2026, 6, 30)] + [date(2026, 7, day) for day in range(1, 21)]
        zero_current, zero_history = normalize_package(
            date(2026, 8, 1), date(2026, 8, 1), list(reversed(labels))
        )
        lag_current, lag_history = normalize_package(
            date(2026, 7, 31),
            date(2026, 8, 1),
            [label - timedelta(days=1) for label in reversed(labels)],
        )
        self.assertEqual(zero_current, lag_current)
        self.assertEqual(zero_history, lag_history)

    def test_mixed_label_collision_and_unsupported_offset_fail(self) -> None:
        with self.assertRaisesRegex(ValueError, "collision"):
            normalize_package(
                date(2026, 8, 1),
                date(2026, 8, 1),
                [date(2026, 7, 31), date(2026, 7, 31)],
            )
        with self.assertRaisesRegex(ValueError, "unsupported"):
            choose_label_offset(date(2026, 7, 30), date(2026, 8, 1))

    def test_raw_entry_grace_does_not_wrap_at_twenty_four_hours(self) -> None:
        opened = datetime(2026, 8, 1, 0, 0)
        self.assertTrue(within_raw_bar_grace(opened, opened + timedelta(minutes=180)))
        self.assertFalse(within_raw_bar_grace(opened, opened + timedelta(minutes=181)))
        self.assertFalse(within_raw_bar_grace(opened, opened + timedelta(days=1, minutes=30)))

    def test_attempt_is_consumed_before_downstream_failure(self) -> None:
        ledger = AttemptLedger()
        self.assertFalse(ledger.consume_before(202608, downstream_gate=False))
        self.assertFalse(ledger.consume_before(202608, downstream_gate=True))
        self.assertTrue(ledger.consume_before(202609, downstream_gate=True))

    def test_later_month_stale_and_malformed_lifecycle(self) -> None:
        entry = datetime(2026, 8, 1, 1, 0)
        self.assertFalse(lifecycle_close(entry, datetime(2026, 8, 20), (2026, 8)))
        self.assertTrue(lifecycle_close(entry, datetime(2026, 9, 1), (2026, 9)))
        self.assertTrue(lifecycle_close(entry, entry + timedelta(days=40), (2026, 8)))
        self.assertTrue(lifecycle_close(entry, datetime(2026, 8, 2), (2026, 8), False))

    def test_fixed_risk_lots_do_not_exceed_budget(self) -> None:
        lots = aggregate_risk_lots(1000.0, 240.0, 0.01)
        self.assertLessEqual(lots * 240.0, 1000.0 + 1.0e-9)


if __name__ == "__main__":
    unittest.main()
