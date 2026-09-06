from tools.strategy_farm.chart_panel_acceptance import static_acceptance


def test_chart_panel_static_contract():
    result = static_acceptance()
    assert result["status"] == "PASS", result
    assert all(result["checks"].values())
