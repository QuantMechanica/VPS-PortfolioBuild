import datetime as dt
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.commission import CommissionModel  # noqa: E402
from portfolio.portfolio_refit import refit  # noqa: E402


class PortfolioRefitTests(unittest.TestCase):
    def test_refit_retires_now_correlated_sleeve_and_adds_anticorrelated_stream(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = common_dir / "QM" / "q08_trades"
            stream_dir.mkdir(parents=True)
            candidates_db = root / "farm_state.sqlite"
            self._write_candidates(candidates_db, [(100, "EURUSD.DWX"), (101, "EURUSD.DWX")])

            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            cost = self._cost()
            self._write_stream(stream_dir / "100_EURUSD_DWX.jsonl", start, [20.0, -10.0] * 30, cost)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", start, [10.0, -5.0] * 30, cost)
            self._write_stream(stream_dir / "102_EURUSD_DWX.jsonl", start, [-8.0, 18.0] * 30, cost)

            report = refit(
                common_dir,
                candidates_db=candidates_db,
                all_streams=True,
                max_corr=0.30,
                max_dd_pct=6.0,
            )

        self.assertEqual(report["keep"], ["100:EURUSD.DWX"])
        self.assertEqual(report["add"], ["102:EURUSD.DWX"])
        self.assertEqual(len(report["retire"]), 1)
        self.assertEqual(report["retire"][0]["key"], "101:EURUSD.DWX")
        self.assertEqual(report["retire"][0]["reason"], "max-corr-to-rest")
        self.assertEqual(report["retire"][0]["correlated_with"], "100:EURUSD.DWX")
        self.assertIn("sharpe", report["before_kpis"])
        self.assertIn("max_drawdown_pct", report["before_kpis"])
        self.assertIn("sharpe", report["after_kpis"])
        self.assertIn("max_drawdown_pct", report["after_kpis"])
        self.assertTrue(report["advisory_only"])
        self.assertIn("commission_basis", report)
        self.assertIn("degraded", report)

    def _write_candidates(self, path: Path, candidates: list[tuple[int, str]]) -> None:
        conn = sqlite3.connect(path)
        try:
            conn.execute(
                """
                CREATE TABLE portfolio_candidates (
                    ea_id INTEGER NOT NULL,
                    symbol TEXT NOT NULL,
                    state TEXT NOT NULL
                )
                """
            )
            conn.executemany(
                "INSERT INTO portfolio_candidates (ea_id, symbol, state) VALUES (?, ?, ?)",
                [(ea_id, symbol, "Q12_REVIEW_READY") for ea_id, symbol in candidates],
            )
            conn.commit()
        finally:
            conn.close()

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
