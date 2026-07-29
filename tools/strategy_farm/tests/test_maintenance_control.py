from __future__ import annotations

import json
import hashlib
import sqlite3
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import farmctl  # noqa: E402
import maintenance_control as mc  # noqa: E402


def _seed(root: Path) -> Path:
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
                id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                attempt_count, claimed_by, payload_json, created_at, updated_at
            ) VALUES
                ('invalid-q02', 'backtest', 'Q02', 'QM5_20182', 'XTIUSD.DWX',
                 'a.set', 'pending', NULL, 0, NULL, '{}', ?, ?),
                ('stale-active', 'backtest', 'Q07', 'QM5_10272', 'XAUUSD.DWX',
                 'b.set', 'active', NULL, 1, 'T9', '{}', ?, ?),
                ('valid-pending', 'backtest', 'Q02', 'QM5_20062', 'EURUSD.DWX',
                 'c.set', 'pending', NULL, 0, NULL, '{}', ?, ?)
            """,
            (now, now, now, now, now, now),
        )
        conn.commit()
    return root / farmctl.DB_REL


def _manifest() -> dict:
    return {
        "run_id": "test-run",
        "description": "unit test",
        "operations": [
            {
                "work_item_id": "invalid-q02",
                "action": "quarantine",
                "hold_code": "FACTORY_OFF_BYPASS",
                "reason": "created while OFF",
                "expected": {"status": "pending", "ea_id": "QM5_20182"},
                "to_status": "failed",
                "to_verdict": "BLOCKED_FACTORY_OFF",
                "release_on_restart": False,
                "idempotency_key": "test:invalid",
            },
            {
                "work_item_id": "stale-active",
                "action": "requeue_hold",
                "hold_code": "STALE_ACTIVE",
                "reason": "no owned process",
                "expected": {"status": "active", "claimed_by": "T9"},
                "to_status": "pending",
                "to_verdict": None,
                "release_on_restart": True,
                "idempotency_key": "test:stale",
            },
            {
                "work_item_id": "valid-pending",
                "action": "hold",
                "hold_code": "FACTORY_OFF",
                "reason": "resume after restart",
                "expected": {"status": "pending"},
                "to_status": "pending",
                "to_verdict": None,
                "release_on_restart": True,
                "idempotency_key": "test:valid",
            },
        ],
    }


def _write_and_load_manifest(path: Path) -> dict:
    path.write_text(json.dumps(_manifest()), encoding="utf-8")
    return mc.load_manifest(path)


def test_dry_run_is_read_only_and_reports_exact_prestate(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    db = _seed(root)
    manifest = _write_and_load_manifest(tmp_path / "manifest.json")
    before = mc.sha256_file(db)

    result = mc.inspect_manifest(db, manifest)

    assert result["valid"] is True
    assert len(result["operations"]) == 3
    assert mc.sha256_file(db) == before


def test_apply_is_hash_bound_atomic_and_idempotent(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    db = _seed(root)
    manifest = _write_and_load_manifest(tmp_path / "manifest.json")
    flag = root / "state" / "FACTORY_OFF.flag"
    flag.write_text("intentional\n", encoding="utf-8")
    snapshot = tmp_path / "snapshot.sqlite"

    result = mc.apply_manifest(
        db,
        manifest,
        factory_off_flag=flag,
        expected_db_sha256=mc.sha256_file(db),
        expected_db_state_sha256=mc.sqlite_state_sha256(db),
        expected_factory_off_sha256=mc.sha256_file(flag),
        snapshot_path=snapshot,
    )

    assert snapshot.exists()
    assert len(result["applied"]) == 3
    with sqlite3.connect(db) as conn:
        invalid = conn.execute(
            "SELECT status, verdict, claimed_by FROM work_items WHERE id='invalid-q02'"
        ).fetchone()
        stale = conn.execute(
            "SELECT status, verdict, claimed_by FROM work_items WHERE id='stale-active'"
        ).fetchone()
        holds = conn.execute(
            "SELECT work_item_id, release_on_restart FROM work_item_holds WHERE active=1 ORDER BY work_item_id"
        ).fetchall()
        ledger_count = conn.execute("SELECT COUNT(*) FROM work_item_transition_ledger").fetchone()[0]
        event_count = conn.execute(
            "SELECT COUNT(*) FROM events WHERE event LIKE 'maintenance_%'"
        ).fetchone()[0]
    assert invalid == ("failed", "BLOCKED_FACTORY_OFF", None)
    assert stale == ("pending", None, None)
    assert holds == [("invalid-q02", 0), ("stale-active", 1), ("valid-pending", 1)]
    assert ledger_count == 3
    assert event_count == 3

    # A retry uses a new snapshot but the same idempotency keys and performs no
    # second transition/event.
    retry = mc.apply_manifest(
        db,
        manifest,
        factory_off_flag=flag,
        expected_db_sha256=mc.sha256_file(db),
        expected_db_state_sha256=mc.sqlite_state_sha256(db),
        expected_factory_off_sha256=mc.sha256_file(flag),
        snapshot_path=tmp_path / "snapshot-retry.sqlite",
    )
    assert all(item["already_applied"] for item in retry["applied"])
    with sqlite3.connect(db) as conn:
        assert conn.execute("SELECT COUNT(*) FROM work_item_transition_ledger").fetchone()[0] == 3
        assert conn.execute("SELECT COUNT(*) FROM events WHERE event LIKE 'maintenance_%'").fetchone()[0] == 3

    post_plan = mc.inspect_manifest(db, manifest)
    assert post_plan["valid"] is True
    assert all(item["already_applied"] for item in post_plan["operations"])


def test_apply_rolls_back_all_row_changes_on_prestate_mismatch(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    db = _seed(root)
    manifest = _write_and_load_manifest(tmp_path / "manifest.json")
    manifest["operations"][1]["expected"]["claimed_by"] = "T1"
    flag = root / "state" / "FACTORY_OFF.flag"
    flag.write_text("intentional\n", encoding="utf-8")

    with pytest.raises(RuntimeError, match="pre-state mismatch"):
        mc.apply_manifest(
            db,
            manifest,
            factory_off_flag=flag,
            expected_db_sha256=mc.sha256_file(db),
            expected_db_state_sha256=mc.sqlite_state_sha256(db),
            expected_factory_off_sha256=mc.sha256_file(flag),
            snapshot_path=tmp_path / "snapshot.sqlite",
        )

    with sqlite3.connect(db) as conn:
        assert conn.execute("SELECT status FROM work_items WHERE id='invalid-q02'").fetchone()[0] == "pending"
        assert conn.execute("SELECT COUNT(*) FROM work_item_transition_ledger").fetchone()[0] == 0


def test_transition_ledger_cannot_be_updated_or_deleted(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    db = _seed(root)
    manifest = _write_and_load_manifest(tmp_path / "manifest.json")
    flag = root / "state" / "FACTORY_OFF.flag"
    flag.write_text("intentional\n", encoding="utf-8")
    mc.apply_manifest(
        db,
        manifest,
        factory_off_flag=flag,
        expected_db_sha256=mc.sha256_file(db),
        expected_db_state_sha256=mc.sqlite_state_sha256(db),
        expected_factory_off_sha256=mc.sha256_file(flag),
        snapshot_path=tmp_path / "snapshot.sqlite",
    )
    with sqlite3.connect(db) as conn:
        with pytest.raises(sqlite3.IntegrityError, match="append-only"):
            conn.execute("DELETE FROM work_item_transition_ledger")
        with pytest.raises(sqlite3.IntegrityError, match="append-only"):
            conn.execute("UPDATE work_item_transition_ledger SET reason='tampered'")


def test_restart_release_requires_factory_on(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    db = _seed(root)
    manifest = _write_and_load_manifest(tmp_path / "manifest.json")
    flag = root / "state" / "FACTORY_OFF.flag"
    flag.write_text("intentional\n", encoding="utf-8")
    mc.apply_manifest(
        db,
        manifest,
        factory_off_flag=flag,
        expected_db_sha256=mc.sha256_file(db),
        expected_db_state_sha256=mc.sqlite_state_sha256(db),
        expected_factory_off_sha256=mc.sha256_file(flag),
        snapshot_path=tmp_path / "snapshot.sqlite",
    )
    with pytest.raises(RuntimeError, match="forbidden"):
        mc.release_restart_holds(
            db,
            factory_off_flag=flag,
            expected_db_sha256=None,
            apply=True,
            release_note="test",
        )
    flag.unlink()
    dry = mc.release_restart_holds(
        db,
        factory_off_flag=flag,
        expected_db_sha256=None,
        apply=False,
        release_note="test",
    )
    assert dry["work_item_ids"] == ["stale-active", "valid-pending"]

    lock_path = root / "state" / "FACTORY_MUTATION.lock"
    lock_record = {
        "pid": 4242,
        "owner": "factory_on_restart_window",
        "nonce": "unit-test-nonce",
    }
    lock_path.write_text(json.dumps(lock_record), encoding="utf-8")
    released = mc.release_restart_holds(
        db,
        factory_off_flag=flag,
        expected_db_sha256=None,
        apply=True,
        release_note="all components healthy",
        held_lock_owner_pid=4242,
        held_lock_owner="factory_on_restart_window",
        held_lock_nonce="unit-test-nonce",
    )
    assert released["released"] == ["stale-active", "valid-pending"]
    assert released["mutation_lock_mode"] == "authenticated_factory_on_lock"
    assert released["post_db_sha256"] == released["post_db_state_sha256"]
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_holds WHERE active=1 AND release_on_restart=1"
        ).fetchone()[0] == 0


def test_restart_release_rejects_wrong_held_lock_nonce(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    db = _seed(root)
    lock_path = root / "state" / "FACTORY_MUTATION.lock"
    lock_path.write_text(
        json.dumps({
            "pid": 4242,
            "owner": "factory_on_restart_window",
            "nonce": "real-nonce",
        }),
        encoding="utf-8",
    )
    with pytest.raises(RuntimeError, match="identity mismatch"):
        mc.release_restart_holds(
            db,
            factory_off_flag=root / "state" / "FACTORY_OFF.flag",
            expected_db_sha256=None,
            apply=True,
            release_note="test",
            held_lock_owner_pid=4242,
            held_lock_owner="factory_on_restart_window",
            held_lock_nonce="wrong-nonce",
        )


def test_completed_hold_release_is_exact_hash_bound_and_keeps_factory_off(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    db = _seed(root)
    manifest = _write_and_load_manifest(tmp_path / "manifest.json")
    flag = root / "state" / "FACTORY_OFF.flag"
    flag.write_text("intentional\n", encoding="utf-8")
    mc.apply_manifest(
        db,
        manifest,
        factory_off_flag=flag,
        expected_db_sha256=mc.sha256_file(db),
        expected_db_state_sha256=mc.sqlite_state_sha256(db),
        expected_factory_off_sha256=mc.sha256_file(flag),
        snapshot_path=tmp_path / "initial.sqlite",
    )
    with sqlite3.connect(db) as conn:
        conn.execute(
            "UPDATE work_items SET status='done', verdict='PASS', claimed_by=NULL "
            "WHERE id='invalid-q02'"
        )
        conn.commit()

    dry = mc.release_completed_hold(
        db,
        factory_off_flag=flag,
        work_item_id="invalid-q02",
        expected_hold_code="FACTORY_OFF_BYPASS",
        expected_status="done",
        expected_verdict="PASS",
        expected_db_sha256=None,
        expected_db_state_sha256=None,
        expected_factory_off_sha256=None,
        snapshot_path=None,
        apply=False,
        release_note="isolated run completed",
    )
    assert dry["active"] is True

    snapshot = tmp_path / "completed.sqlite"
    result = mc.release_completed_hold(
        db,
        factory_off_flag=flag,
        work_item_id="invalid-q02",
        expected_hold_code="FACTORY_OFF_BYPASS",
        expected_status="done",
        expected_verdict="PASS",
        expected_db_sha256=mc.sha256_file(db),
        expected_db_state_sha256=mc.sqlite_state_sha256(db),
        expected_factory_off_sha256=mc.sha256_file(flag),
        snapshot_path=snapshot,
        apply=True,
        release_note="isolated run completed",
    )

    assert flag.exists()
    assert snapshot.exists()
    assert result["already_released"] is False
    assert result["post_db_sha256"] == result["post_db_state_sha256"]
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT status, verdict FROM work_items WHERE id='invalid-q02'"
        ).fetchone() == ("done", "PASS")
        assert conn.execute(
            "SELECT active, release_note FROM work_item_holds WHERE work_item_id='invalid-q02'"
        ).fetchone() == (0, "isolated run completed")
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_transition_ledger "
            "WHERE action='release_completed_hold' AND work_item_id='invalid-q02'"
        ).fetchone()[0] == 1
        assert conn.execute(
            "SELECT COUNT(*) FROM events "
            "WHERE event='maintenance_completed_hold_released' AND entity_id='invalid-q02'"
        ).fetchone()[0] == 1

    retry = mc.release_completed_hold(
        db,
        factory_off_flag=flag,
        work_item_id="invalid-q02",
        expected_hold_code="FACTORY_OFF_BYPASS",
        expected_status="done",
        expected_verdict="PASS",
        expected_db_sha256=mc.sha256_file(db),
        expected_db_state_sha256=mc.sqlite_state_sha256(db),
        expected_factory_off_sha256=mc.sha256_file(flag),
        snapshot_path=tmp_path / "completed-retry.sqlite",
        apply=True,
        release_note="isolated run completed",
    )
    assert retry["already_released"] is True
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_transition_ledger "
            "WHERE action='release_completed_hold' AND work_item_id='invalid-q02'"
        ).fetchone()[0] == 1


def test_completed_hold_release_rejects_terminal_identity_drift(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    db = _seed(root)
    manifest = _write_and_load_manifest(tmp_path / "manifest.json")
    flag = root / "state" / "FACTORY_OFF.flag"
    flag.write_text("intentional\n", encoding="utf-8")
    mc.apply_manifest(
        db,
        manifest,
        factory_off_flag=flag,
        expected_db_sha256=mc.sha256_file(db),
        expected_db_state_sha256=mc.sqlite_state_sha256(db),
        expected_factory_off_sha256=mc.sha256_file(flag),
        snapshot_path=tmp_path / "initial.sqlite",
    )

    with pytest.raises(RuntimeError, match="terminal pre-state mismatch"):
        mc.release_completed_hold(
            db,
            factory_off_flag=flag,
            work_item_id="invalid-q02",
            expected_hold_code="FACTORY_OFF_BYPASS",
            expected_status="done",
            expected_verdict="PASS",
            expected_db_sha256=None,
            expected_db_state_sha256=None,
            expected_factory_off_sha256=None,
            snapshot_path=None,
            apply=False,
            release_note="must not release",
        )


def test_safe_defer_false_pass_reclassification_is_hash_bound_and_idempotent(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    db = _seed(root)
    verdict = "SAFE_DEFER accepted: isolated but repair remains open"
    verdict_sha = hashlib.sha256(verdict.encode("utf-8")).hexdigest()
    payload = {
        "review_close_state": "APPROVED",
        "review_close_verdict": verdict,
        "exit_reconciliations": [
            {
                "from_state": "APPROVED",
                "to_state": "PASSED",
                "reason": "approved_accepted_terminal",
            }
        ],
    }
    with sqlite3.connect(db) as conn:
        conn.execute(
            """
            CREATE TABLE agent_tasks(
                id TEXT PRIMARY KEY,
                task_type TEXT NOT NULL,
                state TEXT NOT NULL,
                verdict TEXT,
                payload_json TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            "INSERT INTO agent_tasks VALUES ('task-safe-defer','ops_issue','PASSED',?,?,?)",
            (verdict, json.dumps(payload), farmctl.utc_now()),
        )
        conn.commit()
    flag = root / "state" / "FACTORY_OFF.flag"
    flag.write_text("intentional\n", encoding="utf-8")

    dry = mc.reclassify_safe_defer_task(
        db,
        factory_off_flag=flag,
        task_id="task-safe-defer",
        expected_task_type="ops_issue",
        expected_verdict_sha256=verdict_sha,
        expected_db_sha256=None,
        expected_db_state_sha256=None,
        expected_factory_off_sha256=None,
        snapshot_path=None,
        apply=False,
        reason="deferred work is not a pass",
    )
    assert dry["from_state"] == "PASSED"
    assert dry["to_state"] == "BLOCKED"

    result = mc.reclassify_safe_defer_task(
        db,
        factory_off_flag=flag,
        task_id="task-safe-defer",
        expected_task_type="ops_issue",
        expected_verdict_sha256=verdict_sha,
        expected_db_sha256=mc.sha256_file(db),
        expected_db_state_sha256=mc.sqlite_state_sha256(db),
        expected_factory_off_sha256=mc.sha256_file(flag),
        snapshot_path=tmp_path / "safe-defer.sqlite",
        apply=True,
        reason="deferred work is not a pass",
    )
    assert result["already_reclassified"] is False
    assert flag.exists()
    with sqlite3.connect(db) as conn:
        row = conn.execute(
            "SELECT state, payload_json FROM agent_tasks WHERE id='task-safe-defer'"
        ).fetchone()
        assert row[0] == "BLOCKED"
        assert json.loads(row[1])["maintenance_reclassifications"][-1]["source"] == "MNT-037"
        assert conn.execute(
            "SELECT COUNT(*) FROM agent_task_transition_ledger "
            "WHERE action='reclassify_safe_defer'"
        ).fetchone()[0] == 1
        assert conn.execute(
            "SELECT COUNT(*) FROM events "
            "WHERE event='maintenance_safe_defer_reclassified'"
        ).fetchone()[0] == 1

    retry = mc.reclassify_safe_defer_task(
        db,
        factory_off_flag=flag,
        task_id="task-safe-defer",
        expected_task_type="ops_issue",
        expected_verdict_sha256=verdict_sha,
        expected_db_sha256=mc.sha256_file(db),
        expected_db_state_sha256=mc.sqlite_state_sha256(db),
        expected_factory_off_sha256=mc.sha256_file(flag),
        snapshot_path=tmp_path / "safe-defer-retry.sqlite",
        apply=True,
        reason="deferred work is not a pass",
    )
    assert retry["already_reclassified"] is True
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM agent_task_transition_ledger "
            "WHERE action='reclassify_safe_defer'"
        ).fetchone()[0] == 1


