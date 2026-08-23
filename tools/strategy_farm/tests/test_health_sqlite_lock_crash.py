from __future__ import annotations

import datetime as dt
import json
import sqlite3

from tools.strategy_farm import health


def _connection() -> sqlite3.Connection:
    connection = sqlite3.connect(":memory:")
    connection.execute(
        """
        CREATE TABLE work_items(
            id TEXT,ea_id TEXT,symbol TEXT,phase TEXT,verdict TEXT,
            payload_json TEXT,updated_at TEXT
        )
        """
    )
    return connection


def test_health_counts_only_recent_sqlite_lock_worker_crash_infra() -> None:
    now = dt.datetime(2026, 8, 23, 18, tzinfo=dt.timezone.utc)
    connection = _connection()
    payload = json.dumps({
        "verdict_reason": "worker_crashed_handling_item",
        "worker_crash_traceback_tail": ["sqlite3.OperationalError: database is locked"],
    })
    connection.executemany(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?)",
        [
            ("494651b2-x", "QM5_9641", "WS30.DWX", "Q10_NEWS", "INFRA_FAIL", payload,
             "2026-08-23T16:25:02+00:00"),
            ("old", "QM5_1", "EURUSD.DWX", "Q02", "INFRA_FAIL", payload,
             "2026-08-21T16:25:02+00:00"),
            ("merit", "QM5_2", "EURUSD.DWX", "Q02", "FAIL", payload,
             "2026-08-23T17:00:00+00:00"),
        ],
    )

    result = health.chk_sqlite_lock_crash_infra_24h(connection, now=now)

    assert result["status"] == "FAIL"
    assert result["value"] == 1
    assert "494651b2" in result["detail"]


def test_health_is_ok_without_lock_crash_rows() -> None:
    connection = _connection()
    result = health.chk_sqlite_lock_crash_infra_24h(
        connection,
        now=dt.datetime(2026, 8, 23, 18, tzinfo=dt.timezone.utc),
    )
    assert result["status"] == "OK"
    assert result["value"] == 0
