"""Reference checks for QM5_41364 XTI/XNG weekly CLV divergence."""

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
MQ5 = EA_DIR / "QM5_41364_xtixng-wclv-div-rv.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41364_xtixng-wclv-div-rv_QM5_41364_XTI_XNG_WCLVDIV_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"


@dataclass(frozen=True)
class PairBar:
    xti_time: datetime
    xng_time: datetime
    xti_open: float
    xti_high: float
    xti_low: float
    xti_close: float
    xng_open: float
    xng_high: float
    xng_low: float
    xng_close: float


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
    xti: tuple[float, float, float],
    xng: tuple[float, float, float],
    count: int = 5,
) -> list[PairBar]:
    """Return newest-first bars whose aggregate is (low, high, final close)."""
    xti_low, xti_high, xti_close = xti
    xng_low, xng_high, xng_close = xng
    xti_mid = (xti_low + xti_high) / 2.0
    xng_mid = (xng_low + xng_high) / 2.0
    bars: list[PairBar] = []
    for offset in range(count):
        when = monday + timedelta(days=offset)
        bars.append(
            PairBar(
                when,
                when,
                xti_mid,
                xti_high if offset == 1 else max(xti_mid, xti_close),
                xti_low if offset == 2 else min(xti_mid, xti_close),
                xti_close if offset == count - 1 else xti_mid,
                xng_mid,
                xng_high if offset == 1 else max(xng_mid, xng_close),
                xng_low if offset == 2 else min(xng_mid, xng_close),
                xng_close if offset == count - 1 else xng_mid,
            )
        )
    return list(reversed(bars))


def completed_bars(
    xti: tuple[float, float, float],
    xng: tuple[float, float, float],
    count: int = 5,
) -> list[PairBar]:
    newest = make_week(datetime(2026, 8, 17, tzinfo=UTC), xti, xng, count)
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
    xti_high = xti_low = xti_close = 0.0
    xng_high = xng_low = xng_close = 0.0

    for index, bar in enumerate(bars):
        if bar.xti_time != bar.xng_time:
            return False, 0, 0.0, 0.0, 0
        if index and bars[index - 1].xti_time <= bar.xti_time:
            return False, 0, 0.0, 0.0, 0
        candidate_week = week_key(bar.xti_time)
        if candidate_week == current_week:
            return False, 0, 0.0, 0.0, 0
        if completed_week == 0:
            if next_week_key(candidate_week) != current_week:
                return False, 0, 0.0, 0.0, 0
            completed_week = candidate_week
        elif candidate_week != completed_week:
            break

        values = (
            bar.xti_open,
            bar.xti_high,
            bar.xti_low,
            bar.xti_close,
            bar.xng_open,
            bar.xng_high,
            bar.xng_low,
            bar.xng_close,
        )
        if any(value <= 0.0 or not math.isfinite(value) for value in values):
            return False, 0, 0.0, 0.0, 0
        if not (
            bar.xti_high >= max(bar.xti_open, bar.xti_close)
            and bar.xti_low <= min(bar.xti_open, bar.xti_close)
            and bar.xng_high >= max(bar.xng_open, bar.xng_close)
            and bar.xng_low <= min(bar.xng_open, bar.xng_close)
        ):
            return False, 0, 0.0, 0.0, 0

        if sessions == 0:
            xti_high, xti_low, xti_close = bar.xti_high, bar.xti_low, bar.xti_close
            xng_high, xng_low, xng_close = bar.xng_high, bar.xng_low, bar.xng_close
        else:
            xti_high, xti_low = max(xti_high, bar.xti_high), min(xti_low, bar.xti_low)
            xng_high, xng_low = max(xng_high, bar.xng_high), min(xng_low, bar.xng_low)
        sessions += 1

    if (
        not completed_week
        or next_week_key(completed_week) != current_week
        or not min_sessions <= sessions <= max_sessions
    ):
        return False, 0, 0.0, 0.0, sessions
    xti_range = xti_high - xti_low
    xng_range = xng_high - xng_low
    if xti_range <= 0.0 or xng_range <= 0.0:
        return False, 0, 0.0, 0.0, sessions
    xti_clv = (xti_close - xti_low) / xti_range
    xng_clv = (xng_close - xng_low) / xng_range
    if not (0.0 <= xti_clv <= 1.0 and 0.0 <= xng_clv <= 1.0):
        return False, 0, 0.0, 0.0, sessions
    direction = 0
    if xti_clv > UPPER and xng_clv < LOWER:
        direction = -1
    elif xti_clv < LOWER and xng_clv > UPPER:
        direction = 1
    return True, direction, xti_clv, xng_clv, sessions


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
    xti_risk_per_lot: float,
    xng_risk_per_lot: float,
    xti_notional_per_lot: float,
    xng_notional_per_lot: float,
    xti_step: float = 0.01,
    xng_step: float = 0.01,
) -> tuple[float, float, float, float]:
    full_xti = 1000.0 / xti_risk_per_lot
    full_xng = 1000.0 / xng_risk_per_lot
    xti_to_xng = xng_notional_per_lot / xti_notional_per_lot
    normalized_per_xng = xti_to_xng / full_xti + 1.0 / full_xng
    raw_xng = 1.0 / normalized_per_xng
    raw_xti = xti_to_xng * raw_xng
    xti_lots = math.floor((raw_xti + 1e-12) / xti_step) * xti_step
    xng_lots = math.floor((raw_xng + 1e-12) / xng_step) * xng_step
    normalized_risk = xti_lots / full_xti + xng_lots / full_xng
    notional_ratio = (
        xti_lots * xti_notional_per_lot / (xng_lots * xng_notional_per_lot)
    )
    return xti_lots, xng_lots, normalized_risk, notional_ratio


