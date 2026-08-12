from __future__ import annotations

from tools.strategy_farm.portfolio import ftmo_intraday_candidate_screen as base
from tools.strategy_farm.portfolio import ftmo_ndx_gap_impulse_nested_filter as screen


def _trade(side: int = 1) -> base.Trade:
    return base.Trade(
        entry_time_utc="2023-01-03T10:00:00+00:00",
        local_date="2023-01-03",
        year=2023,
        side=side,
        r_multiple=1.0,
        exit_reason="test",
    )


def test_raw_control_always_accepts() -> None:
    assert screen.accepts(_trade(), {}, "raw_control")


def test_individual_filters_use_prior_completed_features() -> None:
    features = {
        "2023-01-03": {
            "sma20_delta": 1.0,
            "momentum5": -1.0,
            "prior_session_move": 2.0,
        }
    }
    assert screen.accepts(_trade(1), features, "sma20_align")
    assert not screen.accepts(_trade(1), features, "momentum5_align")
    assert screen.accepts(_trade(1), features, "prior_session_align")


def test_majority_filter_requires_two_alignments() -> None:
    features = {
        "2023-01-03": {
            "sma20_delta": 1.0,
            "momentum5": -1.0,
            "prior_session_move": 2.0,
        }
    }
    assert screen.accepts(_trade(1), features, "majority_2_of_3_align")
    assert not screen.accepts(_trade(-1), features, "majority_2_of_3_align")


def test_unknown_filter_is_rejected() -> None:
    try:
        screen.accepts(_trade(), {"2023-01-03": {}}, "unknown")
    except ValueError as exc:
        assert "unknown filter" in str(exc)
    else:
        raise AssertionError("unknown filter must fail")
