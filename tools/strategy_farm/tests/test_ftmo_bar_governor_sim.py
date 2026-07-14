import datetime as dt

import numpy as np
import pandas as pd
import pytest

from tools.strategy_farm.portfolio.ftmo_bar_governor_sim import (
    GovernedTradePath,
    _parse_risk_clusters,
    _parse_risk_room_pairs,
    build_trade_paths,
    entry_filter_accepts,
    entry_scale_factor,
    index_entries,
    realized_volatility_scale,
    risk_multiplier_for_conditional_deadline,
    risk_multiplier_for_equity,
    risk_multiplier_for_elapsed_day,
    shadow_entry_acceptance,
    simulate_window,
)
from tools.strategy_farm.portfolio.ftmo_report_cost_reconcile import RoundTrip


def _grid(days: int = 6) -> pd.DatetimeIndex:
    return pd.date_range("2024-01-01 23:00:00", periods=days * 96, freq="15min", tz="UTC")


def _trade(
    trade_id: str,
    start: int,
    end: int,
    *,
    adverse: float = 0.0,
    exit_delta: float = 0.0,
    key: str = "1:TEST.DWX",
) -> GovernedTradePath:
    size = end - start + 1
    return GovernedTradePath(
        trade_id=trade_id,
        key=key,
        start_idx=start,
        end_idx=end,
        entry_commission=0.0,
        exit_commission=0.0,
        exit_balance_delta=exit_delta,
        adverse_pnl=np.full(size, adverse, dtype=float),
        close_pnl=np.zeros(size, dtype=float),
    )


def test_parse_risk_room_pairs_preserves_declared_pairs() -> None:
    assert _parse_risk_room_pairs("25:4000, 30:12000") == [
        (25.0, 4000.0),
        (30.0, 12000.0),
    ]


def test_parse_risk_clusters_rejects_duplicate_symbols() -> None:
    assert _parse_risk_clusters("usd=EURUSD.DWX|GBPUSD.DWX") == {
        "EURUSD.DWX": "usd",
        "GBPUSD.DWX": "usd",
    }
    with pytest.raises(ValueError, match="multiple risk clusters"):
        _parse_risk_clusters("usd=EURUSD.DWX;eur=EURUSD.DWX|EURJPY.DWX")


def test_elapsed_risk_steps_are_causal_and_may_accelerate() -> None:
    assert risk_multiplier_for_elapsed_day(14, 25.0, ((15, 30.0),)) == 25.0
    assert risk_multiplier_for_elapsed_day(15, 25.0, ((15, 30.0),)) == 30.0

    grid = _grid()
    paths = [
        _trade("early", 10, 10, exit_delta=100.0),
        _trade("late", 2 * 96 + 10, 2 * 96 + 10, exit_delta=100.0),
    ]
    result = simulate_window(
        grid,
        index_entries(paths),
        start_day=dt.date(2024, 1, 2),
        horizon_days=4,
        weights={"1:TEST.DWX": 1.0},
        risk_multiplier=1.0,
        daily_stop=1000.0,
        full_risk_room=1000.0,
        elapsed_risk_steps=((2, 2.0),),
    )

    assert result.ending_balance == 100300.0


def test_conditional_deadline_accelerates_only_inside_profit_band() -> None:
    steps = ((2, 0.0, 2000.0, 2.0),)
    assert risk_multiplier_for_conditional_deadline(1, 101000.0, 1.0, steps) == 1.0
    assert risk_multiplier_for_conditional_deadline(2, 99999.0, 1.0, steps) == 1.0
    assert risk_multiplier_for_conditional_deadline(2, 101000.0, 1.0, steps) == 2.0
    assert risk_multiplier_for_conditional_deadline(2, 102000.0, 1.0, steps) == 1.0

    grid = _grid()
    paths = [
        _trade("early", 10, 10, exit_delta=1000.0),
        _trade("late", 2 * 96 + 10, 2 * 96 + 10, exit_delta=100.0),
    ]
    result = simulate_window(
        grid,
        index_entries(paths),
        start_day=dt.date(2024, 1, 2),
        horizon_days=4,
        weights={"1:TEST.DWX": 1.0},
        risk_multiplier=1.0,
        daily_stop=1000.0,
        full_risk_room=1000.0,
        conditional_deadline_steps=steps,
    )
    assert result.ending_balance == 101200.0


