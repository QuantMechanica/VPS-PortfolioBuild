from __future__ import annotations

from tools.strategy_farm.portfolio import ftmo_intraday_candidate_screen as base
from tools.strategy_farm.portfolio import ftmo_ws30_gap_fade_nested_filter as screen


def _trade(side: int = 1) -> base.Trade:
    return base.Trade(
        entry_time_utc="2023-01-03T10:00:00+00:00",
        local_date="2023-01-03",
        year=2023,
        side=side,
        r_multiple=1.0,
        exit_reason="test",
    )


def _features() -> dict[str, dict[str, float]]:
    return {
        "2023-01-03": {
            "sma20_delta": 1.0,
            "momentum5": 2.0,
            "prior_session_move": -1.0,
            "prior_atr": 1.0,
            "atr20_median": 1.5,
        }
    }


def test_trend_and_majority_filters_are_side_aware() -> None:
    assert screen.accepts(_trade(1), _features(), "sma20_align")
    assert screen.accepts(_trade(1), _features(), "momentum5_align")
    assert not screen.accepts(_trade(1), _features(), "prior_session_align")
    assert screen.accepts(_trade(1), _features(), "majority_2_of_3_align")


def test_low_volatility_and_combined_filter() -> None:
    assert screen.accepts(_trade(1), _features(), "low_volatility")
    assert screen.accepts(_trade(1), _features(), "momentum5_align_low_volatility")
    assert not screen.accepts(_trade(-1), _features(), "momentum5_align_low_volatility")


def test_raw_control_and_unknown_filter() -> None:
    assert screen.accepts(_trade(), {}, "raw_control")
    try:
        screen.accepts(_trade(), _features(), "unknown")
    except ValueError as exc:
        assert "unknown filter" in str(exc)
    else:
        raise AssertionError("unknown filter must fail")
