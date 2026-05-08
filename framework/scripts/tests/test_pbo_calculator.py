from __future__ import annotations

import unittest

from framework.scripts.pbo_calculator import compute_pbo


class PboCalculatorTests(unittest.TestCase):
    def test_compute_pbo_returns_zero_for_consistent_winner(self) -> None:
        scores = {
            "cfg_a": {"s1": 2.0, "s2": 2.0, "s3": 2.0, "s4": 2.0},
            "cfg_b": {"s1": 1.0, "s2": 1.0, "s3": 1.0, "s4": 1.0},
            "cfg_c": {"s1": 0.5, "s2": 0.5, "s3": 0.5, "s4": 0.5},
        }
        result = compute_pbo(scores)
        self.assertEqual(result["pbo_pct"], 0.0)
        self.assertGreater(result["splits_evaluated"], 0)

    def test_compute_pbo_returns_hundred_when_not_enough_slices(self) -> None:
        scores = {
            "cfg_a": {"s1": 2.0},
            "cfg_b": {"s1": 1.0},
        }
        result = compute_pbo(scores)
        self.assertEqual(result["pbo_pct"], 100.0)
        self.assertEqual(result["splits_evaluated"], 0)


if __name__ == "__main__":
    unittest.main()