def test_safe_defer_reclassification_rejects_non_defer_verdict(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    db = _seed(root)
    verdict = "ordinary pass"
    with sqlite3.connect(db) as conn:
        conn.execute(
            """
            CREATE TABLE agent_tasks(
                id TEXT PRIMARY KEY,
                task_type TEXT NOT NULL,
                state TEXT NOT NULL,
                verdict TEXT,
                payload_json TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            "INSERT INTO agent_tasks VALUES ('task-pass','ops_issue','PASSED',?,?,?)",
            (
                verdict,
                json.dumps({
                    "review_close_state": "APPROVED",
                    "review_close_verdict": verdict,
                }),
                farmctl.utc_now(),
            ),
        )
        conn.commit()
    with pytest.raises(RuntimeError, match="not an explicit SAFE_DEFER"):
        mc.reclassify_safe_defer_task(
            db,
            factory_off_flag=root / "state" / "FACTORY_OFF.flag",
            task_id="task-pass",
            expected_task_type="ops_issue",
            expected_verdict_sha256=hashlib.sha256(verdict.encode("utf-8")).hexdigest(),
            expected_db_sha256=None,
            expected_db_state_sha256=None,
            expected_factory_off_sha256=None,
            snapshot_path=None,
            apply=False,
            reason="must not change",
        )
