from __future__ import annotations

import datetime as dt

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_sleeve_regime_filter_screen as screen
from tools.strategy_farm.portfolio.ftmo_report_cost_reconcile import RoundTrip


def _case() -> dict:
    return {
        "base_risk_fixed": 1000.0,
        "timestamp_basis": "unix_utc",
        "cost": {
            "commission_percent_per_side": 0.0,
            "flat_round_trip_commission_per_lot": 0.0,
            "swap_long_points": 0.0,
            "swap_short_points": 0.0,
            "contract_size": 1.0,
            "source_contract_size": 1.0,
            "profit_currency_to_account_rate": 1.0,
            "digits": 2,
        },
    }


def test_trade_features_use_only_bars_before_entry() -> None:
    index = pd.date_range("2024-01-01T00:00:00Z", periods=120, freq="15min", tz="UTC")
    bars = pd.DataFrame(
        {
            "open": [100.0 + i * 0.01 for i in range(120)],
            "high": [100.1 + i * 0.01 for i in range(120)],
            "low": [99.9 + i * 0.01 for i in range(120)],
            "close": [100.0 + i * 0.01 for i in range(120)],
        },
        index=index,
    )
    trade = RoundTrip(
        entry_time=index[100].to_pydatetime(),
        exit_time=(index[100] + pd.Timedelta(minutes=15)).to_pydatetime(),
        symbol="TEST",
        side="buy",
        volume=1.0,
        entry_price=101.0,
        exit_price=102.0,
        profit=1.0,
        native_swap=0.0,
        native_commission=0.0,
    )
    first = screen.trade_features(_case(), bars, trade)
    bars.loc[index[100]:, ["high", "low", "close"]] = 10000.0
    second = screen.trade_features(_case(), bars, trade)

    assert first is not None and second is not None
    assert first.signed_return_4h == second.signed_return_4h
    assert first.signed_return_24h == second.signed_return_24h
    assert first.volatility_ratio == second.volatility_ratio


def test_long_horizon_features_use_only_pre_entry_bars() -> None:
    index = pd.date_range("2023-01-01T00:00:00Z", periods=1950, freq="15min", tz="UTC")
    bars = pd.DataFrame(
        {
            "open": [100.0 + i * 0.001 for i in range(1950)],
            "high": [100.1 + i * 0.001 for i in range(1950)],
            "low": [99.9 + i * 0.001 for i in range(1950)],
            "close": [100.0 + i * 0.001 for i in range(1950)],
        },
        index=index,
    )
    trade = RoundTrip(
        entry_time=index[1930].to_pydatetime(),
        exit_time=(index[1930] + pd.Timedelta(minutes=15)).to_pydatetime(),
        symbol="TEST",
        side="buy",
        volume=1.0,
        entry_price=101.0,
        exit_price=102.0,
        profit=1.0,
        native_swap=0.0,
        native_commission=0.0,
    )
    first = screen.trade_features(_case(), bars, trade)
    bars.loc[index[1930]:, "close"] = 10000.0
    second = screen.trade_features(_case(), bars, trade)

    assert first is not None and second is not None
    assert first.signed_return_5d == second.signed_return_5d
    assert first.signed_return_20d == second.signed_return_20d


def test_preholdout_score_ignores_holdout() -> None:
    metrics = {
        "development": {"profit_factor": 1.3, "trades": 100},
        "validation_2023": {"profit_factor": 1.1, "trades": 20},
        "holdout_2024_2025": {"profit_factor": 99.0, "trades": 40},
    }

    assert screen.preholdout_score(metrics) == 1.1
