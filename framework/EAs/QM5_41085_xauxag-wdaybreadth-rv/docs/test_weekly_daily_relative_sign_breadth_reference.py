"""Reference checks for QM5_41085 XAU/XAG weekly daily-sign breadth reversion."""

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


def daily_breadth_signal(
    current_week_key: int,
    completed_newest_first: list[PairBar],
    required_sessions: int = 5,
    min_same_sign: int = 4,
) -> tuple[bool, int, tuple[float, ...], float, int, int]:
    """Mirror the strict parent-plus-five synchronized ratio reconstruction."""

    prior_week = 0
    newest_week_ratios: list[float] = []
    parent_final_ratio: float | None = None
    for index, bar in enumerate(completed_newest_first):
        if bar.xau_opened.timestamp() <= 0 or bar.xau_opened != bar.xag_opened:
            return False, 0, (), 0.0, 0, 0
        if index and completed_newest_first[index - 1].xau_opened <= bar.xau_opened:
            return False, 0, (), 0.0, 0, 0
        key = week_key(bar.xau_opened)
        if key == current_week_key:
            return False, 0, (), 0.0, 0, 0
        if prior_week == 0:
            if next_week_key(key) != current_week_key:
                return False, 0, (), 0.0, 0, 0
            prior_week = key
        if key == prior_week:
            if len(newest_week_ratios) >= required_sessions or len(newest_week_ratios) >= 5:
                return False, 0, (), 0.0, 0, 0
            if (
                bar.xau_close <= 0.0
                or bar.xag_close <= 0.0
                or not math.isfinite(bar.xau_close)
                or not math.isfinite(bar.xag_close)
            ):
                return False, 0, (), 0.0, 0, 0
            newest_week_ratios.append(math.log(bar.xau_close) - math.log(bar.xag_close))
            continue
        if next_week_key(key) != prior_week or len(newest_week_ratios) != required_sessions:
            return False, 0, (), 0.0, 0, 0
        if (
            bar.xau_close <= 0.0
            or bar.xag_close <= 0.0
            or not math.isfinite(bar.xau_close)
            or not math.isfinite(bar.xag_close)
        ):
            return False, 0, (), 0.0, 0, 0
        parent_final_ratio = math.log(bar.xau_close) - math.log(bar.xag_close)
        break

    if parent_final_ratio is None or len(newest_week_ratios) != required_sessions:
        return False, 0, (), 0.0, 0, 0
    chronological = (parent_final_ratio, *reversed(newest_week_ratios))
    relative_returns = tuple(
        chronological[index + 1] - chronological[index] for index in range(5)
    )
    positive_count = sum(value > 0.0 for value in relative_returns)
    negative_count = sum(value < 0.0 for value in relative_returns)
    weekly_net = chronological[-1] - chronological[0]
    direction = 0
    if positive_count >= min_same_sign and weekly_net > 0.0:
        direction = -1
    elif negative_count >= min_same_sign and weekly_net < 0.0:
        direction = 1
    return True, direction, relative_returns, weekly_net, positive_count, negative_count


def completed_week_bars(parent_ratio: float, week_ratios: tuple[float, ...]) -> list[PairBar]:
    """Build newest-first completed bars plus the consecutive parent final."""

    current_anchor = datetime(2026, 8, 24, tzinfo=UTC)
    prior_anchor = current_anchor - timedelta(days=7)
    xag = 25.0
    bars = [
        PairBar(
            prior_anchor + timedelta(days=index),
            prior_anchor + timedelta(days=index),
            xag * math.exp(ratio),
            xag,
        )
        for index, ratio in enumerate(week_ratios)
    ]
    bars.reverse()
    parent_final = prior_anchor - timedelta(days=3)
    bars.append(PairBar(parent_final, parent_final, xag * math.exp(parent_ratio), xag))
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


