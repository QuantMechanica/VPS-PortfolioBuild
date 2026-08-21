"""Task 5343f90a: derived, query-only marker for the 2026-08-16 defect-block
cohort. Proves the 15-EA / 44-PASS pre-block evidence is tagged without
rewriting a single stored ``work_items`` row, and that a post-block row (a block
leak) is deliberately NOT tagged. Mirrors ``test_work_item_clean_view.py``.
"""
from __future__ import annotations

import json
import sqlite3

import pytest

from tools.strategy_farm import review_entry_gate as reg
from tools.strategy_farm import work_item_clean_view as clean


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

AGENT_TASKS_DDL = """
CREATE TABLE agent_tasks (
    id TEXT PRIMARY KEY,
    task_type TEXT,
    state TEXT,
    verdict TEXT,
    payload_json TEXT
)
"""

# A representative cohort member and its frozen block moment.
COHORT_EA = "QM5_10648"
BLOCK_TS = clean.DEFECT_BLOCK_COHORT[COHORT_EA]["blocked_at"]


def test_cohort_is_the_documented_fifteen() -> None:
    assert len(clean.DEFECT_BLOCK_COHORT) == 15
    expected = {
        "QM5_10648", "QM5_10649", "QM5_10973", "QM5_11301", "QM5_11302",
        "QM5_11689", "QM5_11897", "QM5_11898", "QM5_12352", "QM5_20070",
        "QM5_20071", "QM5_20179", "QM5_2076", "QM5_9354", "QM5_9501",
    }
    assert set(clean.DEFECT_BLOCK_COHORT) == expected


def test_marker_function_is_time_gated_and_reason_carrying() -> None:
    # Pre-block and exactly-at-block rows are tagged; a post-block row is not.
    assert clean.defect_blocked_at_production_time(COHORT_EA, "2026-08-15T00:00:00+00:00")
    assert clean.defect_blocked_at_production_time(COHORT_EA, BLOCK_TS)
    assert not clean.defect_blocked_at_production_time(COHORT_EA, "2026-08-17T00:00:00+00:00")
    # Bare integer id resolves to the same cohort key.
    assert clean.defect_blocked_at_production_time("10648", "2026-08-15T00:00:00+00:00")
    # A missing timestamp fails safe to tagged (predates the block by construction).
    assert clean.defect_blocked_at_production_time(COHORT_EA, None)
    # An EA outside the cohort is never tagged.
    assert not clean.defect_blocked_at_production_time("QM5_99999", "2026-08-15T00:00:00+00:00")
    assert clean.defect_block_record(COHORT_EA)["reason"] == "host_slot_magic_conflation"
    assert clean.defect_block_record("QM5_11897")["reason"] == "unwired_strategy_inputs"
    assert clean.defect_block_record("QM5_9501")["reason"] == "withdrawn_mechanical_approval"
    assert clean.defect_block_record("QM5_99999") is None


def test_derive_work_item_exposes_marker_fields() -> None:
    pre = clean.derive_work_item(
        {"ea_id": COHORT_EA, "status": "done", "verdict": "PASS",
         "payload_json": "{}", "updated_at": "2026-08-15T00:00:00+00:00"}
    )
    assert pre["defect_blocked_at_production_time"] is True
    assert pre["defect_block_reason"] == "host_slot_magic_conflation"
    assert pre["defect_block_schema"] == clean.DEFECT_BLOCK_SCHEMA
    # PASS taxonomy/status are untouched — the marker adds, never restamps merit.
    assert pre["verdict_taxonomy"] == "strategy"
    assert pre["status"] == "done"

    post = clean.derive_work_item(
        {"ea_id": COHORT_EA, "status": "done", "verdict": "PASS",
         "payload_json": "{}", "updated_at": "2026-08-17T00:00:00+00:00"}
    )
    assert post["defect_blocked_at_production_time"] is False
    # Reason/schema still identify the cohort EA even for a post-block row.
    assert post["defect_block_reason"] == "host_slot_magic_conflation"

    clean_ea = clean.derive_work_item(
        {"ea_id": "QM5_99999", "status": "done", "verdict": "PASS",
         "payload_json": "{}", "updated_at": "2026-08-15T00:00:00+00:00"}
    )
    assert clean_ea["defect_blocked_at_production_time"] is False
    assert clean_ea["defect_block_reason"] is None
    assert clean_ea["defect_block_schema"] is None


