from __future__ import annotations

import datetime as dt
import json
import hashlib
import os
import sqlite3
import subprocess
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import farmctl  # noqa: E402
import maintenance_control as mc  # noqa: E402


RESTART_HOLD_IDS = mc.CANONICAL_RESTART_HOLD_IDS


def _runtime_authorization() -> dict:
    return {
        "authorized": True,
        "decision_id": "unit-runtime-decision",
        "activation_nonce": "a" * 32,
        "decision_sha256": "b" * 64,
        "decision_git_commit": "c" * 40,
        "decision_git_blob": "d" * 40,
        "factory_off_flag_sha256": "e" * 64,
        "task_enabled_before_sha256": "f" * 64,
        "source_bindings": {
            "factory_on": {
                "sha256": "1" * 64,
                "git_commit": "2" * 40,
                "git_blob": "3" * 40,
            },
            "maintenance_control": {
                "sha256": "4" * 64,
                "git_commit": "5" * 40,
                "git_blob": "6" * 40,
            },
        },
    }


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


def _prepare_restart_holds(tmp_path: Path) -> tuple[Path, Path, Path]:
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
        snapshot_path=tmp_path / "restart-hold-snapshot.sqlite",
    )
    with sqlite3.connect(db) as conn:
        conn.execute("DELETE FROM work_item_holds WHERE release_on_restart=1")
        now = mc.utc_now()
        conn.executemany(
            """
            INSERT INTO work_item_holds(
                work_item_id, hold_code, reason, active, release_on_restart,
                created_at, updated_at
            ) VALUES (?, 'FACTORY_OFF', 'resume after restart', 1, 1, ?, ?)
            """,
            [(work_item_id, now, now) for work_item_id in RESTART_HOLD_IDS],
        )
        conn.commit()
    flag.unlink()
    return root, db, flag


def _allow_test_factory_on_context(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        mc, "_require_canonical_restart_release_paths", lambda *args, **kwargs: None
    )
    monkeypatch.setattr(
        mc,
        "_validate_canonical_factory_on_lock",
        lambda *args, **kwargs: {"validated_test_context": True},
    )
    monkeypatch.setattr(
        mc,
        "validate_runtime_activation_decision",
        lambda *args, **kwargs: _runtime_authorization(),
    )


def _factory_on_lock_record(
    *, nonce: str, pid: int | None = None, runtime_authorization: dict | None = None
) -> dict:
    runtime = runtime_authorization or _runtime_authorization()
    now = dt.datetime.now(dt.UTC)
    return {
        "pid": os.getppid() if pid is None else pid,
        "owner": mc.FACTORY_ON_LOCK_OWNER,
        "nonce": nonce,
        "process_image": str(mc.CANONICAL_FACTORY_ON_PROCESS_IMAGE),
        "process_started_at_utc": (now - dt.timedelta(minutes=1)).isoformat(),
        "created_at": now.isoformat(),
        "lock_handle_value": 12345,
        "session_id": 7,
        "factory_on_path": str(mc.CANONICAL_FACTORY_ON_PATH),
        "owner_decision_sha256": mc.CANONICAL_OWNER_DECISION_SHA256,
        "owner_decision_commit": mc.CANONICAL_OWNER_DECISION_COMMIT,
        "owner_decision_blob": mc.CANONICAL_OWNER_DECISION_BLOB,
        "restart_hold_ids": list(RESTART_HOLD_IDS),
        "disabled_terminals_sha256": "0" * 64,
        "runtime_decision_id": runtime["decision_id"],
        "runtime_activation_nonce": runtime["activation_nonce"],
        "runtime_decision_sha256": runtime["decision_sha256"],
        "runtime_decision_commit": runtime["decision_git_commit"],
        "runtime_decision_blob": runtime["decision_git_blob"],
        "factory_on_source_sha256": runtime["source_bindings"]["factory_on"]["sha256"],
        "factory_on_source_commit": runtime["source_bindings"]["factory_on"]["git_commit"],
        "factory_on_source_blob": runtime["source_bindings"]["factory_on"]["git_blob"],
        "factory_off_flag_sha256": runtime["factory_off_flag_sha256"],
        "factory_off_request_path": str(mc.DEFAULT_FACTORY_OFF_REQUEST),
        "task_enabled_before_sha256": runtime["task_enabled_before_sha256"],
    }


