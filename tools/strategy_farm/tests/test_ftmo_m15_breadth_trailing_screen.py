from __future__ import annotations

import numpy as np
import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_breadth_trailing_screen as subject


def test_parameter_grid_matches_predeclaration() -> None:
    rows = subject.parameter_grid()
    assert len(rows) == 648
    assert {row["trail_lookback_bars"] for row in rows} == {2, 4}
    assert {row["hold_bars"] for row in rows} == {8, 16, 24}


def test_trailing_stop_from_completed_bar_only_applies_next_bar() -> None:
    panel = pd.DataFrame(
        {
            "SP500.DWX:open": [100.0, 108.0],
            "SP500.DWX:high": [110.0, 109.0],
            "SP500.DWX:low": [95.0, 104.0],
            "SP500.DWX:close": [108.0, 105.0],
        }
    )
    result = subject.simulate_trailing_leg(
        panel,
        symbol="SP500.DWX",
        path=[0, 1],
        entry_index=0,
        side=1,
        atr=10.0,
        initial_stop_atr=1.0,
        trail_distance_atr=0.5,
        trail_lookback_bars=1,
    )
    assert np.isclose(result, 0.4)  # 105 stop minus one point round-trip cost


def test_preholdout_gate_requires_four_positive_development_years() -> None:
    metrics = {
        "dev_2018_2022": {"trades": 250, "net_r": 10.0, "profit_factor": 1.2},
        "validation_2023": {"trades": 40, "net_r": 2.0, "profit_factor": 1.1},
        "annual": {str(year): {"net_r": 1.0} for year in range(2018, 2023)},
    }
    assert subject.preholdout_pass(metrics)
    metrics["annual"]["2018"]["net_r"] = -1.0
    metrics["annual"]["2019"]["net_r"] = -1.0
    assert not subject.preholdout_pass(metrics)
