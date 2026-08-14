"""Independent reference checks for QM5_21522's locked formulas."""

from __future__ import annotations

import math
import unittest


BLOCK_RETURNS = 252
COMMON_CLOSES = 505
MIN_DOWN_DAYS = 100
BETA_TOLERANCE = 1.0e-12
VARIANCE_EPSILON = 1.0e-16
TREND_MONTHS = 12


def simple_returns(closes: list[float]) -> list[float]:
    if len(closes) != COMMON_CLOSES:
        raise ValueError("exactly 505 common closes are required")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")
    return [
        newer / older - 1.0
        for older, newer in zip(closes, closes[1:])
    ]


def strict_down_indices(market_block: list[float]) -> list[int]:
    if len(market_block) != BLOCK_RETURNS:
        raise ValueError("exactly 252 market returns are required")
    market_mean = math.fsum(market_block) / BLOCK_RETURNS
    return [index for index, value in enumerate(market_block) if value < market_mean]


def downside_beta_block(
    asset_returns: list[float],
    market_returns: list[float],
    offset: int,
) -> tuple[float, float, int]:
    if len(asset_returns) != COMMON_CLOSES - 1 or len(market_returns) != COMMON_CLOSES - 1:
        raise ValueError("exactly 504 synchronized returns are required")
    if offset not in (0, BLOCK_RETURNS):
        raise ValueError("block offset must be 0 or 252")
    asset = asset_returns[offset : offset + BLOCK_RETURNS]
    market = market_returns[offset : offset + BLOCK_RETURNS]
    if any(not math.isfinite(value) for value in asset + market):
        raise ValueError("returns must be finite")

    market_mean = math.fsum(market) / BLOCK_RETURNS
    selected = [index for index, value in enumerate(market) if value < market_mean]
    if len(selected) < MIN_DOWN_DAYS:
        raise ValueError("at least 100 strict below-mean rows are required")
    asset_mean = math.fsum(asset[index] for index in selected) / len(selected)
    selected_market_mean = math.fsum(market[index] for index in selected) / len(selected)
    covariance = math.fsum(
        (asset[index] - asset_mean) * (market[index] - selected_market_mean)
        for index in selected
    )
    variance = math.fsum(
        (market[index] - selected_market_mean) ** 2
        for index in selected
    )
    if variance <= VARIANCE_EPSILON:
        raise ValueError("selected market variance must be positive")
    return covariance / variance, market_mean, len(selected)


def twelve_month_trend(month_end_closes: list[float]) -> float:
    if len(month_end_closes) != TREND_MONTHS + 1:
        raise ValueError("exactly thirteen month-end closes are required")
    if any(not math.isfinite(value) or value <= 0.0 for value in month_end_closes):
        raise ValueError("month ends must be positive and finite")
    endpoint = math.log(month_end_closes[-1] / month_end_closes[0])
    chained = math.fsum(
        math.log(newer / older)
        for older, newer in zip(month_end_closes, month_end_closes[1:])
    )
    if not math.isclose(endpoint, chained, rel_tol=0.0, abs_tol=1.0e-10):
        raise AssertionError("endpoint and chained trend disagree")
    return endpoint


def locked_signal(beta_preceding: float, beta_recent: float, trend: float) -> int:
    if not all(math.isfinite(value) for value in (beta_preceding, beta_recent, trend)):
        raise ValueError("state must be finite")
    if not beta_recent < beta_preceding - BETA_TOLERANCE or trend == 0.0:
        return 0
    return 1 if trend > 0.0 else -1


def deterministic_market() -> list[float]:
    return [
        0.00015 * ((index % 29) - 14)
        + 0.00003 * math.sin(index * 0.37)
        for index in range(COMMON_CLOSES - 1)
    ]