class WeeklyCloseLocationDivergenceReferenceTest(unittest.TestCase):
    def test_xti_upper_xng_lower_fades_with_short_xti(self) -> None:
        valid, direction, xti_clv, xng_clv, sessions = weekly_clv_divergence_signal(
            20260824,
            completed_bars((100.0, 130.0, 125.0), (20.0, 50.0, 25.0)),
        )
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertGreater(xti_clv, UPPER)
        self.assertLess(xng_clv, LOWER)
        self.assertEqual(sessions, 5)

    def test_xti_lower_xng_upper_fades_with_long_xti(self) -> None:
        valid, direction, xti_clv, xng_clv, _ = weekly_clv_divergence_signal(
            20260824,
            completed_bars((100.0, 130.0, 105.0), (20.0, 50.0, 45.0)),
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertLess(xti_clv, LOWER)
        self.assertGreater(xng_clv, UPPER)

    def test_boundaries_interior_and_same_outer_tercile_are_flat(self) -> None:
        states = (
            ((1.0, 2.0, 1.0 + LOWER), (1.0, 2.0, 1.0 + UPPER)),
            ((100.0, 130.0, 115.0), (20.0, 50.0, 35.0)),
            ((100.0, 130.0, 125.0), (20.0, 50.0, 45.0)),
        )
        for xti, xng in states:
            with self.subTest(xti=xti, xng=xng):
                valid, direction, *_ = weekly_clv_divergence_signal(
                    20260824, completed_bars(xti, xng)
                )
                self.assertTrue(valid)
                self.assertEqual(direction, 0)

    def test_session_bounds_fail_closed(self) -> None:
        setup = ((100.0, 130.0, 125.0), (20.0, 50.0, 25.0))
        self.assertFalse(weekly_clv_divergence_signal(20260824, completed_bars(*setup, count=2))[0])
        self.assertFalse(weekly_clv_divergence_signal(20260824, completed_bars(*setup, count=6))[0])

    def test_asynchrony_and_invalid_ohlc_fail_closed(self) -> None:
        bars = completed_bars((100.0, 130.0, 125.0), (20.0, 50.0, 25.0))
        bars[0] = replace(bars[0], xng_time=bars[0].xng_time - timedelta(hours=1))
        self.assertFalse(weekly_clv_divergence_signal(20260824, bars)[0])

        invalid = completed_bars((100.0, 130.0, 125.0), (20.0, 50.0, 25.0))
        invalid[0] = replace(invalid[0], xti_high=90.0)
        self.assertFalse(weekly_clv_divergence_signal(20260824, invalid)[0])

    def test_zero_aggregate_range_fails_closed(self) -> None:
        bars = completed_bars((100.0, 100.0, 100.0), (20.0, 50.0, 25.0))
        self.assertFalse(weekly_clv_divergence_signal(20260824, bars)[0])

    def test_uniform_timestamp_shift_preserves_week_label_and_signal(self) -> None:
        bars = completed_bars((100.0, 130.0, 125.0), (20.0, 50.0, 25.0))
        shifted = [
            replace(
                bar,
                xti_time=bar.xti_time + timedelta(hours=1),
                xng_time=bar.xng_time + timedelta(hours=1),
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
        xti, xng, normalized_risk, ratio = package_lots(
            xti_risk_per_lot=2100.0,
            xng_risk_per_lot=700.0,
            xti_notional_per_lot=240000.0,
            xng_notional_per_lot=30000.0,
        )
        self.assertGreater(xti, 0.0)
        self.assertGreater(xng, 0.0)
        self.assertLessEqual(normalized_risk, 1.0 + 1e-8)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_artifacts_lock_identity_and_safety(self) -> None:
        source = MQ5.read_text(encoding="utf-8")
        preset = SETFILE.read_text(encoding="utf-8")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertIn("qm_ea_id                    = 41364", source)
        self.assertIn("Strategy_LoadWeeklyCloseLocationDivergence", source)
        self.assertIn("g_xti_clv > strategy_clv_upper", source)
        self.assertIn("g_xng_clv < strategy_clv_lower", source)
        self.assertIn("g_xti_clv < strategy_clv_lower", source)
        self.assertIn("g_xng_clv > strategy_clv_upper", source)
        self.assertIn("strategy_min_week_sessions == 3", source)
        self.assertIn("strategy_max_week_sessions == 5", source)
        self.assertNotIn("41083", source)
        self.assertRegex(preset, r"(?m)^RISK_FIXED=1000$")
        self.assertRegex(preset, r"(?m)^RISK_PERCENT=0$")
        self.assertRegex(preset, r"(?m)^strategy_clv_lower=0\.333333333333$")
        self.assertRegex(preset, r"(?m)^strategy_clv_upper=0\.666666666667$")
        self.assertRegex(preset, r"(?m)^qm_friday_close_enabled=false$")
        self.assertEqual(manifest["logical_symbol"], "QM5_41364_XTI_XNG_WCLVDIV_RV_D1")
        self.assertEqual(manifest["host_symbol"], "XTIUSD.DWX")
        self.assertEqual(manifest["basket_symbols"], ["XTIUSD.DWX", "XNGUSD.DWX"])
        resolver = (EA_DIR.parents[1] / "include" / "QM" / "QM_MagicResolver.mqh").read_text(
            encoding="utf-8"
        )
        self.assertRegex(resolver, re.compile(r"413640000.*413640001", re.DOTALL))


if __name__ == "__main__":
    unittest.main()

