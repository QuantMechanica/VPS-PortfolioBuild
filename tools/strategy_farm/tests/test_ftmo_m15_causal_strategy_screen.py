from __future__ import annotations

from pathlib import Path

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as screen


def test_dual_oco_touch_is_a_pessimistic_loss() -> None:
    local_date = pd.Timestamp("2025-01-02").date()
    frame = pd.DataFrame(
        [
            {
                "open": 95.0,
                "high": 100.0,
                "low": 90.0,
                "close": 96.0,
                "utc": pd.Timestamp("2025-01-02T09:00:00Z"),
                "local_date": local_date,
                "year": 2025,
                "weekday": 3,
                "minute": 540,
                "atr56": 10.0,
            },
            {
                "open": 96.0,
                "high": 102.0,
                "low": 88.0,
                "close": 95.0,
                "utc": pd.Timestamp("2025-01-02T09:15:00Z"),
                "local_date": local_date,
                "year": 2025,
                "weekday": 3,
                "minute": 555,
                "atr56": 10.0,
            },
        ]
    )
    instrument = screen.Instrument("TEST", Path("unused"), "UTC", 540, 570, 0.0)

    trades = screen.opening_range_breakout(
        frame,
        instrument,
        range_bars=1,
        active_bars=1,
        buffer_atr=0.0,
        max_range_atr=2.0,
        target_r=5.0,
    )

    assert len(trades) == 1
    assert trades[0].r_multiple == -1.0
    assert trades[0].exit_reason == "orb:stop"


def test_preholdout_score_does_not_read_holdout() -> None:
    row = {
        "metrics": {
            "dev_2018_2022": {"profit_factor": 1.4},
            "validation_2023": {"profit_factor": 1.2},
            "holdout_2024_2025": {"profit_factor": 99.0},
        }
    }
    assert screen.preholdout_score(row) == 1.2


def test_default_sessions_are_explicit_cash_market_windows(tmp_path: Path) -> None:
    instruments = {item.symbol: item for item in screen.default_instruments(tmp_path)}
    assert instruments["GDAXI.DWX"].session_start_minute == 540
    assert instruments["NDX.DWX"].session_start_minute == 570
    assert instruments["XAUUSD.DWX"].session_start_minute == 510
