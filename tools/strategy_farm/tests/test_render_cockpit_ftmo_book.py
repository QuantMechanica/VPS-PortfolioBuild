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
