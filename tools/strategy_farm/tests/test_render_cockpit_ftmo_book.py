from __future__ import annotations

import json
from pathlib import Path

from tools.strategy_farm import render_cockpit_v2 as renderer


FIXTURE = Path(__file__).parent / "fixtures" / "ftmo_book_current_v1.json"


def test_load_ftmo_book_current_binds_v1_fixture() -> None:
    read_model = renderer.load_ftmo_book_current(FIXTURE)

    assert read_model["present"] is True
    assert read_model["error"] is None
    assert read_model["payload"]["schema"] == renderer.FTMO_BOOK_STATE_SCHEMA
    assert len(read_model["payload"]["sleeves"]) == 2


def test_ftmo_book_panel_renders_required_account_level_fields() -> None:
    read_model = renderer.load_ftmo_book_current(FIXTURE)
    page = renderer._render_ftmo_book(read_model)

    assert 'id="ftmo-book"' in page
    assert "FTMO BOOK" in page
    assert "QM5_10403" in page and "XAUUSD" in page and "D1" in page
    assert "0123456789ab" in page
    assert "H-V4 / QM5_41485" in page and "TEST" in page
    assert "31,90 USD/bd" in page and "0,1260 R/bd" in page
    assert "1,306 trades/bd" in page and "85,00 %" in page
    assert "-5.740,00" in page
    assert "4.71 % / 4710 USD" in page and "8.92 % / 8920 USD" in page
    assert "10403/41219" in page and "fail-together clusters 1" in page
    assert "P challenge 96,34 %" in page
    assert "payout LCB 88,39 %" in page and "median 487,0 bd" in page
    assert "session-flat, low-overlap, high-density New-York sleeve" in page


def test_unmeasured_v1_fields_are_explicit_and_never_fabricated(tmp_path: Path) -> None:
    payload = json.loads(FIXTURE.read_text(encoding="utf-8"))
    payload["demo_cycle"].pop("rule_headroom")
    payload["sleeves"][0].pop("sha256")
    path = tmp_path / "ftmo_book_current.json"
    path.write_text(json.dumps(payload), encoding="utf-8")

    page = renderer._render_ftmo_book(renderer.load_ftmo_book_current(path))

    assert page.count("NOT_YET_MEASURABLE") >= 3
    assert "daily 0" not in page
    assert "maximum 0" not in page


def test_missing_invalid_and_untrusted_state_fail_visible_and_escape(tmp_path: Path) -> None:
    missing = renderer.load_ftmo_book_current(tmp_path / "missing.json")
    missing_page = renderer._render_ftmo_book(missing)
    assert "EVIDENCE_MISSING" in missing_page and "state file missing" in missing_page

    invalid_path = tmp_path / "invalid.json"
    invalid_path.write_text('{"schema":"wrong"}', encoding="utf-8")
    invalid_page = renderer._render_ftmo_book(
        renderer.load_ftmo_book_current(invalid_path)
    )
    assert "schema mismatch" in invalid_page

    payload = json.loads(FIXTURE.read_text(encoding="utf-8"))
    payload["strongest_missing_behavior"] = "<script>alert(1)</script>"
    untrusted_path = tmp_path / "untrusted.json"
    untrusted_path.write_text(json.dumps(payload), encoding="utf-8")
    escaped_page = renderer._render_ftmo_book(
        renderer.load_ftmo_book_current(untrusted_path)
    )
    assert "<script>" not in escaped_page
    assert "&lt;script&gt;alert(1)&lt;/script&gt;" in escaped_page