def _insert(conn: sqlite3.Connection, wid: str, ea: str, verdict: str, updated_at: str) -> None:
    conn.execute(
        "INSERT INTO work_items VALUES "
        "(?, 'backtest', 'Q02', ?, 'EURUSD', 'x.set', 'done', ?, 1, NULL, NULL, NULL, '{}', ?, ?)",
        (wid, ea, verdict, updated_at, updated_at),
    )


def test_view_tags_pre_block_rows_and_excludes_post_block_and_clean() -> None:
    conn = sqlite3.connect(":memory:")
    conn.execute(WORK_ITEMS_DDL)
    _insert(conn, "pre", COHORT_EA, "PASS", "2026-08-15T00:00:00+00:00")
    _insert(conn, "at", COHORT_EA, "PASS", BLOCK_TS)
    _insert(conn, "post", COHORT_EA, "PASS", "2026-08-17T00:00:00+00:00")
    _insert(conn, "clean", "QM5_99999", "PASS", "2026-08-15T00:00:00+00:00")
    clean.install_clean_view(conn)
    conn.execute("PRAGMA query_only=ON")
    conn.row_factory = sqlite3.Row

    rows = {
        r["id"]: r
        for r in conn.execute(
            "SELECT id, defect_blocked_at_production_time AS tag, defect_block_reason AS reason, "
            "defect_block_schema AS sch, verdict FROM work_items_clean"
        )
    }
    assert rows["pre"]["tag"] == 1
    assert rows["at"]["tag"] == 1
    assert rows["post"]["tag"] == 0  # block leak semantics: NOT pre-block evidence
    assert rows["clean"]["tag"] == 0
    assert rows["pre"]["reason"] == "host_slot_magic_conflation"
    assert rows["pre"]["sch"] == clean.DEFECT_BLOCK_SCHEMA
    # The cohort EA is identified by reason/schema even on the post-block row,
    # but only pre-block rows carry the boolean tag.
    assert rows["post"]["reason"] == "host_slot_magic_conflation"
    assert rows["clean"]["reason"] is None
    # PASS verdict itself is preserved — nothing overwritten.
    assert rows["pre"]["verdict"] == "PASS"


def test_view_is_query_only_and_does_not_rewrite_source() -> None:
    conn = sqlite3.connect(":memory:")
    conn.execute(WORK_ITEMS_DDL)
    _insert(conn, "pre", COHORT_EA, "PASS", "2026-08-15T00:00:00+00:00")
    clean.install_clean_view(conn)
    conn.execute("PRAGMA query_only=ON")
    with pytest.raises(sqlite3.OperationalError):
        conn.execute("UPDATE work_items SET verdict='FAIL'")
    assert conn.execute("SELECT verdict FROM main.work_items WHERE id='pre'").fetchone()[0] == "PASS"


def test_audit_counts_pass_rows_and_proves_block_held() -> None:
    conn = sqlite3.connect(":memory:")
    conn.execute(WORK_ITEMS_DDL)
    _insert(conn, "p1", COHORT_EA, "PASS", "2026-08-15T00:00:00+00:00")
    _insert(conn, "p2", COHORT_EA, "FAIL", "2026-08-15T00:00:00+00:00")
    _insert(conn, "p3", "QM5_9501", "PASS", "2026-08-15T00:00:00+00:00")
    clean.install_clean_view(conn)
    conn.execute("PRAGMA query_only=ON")
    audit = clean.audit_defect_block_cohort(conn)
    assert audit["schema"] == clean.DEFECT_BLOCK_SCHEMA
    assert audit["tagged_rows"] == 3
    assert audit["pass_rows"] == 2
    assert audit["eas_with_rows"] == 2
    assert audit["post_block_leak_rows"] == 0
    assert audit["block_held"] is True


def test_review_entry_gate_already_excludes_the_cohort() -> None:
    # Criterion 3 substantiation: the only active enqueue selection path
    # (sweep_enqueue_built_eas via review_entry_gate) already bars every cohort
    # EA by its live BLOCKED task state — no new exclusion code is required.
    conn = sqlite3.connect(":memory:")
    conn.execute(AGENT_TASKS_DDL)
    for i, ea in enumerate(clean.DEFECT_BLOCK_COHORT):
        conn.execute(
            "INSERT INTO agent_tasks VALUES (?, 'build_ea', 'BLOCKED', 'CLAUDE REVIEW BLOCK', ?)",
            (f"t{i}", json.dumps({"ea_id": ea.replace("QM5_", "")})),
        )
    conn.row_factory = sqlite3.Row
    index = reg.build_index(conn)
    for ea in clean.DEFECT_BLOCK_COHORT:
        block = reg.blocked(index, ea)
        assert block is not None
        assert block["reason"] == "review_fail_or_blocked"
