from __future__ import annotations

import datetime as dt
import unittest

from tools.strategy_farm.portfolio.ftmo_report_cost_reconcile import (
    RoundTrip,
    _consume_exit_deal,
    ftmo_trade_net,
    report_period_years,
    summarize_nets,
    swap_rollover_units,
)


class FtmoReportCostReconcileTests(unittest.TestCase):
    def test_wednesday_rollover_is_triple(self) -> None:
        entry = dt.datetime(2026, 7, 8, 23, 0)
        exit_ = dt.datetime(2026, 7, 9, 16, 0)
        self.assertEqual(swap_rollover_units(entry, exit_), 3)

    def test_long_weekend_counts_weekdays_only(self) -> None:
        entry = dt.datetime(2026, 7, 9, 23, 0)
        exit_ = dt.datetime(2026, 7, 13, 16, 0)
        self.assertEqual(swap_rollover_units(entry, exit_), 2)

    def test_official_xau_cost_is_applied_per_side_and_per_rollover(self) -> None:
        trade = RoundTrip(
            entry_time=dt.datetime(2026, 7, 8, 23, 0),
            exit_time=dt.datetime(2026, 7, 9, 16, 0),
            symbol="XAUUSD.DWX",
            side="buy",
            volume=0.5,
            entry_price=2000.0,
            exit_price=2010.0,
            profit=500.0,
            native_swap=0.0,
            native_commission=0.0,
        )
        net, commission, swap, units = ftmo_trade_net(
            trade,
            commission_rate_per_side=0.0014 / 100.0,
            swap_long_points=-75.93,
            swap_short_points=-23.55,
            contract_size=100.0,
            digits=2,
        )
        self.assertEqual(units, 3)
        self.assertAlmostEqual(commission, 2.807, places=6)
        self.assertAlmostEqual(swap, -113.895, places=6)
        self.assertAlmostEqual(net, 383.298, places=6)

    def test_same_timestamp_round_trip_has_no_swap(self) -> None:
        timestamp = dt.datetime(2026, 7, 8, 12, 0, tzinfo=dt.UTC)

        self.assertEqual(swap_rollover_units(timestamp, timestamp), 0)

    def test_partial_exits_are_emitted_as_report_counted_fragments(self) -> None:
        entry_time = dt.datetime(2026, 7, 8, 10, 0, tzinfo=dt.UTC)
        queue = [
            {
                "time": entry_time,
                "symbol": "SP500.DWX",
                "side": "buy",
                "volume": 2.0,
                "remaining_volume": 2.0,
                "price": 5000.0,
                "profit": 0.0,
                "swap": 0.0,
                "commission": -2.0,
            }
        ]
        first = _consume_exit_deal(
            queue,
            {
                "time": entry_time + dt.timedelta(hours=1),
                "volume": 0.5,
                "price": 5010.0,
                "profit": 5.0,
                "swap": -0.5,
                "commission": -0.5,
            },
        )
        second = _consume_exit_deal(
            queue,
            {
                "time": entry_time + dt.timedelta(hours=2),
                "volume": 1.5,
                "price": 5020.0,
                "profit": 30.0,
                "swap": -1.5,
                "commission": -1.5,
            },
        )

        self.assertEqual(len(first), 1)
        self.assertEqual(len(second), 1)
        self.assertEqual(queue, [])
        self.assertEqual(first[0].volume, 0.5)
        self.assertEqual(second[0].volume, 1.5)
        self.assertAlmostEqual(first[0].exit_price, 5010.0)
        self.assertAlmostEqual(second[0].exit_price, 5020.0)
        self.assertAlmostEqual(first[0].profit + second[0].profit, 35.0)
        self.assertAlmostEqual(first[0].native_swap + second[0].native_swap, -2.0)
        self.assertAlmostEqual(
            first[0].native_commission + second[0].native_commission,
            -4.0,
        )

    def test_profit_factor_and_close_drawdown(self) -> None:
        metrics = summarize_nets([100.0, -50.0, 25.0, -100.0])
        self.assertEqual(metrics["trades"], 4)
        self.assertEqual(metrics["net_profit"], -25.0)
        self.assertEqual(metrics["profit_factor"], 0.833333)
        self.assertEqual(metrics["close_to_close_max_drawdown"], 125.0)

    def test_dax_source_contract_and_eur_conversion_are_normalized(self) -> None:
        trade = RoundTrip(
            entry_time=dt.datetime(2026, 7, 7, 23, 0),
            exit_time=dt.datetime(2026, 7, 8, 10, 0),
            symbol="GDAXI.DWX",
            side="buy",
            volume=2.0,
            entry_price=100.0,
            exit_price=101.0,
            profit=22.0,
            native_swap=0.0,
            native_commission=0.0,
        )
        net, commission, swap, units = ftmo_trade_net(
            trade,
            commission_rate_per_side=0.0,
            swap_long_points=-100.0,
            swap_short_points=-10.0,
            source_contract_size=10.0,
            contract_size=1.0,
            derive_profit_currency_rate_from_pnl=True,
            digits=2,
        )
        self.assertEqual(units, 1)
        self.assertEqual(commission, 0.0)
        self.assertAlmostEqual(swap, -22.0, places=6)
        self.assertAlmostEqual(net, 0.0, places=6)

    def test_report_period_years_includes_zero_trade_years(self) -> None:
        self.assertEqual(
            report_period_years("H1 (2017.01.01 - 2020.12.31)"),
            {2017, 2018, 2019, 2020},
        )

    def test_flat_round_trip_commission_uses_equivalent_target_lots(self) -> None:
        trade = RoundTrip(
            entry_time=dt.datetime(2026, 7, 7, 10, 0),
            exit_time=dt.datetime(2026, 7, 7, 11, 0),
            symbol="USDJPY.DWX",
            side="buy",
            volume=2.0,
            entry_price=150.0,
            exit_price=150.1,
            profit=133.333333,
            native_swap=0.0,
            native_commission=0.0,
        )
        net, commission, swap, units = ftmo_trade_net(
            trade,
            commission_rate_per_side=0.0,
            flat_round_trip_commission_per_lot=5.0,
            swap_long_points=2.62,
            swap_short_points=-22.41,
            contract_size=100000.0,
            digits=3,
        )
        self.assertEqual(units, 0)
        self.assertEqual(swap, 0.0)
        self.assertEqual(commission, 10.0)
        self.assertAlmostEqual(net, 123.333333, places=6)


if __name__ == "__main__":
    unittest.main()
