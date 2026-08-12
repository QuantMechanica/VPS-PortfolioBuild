from tools.strategy_farm.portfolio.ftmo_shadow_filter_screen import robust_improvement


def metrics(threshold: float, adverse: float) -> dict:
    return {
        "threshold_fill": {"pass_pct": threshold},
        "adverse_bar_fill": {"pass_pct": adverse},
    }


def test_robust_improvement_requires_every_split_and_fill() -> None:
    control = metrics(50.0, 45.0)
    assert robust_improvement(
        metrics(52.0, 47.0),
        metrics(53.0, 48.0),
        control,
        control,
        minimum_improvement_pct=1.0,
    )
    assert not robust_improvement(
        metrics(52.0, 45.5),
        metrics(53.0, 48.0),
        control,
        control,
        minimum_improvement_pct=1.0,
    )
