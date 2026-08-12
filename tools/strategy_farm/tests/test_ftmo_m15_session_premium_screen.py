from __future__ import annotations

from tools.strategy_farm.portfolio import ftmo_m15_session_premium_screen as screen


def test_score_does_not_use_holdout() -> None:
    row = {
        "metrics": {
            "dev_2018_2022": {"profit_factor": 1.25},
            "validation_2023": {"profit_factor": 1.10},
            "holdout_2024_2025": {"profit_factor": 50.0},
        }
    }
    assert screen.score(row) == 1.10
