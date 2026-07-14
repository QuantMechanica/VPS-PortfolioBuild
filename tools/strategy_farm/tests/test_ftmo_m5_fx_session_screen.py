from __future__ import annotations

from pathlib import Path

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m5_fx_session_screen as screen


def test_fixed_session_resolves_dual_touch_stop_first() -> None:
    frame = pd.DataFrame(
        {
            "open": [100.0, 100.0, 100.0, 100.0],
            "high": [100.0, 102.0, 100.0, 100.0],
            "low": [100.0, 99.0, 100.0, 100.0],
            "close": [100.0, 100.0, 100.0, 100.0],
            "atr288": [1.0, 1.0, 1.0, 1.0],
            "utc": pd.to_datetime(
                ["2024-01-02T07:55:00Z", "2024-01-02T08:00:00Z", "2024-01-02T08:05:00Z", "2024-01-02T08:10:00Z"],
                utc=True,
            ),
        }
    )
    instrument = screen.Instrument("TEST", Path("unused.csv"), 0.1)
    spec = screen.SessionSpec("test", "UTC", 8 * 60, 8 * 60 + 15)
    trades = screen.fixed_session_trades(
        frame,
        instrument,
        spec,
        stop_range_multiple=1.0,
        target_r=2.0,
        direction=1,
    )
    assert len(trades) == 1
    assert trades[0].r_multiple == -1.1
    assert trades[0].exit_reason == "test:stop_pessimistic"


def test_score_does_not_use_holdout() -> None:
    row = {
        "metrics": {
            "dev_2018_2022": {"profit_factor": 1.30},
            "validation_2023": {"profit_factor": 1.15},
            "holdout_2024_2025": {"profit_factor": 99.0},
        }
    }
    assert screen.score(row) == 1.15
