from __future__ import annotations

import datetime as dt

import numpy as np
import pandas as pd

from tools.strategy_farm.portfolio import ftmo_bar_joint_book_sim as joint
from tools.strategy_farm.portfolio.ftmo_report_cost_reconcile import RoundTrip


def make_component(
    key: str,
    *,
    pre: list[float],
    post: list[float],
    adverse: list[float],
    close: list[float],
    opens: list[int],
) -> joint.SleeveComponents:
    ea_id, symbol = key.split(":", 1)
    return joint.SleeveComponents(
        key=key,
        ea_id=int(ea_id),
        symbol=symbol,
        base_risk_fixed=1000.0,
        trades=1,
        pre_low_balance_events=np.asarray(pre, dtype=float),
        post_low_balance_events=np.asarray(post, dtype=float),
        adverse_floating=np.asarray(adverse, dtype=float),
        close_floating=np.asarray(close, dtype=float),
        opened_positions=np.asarray(opens, dtype=np.int32),
        ftmo_net=sum(pre) + sum(post),
        ftmo_commission=0.0,
        ftmo_swap=0.0,
        point_value_fallbacks=0,
        excluded_trades=0,
    )


def test_trade_point_value_prefers_report_implied_slope() -> None:
    trade = RoundTrip(
        entry_time=dt.datetime(2024, 1, 1, tzinfo=dt.UTC),
        exit_time=dt.datetime(2024, 1, 2, tzinfo=dt.UTC),
        symbol="TEST",
        side="buy",
        volume=2.0,
        entry_price=100.0,
        exit_price=102.0,
        profit=400.0,
        native_swap=0.0,
        native_commission=0.0,
    )

    value, fallback = joint.trade_point_value(
        trade,
        source_contract_size=100.0,
        fallback_account_rate=1.0,
    )

    assert value == 200.0
    assert not fallback


def test_trade_point_value_falls_back_for_flat_exit() -> None:
    trade = RoundTrip(
        entry_time=dt.datetime(2024, 1, 1, tzinfo=dt.UTC),
        exit_time=dt.datetime(2024, 1, 2, tzinfo=dt.UTC),
        symbol="TEST",
        side="sell",
        volume=2.0,
        entry_price=100.0,
        exit_price=100.0,
        profit=0.0,
        native_swap=0.0,
        native_commission=0.0,
    )

    value, fallback = joint.trade_point_value(
        trade,
        source_contract_size=100.0,
        fallback_account_rate=0.5,
    )

    assert value == 100.0
    assert fallback


def test_cumulative_swap_applies_triple_units() -> None:
    timestamps = pd.date_range("2024-01-03T23:45:00Z", periods=3, freq="15min", tz="UTC")
    schedule = [(pd.Timestamp("2024-01-04T00:00:00Z"), 3)]

    values = joint.cumulative_swap_for_slice(timestamps, schedule, total_swap=-30.0)

    assert values.tolist() == [0.0, -30.0, -30.0]


def test_darwinex_broker_wall_timestamp_normalizes_to_real_utc() -> None:
    broker_wall = pd.Timestamp("2018-07-16T08:25:37Z")

    normalized = joint.normalize_timestamp(
        broker_wall,
        joint.TIMESTAMP_BASIS_DARWINEX_WALL,
    )

    assert normalized == pd.Timestamp("2018-07-16T05:25:37Z")


def test_unix_utc_timestamp_is_not_shifted() -> None:
    timestamp = pd.Timestamp("2024-01-02T10:00:00Z")

    normalized = joint.normalize_timestamp(timestamp, joint.TIMESTAMP_BASIS_UNIX_UTC)

    assert normalized == timestamp


def test_build_components_caps_partial_bar_at_measured_q08_mae() -> None:
    timestamp = pd.Timestamp("2024-01-02T10:00:00Z")
    grid = pd.DatetimeIndex([timestamp])
    trade = RoundTrip(
        entry_time=timestamp.to_pydatetime(),
        exit_time=(timestamp + pd.Timedelta(minutes=4)).to_pydatetime(),
        symbol="TEST",
        side="buy",
        volume=1.0,
        entry_price=100.0,
        exit_price=101.0,
        profit=100.0,
        native_swap=0.0,
        native_commission=0.0,
    )
    bars = pd.DataFrame(
        {"open": [100.0], "high": [102.0], "low": [90.0], "close": [101.0]},
        index=grid,
    )
    case = {
        "ea_id": 1,
        "symbol": "TEST",
        "base_risk_fixed": 1000.0,
        "trades": [trade],
        "q08_rows": [
            {
                "entry_time": int(trade.entry_time.timestamp()),
                "time": int(trade.exit_time.timestamp()),
                "mae_acct": -50.0,
            }
        ],
        "cost": {
            "commission_percent_per_side": 0.0,
            "flat_round_trip_commission_per_lot": 0.0,
            "swap_long_points": 0.0,
            "swap_short_points": 0.0,
            "contract_size": 100.0,
            "source_contract_size": 100.0,
            "profit_currency_to_account_rate": 1.0,
            "digits": 2,
        },
    }

    component = joint.build_sleeve_components(
        case,
        grid=grid,
        aligned_bars=bars,
        observed_bar_timestamps={timestamp},
    )

    assert component.adverse_floating.tolist() == [-50.0]
    assert component.q08_mae_capped_trades == 1
    assert component.q08_mae_capped_bars == 1
    assert component.max_q08_cap_adjustment == 950.0


