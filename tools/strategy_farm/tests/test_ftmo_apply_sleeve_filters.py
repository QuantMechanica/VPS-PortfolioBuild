import pytest

from tools.strategy_farm.portfolio.ftmo_apply_sleeve_filters import apply_selected_filters


def test_apply_selected_filters_ignores_individual_holdout_verdict() -> None:
    manifest = {
        "status": "BASE",
        "deployment_allowed": False,
        "sleeves": [
            {"ea_id": 1, "symbol": "A.DWX"},
            {"ea_id": 2, "symbol": "B.DWX"},
        ],
    }
    selection = {
        "selection_contract": {"selection_uses_holdout": False},
        "sleeves": [
            {
                "ea_id": 1,
                "symbol": "A.DWX",
                "selected_winner": {"rule": "long_only", "holdout_verdict": "FAIL"},
            },
            {"ea_id": 2, "symbol": "B.DWX", "selected_winner": None},
        ],
    }

    output = apply_selected_filters(manifest, selection)

    assert output["sleeves"][0]["entry_filter"] == "long_only"
    assert "entry_filter" not in output["sleeves"][1]
    assert output["filter_application"] == {"1:A.DWX": "long_only"}
    assert output["status"] == "RESEARCH_ONLY_NO_GO"


def test_apply_selected_filters_requires_holdout_exclusion_proof() -> None:
    with pytest.raises(ValueError, match="does not prove"):
        apply_selected_filters(
            {"sleeves": [{"ea_id": 1, "symbol": "A.DWX"}]},
            {
                "selection_contract": {"selection_uses_holdout": True},
                "sleeves": [],
            },
        )
