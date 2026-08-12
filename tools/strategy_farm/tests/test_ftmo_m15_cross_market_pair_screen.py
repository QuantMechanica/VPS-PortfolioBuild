from __future__ import annotations

from tools.strategy_farm.portfolio import ftmo_m15_cross_market_pair_screen as subject


def test_parameter_grid_is_the_predeclared_global_grid() -> None:
    rows = list(subject.parameter_grid())
    assert len(rows) == 972
    assert {tuple(row["pair"]) for row in rows} == set(subject.PAIRS)
    assert {row["mode"] for row in rows} == {"reversion", "momentum"}


def test_preholdout_gate_requires_four_positive_development_years() -> None:
    metrics = {
        "dev_2018_2022": {"trades": 200, "net_r": 10.0, "profit_factor": 1.2},
        "validation_2023": {"trades": 30, "net_r": 2.0, "profit_factor": 1.11},
        "annual": {str(year): {"net_r": 1.0} for year in range(2018, 2023)},
    }
    assert subject.preholdout_pass(metrics)
    metrics["annual"]["2018"]["net_r"] = -1.0
    metrics["annual"]["2019"]["net_r"] = -1.0
    assert not subject.preholdout_pass(metrics)
