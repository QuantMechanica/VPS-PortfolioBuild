"""Reference checks for QM5_41083 XAU/XAG weekly leg divergence."""

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
MQ5 = EA_DIR / "QM5_41083_xauxag-wlegdiv-rv.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41083_xauxag-wlegdiv-rv_QM5_41083_XAU_XAG_WLEGDIV_RV_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"


@dataclass(frozen=True)
class PairBar:
    xau_time: datetime
    xag_time: datetime
    xau_close: float
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
    end_xau: float,
    end_xag: float,
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
                end_xau * (1.0 - 0.001 * distance),
                end_xag * (1.0 - 0.001 * distance),
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


def weekly_leg_divergence_signal(
    current_week: int,
    bars: list[PairBar],
    min_sessions: int = 3,
    max_sessions: int = 5,
) -> tuple[bool, int, float, float, tuple[int, int]]:
    newer_week = 0
    older_week = 0
    newer_sessions = 0
    older_sessions = 0
    newer_xau = newer_xag = older_xau = older_xag = 0.0

    for index, bar in enumerate(bars):
        if bar.xau_time != bar.xag_time:
            return False, 0, 0.0, 0.0, (0, 0)
        if index and bars[index - 1].xau_time <= bar.xau_time:
            return False, 0, 0.0, 0.0, (0, 0)
        candidate_week = week_key(bar.xau_time)
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
            bar.xau_close <= 0.0
            or bar.xag_close <= 0.0
            or not math.isfinite(bar.xau_close)
            or not math.isfinite(bar.xag_close)
        ):
            return False, 0, 0.0, 0.0, (0, 0)
        if candidate_week == newer_week:
            if newer_sessions == 0:
                newer_xau, newer_xag = bar.xau_close, bar.xag_close
            newer_sessions += 1
        else:
            if older_sessions == 0:
                older_xau, older_xag = bar.xau_close, bar.xag_close
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

    gold_return = math.log(newer_xau / older_xau)
    silver_return = math.log(newer_xag / older_xag)
    direction = 0
    if gold_return > 0.0 and silver_return < 0.0:
        direction = -1
    elif gold_return < 0.0 and silver_return > 0.0:
        direction = 1
    return True, direction, gold_return, silver_return, counts


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


class WeeklyLegDivergenceReferenceTest(unittest.TestCase):
    def test_gold_up_silver_down_fades_with_short_xau(self) -> None:
        valid, direction, gold, silver, counts = weekly_leg_divergence_signal(
            20260824, completed_bars((100.0, 50.0), (110.0, 45.0))
        )
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertGreater(gold, 0.0)
        self.assertLess(silver, 0.0)
        self.assertEqual(counts, (5, 5))

    def test_gold_down_silver_up_fades_with_long_xau(self) -> None:
        valid, direction, gold, silver, _ = weekly_leg_divergence_signal(
            20260824, completed_bars((100.0, 50.0), (90.0, 55.0))
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertLess(gold, 0.0)
        self.assertGreater(silver, 0.0)

    def test_same_sign_and_exact_zero_are_valid_flat_states(self) -> None:
        for newer in ((110.0, 55.0), (90.0, 45.0), (100.0, 55.0), (110.0, 50.0)):
            with self.subTest(newer=newer):
                valid, direction, *_ = weekly_leg_divergence_signal(
                    20260824, completed_bars((100.0, 50.0), newer)
                )
                self.assertTrue(valid)
                self.assertEqual(direction, 0)

    def test_session_count_bounds_fail_closed(self) -> None:
        self.assertFalse(
            weekly_leg_divergence_signal(
                20260824,
                completed_bars((100.0, 50.0), (110.0, 45.0), older_count=2),
            )[0]
        )
        self.assertFalse(
            weekly_leg_divergence_signal(
                20260824,
                completed_bars((100.0, 50.0), (110.0, 45.0), newer_count=6),
            )[0]
        )

    def test_asynchrony_and_nonconsecutive_weeks_fail_closed(self) -> None:
        bars = completed_bars((100.0, 50.0), (110.0, 45.0))
        first = bars[0]
        bars[0] = PairBar(
            first.xau_time,
            first.xag_time - timedelta(hours=1),
            first.xau_close,
            first.xag_close,
        )
        self.assertFalse(weekly_leg_divergence_signal(20260824, bars)[0])

        missing_week = make_week(
            datetime(2026, 8, 17, tzinfo=UTC), 110.0, 45.0
        ) + make_week(datetime(2026, 8, 3, tzinfo=UTC), 100.0, 50.0)
        self.assertFalse(weekly_leg_divergence_signal(20260824, missing_week)[0])

    def test_uniform_timestamp_shift_preserves_label(self) -> None:
        bars = completed_bars((100.0, 50.0), (110.0, 45.0))
        shifted = [
            PairBar(
                bar.xau_time + timedelta(hours=1),
                bar.xag_time + timedelta(hours=1),
                bar.xau_close,
                bar.xag_close,
            )
            for bar in bars
        ]
        native = weekly_leg_divergence_signal(20260824, bars)
        shifted_result = weekly_leg_divergence_signal(20260824, shifted)
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
        self.assertIn("qm_ea_id                    = 41083", source)
        self.assertIn("Strategy_LoadWeeklyLegDivergence", source)
        self.assertIn("g_gold_week_return > 0.0 && g_silver_week_return < 0.0", source)
        self.assertIn("g_gold_week_return < 0.0 && g_silver_week_return > 0.0", source)
        self.assertIn("strategy_min_week_sessions == 3", source)
        self.assertIn("strategy_max_week_sessions == 5", source)
        self.assertNotIn("41077", source)
        self.assertRegex(preset, r"(?m)^RISK_FIXED=1000$")
        self.assertRegex(preset, r"(?m)^RISK_PERCENT=0$")
        self.assertRegex(preset, r"(?m)^qm_friday_close_enabled=false$")
        self.assertEqual(manifest["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        resolver = (EA_DIR.parents[1] / "include" / "QM" / "QM_MagicResolver.mqh").read_text(
            encoding="utf-8"
        )
        self.assertRegex(resolver, re.compile(r"410830000.*410830001", re.DOTALL))


if __name__ == "__main__":
    unittest.main()
