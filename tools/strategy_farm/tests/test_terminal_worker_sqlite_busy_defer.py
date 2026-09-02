from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from unittest.mock import patch

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


def _fast_retry_spy(seen: list[dict[str, object]]):
    real_retry = terminal_worker.retry_sqlite_busy

    def _retry(operation, **kwargs):
        seen.append(dict(kwargs))
        return real_retry(
            operation,
            **kwargs,
            sleep=lambda _seconds: None,
            random_uniform=lambda _low, _high: 0.0,
        )

    return _retry


def test_post_claim_payload_write_outlasts_old_retry_budget(tmp_path: Path) -> None:
    database = tmp_path / farmctl.DB_REL
    _minimal_work_items(database)
    real_connect = terminal_worker.farmctl.connect
    connect_attempts = 0
    seen: list[dict[str, object]] = []

    def _busy_then_connect(root: Path):
        nonlocal connect_attempts
        connect_attempts += 1
        if connect_attempts <= 12:
            raise sqlite3.OperationalError("database is locked")
        return real_connect(root)

    with (
        patch.object(terminal_worker, "retry_sqlite_busy", _fast_retry_spy(seen)),
        patch.object(terminal_worker.farmctl, "connect", side_effect=_busy_then_connect),
    ):
        recorded = terminal_worker._record_active_payload(
            tmp_path,
            "item-1",
            {"claimed_by_worker_pid": 123, "post_claim_recorded": True},
            terminal="T10",
        )

    assert recorded is True
    assert connect_attempts == 13
    assert seen == [
        {
            "attempts": terminal_worker.POST_CLAIM_SQLITE_WRITE_RETRIES,
            "base_delay_seconds": terminal_worker.POST_CLAIM_SQLITE_WRITE_RETRY_SLEEP_SECONDS,
        }
    ]
    assert seen[0]["attempts"] == 20
    assert seen[0]["base_delay_seconds"] == 0.5


def test_sqlite_busy_defer_outlasts_old_retry_budget(tmp_path: Path) -> None:
    database = tmp_path / farmctl.DB_REL
    _minimal_work_items(database)
    real_connect = terminal_worker.farmctl.connect
    connect_attempts = 0
    seen: list[dict[str, object]] = []

    def _busy_then_connect(root: Path):
        nonlocal connect_attempts
        connect_attempts += 1
        if connect_attempts <= 12:
            raise sqlite3.OperationalError("database is locked")
        return real_connect(root)

    with (
        patch.object(terminal_worker, "retry_sqlite_busy", _fast_retry_spy(seen)),
        patch.object(terminal_worker.farmctl, "connect", side_effect=_busy_then_connect),
    ):
        deferred = terminal_worker._defer_item_after_sqlite_busy(
            tmp_path,
            {"id": "item-1"},
            "T10",
            sqlite3.OperationalError("database is locked"),
        )

    assert deferred is True
    assert connect_attempts == 13
    assert seen == [
        {
            "attempts": terminal_worker.ORPHAN_DEFER_RELEASE_RETRY_ATTEMPTS,
            "base_delay_seconds": terminal_worker.ORPHAN_DEFER_RELEASE_RETRY_BASE_SECONDS,
            "max_delay_seconds": terminal_worker.ORPHAN_DEFER_RELEASE_RETRY_MAX_SECONDS,
        }
    ]
    # The release envelope now spans ~60s of exponential backoff, comfortably
    # more than the old 20-attempt post-claim budget, so a lock storm that
    # briefly outlasts the claim window still returns the row to pending.
    assert terminal_worker.ORPHAN_DEFER_RELEASE_RETRY_ATTEMPTS >= 30
