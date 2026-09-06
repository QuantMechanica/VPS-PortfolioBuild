"""Deterministic reference checks for QM5_41359 XTI/XNG weekly acceleration overshoot."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone


UTC = timezone.utc


@dataclass(frozen=True)
class PairBar:
    opened: datetime
    xti_close: float
    xng_close: float


def date_key(value: datetime) -> int:
    return value.year * 10_000 + value.month * 100 + value.day


def week_key(value: datetime) -> int:
    return date_key(value - timedelta(days=value.weekday()))


def key_to_date(value: int) -> datetime:
    return datetime(value // 10_000, (value // 100) % 100, value % 100, tzinfo=UTC)


def next_week_key(value: int) -> int:
    anchor = key_to_date(value)
    if week_key(anchor) != value:
        return 0
    return week_key(anchor + timedelta(days=7))


def within_entry_grace(current_bar: datetime, now: datetime, minutes: int = 180) -> bool:
    elapsed = now - current_bar
    return timedelta(0) <= elapsed <= timedelta(minutes=minutes)


def decision_clock(
    current_xti: datetime,
    current_xng: datetime,
    now: datetime,
    completed_newest_first: list[PairBar],
) -> tuple[bool, bool, int]:
    """Mirror the exact synchronized first-tradable-week-bar clock."""

    if current_xti != current_xng or current_xti.date() != now.date():
        return False, False, 0
    current_key = week_key(current_xti)
    if current_key != week_key(now) or not completed_newest_first:
        return False, False, 0
    current_count = 0
    for index, bar in enumerate(completed_newest_first):
        if index and completed_newest_first[index - 1].opened <= bar.opened:
            return False, False, 0
        if week_key(bar.opened) != current_key:
            break
        current_count += 1
    if current_count >= len(completed_newest_first):
        return False, False, 0
    if next_week_key(week_key(completed_newest_first[current_count].opened)) != current_key:
        return False, False, 0
    late = current_count > 0 or not within_entry_grace(current_xti, now)
    return True, late, current_key


def weekly_acceleration_signal(
    current_week_key: int,
    completed_newest_first: list[PairBar],
) -> tuple[bool, int, float, float, tuple[float, float, float]]:
    """Mirror strict sign agreement and newest absolute acceleration."""

    keys: list[int] = []
    spreads: list[float] = []
    for index, bar in enumerate(completed_newest_first):
        if bar.opened.timestamp() <= 0:
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        if index and completed_newest_first[index - 1].opened <= bar.opened:
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        key = week_key(bar.opened)
        if key == current_week_key:
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        if keys and key == keys[-1]:
            continue
        if not keys:
            if next_week_key(key) != current_week_key:
                return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        elif next_week_key(key) != keys[-1]:
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        if (
            bar.xti_close <= 0.0
            or bar.xng_close <= 0.0
            or not math.isfinite(bar.xti_close)
            or not math.isfinite(bar.xng_close)
        ):
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        keys.append(key)
        spreads.append(math.log(bar.xti_close) - math.log(bar.xng_close))
        if len(spreads) == 3:
            break
    if len(spreads) != 3:
        return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)

    new_return = spreads[0] - spreads[1]
    old_return = spreads[1] - spreads[2]
    direction = 0
    if old_return > 0.0 and new_return > 0.0 and abs(new_return) > abs(old_return):
        direction = -1
    elif old_return < 0.0 and new_return < 0.0 and abs(new_return) > abs(old_return):
        direction = 1
    return True, direction, new_return, old_return, tuple(spreads)


def pair_bars(spreads_new_middle_old: tuple[float, float, float]) -> list[PairBar]:
    """Build daily bars whose newest close in each week has the chosen spread."""

    dates = (
        datetime(2026, 8, 21, tzinfo=UTC),
        datetime(2026, 8, 20, tzinfo=UTC),
        datetime(2026, 8, 14, tzinfo=UTC),
        datetime(2026, 8, 13, tzinfo=UTC),
        datetime(2026, 8, 7, tzinfo=UTC),
    )
    selected = (
        spreads_new_middle_old[0],
        spreads_new_middle_old[0] - 0.01,
        spreads_new_middle_old[1],
        spreads_new_middle_old[1] + 0.01,
        spreads_new_middle_old[2],
    )
    xng = 25.0
    return [PairBar(opened, xng * math.exp(spread), xng) for opened, spread in zip(dates, selected)]


def consume_attempt(attempts: set[int], current_week_key: int) -> bool:
    if current_week_key in attempts:
        return False
    attempts.add(current_week_key)
    return True


def should_close(opened: datetime | None, now: datetime, max_days: int = 10) -> bool:
    if opened is None or opened > now:
        return True
    return week_key(opened) != week_key(now) or now - opened >= timedelta(days=max_days)


def package_lots(
    full_xti_lots: float,
    full_xng_lots: float,
    xti_notional_per_lot: float,
    xng_notional_per_lot: float,
    xti_step: float,
    xng_step: float,
) -> tuple[float, float, float, float]:
    ratio = xng_notional_per_lot / xti_notional_per_lot
    risk_per_xng_lot = ratio / full_xti_lots + 1.0 / full_xng_lots
    raw_xng = 1.0 / risk_per_xng_lot
    raw_xti = ratio * raw_xng
    xti = math.floor((raw_xti + 1.0e-12) / xti_step) * xti_step
    xng = math.floor((raw_xng + 1.0e-12) / xng_step) * xng_step
    normalized_risk = xti / full_xti_lots + xng / full_xng_lots
    notional_ratio = xti * xti_notional_per_lot / (xng * xng_notional_per_lot)
    return xti, xng, normalized_risk, notional_ratio


class WeeklyAccelerationReferenceTest(unittest.TestCase):
    def test_positive_acceleration_overshoot_sells_xti(self) -> None:
        bars = pair_bars((5.30, 5.10, 5.00))
        valid, direction, new_value, old_value, _ = weekly_acceleration_signal(20260824, bars)
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertAlmostEqual(new_value, 0.20)
        self.assertAlmostEqual(old_value, 0.10)

    def test_negative_acceleration_overshoot_buys_xti(self) -> None:
        bars = pair_bars((4.70, 4.90, 5.00))
        valid, direction, new_value, old_value, _ = weekly_acceleration_signal(20260824, bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertAlmostEqual(new_value, -0.20)
        self.assertAlmostEqual(old_value, -0.10)

    def test_equality_nondominance_opposed_sign_and_zero_are_flat(self) -> None:
        cases = (
            (5.20, 5.10, 5.00),
            (5.15, 5.10, 5.00),
            (5.20, 5.10, 5.15),
            (5.10, 5.10, 5.00),
        )
        for spreads in cases:
            with self.subTest(spreads=spreads):
                valid, direction, *_ = weekly_acceleration_signal(20260824, pair_bars(spreads))
                self.assertTrue(valid)
                self.assertEqual(direction, 0)

    def test_decision_clock_marks_first_bar_and_late_restart(self) -> None:
        current = datetime(2026, 8, 24, tzinfo=UTC)
        bars = pair_bars((5.20, 5.05, 5.10))
        self.assertEqual(decision_clock(current, current, current, bars), (True, False, 20260824))
        tuesday = datetime(2026, 8, 25, tzinfo=UTC)
        bars.insert(0, PairBar(current, 4_300.0, 25.0))
        self.assertEqual(decision_clock(tuesday, tuesday, tuesday, bars), (True, True, 20260824))
        self.assertEqual(
            decision_clock(current, current, current + timedelta(minutes=181), bars[1:]),
            (True, True, 20260824),
        )

    def test_clock_rejects_unsynchronized_or_skipped_week(self) -> None:
        current = datetime(2026, 8, 24, tzinfo=UTC)
        bars = pair_bars((5.20, 5.05, 5.10))
        self.assertFalse(decision_clock(current, current + timedelta(hours=1), current, bars)[0])
        bars[0] = PairBar(datetime(2026, 8, 14, tzinfo=UTC), bars[0].xti_close, bars[0].xng_close)
        self.assertFalse(decision_clock(current, current, current, bars)[0])

    def test_endpoint_validation_rejects_bad_order_gap_and_price(self) -> None:
        bars = pair_bars((5.20, 5.05, 5.10))
        bars[1] = PairBar(bars[0].opened + timedelta(days=1), bars[1].xti_close, bars[1].xng_close)
        self.assertFalse(weekly_acceleration_signal(20260824, bars)[0])
        bars = pair_bars((5.20, 5.05, 5.10))
        bars[-1] = PairBar(datetime(2026, 7, 31, tzinfo=UTC), bars[-1].xti_close, bars[-1].xng_close)
        self.assertFalse(weekly_acceleration_signal(20260824, bars)[0])
        bars = pair_bars((5.20, 5.05, 5.10))
        bars[2] = PairBar(bars[2].opened, 0.0, bars[2].xng_close)
        self.assertFalse(weekly_acceleration_signal(20260824, bars)[0])

    def test_week_key_crosses_year_and_attempt_is_single_use(self) -> None:
        self.assertEqual(week_key(datetime(2027, 1, 3, tzinfo=UTC)), 20261228)
        self.assertEqual(next_week_key(20261228), 20270104)
        attempts: set[int] = set()
        self.assertTrue(consume_attempt(attempts, 20270104))
        self.assertFalse(consume_attempt(attempts, 20270104))

    def test_next_week_and_stale_exit(self) -> None:
        opened = datetime(2026, 8, 24, 0, 1, tzinfo=UTC)
        self.assertFalse(should_close(opened, datetime(2026, 8, 28, tzinfo=UTC)))
        self.assertTrue(should_close(opened, datetime(2026, 8, 31, tzinfo=UTC)))
        self.assertTrue(should_close(opened, opened + timedelta(days=10)))
        self.assertTrue(should_close(None, opened))

    def test_package_rounding_never_exceeds_aggregate_risk(self) -> None:
        xti, xng, normalized_risk, notional_ratio = package_lots(
            1.2, 8.0, 430_000.0, 125_000.0, 0.01, 0.01
        )
        self.assertGreater(xti, 0.0)
        self.assertGreater(xng, 0.0)
        self.assertLessEqual(normalized_risk, 1.0 + 1.0e-12)
        self.assertLessEqual(abs(notional_ratio - 1.0) * 100.0, 20.0)


if __name__ == "__main__":
    unittest.main()