class WeeklyDailyRelativeSignBreadthReferenceTest(unittest.TestCase):
    def test_four_positive_components_and_positive_net_sell_xau(self) -> None:
        result = daily_breadth_signal(
            20260824, completed_week_bars(5.00, (5.10, 5.20, 5.15, 5.30, 5.40))
        )
        valid, direction, _, weekly_net, positive_count, negative_count = result
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertGreater(weekly_net, 0.0)
        self.assertEqual((positive_count, negative_count), (4, 1))

    def test_four_negative_components_and_negative_net_buy_xau(self) -> None:
        result = daily_breadth_signal(
            20260824, completed_week_bars(5.40, (5.30, 5.20, 5.25, 5.10, 5.00))
        )
        valid, direction, _, weekly_net, positive_count, negative_count = result
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertLess(weekly_net, 0.0)
        self.assertEqual((positive_count, negative_count), (1, 4))

    def test_breadth_net_disagreement_is_flat(self) -> None:
        valid, direction, _, weekly_net, positive_count, _ = daily_breadth_signal(
            20260824, completed_week_bars(5.00, (5.10, 5.20, 5.30, 5.40, 4.80))
        )
        self.assertTrue(valid)
        self.assertEqual(positive_count, 4)
        self.assertLess(weekly_net, 0.0)
        self.assertEqual(direction, 0)

    def test_three_of_five_and_zero_components_are_flat(self) -> None:
        cases = (
            (5.00, (5.10, 5.00, 5.10, 5.00, 5.10)),
            (5.00, (5.10, 5.10, 5.20, 5.20, 5.30)),
        )
        for parent, ratios in cases:
            with self.subTest(ratios=ratios):
                valid, direction, *_ = daily_breadth_signal(
                    20260824, completed_week_bars(parent, ratios)
                )
                self.assertTrue(valid)
                self.assertEqual(direction, 0)

    def test_four_or_six_session_weeks_fail_closed(self) -> None:
        for ratios in (
            (5.10, 5.20, 5.30, 5.40),
            (5.10, 5.20, 5.30, 5.40, 5.50, 5.60),
        ):
            with self.subTest(count=len(ratios)):
                self.assertFalse(
                    daily_breadth_signal(
                        20260824, completed_week_bars(5.00, ratios)
                    )[0]
                )

    def test_endpoint_validation_rejects_async_order_gap_price_and_parent(self) -> None:
        ratios = (5.10, 5.20, 5.15, 5.30, 5.40)
        bars = completed_week_bars(5.00, ratios)
        bars[0] = replace(bars[0], xag_opened=bars[0].xag_opened + timedelta(hours=1))
        self.assertFalse(daily_breadth_signal(20260824, bars)[0])
        bars = completed_week_bars(5.00, ratios)
        bars[1] = replace(
            bars[1], xau_opened=bars[0].xau_opened, xag_opened=bars[0].xag_opened
        )
        self.assertFalse(daily_breadth_signal(20260824, bars)[0])
        bars = completed_week_bars(5.00, ratios)
        bars[-1] = replace(
            bars[-1],
            xau_opened=bars[-1].xau_opened - timedelta(days=7),
            xag_opened=bars[-1].xag_opened - timedelta(days=7),
        )
        self.assertFalse(daily_breadth_signal(20260824, bars)[0])
        bars = completed_week_bars(5.00, ratios)
        bars[0] = replace(bars[0], xau_close=0.0)
        self.assertFalse(daily_breadth_signal(20260824, bars)[0])
        self.assertFalse(
            daily_breadth_signal(20260824, completed_week_bars(5.00, ratios)[:-1])[0]
        )

    def test_current_week_data_is_rejected(self) -> None:
        bars = completed_week_bars(5.00, (5.10, 5.20, 5.15, 5.30, 5.40))
        current = datetime(2026, 8, 24, tzinfo=UTC)
        bars.insert(0, PairBar(current, current, 4_300.0, 25.0))
        self.assertFalse(daily_breadth_signal(20260824, bars)[0])

    def test_decision_clock_marks_first_bar_and_late_restart(self) -> None:
        current = datetime(2026, 8, 24, tzinfo=UTC)
        bars = completed_week_bars(5.00, (5.10, 5.20, 5.15, 5.30, 5.40))
        self.assertEqual(decision_clock(current, current, current, bars), (True, False, 20260824))
        tuesday = datetime(2026, 8, 25, tzinfo=UTC)
        late_bars = [PairBar(current, current, 4_300.0, 25.0), *bars]
        self.assertEqual(
            decision_clock(tuesday, tuesday, tuesday, late_bars),
            (True, True, 20260824),
        )
        self.assertEqual(
            decision_clock(current, current, current + timedelta(minutes=181), bars),
            (True, True, 20260824),
        )

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
