from __future__ import annotations

import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import farmctl, terminal_worker


def _minimal_work_items(database: Path) -> None:
    database.parent.mkdir(parents=True)
    with sqlite3.connect(database) as connection:
        connection.execute(
            """
            CREATE TABLE work_items(
                id TEXT PRIMARY KEY,status TEXT,verdict TEXT,claimed_by TEXT,
                payload_json TEXT,updated_at TEXT
            )
            """
        )
        connection.execute(
            "INSERT INTO work_items VALUES('item-1','active',NULL,'T10',?,?)",
            (json.dumps({"claimed_by_worker_pid": 123, "pid": None}), farmctl.utc_now()),
        )


def test_sqlite_busy_defer_returns_active_item_to_pending_without_infra(tmp_path: Path) -> None:
    database = tmp_path / farmctl.DB_REL
    _minimal_work_items(database)

    deferred = terminal_worker._defer_item_after_sqlite_busy(
        tmp_path,
        {"id": "item-1"},
        "T10",
        sqlite3.OperationalError("database is locked"),
    )

    assert deferred is True
    with sqlite3.connect(database) as connection:
        status, verdict, claimed_by, raw = connection.execute(
            "SELECT status,verdict,claimed_by,payload_json FROM work_items WHERE id='item-1'"
        ).fetchone()
    payload = json.loads(raw)
    assert (status, verdict, claimed_by) == ("pending", None, None)
    assert payload["sqlite_busy_deferred_operation"] == "run_claimed_item_pre_spawn"
    assert payload["sqlite_busy_error"] == "database is locked"
    assert "verdict_reason" not in payload
