import dataclasses
import datetime as dt

from tools.strategy_farm.portfolio.ftmo_recover_deterministic_summary import trade_digest
from tools.strategy_farm.portfolio.ftmo_report_cost_reconcile import RoundTrip


def test_trade_digest_is_order_sensitive_and_repeatable() -> None:
    trade_a = RoundTrip(
        entry_time=dt.datetime(2024, 1, 1),
        exit_time=dt.datetime(2024, 1, 2),
        symbol="TEST.DWX",
        side="buy",
        volume=1.0,
        entry_price=100.0,
        exit_price=101.0,
        profit=1.0,
        native_swap=0.0,
        native_commission=0.0,
    )
    trade_b = dataclasses.replace(trade_a, profit=2.0)

    assert trade_digest([trade_a, trade_b]) == trade_digest([trade_a, trade_b])
    assert trade_digest([trade_a, trade_b]) != trade_digest([trade_b, trade_a])
