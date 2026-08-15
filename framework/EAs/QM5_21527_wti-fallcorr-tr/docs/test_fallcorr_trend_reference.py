"""Independent reference checks for QM5_21527's locked formulas."""

from __future__ import annotations

import math
import unittest


BLOCK_RETURNS = 63
COMMON_CLOSES = 127
CORRELATION_TOLERANCE = 1.0e-12
VARIANCE_EPSILON = 1.0e-16
TREND_MONTHS = 12


def simple_returns(closes: list[float]) -> list[float]:
    if len(closes) != COMMON_CLOSES:
        raise ValueError("exactly 127 synchronized closes are required")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")
    return [newer / older - 1.0 for older, newer in zip(closes, closes[1:])]


def sample_pearson_block(
    asset_returns: list[float],
    market_returns: list[float],
    newest_offset: int,
) -> float:
    expected_returns = COMMON_CLOSES - 1
    if len(asset_returns) != expected_returns or len(market_returns) != expected_returns:
        raise ValueError("exactly 126 synchronized returns are required")
    if newest_offset not in (0, BLOCK_RETURNS):
        raise ValueError("offset must select the recent or preceding block")
    start = expected_returns - newest_offset - BLOCK_RETURNS
    asset = asset_returns[start : start + BLOCK_RETURNS]
    market = market_returns[start : start + BLOCK_RETURNS]
    if any(not math.isfinite(value) for value in asset + market):
        raise ValueError("returns must be finite")

    asset_mean = math.fsum(asset) / BLOCK_RETURNS
    market_mean = math.fsum(market) / BLOCK_RETURNS
    asset_ss = math.fsum((value - asset_mean) ** 2 for value in asset)
    market_ss = math.fsum((value - market_mean) ** 2 for value in market)
    cross = math.fsum(
        (asset_value - asset_mean) * (market_value - market_mean)
        for asset_value, market_value in zip(asset, market)
    )
    if asset_ss <= VARIANCE_EPSILON or market_ss <= VARIANCE_EPSILON:
        raise ValueError("block variance must be positive")
    correlation = cross / math.sqrt(asset_ss * market_ss)
    if not math.isfinite(correlation) or abs(correlation) > 1.0 + CORRELATION_TOLERANCE:
        raise ValueError("correlation is invalid")
    return max(-1.0, min(1.0, correlation))


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


def locked_signal(correlation_preceding: float, correlation_recent: float, trend: float) -> int:
    values = (correlation_preceding, correlation_recent, trend)
    if not all(math.isfinite(value) for value in values):
        raise ValueError("state must be finite")
    eligible = abs(correlation_recent) + CORRELATION_TOLERANCE < abs(correlation_preceding)
    if not eligible or trend == 0.0:
        return 0
    return 1 if trend > 0.0 else -1


def deterministic_market() -> list[float]:
    return [
        0.00015 * ((index % 17) - 8) + 0.00007 * math.sin(index * 0.41)
        for index in range(COMMON_CLOSES - 1)
    ]


class FallingCorrelationTrendReferenceTest(unittest.TestCase):
    def test_newest_offsets_select_disjoint_return_blocks(self) -> None:
        recent = set(range(63, 126))
        preceding = set(range(0, 63))
        self.assertFalse(recent & preceding)
        self.assertEqual(min(recent), 63)
        self.assertEqual(max(preceding), 62)

    def test_block_local_pearson_and_offset_mapping(self) -> None:
        market = deterministic_market()
        asset = [2.0 * value + 0.0003 for value in market[:BLOCK_RETURNS]]
        asset += [-3.0 * value - 0.0002 for value in market[BLOCK_RETURNS:]]
        preceding = sample_pearson_block(asset, market, BLOCK_RETURNS)
        recent = sample_pearson_block(asset, market, 0)
        self.assertAlmostEqual(preceding, 1.0, places=12)
        self.assertAlmostEqual(recent, -1.0, places=12)

    def test_recent_changes_cannot_change_preceding_correlation(self) -> None:
        market = deterministic_market()
        baseline = [1.2 * value + 0.0001 for value in market]
        changed = baseline[:BLOCK_RETURNS] + [
            math.sin(index * 0.63) * 0.0008
            for index in range(BLOCK_RETURNS)
        ]
        baseline_preceding = sample_pearson_block(baseline, market, BLOCK_RETURNS)
        changed_preceding = sample_pearson_block(changed, market, BLOCK_RETURNS)
        self.assertAlmostEqual(baseline_preceding, changed_preceding, places=14)

    def test_falling_absolute_gate_is_strict_and_sign_symmetric(self) -> None:
        self.assertEqual(locked_signal(-0.80, 0.25, 0.20), 1)
        self.assertEqual(locked_signal(0.80, -0.25, -0.20), -1)
        self.assertEqual(locked_signal(0.50, -0.50, 0.20), 0)
        self.assertEqual(locked_signal(0.50, 0.50 - CORRELATION_TOLERANCE, 0.20), 0)
        self.assertEqual(locked_signal(0.50, 0.20, 0.0), 0)

    def test_manual_sample_pearson_equivalence(self) -> None:
        market = deterministic_market()
        asset = [
            0.35 * value + 0.0004 * math.cos(index * 0.29)
            for index, value in enumerate(market)
        ]
        observed = sample_pearson_block(asset, market, 0)
        x = asset[-BLOCK_RETURNS:]
        y = market[-BLOCK_RETURNS:]
        x_mean = math.fsum(x) / BLOCK_RETURNS
        y_mean = math.fsum(y) / BLOCK_RETURNS
        covariance = math.fsum((a - x_mean) * (b - y_mean) for a, b in zip(x, y)) / 62
        x_variance = math.fsum((a - x_mean) ** 2 for a in x) / 62
        y_variance = math.fsum((b - y_mean) ** 2 for b in y) / 62
        expected = covariance / math.sqrt(x_variance * y_variance)
        self.assertAlmostEqual(observed, expected, places=14)

    def test_singular_variance_and_wrong_support_fail_closed(self) -> None:
        market = deterministic_market()
        with self.assertRaisesRegex(ValueError, "variance"):
            sample_pearson_block([0.0] * 126, market, 0)
        with self.assertRaisesRegex(ValueError, "126"):
            sample_pearson_block(market[:-1], market[:-1], 0)
        with self.assertRaisesRegex(ValueError, "127"):
            simple_returns([100.0] * 126)

    def test_twelve_month_endpoint_and_direction(self) -> None:
        rising = [100.0, 98.0, 104.0, 101.0, 108.0, 105.0, 112.0,
                  109.0, 116.0, 113.0, 121.0, 118.0, 125.0]
        falling = list(reversed(rising))
        self.assertAlmostEqual(twelve_month_trend(rising), math.log(1.25), places=14)
        self.assertEqual(locked_signal(0.70, 0.20, twelve_month_trend(rising)), 1)
        self.assertEqual(locked_signal(0.70, 0.20, twelve_month_trend(falling)), -1)
        with self.assertRaisesRegex(ValueError, "thirteen"):
            twelve_month_trend(rising[:-1])


if __name__ == "__main__":
    unittest.main(verbosity=2)
