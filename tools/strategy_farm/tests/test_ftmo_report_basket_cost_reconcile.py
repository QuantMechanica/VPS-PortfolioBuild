from __future__ import annotations

import datetime as dt

import pytest

from tools.strategy_farm.portfolio.ftmo_report_basket_cost_reconcile import recost_trades
from tools.strategy_farm.portfolio.ftmo_report_cost_reconcile import RoundTrip


def trade(symbol: str, profit: float) -> RoundTrip:
    timestamp = dt.datetime(2026, 7, 7, 10, 0)
    return RoundTrip(
        entry_time=timestamp,
        exit_time=timestamp + dt.timedelta(hours=1),
        symbol=symbol,
        side="buy",
        volume=1.0,
        entry_price=1.0,
        exit_price=1.001,
        profit=profit,
        native_swap=0.0,
        native_commission=0.0,
    )


def costs() -> dict:
    return {
        symbol: {
            "commission_percent_per_side": 0.0,
            "flat_round_trip_commission_per_lot": commission,
            "swap_long_points": 0.0,
            "swap_short_points": 0.0,
            "contract_size": 100000.0,
            "source_contract_size": 100000.0,
            "profit_currency_to_account_rate": 1.0,
            "digits": 5,
        }
        for symbol, commission in (("A.DWX", 5.0), ("B.DWX", 7.0))
    }


def test_recosts_each_report_symbol_with_its_own_leg_cost() -> None:
    native, official, _conservative = recost_trades(
        [trade("A.DWX", 100.0), trade("B.DWX", 100.0)],
        costs(),
    )

    assert native == [100.0, 100.0]
    assert [row[1] for row in official] == [5.0, 7.0]
    assert [row[0] for row in official] == [95.0, 93.0]


def test_rejects_report_symbol_without_cost_specification() -> None:
    with pytest.raises(ValueError, match="missing cost specification"):
        recost_trades([trade("C.DWX", 100.0)], costs())