def test_section_g_and_sleeve_money_sidecar_render_verbatim(tmp_path: Path) -> None:
    payload = json.loads(FIXTURE.read_text(encoding="utf-8"))
    arm = {
        "status": "PRE_SUNDAY_LIVE_TRIAL",
        "sleeves": [
            {
                "ea_id": 10403,
                "symbol": "XAUUSD",
                "timeframe": "D1",
                "role": "Gold trend",
                "risk_percent": 0.3125,
            }
        ],
        "R_PER_DAY": 0.108484,
        "TRADES_PER_DAY": 1.336323,
        "ACTIVE_DAY_RATIO": 0.867713,
        "P_DAILY_LOSS_BREACH": 0.0,
        "P_MAX_LOSS_BREACH": 0.0202,
        "P_FIRST_NET_FTMO_PAYOUT_LCB": 0.8668,
        "MEDIAN_CHALLENGE_DAYS_BD": 289.0,
        "MEDIAN_FIRST_PAYOUT_DAYS_BD": 489.0,
        "STRONGEST_DEPENDENCE_CLUSTER": ["10403_XAUUSD_D1", "41219_XAUUSD_D1"],
    }
    payload["incumbent"] = arm
    payload["shadow"] = {**arm, "status": "SHADOW_EQUALS_INCUMBENT"}
    payload["delta_shadow_vs_incumbent"] = {
        "DELTA_P_FIRST_NET_FTMO_PAYOUT_LCB": 0.0,
        "DELTA_P_CHALLENGE_PASS": 0.0,
        "DELTA_P_DAILY_LOSS_BREACH": 0.0,
        "DELTA_P_MAX_LOSS_BREACH": 0.0,
        "DELTA_EXPECTED_TIME_TO_CHALLENGE": 0.0,
        "DELTA_TRADE_DENSITY": 0.0,
        "DELTA_MAX_DRAWDOWN": 0.0,
        "DELTA_COST_DRAG": 0.0,
        "note": "shadow == incumbent",
    }
    payload["strongest_missing_book_behavior"] = "New-York index cash-session return engine"
    payload["financing"] = {"label": "FINANCED"}
    state = tmp_path / "book.json"
    state.write_text(json.dumps(payload), encoding="utf-8")

    attribution_payload = {
        "schema": renderer.FTMO_SLEEVE_ATTRIBUTION_SCHEMA,
        "book_id": payload["book_id"],
        "generated_at_utc": "2026-09-21T20:00:00Z",
        "day_count": 4,
        "latest_prague_day": "2026-09-21",
        "unattributed_deal_count": 1,
        "reconciliation_ok": True,
        "reconciliation": {
            "account_realised_usd": 120.61,
            "roster_realised_usd": 83.93,
            "unattributed_realised_usd": 36.68,
            "difference_usd": 0.0,
        },
        "sleeves": [
            {
                "magic": 114220004,
                "ea_id": 11422,
                "symbol": "USDCAD",
                "realised_usd": -37.5,
                "latest_floating_usd": 130.1,
                "trade_count": 1,
            }
        ],
        "days": [],
        "unattributed": [],
    }
    attribution = tmp_path / "attribution.json"
    attribution.write_text(json.dumps(attribution_payload), encoding="utf-8")

    page = renderer._render_ftmo_book(
        renderer.load_ftmo_book_current(state),
        renderer.load_ftmo_sleeve_attribution(attribution),
    )

    assert "OWNER section G" in page and "INCUMBENT" in page and "SHADOW" in page
    assert "Gold trend" in page and "0,31250 %" in page
    assert "86,68 %" in page and "489,0" in page
    assert "shadow == incumbent" in page
    assert "New-York index cash-session return engine" in page and "FINANCED" in page
    assert "SLEEVE P&amp;L" in page and "114220004" in page
    assert "120,61 USD" in page and "83,93 USD" in page and "36,68 USD" in page
    assert "Unattributed deals:</b> 1" in page


def test_missing_attribution_sidecar_is_fail_visible(tmp_path: Path) -> None:
    model = renderer.load_ftmo_sleeve_attribution(tmp_path / "missing.json")
    page = renderer._render_ftmo_attribution(model)
    assert "EVIDENCE_MISSING" in page and "state file missing" in page
