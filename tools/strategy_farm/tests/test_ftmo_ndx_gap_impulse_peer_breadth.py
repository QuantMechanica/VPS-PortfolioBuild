from __future__ import annotations

import datetime as dt
import json

import pandas as pd
import pytest

from tools.strategy_farm.portfolio import ftmo_intraday_candidate_screen as base
from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_ndx_gap_impulse_peer_breadth as screen


def _trade(side: int = 1) -> base.Trade:
    return base.Trade(
        entry_time_utc="2023-01-03T15:30:00+00:00",
        local_date="2023-01-03",
        year=2023,
        side=side,
        r_multiple=1.0,
        exit_reason="test",
    )


def _features() -> dict[str, dict[str, float]]:
    return {
        "2023-01-03": {
            "sp500_gap_atr": 0.2,
            "sp500_impulse_atr": 0.3,
            "ws30_gap_atr": -0.2,
            "ws30_impulse_atr": 0.4,
        }
    }


def test_declared_peer_filters() -> None:
    trade = _trade()
    features = _features()
    assert screen.accepts(trade, {}, "raw_control")
    assert screen.accepts(trade, features, "sp500_impulse_025_align")
    assert screen.accepts(trade, features, "ws30_impulse_025_align")
    assert screen.accepts(trade, features, "any_peer_impulse_025_align")
    assert screen.accepts(trade, features, "both_peer_impulse_025_align")
    assert not screen.accepts(trade, features, "both_peer_gap_010_align")
    assert screen.accepts(trade, features, "peer_majority_3_of_4_010_align")


def test_missing_peer_data_rejects_non_control() -> None:
    assert not screen.accepts(_trade(), {}, "any_peer_impulse_025_align")


def test_peer_features_stop_at_completed_opening_window() -> None:
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    times = pd.date_range("2023-01-02 09:30", periods=12, freq="15min", tz="UTC")
    times = times.append(pd.date_range("2023-01-03 09:30", periods=12, freq="15min", tz="UTC"))
    frame = pd.DataFrame(
        {
            "utc": times,
            "local_date": [dt.date(2023, 1, 2)] * 12 + [dt.date(2023, 1, 3)] * 12,
            "weekday": [0] * 12 + [1] * 12,
            "minute": [570 + 15 * index for index in range(12)] * 2,
            "open": [100.0] * 12 + [102.0] * 12,
            "close": [100.0] * 12 + [102.0, 102.2, 102.4, 102.6] + [50.0] * 8,
            "atr56": [2.0] * 24,
        }
    )
    instrument = m15.Instrument("PEER", None, "UTC", 570, 750, 0.0)  # type: ignore[arg-type]
    features = screen.peer_features(frame, instrument)
    assert features["2023-01-03"]["gap_atr"] == pytest.approx(1.0)
    assert features["2023-01-03"]["impulse_atr"] == pytest.approx(0.3)


def test_holdout_receipt_must_pass_and_match(tmp_path) -> None:
    receipt = tmp_path / "validation.json"
    receipt.write_text(
        json.dumps(
            {
                "status": "VALIDATION_PASS",
                "selected_filter": "sp500_impulse_025_align",
                "year": 2024,
            }
        ),
        encoding="utf-8",
    )
    screen._load_validation_receipt(receipt, "sp500_impulse_025_align")
    with pytest.raises(ValueError, match="does not match"):
        screen._load_validation_receipt(receipt, "ws30_impulse_025_align")


def test_validation_gate() -> None:
    assert screen.validation_pass({"trades": 40, "net_r": 1.0, "profit_factor": 1.10})
    assert not screen.validation_pass({"trades": 39, "net_r": 1.0, "profit_factor": 2.0})