def _mock_valid_factory_parent(
    monkeypatch: pytest.MonkeyPatch,
    record: dict,
    *,
    actively_held: bool = True,
    handle_matches: bool = True,
) -> None:
    monkeypatch.setattr(
        mc,
        "_query_windows_process_identity",
        lambda pid: {
            "process_id": pid,
            "executable_path": str(mc.CANONICAL_FACTORY_ON_PROCESS_IMAGE),
            "command_line": "canonical-test-command-line",
            "session_id": record["session_id"],
            "process_started_at_utc": record["process_started_at_utc"],
        },
    )
    monkeypatch.setattr(
        mc,
        "_windows_command_line_args",
        lambda command_line: [
            str(mc.CANONICAL_FACTORY_ON_PROCESS_IMAGE),
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(mc.CANONICAL_FACTORY_ON_PATH),
            "-CanonicalRuntimeHost",
        ],
    )
    monkeypatch.setattr(mc, "_windows_process_session_id", lambda pid: record["session_id"])
    monkeypatch.setattr(mc, "_is_lock_actively_held", lambda path: actively_held)
    monkeypatch.setattr(
        mc,
        "_parent_handle_targets_lock",
        lambda parent_pid, handle_value, lock_path: handle_matches,
    )


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


def test_restart_release_requires_factory_on(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _, db, flag = _prepare_restart_holds(tmp_path)
    _allow_test_factory_on_context(monkeypatch)
    flag.write_text("intentional\n", encoding="utf-8")
    with pytest.raises(RuntimeError, match="OFF wins"):
        mc.release_restart_holds(
            db,
            factory_off_flag=flag,
            expected_db_sha256=None,
            apply=True,
            release_note="test",
            factory_on_lock_nonce="unit-test-nonce",
        )
    flag.unlink()
    dry = mc.release_restart_holds(
        db,
        factory_off_flag=flag,
        expected_db_sha256=None,
        apply=False,
        release_note="test",
    )
    assert dry["work_item_ids"] == sorted(RESTART_HOLD_IDS)

    released = mc.release_restart_holds(
        db,
        factory_off_flag=flag,
        expected_db_sha256=None,
        apply=True,
        release_note="all components healthy",
        factory_on_lock_nonce="unit-test-nonce",
    )
    assert released["released"] == sorted(RESTART_HOLD_IDS)
    assert released["mutation_committed"] is True
    assert released["mutation_lock_mode"] == "authenticated_live_factory_on_parent_lock"
    assert released["post_commit_evidence"]["status"] == "PASS"
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_holds WHERE active=1 AND release_on_restart=1"
        ).fetchone()[0] == 0


def test_restart_release_rejects_wrong_factory_on_lock_nonce(tmp_path: Path) -> None:
    lock_path = tmp_path / "FACTORY_MUTATION.lock"
    lock_path.write_text(json.dumps(_factory_on_lock_record(nonce="real-nonce")), encoding="utf-8")
    with pytest.raises(RuntimeError, match="identity mismatch"):
        mc._validate_canonical_factory_on_lock(
            lock_path,
            expected_nonce="wrong-nonce",
            runtime_authorization=_runtime_authorization(),
        )