def test_components_to_daily_preserves_joint_offsets() -> None:
    grid = pd.DatetimeIndex(
        [
            "2024-01-01T22:45:00Z",
            "2024-01-01T23:00:00Z",
            "2024-01-02T22:45:00Z",
            "2024-01-02T23:00:00Z",
        ]
    ).tz_convert("UTC")
    first = make_component(
        "1:A",
        pre=[-10.0, 0.0, 0.0, 0.0],
        post=[0.0, 110.0, 0.0, 0.0],
        adverse=[-50.0, 0.0, 0.0, 0.0],
        close=[20.0, 0.0, 0.0, 0.0],
        opens=[1, 0, 0, 0],
    )
    second = make_component(
        "2:B",
        pre=[0.0, 0.0, -5.0, 0.0],
        post=[0.0, 0.0, 0.0, -45.0],
        adverse=[0.0, 0.0, -25.0, 0.0],
        close=[0.0, 0.0, -10.0, 0.0],
        opens=[0, 0, 1, 0],
    )

    days, pairs = joint.components_to_daily(
        grid,
        [first, second],
        weights={"1:A": 1.0, "2:B": 1.0},
        multiplier=1.0,
    )

    assert days == [dt.date(2024, 1, 1), dt.date(2024, 1, 2), dt.date(2024, 1, 3)]
    assert pairs[0] == (-10.0, -60.0, 1)
    assert pairs[1] == (105.0, 0.0, 1)
    assert pairs[2] == (-45.0, -45.0, 0)


def test_components_to_daily_vectorization_matches_event_order_reference() -> None:
    rng = np.random.default_rng(17)
    grid = pd.date_range("2024-03-30T20:00:00Z", periods=80, freq="15min", tz="UTC")
    components = []
    for number in range(2):
        components.append(
            make_component(
                f"{number + 1}:S{number + 1}",
                pre=rng.normal(0.0, 5.0, len(grid)).tolist(),
                post=rng.normal(0.0, 20.0, len(grid)).tolist(),
                adverse=(-np.abs(rng.normal(0.0, 50.0, len(grid)))).tolist(),
                close=rng.normal(0.0, 30.0, len(grid)).tolist(),
                opens=rng.integers(0, 2, len(grid)).tolist(),
            )
        )
    weights = {"1:S1": 0.75, "2:S2": 0.25}
    multiplier = 3.0

    days, pairs = joint.components_to_daily(
        grid,
        components,
        weights=weights,
        multiplier=multiplier,
    )

    pre = sum(c.pre_low_balance_events * weights[c.key] * multiplier for c in components)
    post = sum(c.post_low_balance_events * weights[c.key] * multiplier for c in components)
    adverse = sum(c.adverse_floating * weights[c.key] * multiplier for c in components)
    close = sum(c.close_floating * weights[c.key] * multiplier for c in components)
    opens = sum(c.opened_positions for c in components)
    reference: dict[dt.date, dict[str, float | int]] = {}
    balance = 0.0
    for index, timestamp in enumerate(grid):
        day = timestamp.to_pydatetime().astimezone(joint.PRAGUE).date()
        state = reference.setdefault(
            day,
            {"start": balance, "low": balance, "opens": 0},
        )
        balance += float(pre[index])
        state["low"] = min(float(state["low"]), balance, balance + float(adverse[index]))
        balance += float(post[index])
        state["low"] = min(float(state["low"]), balance, balance + float(close[index]))
        state["opens"] = int(state["opens"]) + int(opens[index])
    expected_days = list(reference)
    expected_pairs = []
    for index, day in enumerate(expected_days):
        start = float(reference[day]["start"])
        end = float(reference[expected_days[index + 1]]["start"]) if index + 1 < len(expected_days) else balance
        expected_pairs.append(
            (end - start, float(reference[day]["low"]) - start, int(reference[day]["opens"]))
        )

    assert days == expected_days
    np.testing.assert_allclose(
        np.asarray(pairs, dtype=float),
        np.asarray(expected_pairs, dtype=float),
        rtol=0.0,
        atol=1e-9,
    )


def test_rates_include_wilson_interval() -> None:
    result = joint.rates({"passed": 80, "not_reached": 20})

    assert result["pass_pct"] == 80.0
    assert result["pass_ci95_pct"][0] < 80.0 < result["pass_ci95_pct"][1]


def test_target_only_is_an_optimistic_loss_rule_ceiling() -> None:
    sequence = [
        (2500.0, -6000.0, 1),
        (2500.0, 0.0, 1),
        (2500.0, 0.0, 1),
        (2500.0, 0.0, 1),
    ]

    assert joint.evaluate_window(sequence, target=joint.TARGET) == "daily_breach"
    assert joint.evaluate_target_only_window(sequence) == "passed"


def test_excluded_year_splits_segments_without_crossing_gap() -> None:
    days = [
        dt.date(2019, 12, 30),
        dt.date(2019, 12, 31),
        dt.date(2020, 1, 1),
        dt.date(2021, 1, 1),
        dt.date(2021, 1, 2),
    ]
    pairs = [(float(index), 0.0, 0) for index in range(len(days))]

    segments = joint.split_valid_segments(days, pairs, excluded_years={2020})

    assert segments == [[pairs[0], pairs[1]], [pairs[3], pairs[4]]]


def test_segment_bootstrap_is_deterministic() -> None:
    segments = [[(10.0, -1.0, 1)] * 20, [(-5.0, -2.0, 1)] * 20]

    first = joint.bootstrap_segments(segments, horizon=10, block=2, runs=100, seed=7)
    second = joint.bootstrap_segments(segments, horizon=10, block=2, runs=100, seed=7)

    assert first == second