def test_four_profitable_trading_days_pass() -> None:
    grid = _grid()
    paths = [
        _trade(f"t{day}", day * 96 + 10, day * 96 + 10, exit_delta=2500.0)
        for day in range(4)
    ]
    result = simulate_window(
        grid,
        index_entries(paths),
        start_day=dt.date(2024, 1, 2),
        horizon_days=5,
        weights={"1:TEST.DWX": 1.0},
        risk_multiplier=1.0,
        daily_stop=1000.0,
        full_risk_room=1000.0,
    )
    assert result.outcome == "passed"
    assert result.trading_days == 4
    assert result.ending_balance == 110000.0


def test_stop_cancels_exit_and_blocks_rest_of_day() -> None:
    grid = _grid()
    first = _trade("first", 10, 110, adverse=-1500.0, exit_delta=-5000.0)
    blocked = _trade("blocked", 20, 20, exit_delta=5000.0)
    result = simulate_window(
        grid,
        index_entries([first, blocked]),
        start_day=dt.date(2024, 1, 2),
        horizon_days=2,
        weights={"1:TEST.DWX": 1.0},
        risk_multiplier=1.0,
        daily_stop=1000.0,
        full_risk_room=1000.0,
    )
    assert result.outcome == "not_reached"
    assert result.ending_balance == 99000.0
    assert result.stop_events == 1
    assert result.accepted_entries == 1
    assert result.blocked_entries == 1


def test_window_starts_flat() -> None:
    grid = _grid()
    old = _trade("old", 10, 120, adverse=-9000.0, exit_delta=-9000.0)
    result = simulate_window(
        grid,
        index_entries([old]),
        start_day=dt.date(2024, 1, 3),
        horizon_days=2,
        weights={"1:TEST.DWX": 1.0},
        risk_multiplier=1.0,
        daily_stop=1000.0,
        full_risk_room=1000.0,
    )
    assert result.outcome == "not_reached"
    assert result.accepted_entries == 0
    assert result.ending_balance == 100000.0


def test_exit_settlement_is_included_in_stop_decision() -> None:
    grid = _grid()
    trade = _trade("exit_loss", 10, 10, adverse=0.0, exit_delta=-2000.0)
    result = simulate_window(
        grid,
        index_entries([trade]),
        start_day=dt.date(2024, 1, 2),
        horizon_days=1,
        weights={"1:TEST.DWX": 1.0},
        risk_multiplier=1.0,
        daily_stop=1000.0,
        full_risk_room=1000.0,
    )
    assert result.outcome == "not_reached"
    assert result.stop_events == 1
    assert result.ending_balance == 99000.0


def test_entry_scale_throttles_near_max_loss_floor() -> None:
    assert entry_scale_factor(100000.0, 95500.0, 2000.0) == 1.0
    assert entry_scale_factor(96500.0, 95500.0, 2000.0) == 0.5
    assert entry_scale_factor(95500.0, 95500.0, 2000.0) == 0.0


def test_realized_volatility_scale_is_causal_bounded_and_warm() -> None:
    kwargs = {
        "lookback_days": 3,
        "target_rms": 500.0,
        "minimum_scale": 0.5,
        "maximum_scale": 1.25,
    }
    assert realized_volatility_scale([1000.0, -1000.0], **kwargs) == 1.0
    assert realized_volatility_scale([1000.0, -1000.0, 1000.0], **kwargs) == 0.5
    assert realized_volatility_scale([0.0, 0.0, 0.0], **kwargs) == 1.25


def test_realized_volatility_target_scales_only_after_completed_days() -> None:
    grid = _grid()
    paths = [
        _trade("d0", 10, 10, exit_delta=1000.0),
        _trade("d1", 96 + 10, 96 + 10, exit_delta=-1000.0),
        _trade("d2", 2 * 96 + 10, 2 * 96 + 10, exit_delta=1000.0),
        _trade("d3", 3 * 96 + 10, 3 * 96 + 10, exit_delta=1000.0),
    ]
    result = simulate_window(
        grid,
        index_entries(paths),
        start_day=dt.date(2024, 1, 2),
        horizon_days=5,
        weights={"1:TEST.DWX": 1.0},
        risk_multiplier=1.0,
        daily_stop=2000.0,
        full_risk_room=2000.0,
        realized_vol_lookback_days=3,
        realized_vol_target_rms=500.0,
        realized_vol_minimum_scale=0.5,
        realized_vol_maximum_scale=1.0,
    )

    assert result.ending_balance == 101500.0


