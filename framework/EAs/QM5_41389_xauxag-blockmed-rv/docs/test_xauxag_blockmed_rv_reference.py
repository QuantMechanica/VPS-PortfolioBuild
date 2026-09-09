"""Independent reference fixtures for QM5_41389 XAU/XAG block median."""

import math
from pathlib import Path
import re
import unittest


EPSILON = 1e-12
EA_SOURCE = (
    Path(__file__).resolve().parents[1]
    / "QM5_41389_xauxag-blockmed-rv.mq5"
)


def block_median(changes):
    if len(changes) != 12 or not all(math.isfinite(x) for x in changes):
        return None
    blocks = [sum(changes[start : start + 3]) / 3 for start in range(0, 12, 3)]
    ordered = sorted(blocks)
    return (ordered[1] + ordered[2]) / 2


def pair_direction(changes):
    location = block_median(changes)
    if location is None:
        return 0
    if location > EPSILON:
        return -1  # sell XAU, buy XAG
    if location < -EPSILON:
        return 1  # buy XAU, sell XAG
    return 0


class XauXagBlockMedianReference(unittest.TestCase):
    def test_runtime_identity_and_locked_strategy_arithmetic(self):
        source = EA_SOURCE.read_text(encoding="utf-8")
        self.assertIn('g_leg_xau == "XAUUSD.DWX"', source)
        self.assertIn('g_leg_xag == "XAGUSD.DWX"', source)
        self.assertIn("qm_ea_id == 41389", source)
        self.assertIn("strategy_block_count == 4", source)
        self.assertIn("strategy_block_width == 3", source)
        self.assertIn("strategy_median_divisor == 2", source)
        self.assertIn("RISK_FIXED > 0.0", source)

    def test_exact_chronological_block_membership(self):
        changes = [1.0, 2.0, 3.0, 10.0, 20.0, 30.0,
                   -3.0, -6.0, -9.0, -10.0, -20.0, -30.0]
        # block means [2, 20, -6, -20] -> inner [-6, 2] -> -2
        self.assertEqual(block_median(changes), -2.0)
        self.assertEqual(pair_direction(changes), 1)

    def test_positive_location_is_faded_short_ratio(self):
        changes = [0.01, 0.02, 0.03] * 4
        self.assertAlmostEqual(block_median(changes), 0.02, places=15)
        self.assertEqual(pair_direction(changes), -1)

    def test_reflection_changes_only_pair_side(self):
        changes = [0.12, 0.09, 0.06, -0.03, -0.03, -0.03,
                   0.02, 0.02, 0.02, -0.08, -0.07, -0.06]
        reflected = [-x for x in changes]
        self.assertAlmostEqual(
            block_median(reflected), -block_median(changes), places=15
        )
        self.assertEqual(pair_direction(reflected), -pair_direction(changes))

    def test_raw_mean_neighbor_takes_opposite_side(self):
        changes = [0.12, 0.09, 0.06, -0.03, -0.03, -0.03,
                   0.02, 0.02, 0.02, -0.08, -0.07, -0.06]
        self.assertAlmostEqual(sum(changes) / 12, 0.0025, places=15)
        self.assertAlmostEqual(block_median(changes), -0.005, places=15)
        self.assertEqual(pair_direction(changes), 1)

    def test_exact_zero_and_epsilon_consume_flat(self):
        zero = [0.09, 0.06, 0.03, -0.03, -0.03, -0.03,
                0.03, 0.03, 0.03, -0.09, -0.06, -0.03]
        self.assertAlmostEqual(block_median(zero), 0.0, places=15)
        self.assertEqual(pair_direction(zero), 0)
        self.assertEqual(pair_direction([EPSILON / 2] * 12), 0)

    def test_invalid_values_fail_closed(self):
        self.assertIsNone(block_median([0.01] * 11))
        self.assertIsNone(block_median([0.01] * 11 + [math.nan]))

    def test_synchronized_log_ratio_change_identity(self):
        gold = [100.0, 110.0, 121.0]
        silver = [10.0, 10.5, 11.025]
        ratios = [math.log(g) - math.log(s) for g, s in zip(gold, silver)]
        changes = [ratios[i + 1] - ratios[i] for i in range(2)]
        direct = [
            math.log((gold[i + 1] / silver[i + 1]) /
                     (gold[i] / silver[i]))
            for i in range(2)
        ]
        for actual, expected in zip(changes, direct):
            self.assertAlmostEqual(actual, expected, places=15)

    def test_framework_owned_inputs_are_not_default_pinned(self):
        source = EA_SOURCE.read_text(encoding="utf-8")
        guard = re.search(
            r"bool Strategy_InputsValid\(\)\s*\{(?P<body>.*?)^\s*\}",
            source,
            re.MULTILINE | re.DOTALL,
        ).group("body")
        for name in ("qm_rng_seed", "qm_news_", "qm_friday_close_"):
            self.assertNotIn(name, guard)
        self.assertNotRegex(
            guard,
            r"qm_stress_reject_probability\s*(?:==|!=)",
        )
        self.assertIn("qm_stress_reject_probability >= 0.0", guard)
        self.assertIn("qm_stress_reject_probability <= 1.0", guard)


if __name__ == "__main__":
    unittest.main()

