"""Reference checks for QM5_41077 XAU/XAG weekly partial retracement."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone


UTC = timezone.utc


@dataclass(frozen=True)
class PairBar:
    opened: datetime
    xau_close: float
    xag_close: float


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
    current_xau: datetime,
    current_xag: datetime,
    now: datetime,
    completed_newest_first: list[PairBar],
) -> tuple[bool, bool, int]:
    """Mirror the exact synchronized first-tradable-week-bar clock."""

    if current_xau != current_xag or current_xau.date() != now.date():
        return False, False, 0
    current_key = week_key(current_xau)
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
    late = current_count > 0 or not within_entry_grace(current_xau, now)
    return True, late, current_key


def weekly_retracement_signal(
    current_week_key: int,
    completed_newest_first: list[PairBar],
) -> tuple[bool, int, float, float, tuple[float, float, float]]:
    """Mirror synchronized week ends and a strict smaller opposite retracement."""

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
            bar.xau_close <= 0.0
            or bar.xag_close <= 0.0
            or not math.isfinite(bar.xau_close)
            or not math.isfinite(bar.xag_close)
        ):
            return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)
        keys.append(key)
        spreads.append(math.log(bar.xau_close) - math.log(bar.xag_close))
        if len(spreads) == 3:
            break
    if len(spreads) != 3:
        return False, 0, 0.0, 0.0, (0.0, 0.0, 0.0)

    new_return = spreads[0] - spreads[1]
    old_return = spreads[1] - spreads[2]
    direction = 0
    if old_return > 0.0 and new_return < 0.0 and abs(new_return) < abs(old_return):
        direction = -1
    elif old_return < 0.0 and new_return > 0.0 and abs(new_return) < abs(old_return):
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
    xag = 25.0
    return [PairBar(opened, xag * math.exp(spread), xag) for opened, spread in zip(dates, selected)]


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
    full_xau_lots: float,
    full_xag_lots: float,
    xau_notional_per_lot: float,
    xag_notional_per_lot: float,
    xau_step: float,
    xag_step: float,
) -> tuple[float, float, float, float]:
    ratio = xag_notional_per_lot / xau_notional_per_lot
    risk_per_xag_lot = ratio / full_xau_lots + 1.0 / full_xag_lots
    raw_xag = 1.0 / risk_per_xag_lot
    raw_xau = ratio * raw_xag
    xau = math.floor((raw_xau + 1.0e-12) / xau_step) * xau_step
    xag = math.floor((raw_xag + 1.0e-12) / xag_step) * xag_step
    normalized_risk = xau / full_xau_lots + xag / full_xag_lots
    notional_ratio = xau * xau_notional_per_lot / (xag * xag_notional_per_lot)
    return xau, xag, normalized_risk, notional_ratio


class WeeklyRetracementReferenceTest(unittest.TestCase):
    def test_positive_impulse_smaller_negative_retracement_sells_xau(self) -> None:
        bars = pair_bars((5.12, 5.20, 5.00))
        valid, direction, new_value, old_value, spreads = weekly_retracement_signal(20260824, bars)
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertAlmostEqual(new_value, -0.08)
        self.assertAlmostEqual(old_value, 0.20)
        self.assertGreater(spreads[0], spreads[2])
        self.assertLess(spreads[0], spreads[1])

    def test_negative_impulse_smaller_positive_retracement_buys_xau(self) -> None:
        bars = pair_bars((4.88, 4.80, 5.00))
        valid, direction, new_value, old_value, spreads = weekly_retracement_signal(20260824, bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertAlmostEqual(new_value, 0.08)
        self.assertAlmostEqual(old_value, -0.20)
        self.assertLess(spreads[0], spreads[2])
        self.assertGreater(spreads[0], spreads[1])

    def test_equality_larger_same_sign_and_zero_are_flat(self) -> None:
        cases = (
            (5.00, 5.20, 5.00),
            (4.90, 5.20, 5.00),
            (5.30, 5.20, 5.00),
            (5.20, 5.20, 5.00),
        )
        for spreads in cases:
            with self.subTest(spreads=spreads):
                valid, direction, *_ = weekly_retracement_signal(20260824, pair_bars(spreads))
                self.assertTrue(valid)
                self.assertEqual(direction, 0)

    def test_decision_clock_marks_first_bar_and_late_restart(self) -> None:
        current = datetime(2026, 8, 24, tzinfo=UTC)
        bars = pair_bars((5.12, 5.20, 5.00))
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
        bars = pair_bars((5.12, 5.20, 5.00))
        self.assertFalse(decision_clock(current, current + timedelta(hours=1), current, bars)[0])
        bars[0] = PairBar(datetime(2026, 8, 14, tzinfo=UTC), bars[0].xau_close, bars[0].xag_close)
        self.assertFalse(decision_clock(current, current, current, bars)[0])

    def test_endpoint_validation_rejects_bad_order_gap_and_price(self) -> None:
        bars = pair_bars((5.12, 5.20, 5.00))
        bars[1] = PairBar(bars[0].opened + timedelta(days=1), bars[1].xau_close, bars[1].xag_close)
        self.assertFalse(weekly_retracement_signal(20260824, bars)[0])
        bars = pair_bars((5.12, 5.20, 5.00))
        bars[-1] = PairBar(datetime(2026, 7, 31, tzinfo=UTC), bars[-1].xau_close, bars[-1].xag_close)
        self.assertFalse(weekly_retracement_signal(20260824, bars)[0])
        bars = pair_bars((5.12, 5.20, 5.00))
        bars[2] = PairBar(bars[2].opened, 0.0, bars[2].xag_close)
        self.assertFalse(weekly_retracement_signal(20260824, bars)[0])

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
        xau, xag, normalized_risk, notional_ratio = package_lots(
            1.2, 8.0, 430_000.0, 125_000.0, 0.01, 0.01
        )
        self.assertGreater(xau, 0.0)
        self.assertGreater(xag, 0.0)
        self.assertLessEqual(normalized_risk, 1.0 + 1.0e-12)
        self.assertLessEqual(abs(notional_ratio - 1.0) * 100.0, 20.0)


if __name__ == "__main__":
    unittest.main()
