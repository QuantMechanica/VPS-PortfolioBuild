import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.commission import CommissionModel  # noqa: E402
from portfolio.portfolio_common import load_streams  # noqa: E402


class PortfolioCommonTests(unittest.TestCase):
    def test_trade_stream_parses_intraday_adverse_fields_and_legacy_rows(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = common_dir / "QM" / "q08_trades"
            stream_dir.mkdir(parents=True)
            stream_path = stream_dir / "100_EURUSD_DWX.jsonl"

            rows = [
                {
                    "event": "TRADE_CLOSED",
                    "symbol": "EURUSD.DWX",
                    "time": 1_704_153_600,
                    "entry_time": 1_704_150_000,
                    "mae_acct": -123.45,
                    "net": 250.0,
                    "profit": 250.0,
                    "swap": 0.0,
                    "commission": 0.0,
                    "volume": 1.0,
                    "notional": 10000.0,
                },
                {
                    "event": "TRADE_CLOSED",
                    "symbol": "EURUSD.DWX",
                    "time": 1_704_240_000,
                    "net": -50.0,
                    "profit": -50.0,
                    "swap": 0.0,
                    "commission": 0.0,
                    "volume": 1.0,
                    "notional": 10000.0,
                },
            ]
            with stream_path.open("w", encoding="utf-8") as fh:
                for row in rows:
                    fh.write(json.dumps(row, sort_keys=True) + "\n")

            model = CommissionModel(REPO / "framework" / "registry" / "live_commission.json")
            streams = load_streams(common_dir, commission_model=model)

        trades = streams[(100, "EURUSD.DWX")]
        self.assertEqual(len(trades), 2)
        self.assertEqual(trades[0].entry_time, 1_704_150_000)
        self.assertEqual(trades[0].mae_acct, -123.45)
        self.assertIsNone(trades[1].entry_time)
        self.assertIsNone(trades[1].mae_acct)


if __name__ == "__main__":
    unittest.main()
