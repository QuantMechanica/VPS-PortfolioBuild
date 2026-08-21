"""Reference checks for QM5_41079 XAU/XAG weekly closing-extreme reversion."""

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
    """Mirror the synchronized first-tradable-week-bar clock."""

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


def closing_extreme_signal(
    current_week_key: int,
    completed_newest_first: list[PairBar],
    min_sessions: int = 3,
    max_sessions: int = 5,
) -> tuple[bool, int, tuple[float, ...], int]:
    """Mirror the strict newest ratio rank inside the completed prior week."""

    prior_week = 0
    ratios: list[float] = []
    older_boundary_seen = False
    for index, bar in enumerate(completed_newest_first):
        if bar.xau_opened.timestamp() <= 0 or bar.xau_opened != bar.xag_opened:
            return False, 0, (), 0
        if index and completed_newest_first[index - 1].xau_opened <= bar.xau_opened:
            return False, 0, (), 0
        key = week_key(bar.xau_opened)
        if key == current_week_key:
            return False, 0, (), 0
        if prior_week == 0:
            if next_week_key(key) != current_week_key:
                return False, 0, (), 0
            prior_week = key
        elif key != prior_week:
            if next_week_key(key) != prior_week:
                return False, 0, (), 0
            older_boundary_seen = True
            break
        if len(ratios) >= max_sessions or len(ratios) >= 5:
            return False, 0, (), 0
        if (
            bar.xau_close <= 0.0
            or bar.xag_close <= 0.0
            or not math.isfinite(bar.xau_close)
            or not math.isfinite(bar.xag_close)
        ):
            return False, 0, (), 0
        ratios.append(math.log(bar.xau_close) - math.log(bar.xag_close))

    if not older_boundary_seen or not min_sessions <= len(ratios) <= max_sessions:
        return False, 0, (), 0
    upper = all(ratios[0] > value for value in ratios[1:])
    lower = all(ratios[0] < value for value in ratios[1:])
    direction = -1 if upper and not lower else 1 if lower and not upper else 0
    return True, direction, tuple(ratios), len(ratios)


def prior_week_bars(ratios_newest_first: tuple[float, ...]) -> list[PairBar]:
    """Build one prior-week series plus an older boundary close."""

    current_anchor = datetime(2026, 8, 24, tzinfo=UTC)
    prior_anchor = current_anchor - timedelta(days=7)
    xag = 25.0
    newest_offset = 5 if len(ratios_newest_first) > 5 else 4
    bars = [
        PairBar(
            prior_anchor + timedelta(days=newest_offset - index),
            prior_anchor + timedelta(days=newest_offset - index),
            xag * math.exp(ratio),
            xag,
        )
        for index, ratio in enumerate(ratios_newest_first)
    ]
    boundary = prior_anchor - timedelta(days=7) + timedelta(days=4)
    bars.append(PairBar(boundary, boundary, xag * math.exp(5.0), xag))
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


class WeeklyClosingExtremeReferenceTest(unittest.TestCase):
    def test_strict_upper_closing_extreme_sells_xau(self) -> None:
        valid, direction, ratios, count = closing_extreme_signal(
            20260824, prior_week_bars((5.20, 5.10, 5.15, 5.05, 5.00))
        )
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertEqual(count, 5)
        self.assertTrue(all(ratios[0] > value for value in ratios[1:]))

    def test_strict_lower_closing_extreme_buys_xau(self) -> None:
        valid, direction, ratios, count = closing_extreme_signal(
            20260824, prior_week_bars((4.80, 4.90, 4.85, 4.95, 5.00))
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertEqual(count, 5)
        self.assertTrue(all(ratios[0] < value for value in ratios[1:]))

    def test_equality_and_interior_newest_close_are_flat(self) -> None:
        cases = (
            (5.20, 5.10, 5.20, 5.00, 4.90),
            (5.00, 5.10, 4.90, 5.20, 4.80),
        )
        for ratios in cases:
            with self.subTest(ratios=ratios):
                valid, direction, *_ = closing_extreme_signal(
                    20260824, prior_week_bars(ratios)
                )
                self.assertTrue(valid)
                self.assertEqual(direction, 0)

    def test_three_four_and_five_session_weeks_are_valid(self) -> None:
        for ratios in ((5.2, 5.1, 5.0), (4.7, 4.8, 4.9, 5.0), (5.4, 5.3, 5.2, 5.1, 5.0)):
            with self.subTest(ratios=ratios):
                valid, direction, _, count = closing_extreme_signal(
                    20260824, prior_week_bars(ratios)
                )
                self.assertTrue(valid)
                self.assertNotEqual(direction, 0)
                self.assertEqual(count, len(ratios))

    def test_two_or_six_sessions_fail_closed(self) -> None:
        self.assertFalse(
            closing_extreme_signal(20260824, prior_week_bars((5.1, 5.0)))[0]
        )
        self.assertFalse(
            closing_extreme_signal(
                20260824, prior_week_bars((5.5, 5.4, 5.3, 5.2, 5.1, 5.0))
            )[0]
        )

    def test_decision_clock_marks_first_bar_and_late_restart(self) -> None:
        current = datetime(2026, 8, 24, tzinfo=UTC)
        bars = prior_week_bars((5.2, 5.1, 5.0, 4.9, 4.8))
        self.assertEqual(decision_clock(current, current, current, bars), (True, False, 20260824))
        tuesday = datetime(2026, 8, 25, tzinfo=UTC)
        bars.insert(0, PairBar(current, current, 4_300.0, 25.0))
        self.assertEqual(decision_clock(tuesday, tuesday, tuesday, bars), (True, True, 20260824))
        self.assertEqual(
            decision_clock(current, current, current + timedelta(minutes=181), bars[1:]),
            (True, True, 20260824),
        )

    def test_endpoint_validation_rejects_sync_order_gap_and_price(self) -> None:
        base = (5.2, 5.1, 5.0, 4.9, 4.8)
        bars = prior_week_bars(base)
        bars[0] = replace(bars[0], xag_opened=bars[0].xag_opened + timedelta(hours=1))
        self.assertFalse(closing_extreme_signal(20260824, bars)[0])
        bars = prior_week_bars(base)
        bars[1] = replace(bars[1], xau_opened=bars[0].xau_opened, xag_opened=bars[0].xag_opened)
        self.assertFalse(closing_extreme_signal(20260824, bars)[0])
        bars = prior_week_bars(base)
        bars[-1] = replace(
            bars[-1],
            xau_opened=bars[-1].xau_opened - timedelta(days=7),
            xag_opened=bars[-1].xag_opened - timedelta(days=7),
        )
        self.assertFalse(closing_extreme_signal(20260824, bars)[0])
        bars = prior_week_bars(base)
        bars[0] = replace(bars[0], xau_close=0.0)
        self.assertFalse(closing_extreme_signal(20260824, bars)[0])

    def test_current_week_data_is_rejected(self) -> None:
        bars = prior_week_bars((5.2, 5.1, 5.0, 4.9, 4.8))
        current = datetime(2026, 8, 24, tzinfo=UTC)
        bars.insert(0, PairBar(current, current, 4_300.0, 25.0))
        self.assertFalse(closing_extreme_signal(20260824, bars)[0])

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
