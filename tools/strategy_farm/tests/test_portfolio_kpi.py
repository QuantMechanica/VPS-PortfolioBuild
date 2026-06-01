import datetime as dt
import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.commission import CommissionModel  # noqa: E402
from portfolio.portfolio_assemble import greedy_select  # noqa: E402
from portfolio.portfolio_kpi import (  # noqa: E402
    equal_weights,
    metrics_from_daily_pnl,
    portfolio_equity,
)


class PortfolioKpiTests(unittest.TestCase):
    def test_anticorrelated_sleeves_reduce_combined_drawdown_and_equal_weight_mean(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = common_dir / "QM" / "q08_trades"
            stream_dir.mkdir(parents=True)

            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            model = CommissionModel(REPO / "framework" / "registry" / "live_commission.json")
            cost = model.cost_round_trip("EURUSD.DWX", 1.0, 10000.0)
            left_daily = [100.0, -400.0, 100.0, 100.0]
            right_daily = [-100.0, 400.0, -100.0, -100.0]
            self._write_stream(stream_dir / "100_EURUSD_DWX.jsonl", start, left_daily, cost)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", start, right_daily, cost)

            keys = [(100, "EURUSD.DWX"), (101, "EURUSD.DWX")]
            dates, combined_equity = portfolio_equity(keys, equal_weights(keys), common_dir)

        left_equity = self._cumulative_sum(left_daily)
        right_equity = self._cumulative_sum(right_daily)
        expected_mean = [(left + right) / 2.0 for left, right in zip(left_equity, right_equity)]
        self.assertEqual(len(dates), 4)
        self.assertEqual(combined_equity, expected_mean)

        left_metrics = metrics_from_daily_pnl(left_daily, n_sleeves=1)
        right_metrics = metrics_from_daily_pnl(right_daily, n_sleeves=1)
        combined_metrics = metrics_from_daily_pnl(
            [(left + right) / 2.0 for left, right in zip(left_daily, right_daily)],
            n_sleeves=2,
        )
        self.assertLess(combined_metrics["max_drawdown_pct"], left_metrics["max_drawdown_pct"])
        self.assertLess(combined_metrics["max_drawdown_pct"], right_metrics["max_drawdown_pct"])

    def test_zero_variance_and_single_day_sharpe_are_none(self) -> None:
        zero_variance = metrics_from_daily_pnl([10.0, 10.0, 10.0], n_sleeves=1)
        single_day = metrics_from_daily_pnl([10.0], n_sleeves=1)

        self.assertIsNone(zero_variance["sharpe"])
        self.assertIsNone(single_day["sharpe"])
        self.assertEqual(single_day["n_days"], 1)

    def test_assembler_respects_max_drawdown_constraint(self) -> None:
        keys = [(100, "EURUSD.DWX"), (101, "EURUSD.DWX"), (102, "EURUSD.DWX")]
        matrix = [
            [100.0, 50.0, 80.0],
            [-1_000.0, -10.0, -20.0],
            [1_000.0, 60.0, 90.0],
        ]

        selected, _, metrics = greedy_select(keys, matrix, max_dd_pct=1.0)

        self.assertNotIn((100, "EURUSD.DWX"), selected)
        self.assertLessEqual(metrics["max_drawdown_pct"], 1.0)

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

    def _cumulative_sum(self, values: list[float]) -> list[float]:
        total = 0.0
        output: list[float] = []
        for value in values:
            total += value
            output.append(total)
        return output


if __name__ == "__main__":
    unittest.main()