def test_restart_release_rejects_matching_but_unheld_fake_lock(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    runtime = _runtime_authorization()
    record = _factory_on_lock_record(nonce="known-nonce", runtime_authorization=runtime)
    lock_path = tmp_path / "FACTORY_MUTATION.lock"
    lock_path.write_text(json.dumps(record), encoding="utf-8")
    _mock_valid_factory_parent(monkeypatch, record, actively_held=False)

    with pytest.raises(RuntimeError, match="not actively held"):
        mc._validate_canonical_factory_on_lock(
            lock_path,
            expected_nonce="known-nonce",
            runtime_authorization=runtime,
        )


def test_restart_release_rejects_parent_handle_for_another_file(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    runtime = _runtime_authorization()
    record = _factory_on_lock_record(nonce="known-nonce", runtime_authorization=runtime)
    lock_path = tmp_path / "FACTORY_MUTATION.lock"
    lock_path.write_text(json.dumps(record), encoding="utf-8")
    _mock_valid_factory_parent(monkeypatch, record, handle_matches=False)

    with pytest.raises(RuntimeError, match="handle does not identify"):
        mc._validate_canonical_factory_on_lock(
            lock_path,
            expected_nonce="known-nonce",
            runtime_authorization=runtime,
        )


@pytest.mark.skipif(os.name != "nt", reason="Windows handle-duplication contract")
def test_parent_handle_file_identity_probe_uses_concrete_live_parent_handle(
    tmp_path: Path,
) -> None:
    lock_path = tmp_path / "FACTORY_MUTATION.lock"
    other_path = tmp_path / "other.lock"
    lock_path.write_text("lock\n", encoding="utf-8")
    other_path.write_text("other\n", encoding="utf-8")
    helper = tmp_path / "probe_parent_handle.py"
    helper.write_text(
        "\n".join(
            (
                "import json, os, sys",
                f"sys.path.insert(0, {str(HERE.parent)!r})",
                "import maintenance_control as mc",
                "lock_handle = int(sys.argv[1])",
                "other_handle = int(sys.argv[2])",
                "lock_path = mc.Path(sys.argv[3])",
                "print(json.dumps({",
                "  'matching': mc._parent_handle_targets_lock(os.getppid(), lock_handle, lock_path),",
                "  'other': mc._parent_handle_targets_lock(os.getppid(), other_handle, lock_path),",
                "}))",
            )
        )
        + "\n",
        encoding="utf-8",
    )
    def ps_literal(value: Path | str) -> str:
        return "'" + str(value).replace("'", "''") + "'"

    script = f"""
$ErrorActionPreference = 'Stop'
$lock = [System.IO.File]::Open({ps_literal(lock_path)}, 'Open', 'ReadWrite', 'Read')
$other = [System.IO.File]::Open({ps_literal(other_path)}, 'Open', 'ReadWrite', 'Read')
try {{
    & {ps_literal(sys.executable)} {ps_literal(helper)} `
        $lock.SafeFileHandle.DangerousGetHandle().ToInt64() `
        $other.SafeFileHandle.DangerousGetHandle().ToInt64() {ps_literal(lock_path)}
    if ($LASTEXITCODE -ne 0) {{ exit $LASTEXITCODE }}
}} finally {{
    $other.Dispose()
    $lock.Dispose()
}}
"""
    result = subprocess.run(
        (
            str(mc.CANONICAL_FACTORY_ON_PROCESS_IMAGE),
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            script,
        ),
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=30,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    probe = json.loads(result.stdout)
    assert probe == {"matching": True, "other": False}


def test_restart_release_rejects_non_factory_parent_with_matching_claimed_lock(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    runtime = _runtime_authorization()
    record = _factory_on_lock_record(nonce="known-nonce", runtime_authorization=runtime)
    lock_path = tmp_path / "FACTORY_MUTATION.lock"
    lock_path.write_text(json.dumps(record), encoding="utf-8")
    monkeypatch.setattr(
        mc,
        "_query_windows_process_identity",
        lambda pid: {
            "process_id": pid,
            "executable_path": sys.executable,
            "command_line": f'"{sys.executable}" fake_parent.py',
            "session_id": 7,
            "process_started_at_utc": record["process_started_at_utc"],
        },
    )

    with pytest.raises(RuntimeError, match="parent image mismatch"):
        mc._validate_canonical_factory_on_lock(
            lock_path,
            expected_nonce="known-nonce",
            runtime_authorization=runtime,
        )


def test_restart_release_rejects_disabled_terminal_drift_under_live_lock(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    disabled = tmp_path / "disabled_terminals.txt"
    disabled.write_text("T5\n", encoding="utf-8")
    record = _factory_on_lock_record(nonce="known-nonce")
    record["disabled_terminals_sha256"] = mc.sha256_file(disabled)
    lock_path = tmp_path / "FACTORY_MUTATION.lock"
    lock_path.write_text(json.dumps(record), encoding="utf-8")
    disabled.write_text("T6\n", encoding="utf-8")
    monkeypatch.setattr(mc, "DEFAULT_DISABLED_TERMINALS", disabled)
    _mock_valid_factory_parent(monkeypatch, record)

    with pytest.raises(RuntimeError, match="changed under Factory_ON lock"):
        mc._validate_canonical_factory_on_lock(
            lock_path,
            expected_nonce="known-nonce",
            runtime_authorization=_runtime_authorization(),
        )


def test_restart_release_apply_rejects_noncanonical_paths(tmp_path: Path) -> None:
    with pytest.raises(RuntimeError, match="canonical production paths"):
        mc._require_canonical_restart_release_paths(
            tmp_path / "farm.sqlite",
            tmp_path / "FACTORY_OFF.flag",
            tmp_path / "FACTORY_MUTATION.lock",
        )


@pytest.mark.parametrize("drift", ["missing", "extra"])
def test_restart_release_rejects_missing_or_extra_ids_before_writes(
    tmp_path: Path, drift: str
) -> None:
    _, db, _ = _prepare_restart_holds(tmp_path)
    with sqlite3.connect(db) as conn:
        if drift == "missing":
            conn.execute(
                "DELETE FROM work_item_holds WHERE work_item_id=?",
                (RESTART_HOLD_IDS[0],),
            )
        else:
            now = mc.utc_now()
            conn.execute(
                """
                INSERT INTO work_item_holds(
                    work_item_id, hold_code, reason, active, release_on_restart,
                    created_at, updated_at
                ) VALUES ('unexpected-owner-id', 'FACTORY_OFF', 'not approved', 1, 1, ?, ?)
                """,
                (now, now),
            )
        conn.commit()

    with pytest.raises(RuntimeError, match="exact-set mismatch") as exc_info:
        mc._apply_restart_hold_release_transaction(
            db,
            release_note="must not apply",
            runtime_authorization=_runtime_authorization(),
        )

    if drift == "missing":
        assert RESTART_HOLD_IDS[0] in str(exc_info.value)
    else:
        assert "unexpected-owner-id" in str(exc_info.value)
    with sqlite3.connect(db) as conn:
        expected_active = 6 if drift == "missing" else 8
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_holds WHERE active=1 AND release_on_restart=1"
        ).fetchone()[0] == expected_active
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_transition_ledger "
            "WHERE action='release_hold'"
        ).fetchone()[0] == 0
        assert conn.execute(
            "SELECT COUNT(*) FROM events WHERE event='maintenance_hold_released'"
        ).fetchone()[0] == 0
        assert conn.execute(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' "
            "AND name='factory_runtime_activation_consumptions'"
        ).fetchone()[0] == 0


def test_restart_release_ids_are_unique_and_bound_to_canonical_owner_decision() -> None:
    decision = mc._validate_canonical_restart_owner_decision()
    assert len(RESTART_HOLD_IDS) == len(set(RESTART_HOLD_IDS)) == 7
    assert decision["restart_holds"]["authorized_work_item_ids"] == list(
        RESTART_HOLD_IDS
    )


def test_restart_release_rejects_tampered_owner_decision(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    decision_path = tmp_path / "decision.json"
    decision_path.write_text('{"authority":"OWNER","tampered":true}', encoding="utf-8")
    monkeypatch.setattr(mc, "_canonical_repo_root", lambda: tmp_path)
    monkeypatch.setattr(
        mc, "CANONICAL_OWNER_DECISION_RELATIVE_PATH", Path("decision.json")
    )
    with pytest.raises(RuntimeError, match="SHA-256 mismatch"):
        mc._validate_canonical_restart_owner_decision()


def test_restart_release_cas_failure_rolls_back_every_write(tmp_path: Path) -> None:
    _, db, _ = _prepare_restart_holds(tmp_path)
    cas_target = sorted(RESTART_HOLD_IDS)[2]
    with sqlite3.connect(db) as conn:
        conn.executescript(
            f"""
            CREATE TRIGGER ignore_one_restart_release
            BEFORE UPDATE OF active ON work_item_holds
            WHEN OLD.work_item_id='{cas_target}'
            BEGIN
                SELECT RAISE(IGNORE);
            END;
            """
        )

    with pytest.raises(RuntimeError, match=f"CAS failed.*{cas_target}"):
        mc._apply_restart_hold_release_transaction(
            db,
            release_note="must roll back",
            runtime_authorization=_runtime_authorization(),
        )

    with sqlite3.connect(db) as conn:
        placeholders = ",".join("?" for _ in RESTART_HOLD_IDS)
        rows = conn.execute(
            "SELECT work_item_id, active, released_at, release_note "
            f"FROM work_item_holds WHERE work_item_id IN ({placeholders}) ORDER BY work_item_id",
            RESTART_HOLD_IDS,
        ).fetchall()
        assert rows == [(work_item_id, 1, None, None) for work_item_id in sorted(RESTART_HOLD_IDS)]
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_transition_ledger "
            "WHERE action='release_hold'"
        ).fetchone()[0] == 0
        assert conn.execute(
            "SELECT COUNT(*) FROM events WHERE event='maintenance_hold_released'"
        ).fetchone()[0] == 0


def test_restart_release_ledger_collision_rolls_back_instead_of_ignoring(
    tmp_path: Path,
) -> None:
    _, db, _ = _prepare_restart_holds(tmp_path)
    collision_id = sorted(RESTART_HOLD_IDS)[0]
    with sqlite3.connect(db) as conn:
        created_at = conn.execute(
            "SELECT created_at FROM work_item_holds WHERE work_item_id=?",
            (collision_id,),
        ).fetchone()[0]
        conn.execute(
            """
            INSERT INTO work_item_transition_ledger(
                idempotency_key, ts, work_item_id, action, reason, run_id, detail_json
            ) VALUES (?, ?, ?, 'preexisting_collision', 'test', 'test', '{}')
            """,
            (
                f"restart-release:{collision_id}:{created_at}",
                mc.utc_now(),
                collision_id,
            ),
        )
        conn.commit()

    with pytest.raises(sqlite3.IntegrityError, match="UNIQUE constraint failed"):
        mc._apply_restart_hold_release_transaction(
            db,
            release_note="must roll back on ledger collision",
            runtime_authorization=_runtime_authorization(),
        )

    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_holds WHERE active=1 AND release_on_restart=1"
        ).fetchone()[0] == 7
        assert conn.execute(
            "SELECT COUNT(*) FROM events WHERE event='maintenance_hold_released'"
        ).fetchone()[0] == 0
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_transition_ledger WHERE action='release_hold'"
        ).fetchone()[0] == 0
        assert conn.execute(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' "
            "AND name='factory_runtime_activation_consumptions'"
        ).fetchone()[0] == 0


def test_restart_release_consumes_runtime_nonce_once_in_same_transaction(
    tmp_path: Path,
) -> None:
    _, db, _ = _prepare_restart_holds(tmp_path)
    runtime = _runtime_authorization()
    first = mc._apply_restart_hold_release_transaction(
        db,
        release_note="consume one-time OWNER activation",
        runtime_authorization=runtime,
    )
    assert first["runtime_activation_nonce_consumed"] == runtime["activation_nonce"]

    with sqlite3.connect(db) as conn:
        consumption = conn.execute(
            "SELECT activation_nonce, decision_id, decision_sha256, released_hold_count "
            "FROM factory_runtime_activation_consumptions"
        ).fetchall()
        assert consumption == [
            (
                runtime["activation_nonce"],
                runtime["decision_id"],
                runtime["decision_sha256"],
                7,
            )
        ]
        conn.execute(
            "UPDATE work_item_holds SET active=1, released_at=NULL, release_note=NULL "
            "WHERE release_on_restart=1"
        )
        conn.commit()

    with pytest.raises(sqlite3.IntegrityError, match="UNIQUE constraint failed"):
        mc._apply_restart_hold_release_transaction(
            db,
            release_note="nonce replay must abort",
            runtime_authorization=runtime,
        )

    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM factory_runtime_activation_consumptions"
        ).fetchone()[0] == 1
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_holds WHERE active=1 AND release_on_restart=1"
        ).fetchone()[0] == 7
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_transition_ledger WHERE action='release_hold'"
        ).fetchone()[0] == 7


