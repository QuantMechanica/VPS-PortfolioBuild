"""Reference checks for QM5_41078 XAU/XAG weekly sign-streak reversion."""

from __future__ import annotations

import math
import unittest
from dataclasses import dataclass, replace
from datetime import datetime, timedelta, timezone


UTC = timezone.utc


@dataclass(frozen=True)
class PairBar:
    xau_opened: datetime
    xag_opened: datetime
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
        if bar.xau_opened != bar.xag_opened:
            return False, False, 0
        if index and completed_newest_first[index - 1].xau_opened <= bar.xau_opened:
            return False, False, 0
        if week_key(bar.xau_opened) != current_key:
            break
        current_count += 1
    if current_count >= len(completed_newest_first):
        return False, False, 0
    prior_week = week_key(completed_newest_first[current_count].xau_opened)
    if next_week_key(prior_week) != current_key:
        return False, False, 0
    late = current_count > 0 or not within_entry_grace(current_xau, now)
    return True, late, current_key


def weekly_streak_signal(
    current_week_key: int,
    completed_newest_first: list[PairBar],
) -> tuple[bool, int, tuple[float, float, float, float], tuple[float, ...], tuple[int, ...]]:
    """Mirror five synchronized week ends and the strict fresh sign path."""

    keys: list[int] = []
    counts: list[int] = []
    spreads: list[float] = []
    oldest_boundary_seen = False

    for index, bar in enumerate(completed_newest_first):
        if bar.xau_opened.timestamp() <= 0 or bar.xau_opened != bar.xag_opened:
            return False, 0, (0.0,) * 4, (), ()
        if index and completed_newest_first[index - 1].xau_opened <= bar.xau_opened:
            return False, 0, (0.0,) * 4, (), ()
        key = week_key(bar.xau_opened)
        if key == current_week_key:
            return False, 0, (0.0,) * 4, (), ()

        if not keys or key != keys[-1]:
            if len(keys) >= 5:
                if next_week_key(key) != keys[-1]:
                    return False, 0, (0.0,) * 4, (), ()
                oldest_boundary_seen = True
                break
            if not keys:
                if next_week_key(key) != current_week_key:
                    return False, 0, (0.0,) * 4, (), ()
            elif next_week_key(key) != keys[-1]:
                return False, 0, (0.0,) * 4, (), ()
            if (
                bar.xau_close <= 0.0
                or bar.xag_close <= 0.0
                or not math.isfinite(bar.xau_close)
                or not math.isfinite(bar.xag_close)
            ):
                return False, 0, (0.0,) * 4, (), ()
            keys.append(key)
            counts.append(0)
            spreads.append(math.log(bar.xau_close) - math.log(bar.xag_close))

        counts[-1] += 1
        if counts[-1] > 5:
            return False, 0, (0.0,) * 4, (), ()

    if len(keys) != 5 or not oldest_boundary_seen:
        return False, 0, (0.0,) * 4, (), ()
    if any(count < 3 or count > 5 for count in counts):
        return False, 0, (0.0,) * 4, (), ()

    returns = (
        spreads[0] - spreads[1],
        spreads[1] - spreads[2],
        spreads[2] - spreads[3],
        spreads[3] - spreads[4],
    )
    if not all(math.isfinite(value) for value in returns):
        return False, 0, (0.0,) * 4, (), ()

    direction = 0
    if returns[0] > 0.0 and returns[1] > 0.0 and returns[2] > 0.0 and returns[3] < 0.0:
        direction = -1
    elif returns[0] < 0.0 and returns[1] < 0.0 and returns[2] < 0.0 and returns[3] > 0.0:
        direction = 1
    return True, direction, returns, tuple(spreads), tuple(counts)


def pair_bars(
    spreads_newest_first: tuple[float, float, float, float, float],
    counts: tuple[int, int, int, int, int] = (5, 5, 5, 5, 5),
) -> list[PairBar]:
    """Build descending daily pairs plus one older boundary bar."""

    current_anchor = datetime(2026, 8, 24, tzinfo=UTC)
    xag = 25.0
    bars: list[PairBar] = []
    for week_index, (spread, count) in enumerate(zip(spreads_newest_first, counts)):
        anchor = current_anchor - timedelta(days=7 * (week_index + 1))
        newest_offset = 5 if count > 5 else 4
        for day_index in range(count):
            opened = anchor + timedelta(days=newest_offset - day_index)
            intrawEEK_spread = spread - 0.001 * day_index
            bars.append(PairBar(opened, opened, xag * math.exp(intrawEEK_spread), xag))
    boundary = current_anchor - timedelta(days=42) + timedelta(days=4)
    bars.append(PairBar(boundary, boundary, xag * math.exp(4.75), xag))
    return bars


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


