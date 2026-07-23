import csv
import tempfile
import unittest
from pathlib import Path

from framework.scripts.portfolio_aggregate_gate import check_portfolio_aggregate_compliance


class PortfolioAggregateGateTests(unittest.TestCase):
    def _curve(self, path: Path, rows: list[tuple[str, float]]) -> None:
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=["timestamp", "equity"])
            writer.writeheader()
            for ts, equity in rows:
                writer.writerow({"timestamp": ts, "equity": equity})

    def test_basket_pass(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            c1 = root / "a.csv"
            c2 = root / "b.csv"
            self._curve(c1, [("2026-01-01T00:00:00+00:00", 100000), ("2026-01-02T00:00:00+00:00", 101000)])
            self._curve(c2, [("2026-01-01T00:00:00+00:00", 100000), ("2026-01-02T00:00:00+00:00", 100500)])
            result = check_portfolio_aggregate_compliance(
                [
                    {"ea": "QM5_1001", "symbol": "EURUSD.DWX", "equity_curve": str(c1)},
                    {"ea": "QM5_1002", "symbol": "GBPUSD.DWX", "equity_curve": str(c2)},
                ]
            )
            self.assertEqual(result["verdict"], "BASKET_PASS")

    def test_basket_fail_on_drawdown(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            c1 = root / "a.csv"
            c2 = root / "b.csv"
            self._curve(c1, [("2026-01-01T00:00:00+00:00", 100000), ("2026-01-02T00:00:00+00:00", 94000)])
            self._curve(c2, [("2026-01-01T00:00:00+00:00", 100000), ("2026-01-02T00:00:00+00:00", 94000)])
            result = check_portfolio_aggregate_compliance(
                [
                    {"ea": "QM5_1001", "symbol": "EURUSD.DWX", "equity_curve": str(c1)},
                    {"ea": "QM5_1002", "symbol": "GBPUSD.DWX", "equity_curve": str(c2)},
                ]
            )
            self.assertEqual(result["verdict"], "BASKET_FAIL")


if __name__ == "__main__":
    unittest.main()
