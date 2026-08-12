from __future__ import annotations

from tools.strategy_farm.portfolio import ftmo_incumbent_weekday_filter as subject


def test_qualifying_weekday_requires_four_negative_years_and_density() -> None:
    stats = {
        0: {
            2018: {"trades": 2, "net": -1.0},
            2019: {"trades": 3, "net": -2.0},
            2020: {"trades": 2, "net": -3.0},
            2021: {"trades": 4, "net": -4.0},
            2022: {"trades": 2, "net": 1.0},
        },
        1: {
            2018: {"trades": 2, "net": -1.0},
            2019: {"trades": 1, "net": -2.0},
            2020: {"trades": 2, "net": -3.0},
            2021: {"trades": 4, "net": -4.0},
            2022: {"trades": 2, "net": -5.0},
        },
    }
    assert subject.qualifying_weekdays(stats) == [0]


def test_apply_exclusions_preserves_weights_and_untouched_sleeves() -> None:
    manifest = {
        "sleeves": [
            {"ea_id": 1, "symbol": "A.DWX"},
            {"ea_id": 2, "symbol": "B.DWX"},
        ],
        "scenarios": [{"name": "x", "weights": {"1:A.DWX": 0.4, "2:B.DWX": 0.6}}],
    }
    output = subject.apply_exclusions(manifest, {"1:A.DWX": [4, 0]})
    assert output["sleeves"][0]["entry_filter_excluded_weekdays"] == [0, 4]
    assert "entry_filter" not in output["sleeves"][1]
    assert output["scenarios"] == manifest["scenarios"]
