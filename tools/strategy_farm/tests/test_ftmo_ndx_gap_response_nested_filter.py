from tools.strategy_farm.portfolio import ftmo_intraday_candidate_screen as base
from tools.strategy_farm.portfolio import ftmo_ndx_gap_response_nested_filter as screen


def _trade(year: int, r_multiple: float) -> base.Trade:
    return base.Trade(
        entry_time_utc=f"{year}-01-03T10:00:00+00:00",
        local_date=f"{year}-01-03",
        year=year,
        side=1,
        r_multiple=r_multiple,
        exit_reason="test",
    )


def test_filter_metrics_uses_declared_research_years() -> None:
    trades = [_trade(year, 1.0) for year in screen.RESEARCH_YEARS]
    metrics = screen.filter_metrics(trades)
    assert set(metrics["annual"]) == {str(year) for year in screen.RESEARCH_YEARS}
    assert metrics["positive_years"] == len(screen.RESEARCH_YEARS)


def test_frozen_parameters_match_parent_near_miss() -> None:
    assert screen.FROZEN_PARAMETERS["mode"] == "continuation"
    assert screen.FROZEN_PARAMETERS["gap_atr"] == 1.0
    assert screen.FROZEN_PARAMETERS["response_atr"] == 0.15
