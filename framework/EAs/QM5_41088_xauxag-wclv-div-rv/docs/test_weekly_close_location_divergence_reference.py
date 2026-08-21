"""Reference checks for QM5_41088 XAU/XAG weekly CLV divergence."""

from __future__ import annotations

import json
import math
import re
import unittest
from dataclasses import dataclass, replace
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
LOWER = 0.333333333333
UPPER = 0.666666666667
EA_DIR = Path(__file__).resolve().parents[1]
MQ5 = EA_DIR / "QM5_41088_xauxag-wclv-div-rv.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41088_xauxag-wclv-div-rv_QM5_41088_XAU_XAG_WCLVDIV_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"


@dataclass(frozen=True)
class PairBar:
    xau_time: datetime
    xag_time: datetime
    xau_open: float
    xau_high: float
    xau_low: float
    xau_close: float
    xag_open: float
    xag_high: float
    xag_low: float
    xag_close: float


def date_key(value: datetime) -> int:
    return value.year * 10000 + value.month * 100 + value.day


def week_key(value: datetime) -> int:
    monday = value - timedelta(days=value.weekday())
    return date_key(monday)


def key_to_date(value: int) -> datetime:
    return datetime(value // 10000, (value // 100) % 100, value % 100, tzinfo=UTC)


def next_week_key(value: int) -> int:
    return week_key(key_to_date(value) + timedelta(days=7))


def make_week(
    monday: datetime,
    xau: tuple[float, float, float],
    xag: tuple[float, float, float],
    count: int = 5,
) -> list[PairBar]:
    """Return newest-first bars whose aggregate is (low, high, final close)."""
    xau_low, xau_high, xau_close = xau
    xag_low, xag_high, xag_close = xag
    xau_mid = (xau_low + xau_high) / 2.0
    xag_mid = (xag_low + xag_high) / 2.0
    bars: list[PairBar] = []
    for offset in range(count):
        when = monday + timedelta(days=offset)
        bars.append(
            PairBar(
                when,
                when,
                xau_mid,
                xau_high if offset == 1 else max(xau_mid, xau_close),
                xau_low if offset == 2 else min(xau_mid, xau_close),
                xau_close if offset == count - 1 else xau_mid,
                xag_mid,
                xag_high if offset == 1 else max(xag_mid, xag_close),
                xag_low if offset == 2 else min(xag_mid, xag_close),
                xag_close if offset == count - 1 else xag_mid,
            )
        )
    return list(reversed(bars))


def completed_bars(
    xau: tuple[float, float, float],
    xag: tuple[float, float, float],
    count: int = 5,
) -> list[PairBar]:
    newest = make_week(datetime(2026, 8, 17, tzinfo=UTC), xau, xag, count)
    older = make_week(
        datetime(2026, 8, 10, tzinfo=UTC),
        (100.0, 110.0, 105.0),
        (20.0, 30.0, 25.0),
        5,
    )
    return newest + older


def weekly_clv_divergence_signal(
    current_week: int,
    bars: list[PairBar],
    min_sessions: int = 3,
    max_sessions: int = 5,
) -> tuple[bool, int, float, float, int]:
    completed_week = 0
    sessions = 0
    xau_high = xau_low = xau_close = 0.0
    xag_high = xag_low = xag_close = 0.0

    for index, bar in enumerate(bars):
        if bar.xau_time != bar.xag_time:
            return False, 0, 0.0, 0.0, 0
        if index and bars[index - 1].xau_time <= bar.xau_time:
            return False, 0, 0.0, 0.0, 0
        candidate_week = week_key(bar.xau_time)
        if candidate_week == current_week:
            return False, 0, 0.0, 0.0, 0
        if completed_week == 0:
            if next_week_key(candidate_week) != current_week:
                return False, 0, 0.0, 0.0, 0
            completed_week = candidate_week
        elif candidate_week != completed_week:
            break

        values = (
            bar.xau_open,
            bar.xau_high,
            bar.xau_low,
            bar.xau_close,
            bar.xag_open,
            bar.xag_high,
            bar.xag_low,
            bar.xag_close,
        )
        if any(value <= 0.0 or not math.isfinite(value) for value in values):
            return False, 0, 0.0, 0.0, 0
        if not (
            bar.xau_high >= max(bar.xau_open, bar.xau_close)
            and bar.xau_low <= min(bar.xau_open, bar.xau_close)
            and bar.xag_high >= max(bar.xag_open, bar.xag_close)
            and bar.xag_low <= min(bar.xag_open, bar.xag_close)
        ):
            return False, 0, 0.0, 0.0, 0

        if sessions == 0:
            xau_high, xau_low, xau_close = bar.xau_high, bar.xau_low, bar.xau_close
            xag_high, xag_low, xag_close = bar.xag_high, bar.xag_low, bar.xag_close
        else:
            xau_high, xau_low = max(xau_high, bar.xau_high), min(xau_low, bar.xau_low)
            xag_high, xag_low = max(xag_high, bar.xag_high), min(xag_low, bar.xag_low)
        sessions += 1

    if (
        not completed_week
        or next_week_key(completed_week) != current_week
        or not min_sessions <= sessions <= max_sessions
    ):
        return False, 0, 0.0, 0.0, sessions
    xau_range = xau_high - xau_low
    xag_range = xag_high - xag_low
    if xau_range <= 0.0 or xag_range <= 0.0:
        return False, 0, 0.0, 0.0, sessions
    xau_clv = (xau_close - xau_low) / xau_range
    xag_clv = (xag_close - xag_low) / xag_range
    if not (0.0 <= xau_clv <= 1.0 and 0.0 <= xag_clv <= 1.0):
        return False, 0, 0.0, 0.0, sessions
    direction = 0
    if xau_clv > UPPER and xag_clv < LOWER:
        direction = -1
    elif xau_clv < LOWER and xag_clv > UPPER:
        direction = 1
    return True, direction, xau_clv, xag_clv, sessions


def within_entry_grace(current_bar: datetime, now: datetime, minutes: int = 180) -> bool:
    elapsed = (now - current_bar).total_seconds()
    return 0 <= elapsed <= minutes * 60


def consume_attempt(attempts: set[int], current_week: int) -> bool:
    if current_week in attempts:
        return False
    attempts.add(current_week)
    return True


def should_close(opened: datetime | None, now: datetime, max_days: int = 10) -> bool:
    if opened is None or now <= opened:
        return False
    return week_key(now) != week_key(opened) or now - opened >= timedelta(days=max_days)


def package_lots(
    xau_risk_per_lot: float,
    xag_risk_per_lot: float,
    xau_notional_per_lot: float,
    xag_notional_per_lot: float,
    xau_step: float = 0.01,
    xag_step: float = 0.01,
) -> tuple[float, float, float, float]:
    full_xau = 1000.0 / xau_risk_per_lot
    full_xag = 1000.0 / xag_risk_per_lot
    xau_to_xag = xag_notional_per_lot / xau_notional_per_lot
    normalized_per_xag = xau_to_xag / full_xau + 1.0 / full_xag
    raw_xag = 1.0 / normalized_per_xag
    raw_xau = xau_to_xag * raw_xag
    xau_lots = math.floor((raw_xau + 1e-12) / xau_step) * xau_step
    xag_lots = math.floor((raw_xag + 1e-12) / xag_step) * xag_step
    normalized_risk = xau_lots / full_xau + xag_lots / full_xag
    notional_ratio = (
        xau_lots * xau_notional_per_lot / (xag_lots * xag_notional_per_lot)
    )
    return xau_lots, xag_lots, normalized_risk, notional_ratio


class WeeklyCloseLocationDivergenceReferenceTest(unittest.TestCase):
    def test_xau_upper_xag_lower_fades_with_short_xau(self) -> None:
        valid, direction, xau_clv, xag_clv, sessions = weekly_clv_divergence_signal(
            20260824,
            completed_bars((100.0, 130.0, 125.0), (20.0, 50.0, 25.0)),
        )
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertGreater(xau_clv, UPPER)
        self.assertLess(xag_clv, LOWER)
        self.assertEqual(sessions, 5)

    def test_xau_lower_xag_upper_fades_with_long_xau(self) -> None:
        valid, direction, xau_clv, xag_clv, _ = weekly_clv_divergence_signal(
            20260824,
            completed_bars((100.0, 130.0, 105.0), (20.0, 50.0, 45.0)),
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertLess(xau_clv, LOWER)
        self.assertGreater(xag_clv, UPPER)

    def test_boundaries_interior_and_same_outer_tercile_are_flat(self) -> None:
        states = (
            ((1.0, 2.0, 1.0 + LOWER), (1.0, 2.0, 1.0 + UPPER)),
            ((100.0, 130.0, 115.0), (20.0, 50.0, 35.0)),
            ((100.0, 130.0, 125.0), (20.0, 50.0, 45.0)),
        )
        for xau, xag in states:
            with self.subTest(xau=xau, xag=xag):
                valid, direction, *_ = weekly_clv_divergence_signal(
                    20260824, completed_bars(xau, xag)
                )
                self.assertTrue(valid)
                self.assertEqual(direction, 0)

    def test_session_bounds_fail_closed(self) -> None:
        setup = ((100.0, 130.0, 125.0), (20.0, 50.0, 25.0))
        self.assertFalse(weekly_clv_divergence_signal(20260824, completed_bars(*setup, count=2))[0])
        self.assertFalse(weekly_clv_divergence_signal(20260824, completed_bars(*setup, count=6))[0])

    def test_asynchrony_and_invalid_ohlc_fail_closed(self) -> None:
        bars = completed_bars((100.0, 130.0, 125.0), (20.0, 50.0, 25.0))
        bars[0] = replace(bars[0], xag_time=bars[0].xag_time - timedelta(hours=1))
        self.assertFalse(weekly_clv_divergence_signal(20260824, bars)[0])

        invalid = completed_bars((100.0, 130.0, 125.0), (20.0, 50.0, 25.0))
        invalid[0] = replace(invalid[0], xau_high=90.0)
        self.assertFalse(weekly_clv_divergence_signal(20260824, invalid)[0])

    def test_zero_aggregate_range_fails_closed(self) -> None:
        bars = completed_bars((100.0, 100.0, 100.0), (20.0, 50.0, 25.0))
        self.assertFalse(weekly_clv_divergence_signal(20260824, bars)[0])

    def test_uniform_timestamp_shift_preserves_week_label_and_signal(self) -> None:
        bars = completed_bars((100.0, 130.0, 125.0), (20.0, 50.0, 25.0))
        shifted = [
            replace(
                bar,
                xau_time=bar.xau_time + timedelta(hours=1),
                xag_time=bar.xag_time + timedelta(hours=1),
            )
            for bar in bars
        ]
        self.assertEqual(
            weekly_clv_divergence_signal(20260824, bars)[0:2],
            weekly_clv_divergence_signal(20260824, shifted)[0:2],
        )

    def test_attempt_clock_and_lifecycle_are_bounded(self) -> None:
        attempts: set[int] = set()
        self.assertTrue(consume_attempt(attempts, 20260824))
        self.assertFalse(consume_attempt(attempts, 20260824))
        monday = datetime(2026, 8, 24, tzinfo=UTC)
        self.assertTrue(within_entry_grace(monday, monday + timedelta(minutes=180)))
        self.assertFalse(within_entry_grace(monday, monday + timedelta(minutes=181)))
        self.assertFalse(should_close(monday, monday + timedelta(days=4)))
        self.assertTrue(should_close(monday, monday + timedelta(days=7)))

    def test_aggregate_risk_and_notional_round_down(self) -> None:
        xau, xag, normalized_risk, ratio = package_lots(
            xau_risk_per_lot=2100.0,
            xag_risk_per_lot=700.0,
            xau_notional_per_lot=240000.0,
            xag_notional_per_lot=30000.0,
        )
        self.assertGreater(xau, 0.0)
        self.assertGreater(xag, 0.0)
        self.assertLessEqual(normalized_risk, 1.0 + 1e-8)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_artifacts_lock_identity_and_safety(self) -> None:
        source = MQ5.read_text(encoding="utf-8")
        preset = SETFILE.read_text(encoding="utf-8")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertIn("qm_ea_id                    = 41088", source)
        self.assertIn("Strategy_LoadWeeklyCloseLocationDivergence", source)
        self.assertIn("g_xau_clv > strategy_clv_upper", source)
        self.assertIn("g_xag_clv < strategy_clv_lower", source)
        self.assertIn("g_xau_clv < strategy_clv_lower", source)
        self.assertIn("g_xag_clv > strategy_clv_upper", source)
        self.assertIn("strategy_min_week_sessions == 3", source)
        self.assertIn("strategy_max_week_sessions == 5", source)
        self.assertNotIn("41083", source)
        self.assertRegex(preset, r"(?m)^RISK_FIXED=1000$")
        self.assertRegex(preset, r"(?m)^RISK_PERCENT=0$")
        self.assertRegex(preset, r"(?m)^strategy_clv_lower=0\.333333333333$")
        self.assertRegex(preset, r"(?m)^strategy_clv_upper=0\.666666666667$")
        self.assertRegex(preset, r"(?m)^qm_friday_close_enabled=false$")
        self.assertEqual(manifest["logical_symbol"], "QM5_41088_XAU_XAG_WCLVDIV_RV_D1")
        self.assertEqual(manifest["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        resolver = (EA_DIR.parents[1] / "include" / "QM" / "QM_MagicResolver.mqh").read_text(
            encoding="utf-8"
        )
        self.assertRegex(resolver, re.compile(r"410880000.*410880001", re.DOTALL))


if __name__ == "__main__":
    unittest.main()