def test_open_risk_limit_caps_same_bar_entries_to_policy_room() -> None:
    grid = _grid()
    paths = [
        _trade("first", 10, 20, exit_delta=100.0),
        _trade("second", 10, 20, exit_delta=100.0),
    ]
    result = simulate_window(
        grid,
        index_entries(paths),
        start_day=dt.date(2024, 1, 2),
        horizon_days=1,
        weights={"1:TEST.DWX": 1.0},
        risk_multiplier=1.0,
        daily_stop=1000.0,
        full_risk_room=1000.0,
        open_risk_limit_ratio=1.0,
    )

    assert result.accepted_entries == 2
    assert result.blocked_entries == 0
    assert result.ending_balance == 100100.0


def test_symbol_open_risk_limit_caps_only_same_symbol_entries() -> None:
    grid = _grid()
    paths = [
        _trade("first", 10, 20, exit_delta=100.0, key="1:TEST.DWX"),
        _trade("second", 10, 20, exit_delta=100.0, key="2:TEST.DWX"),
        _trade("other", 10, 20, exit_delta=100.0, key="3:OTHER.DWX"),
    ]
    result = simulate_window(
        grid,
        index_entries(paths),
        start_day=dt.date(2024, 1, 2),
        horizon_days=1,
        weights={"1:TEST.DWX": 0.25, "2:TEST.DWX": 0.25, "3:OTHER.DWX": 0.5},
        risk_multiplier=4.0,
        daily_stop=1000.0,
        full_risk_room=1000.0,
        symbol_open_risk_limit_ratio=1.0,
    )

    assert result.accepted_entries == 3
    assert result.blocked_entries == 0
    assert result.ending_balance == 100200.0


def test_cluster_open_risk_limit_caps_declared_symbols_as_one_group() -> None:
    grid = _grid()
    paths = [
        _trade("eur", 10, 20, exit_delta=100.0, key="1:EURUSD.DWX"),
        _trade("gbp", 10, 20, exit_delta=100.0, key="2:GBPUSD.DWX"),
        _trade("gold", 10, 20, exit_delta=100.0, key="3:XAUUSD.DWX"),
    ]
    result = simulate_window(
        grid,
        index_entries(paths),
        start_day=dt.date(2024, 1, 2),
        horizon_days=1,
        weights={"1:EURUSD.DWX": 0.25, "2:GBPUSD.DWX": 0.25, "3:XAUUSD.DWX": 0.5},
        risk_multiplier=4.0,
        daily_stop=1000.0,
        full_risk_room=1000.0,
        cluster_open_risk_limit_ratio=1.0,
        risk_cluster_by_symbol={"EURUSD.DWX": "usd_fx", "GBPUSD.DWX": "usd_fx"},
    )

    assert result.accepted_entries == 3
    assert result.blocked_entries == 0
    assert result.ending_balance == 100300.0


def test_profit_risk_steps_are_non_decreasing_and_thresholded() -> None:
    steps = ((2000.0, 2.0), (5000.0, 3.0))
    assert risk_multiplier_for_equity(101999.0, 1.0, steps) == 1.0
    assert risk_multiplier_for_equity(102000.0, 1.0, steps) == 2.0
    assert risk_multiplier_for_equity(105001.0, 1.0, steps) == 3.0


def test_profit_risk_step_locks_normal_entries_at_target_before_four_days() -> None:
    grid = _grid()
    paths = [
        _trade(f"t{day}", day * 96 + 10, day * 96 + 10, exit_delta=2000.0)
        for day in range(4)
    ]
    result = simulate_window(
        grid,
        index_entries(paths),
        start_day=dt.date(2024, 1, 2),
        horizon_days=5,
        weights={"1:TEST.DWX": 1.0},
        risk_multiplier=1.0,
        daily_stop=1000.0,
        full_risk_room=1000.0,
        profit_risk_steps=((2000.0, 2.0),),
    )
    assert result.outcome == "not_reached"
    assert result.trading_days == 3
    assert result.ending_balance == 110000.0
    assert result.blocked_entries == 1


