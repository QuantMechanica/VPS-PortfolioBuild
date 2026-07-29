from __future__ import annotations

import datetime as dt
from pathlib import Path

from tools.strategy_farm import render_cockpit


NOW = dt.datetime(2026, 7, 29, 16, 0, tzinfo=dt.UTC)


def test_cockpit_programme_snapshot_uses_source_repo_and_is_fresh() -> None:
    snapshot = render_cockpit.pipeline_books_program_snapshot(now_utc=NOW)

    assert snapshot["state"] == "FRESH"
    assert snapshot["valid"] is True
    assert len(snapshot["work_packages"]) == 9


def test_programme_panel_renders_all_required_contracts() -> None:
    snapshot = render_cockpit.pipeline_books_program_snapshot(now_utc=NOW)
    page = render_cockpit.render_pipeline_books_program(snapshot)

    assert "PROGRAM SOURCE FRESH" in page
    assert "W0" in page and "W8" in page
    assert "SOURCE_IMPLEMENTED_WITH_OWNER_RESIDUALS" in page
    assert "SHADOW_EVALUATOR_SOURCE_IMPLEMENTED_NO_GO" in page
    assert "FACTORY</b> INTENTIONALLY_OFF" in page
    assert "NO ACTION AUTHORIZED" in page
    assert "Q08 V3 // EVIDENCE" in page
    assert "SUPPORTED · CONDITIONAL · INSUFFICIENT · CONTRADICTED · INVALID" in page
    assert "DXZ_BETTER_BOOK_V1" in page
    assert "FTMO_2S_100K_SWING_V1" in page
    assert "GREEN PASS" in page
    assert f'{snapshot["verification_lanes"]["green"]["passed"]} passed' in page
    assert "EXTERNAL RESIDUAL EXPECTED_FAIL_CLOSED" in page
    assert "DXZ10939 real spec binding" in page
    assert "OWNER BLOCKERS" in page
    assert "06 OPEN" in page
    assert "OWNER-FTMO-GOVERNOR-MONEY" in page


def test_missing_or_invalid_programme_never_renders_clear_or_pass() -> None:
    page = render_cockpit.render_pipeline_books_program(
        {
            "state": "INVALID",
            "valid": False,
            "error": "plan hash mismatch",
            "work_packages": [],
            "owner_blockers": [],
        }
    )

    assert "PROGRAM SOURCE INVALID" in page
    assert "NO TRUSTED W0–W8 STATUS AVAILABLE" in page
    assert "plan hash mismatch" in page
    assert "PROGRAM SOURCE FRESH" not in page
    assert "GREEN PASS" not in page
    assert "00 OPEN" not in page


def test_stale_programme_is_visibly_non_fresh_but_keeps_verified_detail() -> None:
    snapshot = render_cockpit.pipeline_books_program_snapshot(
        now_utc=dt.datetime(2026, 8, 6, 15, 30, tzinfo=dt.UTC)
    )
    page = render_cockpit.render_pipeline_books_program(snapshot)

    assert snapshot["state"] == "STALE"
    assert "PROGRAM SOURCE STALE" in page
    assert "programme status is" in page
    assert "W0" in page and "W8" in page


def test_owner_surface_contains_all_verified_programme_blockers() -> None:
    snapshot = render_cockpit.pipeline_books_program_snapshot(now_utc=NOW)
    rows = render_cockpit.pipeline_books_owner_decision_rows(snapshot)

    assert len(rows) == 6
    assert all(row["cat"] == "PROGRAM" for row in rows)
    assert all(row["alert"] is True for row in rows)
    assert any("FTMO" in row["title"] for row in rows)


def test_owner_surface_shows_source_failure_instead_of_no_decisions() -> None:
    rows = render_cockpit.pipeline_books_owner_decision_rows(
        {"state": "MISSING", "error": "status source missing", "owner_blockers": []}
    )

    assert rows == [
        {
            "cat": "PROGRAM STATUS",
            "title": "Pipeline Books source MISSING",
            "detail": "status source missing",
            "due": "",
            "alert": True,
        }
    ]


def test_programme_renderer_escapes_untrusted_error_text() -> None:
    page = render_cockpit.render_pipeline_books_program(
        {
            "state": "INVALID",
            "valid": False,
            "error": "<script>alert(1)</script>",
            "work_packages": [],
            "owner_blockers": [],
        }
    )

    assert "<script>" not in page
    assert "&lt;script&gt;" in page


def test_cockpit_database_reads_are_query_only() -> None:
    source = Path(render_cockpit.__file__).read_text(encoding="utf-8")
    assert 'sqlite3.connect(str(DB))' not in source
    assert source.count('?mode=ro", uri=True') >= 4
    assert source.count('PRAGMA query_only=ON') >= 3
