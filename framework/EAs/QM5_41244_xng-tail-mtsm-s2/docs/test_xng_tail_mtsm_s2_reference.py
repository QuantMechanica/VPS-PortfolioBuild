"""Independent reference invariants for QM5_41244's locked MTSM-S2 port."""

from __future__ import annotations

import math
import unittest
from pathlib import Path


LONG = 1
FLAT = 0
SHORT = -1
EA_DIR = Path(__file__).resolve().parents[1]


def partial_moments(returns: list[float]) -> tuple[float, float]:
    if len(returns) != 5:
        raise ValueError("the locked partial-moment window contains five returns")
    upm = sum(value * value for value in returns if value > 0.0) / 5.0
    lpm = sum(value * value for value in returns if value < 0.0) / 5.0
    return upm, lpm


def nearest_rank(values: list[float], percentile: float) -> float:
    if not values or not 0.0 < percentile <= 100.0:
        raise ValueError("invalid nearest-rank sample")
    ordered = sorted(values)
    rank = math.ceil(percentile * len(ordered) / 100.0)
    return ordered[rank - 1]


def s2_target(
    momentum_sum: float,
    current_upm: float,
    current_lpm: float,
    up_reference: float,
    low_reference: float,
) -> int:
    up_tail = current_upm >= up_reference
    low_tail = current_lpm >= low_reference
    if up_tail and low_tail:
        return FLAT
    if not up_tail and low_tail:
        return LONG
    if up_tail and not low_tail:
        return SHORT
    return LONG if momentum_sum > 0.0 else SHORT


def rolling_moments(returns: list[float]) -> list[tuple[float, float]]:
    return [partial_moments(returns[start : start + 5]) for start in range(253)]


class XngTailMtsmS2ReferenceTests(unittest.TestCase):
    def test_partial_moments_square_only_their_own_sign(self) -> None:
        upm, lpm = partial_moments([0.10, -0.20, 0.0, 0.30, -0.40])
        self.assertAlmostEqual(upm, (0.10**2 + 0.30**2) / 5.0)
        self.assertAlmostEqual(lpm, (0.20**2 + 0.40**2) / 5.0)

    def test_nearest_rank_eighty_percentile_is_one_based(self) -> None:
        self.assertEqual(nearest_rank(list(range(1, 253)), 80.0), 202)

    def test_exact_four_region_s2_map_and_tail_equality(self) -> None:
        self.assertEqual(s2_target(1.0, 2.0, 2.0, 2.0, 2.0), FLAT)
        self.assertEqual(s2_target(-1.0, 1.0, 2.0, 2.0, 2.0), LONG)
        self.assertEqual(s2_target(1.0, 2.0, 1.0, 2.0, 2.0), SHORT)
        self.assertEqual(s2_target(1.0, 1.0, 1.0, 2.0, 2.0), LONG)
        self.assertEqual(s2_target(-1.0, 1.0, 1.0, 2.0, 2.0), SHORT)

    def test_zero_momentum_maps_short_in_neither_tail_region(self) -> None:
        self.assertEqual(s2_target(0.0, 1.0, 1.0, 2.0, 2.0), SHORT)

    def test_current_partial_moment_is_excluded_from_references(self) -> None:
        # Newest-first returns: an extreme current five-return window followed
        # by 257 modest alternating returns. Reference observations start at 1.
        returns = [0.50] * 5 + [0.01 if index % 2 == 0 else -0.01 for index in range(257)]
        observations = rolling_moments(returns)
        current_upm, _ = observations[0]
        older_upm = [value[0] for value in observations[1:253]]
        self.assertGreater(current_upm, max(older_upm))
        self.assertNotIn(current_upm, older_upm)
        self.assertLess(nearest_rank(older_upm, 80.0), current_upm)

    def test_source_and_setfile_lock_the_card_contract(self) -> None:
        source = (EA_DIR / "QM5_41244_xng-tail-mtsm-s2.mq5").read_text(encoding="utf-8")
        setfile = (
            EA_DIR
            / "sets"
            / "QM5_41244_xng-tail-mtsm-s2_XNGUSD.DWX_D1_backtest.set"
        ).read_text(encoding="utf-8")
        for token in (
            'const string g_symbol = "XNGUSD.DWX";',
            "strategy_momentum_days        = 30;",
            "strategy_partial_moment_days  = 5;",
            "strategy_percentile_history   = 252;",
            "strategy_tail_percentile      = 80.0;",
            "Strategy_RecordAttemptState(g_state_bar_time)",
            "g_transition_closed_this_label = true;",
        ):
            self.assertIn(token, source)
        for token in (
            "RISK_FIXED=1000",
            "RISK_PERCENT=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_news_temporal=3",
            "qm_news_compliance=1",
            "qm_friday_close_enabled=1",
        ):
            self.assertIn(token, setfile)


if __name__ == "__main__":
    unittest.main()
