import datetime as dt
import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.commission import CommissionModel  # noqa: E402
from portfolio.portfolio_montecarlo import build_artifact, write_artifact  # noqa: E402


class PortfolioMonteCarloTests(unittest.TestCase):
    def test_known_drawdown_distribution_is_finite_and_ordered(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            self._write_streams(common_dir, [100.0, 100.0, -300.0, 50.0, -50.0, 200.0])

            artifact = build_artifact(
                common_dir=common_dir,
                all_streams=True,
                runs=200,
                block_days=2,
                seed=7,
                starting_capital=10_000.0,
            )

        max_dd = artifact["block_bootstrap"]["max_drawdown_pct"]
        self.assertGreaterEqual(max_dd["p50"], 0.0)
        self.assertGreaterEqual(max_dd["p95"], max_dd["p50"])
        self.assertGreaterEqual(artifact["observed"]["max_drawdown_pct"], 0.0)

    def test_fixed_seed_writes_identical_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp) / "common"
            out1 = Path(tmp) / "one.json"
            out2 = Path(tmp) / "two.json"
            self._write_streams(common_dir, [40.0, -20.0, 15.0, -60.0, 90.0])

            kwargs = {
                "common_dir": common_dir,
                "all_streams": True,
                "runs": 100,
                "block_days": 3,
                "seed": 11,
                "starting_capital": 10_000.0,
            }
            artifact1 = build_artifact(**kwargs)
            artifact2 = build_artifact(**kwargs)
            write_artifact(artifact1, out1)
            write_artifact(artifact2, out2)

            self.assertEqual(artifact1, artifact2)
            self.assertEqual(
                json.loads(out1.read_text(encoding="utf-8")),
                json.loads(out2.read_text(encoding="utf-8")),
            )

    def _write_streams(self, common_dir: Path, pnl: list[float]) -> None:
        stream_dir = common_dir / "QM" / "q08_trades"
        stream_dir.mkdir(parents=True)
        model = CommissionModel(REPO / "framework" / "registry" / "live_commission.json")
        cost = model.cost_round_trip("EURUSD.DWX", 1.0, 10000.0)
        start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
        with (stream_dir / "100_EURUSD_DWX.jsonl").open("w", encoding="utf-8") as fh:
            for offset, net_of_cost in enumerate(pnl):
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
