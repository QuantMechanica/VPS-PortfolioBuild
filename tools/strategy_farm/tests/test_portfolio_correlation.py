import datetime as dt
import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.commission import CommissionModel  # noqa: E402
from portfolio.portfolio_common import load_streams  # noqa: E402
from portfolio.portfolio_correlation import build_artifact  # noqa: E402


class PortfolioCorrelationTests(unittest.TestCase):
    def test_cost_rule_correlation_and_sparse_overlap(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = common_dir / "QM" / "q08_trades"
            stream_dir.mkdir(parents=True)

            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            engine = CommissionModel(REPO / "framework" / "registry" / "live_commission.json")
            expected_cost = engine.cost_round_trip("EURUSD.DWX", 1.0, 10000.0)
            self._write_stream(
                stream_dir / "100_EURUSD_DWX.jsonl",
                start,
                [float(i) for i in range(1, 61)],
                expected_cost,
            )
            self._write_stream(
                stream_dir / "101_EURUSD_DWX.jsonl",
                start,
                [float(-i) for i in range(1, 61)],
                expected_cost,
            )
            self._write_stream(
                stream_dir / "102_EURUSD_DWX.jsonl",
                start,
                [20.0, -10.0, 15.0],
                expected_cost,
            )

            streams = load_streams(common_dir)
            first_trade = streams[(100, "EURUSD.DWX")][0]
            self.assertEqual(first_trade.commission_cost, expected_cost)
            self.assertEqual(first_trade.net_of_cost, first_trade.net - expected_cost)

            artifact = build_artifact(
                common_dir=common_dir,
                all_streams=True,
                min_overlap_days=10,
            )

        self.assertEqual(artifact["generated_basis"], "all_q08_streams_uncertified")
        self.assertFalse(artifact["commission_degraded"])
        self.assertEqual(artifact["keys"], ["100:EURUSD.DWX", "101:EURUSD.DWX", "102:EURUSD.DWX"])
        self.assertAlmostEqual(artifact["correlation"][0][1], -1.0)
        self.assertIn(["100:EURUSD.DWX", "102:EURUSD.DWX"], artifact["insufficient_overlap"])

    def _write_stream(
        self,
        path: Path,
        start: dt.datetime,
        desired_pnl: list[float],
        cost: float,
    ) -> None:
        with path.open("w", encoding="utf-8") as fh:
            for offset, net_of_cost in enumerate(desired_pnl):
                row = {
                    "event": "TRADE_CLOSED",
                    "time": int((start + dt.timedelta(days=offset)).timestamp()),
                    "net": net_of_cost + cost,
                    "profit": net_of_cost + cost,
                    "swap": 0.0,
                    "commission": 0.0,
                    "volume": 1.0,
                    "notional": 10000.0,
                }
                fh.write(json.dumps(row, sort_keys=True) + "\n")


if __name__ == "__main__":
    unittest.main()