@pytest.mark.parametrize("intent_kind", ["main_flag", "request_marker"])
def test_restart_release_rechecks_off_intent_inside_begin_immediate_window(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    intent_kind: str,
) -> None:
    _, db, _ = _prepare_restart_holds(tmp_path)
    flag = tmp_path / "FACTORY_OFF.flag"
    request = tmp_path / "FACTORY_OFF_REQUEST.flag"
    appeared = flag if intent_kind == "main_flag" else request
    real_check = mc._require_no_factory_off_intent
    checks = 0

    def inject_between_precheck_and_transaction(
        factory_off_flag: Path, factory_off_request: Path
    ) -> None:
        nonlocal checks
        checks += 1
        real_check(factory_off_flag, factory_off_request)
        if checks == 1:
            appeared.write_text("new emergency OFF intent\n", encoding="utf-8")

    monkeypatch.setattr(
        mc, "_require_no_factory_off_intent", inject_between_precheck_and_transaction
    )
    with pytest.raises(RuntimeError, match="OFF wins"):
        mc._apply_restart_hold_release_transaction(
            db,
            release_note="must abort for emergency OFF",
            runtime_authorization=_runtime_authorization(),
            factory_off_flag=flag,
            factory_off_request=request,
        )

    assert checks == 2
    assert appeared.exists()
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_holds WHERE active=1 AND release_on_restart=1"
        ).fetchone()[0] == 7
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_transition_ledger WHERE action='release_hold'"
        ).fetchone()[0] == 0
        assert conn.execute(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' "
            "AND name='factory_runtime_activation_consumptions'"
        ).fetchone()[0] == 0


def test_post_commit_evidence_failure_reports_committed_without_raising(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _, db, flag = _prepare_restart_holds(tmp_path)
    _allow_test_factory_on_context(monkeypatch)

    def fail_checkpoint(path: Path) -> dict[str, int]:
        raise RuntimeError(f"simulated evidence failure for {path}")

    monkeypatch.setattr(mc, "checkpoint_wal", fail_checkpoint)
    result = mc.release_restart_holds(
        db,
        factory_off_flag=flag,
        expected_db_sha256=None,
        apply=True,
        release_note="commit remains authoritative",
        factory_on_lock_nonce="unit-test-nonce",
    )

    assert result["mutation_committed"] is True
    assert result["post_commit_evidence"]["status"] == "FAILED_AFTER_COMMIT"
    assert "simulated evidence failure" in result["post_commit_evidence"]["errors"][0]
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_holds WHERE active=1 AND release_on_restart=1"
        ).fetchone()[0] == 0
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_transition_ledger WHERE action='release_hold'"
        ).fetchone()[0] == 7


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
