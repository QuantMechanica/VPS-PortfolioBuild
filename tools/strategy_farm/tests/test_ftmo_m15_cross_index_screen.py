from __future__ import annotations

import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_cross_index_screen as screen


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