class LowDownsideBetaTrendReferenceTest(unittest.TestCase):
    def test_exact_block_slopes_and_local_means(self) -> None:
        market = deterministic_market()
        asset = [
            (1.75 if index < BLOCK_RETURNS else 0.40) * value
            + (0.0007 if index < BLOCK_RETURNS else -0.0003)
            for index, value in enumerate(market)
        ]
        preceding, preceding_mean, preceding_days = downside_beta_block(asset, market, 0)
        recent, recent_mean, recent_days = downside_beta_block(asset, market, BLOCK_RETURNS)
        self.assertAlmostEqual(preceding, 1.75, places=12)
        self.assertAlmostEqual(recent, 0.40, places=12)
        self.assertEqual(preceding_days, len(strict_down_indices(market[:BLOCK_RETURNS])))
        self.assertEqual(recent_days, len(strict_down_indices(market[BLOCK_RETURNS:])))
        self.assertAlmostEqual(preceding_mean, math.fsum(market[:252]) / 252, places=16)
        self.assertAlmostEqual(recent_mean, math.fsum(market[252:]) / 252, places=16)

    def test_blocks_have_disjoint_return_indices(self) -> None:
        preceding = set(range(0, BLOCK_RETURNS))
        recent = set(range(BLOCK_RETURNS, 2 * BLOCK_RETURNS))
        self.assertFalse(preceding & recent)
        self.assertEqual(max(preceding), 251)
        self.assertEqual(min(recent), 252)

    def test_recent_changes_do_not_change_preceding_beta(self) -> None:
        market = deterministic_market()
        baseline_asset = [1.2 * value + 0.0001 for value in market]
        changed_asset = baseline_asset[:]
        changed_asset[BLOCK_RETURNS:] = [
            -0.8 * value + 0.002 for value in market[BLOCK_RETURNS:]
        ]
        baseline_preceding = downside_beta_block(baseline_asset, market, 0)[0]
        changed_preceding = downside_beta_block(changed_asset, market, 0)[0]
        changed_recent = downside_beta_block(changed_asset, market, BLOCK_RETURNS)[0]
        self.assertAlmostEqual(baseline_preceding, changed_preceding, places=14)
        self.assertAlmostEqual(changed_recent, -0.8, places=12)

    def test_strict_below_mean_excludes_ties(self) -> None:
        market = [-0.01] * 100 + [0.0] * 52 + [0.01] * 100
        selected = strict_down_indices(market)
        self.assertEqual(len(selected), 100)
        self.assertTrue(all(index < 100 for index in selected))

    def test_minimum_support_and_singular_variance_fail_closed(self) -> None:
        market_low_support = [-0.01] * 99 + [0.01] * 405
        asset = [0.5 * value for value in market_low_support]
        with self.assertRaisesRegex(ValueError, "at least 100"):
            downside_beta_block(asset, market_low_support, 0)

        market_singular = [-0.01] * 100 + [0.01] * 152 + deterministic_market()[252:]
        asset_singular = [0.5 * value for value in market_singular]
        with self.assertRaisesRegex(ValueError, "variance"):
            downside_beta_block(asset_singular, market_singular, 0)

    def test_falling_beta_gate_is_strict_and_symmetric_trend(self) -> None:
        self.assertEqual(locked_signal(1.0, 0.5, 0.2), 1)
        self.assertEqual(locked_signal(1.0, 0.5, -0.2), -1)
        self.assertEqual(locked_signal(1.0, 1.0 - BETA_TOLERANCE, 0.2), 0)
        self.assertEqual(locked_signal(1.0, 1.1, 0.2), 0)
        self.assertEqual(locked_signal(1.0, 0.5, 0.0), 0)

    def test_twelve_month_endpoint_and_exact_support(self) -> None:
        rising = [100.0, 98.0, 104.0, 101.0, 108.0, 105.0, 112.0,
                  109.0, 116.0, 113.0, 121.0, 118.0, 125.0]
        self.assertAlmostEqual(twelve_month_trend(rising), math.log(1.25), places=14)
        with self.assertRaisesRegex(ValueError, "thirteen"):
            twelve_month_trend(rising[:-1])
        with self.assertRaisesRegex(ValueError, "505"):
            simple_returns([100.0] * 504)


if __name__ == "__main__":
    unittest.main(verbosity=2)
