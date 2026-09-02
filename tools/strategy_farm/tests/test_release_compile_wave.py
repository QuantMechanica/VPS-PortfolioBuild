import hashlib
import json
import os
import sqlite3
import time
from pathlib import Path

import pytest

from tools.strategy_farm import release_compile_wave as rollout


def _fixture(tmp_path: Path):
    db = tmp_path / "farm.sqlite"
    repo = tmp_path / "repo"
    ea_label = "QM5_1001_example"
    source = repo / "framework" / "EAs" / ea_label / f"{ea_label}.mq5"
    source.parent.mkdir(parents=True)
    source.write_text("void OnTick() {}\n", encoding="utf-8")
    source_sha = hashlib.sha256(source.read_bytes()).hexdigest()
    conn = sqlite3.connect(db)
    conn.executescript(
        """
        CREATE TABLE work_items(id TEXT PRIMARY KEY,ea_id TEXT,phase TEXT,status TEXT,
          claimed_by TEXT,verdict TEXT,payload_json TEXT,created_at TEXT);
        CREATE TABLE work_item_holds(work_item_id TEXT PRIMARY KEY,hold_code TEXT,
          active INTEGER,release_on_restart INTEGER,created_at TEXT,updated_at TEXT,
          released_at TEXT,release_note TEXT);
        CREATE TABLE work_item_transition_ledger(seq INTEGER PRIMARY KEY AUTOINCREMENT,
          idempotency_key TEXT UNIQUE,ts TEXT,work_item_id TEXT,action TEXT,reason TEXT,
          run_id TEXT,detail_json TEXT);
        CREATE TABLE events(ts TEXT,entity_type TEXT,entity_id TEXT,event TEXT,detail_json TEXT);
        CREATE TABLE agent_tasks(id TEXT PRIMARY KEY);
        """
    )
    payload = json.dumps({"ea_label": ea_label, "mq5_sha256": source_sha})
    conn.execute("INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?)", ("one", "QM5_1001", "COMPILE_EA", "pending", None, None, payload, "2026-01-01"))
    conn.execute("INSERT INTO work_item_holds VALUES(?,?,?,?,?,?,?,?)", ("one", rollout.HOLD_CODE, 1, 1, "2026-01-01", "2026-01-01", None, None))
    conn.commit()
    conn.close()
    return db, repo, source


def test_apply_releases_only_hold_and_records_audit(tmp_path):
    db, repo, _ = _fixture(tmp_path)
    result = rollout.apply_wave(db, repo, tmp_path / "backups", 1, "canary")
    assert result["applied"] == 1
    assert Path(result["backup"]["path"]).stat().st_size > 0
    assert result["backup_write_guard"]["transaction"].endswith("/ COMMIT")
    assert result["factory_mutation_lock"]["release_status"] == "released"
    assert not (tmp_path / "FACTORY_MUTATION.lock").exists()
    conn = sqlite3.connect(db)
    assert conn.execute("SELECT status FROM work_items WHERE id='one'").fetchone()[0] == "pending"
    assert conn.execute("SELECT active FROM work_item_holds WHERE work_item_id='one'").fetchone()[0] == 0
    assert conn.execute("SELECT action FROM work_item_transition_ledger").fetchone()[0] == "release_hold"
    conn.close()


def test_stale_source_is_deferred(tmp_path):
    db, repo, source = _fixture(tmp_path)
    source.write_text("changed\n", encoding="utf-8")
    plan = rollout.inspect(db, repo, 1)
    assert plan["release_count"] == 0
    assert plan["deferred"][0]["reason"] == "SOURCE_SHA_STALE_OR_MISSING"


def test_backup_timeout_removes_partial_snapshot(tmp_path):
    db, _, _ = _fixture(tmp_path)
    backup_dir = tmp_path / "backups"

    with pytest.raises(TimeoutError, match="COMPILE_WAVE_BACKUP_TIMEOUT"):
        rollout._backup(db, backup_dir, timeout_seconds=1e-9)

    assert list(backup_dir.glob("*.partial")) == []


