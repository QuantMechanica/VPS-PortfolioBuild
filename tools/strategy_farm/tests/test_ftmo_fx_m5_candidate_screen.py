from __future__ import annotations

import datetime as dt

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_fx_m5_candidate_screen as screen


def test_simulate_trade_uses_stop_first_and_deducts_cost() -> None:
    utc = pd.to_datetime(
        ["2024-01-02T08:00:00Z", "2024-01-02T08:05:00Z"], utc=True
    )
    frame = pd.DataFrame(
        {
            "open": [100.0, 100.0],
            "high": [102.0, 100.5],
            "low": [98.0, 99.5],
            "close": [100.0, 100.0],
            "utc": utc,
            "local_date": [dt.date(2024, 1, 2), dt.date(2024, 1, 2)],
            "year": [2024, 2024],
        }
    )

    trade = screen.simulate_trade(
        frame,
        entry_index=0,
        side=1,
        stop_distance=1.0,
        target_r=1.0,
        last_index=1,
        round_trip_cost_points=0.1,
    )

    assert trade is not None
    assert trade.exit_reason == "stop_pessimistic"
    assert trade.r_multiple == -1.1
    assert trade.mae_r == -2.1


def test_preholdout_gate_does_not_consult_holdout() -> None:
    metrics = {
        "dev_2018_2022": {"trades": 600, "profit_factor": 1.2},
        "validation_2023": {
            "trades": 100,
            "profit_factor": 1.1,
            "net_r": 2.0,
        },
        "annual": {
            "2018": {"net_r": 1.0},
            "2019": {"net_r": 1.0},
            "2020": {"net_r": 1.0},
            "2021": {"net_r": -1.0},
            "2022": {"net_r": -1.0},
        },
    }

    assert screen.preholdout_pass(metrics)


def test_sealed_holdout_is_calculated_separately() -> None:
    trades = [
        screen.Trade("", "", "2023-01-01", 2023, 1, 99.0, -1.0, "time"),
        screen.Trade("", "", "2024-01-01", 2024, 1, 1.0, -1.0, "time"),
        screen.Trade("", "", "2025-01-01", 2025, 1, -0.5, -1.0, "time"),
    ]

    metrics = screen.sealed_holdout_metrics(trades)

    assert metrics["holdout_2024_2025"]["trades"] == 2
    assert metrics["holdout_2024_2025"]["net_r"] == 0.5
    assert set(metrics["annual"]) == {"2024", "2025"}


def test_holdout_requires_both_years_positive() -> None:
    metrics = {
        "holdout_2024_2025": {
            "trades": 200,
            "profit_factor": 1.2,
            "net_r": 5.0,
        },
        "annual": {"2024": {"net_r": 6.0}, "2025": {"net_r": -1.0}},
    }

    assert not screen.holdout_pass(metrics)


def test_default_instruments_use_conservative_positive_costs(tmp_path) -> None:
    instruments = screen.default_instruments(tmp_path)

    assert {instrument.symbol for instrument in instruments} == {
        "EURUSD.DWX",
        "GBPUSD.DWX",
        "USDJPY.DWX",
        "GBPJPY.DWX",
    }
    assert all(instrument.round_trip_cost_points > 0.0 for instrument in instruments)


def test_confirmed_range_enters_on_bar_after_close_signal() -> None:
    times = pd.date_range("2024-01-02T00:00:00Z", periods=205, freq="5min")
    frame = pd.DataFrame(
        {
            "open": [100.0] * len(times),
            "high": [100.5] * len(times),
            "low": [99.5] * len(times),
            "close": [100.0] * len(times),
            "utc": times,
            "local_date": [dt.date(2024, 1, 2)] * len(times),
            "year": [2024] * len(times),
            "weekday": [1] * len(times),
            "minute": [timestamp.hour * 60 + timestamp.minute for timestamp in times],
            "atr36": [1.0] * len(times),
        }
    )
    frame.loc[96, ["high", "close"]] = [101.5, 101.5]
    frame.loc[97, "open"] = 101.6
    instrument = screen.Instrument("TEST", screen.Path("unused"), "UTC", 0.0)

    trades = screen.confirmed_session_range_trade(
        frame,
        instrument,
        range_end_hour=8,
        entry_end_hour=10,
        buffer_fraction=0.0,
        stop_range_fraction=1.0,
        target_r=1.0,
        rejection=False,
    )

    assert len(trades) == 1
    assert trades[0].entry_time_utc == times[97].isoformat()
