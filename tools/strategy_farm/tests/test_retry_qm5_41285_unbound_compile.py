from __future__ import annotations

import sqlite3
from pathlib import Path

from tools.strategy_farm import retry_qm5_41285_unbound_compile as retry


def test_online_backup_completes_under_reserved_write_guard(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    state = root / "state"
    state.mkdir(parents=True)
    db = state / "farm_state.sqlite"
    with sqlite3.connect(db) as conn:
        conn.execute("CREATE TABLE fixture(value TEXT NOT NULL)")
        conn.execute("INSERT INTO fixture(value) VALUES ('preimage')")
        conn.commit()

    guard, detail = retry.acquire_backup_write_guard(root, timeout_seconds=1.0)
    try:
        backup, digest = retry.backup_database(root, tmp_path / "backups")
    finally:
        guard.rollback()
        guard.close()

    assert detail["transaction"] == "BEGIN IMMEDIATE / caller-owned"
    assert len(digest) == 64
    with sqlite3.connect(backup) as copied:
        assert copied.execute("PRAGMA quick_check").fetchone()[0] == "ok"
        assert copied.execute("SELECT value FROM fixture").fetchone()[0] == "preimage"
    with sqlite3.connect(db) as original:
        assert original.execute("SELECT value FROM fixture").fetchone()[0] == "preimage"
