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
from portfolio.portfolio_kpi import equal_weights, portfolio_metrics  # noqa: E402


class PortfolioAdmissionTests(unittest.TestCase):
    def test_empty_book_admits_first_sleeve(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            verdict = evaluate_candidate((100, "EURUSD.DWX"), [], Path(tmp))

        self.assertTrue(verdict["admit"])
        self.assertEqual(verdict["reason"], "first_sleeve")

    def test_ea_id_label_normalizes_to_int_not_prefix_digit(self) -> None:
        # portfolio_candidates.ea_id stores 'QM5_10692'; the key must be 10692, NOT the
        # '5' in the 'QM5' prefix (regression for the F1 read_candidates int() crash).
        from portfolio.portfolio_common import _coerce_ea_int
        self.assertEqual(_coerce_ea_int("QM5_10692"), 10692)
        self.assertEqual(_coerce_ea_int("QM5_5"), 5)
        self.assertEqual(_coerce_ea_int(10692), 10692)
        self.assertIsNone(_coerce_ea_int("not-an-ea"))

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

            # Candidate is net-LOSING and uncorrelated to the book (its even/odd-day means
            # are equal, so zero period-2 correlation). Under risk-parity it can't help:
            # it drags Sharpe down and adds its own drawdown, with no anti-correlation to
            # smooth the book. (A net-negative ANTI-correlated sleeve would legitimately
            # diversify under risk-parity by smoothing — so that is not a no-diversification
            # case once the diversifies test uses the book's real risk-parity weighting.)
            self._write_stream(stream_dir / "100_EURUSD_DWX.jsonl", start, [20.0, 10.0] * 30, cost)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", start, [-30.0, -20.0, -10.0, -20.0] * 15, cost)

            verdict = evaluate_candidate(
                (101, "EURUSD.DWX"),
                [(100, "EURUSD.DWX")],
                common_dir,
            )

        self.assertFalse(verdict["admit"])
        self.assertEqual(verdict["reason"], "no_diversification")
        self.assertFalse(verdict["diversifies"])

    def test_risk_parity_admits_dense_diversifier_that_equal_weight_rejects(self) -> None:
        # Regression for the diversifies-weighting fix. The candidate is a high-volatility,
        # uncorrelated, net-positive sleeve (like a dense index EA next to sparse low-freq
        # sleeves). Under EQUAL weight its big swings dominate the daily variance so it looks
        # non-diversifying; under risk-parity (inverse-vol — how the book is actually built)
        # it is down-weighted and reduces the book's drawdown, so it is admitted.
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = self._stream_dir(common_dir)
            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            cost = self._cost()

            book = [(100, "EURUSD.DWX")]
            with_book = [(100, "EURUSD.DWX"), (101, "EURUSD.DWX")]
            self._write_stream(stream_dir / "100_EURUSD_DWX.jsonl", start, [12.0, -9.0] * 30, cost)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", start, [80.0, -50.0, -20.0] * 20, cost)

            # Equal-weight would NOT have diversified (the old behaviour) ...
            ew_without = portfolio_metrics(book, equal_weights(book), common_dir)
            ew_with = portfolio_metrics(with_book, equal_weights(with_book), common_dir)
            ew_diversifies = (ew_with["sharpe"] > ew_without["sharpe"]) or (
                ew_with["max_drawdown_pct"] < ew_without["max_drawdown_pct"]
            )
            self.assertFalse(ew_diversifies)

            # ... but the gate (now risk-parity weighted) admits it.
            verdict = evaluate_candidate((101, "EURUSD.DWX"), book, common_dir)

        self.assertTrue(verdict["admit"])
        self.assertEqual(verdict["reason"], "admitted")
        self.assertLessEqual(verdict["max_corr_to_book"], 0.30)
        self.assertTrue(verdict["diversifies"])

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

    def test_monthly_fallback_admits_sparse_uncorrelated_low_freq(self) -> None:
        # Two structural low-freq sleeves trade once a month on DIFFERENT days, so they
        # never share a daily bar (daily overlap = 0 -> the daily gate alone would reject
        # them as insufficient_overlap). On a monthly basis they are anti-correlated and
        # the book improves -> the fallback must admit them.
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = self._stream_dir(common_dir)
            start = dt.datetime(2022, 1, 1, tzinfo=dt.UTC)
            cost = self._cost()

            # book sleeve drops -40 every odd month; candidate makes +120 in exactly those
            # months (and only +20 in the others) -> anti-correlated monthly and fills the
            # book's drawdowns, so the combined book is both higher-Sharpe and lower-DD.
            self._write_monthly_stream(stream_dir / "100_EURUSD_DWX.jsonl", start, [100.0, -40.0] * 12, 1, cost)
            self._write_monthly_stream(stream_dir / "101_EURUSD_DWX.jsonl", start, [20.0, 120.0] * 12, 15, cost)

            verdict = evaluate_candidate((101, "EURUSD.DWX"), [(100, "EURUSD.DWX")], common_dir)

        self.assertEqual(verdict["corr_basis"], "monthly")
        self.assertFalse(verdict["corr_insufficient"])
        self.assertLessEqual(verdict["max_corr_to_book"], 0.30)
        self.assertTrue(verdict["admit"])
        self.assertEqual(verdict["reason"], "admitted")

    def test_monthly_fallback_rejects_sparse_correlated_low_freq(self) -> None:
        # Same sparsity, but the two sleeves move in phase monthly. The daily gate would
        # have mislabelled them insufficient_overlap (and parked them on the watchlist);
        # the monthly fallback correctly catches the correlation and rejects.
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = self._stream_dir(common_dir)
            start = dt.datetime(2022, 1, 1, tzinfo=dt.UTC)
            cost = self._cost()

            self._write_monthly_stream(stream_dir / "100_EURUSD_DWX.jsonl", start, [100.0, -40.0] * 12, 1, cost)
            self._write_monthly_stream(stream_dir / "101_EURUSD_DWX.jsonl", start, [200.0, -80.0] * 12, 15, cost)

            verdict = evaluate_candidate((101, "EURUSD.DWX"), [(100, "EURUSD.DWX")], common_dir)

        self.assertEqual(verdict["corr_basis"], "monthly")
        self.assertFalse(verdict["corr_insufficient"])
        self.assertGreater(verdict["max_corr_to_book"], 0.30)
        self.assertFalse(verdict["admit"])
        self.assertEqual(verdict["reason"], "correlation_above_max_corr")

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

    def _write_monthly_stream(
        self,
        path: Path,
        start: dt.datetime,
        monthly_pnl: list[float],
        day_of_month: int,
        cost: float,
    ) -> None:
        with path.open("w", encoding="utf-8") as fh:
            for index, net_of_cost in enumerate(monthly_pnl):
                year = start.year + (start.month - 1 + index) // 12
                month = (start.month - 1 + index) % 12 + 1
                stamp = dt.datetime(year, month, day_of_month, tzinfo=dt.UTC)
                row = {
                    "event": "TRADE_CLOSED",
                    "time": int(stamp.timestamp()),
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
