import pytest

from tools.strategy_farm.portfolio.ftmo_calendar_launch_holdout import frozen_gate


def test_frozen_gate_requires_exact_preholdout_winner() -> None:
    selection = {
        "status": "PREHOLDOUT_SURVIVOR",
        "selected_winner": {"gate": "month_02"},
        "selection_contract": {"selection_uses_sealed_years": False},
    }

    assert frozen_gate(selection, "month_02")
    with pytest.raises(ValueError, match="does not match"):
        frozen_gate(selection, "month_03")
