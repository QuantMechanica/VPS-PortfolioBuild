from __future__ import annotations

import datetime as dt
from pathlib import Path

from tools.strategy_farm import render_cockpit


NOW = dt.datetime(2026, 7, 30, 10, 0, tzinfo=dt.UTC)


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
    assert "FTMO_RESEARCH_RUNTIME_EVALUATED_STRICT_UNVERIFIED_NO_GO" in page
    assert "FACTORY</b> INTENTIONALLY_OFF" in page
    assert "NO ACTION AUTHORIZED" in page
    assert "Q08 V3 // EVIDENCE" in page
    assert "SUPPORTED · CONDITIONAL · INSUFFICIENT · CONTRADICTED · INVALID" in page
    assert "DXZ_BETTER_BOOK_V1" in page
    assert "FTMO_2S_100K_SWING_V1" in page
    assert "GREEN PASS" in page
    assert f'{snapshot["verification_lanes"]["green"]["passed"]} passed' in page
    assert "EXTERNAL RESIDUAL RESOLVED_PASS" in page
    assert "5/5 sentinels passed" in page
    assert "DXZ10939 real spec binding" in page
    assert "OWNER BLOCKERS" in page
    assert "04 OPEN" in page
    assert "OWNER-FTMO-GOVERNOR-MONEY" in page
    assert "FTMO BOOK 3 // HASH-BOUND RECORDED RESEARCH PROJECTION" in page
    assert "RESEARCH_MODEL_COMPLETE_STRICT_QUALIFICATION_UNVERIFIED" in page
    assert "R0 QM5_9936 USDJPY.DWX 1143 trades / 0 lifecycle mismatches" in page
    assert "R1 QM5_10145 XAUUSD.DWX 291 trades / 0 lifecycle mismatches" in page
    assert "R2 QM5_13108 XTIUSD.DWX 548 trades / 0 lifecycle mismatches" in page
    assert "POLICY BOOTSTRAP · NON-GATE-ELIGIBLE" in page
    assert "67.240%" in page and "44.896%" in page and "33.456%" in page
    assert "NOT SELECTION-SEALED · NON-GATE-ELIGIBLE" in page
    assert "84.31%" in page and "81.37%" in page and "3.92%" in page
    assert "FACTORY / RESTART / MONEY / PURCHASE / DEPLOY = FALSE" in page
    assert "this dashboard does not revalidate D: runtime files" in page


def test_programme_panel_renders_v2_resolved_residual_as_bound_pass() -> None:
    snapshot = render_cockpit.pipeline_books_program_snapshot(now_utc=NOW)
    snapshot["verification_lanes"]["green"]["deselected"] = 0
    residual = snapshot["verification_lanes"]["external_residual"]
    residual["state"] = "RESOLVED_PASS"
    residual["pass_count"] = 5
    snapshot["bindings"]["external_residual_exit_receipt"] = {
        "file_sha256": "d" * 64
    }
    snapshot["owner_blockers"] = snapshot["owner_blockers"][:4]

    page = render_cockpit.render_pipeline_books_program(snapshot)

    assert "EXTERNAL RESIDUAL RESOLVED_PASS" in page
    assert "5/5 sentinels passed" in page
    assert '<div class="pb-lane-line pass"><b>EXTERNAL RESIDUAL' in page
    assert "exit receipt dddddddddddd" in page
    assert "5 exact fail-closed sentinels" not in page
    assert "04 OPEN" in page


def test_invalid_snapshot_with_residual_payload_still_renders_fail_closed() -> None:
    snapshot = render_cockpit.pipeline_books_program_snapshot(now_utc=NOW)
    snapshot["state"] = "INVALID"
    snapshot["valid"] = False
    snapshot["error"] = "synthetic validation failure"
    snapshot["work_packages"][0]["status"] = "CHALLENGE_READY"

    page = render_cockpit.render_pipeline_books_program(snapshot)

    assert "NO TRUSTED W0–W8 STATUS AVAILABLE" in page
    assert "synthetic validation failure" in page
    assert "CHALLENGE_READY" not in page


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
    assert "DXZ_BETTER_BOOK_V1" in page
    assert "RESEARCH_MODEL_COMPLETE_STRICT_QUALIFICATION_UNVERIFIED" in page
    assert "NO TRUSTED W0–W8 STATUS AVAILABLE" not in page


def test_owner_surface_contains_all_verified_programme_blockers() -> None:
    snapshot = render_cockpit.pipeline_books_program_snapshot(now_utc=NOW)
    rows = render_cockpit.pipeline_books_owner_decision_rows(snapshot)

    assert len(rows) == 4
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
