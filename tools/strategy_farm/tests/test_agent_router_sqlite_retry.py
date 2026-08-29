import sqlite3
from pathlib import Path

from tools.strategy_farm import agent_router


def test_update_task_retries_whole_operation_after_busy(monkeypatch) -> None:
    calls = []

    def operation(*args, **kwargs):
        calls.append((args, kwargs))
        if len(calls) == 1:
            raise sqlite3.OperationalError("database is locked")
        return {"updated": True}

    monkeypatch.setattr(agent_router, "_update_task_once", operation)
    monkeypatch.setattr("tools.strategy_farm.sqlite_busy.time.sleep", lambda _: None)

    result = agent_router.update_task(Path("D:/farm"), "task-1", state="REVIEW")

    assert result == {"updated": True}
    assert len(calls) == 2


def test_close_review_retries_whole_operation_after_busy(monkeypatch) -> None:
    calls = []

    def operation(*args, **kwargs):
        calls.append((args, kwargs))
        if len(calls) == 1:
            raise sqlite3.OperationalError("database table is locked")
        return {"closed": True}

    monkeypatch.setattr(agent_router, "_close_review_task_once", operation)
    monkeypatch.setattr("tools.strategy_farm.sqlite_busy.time.sleep", lambda _: None)

    result = agent_router.close_review_task(
        Path("D:/farm"), "task-1", close_state="APPROVED", verdict="PASS"
    )

    assert result == {"closed": True}
    assert len(calls) == 2
