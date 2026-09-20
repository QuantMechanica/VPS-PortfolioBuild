"""Archived-duplicate rows (OWNER-DEC-BACKLOG-20260912) must not block Q02 intake (2026-09-20)."""
import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import review_entry_gate as gate  # noqa: E402


def _conn(rows):
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.execute("CREATE TABLE agent_tasks (id TEXT, task_type TEXT, state TEXT, verdict TEXT, payload_json TEXT)")
    for r in rows:
        con.execute("INSERT INTO agent_tasks VALUES (?,?,?,?,?)", (*r[:4], json.dumps(r[4])))
    con.commit()
    return con


def test_archived_duplicate_failed_row_is_ignored_but_real_fail_blocks():
    con = _conn([
        ("t1", "review_ea", "APPROVED", "APPROVED (Fable): build complete", {"ea_id": "38001"}),
        ("t2", "build_ea", "FAILED", "ARCHIVED (OWNER-DEC-BACKLOG-20260912) from BLOCKED: duplicate rework", {"ea_id": "38001"}),
        ("t3", "review_ea", "FAILED", "FAIL: unwired input", {"ea_id": "38002"}),
        ("t4", "build_ea", "FAILED", "ARCHIVED (OWNER-DEC-BACKLOG-20260912) duplicate", {"ea_id": "38003"}),
    ])
    idx = gate.build_index(con)
    assert gate.blocked(idx, "QM5_38001") is None
    assert gate.blocked(idx, "QM5_38002")["reason"] == "review_fail_or_blocked"
    # only an archived row and no accepted review: the EA is simply unknown to the gate (exempt)
    assert gate.blocked(idx, "QM5_38003") is None
