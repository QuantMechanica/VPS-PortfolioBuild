from __future__ import annotations

import hashlib
import json
import sqlite3
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import farmctl  # noqa: E402


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _insert_build(root: Path, task_id: str, payload: dict | None = None, status: str = "pending") -> None:
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO tasks(id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
            VALUES (?, 'build_ea', ?, NULL, 'QM5_9001', ?, ?, ?)
            """,
            (task_id, status, json.dumps(payload or {"ea_id": "QM5_9001"}), now, now),
        )
        conn.commit()


def _write_clean_result(path: Path, task_id: str, *, generation: int = 0, token: str | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "task_id": task_id,
        "ea_id": "QM5_9001",
        "compile_succeeded": True,
        "build_check_passed": True,
        "smoke_result": "passed",
        "setfiles_generated": [str(path.parent / "QM5_9001_EURUSD.DWX_H1_backtest.set")],
        "build_generation": generation,
    }
    if token is not None:
        payload["build_attempt_token"] = token
    path.write_text(json.dumps(payload), encoding="utf-8")


def test_record_build_is_fail_closed_before_any_db_write_when_factory_off(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    flag = farmctl.factory_off_flag_path(root)
    flag.parent.mkdir(parents=True)
    flag.write_text("intentional maintenance\n", encoding="utf-8")
    result_path = tmp_path / "result.json"
    _write_clean_result(result_path, "missing-task")

    result = farmctl.record_build_result(root, "missing-task", str(result_path))

    assert result["recorded"] is False
    assert result["reason"] == "factory_off"
    assert not (root / farmctl.DB_REL).exists()


def test_hash_bound_record_during_off_never_enqueues_q02(tmp_path: Path, monkeypatch) -> None:
    root = tmp_path / "farm"
    task_id = "build-off"
    _insert_build(root, task_id)
    result_path = root / "artifacts" / "builds" / f"{task_id}.json"
    _write_clean_result(result_path, task_id)
    flag = farmctl.factory_off_flag_path(root)
    flag.parent.mkdir(parents=True, exist_ok=True)
    flag.write_text("intentional maintenance\n", encoding="utf-8")
    monkeypatch.setattr(farmctl, "_validate_ea_spec_md", lambda *_: {"ok": True, "failures": []})
    monkeypatch.setattr(farmctl, "_validate_ea_strategy_entry", lambda *_: {"ok": True, "failures": []})

    wrong = farmctl.record_build_result(
        root,
        task_id,
        str(result_path),
        allow_factory_off=True,
        expected_factory_off_sha256="0" * 64,
    )
    assert wrong["reason"] == "factory_off_override_hash_mismatch"

    recorded = farmctl.record_build_result(
        root,
        task_id,
        str(result_path),
        allow_factory_off=True,
        expected_factory_off_sha256=_sha256(flag),
    )

    assert recorded["recorded"] is True
    assert recorded["new_status"] == "done"
    assert recorded["auto_q02_enqueued"]["reason"] == "factory_off"
    with farmctl.connect(root) as conn:
        assert conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 0
        row = conn.execute("SELECT status, payload_json FROM tasks WHERE id=?", (task_id,)).fetchone()
    stored = json.loads(row["payload_json"])
    assert row["status"] == "done"
    assert stored["recorded_during_factory_off_override"] is True
    assert stored["auto_q02_enqueued"]["reason"] == "factory_off"

    repeated = farmctl.record_build_result(
        root,
        task_id,
        str(result_path),
        allow_factory_off=True,
        expected_factory_off_sha256=_sha256(flag),
    )
    assert repeated["already_recorded"] is True
    with farmctl.connect(root) as conn:
        assert conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 0


def test_embedded_materializer_rejects_rework_and_generation_mismatch(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    stale = {
        "task_id": "build-stale",
        "build_generation": 0,
        "compile_succeeded": True,
    }
    assert farmctl._materialize_embedded_build_result(
        root,
        "build-stale",
        {
            "codex_review_rework": True,
            "build_generation": 1,
            "codex_result": stale,
            "pre_review_not_reviewable_reason": "missing_build_result",
        },
    ) is None
    assert farmctl._materialize_embedded_build_result(
        root,
        "build-stale",
        {
            "build_generation": 1,
            "codex_result": stale,
            "pre_review_not_reviewable_reason": "missing_build_result",
        },
    ) is None


def test_rework_invalidates_stale_result_and_preserves_review_history(tmp_path: Path, monkeypatch) -> None:
    root = tmp_path / "farm"
    task_id = "build-rework"
    result_path = root / "artifacts" / "builds" / f"{task_id}.json"
    _write_clean_result(result_path, task_id)
    payload = {
        "ea_id": "QM5_9001",
        "slug": "rework",
        "blocked_reason": "codex_review_fail",
        "codex_result": json.loads(result_path.read_text(encoding="utf-8")),
        "auto_q02_enqueued": {"enqueued": [{"wi_id": "bad"}]},
        "build_result_path": str(result_path),
        "build_generation": 0,
    }
    _insert_build(root, task_id, payload=payload, status="blocked")
    now = farmctl.utc_now()
    review_id = "review-old"
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO tasks(id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
            VALUES (?, 'codex_review', 'done', NULL, 'QM5_9001', ?, ?, ?)
            """,
            (
                review_id,
                json.dumps({
                    "build_task_id": task_id,
                    "build_generation": 0,
                    "verdict": {"verdict": "FAIL", "findings": ["repair me"]},
                }),
                now,
                now,
            ),
        )
        conn.commit()
    monkeypatch.setattr(farmctl, "_repo_dirty_status", lambda: {"blocked": False, "entries": []})

    prepared = farmctl._prepare_codex_review_fail_reworks(root)

    assert [item["build_task_id"] for item in prepared] == [task_id]
    with farmctl.connect(root) as conn:
        build_row = conn.execute("SELECT status, payload_json FROM tasks WHERE id=?", (task_id,)).fetchone()
        review_rows = conn.execute("SELECT id, payload_json FROM tasks WHERE kind='codex_review'").fetchall()
    updated = json.loads(build_row["payload_json"])
    assert build_row["status"] == "pending"
    assert updated["build_generation"] == 1
    assert updated["build_attempt_token"]
    assert "codex_result" not in updated
    assert "auto_q02_enqueued" not in updated
    assert len(review_rows) == 1
    old_review = json.loads(review_rows[0]["payload_json"])
    assert old_review["superseded_by_build_generation"] == 1
    assert farmctl._materialize_embedded_build_result(root, task_id, updated) is None


def test_pending_selector_excludes_item_specific_hold(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
                id, kind, phase, ea_id, symbol, setfile_path, status,
                attempt_count, payload_json, created_at, updated_at
            ) VALUES ('held', 'backtest', 'Q02', 'QM5_9001', 'EURUSD.DWX',
                      'held.set', 'pending', 0, '{}', ?, ?)
            """,
            (now, now),
        )
        conn.execute(
            """
            INSERT INTO work_item_holds(
                work_item_id, hold_code, reason, active, release_on_restart,
                created_at, updated_at
            ) VALUES ('held', 'FACTORY_OFF', 'maintenance', 1, 1, ?, ?)
            """,
            (now, now),
        )
        conn.commit()
        assert conn.execute(farmctl.pending_claim_order_sql()).fetchall() == []