def test_direction_only_filters_are_directional() -> None:
    timestamp = dt.datetime(2024, 1, 2, tzinfo=dt.UTC)
    sell = RoundTrip(timestamp, timestamp, "TEST", "sell", 1.0, 1.0, 1.0, 0.0, 0.0, 0.0)
    buy = RoundTrip(timestamp, timestamp, "TEST", "buy", 1.0, 1.0, 1.0, 0.0, 0.0, 0.0)

    assert entry_filter_accepts({"entry_filter": "short_only"}, sell, pd.Timestamp(timestamp), None)
    assert not entry_filter_accepts({"entry_filter": "short_only"}, buy, pd.Timestamp(timestamp), None)
    assert entry_filter_accepts({"entry_filter": "long_only"}, buy, pd.Timestamp(timestamp), None)
    assert not entry_filter_accepts({"entry_filter": "long_only"}, sell, pd.Timestamp(timestamp), None)


def test_exclude_weekdays_uses_prague_entry_day() -> None:
    timestamp = dt.datetime(2024, 1, 1, 23, 30, tzinfo=dt.UTC)
    trade = RoundTrip(timestamp, timestamp, "TEST", "buy", 1.0, 1.0, 1.0, 0.0, 0.0, 0.0)
    tuesday_excluded = {
        "entry_filter": "exclude_weekdays",
        "entry_filter_excluded_weekdays": [1],
    }
    assert not entry_filter_accepts(tuesday_excluded, trade, pd.Timestamp(timestamp), None)
    tuesday_excluded["entry_filter_excluded_weekdays"] = [0]
    assert entry_filter_accepts(tuesday_excluded, trade, pd.Timestamp(timestamp), None)


def test_one_and_five_day_trend_filters_use_only_pre_entry_bars() -> None:
    index = pd.date_range("2024-01-01T00:00:00Z", periods=510, freq="15min", tz="UTC")
    closes = np.linspace(100.0, 120.0, len(index))
    bars = pd.DataFrame(
        {"high": closes + 0.1, "low": closes - 0.1, "close": closes},
        index=index,
    )
    entry = index[500]
    trade = RoundTrip(
        entry.to_pydatetime(), entry.to_pydatetime(), "TEST", "buy", 1.0, 100.0, 100.0, 0.0, 0.0, 0.0
    )

    before_24h = entry_filter_accepts({"entry_filter": "trend_24h_align"}, trade, entry, bars)
    before_5d = entry_filter_accepts({"entry_filter": "trend_5d_align"}, trade, entry, bars)
    bars.loc[entry:, "close"] = 1.0

    assert before_24h
    assert before_5d
    assert entry_filter_accepts({"entry_filter": "trend_24h_align"}, trade, entry, bars)
    assert entry_filter_accepts({"entry_filter": "trend_5d_align"}, trade, entry, bars)


def test_asia_filter_uses_prague_hour_boundary() -> None:
    winter_before = pd.Timestamp("2024-01-02T05:59:00Z")
    winter_boundary = pd.Timestamp("2024-01-02T06:00:00Z")
    summer_before = pd.Timestamp("2024-07-02T04:59:00Z")
    summer_boundary = pd.Timestamp("2024-07-02T05:00:00Z")
    trade = RoundTrip(
        winter_before.to_pydatetime(),
        winter_before.to_pydatetime(),
        "TEST",
        "buy",
        1.0,
        1.0,
        1.0,
        0.0,
        0.0,
        0.0,
    )

    assert entry_filter_accepts({"entry_filter": "asia_only"}, trade, winter_before, None)
    assert not entry_filter_accepts(
        {"entry_filter": "asia_only"}, trade, winter_boundary, None
    )
    assert entry_filter_accepts({"entry_filter": "asia_only"}, trade, summer_before, None)
    assert not entry_filter_accepts(
        {"entry_filter": "asia_only"}, trade, summer_boundary, None
    )