def test_exact_selector_releases_only_requested_item(tmp_path):
    db, repo, _ = _fixture(tmp_path)
    with sqlite3.connect(db) as conn:
        payload = conn.execute(
            "SELECT payload_json FROM work_items WHERE id='one'"
        ).fetchone()[0]
        conn.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?)",
            ("two", "QM5_1001", "COMPILE_EA", "pending", None, None, payload, "2026-01-02"),
        )
        conn.execute(
            "INSERT INTO work_item_holds VALUES(?,?,?,?,?,?,?,?)",
            (
                "two",
                rollout.HOLD_CODE,
                1,
                1,
                "2026-01-02",
                "2026-01-02",
                None,
                None,
            ),
        )

    plan = rollout.inspect(db, repo, 1, "two")
    assert plan["work_item_id_selector"] == "two"
    assert [item["work_item_id"] for item in plan["release"]] == ["two"]

    result = rollout.apply_wave(db, repo, tmp_path / "backups", 1, "retry canary", "two")
    assert result["applied_work_item_ids"] == ["two"]
    with sqlite3.connect(db) as conn:
        holds = dict(conn.execute("SELECT work_item_id,active FROM work_item_holds"))
        detail = json.loads(
            conn.execute("SELECT detail_json FROM work_item_transition_ledger").fetchone()[0]
        )
    assert holds == {"one": 1, "two": 0}
    assert detail["work_item_id_selector"] == "two"


# --- backup reuse (release_compile_wave._resolve_backup and callers) ---------


def test_apply_wave_backup_records_identity_and_writes_sidecar(tmp_path):
    """A fresh backup is written with reused=False and a matching sidecar."""
    db, repo, _ = _fixture(tmp_path)
    result = rollout.apply_wave(db, repo, tmp_path / "backups", 1, "canary")
    assert result["backup"]["reused"] is False
    assert result["backup"]["identity_established"] is True
    assert result["backup_reuse_max_age_minutes"] == rollout.DEFAULT_BACKUP_REUSE_MAX_AGE_MINUTES
    sidecar = rollout._identity_sidecar_path(Path(result["backup"]["path"]))
    assert sidecar.is_file()
    identity = json.loads(sidecar.read_text(encoding="utf-8"))
    assert identity["backup_sha256"] == result["backup"]["sha256"]
    assert identity["row_counts"] == {"work_items": 1, "agent_tasks": 0, "work_item_holds": 1}


def test_resolve_backup_reuses_fresh_identity_matched_backup(tmp_path):
    """A second call with an unchanged DB reuses the first backup instead of writing a new one."""
    db, _, _ = _fixture(tmp_path)
    backup_dir = tmp_path / "backups"
    conn = sqlite3.connect(db)
    try:
        first = rollout._resolve_backup(conn, db, backup_dir, timeout_seconds=5.0, reuse_max_age_minutes=60.0)
        assert first["reused"] is False
        assert rollout._identity_sidecar_path(Path(first["path"])).is_file()

        second = rollout._resolve_backup(conn, db, backup_dir, timeout_seconds=5.0, reuse_max_age_minutes=60.0)
    finally:
        conn.close()

    assert second["reused"] is True
    assert second["path"] == first["path"]
    assert second["sha256"] == first["sha256"]
    assert second["identity_established"] is True
    assert len(list(backup_dir.glob("*.sqlite"))) == 1


def test_resolve_backup_does_not_reuse_after_real_db_mutation(tmp_path):
    """Fail-closed: a genuine DB change between calls forces a fresh backup, never a stale reuse."""
    db, _, _ = _fixture(tmp_path)
    backup_dir = tmp_path / "backups"
    conn = sqlite3.connect(db)
    try:
        first = rollout._resolve_backup(conn, db, backup_dir, timeout_seconds=5.0, reuse_max_age_minutes=60.0)
        conn.execute("INSERT INTO agent_tasks(id) VALUES('t1')")
        conn.commit()

        second = rollout._resolve_backup(conn, db, backup_dir, timeout_seconds=5.0, reuse_max_age_minutes=60.0)
    finally:
        conn.close()

    assert second["reused"] is False
    assert second["path"] != first["path"]
    assert len(list(backup_dir.glob("*.sqlite"))) == 2


