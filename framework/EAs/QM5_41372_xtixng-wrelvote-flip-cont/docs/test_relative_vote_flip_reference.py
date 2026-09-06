"""Deterministic reference checks for QM5_41372 relative-vote flip."""

from __future__ import annotations

import json
import math
import re
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]
MQ5 = EA_DIR / "QM5_41372_xtixng-wrelvote-flip-cont.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41372_xtixng-wrelvote-flip-cont_QM5_41372_XTI_XNG_WRELVOTE_FLIP_CONT_D1_D1_backtest.set"
)
MANIFEST = EA_DIR / "basket_manifest.json"


def vote_flip_signal(relative_returns: list[float], epsilon: float = 1e-10) -> int:
    if len(relative_returns) != 4 or any(
        not math.isfinite(value) or abs(value) <= epsilon for value in relative_returns
    ):
        return 0
    signs = [1 if value > 0 else -1 for value in relative_returns]
    old_vote = sum(signs[:3])
    new_vote = sum(signs[1:])
    if old_vote < 0 < new_vote:
        return 1
    if old_vote > 0 > new_vote:
        return -1
    return 0


def week_key(value: datetime) -> datetime:
    return (value - timedelta(days=value.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0
    )


def weeks_valid(current_week: datetime, completed: list[tuple[datetime, int]]) -> bool:
    if len(completed) != 5:
        return False
    expected = current_week - timedelta(days=7)
    for anchor, sessions in completed:
        if week_key(anchor) != expected or not 3 <= sessions <= 5:
            return False
        expected -= timedelta(days=7)
    return True


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
    xti = math.floor((raw_xti + 1e-12) / step) * step
    xng = math.floor((raw_xng + 1e-12) / step) * step
    risk = xti / full_xti + xng / full_xng
    notional_ratio = xti * xti_notional_per_lot / (xng * xng_notional_per_lot)
    return xti, xng, risk, notional_ratio


class RelativeVoteFlipReferenceTest(unittest.TestCase):
    def test_negative_to_positive_majority_follows_wti(self) -> None:
        self.assertEqual(vote_flip_signal([-0.03, 0.02, -0.01, 0.04]), 1)

    def test_positive_to_negative_majority_follows_xng(self) -> None:
        self.assertEqual(vote_flip_signal([0.03, -0.02, 0.01, -0.04]), -1)

    def test_no_flip_and_ties_are_flat(self) -> None:
        for values in (
            [0.03, 0.02, -0.01, 0.04],
            [-0.03, -0.02, 0.01, -0.04],
            [-0.03, 0.02, -0.01, -0.04],
            [-0.03, 0.0, -0.01, 0.04],
            [-0.03, 1e-10, -0.01, 0.04],
        ):
            with self.subTest(values=values):
                self.assertEqual(vote_flip_signal(values), 0)

    def test_five_consecutive_completed_weeks_and_session_bounds(self) -> None:
        current = datetime(2026, 8, 24, tzinfo=UTC)
        valid = [(current - timedelta(days=7 * index), 5) for index in range(1, 6)]
        self.assertTrue(weeks_valid(current, valid))
        invalid_sessions = valid.copy()
        invalid_sessions[2] = (invalid_sessions[2][0], 2)
        self.assertFalse(weeks_valid(current, invalid_sessions))
        missing_week = valid.copy()
        missing_week[3] = (missing_week[3][0] - timedelta(days=7), 5)
        self.assertFalse(weeks_valid(current, missing_week))

    def test_aggregate_risk_and_equal_notional_are_bounded(self) -> None:
        xti, xng, risk, ratio = package_lots(2100.0, 700.0, 240000.0, 30000.0)
        self.assertGreater(xti, 0.0)
        self.assertGreater(xng, 0.0)
        self.assertLessEqual(risk, 1.0 + 1e-8)
        self.assertLessEqual(abs(ratio - 1.0) * 100.0, 20.0)

    def test_static_artifacts_lock_identity_signal_and_fixed_risk(self) -> None:
        source = MQ5.read_text(encoding="utf-8")
        preset = SETFILE.read_text(encoding="utf-8")
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertIn("qm_ea_id                    = 41372", source)
        self.assertIn("Strategy_LoadRelativeVoteFlip", source)
        self.assertIn("g_old_vote < 0 && g_new_vote > 0", source)
        self.assertIn("g_old_vote > 0 && g_new_vote < 0", source)
        self.assertIn("for(int slot = 0; slot < 5; ++slot)", source)
        self.assertIn("strategy_history_bars_d1 == 50", source)
        self.assertNotIn("41371", source)
        self.assertRegex(preset, r"(?m)^RISK_FIXED=1000$")
        self.assertRegex(preset, r"(?m)^RISK_PERCENT=0$")
        self.assertRegex(preset, r"(?m)^qm_friday_close_enabled=false$")
        self.assertEqual(manifest["host_symbol"], "XTIUSD.DWX")
        self.assertEqual(manifest["basket_symbols"], ["XTIUSD.DWX", "XNGUSD.DWX"])
        resolver = (EA_DIR.parents[1] / "include" / "QM" / "QM_MagicResolver.mqh").read_text(
            encoding="utf-8"
        )
        self.assertRegex(resolver, re.compile(r"413720000.*413720001", re.DOTALL))


if __name__ == "__main__":
    unittest.main()
