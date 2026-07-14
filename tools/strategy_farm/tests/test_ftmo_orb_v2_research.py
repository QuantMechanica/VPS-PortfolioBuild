from __future__ import annotations

import datetime as dt
import unittest

from tools.strategy_farm.portfolio.ftmo_orb_v2_research import (
    OrbTrade,
    closing_entry_side,
    filter_trades,
    summarize,
)


def trade(year: int, weekday_day: int, hour: int, minute: int, net: float) -> OrbTrade:
    entry = dt.datetime(year, 1, weekday_day, hour, minute)
    return OrbTrade(entry, entry + dt.timedelta(hours=1), "buy", 1.0, net, "tp")


class FtmoOrbV2ResearchTests(unittest.TestCase):
    def test_exit_type_matches_opposite_entry_side(self) -> None:
        self.assertEqual(closing_entry_side("sell"), "buy")
        self.assertEqual(closing_entry_side("buy"), "sell")

    def test_cutoff_and_weekday_filter_are_causal_removals(self) -> None:
        rows = [
            trade(2020, 6, 17, 0, 100.0),   # Monday, 30 minutes after open
            trade(2020, 7, 19, 0, -50.0),  # Tuesday, 150 minutes after open
            trade(2021, 8, 17, 30, 25.0),  # Friday, 60 minutes after open
        ]
        kept = filter_trades(
            rows,
            years=frozenset({2020, 2021}),
            entry_cutoff_minutes=60,
            weekdays=frozenset({0, 1, 2, 3}),
        )
        self.assertEqual([row.net for row in kept], [100.0])

    def test_summary_uses_both_positive_and_negative_trades(self) -> None:
        metrics = summarize(
            [
                trade(2020, 6, 17, 0, 100.0),
                trade(2020, 7, 17, 0, -40.0),
                trade(2020, 8, 17, 0, 20.0),
            ]
        )
        self.assertEqual(metrics["net_profit"], 80.0)
        self.assertEqual(metrics["profit_factor"], 3.0)
        self.assertEqual(metrics["close_to_close_max_drawdown"], 40.0)


if __name__ == "__main__":
    unittest.main()