class WeeklyStreakReversionReferenceTest(unittest.TestCase):
    def test_fresh_positive_three_week_streak_sells_xau(self) -> None:
        bars = pair_bars((5.20, 5.10, 5.00, 4.90, 5.00))
        valid, direction, returns, spreads, counts = weekly_streak_signal(20260824, bars)
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertTrue(all(value > 0.0 for value in returns[:3]))
        self.assertLess(returns[3], 0.0)
        self.assertEqual(counts, (5, 5, 5, 5, 5))
        self.assertEqual(len(spreads), 5)

    def test_fresh_negative_three_week_streak_buys_xau(self) -> None:
        bars = pair_bars((4.80, 4.90, 5.00, 5.10, 5.00))
        valid, direction, returns, *_ = weekly_streak_signal(20260824, bars)
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertTrue(all(value < 0.0 for value in returns[:3]))
        self.assertGreater(returns[3], 0.0)

    def test_zero_rolling_and_mixed_paths_are_flat(self) -> None:
        cases = (
            (5.20, 5.10, 5.00, 5.00, 5.10),
            (5.40, 5.30, 5.20, 5.10, 5.00),
            (5.20, 5.10, 5.00, 5.10, 5.00),
        )
        for spreads in cases:
            with self.subTest(spreads=spreads):
                valid, direction, *_ = weekly_streak_signal(20260824, pair_bars(spreads))
                self.assertTrue(valid)
                self.assertEqual(direction, 0)

    def test_week_session_bounds_are_strict(self) -> None:
        spreads = (5.20, 5.10, 5.00, 4.90, 5.00)
        valid, direction, _, _, counts = weekly_streak_signal(
            20260824, pair_bars(spreads, (3, 4, 5, 3, 5))
        )
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertEqual(counts, (3, 4, 5, 3, 5))
        self.assertFalse(weekly_streak_signal(20260824, pair_bars(spreads, (2, 5, 5, 5, 5)))[0])
        self.assertFalse(weekly_streak_signal(20260824, pair_bars(spreads, (6, 5, 5, 5, 5)))[0])

    def test_decision_clock_marks_first_bar_and_late_restart(self) -> None:
        current = datetime(2026, 8, 24, tzinfo=UTC)
        bars = pair_bars((5.20, 5.10, 5.00, 4.90, 5.00))
        self.assertEqual(decision_clock(current, current, current, bars), (True, False, 20260824))
        tuesday = datetime(2026, 8, 25, tzinfo=UTC)
        bars.insert(0, PairBar(current, current, 4_300.0, 25.0))
        self.assertEqual(decision_clock(tuesday, tuesday, tuesday, bars), (True, True, 20260824))
        self.assertEqual(
            decision_clock(current, current, current + timedelta(minutes=181), bars[1:]),
            (True, True, 20260824),
        )

    def test_clock_rejects_unsynchronized_or_skipped_week(self) -> None:
        current = datetime(2026, 8, 24, tzinfo=UTC)
        bars = pair_bars((5.20, 5.10, 5.00, 4.90, 5.00))
        self.assertFalse(decision_clock(current, current + timedelta(hours=1), current, bars)[0])
        skipped = replace(bars[0], xau_opened=datetime(2026, 8, 7, tzinfo=UTC), xag_opened=datetime(2026, 8, 7, tzinfo=UTC))
        bars[0] = skipped
        self.assertFalse(decision_clock(current, current, current, bars)[0])

    def test_endpoint_validation_rejects_sync_order_gap_and_price(self) -> None:
        spreads = (5.20, 5.10, 5.00, 4.90, 5.00)
        bars = pair_bars(spreads)
        bars[0] = replace(bars[0], xag_opened=bars[0].xag_opened + timedelta(hours=1))
        self.assertFalse(weekly_streak_signal(20260824, bars)[0])
        bars = pair_bars(spreads)
        bars[1] = replace(bars[1], xau_opened=bars[0].xau_opened + timedelta(days=1), xag_opened=bars[0].xau_opened + timedelta(days=1))
        self.assertFalse(weekly_streak_signal(20260824, bars)[0])
        bars = pair_bars(spreads)
        bars[15] = replace(bars[15], xau_opened=bars[15].xau_opened - timedelta(days=7), xag_opened=bars[15].xag_opened - timedelta(days=7))
        self.assertFalse(weekly_streak_signal(20260824, bars)[0])
        bars = pair_bars(spreads)
        bars[0] = replace(bars[0], xau_close=0.0)
        self.assertFalse(weekly_streak_signal(20260824, bars)[0])

    def test_only_week_end_closes_drive_signal(self) -> None:
        bars = pair_bars((5.20, 5.10, 5.00, 4.90, 5.00))
        baseline = weekly_streak_signal(20260824, bars)
        for index, bar in enumerate(bars[:-1]):
            if index % 5:
                bars[index] = replace(bar, xau_close=bar.xau_close * math.exp(0.75))
        changed = weekly_streak_signal(20260824, bars)
        self.assertEqual(baseline[0:4], changed[0:4])

    def test_week_key_crosses_year_and_attempt_is_single_use(self) -> None:
        self.assertEqual(week_key(datetime(2027, 1, 3, tzinfo=UTC)), 20261228)
        self.assertEqual(next_week_key(20261228), 20270104)
        attempts: set[int] = set()
        self.assertTrue(consume_attempt(attempts, 20270104))
        self.assertFalse(consume_attempt(attempts, 20270104))

    def test_next_week_stale_exit_and_package_risk(self) -> None:
        opened = datetime(2026, 8, 24, 0, 1, tzinfo=UTC)
        self.assertFalse(should_close(opened, datetime(2026, 8, 28, tzinfo=UTC)))
        self.assertTrue(should_close(opened, datetime(2026, 8, 31, tzinfo=UTC)))
        self.assertTrue(should_close(opened, opened + timedelta(days=10)))
        self.assertTrue(should_close(None, opened))
        xau, xag, normalized_risk, notional_ratio = package_lots(
            1.2, 8.0, 430_000.0, 125_000.0, 0.01, 0.01
        )
        self.assertGreater(xau, 0.0)
        self.assertGreater(xag, 0.0)
        self.assertLessEqual(normalized_risk, 1.0 + 1.0e-12)
        self.assertLessEqual(abs(notional_ratio - 1.0) * 100.0, 20.0)


if __name__ == "__main__":
    unittest.main()
