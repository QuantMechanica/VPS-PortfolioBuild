"""Deterministic reference checks for QM5_41371 leader-switch continuation."""

from __future__ import annotations

import json
import math
import re
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]
MQ5 = EA_DIR / "QM5_41371_xtixng-cs-leadswitch-cont.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41371_xtixng-cs-leadswitch-cont_QM5_41371_XTI_XNG_CS_LEADSWITCH_CONT_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"


@dataclass(frozen=True)
class PairBar:
    xti_time: datetime
    xng_time: datetime
    xti_close: float
    xng_close: float


def date_key(value: datetime) -> int:
    return value.year * 10000 + value.month * 100 + value.day


def week_key(value: datetime) -> int:
    return date_key(value - timedelta(days=value.weekday()))


def key_to_date(value: int) -> datetime:
    return datetime(value // 10000, (value // 100) % 100, value % 100, tzinfo=UTC)


def next_week_key(value: int) -> int:
    return week_key(key_to_date(value) + timedelta(days=7))


def make_week(monday: datetime, end: tuple[float, float], count: int = 5) -> list[PairBar]:
    bars: list[PairBar] = []
    for offset in range(count):
        when = monday + timedelta(days=offset)
        distance = count - 1 - offset
        bars.append(
            PairBar(
                when,
                when,
                end[0] * (1.0 - 0.001 * distance),
                end[1] * (1.0 - 0.001 * distance),
            )
        )
    return list(reversed(bars))


def completed_bars(
    oldest: tuple[float, float],
    middle: tuple[float, float],
    newest: tuple[float, float],
    counts: tuple[int, int, int] = (5, 5, 5),
) -> list[PairBar]:
    return (
        make_week(datetime(2026, 8, 17, tzinfo=UTC), newest, counts[2])
        + make_week(datetime(2026, 8, 10, tzinfo=UTC), middle, counts[1])
        + make_week(datetime(2026, 8, 3, tzinfo=UTC), oldest, counts[0])
    )


def leader_switch_signal(
    current_week: int,
    bars: list[PairBar],
    min_sessions: int = 3,
    max_sessions: int = 5,
    epsilon: float = 1e-10,
) -> tuple[bool, int, tuple[float, float, float, float], tuple[int, int, int]]:
    keys = [0, 0, 0]  # newest, middle, oldest
    sessions = [0, 0, 0]
    xti_close = [0.0, 0.0, 0.0]
    xng_close = [0.0, 0.0, 0.0]

    for index, bar in enumerate(bars):
        if bar.xti_time != bar.xng_time:
            return False, 0, (0.0,) * 4, tuple(reversed(sessions))
        if index and bars[index - 1].xti_time <= bar.xti_time:
            return False, 0, (0.0,) * 4, tuple(reversed(sessions))
        candidate = week_key(bar.xti_time)
        if candidate == current_week:
            return False, 0, (0.0,) * 4, tuple(reversed(sessions))
        try:
            slot = keys.index(candidate)
        except ValueError:
            try:
                slot = keys.index(0)
            except ValueError:
                break
            expected_next = current_week if slot == 0 else keys[slot - 1]
            if next_week_key(candidate) != expected_next:
                return False, 0, (0.0,) * 4, tuple(reversed(sessions))
            keys[slot] = candidate
        if (
            bar.xti_close <= 0.0
            or bar.xng_close <= 0.0
            or not math.isfinite(bar.xti_close)
            or not math.isfinite(bar.xng_close)
        ):
            return False, 0, (0.0,) * 4, tuple(reversed(sessions))
        if sessions[slot] == 0:
            xti_close[slot], xng_close[slot] = bar.xti_close, bar.xng_close
        sessions[slot] += 1

    counts = tuple(reversed(sessions))
    if (
        not all(keys)
        or next_week_key(keys[0]) != current_week
        or next_week_key(keys[1]) != keys[0]
        or next_week_key(keys[2]) != keys[1]
        or any(not min_sessions <= count <= max_sessions for count in sessions)
    ):
        return False, 0, (0.0,) * 4, counts

    o0 = math.log(xti_close[1] / xti_close[2])
    g0 = math.log(xng_close[1] / xng_close[2])
    o1 = math.log(xti_close[0] / xti_close[1])
    g1 = math.log(xng_close[0] / xng_close[1])
    older_same = (o0 > 0 and g0 > 0) or (o0 < 0 and g0 < 0)
    newer_same = (o1 > 0 and g1 > 0) or (o1 < 0 and g1 < 0)
    d0, d1 = o0 - g0, o1 - g1
    direction = 0
    if older_same and newer_same and d0 < -epsilon and d1 > epsilon:
        direction = 1  # New WTI winner is followed: buy XTI, sell XNG.
    elif older_same and newer_same and d0 > epsilon and d1 < -epsilon:
        direction = -1  # New XNG winner is followed: sell XTI, buy XNG.
    return True, direction, (o0, g0, o1, g1), counts


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
    step: float = 0.01,
) -> tuple[float, float, float, float]:
    full_xti = 1000.0 / xti_risk_per_lot
    full_xng = 1000.0 / xng_risk_per_lot
    ratio = xng_notional_per_lot / xti_notional_per_lot
    raw_xng = 1.0 / (ratio / full_xti + 1.0 / full_xng)
    raw_xti = ratio * raw_xng
    xti_lots = math.floor((raw_xti + 1e-12) / step) * step
    xng_lots = math.floor((raw_xng + 1e-12) / step) * step
    risk = xti_lots / full_xti + xng_lots / full_xng
    actual_ratio = xti_lots * xti_notional_per_lot / (
        xng_lots * xng_notional_per_lot
    )
    return xti_lots, xng_lots, risk, actual_ratio


