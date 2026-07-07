import json
import os
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio import portfolio_common  # noqa: E402
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


class BasketStreamAliasTests(unittest.TestCase):
    """Regression tests required by review b4e2a62b (2026-07-07).

    Basket EAs carry a logical composite work-item symbol; their q08 stream
    file may be keyed by HOST symbol (volatile Common) or by the logical name
    (durable store). load_streams() must hand trades back under the ORIGINAL
    candidate key, and when both files exist the NEWER one must win.
    """

    EA = 777
    LOGICAL_SYM = f"QM5_{EA}_AUDUSD_EURJPY_COINTEGRATION_D1"
    HOST_SYM = "AUDUSD.DWX"

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.common_dir = Path(self._tmp.name) / "common"
        self.stream_dir = self.common_dir / "QM" / "q08_trades"
        self.stream_dir.mkdir(parents=True)
        # Fake repo EAs dir carrying the '; host_symbol:' setfile header.
        self.eas_dir = Path(self._tmp.name) / "EAs"
        sets_dir = self.eas_dir / f"QM5_{self.EA}_test-basket" / "sets"
        sets_dir.mkdir(parents=True)
        (sets_dir / f"QM5_{self.EA}_test-basket_D1_backtest.set").write_text(
            f"; host_symbol: {self.HOST_SYM}\nRiskFixed=1000\n", encoding="utf-8"
        )
        self._old_repo_eas = portfolio_common.REPO_EAS
        portfolio_common.REPO_EAS = self.eas_dir
        self.model = CommissionModel(REPO / "framework" / "registry" / "live_commission.json")

    def tearDown(self) -> None:
        portfolio_common.REPO_EAS = self._old_repo_eas
        self._tmp.cleanup()

    def _write_stream(self, filename: str, net: float, mtime: float | None = None) -> Path:
        path = self.stream_dir / filename
        row = {
            "event": "TRADE_CLOSED",
            "symbol": self.HOST_SYM,
            "time": 1_704_153_600,
            "net": net,
            "profit": net,
            "swap": 0.0,
            "commission": 0.0,
            "volume": 1.0,
            "notional": 10000.0,
        }
        path.write_text(json.dumps(row, sort_keys=True) + "\n", encoding="utf-8")
        if mtime is not None:
            os.utime(path, (mtime, mtime))
        return path

    @property
    def _candidate(self) -> tuple[int, str]:
        return (self.EA, self.LOGICAL_SYM)

    def test_host_file_returned_under_original_logical_key(self) -> None:
        self._write_stream(f"{self.EA}_AUDUSD_DWX.jsonl", net=111.0)
        streams = load_streams(self.common_dir, candidates=[self._candidate], commission_model=self.model)
        self.assertEqual(list(streams), [self._candidate])
        self.assertEqual(len(streams[self._candidate]), 1)
        self.assertAlmostEqual(streams[self._candidate][0].net, 111.0, places=6)

    def test_non_basket_candidates_unchanged(self) -> None:
        resolved, note = portfolio_common.resolve_basket_stream_key(
            (100, "EURUSD.DWX"), self.common_dir
        )
        self.assertIsNone(resolved)
        self.assertIsNone(note)
        path = self.stream_dir / "100_EURUSD_DWX.jsonl"
        row = {
            "event": "TRADE_CLOSED", "symbol": "EURUSD.DWX", "time": 1_704_153_600,
            "net": 50.0, "profit": 50.0, "swap": 0.0, "commission": 0.0,
            "volume": 1.0, "notional": 10000.0,
        }
        path.write_text(json.dumps(row, sort_keys=True) + "\n", encoding="utf-8")
        streams = load_streams(
            self.common_dir, candidates=[(100, "EURUSD.DWX")], commission_model=self.model
        )
        self.assertEqual(list(streams), [(100, "EURUSD.DWX")])

    def test_logical_file_newer_than_host_wins(self) -> None:
        self._write_stream(f"{self.EA}_AUDUSD_DWX.jsonl", net=111.0, mtime=1_000_000)
        self._write_stream(
            f"{self.EA}_{self.LOGICAL_SYM}.jsonl", net=222.0, mtime=2_000_000
        )
        streams = load_streams(self.common_dir, candidates=[self._candidate], commission_model=self.model)
        self.assertEqual(list(streams), [self._candidate])
        self.assertEqual(len(streams[self._candidate]), 1)
        self.assertAlmostEqual(streams[self._candidate][0].net, 222.0, places=6)

    def test_host_file_newer_than_logical_wins(self) -> None:
        self._write_stream(f"{self.EA}_AUDUSD_DWX.jsonl", net=111.0, mtime=2_000_000)
        self._write_stream(
            f"{self.EA}_{self.LOGICAL_SYM}.jsonl", net=222.0, mtime=1_000_000
        )
        streams = load_streams(self.common_dir, candidates=[self._candidate], commission_model=self.model)
        self.assertEqual(list(streams), [self._candidate])
        self.assertEqual(len(streams[self._candidate]), 1)
        self.assertAlmostEqual(streams[self._candidate][0].net, 111.0, places=6)


if __name__ == "__main__":
    unittest.main()
