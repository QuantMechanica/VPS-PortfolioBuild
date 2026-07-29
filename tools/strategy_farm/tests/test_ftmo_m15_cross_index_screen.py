from __future__ import annotations

import gc
import weakref

import numpy as np
import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_cross_index_screen as screen


def _session_panel() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "weekday": [1, 1],
            "local_date": ["2024-01-02", "2024-01-02"],
            "minute": [screen.SESSION_START_MINUTE, screen.SESSION_START_MINUTE + 15],
        }
    )


def test_leg_stop_is_pessimistic_when_target_also_touches() -> None:
    panel = pd.DataFrame(
        [
            {
                "NDX.DWX:open": 100.0,
                "NDX.DWX:high": 130.0,
                "NDX.DWX:low": 80.0,
                "NDX.DWX:close": 110.0,
            }
        ]
    )
    result = screen.simulate_leg(
        panel,
        symbol="NDX.DWX",
        path=[0],
        entry_index=0,
        side=1,
        atr=10.0,
        stop_atr=1.0,
        target_r=2.0,
    )
    assert result == -1.4


def test_score_ignores_holdout() -> None:
    row = {
        "metrics": {
            "dev_2018_2022": {"profit_factor": 1.3},
            "validation_2023": {"profit_factor": 1.1},
            "holdout_2024_2025": {"profit_factor": 100.0},
        }
    }
    assert screen.score(row) == 1.1


def test_frame_caches_reject_stale_entries_for_a_reused_identity() -> None:
    panel = _session_panel()
    stale_panel = _session_panel().iloc[:1].copy()
    panel_id = id(panel)
    screen.frame_cache.store_for_frame(
        screen._ARRAY_CACHE,
        panel_id,
        stale_panel,
        {"minute": np.array([-1])},
    )
    screen.frame_cache.store_for_frame(
        screen._SESSION_DAY_CACHE,
        panel_id,
        stale_panel,
        [[99]],
    )

    try:
        assert screen.session_days(panel) == [[0, 1]]
        np.testing.assert_array_equal(
            screen._values(panel, "minute"), panel["minute"].to_numpy()
        )

        del stale_panel
        gc.collect()

        assert screen._ARRAY_CACHE[panel_id][0]() is panel
        assert screen._SESSION_DAY_CACHE[panel_id][0]() is panel
    finally:
        screen._ARRAY_CACHE.clear()
        screen._SESSION_DAY_CACHE.clear()


def test_frame_caches_release_entries_when_panel_is_collected() -> None:
    panel = _session_panel()
    panel_id = id(panel)
    panel_ref = weakref.ref(panel)

    screen.session_days(panel)
    assert panel_id in screen._ARRAY_CACHE
    assert panel_id in screen._SESSION_DAY_CACHE

    del panel
    gc.collect()

    assert panel_ref() is None
    assert panel_id not in screen._ARRAY_CACHE
    assert panel_id not in screen._SESSION_DAY_CACHE
