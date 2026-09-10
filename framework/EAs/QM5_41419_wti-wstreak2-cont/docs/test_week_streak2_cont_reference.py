"""Deterministic reference checks for QM5_41419 WTI fresh-streak continuation."""

from __future__ import annotations

import math
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]


def week_key(value: datetime) -> int:
    monday = value - timedelta(days=value.weekday())
    return monday.year * 10_000 + monday.month * 100 + monday.day


def key_to_date(value: int) -> datetime:
    return datetime(value // 10_000, (value // 100) % 100, value % 100, tzinfo=UTC)


def next_week_key(value: int) -> int:
    anchor = key_to_date(value)
    if week_key(anchor) != value:
        return 0
    return week_key(anchor + timedelta(days=7))


def fresh_two_week_signal(closes: tuple[float, float, float, float]) -> int:
    if len(closes) != 4 or any(value <= 0 or not math.isfinite(value) for value in closes):
        return 0
    r0 = math.log(closes[0] / closes[1])
    r1 = math.log(closes[1] / closes[2])
    r2 = math.log(closes[2] / closes[3])
    if r0 > 0 and r1 > 0 and r2 < 0:
        return 1
    if r0 < 0 and r1 < 0 and r2 > 0:
        return -1
    return 0


def package_valid(keys: tuple[int, ...], counts: tuple[int, ...], current: int) -> bool:
    if len(keys) != 4 or len(counts) != 4:
        return False
    if next_week_key(keys[0]) != current:
        return False
    return all(
        3 <= counts[index] <= 5
        and (index == 0 or next_week_key(keys[index]) == keys[index - 1])
        for index in range(4)
    )


def should_close(opened: datetime | None, current: datetime, now: datetime) -> bool:
    if opened is None or opened > now:
        return True
    return week_key(opened) != week_key(current) or now - opened >= timedelta(days=10)


class WeekStreak2ContinuationReferenceTest(unittest.TestCase):
    def test_fresh_positive_streak_is_long(self) -> None:
        self.assertEqual(fresh_two_week_signal((120.0, 110.0, 100.0, 105.0)), 1)

    def test_fresh_negative_streak_is_short(self) -> None:
        self.assertEqual(fresh_two_week_signal((80.0, 90.0, 100.0, 95.0)), -1)

    def test_zero_rolling_and_mixed_paths_are_flat(self) -> None:
        cases = (
            (120.0, 110.0, 100.0, 90.0),
            (80.0, 90.0, 100.0, 110.0),
            (110.0, 110.0, 100.0, 105.0),
            (100.0, 110.0, 100.0, 105.0),
        )
        self.assertTrue(all(fresh_two_week_signal(case) == 0 for case in cases))

    def test_consecutive_week_and_session_contract(self) -> None:
        keys = (20260817, 20260810, 20260803, 20260727)
        self.assertTrue(package_valid(keys, (3, 4, 5, 3), 20260824))
        self.assertFalse(package_valid(keys, (2, 4, 5, 3), 20260824))
        self.assertFalse(package_valid(keys, (3, 4, 6, 3), 20260824))
        self.assertFalse(package_valid((20260817, 20260803, 20260727, 20260720), (5, 5, 5, 5), 20260824))

    def test_year_boundary_and_lifecycle(self) -> None:
        self.assertEqual(next_week_key(20261228), 20270104)
        opened = datetime(2026, 8, 24, 0, 1, tzinfo=UTC)
        self.assertFalse(should_close(opened, datetime(2026, 8, 28, tzinfo=UTC), datetime(2026, 8, 28, tzinfo=UTC)))
        self.assertTrue(should_close(opened, datetime(2026, 8, 31, tzinfo=UTC), datetime(2026, 8, 31, tzinfo=UTC)))
        self.assertTrue(should_close(opened, datetime(2026, 8, 28, tzinfo=UTC), opened + timedelta(days=10)))

    def test_static_build_contract_and_pacer_guard(self) -> None:
        source = (EA_DIR / "QM5_41419_wti-wstreak2-cont.mq5").read_text(encoding="utf-8")
        setfile = (EA_DIR / "sets" / "QM5_41419_wti-wstreak2-cont_XTIUSD.DWX_D1_backtest.set").read_text(encoding="utf-8")
        for marker in (
            "qm_ea_id != 41419",
            "strategy_required_weeks != 4",
            "return_r0 > strategy_return_epsilon",
            "direction = 1;",
            "QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1)",
            "req.tp = 0.0;",
            "opened_week_key != current_week_key",
        ):
            self.assertIn(marker, source)
        guard = source[source.index("bool Strategy_NoTradeFilter()") : source.index("// -----------------------------------------------------------------------------\n// Trade Entry.")]
        for forbidden in (
            "RISK_FIXED !=",
            "PORTFOLIO_WEIGHT !=",
            "qm_rng_seed !=",
            "qm_news_temporal !=",
            "qm_news_compliance !=",
            "qm_news_stale_max_hours !=",
            "qm_news_min_impact !=",
            "qm_news_mode_legacy !=",
            "qm_friday_close_enabled !=",
            "qm_friday_close_hour_broker !=",
            "qm_stress_reject_probability !=",
        ):
            self.assertNotIn(forbidden, guard)
        for marker in (
            "qm_ea_id=41419",
            "strategy_symbol=XTIUSD.DWX",
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "strategy_required_weeks=4",
        ):
            self.assertIn(marker, setfile)


if __name__ == "__main__":
    unittest.main()