def test_shadow_pnl_filter_uses_only_prior_closed_same_year_trades() -> None:
    def round_trip(day: str, profit: float) -> RoundTrip:
        entry = pd.Timestamp(f"{day}T10:00:00Z").to_pydatetime()
        exit_time = pd.Timestamp(f"{day}T11:00:00Z").to_pydatetime()
        return RoundTrip(
            entry,
            exit_time,
            "TEST",
            "buy",
            1.0,
            100.0,
            100.0,
            profit,
            0.0,
            0.0,
        )

    case = {
        "entry_filter": "shadow_pnl_last_2_pos_same_year",
        "timestamp_basis": "unix_utc",
        "trades": [
            round_trip("2024-01-02", 10.0),
            round_trip("2024-01-03", -20.0),
            round_trip("2024-01-04", 999.0),
            round_trip("2025-01-02", 1.0),
        ],
        "cost": {
            "commission_percent_per_side": 0.0,
            "flat_round_trip_commission_per_lot": 0.0,
            "swap_long_points": 0.0,
            "swap_short_points": 0.0,
            "contract_size": 1.0,
            "source_contract_size": 1.0,
            "profit_currency_to_account_rate": 1.0,
            "derive_profit_currency_rate_from_pnl": False,
            "digits": 2,
        },
    }

    assert shadow_entry_acceptance(case) == [True, True, False, True]


def test_twenty_day_trend_filter_uses_only_pre_entry_bars() -> None:
    index = pd.date_range("2023-01-01T00:00:00Z", periods=1940, freq="15min", tz="UTC")
    closes = np.linspace(100.0, 120.0, len(index))
    bars = pd.DataFrame(
        {"high": closes + 0.1, "low": closes - 0.1, "close": closes},
        index=index,
    )
    entry = index[1930]
    trade = RoundTrip(
        entry.to_pydatetime(),
        entry.to_pydatetime(),
        "TEST",
        "buy",
        1.0,
        100.0,
        100.0,
        0.0,
        0.0,
        0.0,
    )

    before = entry_filter_accepts({"entry_filter": "trend_20d_align"}, trade, entry, bars)
    fade_before = entry_filter_accepts({"entry_filter": "trend_20d_fade"}, trade, entry, bars)
    bars.loc[entry:, "close"] = 1.0
    after = entry_filter_accepts({"entry_filter": "trend_20d_align"}, trade, entry, bars)
    fade_after = entry_filter_accepts({"entry_filter": "trend_20d_fade"}, trade, entry, bars)

    assert before
    assert not fade_before
    assert after == before
    assert fade_after == fade_before


def test_trend_consensus_filter_matches_four_and_twenty_four_hour_signs() -> None:
    index = pd.date_range("2024-01-01T00:00:00Z", periods=110, freq="15min", tz="UTC")
    closes = np.linspace(100.0, 120.0, len(index))
    bars = pd.DataFrame(
        {"high": closes + 0.1, "low": closes - 0.1, "close": closes},
        index=index,
    )
    entry = index[100]
    buy = RoundTrip(
        entry.to_pydatetime(), entry.to_pydatetime(), "TEST", "buy", 1.0, 100.0, 100.0, 0.0, 0.0, 0.0
    )
    sell = RoundTrip(
        entry.to_pydatetime(), entry.to_pydatetime(), "TEST", "sell", 1.0, 100.0, 100.0, 0.0, 0.0, 0.0
    )

    assert entry_filter_accepts(
        {"entry_filter": "trend_consensus_align"}, buy, entry, bars
    )
    assert entry_filter_accepts(
        {"entry_filter": "trend_consensus_fade"}, sell, entry, bars
    )

    bars.loc[entry:, "close"] = 1.0
    assert entry_filter_accepts(
        {"entry_filter": "trend_consensus_align"}, buy, entry, bars
    )


