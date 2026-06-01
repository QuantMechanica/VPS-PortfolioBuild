import sys
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.commission import CommissionModel  # noqa: E402


class CommissionModelTests(unittest.TestCase):
    def setUp(self) -> None:
        self.model = CommissionModel(REPO / "framework" / "registry" / "live_commission.json")

    def test_forex_flat_wins_for_small_notional(self) -> None:
        self.assertEqual(self.model.cost_round_trip("EURUSD.DWX", 1.0, 10000.0), 5.0)

    def test_forex_pct_wins_for_large_notional(self) -> None:
        self.assertEqual(self.model.cost_round_trip("EURUSD.DWX", 1.0, 200000.0), 10.0)

    def test_index_uses_five_point_five_flat_floor(self) -> None:
        self.assertEqual(self.model.cost_round_trip("NDX.DWX", 2.0, 10000.0), 11.0)

    def test_commodity_is_pure_pct(self) -> None:
        self.assertEqual(self.model.cost_round_trip("XAUUSD.DWX", 3.0, 250000.0), 12.5)

    def test_legacy_none_path_flags_degraded(self) -> None:
        cost = self.model.cost_round_trip("XAUUSD.DWX", 3.0, None)

        self.assertEqual(cost, 0.0)
        self.assertTrue(self.model.degraded)
        self.assertEqual(self.model.degraded_symbols, {"XAUUSD.DWX"})

    def test_unknown_symbol_uses_default_class_and_warns(self) -> None:
        with self.assertLogs("portfolio.commission", level="WARNING") as logs:
            self.assertEqual(self.model.cost_round_trip("UNKNOWN.DWX", 1.0, 10000.0), 5.0)

        self.assertIn("Unknown commission symbol UNKNOWN.DWX", "\n".join(logs.output))
        self.assertEqual(self.model.unknown_symbols, {"UNKNOWN.DWX"})


if __name__ == "__main__":
    unittest.main()
