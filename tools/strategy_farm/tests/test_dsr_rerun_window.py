import json
import sqlite3

import pytest

from tools.strategy_farm import dsr_cohort, farmctl


def _db():
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute("""CREATE TABLE work_items(
        id TEXT PRIMARY KEY, phase TEXT, ea_id TEXT, symbol TEXT,
        data_window_start TEXT, data_window_end TEXT, payload_json TEXT)""")
    return conn


def test_append_only_q08_rerun_resolves_q07_predecessor_window():
    conn = _db()
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?)",
        ("q07", "Q07", "QM5_42", "XAUUSD.DWX", "2017.01.01", "2025.12.31", "{}"),
    )
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?)",
        (
            "old-q08", "Q08", "QM5_42", "XAUUSD.DWX", None, None,
            json.dumps({"promoted_from_work_item": "q07"}),
        ),
    )
    candidate = {
        "id": "rerun", "phase": "Q08", "ea_id": "QM5_42",
        "symbol": "XAUUSD.DWX", "data_window_start": None,
        "data_window_end": None,
    }
    payload = {
        "append_only_rerun_of_work_item": "old-q08",
        "append_only_rerun_lineage_work_items": ["old-q08"],
    }
    window, source = dsr_cohort._candidate_window(conn, candidate, payload)
    assert window == {"from": "2017-01-01", "to": "2025-12-31"}
    assert source.endswith("q07:work_items.data_window_start/data_window_end")


def test_payload_window_has_precedence_over_row_and_lineage():
    conn = _db()
    candidate = {
        "id": "q08", "phase": "Q08", "ea_id": "QM5_42",
        "symbol": "XAUUSD.DWX", "data_window_start": "2017.01.01",
        "data_window_end": "2025.12.31",
    }
    window, source = dsr_cohort._candidate_window(
        conn, candidate, {"expected_from_date": "2018.01.01", "expected_to_date": "2024.12.31"}
    )
    assert window == {"from": "2018-01-01", "to": "2024-12-31"}
    assert source == "payload.expected_from_date/expected_to_date"


def test_missing_authoritative_window_still_fails_closed():
    conn = _db()
    candidate = {"id": "q08", "phase": "Q08", "ea_id": "QM5_42", "symbol": "XAUUSD.DWX"}
    with pytest.raises(dsr_cohort.CohortUnavailable, match="CANDIDATE_WINDOW_UNAVAILABLE"):
        dsr_cohort._candidate_window(conn, candidate, {})


def test_q08_enqueue_payload_carries_predecessor_window():
    payload = {}
    farmctl._carry_q08_candidate_window(
        {
            "data_window_start": "2017.01.01", "data_window_end": "2025.12.31",
            "payload_json": "{}",
        },
        payload,
    )
    assert payload["expected_from_date"] == "2017.01.01"
    assert payload["expected_to_date"] == "2025.12.31"