class LeaderSwitchReferenceTest(unittest.TestCase):
    def test_positive_common_shocks_rotate_from_wti_to_xng_and_follow_xng(self) -> None:
        valid, direction, returns, counts = leader_switch_signal(
            20260824, completed_bars((100.0, 50.0), (110.0, 52.0), (114.0, 60.0))
        )
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertGreater(returns[0] - returns[1], 0.0)
        self.assertLess(returns[2] - returns[3], 0.0)
        self.assertEqual(counts, (5, 5, 5))

    def test_positive_common_shocks_rotate_from_xng_to_wti_and_follow_wti(self) -> None:
        valid, direction, returns, _ = leader_switch_signal(
            20260824, completed_bars((100.0, 50.0), (104.0, 56.0), (116.0, 59.0))
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertLess(returns[0] - returns[1], 0.0)
        self.assertGreater(returns[2] - returns[3], 0.0)

    def test_negative_common_shocks_are_symmetric(self) -> None:
        valid, direction, _, _ = leader_switch_signal(
            20260824, completed_bars((100.0, 50.0), (90.0, 48.0), (86.0, 42.0))
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 1)

    def test_no_switch_zero_and_mixed_sign_weeks_are_flat(self) -> None:
        cases = (
            ((100.0, 50.0), (110.0, 52.0), (121.0, 54.0)),
            ((100.0, 50.0), (110.0, 52.0), (110.0, 60.0)),
            ((100.0, 50.0), (110.0, 48.0), (114.0, 55.0)),
            ((100.0, 50.0), (105.0, 52.5), (110.0, 55.0)),
        )
        for case in cases:
            with self.subTest(case=case):
                valid, direction, *_ = leader_switch_signal(
                    20260824, completed_bars(*case)
                )
                self.assertTrue(valid)
                self.assertEqual(direction, 0)

    def test_session_bounds_asynchrony_and_missing_week_fail_closed(self) -> None:
        self.assertFalse(
            leader_switch_signal(
                20260824,
                completed_bars(
                    (100.0, 50.0), (110.0, 52.0), (114.0, 60.0), (2, 5, 5)
                ),
            )[0]
        )
        bars = completed_bars((100.0, 50.0), (110.0, 52.0), (114.0, 60.0))
        first = bars[0]
        bars[0] = PairBar(
            first.xti_time,
            first.xng_time - timedelta(hours=1),
            first.xti_close,
            first.xng_close,
        )
        self.assertFalse(leader_switch_signal(20260824, bars)[0])
        missing = make_week(datetime(2026, 8, 17, tzinfo=UTC), (114.0, 60.0))
        missing += make_week(datetime(2026, 8, 3, tzinfo=UTC), (100.0, 50.0))
        self.assertFalse(leader_switch_signal(20260824, missing)[0])

    def test_attempt_clock_lifecycle_risk_and_notional_are_bounded(self) -> None:
        attempts: set[int] = set()
        self.assertTrue(consume_attempt(attempts, 20260824))
        self.assertFalse(consume_attempt(attempts, 20260824))
        monday = datetime(2026, 8, 24, tzinfo=UTC)
        self.assertTrue(within_entry_grace(monday, monday + timedelta(minutes=180)))
        self.assertFalse(within_entry_grace(monday, monday + timedelta(minutes=181)))
        self.assertFalse(should_close(monday, monday + timedelta(days=4)))
        self.assertTrue(should_close(monday, monday + timedelta(days=7)))
        xti, xng, risk, ratio = package_lots(2100.0, 700.0, 240000.0, 30000.0)
        self.assertGreater(xti, 0.0)
        self.assertGreater(xng, 0.0)
        self.assertLessEqual(risk, 1.0 + 1e-8)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_artifacts_lock_identity_signal_and_fixed_risk(self) -> None:
        source = MQ5.read_text(encoding="utf-8")
        preset = SETFILE.read_text(encoding="utf-8")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertIn("qm_ea_id                    = 41371", source)
        self.assertIn("Strategy_LoadLeaderSwitch", source)
        self.assertIn("g_older_relative_return < -strategy_signal_epsilon", source)
        self.assertIn("g_newer_relative_return > strategy_signal_epsilon", source)
        self.assertIn("direction = 1; // WTI became the winner", source)
        self.assertIn("direction = -1; // natural gas became the winner", source)
        self.assertIn("strategy_history_bars_d1 == 40", source)
        self.assertNotIn("41368", source)
        self.assertRegex(preset, r"(?m)^RISK_FIXED=1000$")
        self.assertRegex(preset, r"(?m)^RISK_PERCENT=0$")
        self.assertRegex(preset, r"(?m)^qm_friday_close_enabled=false$")
        self.assertEqual(manifest["host_symbol"], "XTIUSD.DWX")
        self.assertEqual(manifest["basket_symbols"], ["XTIUSD.DWX", "XNGUSD.DWX"])
        resolver = (EA_DIR.parents[1] / "include" / "QM" / "QM_MagicResolver.mqh").read_text(
            encoding="utf-8"
        )
        self.assertRegex(resolver, re.compile(r"413710000.*413710001", re.DOTALL))


if __name__ == "__main__":
    unittest.main()
