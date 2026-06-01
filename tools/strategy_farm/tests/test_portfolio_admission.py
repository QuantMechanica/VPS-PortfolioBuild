import datetime as dt
import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.commission import CommissionModel  # noqa: E402
from portfolio.portfolio_admission import evaluate_candidate  # noqa: E402


class PortfolioAdmissionTests(unittest.TestCase):
    def test_empty_book_admits_first_sleeve(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            verdict = evaluate_candidate((100, "EURUSD.DWX"), [], Path(tmp))

        self.assertTrue(verdict["admit"])
        self.assertEqual(verdict["reason"], "first_sleeve")

    def test_anticorrelated_candidate_with_low_pf_admits_when_portfolio_improves(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = self._stream_dir(common_dir)
            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            cost = self._cost()

            self._write_stream(stream_dir / "100_EURUSD_DWX.jsonl", start, [100.0, -80.0] * 30, cost)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", start, [-70.0, 60.0] * 30, cost)

            verdict = evaluate_candidate(
                (101, "EURUSD.DWX"),
                [(100, "EURUSD.DWX")],
                common_dir,
            )

        self.assertTrue(verdict["admit"])
        self.assertLess(verdict["standalone_pf"], 1.0)
        self.assertLessEqual(verdict["max_corr_to_book"], 0.30)
        self.assertGreater(verdict["sharpe_with"], verdict["sharpe_without"])

    def test_highly_correlated_candidate_is_rejected_regardless_of_pf(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = self._stream_dir(common_dir)
            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            cost = self._cost()

            self._write_stream(stream_dir / "100_EURUSD_DWX.jsonl", start, [10.0, -5.0] * 30, cost)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", start, [20.0, -10.0] * 30, cost)

            verdict = evaluate_candidate(
                (101, "EURUSD.DWX"),
                [(100, "EURUSD.DWX")],
                common_dir,
            )

        self.assertFalse(verdict["admit"])
        self.assertEqual(verdict["reason"], "correlation_above_max_corr")
        self.assertGreater(verdict["max_corr_to_book"], 0.30)

    def test_candidate_without_portfolio_improvement_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = self._stream_dir(common_dir)
            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            cost = self._cost()

            self._write_stream(stream_dir / "100_EURUSD_DWX.jsonl", start, [20.0, 10.0] * 30, cost)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", start, [-40.0, -10.0] * 30, cost)

            verdict = evaluate_candidate(
                (101, "EURUSD.DWX"),
                [(100, "EURUSD.DWX")],
                common_dir,
            )

        self.assertFalse(verdict["admit"])
        self.assertEqual(verdict["reason"], "no_diversification")
        self.assertFalse(verdict["diversifies"])

    def test_insufficient_overlap_is_not_proven_uncorrelated(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = self._stream_dir(common_dir)
            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            cost = self._cost()

            self._write_stream(stream_dir / "100_EURUSD_DWX.jsonl", start, [10.0, -5.0] * 30, cost)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", start, [-10.0, 5.0] * 5, cost)

            verdict = evaluate_candidate(
                (101, "EURUSD.DWX"),
                [(100, "EURUSD.DWX")],
                common_dir,
            )

        self.assertFalse(verdict["admit"])
        self.assertTrue(verdict["corr_insufficient"])
        self.assertEqual(verdict["reason"], "insufficient_overlap")

    def _stream_dir(self, common_dir: Path) -> Path:
        stream_dir = common_dir / "QM" / "q08_trades"
        stream_dir.mkdir(parents=True)
        return stream_dir

    def _cost(self) -> float:
        model = CommissionModel(REPO / "framework" / "registry" / "live_commission.json")
        return model.cost_round_trip("EURUSD.DWX", 1.0, 10000.0)

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
