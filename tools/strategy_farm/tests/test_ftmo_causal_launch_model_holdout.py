import pytest

from tools.strategy_farm.portfolio.ftmo_causal_launch_model_holdout import frozen_selection
from tools.strategy_farm.portfolio.ftmo_causal_launch_model_screen import fit_ridge


def _selection() -> dict:
    model = fit_ridge([{"x": 0.0}, {"x": 1.0}], [0.0, 1.0], 1.0)
    return {
        "status": "PREHOLDOUT_SURVIVOR",
        "selection_contract": {"selection_uses_sealed_years": False},
        "selected_winner": {
            "model_id": "frozen",
            "score_mode": "joint",
            "score_threshold": 0.5,
            "frozen_models": {"joint": model.to_json()},
        },
    }


def test_frozen_selection_accepts_exact_winner() -> None:
    mode, cutoff, models = frozen_selection(_selection(), "frozen")

    assert mode == "joint"
    assert cutoff == 0.5
    assert set(models) == {"joint"}


def test_frozen_selection_rejects_model_substitution() -> None:
    with pytest.raises(ValueError, match="does not match"):
        frozen_selection(_selection(), "different")


def test_frozen_selection_requires_holdout_exclusion_proof() -> None:
    selection = _selection()
    selection["selection_contract"]["selection_uses_sealed_years"] = True

    with pytest.raises(ValueError, match="does not prove"):
        frozen_selection(selection, "frozen")
