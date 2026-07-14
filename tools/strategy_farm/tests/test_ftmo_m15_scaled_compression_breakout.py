from __future__ import annotations

import datetime as dt
import json

import pandas as pd
import pytest

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_m15_scaled_compression_breakout as screen


def _frame() -> pd.DataFrame:
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    times = pd.date_range("2023-01-03 09:30", periods=12, freq="15min", tz="UTC")
    high = [101.0] * 12
    low = [99.0] * 12
    close = [100.0] * 12
    close[4] = 102.0
    open_ = [100.0] * 12
    open_[5] = 102.0
    high[5:] = [106.0] * 7
    return pd.DataFrame(
        {
            "open": open_,
            "high": high,
            "low": low,
            "close": close,
            "utc": times,
            "local_date": [dt.date(2023, 1, 3)] * 12,
            "year": [2023] * 12,
            "weekday": [1] * 12,
            "minute": [570 + 15 * index for index in range(12)],
            "atr56": [1.0] * 12,
        }
    )


def test_sqrt_scaled_range_accepts_two_atr_four_bar_range() -> None:
    instrument = m15.Instrument("TEST", None, "UTC", 570, 750, 0.0)  # type: ignore[arg-type]
    trades = screen.scaled_trades(
        _frame(),
        instrument,
        range_bars=4,
        active_bars=4,
        max_scaled_range=1.0,
        breakout_buffer_atr=0.05,
        stop_atr=1.0,
        target_r=2.0,
    )
    assert len(trades) == 1
    assert trades[0].entry_time_utc == "2023-01-03T10:45:00+00:00"


def test_parameter_grid_matches_predeclaration() -> None:
    assert len(list(screen.parameter_grid())) == 96


def test_receipt_guards(tmp_path) -> None:
    research = tmp_path / "research.json"
    research.write_text(json.dumps({"status": "NO_RESEARCH_SURVIVOR"}), encoding="utf-8")
    with pytest.raises(ValueError, match="RESEARCH_SURVIVOR_FOUND"):
        screen.load_research_receipt(research)

    validation = tmp_path / "validation.json"
    validation.write_text(
        json.dumps(
            {
                "status": "VALIDATION_FAIL",
                "year": 2024,
                "selected_candidate": {"symbol": "NDX.DWX", "parameters": {"x": 1}},
            }
        ),
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="VALIDATION_PASS"):
        screen.load_validation_receipt(validation)


def test_stage_gate() -> None:
    assert screen.stage_pass({"trades": 25, "net_r": 1.0, "profit_factor": 1.10})
    assert not screen.stage_pass({"trades": 24, "net_r": 1.0, "profit_factor": 2.0})
