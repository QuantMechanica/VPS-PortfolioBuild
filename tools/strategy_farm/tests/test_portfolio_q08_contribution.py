import datetime as dt
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.commission import CommissionModel  # noqa: E402
from portfolio.portfolio_common import Trade  # noqa: E402
from portfolio import portfolio_q08_contribution  # noqa: E402
from portfolio.portfolio_q08_contribution import (  # noqa: E402
    equity_curve,
    evaluate_q08_soft_rescue,
    monthly_returns,
)


class PortfolioQ08ContributionTests(unittest.TestCase):
    def test_default_starting_capital_matches_canonical_tester_deposit(self) -> None:
        self.assertEqual(portfolio_q08_contribution.DEFAULT_STARTING_CAPITAL, 100_000.0)

    def test_monthly_returns_and_equity_curve_are_chronological(self) -> None:
        trades = [
            Trade(100, "EURUSD.DWX", self._ts(2024, 2, 1), 0.0, 1.0, 10000.0, 0.0, 3.25),
            Trade(100, "EURUSD.DWX", self._ts(2024, 1, 2), 0.0, 1.0, 10000.0, 0.0, 10.0),
            Trade(100, "EURUSD.DWX", self._ts(2024, 1, 5), 0.0, 1.0, 10000.0, 0.0, -4.5),
        ]

        self.assertEqual(monthly_returns(trades), {"2024-01": 5.5, "2024-02": 3.25})
        self.assertEqual(
            equity_curve(trades),
            [
                {"time": self._ts(2024, 1, 2), "equity": 10.0, "net_of_cost": 10.0},
                {"time": self._ts(2024, 1, 5), "equity": 5.5, "net_of_cost": -4.5},
                {"time": self._ts(2024, 2, 1), "equity": 8.75, "net_of_cost": 3.25},
            ],
        )

    def test_need_more_data_when_candidate_trade_count_below_minimum(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp) / "common"
            stream_dir = self._stream_dir(common_dir)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 19)

            verdict = evaluate_q08_soft_rescue(
                (101, "EURUSD.DWX"),
                common_dir=common_dir,
                candidates_db=Path(tmp) / "missing.sqlite",
            )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertEqual(verdict["reason"], "portfolio_trade_count_below_min")
        self.assertEqual(verdict["trade_count"], 19)

    def test_regime_catastrophe_defers_to_portfolio_admission(self) -> None:
        # DL-078 (OWNER-ratified 2026-06-27): a standalone Q08 8.10 regime catastrophe no
        # longer hard-rejects. It is recorded for audit but the verdict defers to
        # portfolio_admission -- the anticorrelation book is meant to ABSORB regime
        # dependence (DL-075). A regime-fragile sleeve that improves the book is admitted.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            candidates_db = root / "candidates.sqlite"
            summary = root / "q08_summary.json"
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 30)
            self._write_candidates(candidates_db, [("QM5_100", "EURUSD.DWX"), ("QM5_101", "EURUSD.DWX")])
            summary.write_text(
                json.dumps(
                    {
                        "sub_gates": [
                            {
                                "name": "8.10 Regime",
                                "detail": "unprofitable_regimes=London,NY",
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={
                    "admit": True,
                    "reason": "portfolio_contribution_pass",
                    "max_corr_to_book": 0.2,
                    "maxdd_with": 0.04,
                    "maxdd_without": 0.06,
                },
            ) as admission:
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=candidates_db,
                    q08_summary_path=summary,
                )

        self.assertEqual(verdict["verdict"], "PASS_PORTFOLIO")
        self.assertTrue(verdict["q08_regime_catastrophe"])
        self.assertTrue(verdict["regime_catastrophe_absorbed_by_book"])
        admission.assert_called_once()

    def test_regime_catastrophe_still_fails_when_book_not_improved(self) -> None:
        # The override is not a free pass: a regime-fragile sleeve that does NOT improve the
        # book still FAILs at the admission check (DL-078 defers, it does not waive).
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            summary = root / "q08_summary.json"
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 30)
            summary.write_text(
                json.dumps({"sub_gates": [{"name": "8.10 Regime", "detail": "unprofitable_regimes=NY"}]}),
                encoding="utf-8",
            )
            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={"admit": False, "reason": "no_diversification"},
            ):
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=root / "missing.sqlite",
                    q08_summary_path=summary,
                )

        self.assertEqual(verdict["verdict"], "FAIL_PORTFOLIO")
        self.assertEqual(verdict["reason"], "no_diversification")
        self.assertTrue(verdict["q08_regime_catastrophe"])

    def test_pass_portfolio_delegates_to_portfolio_admission(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            candidates_db = root / "candidates.sqlite"
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 30)
            self._write_candidates(candidates_db, [("QM5_100", "EURUSD.DWX"), ("QM5_101", "EURUSD.DWX")])

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={
                    "admit": True,
                    "reason": "portfolio_contribution_pass",
                    "max_corr_to_book": 0.2,
                    "sharpe_with": 1.1,
                    "sharpe_without": 0.9,
                },
            ) as admission:
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=candidates_db,
                )

        self.assertEqual(verdict["verdict"], "PASS_PORTFOLIO")
        self.assertEqual(verdict["reason"], "portfolio_contribution_pass")
        admission.assert_called_once_with(
            (101, "EURUSD.DWX"),
            [(100, "EURUSD.DWX")],
            common_dir,
            max_corr=0.30,
            starting_capital=100_000.0,
        )

    def test_fail_portfolio_delegates_to_portfolio_admission(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 30)

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={"admit": False, "reason": "correlation_above_max_corr"},
            ):
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=root / "missing.sqlite",
                )

        self.assertEqual(verdict["verdict"], "FAIL_PORTFOLIO")
        self.assertEqual(verdict["reason"], "correlation_above_max_corr")

    def test_insufficient_overlap_is_need_more_data_not_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 30)

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={
                    "admit": False,
                    "reason": "insufficient_overlap",
                    "diversifies": True,
                    "sharpe_with": 1.1,
                    "sharpe_without": 0.9,
                },
            ):
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=root / "missing.sqlite",
                )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertEqual(verdict["reason"], "portfolio_correlation_overlap_below_min")
        self.assertEqual(verdict["previous_verdict"], "FAIL_PORTFOLIO")
        self.assertTrue(verdict["sparse_overlap_watchlist"])

    def test_missing_book_streams_are_need_more_data_not_runner_crash(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            candidates_db = root / "candidates.sqlite"
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 30)
            self._write_candidates(candidates_db, [("QM5_100", "EURUSD.DWX")])

            verdict = evaluate_q08_soft_rescue(
                (101, "EURUSD.DWX"),
                common_dir=common_dir,
                candidates_db=candidates_db,
            )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertEqual(verdict["reason"], "portfolio_admission_missing_streams")
        self.assertIn("missing q08 trade streams", verdict["admission_error"])

    def _ts(self, year: int, month: int, day: int) -> int:
        return int(dt.datetime(year, month, day, tzinfo=dt.UTC).timestamp())

    def _stream_dir(self, common_dir: Path) -> Path:
        stream_dir = common_dir / "QM" / "q08_trades"
        stream_dir.mkdir(parents=True)
        return stream_dir

    def _write_stream(self, path: Path, desired_net: list[float]) -> None:
        cost = CommissionModel(REPO / "framework" / "registry" / "live_commission.json").cost_round_trip(
            "EURUSD.DWX",
            1.0,
            10000.0,
        )
        start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
        with path.open("w", encoding="utf-8") as fh:
            for offset, net_of_cost in enumerate(desired_net):
                row = {
                    "event": "TRADE_CLOSED",
                    "symbol": "EURUSD.DWX",
                    "time": int((start + dt.timedelta(days=offset)).timestamp()),
                    "net": net_of_cost + cost,
                    "volume": 1.0,
                    "notional": 10000.0,
                }
                fh.write(json.dumps(row, sort_keys=True) + "\n")

    def _write_candidates(self, db_path: Path, rows: list[tuple[str, str]]) -> None:
        conn = sqlite3.connect(db_path)
        try:
            conn.execute("CREATE TABLE portfolio_candidates (ea_id TEXT, symbol TEXT, state TEXT)")
            conn.executemany(
                "INSERT INTO portfolio_candidates (ea_id, symbol, state) VALUES (?, ?, 'Q12_REVIEW_READY')",
                rows,
            )
            conn.commit()
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
