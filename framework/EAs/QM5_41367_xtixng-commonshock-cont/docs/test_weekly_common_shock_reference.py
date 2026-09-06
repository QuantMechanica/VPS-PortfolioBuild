"""Reference checks for QM5_41367 XTI/XNG weekly common-shock continuation."""

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
MQ5 = EA_DIR / "QM5_41367_xtixng-commonshock-cont.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41367_xtixng-commonshock-cont_QM5_41367_XTI_XNG_COMMONSHOCK_CONT_D1_D1_backtest.set"
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
    monday = value - timedelta(days=value.weekday())
    return date_key(monday)


def key_to_date(value: int) -> datetime:
    return datetime(value // 10000, (value // 100) % 100, value % 100, tzinfo=UTC)


def next_week_key(value: int) -> int:
    return week_key(key_to_date(value) + timedelta(days=7))


def make_week(
    monday: datetime,
    end_xti: float,
    end_xng: float,
    count: int = 5,
) -> list[PairBar]:
    bars: list[PairBar] = []
    for offset in range(count):
        when = monday + timedelta(days=offset)
        distance = count - 1 - offset
        bars.append(
            PairBar(
                when,
                when,
                end_xti * (1.0 - 0.001 * distance),
                end_xng * (1.0 - 0.001 * distance),
            )
        )
    return list(reversed(bars))


def completed_bars(
    older: tuple[float, float],
    newer: tuple[float, float],
    older_count: int = 5,
    newer_count: int = 5,
) -> list[PairBar]:
    older_monday = datetime(2026, 8, 10, tzinfo=UTC)
    newer_monday = datetime(2026, 8, 17, tzinfo=UTC)
    third_monday = datetime(2026, 8, 3, tzinfo=UTC)
    return (
        make_week(newer_monday, newer[0], newer[1], newer_count)
        + make_week(older_monday, older[0], older[1], older_count)
        + make_week(third_monday, older[0] * 0.99, older[1] * 0.99, 5)
    )


def weekly_common_shock_signal(
    current_week: int,
    bars: list[PairBar],
    min_sessions: int = 3,
    max_sessions: int = 5,
    epsilon: float = 1e-10,
) -> tuple[bool, int, float, float, tuple[int, int]]:
    newer_week = 0
    older_week = 0
    newer_sessions = 0
    older_sessions = 0
    newer_xti = newer_xng = older_xti = older_xng = 0.0

    for index, bar in enumerate(bars):
        if bar.xti_time != bar.xng_time:
            return False, 0, 0.0, 0.0, (0, 0)
        if index and bars[index - 1].xti_time <= bar.xti_time:
            return False, 0, 0.0, 0.0, (0, 0)
        candidate_week = week_key(bar.xti_time)
        if candidate_week == current_week:
            return False, 0, 0.0, 0.0, (0, 0)
        if newer_week == 0:
            if next_week_key(candidate_week) != current_week:
                return False, 0, 0.0, 0.0, (0, 0)
            newer_week = candidate_week
        elif candidate_week != newer_week and older_week == 0:
            if next_week_key(candidate_week) != newer_week:
                return False, 0, 0.0, 0.0, (0, 0)
            older_week = candidate_week
        elif candidate_week not in (newer_week, older_week):
            break
        if (
            bar.xti_close <= 0.0
            or bar.xng_close <= 0.0
            or not math.isfinite(bar.xti_close)
            or not math.isfinite(bar.xng_close)
        ):
            return False, 0, 0.0, 0.0, (0, 0)
        if candidate_week == newer_week:
            if newer_sessions == 0:
                newer_xti, newer_xng = bar.xti_close, bar.xng_close
            newer_sessions += 1
        else:
            if older_sessions == 0:
                older_xti, older_xng = bar.xti_close, bar.xng_close
            older_sessions += 1

    counts = (older_sessions, newer_sessions)
    if (
        not newer_week
        or not older_week
        or next_week_key(newer_week) != current_week
        or next_week_key(older_week) != newer_week
        or not min_sessions <= newer_sessions <= max_sessions
        or not min_sessions <= older_sessions <= max_sessions
    ):
        return False, 0, 0.0, 0.0, counts

    wti_return = math.log(newer_xti / older_xti)
    xng_return = math.log(newer_xng / older_xng)
    direction = 0
    same_positive = wti_return > 0.0 and xng_return > 0.0
    same_negative = wti_return < 0.0 and xng_return < 0.0
    relative_return = wti_return - xng_return
    if (same_positive or same_negative) and relative_return > epsilon:
        direction = 1  # WTI outperformed: buy XTI, sell XNG.
    elif (same_positive or same_negative) and relative_return < -epsilon:
        direction = -1  # XNG outperformed: sell XTI, buy XNG.
    return True, direction, wti_return, xng_return, counts


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


class WeeklyCommonShockReferenceTest(unittest.TestCase):
    def test_positive_common_shock_wti_winner_is_followed(self) -> None:
        valid, direction, wti, xng, counts = weekly_common_shock_signal(
            20260824, completed_bars((100.0, 50.0), (110.0, 52.0))
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertGreater(wti, 0.0)
        self.assertGreater(xng, 0.0)
        self.assertGreater(wti, xng)
        self.assertEqual(counts, (5, 5))

    def test_positive_common_shock_xng_winner_is_followed(self) -> None:
        valid, direction, wti, xng, _ = weekly_common_shock_signal(
            20260824, completed_bars((100.0, 50.0), (104.0, 58.0))
        )
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertGreater(wti, 0.0)
        self.assertGreater(xng, 0.0)
        self.assertLess(wti, xng)

    def test_negative_common_shock_is_symmetric_across_leaders(self) -> None:
        wti_loser = weekly_common_shock_signal(
            20260824, completed_bars((100.0, 50.0), (90.0, 48.0))
        )
        xng_loser = weekly_common_shock_signal(
            20260824, completed_bars((100.0, 50.0), (96.0, 45.0))
        )
        self.assertTrue(wti_loser[0])
        self.assertEqual(wti_loser[1], -1)
        self.assertLess(wti_loser[2], wti_loser[3])
        self.assertTrue(xng_loser[0])
        self.assertEqual(xng_loser[1], 1)
        self.assertGreater(xng_loser[2], xng_loser[3])

    def test_mixed_sign_zero_and_relative_equality_are_flat(self) -> None:
        for newer in (
            (110.0, 45.0),
            (90.0, 55.0),
            (100.0, 55.0),
            (110.0, 50.0),
            (110.0, 55.0),
            (90.0, 45.0),
        ):
            with self.subTest(newer=newer):
                valid, direction, *_ = weekly_common_shock_signal(
                    20260824, completed_bars((100.0, 50.0), newer)
                )
                self.assertTrue(valid)
                self.assertEqual(direction, 0)

    def test_session_count_bounds_fail_closed(self) -> None:
        self.assertFalse(
            weekly_common_shock_signal(
                20260824,
                completed_bars((100.0, 50.0), (110.0, 52.0), older_count=2),
            )[0]
        )
        self.assertFalse(
            weekly_common_shock_signal(
                20260824,
                completed_bars((100.0, 50.0), (110.0, 52.0), newer_count=6),
            )[0]
        )

    def test_asynchrony_and_nonconsecutive_weeks_fail_closed(self) -> None:
        bars = completed_bars((100.0, 50.0), (110.0, 52.0))
        first = bars[0]
        bars[0] = PairBar(
            first.xti_time,
            first.xng_time - timedelta(hours=1),
            first.xti_close,
            first.xng_close,
        )
        self.assertFalse(weekly_common_shock_signal(20260824, bars)[0])

        missing_week = make_week(
            datetime(2026, 8, 17, tzinfo=UTC), 110.0, 52.0
        ) + make_week(datetime(2026, 8, 3, tzinfo=UTC), 100.0, 50.0)
        self.assertFalse(weekly_common_shock_signal(20260824, missing_week)[0])

    def test_uniform_timestamp_shift_preserves_label(self) -> None:
        bars = completed_bars((100.0, 50.0), (110.0, 52.0))
        shifted = [
            PairBar(
                bar.xti_time + timedelta(hours=1),
                bar.xng_time + timedelta(hours=1),
                bar.xti_close,
                bar.xng_close,
            )
            for bar in bars
        ]
        native = weekly_common_shock_signal(20260824, bars)
        shifted_result = weekly_common_shock_signal(20260824, shifted)
        self.assertEqual(native[0:2], shifted_result[0:2])

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
        self.assertIn("qm_ea_id                    = 41367", source)
        self.assertIn("Strategy_LoadWeeklyCommonShock", source)
        self.assertIn("g_wti_week_return > 0.0 && g_xng_week_return > 0.0", source)
        self.assertIn("g_wti_week_return < 0.0 && g_xng_week_return < 0.0", source)
        self.assertIn("relative_return > strategy_signal_epsilon", source)
        self.assertIn("relative_return < -strategy_signal_epsilon", source)
        self.assertIn("direction = 1; // WTI outperformed: buy XTI, sell XNG.", source)
        self.assertIn("direction = -1; // natural gas outperformed: sell XTI, buy XNG.", source)
        self.assertIn("strategy_min_sessions_per_week == 3", source)
        self.assertIn("strategy_max_sessions_per_week == 5", source)
        self.assertIn("strategy_signal_epsilon - 1.0e-10", source)
        self.assertNotIn("41083", source)
        self.assertRegex(preset, r"(?m)^RISK_FIXED=1000$")
        self.assertRegex(preset, r"(?m)^RISK_PERCENT=0$")
        self.assertRegex(preset, r"(?m)^qm_friday_close_enabled=false$")
        self.assertEqual(manifest["host_symbol"], "XTIUSD.DWX")
        self.assertEqual(manifest["basket_symbols"], ["XTIUSD.DWX", "XNGUSD.DWX"])
        resolver = (EA_DIR.parents[1] / "include" / "QM" / "QM_MagicResolver.mqh").read_text(
            encoding="utf-8"
        )
        self.assertRegex(resolver, re.compile(r"413670000.*413670001", re.DOTALL))


if __name__ == "__main__":
    unittest.main()



