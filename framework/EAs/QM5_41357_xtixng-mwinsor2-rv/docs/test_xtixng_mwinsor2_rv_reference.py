"""Independent reference fixtures for QM5_41357 fixed-tail Winsor basket."""

import math
from pathlib import Path
import unittest


WINSOR_EACH_TAIL = 2
DIVISOR = 12
EPSILON = 1e-12
EA_SOURCE = (
    Path(__file__).resolve().parents[1]
    / "QM5_41357_xtixng-mwinsor2-rv.mq5"
)


def winsorized_mean(returns):
    if len(returns) != 12 or not all(math.isfinite(x) for x in returns):
        return None
    ordered = sorted(returns)
    capped = [
        ordered[WINSOR_EACH_TAIL]
        if i < WINSOR_EACH_TAIL
        else ordered[-WINSOR_EACH_TAIL - 1]
        if i >= len(ordered) - WINSOR_EACH_TAIL
        else value
        for i, value in enumerate(ordered)
    ]
    return sum(capped) / DIVISOR


def trimmed_mean(returns):
    ordered = sorted(returns)
    return sum(ordered[2:10]) / 8


def pair_direction(returns):
    location = winsorized_mean(returns)
    if location is None:
        return 0
    if location > EPSILON:
        return -1  # sell XTI, buy XNG
    if location < -EPSILON:
        return 1  # buy XTI, sell XNG
    return 0


class XtiXngWinsor2Reference(unittest.TestCase):
    def test_runtime_identity_and_locked_arithmetic(self):
        source = EA_SOURCE.read_text(encoding="utf-8")
        self.assertIn('g_leg_xti == "XTIUSD.DWX"', source)
        self.assertIn('g_leg_xng == "XNGUSD.DWX"', source)
        self.assertIn("qm_ea_id == 41357", source)
        self.assertIn("strategy_winsor_each_tail == 2", source)
        self.assertIn("strategy_winsor_divisor == 12", source)
        self.assertIn("strategy_xng_max_spread_points == 3000", source)
        self.assertIn("MathIsValidNumber(RISK_FIXED)", source)

    def test_exact_two_per_tail_replacement(self):
        returns = [12.0, 1.0, 8.0, 2.0, 11.0, 3.0,
                   10.0, 4.0, 9.0, 5.0, 7.0, 6.0]
        # sorted [1..12] -> [3,3,3,4,5,6,7,8,9,10,10,10]
        self.assertEqual(winsorized_mean(returns), 6.5)

    def test_positive_location_is_faded_short_ratio(self):
        returns = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06,
                   0.07, 0.08, 0.09, 0.10, 0.11, 0.12]
        self.assertAlmostEqual(winsorized_mean(returns), 0.065, places=15)
        self.assertEqual(pair_direction(returns), -1)

    def test_reflection_changes_only_pair_side(self):
        returns = [0.063, -0.073, 0.043, 0.006, -0.080, 0.085,
                   0.014, 0.004, -0.033, -0.068, 0.030, 0.029]
        reflected = [-x for x in returns]
        self.assertAlmostEqual(
            winsorized_mean(reflected), -winsorized_mean(returns), places=15
        )
        self.assertEqual(pair_direction(reflected), -pair_direction(returns))

    def test_fixed_trim_neighbor_takes_opposite_side(self):
        returns = [0.063, -0.073, 0.043, 0.006, -0.080, 0.085,
                   0.014, 0.004, -0.033, -0.068, 0.030, 0.029]
        self.assertAlmostEqual(
            winsorized_mean(returns), -0.002083333333333335, places=15
        )
        self.assertAlmostEqual(trimmed_mean(returns), 0.003125, places=15)
        self.assertEqual(pair_direction(returns), 1)

    def test_exact_zero_consumes_flat(self):
        returns = [-0.06, -0.05, -0.04, -0.03, -0.02, -0.01,
                   0.01, 0.02, 0.03, 0.04, 0.05, 0.06]
        self.assertAlmostEqual(winsorized_mean(returns), 0.0, places=15)
        self.assertEqual(pair_direction(returns), 0)

    def test_invalid_values_fail_closed(self):
        self.assertIsNone(winsorized_mean([0.01] * 11))
        self.assertIsNone(winsorized_mean([0.01] * 11 + [math.nan]))

    def test_synchronized_log_ratio_return_identity(self):
        oil = [100.0, 110.0, 121.0]
        gas = [10.0, 10.5, 11.025]
        ratios = [math.log(g) - math.log(s) for g, s in zip(oil, gas)]
        returns = [ratios[i + 1] - ratios[i] for i in range(2)]
        direct = [
            math.log((oil[i + 1] / gas[i + 1]) /
                     (oil[i] / gas[i]))
            for i in range(2)
        ]
        for actual, expected in zip(returns, direct):
            self.assertAlmostEqual(actual, expected, places=15)


if __name__ == "__main__":
    unittest.main()
