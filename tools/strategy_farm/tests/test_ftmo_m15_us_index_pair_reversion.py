from __future__ import annotations

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_m15_us_index_pair_reversion as pair


def _frame(high: float, low: float) -> pd.DataFrame:
    utc = pd.to_datetime(["2023-01-03T14:30:00Z"], utc=True)
    frame = pd.DataFrame(
        {
            "open": [100.0],
            "high": [high],
            "low": [low],
            "close": [100.0],
            "utc": utc,
            "local_date": [pd.Timestamp("2023-01-03").date()],
            "year": [2023],
        }
    )
    return frame


def test_parameter_grid_is_predeclared_size() -> None:
    assert len(list(pair.parameter_grid())) == 486


def test_invalid_pair_mode_is_rejected() -> None:
    try:
        pair.screen({}, {}, mode="oracle")
    except ValueError as exc:
        assert "unsupported pair mode" in str(exc)
    else:  # pragma: no cover
        raise AssertionError("invalid mode must fail")


def test_joint_dual_touch_uses_stop_first() -> None:
    m15._ARRAY_CACHE.clear()
    trade = pair.simulate_pair_trade(
        _frame(high=102.0, low=98.0),
        _frame(high=102.0, low=98.0),
        path_a=[0],
        path_b=[0],
        side_a=-1,
        atr_a=1.0,
        atr_b=1.0,
        portfolio_stop_atr=1.0,
        target_r=1.0,
        cost_points_a=0.0,
        cost_points_b=0.0,
        reason="test",
    )
    assert trade is not None
    assert trade.r_multiple == -1.0
    assert trade.exit_reason == "test:stop_pessimistic"


def test_costs_are_charged_to_both_legs() -> None:
    m15._ARRAY_CACHE.clear()
    trade = pair.simulate_pair_trade(
        _frame(high=100.0, low=100.0),
        _frame(high=100.0, low=100.0),
        path_a=[0],
        path_b=[0],
        side_a=1,
        atr_a=10.0,
        atr_b=5.0,
        portfolio_stop_atr=1.0,
        target_r=2.0,
        cost_points_a=2.0,
        cost_points_b=1.0,
        reason="test",
    )
    assert trade is not None
    assert trade.r_multiple == -0.2
