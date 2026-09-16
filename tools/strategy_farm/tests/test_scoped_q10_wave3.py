from __future__ import annotations

import json
import sqlite3

from tools.strategy_farm import q09_news_runner as runner
from tools.strategy_farm import scoped_q10_wave3 as wave3


def test_wave3_allowlist_is_exact_disjoint_and_excluded() -> None:
    assert len(wave3.RELEASE_IDS) == 7
    assert len(set(wave3.RELEASE_IDS)) == 7
    assert not (set(wave3.RELEASE_IDS) & set(wave3.EXCLUDED_IDS))
    assert set(wave3.EXCLUDED_IDS) == {
        "745671a4-02e4-4df5-b5e1-e25f0e41ca0e",
        "d712832c-b41b-471c-a986-79f7f17f8dfb",
    }


def test_wave3_fix_commit_is_present_in_repository() -> None:
    assert wave3.SILENT_ABORT_FIX_COMMIT != "TBD"
    assert wave3._fix_commit_present()


def test_wave3_inspect_refuses_row_without_silent_abort_hold(tmp_path) -> None:
    db = tmp_path / "farm_state.sqlite"
    conn = sqlite3.connect(db)
    conn.row_factory = sqlite3.Row
    conn.execute(
        "CREATE TABLE work_items (id TEXT, phase TEXT, status TEXT, verdict TEXT, "
        "claimed_by TEXT, ea_id TEXT, symbol TEXT, setfile_path TEXT, "
        "payload_json TEXT, evidence_path TEXT, updated_at TEXT)"
    )
    conn.execute(
        "CREATE TABLE work_item_holds (work_item_id TEXT, hold_code TEXT, reason TEXT, "
        "active INTEGER, release_on_restart INTEGER, created_at TEXT, updated_at TEXT, "
        "released_at TEXT, release_note TEXT)"
    )
    conn.execute(
        "INSERT INTO work_items VALUES('w1','Q10_NEWS','pending',NULL,NULL,"
        "'QM5_1','XAUUSD.DWX','',?,NULL,'t')",
        (json.dumps({"q09_run_plan_path": "x", "q09_run_plan_file_sha256": "y"}),),
    )
    row = conn.execute("SELECT * FROM work_items WHERE id='w1'").fetchone()
    try:
        wave3.inspect_row(conn, row)
    except wave3.Wave3Error as exc:
        assert "silent-abort hold missing" in str(exc)
    else:
        raise AssertionError("row without the hold was accepted")


def test_wave3_excluded_rows_carry_documented_reasons() -> None:
    for reason in wave3.EXCLUDED_IDS.values():
        assert reason.strip()
