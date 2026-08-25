import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import reconcile_compile_rollout_holds as subject


def _fixture(tmp_path: Path, *, with_successor: bool = True):
    db = tmp_path / "farm.sqlite"
    repo = tmp_path / "repo"
    label = "QM5_1001_fixture-h1"
    source = repo / "framework" / "EAs" / label / f"{label}.mq5"
    source.parent.mkdir(parents=True)
    source.write_text("current source\n", encoding="utf-8")
    current_sha = hashlib.sha256(source.read_bytes()).hexdigest()
    conn = sqlite3.connect(db)
    conn.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY,ea_id TEXT,phase TEXT,status TEXT,verdict TEXT,
          payload_json TEXT,created_at TEXT,updated_at TEXT);
        CREATE TABLE work_item_holds(
          work_item_id TEXT PRIMARY KEY,hold_code TEXT,active INTEGER,
          created_at TEXT,updated_at TEXT,released_at TEXT,release_note TEXT);
        CREATE TABLE work_item_supersedes(
          work_item_id TEXT NOT NULL,superseded_by_work_item_id TEXT,reason TEXT,
          source_encoding TEXT NOT NULL,evidence_path TEXT,recorded_by TEXT,
          recorded_at TEXT,PRIMARY KEY(work_item_id,source_encoding));
        CREATE TABLE work_item_transition_ledger(
          seq INTEGER PRIMARY KEY AUTOINCREMENT,idempotency_key TEXT UNIQUE,ts TEXT,
          work_item_id TEXT,action TEXT,reason TEXT,run_id TEXT,detail_json TEXT);
        CREATE TABLE events(
          ts TEXT,entity_type TEXT,entity_id TEXT,event TEXT,detail_json TEXT);
        """
    )
    stale_payload = json.dumps({"ea_label": label, "mq5_sha256": "a" * 64})
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?)",
        ("old", "QM5_1001", "COMPILE_EA", "pending", None, stale_payload,
         "2026-01-01T00:00:00+00:00", "2026-01-01T00:00:00+00:00"),
    )
    conn.execute(
        "INSERT INTO work_item_holds VALUES(?,?,?,?,?,?,?)",
        ("old", subject.HOLD_CODE, 1, "2026-01-01", "2026-01-01", None, None),
    )
    if with_successor:
        fresh_payload = json.dumps({"ea_label": label, "mq5_sha256": current_sha})
        conn.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?)",
            ("new", "QM5_1001", "COMPILE_EA", "pending", None, fresh_payload,
             "2026-01-02T00:00:00+00:00", "2026-01-02T00:00:00+00:00"),
        )
        conn.execute(
            "INSERT INTO work_item_holds VALUES(?,?,?,?,?,?,?)",
            ("new", subject.HOLD_CODE, 1, "2026-01-02", "2026-01-02", None, None),
        )
    conn.commit()
    conn.close()
    return db, repo


def test_inspect_separates_stale_predecessor_from_fresh_successor(tmp_path: Path):
    db, repo = _fixture(tmp_path)

    result = subject.inspect(db, repo)

    assert result["active_hold_count"] == 2
    assert result["stale_hold_count"] == 1
    assert result["ready_to_supersede_count"] == 1
    assert result["source_fresh_hold_count"] == 1
    old = next(row for row in result["rows"] if row["work_item_id"] == "old")
    assert old["successor_work_item_id"] == "new"
    assert old["action"] == "SUPERSEDE_AND_CLOSE_STALE_HOLD"


def test_apply_records_supersession_and_closes_only_stale_hold(tmp_path: Path):
    db, repo = _fixture(tmp_path)

    result = subject.apply_reconciliation(
        db,
        repo,
        tmp_path / "backups",
        expected_stale_count=1,
        evidence_path="evidence.md",
    )

    assert result["applied"] == 1
    assert result["post_active_hold_count"] == 1
    assert result["post_stale_hold_count"] == 0
    with sqlite3.connect(db) as conn:
        holds = dict(conn.execute("SELECT work_item_id,active FROM work_item_holds"))
        work = conn.execute(
            "SELECT id,status,verdict FROM work_items ORDER BY id"
        ).fetchall()
        supersession = conn.execute(
            "SELECT work_item_id,superseded_by_work_item_id FROM work_item_supersedes"
        ).fetchone()
        action = conn.execute(
            "SELECT action FROM work_item_transition_ledger"
        ).fetchone()[0]
    assert holds == {"old": 0, "new": 1}
    assert work == [("new", "pending", None), ("old", "pending", None)]
    assert supersession == ("old", "new")
    assert action == "supersede_stale_compile_hold"


def test_apply_refuses_stale_row_without_successor(tmp_path: Path):
    db, repo = _fixture(tmp_path, with_successor=False)

    with pytest.raises(subject.ReconciliationError, match="stale_rows_not_ready"):
        subject.apply_reconciliation(
            db,
            repo,
            tmp_path / "backups",
            expected_stale_count=1,
            evidence_path="evidence.md",
        )
