from __future__ import annotations

import sqlite3

import pytest

from tools.strategy_farm import defect_block_taint_view as taint


WORK_ITEMS_DDL = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY,
    kind TEXT,
    phase TEXT,
    ea_id TEXT,
    symbol TEXT,
    setfile_path TEXT,
    status TEXT,
    verdict TEXT,
    attempt_count INTEGER,
    parent_task_id TEXT,
    evidence_path TEXT,
    claimed_by TEXT,
    payload_json TEXT,
    created_at TEXT,
    updated_at TEXT
)
"""


def _conn_with_rows(rows: list[dict]) -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:")
    conn.execute(WORK_ITEMS_DDL)
    for i, row in enumerate(rows):
        conn.execute(
            "INSERT INTO work_items (id, ea_id, phase, status, verdict, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (
                row.get("id", f"wi-{i}"),
                row["ea_id"],
                row.get("phase", "Q02"),
                row.get("status", "done"),
                row.get("verdict"),
                row.get("created_at", "2026-08-10T00:00:00+00:00"),
            ),
        )
    conn.commit()
    taint.install_taint_view(conn)
    return conn


def test_bare_ea_id_strips_qm5_prefix() -> None:
    assert taint._bare_ea_id("QM5_10648") == "10648"
    assert taint._bare_ea_id("10648") == "10648"
    assert taint._bare_ea_id(None) == ""


def test_taint_record_hits_registry_and_misses_unknown_ea() -> None:
    assert taint.taint_record("QM5_10648") is not None
    assert taint.taint_record("10648") is not None
    assert taint.taint_record("QM5_99999") is None


def test_view_flags_only_registry_eas() -> None:
    conn = _conn_with_rows(
        [
            {"ea_id": "QM5_10648", "phase": "Q02", "verdict": "PASS"},
            {"ea_id": "QM5_99999", "phase": "Q02", "verdict": "PASS"},
        ]
    )
    conn.row_factory = sqlite3.Row
    rows = {
        r["ea_id"]: r
        for r in conn.execute(f"SELECT * FROM {taint.TAINT_VIEW_NAME}")
    }
    assert rows["QM5_10648"]["defect_block_taint"] == 1
    assert rows["QM5_10648"]["defect_block_class"] == "host_slot_magic_conflation"
    assert rows["QM5_99999"]["defect_block_taint"] == 0
    assert rows["QM5_99999"]["defect_block_class"] is None


def test_view_never_mutates_source_table() -> None:
    conn = _conn_with_rows([{"ea_id": "QM5_10648", "phase": "Q02", "verdict": "PASS"}])
    before = conn.execute("SELECT * FROM work_items").fetchall()
    conn.execute(f"SELECT * FROM {taint.TAINT_VIEW_NAME}").fetchall()
    after = conn.execute("SELECT * FROM work_items").fetchall()
    assert before == after
    with pytest.raises(sqlite3.OperationalError):
        conn.execute(f"INSERT INTO {taint.TAINT_VIEW_NAME} (id) VALUES ('x')")


def test_audit_reports_after_block_invariant_violation() -> None:
    rec = taint.DEFECT_BLOCKED_EAS["10648"]
    conn = _conn_with_rows(
        [
            {"ea_id": "QM5_10648", "phase": "Q02", "verdict": "PASS", "created_at": "2026-08-10T00:00:00+00:00"},
            {"ea_id": "QM5_10648", "phase": "Q03", "verdict": "PASS", "created_at": "2027-01-01T00:00:00+00:00"},
        ]
    )
    report = taint.audit_taint_view(conn)
    assert report["tainted_row_count"] == 2
    assert report["after_block_invariant"]["valid"] is False
    assert report["after_block_invariant"]["violation_count"] == 1


def test_audit_clean_when_all_rows_predate_block() -> None:
    conn = _conn_with_rows(
        [
            {"ea_id": "QM5_10648", "phase": "Q02", "verdict": "PASS", "created_at": "2026-08-10T00:00:00+00:00"},
            {"ea_id": "QM5_10973", "phase": "Q03", "verdict": "FAIL", "created_at": "2026-08-12T00:00:00+00:00"},
        ]
    )
    report = taint.audit_taint_view(conn)
    assert report["tainted_row_count"] == 2
    assert report["pass_row_count"] == 1
    assert report["after_block_invariant"]["valid"] is True


def test_open_taint_view_connection_is_query_only(tmp_path) -> None:
    db_path = tmp_path / "farm_state.sqlite"
    setup_conn = sqlite3.connect(db_path)
    setup_conn.execute(WORK_ITEMS_DDL)
    setup_conn.execute(
        "INSERT INTO work_items (id, ea_id, phase, status, verdict, created_at) "
        "VALUES ('wi-1', 'QM5_10648', 'Q02', 'done', 'PASS', '2026-08-10T00:00:00+00:00')"
    )
    setup_conn.commit()
    setup_conn.close()

    conn = taint.open_taint_view_connection(db_path)
    try:
        rows = conn.execute(f"SELECT defect_block_taint FROM {taint.TAINT_VIEW_NAME}").fetchall()
        assert rows == [(1,)]
        with pytest.raises(sqlite3.OperationalError):
            conn.execute("INSERT INTO work_items (id) VALUES ('wi-2')")
    finally:
        conn.close()


def test_registry_size_matches_task_specification() -> None:
    assert len(taint.DEFECT_BLOCKED_EAS) == 15
