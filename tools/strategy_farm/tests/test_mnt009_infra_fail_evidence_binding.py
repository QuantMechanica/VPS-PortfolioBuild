from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


def _runtime(tmp_path: Path) -> Path:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    return root / farmctl.DB_REL


def _insert_active(db: Path, item_id: str) -> None:
    now = "2026-08-21T10:00:00+00:00"
    with sqlite3.connect(db) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
            ) VALUES (?, 'backtest', 'Q02', 'QM5_9001', 'EURUSD.DWX', 'test.set',
                      'active', NULL, 0, NULL, NULL, 'T1', '{}', ?, ?)
            """,
            (item_id, now, now),
        )
        conn.commit()


def test_infra_fail_without_evidence_path_is_rejected(tmp_path: Path) -> None:
    db = _runtime(tmp_path)
    _insert_active(db, "wi-infra-null")
    with sqlite3.connect(db) as conn, pytest.raises(
        sqlite3.IntegrityError,
        match="terminal INFRA_FAIL work_item requires evidence_path",
    ):
        conn.execute(
            "UPDATE work_items SET status='failed', verdict='INFRA_FAIL' WHERE id=?",
            ("wi-infra-null",),
        )


def test_infra_fail_with_empty_string_evidence_path_is_rejected(tmp_path: Path) -> None:
    db = _runtime(tmp_path)
    _insert_active(db, "wi-infra-empty")
    with sqlite3.connect(db) as conn, pytest.raises(
        sqlite3.IntegrityError,
        match="terminal INFRA_FAIL work_item requires evidence_path",
    ):
        conn.execute(
            "UPDATE work_items SET status='failed', verdict='INFRA_FAIL', "
            "evidence_path='' WHERE id=?",
            ("wi-infra-empty",),
        )


def test_infra_fail_with_real_evidence_path_succeeds(tmp_path: Path) -> None:
    db = _runtime(tmp_path)
    _insert_active(db, "wi-infra-real")
    with sqlite3.connect(db) as conn:
        conn.execute(
            "UPDATE work_items SET status='failed', verdict='INFRA_FAIL', "
            "evidence_path='D:\\QM\\reports\\pipeline\\QM5_9001\\summary.json' WHERE id=?",
            ("wi-infra-real",),
        )
        conn.commit()
        row = conn.execute(
            "SELECT evidence_path FROM work_items WHERE id=?", ("wi-infra-real",)
        ).fetchone()
    assert row[0] == "D:\\QM\\reports\\pipeline\\QM5_9001\\summary.json"


def test_infra_fail_with_evidence_unavailable_sentinel_succeeds(tmp_path: Path) -> None:
    db = _runtime(tmp_path)
    _insert_active(db, "wi-infra-sentinel")
    sentinel = farmctl._evidence_unavailable_sentinel("timeout_retries_exhausted")
    with sqlite3.connect(db) as conn:
        conn.execute(
            "UPDATE work_items SET status='failed', verdict='INFRA_FAIL', "
            "evidence_path=? WHERE id=?",
            (sentinel, "wi-infra-sentinel"),
        )
        conn.commit()
        row = conn.execute(
            "SELECT evidence_path FROM work_items WHERE id=?", ("wi-infra-sentinel",)
        ).fetchone()
    assert row[0] == "EVIDENCE_UNAVAILABLE:timeout_retries_exhausted"


def test_non_infra_terminal_verdicts_are_unaffected(tmp_path: Path) -> None:
    # MNT-009 is deliberately scoped to verdict='INFRA_FAIL' only -- sentinel
    # terminal verdicts like WAITING_INPUT/PENDING_RUNNER never carried
    # evidence_path and auditing every one of those call sites is unscoped
    # follow-up, not this ticket. Confirm the narrower trigger leaves them be.
    db = _runtime(tmp_path)
    for item_id, verdict in (
        ("wi-waiting", "WAITING_INPUT"),
        ("wi-pending-runner", "PENDING_RUNNER"),
        ("wi-invalid", "INVALID"),
        ("wi-pass", "PASS"),
    ):
        _insert_active(db, item_id)
        with sqlite3.connect(db) as conn:
            conn.execute(
                "UPDATE work_items SET status='done', verdict=? WHERE id=?",
                (verdict, item_id),
            )
            conn.commit()


def test_evidence_unavailable_sentinel_format() -> None:
    assert (
        farmctl._evidence_unavailable_sentinel("worker_died_retries_exhausted")
        == "EVIDENCE_UNAVAILABLE:worker_died_retries_exhausted"
    )
