from __future__ import annotations

import gc
import weakref
from pathlib import Path

import numpy as np
import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m5_fx_session_screen as screen


def _session_frame() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "open": [100.0, 101.0, 102.0, 103.0],
            "high": [100.0, 102.0, 103.0, 104.0],
            "low": [100.0, 99.0, 101.0, 102.0],
            "close": [100.0, 101.0, 102.0, 103.0],
            "atr288": [1.0, 1.0, 1.0, 1.0],
            "utc": pd.to_datetime(
                [
                    "2024-01-02T07:55:00Z",
                    "2024-01-02T08:00:00Z",
                    "2024-01-02T08:05:00Z",
                    "2024-01-02T08:10:00Z",
                ],
                utc=True,
            ),
        }
    )


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


def test_frame_caches_reject_stale_entries_for_a_reused_identity() -> None:
    frame = _session_frame()
    stale_frame = _session_frame().iloc[:1].copy()
    spec = screen.SessionSpec("test", "UTC", 8 * 60, 8 * 60 + 15)
    frame_id = id(frame)
    session_key = (frame_id, spec.timezone, spec.entry_minute, spec.exit_minute)
    screen.frame_cache.store_for_frame(
        screen._ARRAY_CACHE,
        frame_id,
        stale_frame,
        {"open": np.array([-999.0])},
    )
    screen.frame_cache.store_for_frame(
        screen._SESSION_CACHE,
        session_key,
        stale_frame,
        [[99]],
    )

    try:
        np.testing.assert_array_equal(
            screen._values(frame, "open"), frame["open"].to_numpy()
        )
        assert screen.session_days(frame, spec) == [[1, 2, 3]]

        del stale_frame
        gc.collect()

        assert screen._ARRAY_CACHE[frame_id][0]() is frame
        assert screen._SESSION_CACHE[session_key][0]() is frame
    finally:
        screen._ARRAY_CACHE.clear()
        screen._SESSION_CACHE.clear()


def test_frame_caches_release_entries_when_frame_is_collected() -> None:
    frame = _session_frame()
    spec = screen.SessionSpec("test", "UTC", 8 * 60, 8 * 60 + 15)
    frame_id = id(frame)
    session_key = (frame_id, spec.timezone, spec.entry_minute, spec.exit_minute)
    frame_ref = weakref.ref(frame)

    screen._values(frame, "open")
    screen.session_days(frame, spec)
    assert frame_id in screen._ARRAY_CACHE
    assert session_key in screen._SESSION_CACHE

    del frame
    gc.collect()

    assert frame_ref() is None
    assert frame_id not in screen._ARRAY_CACHE
    assert session_key not in screen._SESSION_CACHE