def test_report_pnl_scale_normalizes_low_risk_native_report() -> None:
    grid = pd.date_range("2024-01-02T10:00:00Z", periods=2, freq="15min", tz="UTC")
    bars = pd.DataFrame(
        {
            "open": [100.0, 100.0],
            "high": [101.0, 103.0],
            "low": [99.0, 100.0],
            "close": [100.0, 102.0],
        },
        index=grid,
    )
    trade = RoundTrip(
        grid[0].to_pydatetime(),
        grid[1].to_pydatetime(),
        "TEST.DWX",
        "buy",
        1.0,
        100.0,
        102.0,
        2.0,
        0.0,
        0.0,
    )
    case = {
        "ea_id": 1,
        "symbol": "TEST.DWX",
        "timestamp_basis": "unix_utc",
        "report_pnl_scale": 10.0,
        "trades": [trade],
        "q08_rows": [{"mae_acct": -1.0}],
        "cost": {
            "commission_percent_per_side": 0.0,
            "flat_round_trip_commission_per_lot": 0.0,
            "swap_long_points": 0.0,
            "swap_short_points": 0.0,
            "contract_size": 1.0,
            "source_contract_size": 1.0,
            "profit_currency_to_account_rate": 1.0,
            "derive_profit_currency_rate_from_pnl": False,
            "digits": 2,
        },
    }

    paths = build_trade_paths(
        case,
        grid=grid,
        aligned_bars=bars,
        observed_bar_timestamps=set(grid),
    )

    assert len(paths) == 1
    assert paths[0].exit_balance_delta == 20.0
    assert paths[0].adverse_pnl.tolist() == [-10.0, 0.0]
    assert paths[0].close_pnl.tolist() == [0.0, 20.0]


def test_basket_leg_uses_logical_weight_key_and_fractional_nominal_risk() -> None:
    grid = pd.date_range("2024-01-02T10:00:00Z", periods=2, freq="15min", tz="UTC")
    bars = pd.DataFrame(
        {
            "open": [100.0, 100.0],
            "high": [101.0, 103.0],
            "low": [99.0, 100.0],
            "close": [100.0, 102.0],
        },
        index=grid,
    )
    trade = RoundTrip(
        grid[0].to_pydatetime(),
        grid[1].to_pydatetime(),
        "LEG.DWX",
        "buy",
        1.0,
        100.0,
        102.0,
        2.0,
        0.0,
        0.0,
    )
    case = {
        "ea_id": 7,
        "symbol": "LEG.DWX",
        "weight_key": "7:PAIR.BASKET",
        "nominal_risk_per_trade": 500.0,
        "timestamp_basis": "unix_utc",
        "trades": [trade],
        "q08_rows": [{"mae_acct": -1.0}],
        "cost": {
            "commission_percent_per_side": 0.0,
            "flat_round_trip_commission_per_lot": 0.0,
            "swap_long_points": 0.0,
            "swap_short_points": 0.0,
            "contract_size": 1.0,
            "source_contract_size": 1.0,
            "profit_currency_to_account_rate": 1.0,
            "derive_profit_currency_rate_from_pnl": False,
            "digits": 2,
        },
    }

    paths = build_trade_paths(
        case,
        grid=grid,
        aligned_bars=bars,
        observed_bar_timestamps=set(grid),
    )

    assert paths[0].key == "7:PAIR.BASKET"
    assert paths[0].trade_id == "7:PAIR.BASKET:LEG.DWX:1"
    assert paths[0].nominal_risk == 500.0


def test_volatility_filter_uses_only_pre_entry_bars() -> None:
    index = pd.date_range("2024-01-01T00:00:00Z", periods=110, freq="15min", tz="UTC")
    ranges = np.ones(110)
    ranges[84:100] = 2.0
    bars = pd.DataFrame(
        {
            "high": 100.0 + ranges / 2.0,
            "low": 100.0 - ranges / 2.0,
            "close": 100.0,
        },
        index=index,
    )
    entry = index[100]
    trade = RoundTrip(
        entry.to_pydatetime(), entry.to_pydatetime(), "TEST", "buy", 1.0, 100.0, 100.0, 0.0, 0.0, 0.0
    )

    before = entry_filter_accepts(
        {"entry_filter": "volatility_active"}, trade, entry, bars
    )
    bars.loc[entry:, ["high", "low"]] = [1000.0, 0.0]
    after = entry_filter_accepts(
        {"entry_filter": "volatility_active"}, trade, entry, bars
    )

    assert before
    assert after == before
