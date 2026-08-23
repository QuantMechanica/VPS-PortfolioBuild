from __future__ import annotations

import sqlite3

import pytest

from tools.strategy_farm import sqlite_busy


def test_retry_sqlite_busy_uses_bounded_exponential_jitter() -> None:
    calls = 0
    sleeps: list[float] = []

    def operation() -> str:
        nonlocal calls
        calls += 1
        if calls < 4:
            raise sqlite3.OperationalError("database is locked")
        return "committed"

    result = sqlite_busy.retry_sqlite_busy(
        operation,
        attempts=5,
        base_delay_seconds=0.1,
        max_delay_seconds=0.25,
        jitter_seconds=0.05,
        sleep=sleeps.append,
        random_uniform=lambda _low, high: high,
    )

    assert result == "committed"
    assert calls == 4
    assert sleeps == pytest.approx([0.15, 0.25, 0.30])


def test_retry_sqlite_busy_does_not_retry_non_contention_error() -> None:
    calls = 0

    def operation() -> None:
        nonlocal calls
        calls += 1
        raise sqlite3.OperationalError("no such table: missing")

    with pytest.raises(sqlite3.OperationalError, match="no such table"):
        sqlite_busy.retry_sqlite_busy(operation, sleep=lambda _seconds: None)
    assert calls == 1


def test_configure_connection_applies_short_busy_timeout() -> None:
    connection = sqlite3.connect(":memory:")
    try:
        sqlite_busy.configure_connection(connection)
        assert connection.execute("PRAGMA busy_timeout").fetchone()[0] == 750
    finally:
        connection.close()
