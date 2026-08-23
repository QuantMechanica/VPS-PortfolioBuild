from __future__ import annotations

import sqlite3

from tools.strategy_farm import q09_ftmo_recommendation as surface
from tools.strategy_farm import render_cockpit
from tools.strategy_farm import render_cockpit_v2
from tools.strategy_farm.dashboards import render_dashboards


def test_projection_reuses_admission_results_and_emits_explicit_yes_no(
    tmp_path, monkeypatch
) -> None:
    connection = sqlite3.connect(tmp_path / "farm.sqlite")
    connection.executescript(
        """
        CREATE TABLE work_items (
            ea_id TEXT, symbol TEXT, phase TEXT, status TEXT
        );
        INSERT INTO work_items VALUES
          ('QM5_1','EURUSD.DWX','Q09_NEWS','done'),
          ('QM5_2','USDJPY.DWX','Q09_NEWS','done');
        """
    )

    def fake_admission(_connection, ea_id, symbol):
        admitted = ea_id == "QM5_1"
        return {
            "admitted": admitted,
            "reason_code": "FTMO_Q09_ADMITTED" if admitted else "FTMO_Q09_NOT_CONFIG_LOCKED",
            "q09_news_work_item_id": f"q09-{ea_id}",
            "chosen_temporal": "PRE60" if admitted else None,
        }

    monkeypatch.setattr(surface, "evaluate_ftmo_q09_admission", fake_admission)
    try:
        result = surface.collect(connection)
    finally:
        connection.close()

    assert result["available"] is True
    assert result["criteria_source"].endswith("evaluate_ftmo_q09_admission")
    assert result["total"] == 2
    assert result["suitable_yes"] == 1
    assert result["suitable_no"] == 1
    assert [row["recommendation"] for row in result["rows"]] == ["YES", "NO"]
    assert result["reason_counts"] == {
        "FTMO_Q09_ADMITTED": 1,
        "FTMO_Q09_NOT_CONFIG_LOCKED": 1,
    }


def _recommendation_fixture():
    return {
        "schema_version": surface.SCHEMA_VERSION,
        "available": True,
        "criteria_source": "portfolio.ftmo_q09_admission.evaluate_ftmo_q09_admission",
        "total": 2,
        "suitable_yes": 1,
        "suitable_no": 1,
        "reason_counts": {"FTMO_Q09_ADMITTED": 1, "FTMO_Q09_NOT_CONFIG_LOCKED": 1},
        "rows": [
            {
                "ea_id": "QM5_1",
                "symbol": "EURUSD.DWX",
                "suitable": True,
                "recommendation": "YES",
                "reason_code": "FTMO_Q09_ADMITTED",
                "q09_news_work_item_id": "q09-1",
                "chosen_temporal": "PRE60",
            },
            {
                "ea_id": "QM5_1",
                "symbol": "USDJPY.DWX",
                "suitable": False,
                "recommendation": "NO",
                "reason_code": "FTMO_Q09_NOT_CONFIG_LOCKED",
                "q09_news_work_item_id": "q09-2",
                "chosen_temporal": None,
            },
        ],
        "error": None,
    }


def test_aggregate_cockpit_and_mission_control_render_yes_no() -> None:
    recommendation = _recommendation_fixture()
    snapshot = {
        "schema_version": render_cockpit.PIPELINE_COHORT_SCHEMA_VERSION,
        "available": True,
        "transitions": [],
        "q09_arms": [],
        "q09_both_authenticated": 0,
        "q09_upstream_pass": 0,
        "q10_historical_visible": 0,
        "q10_current_contract_bound": 0,
        "q09_ftmo_recommendation": recommendation,
    }
    cockpit_html = render_cockpit.render_pipeline_cohorts(snapshot)
    mission_control_html = render_cockpit_v2._render_q09_ftmo_recommendation(
        {"q09_ftmo_recommendation": recommendation}
    )

    for html in (cockpit_html, mission_control_html):
        assert "FTMO" in html
        assert "1 JA" in html
        assert "1 NEIN" in html
        assert "presentation" in html.lower() or "Präsentation" in html


def test_strategy_archive_detail_renders_pair_level_recommendation() -> None:
    html = render_dashboards._render_ftmo_q09_detail(
        {"q09_ftmo_recommendation": _recommendation_fixture()}
    )

    assert "Q09 News Impact · FTMO geeignet" in html
    assert "EURUSD.DWX" in html and "USDJPY.DWX" in html
    assert ">JA<" in html and ">NEIN<" in html
    assert "FTMO_Q09_ADMITTED" in html
    assert "keine Challenge-, Deployment- oder AutoTrading-Autorität" in html
