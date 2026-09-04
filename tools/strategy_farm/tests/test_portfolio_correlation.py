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
                bootstrap_replicates=200,
            )

        self.assertEqual(artifact["schema"], "qm.portfolio-correlation/v2")
        self.assertEqual(artifact["generated_basis"], "all_q08_streams_uncertified")
        self.assertEqual(artifact["method_status"], "OWNER_RATIFIED")
        self.assertEqual(
            artifact["numeric_threshold_status"],
            "WORKING_DEFAULT_OPEN_OWNER_ITEM",
        )
        self.assertFalse(artifact["commission_degraded"])
        self.assertEqual(artifact["keys"], ["100:EURUSD.DWX", "101:EURUSD.DWX", "102:EURUSD.DWX"])
        self.assertAlmostEqual(artifact["correlation"][0][1], -1.0)
        self.assertIn(["100:EURUSD.DWX", "102:EURUSD.DWX"], artifact["insufficient_overlap"])
        sparse = next(
            row
            for row in artifact["pair_evidence"]
            if row["pair"] == ["100:EURUSD.DWX", "102:EURUSD.DWX"]
        )
        self.assertEqual(sparse["admission_verdict"], "ABSTAIN")
        self.assertIsNone(artifact["correlation"][0][2])

    def test_cos_exact_shift_flags_clustered_same_symbol_occupancy(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = common_dir / "QM" / "q08_trades"
            stream_dir.mkdir(parents=True)
            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            end = start + dt.timedelta(days=29)
            self._write_trade(
                stream_dir / "200_XAUUSD_DWX.jsonl",
                entry=start,
                exit=end,
                symbol="XAUUSD.DWX",
                side="BUY",
            )
            self._write_trade(
                stream_dir / "201_XAUUSD_DWX.jsonl",
                entry=start,
                exit=end,
                symbol="XAUUSD.DWX",
                side="BUY",
            )
            # Extend the pool-wide circular ring so the two 30-day blocks are not
            # saturated. This third stream is below the COS power floor itself.
            anchor = start + dt.timedelta(days=90)
            self._write_trade(
                stream_dir / "202_USDJPY_DWX.jsonl",
                entry=anchor,
                exit=anchor,
                symbol="USDJPY.DWX",
                side="SELL",
            )

            streams = load_streams(common_dir)
            self.assertEqual(streams[(200, "XAUUSD.DWX")][0].side, "BUY")
            artifact = build_artifact(
                common_dir=common_dir,
                all_streams=True,
                bootstrap_replicates=100,
            )

        pair = next(
            row
            for row in artifact["pair_evidence"]
            if row["pair"] == ["200:XAUUSD.DWX", "201:XAUUSD.DWX"]
        )
        self.assertEqual(pair["layer_b"]["testability"], "TESTABLE")
        self.assertEqual(pair["layer_b"]["observed_cooccupancy"], 30)
        self.assertEqual(pair["layer_b"]["psi"], 1.0)
        self.assertEqual(pair["layer_b"]["verdict"], "FLAG_B")
        self.assertEqual(pair["method_verdict"], "ABSTAIN")
        self.assertEqual(pair["admission_verdict"], "ABSTAIN")

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

    def _write_trade(
        self,
        path: Path,
        *,
        entry: dt.datetime,
        exit: dt.datetime,
        symbol: str,
        side: str,
    ) -> None:
        row = {
            "event": "TRADE_CLOSED",
            "entry_time": int(entry.timestamp()),
            "time": int(exit.timestamp()),
            "side": side,
            "symbol": symbol,
            "net": 10.0,
            "volume": 1.0,
            "notional": 10000.0,
        }
        with path.open("w", encoding="utf-8") as fh:
            fh.write(json.dumps(row, sort_keys=True) + "\n")


if __name__ == "__main__":
    unittest.main()