def test_resolve_backup_ignores_sidecar_older_than_reuse_window(tmp_path):
    """Fail-closed: a matching-but-stale sidecar (older than N minutes) is not reused."""
    db, _, _ = _fixture(tmp_path)
    backup_dir = tmp_path / "backups"
    conn = sqlite3.connect(db)
    try:
        first = rollout._resolve_backup(conn, db, backup_dir, timeout_seconds=5.0, reuse_max_age_minutes=60.0)
        sidecar = rollout._identity_sidecar_path(Path(first["path"]))
        old_ts = time.time() - (2 * 3600)
        os.utime(sidecar, (old_ts, old_ts))

        second = rollout._resolve_backup(conn, db, backup_dir, timeout_seconds=5.0, reuse_max_age_minutes=60.0)
    finally:
        conn.close()

    assert second["reused"] is False
    assert len(list(backup_dir.glob("*.sqlite"))) == 2


def test_resolve_backup_fails_closed_when_identity_table_missing(tmp_path):
    """Fail-closed: identity cannot be established (missing table) -> always a fresh backup, no sidecar."""
    db = tmp_path / "partial_schema.sqlite"
    conn = sqlite3.connect(db)
    conn.executescript(
        "CREATE TABLE work_items(id TEXT PRIMARY KEY);"
        "CREATE TABLE work_item_holds(work_item_id TEXT PRIMARY KEY);"
        # agent_tasks intentionally missing
    )
    conn.commit()
    backup_dir = tmp_path / "backups"
    try:
        first = rollout._resolve_backup(conn, db, backup_dir, timeout_seconds=5.0, reuse_max_age_minutes=60.0)
        second = rollout._resolve_backup(conn, db, backup_dir, timeout_seconds=5.0, reuse_max_age_minutes=60.0)
    finally:
        conn.close()

    assert first["reused"] is False
    assert first["identity_established"] is False
    assert not rollout._identity_sidecar_path(Path(first["path"])).is_file()
    assert second["reused"] is False
    assert second["path"] != first["path"]
    assert len(list(backup_dir.glob("*.sqlite"))) == 2


def test_resolve_backup_disabled_via_zero_max_age(tmp_path):
    """reuse_max_age_minutes<=0 disables reuse entirely, per-call."""
    db, _, _ = _fixture(tmp_path)
    backup_dir = tmp_path / "backups"
    conn = sqlite3.connect(db)
    try:
        first = rollout._resolve_backup(conn, db, backup_dir, timeout_seconds=5.0, reuse_max_age_minutes=0.0)
        second = rollout._resolve_backup(conn, db, backup_dir, timeout_seconds=5.0, reuse_max_age_minutes=0.0)
    finally:
        conn.close()

    assert first["reused"] is False
    assert second["reused"] is False
    assert len(list(backup_dir.glob("*.sqlite"))) == 2


def test_env_default_backup_reuse_max_age_minutes(monkeypatch):
    monkeypatch.delenv("QM_COMPILE_WAVE_BACKUP_REUSE_MAX_AGE_MINUTES", raising=False)
    assert (
        rollout._env_default_backup_reuse_max_age_minutes()
        == rollout.DEFAULT_BACKUP_REUSE_MAX_AGE_MINUTES
    )
    monkeypatch.setenv("QM_COMPILE_WAVE_BACKUP_REUSE_MAX_AGE_MINUTES", "15")
    assert rollout._env_default_backup_reuse_max_age_minutes() == 15.0
    monkeypatch.setenv("QM_COMPILE_WAVE_BACKUP_REUSE_MAX_AGE_MINUTES", "not-a-number")
    assert (
        rollout._env_default_backup_reuse_max_age_minutes()
        == rollout.DEFAULT_BACKUP_REUSE_MAX_AGE_MINUTES
    )
