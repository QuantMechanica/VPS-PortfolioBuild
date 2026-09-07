"""Reference checks for QM5_41374 weekly efficiency-divergence basket."""

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
MQ5 = EA_DIR / "QM5_41374_xtixng-weffdiv-rv.mq5"
SETFILE = EA_DIR / "sets" / (
    "QM5_41374_xtixng-weffdiv-rv_"
    "QM5_41374_XTI_XNG_WEFFDIV_RV_D1_D1_backtest.set"
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
    return date_key(value - timedelta(days=value.weekday()))


def key_to_date(value: int) -> datetime:
    return datetime(value // 10000, (value // 100) % 100, value % 100, tzinfo=UTC)


def next_week_key(value: int) -> int:
    return week_key(key_to_date(value) + timedelta(days=7))


def make_week(
    monday: datetime,
    xti: tuple[float, float, float, float],
    xng: tuple[float, float, float, float],
    count: int = 5,
) -> list[PairBar]:
    """Return newest-first bars matching aggregate (open, high, low, close)."""
    xo, xh, xl, xc = xti
    go, gh, gl, gc = xng
    xm = (xh + xl) / 2.0
    gm = (gh + gl) / 2.0
    bars: list[PairBar] = []
    for offset in range(count):
        when = monday + timedelta(days=offset)
        x_open = xo if offset == 0 else xm
        g_open = go if offset == 0 else gm
        x_close = xc if offset == count - 1 else xm
        g_close = gc if offset == count - 1 else gm
        bars.append(
            PairBar(
                when,
                when,
                x_open,
                xh if offset == 1 else max(x_open, x_close),
                xl if offset == 2 else min(x_open, x_close),
                x_close,
                g_open,
                gh if offset == 1 else max(g_open, g_close),
                gl if offset == 2 else min(g_open, g_close),
                g_close,
            )
        )
    return list(reversed(bars))


def completed_bars(
    xti: tuple[float, float, float, float],
    xng: tuple[float, float, float, float],
    count: int = 5,
) -> list[PairBar]:
    newest = make_week(datetime(2026, 8, 17, tzinfo=UTC), xti, xng, count)
    older = make_week(
        datetime(2026, 8, 10, tzinfo=UTC),
        (105.0, 110.0, 100.0, 106.0),
        (25.0, 30.0, 20.0, 26.0),
    )
    return newest + older


def efficiency_signal(
    current_week: int,
    bars: list[PairBar],
    min_sessions: int = 3,
    max_sessions: int = 5,
) -> tuple[bool, int, float, float, int]:
    completed_week = 0
    selected: list[PairBar] = []
    for index, bar in enumerate(bars):
        if bar.xti_time != bar.xng_time:
            return False, 0, 0.0, 0.0, 0
        if index and bars[index - 1].xti_time <= bar.xti_time:
            return False, 0, 0.0, 0.0, 0
        candidate_week = week_key(bar.xti_time)
        if candidate_week == current_week:
            return False, 0, 0.0, 0.0, 0
        if not completed_week:
            if next_week_key(candidate_week) != current_week:
                return False, 0, 0.0, 0.0, 0
            completed_week = candidate_week
        elif candidate_week != completed_week:
            break
        values = (
            bar.xti_open, bar.xti_high, bar.xti_low, bar.xti_close,
            bar.xng_open, bar.xng_high, bar.xng_low, bar.xng_close,
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
        selected.append(bar)

    sessions = len(selected)
    if not min_sessions <= sessions <= max_sessions:
        return False, 0, 0.0, 0.0, sessions
    chronological = list(reversed(selected))
    xo, xc = chronological[0].xti_open, chronological[-1].xti_close
    go, gc = chronological[0].xng_open, chronological[-1].xng_close
    xh, xl = max(b.xti_high for b in selected), min(b.xti_low for b in selected)
    gh, gl = max(b.xng_high for b in selected), min(b.xng_low for b in selected)
    if xh <= xl or gh <= gl or xc == xo or gc == go:
        return False, 0, 0.0, 0.0, sessions
    xe, ge = abs(xc - xo) / (xh - xl), abs(gc - go) / (gh - gl)
    if not (0.0 < xe <= 1.0 and 0.0 < ge <= 1.0):
        return False, 0, 0.0, 0.0, sessions
    direction = 0
    if xe > UPPER and ge < LOWER:
        direction = -1 if xc > xo else 1
    elif ge > UPPER and xe < LOWER:
        direction = 1 if gc > go else -1
    return True, direction, xe, ge, sessions


class WeeklyEfficiencyDivergenceReferenceTest(unittest.TestCase):
    def test_high_efficiency_xti_up_is_faded_short(self) -> None:
        valid, direction, xe, ge, sessions = efficiency_signal(
            20260824,
            completed_bars((100.0, 130.0, 100.0, 125.0), (30.0, 50.0, 20.0, 32.0)),
        )
        self.assertTrue(valid)
        self.assertEqual(direction, -1)
        self.assertGreater(xe, UPPER)
        self.assertLess(ge, LOWER)
        self.assertEqual(sessions, 5)

    def test_high_efficiency_xti_down_is_faded_long(self) -> None:
        valid, direction, xe, ge, _ = efficiency_signal(
            20260824,
            completed_bars((125.0, 130.0, 95.0, 100.0), (30.0, 50.0, 20.0, 32.0)),
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertGreater(xe, UPPER)
        self.assertLess(ge, LOWER)

    def test_high_efficiency_xng_up_implies_long_xti(self) -> None:
        valid, direction, xe, ge, _ = efficiency_signal(
            20260824,
            completed_bars((110.0, 130.0, 100.0, 112.0), (20.0, 50.0, 20.0, 45.0)),
        )
        self.assertTrue(valid)
        self.assertEqual(direction, 1)
        self.assertLess(xe, LOWER)
        self.assertGreater(ge, UPPER)

    def test_boundaries_and_nondivergent_states_are_flat(self) -> None:
        states = (
            ((100.0, 130.0, 100.0, 120.0), (30.0, 60.0, 10.0, 50.0)),
            ((100.0, 130.0, 100.0, 115.0), (20.0, 50.0, 20.0, 35.0)),
        )
        for xti, xng in states:
            with self.subTest(xti=xti, xng=xng):
                valid, direction, *_ = efficiency_signal(20260824, completed_bars(xti, xng))
                self.assertTrue(valid)
                self.assertEqual(direction, 0)

    def test_asynchrony_zero_body_and_session_bounds_fail_closed(self) -> None:
        setup = ((100.0, 130.0, 100.0, 125.0), (30.0, 50.0, 20.0, 32.0))
        bars = completed_bars(*setup)
        bars[0] = replace(bars[0], xng_time=bars[0].xng_time - timedelta(hours=1))
        self.assertFalse(efficiency_signal(20260824, bars)[0])
        self.assertFalse(
            efficiency_signal(
                20260824,
                completed_bars((100.0, 130.0, 100.0, 100.0), setup[1]),
            )[0]
        )
        self.assertFalse(efficiency_signal(20260824, completed_bars(*setup, count=2))[0])
        self.assertFalse(efficiency_signal(20260824, completed_bars(*setup, count=6))[0])

    def test_static_artifacts_lock_identity_guard_and_manifest(self) -> None:
        source = MQ5.read_text(encoding="utf-8")
        preset = SETFILE.read_text(encoding="utf-8")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertIn("qm_ea_id                    = 41374", source)
        self.assertIn("Strategy_LoadWeeklyEfficiencyDivergence", source)
        self.assertIn("MathAbs(xti_body) / xti_range", source)
        self.assertIn("MathAbs(xng_body) / xng_range", source)
        self.assertIn("strategy_efficiency_upper", source)
        self.assertIn("strategy_efficiency_lower", source)
        self.assertRegex(preset, r"(?m)^RISK_FIXED=1000$")
        self.assertRegex(preset, r"(?m)^RISK_PERCENT=0$")
        self.assertRegex(preset, r"(?m)^strategy_efficiency_lower=0\.333333333333$")
        self.assertRegex(preset, r"(?m)^strategy_efficiency_upper=0\.666666666667$")
        guard = re.search(
            r"bool Strategy_InputsValid\(\).*?\n  \}", source, re.DOTALL
        ).group(0)
        for forbidden in (
            "qm_rng_seed ==", "qm_news_", "qm_friday_close_", "PORTFOLIO_WEIGHT",
        ):
            self.assertNotIn(forbidden, guard)
        self.assertIn("RISK_FIXED > 0.0", guard)
        self.assertIn("qm_stress_reject_probability >= 0.0", guard)
        self.assertIn("qm_stress_reject_probability <= 1.0", guard)
        self.assertEqual(manifest["logical_symbol"], "QM5_41374_XTI_XNG_WEFFDIV_RV_D1")
        self.assertEqual(manifest["basket_symbols"], ["XTIUSD.DWX", "XNGUSD.DWX"])
        resolver = (EA_DIR.parents[1] / "include" / "QM" / "QM_MagicResolver.mqh").read_text(
            encoding="utf-8"
        )
        self.assertRegex(resolver, re.compile(r"413740000.*413740001", re.DOTALL))


if __name__ == "__main__":
    unittest.main()
