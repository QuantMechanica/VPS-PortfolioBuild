"""Deterministic reference checks for QM5_41451 XAU/XAG weekly NR2 CLV momentum."""

from __future__ import annotations

import json
import math
import re
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]
MQ5 = EA_DIR / "QM5_41451_xauxag-nr2-clv-mom.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41451_xauxag-nr2-clv-mom_QM5_41451_XAU_XAG_NR2_CLV_MOM_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"


def ratio_close(xau: float, xag: float) -> float:
    if xau <= 0 or xag <= 0 or not math.isfinite(xau) or not math.isfinite(xag):
        raise ValueError("prices must be positive and finite")
    return math.log(xau) - math.log(xag)


def range_and_clv(values: list[float]) -> tuple[float, float]:
    if not 3 <= len(values) <= 5 or any(not math.isfinite(value) for value in values):
        raise ValueError("completed week must have three through five finite values")
    low = min(values)
    high = max(values)
    width = high - low
    if width <= 0:
        raise ValueError("range must be positive")
    return width, (values[-1] - low) / width


def nr2_clv_signal(prior_range: float, newest_range: float, clv: float) -> int:
    if any(not math.isfinite(value) for value in (prior_range, newest_range, clv)):
        return 0
    if prior_range <= 0 or newest_range <= 0 or newest_range >= prior_range or not 0 <= clv <= 1:
        return 0
    if clv > 0.75:
        return 1
    if clv < 0.25:
        return -1
    return 0


def week_key(value: datetime) -> datetime:
    return (value - timedelta(days=value.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0
    )


def weeks_valid(current_week: datetime, completed: list[tuple[datetime, int]]) -> bool:
    if len(completed) != 2:
        return False
    expected = current_week - timedelta(days=7)
    for anchor, sessions in completed:
        if week_key(anchor) != expected or not 3 <= sessions <= 5:
            return False
        expected -= timedelta(days=7)
    return True


def package_lots(
    xau_risk_per_lot: float,
    xag_risk_per_lot: float,
    xau_notional_per_lot: float,
    xag_notional_per_lot: float,
    step: float = 0.01,
) -> tuple[float, float, float, float]:
    full_xau = 1000.0 / xau_risk_per_lot
    full_xag = 1000.0 / xag_risk_per_lot
    lot_ratio = xag_notional_per_lot / xau_notional_per_lot
    raw_xag = 1.0 / (lot_ratio / full_xau + 1.0 / full_xag)
    raw_xau = lot_ratio * raw_xag
    xau = math.floor((raw_xau + 1e-12) / step) * step
    xag = math.floor((raw_xag + 1e-12) / step) * step
    risk = xau / full_xau + xag / full_xag
    notional_ratio = xau * xau_notional_per_lot / (xag * xag_notional_per_lot)
    return xau, xag, risk, notional_ratio


class Nr2ClvMomentumReferenceTest(unittest.TestCase):
    def test_ratio_range_and_both_continuation_sides(self) -> None:
        prior_width, _ = range_and_clv([4.55, 4.63, 4.56, 4.60])
        upper_width, upper_clv = range_and_clv([4.58, 4.61, 4.57, 4.62])
        lower_width, lower_clv = range_and_clv([4.62, 4.59, 4.63, 4.57])
        self.assertEqual(nr2_clv_signal(prior_width, upper_width, upper_clv), 1)
        self.assertEqual(nr2_clv_signal(prior_width, lower_width, lower_clv), -1)

    def test_ties_expansion_boundaries_and_interior_are_flat(self) -> None:
        for prior, newest, clv in (
            (0.04, 0.04, 0.90),
            (0.04, 0.05, 0.90),
            (0.05, 0.04, 0.75),
            (0.05, 0.04, 0.25),
            (0.05, 0.04, 0.50),
            (0.04, math.inf, 0.90),
        ):
            with self.subTest(prior=prior, newest=newest, clv=clv):
                self.assertEqual(nr2_clv_signal(prior, newest, clv), 0)

    def test_ratio_transform_and_invalid_prices(self) -> None:
        self.assertAlmostEqual(ratio_close(2400.0, 30.0), math.log(80.0))
        for pair in ((0.0, 30.0), (2400.0, -1.0), (math.inf, 30.0)):
            with self.subTest(pair=pair):
                with self.assertRaises(ValueError):
                    ratio_close(*pair)

    def test_two_consecutive_completed_weeks_and_session_bounds(self) -> None:
        current = datetime(2026, 8, 24, tzinfo=UTC)
        valid = [(current - timedelta(days=7 * index), 5) for index in range(1, 3)]
        self.assertTrue(weeks_valid(current, valid))
        self.assertFalse(weeks_valid(current, [valid[0]]))
        self.assertFalse(weeks_valid(current, [(valid[0][0], 2), valid[1]]))
        self.assertFalse(weeks_valid(current, [valid[0], (valid[1][0] - timedelta(days=7), 5)]))

    def test_aggregate_risk_and_equal_notional_are_bounded(self) -> None:
        xau, xag, risk, ratio = package_lots(2100.0, 700.0, 240000.0, 30000.0)
        self.assertGreater(xau, 0.0)
        self.assertGreater(xag, 0.0)
        self.assertLessEqual(risk, 1.0 + 1e-8)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_artifacts_lock_signal_risk_and_unpinned_framework(self) -> None:
        source = MQ5.read_text(encoding="utf-8")
        preset = SETFILE.read_text(encoding="utf-8")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertIn("qm_ea_id                    = 41451", source)
        self.assertIn("Strategy_LoadNr2Clv", source)
        self.assertIn("g_week_ratio_range[0] < g_week_ratio_range[1]", source)
        self.assertIn("g_newest_week_clv > strategy_clv_upper", source)
        self.assertIn("g_newest_week_clv < strategy_clv_lower", source)
        self.assertIn("direction = 1;  // High ratio settlement", source)
        self.assertIn("direction = -1; // Low ratio settlement", source)
        self.assertIn("strategy_required_weeks == 2", source)
        self.assertNotIn('XAUUSD.DWX";', source)
        self.assertNotIn('XAGUSD.DWX";', source)
        self.assertNotRegex(source, r"qm_rng_seed\s*==")
        self.assertNotRegex(source, r"qm_news_[a-z_]+\s*==")
        self.assertNotRegex(source, r"qm_friday_close_[a-z_]+\s*==")
        self.assertRegex(preset, r"(?m)^RISK_FIXED=1000$")
        self.assertRegex(preset, r"(?m)^RISK_PERCENT=0$")
        self.assertRegex(preset, r"(?m)^strategy_host_symbol=XAUUSD\.DWX$")
        self.assertRegex(preset, r"(?m)^strategy_companion_symbol=XAGUSD\.DWX$")
        self.assertEqual(manifest["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(manifest["basket_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])
        resolver = (EA_DIR.parents[1] / "include" / "QM" / "QM_MagicResolver.mqh").read_text(
            encoding="utf-8"
        )
        self.assertRegex(resolver, re.compile(r"414510000.*414510001", re.DOTALL))


if __name__ == "__main__":
    unittest.main()
