from __future__ import annotations

from datetime import date
from pathlib import Path

import pandas as pd
import pytest

from tools.strategy_farm.portfolio import ftmo_fx_cross_sectional_london_screen as screen


def test_completed_return_uses_only_days_before_entry() -> None:
    closes = {
        date(2023, 1, 2): 1.0,
        date(2023, 1, 3): 2.0,
        date(2023, 1, 4): 100.0,
    }
    assert screen.completed_return(closes, date(2023, 1, 4), 1) == pytest.approx(1.0)
    assert screen.completed_return(closes, date(2023, 1, 3), 1) is None


def test_daily_leader_uses_absolute_signal_and_symbol_tie_break() -> None:
    rows = [
        screen.Opportunity("Z", "2023-01-03", 2023, "x", 0, (0,), -0.02),
        screen.Opportunity("A", "2023-01-03", 2023, "x", 0, (0,), 0.02),
    ]
    assert screen.select_daily_leader(rows, 2).symbol == "A"
    assert screen.select_daily_leader(rows[:1], 2) is None


def test_same_bar_dual_touch_is_charged_as_stop() -> None:
    frame = pd.DataFrame(
        {
            "open": [100.0],
            "high": [102.0],
            "low": [98.0],
            "close": [101.0],
            "atr288_prior": [1.0],
        }
    )
    opportunity = screen.Opportunity(
        "TEST", "2023-01-03", 2023, "2023-01-03T08:00:00+00:00", 0, (0,), 0.01
    )
    instrument = screen.Instrument("TEST", Path("unused.csv"), 0.1)
    trade = screen.simulate_opportunity(
        opportunity,
        frame,
        instrument,
        direction="momentum",
        stop_atr_multiple=1.0,
        target_r=1.0,
    )
    assert trade is not None
    assert trade.r_multiple == pytest.approx(-1.1)
    assert trade.exit_reason.endswith("stop_pessimistic")


def test_winner_selection_is_deterministic() -> None:
    def row(direction: str) -> dict:
        return {
            "parameters": {
                "lookback": 1,
                "direction": direction,
                "stop_atr_multiple": 8.0,
                "target_r": 1.0,
            },
            "metrics": {
                "development_2018_2022": {"profit_factor": 1.2, "trades": 900},
                "validation_2023": {"profit_factor": 1.1},
            },
            "passes_preholdout_gate": True,
        }

    winner = screen.select_winner([row("momentum"), row("mean_reversion")])
    assert winner is not None
    assert winner["parameters"]["direction"] == "mean_reversion"
