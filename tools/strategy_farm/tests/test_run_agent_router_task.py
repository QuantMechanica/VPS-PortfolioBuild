from __future__ import annotations

import json
import sqlite3

from tools.strategy_farm import run_agent_router_task as task


def test_router_failure_log_preserves_successful_owner_reconcile(
    tmp_path, monkeypatch,
) -> None:
    monkeypatch.setattr(task, "LOG_DIR", tmp_path)
    monkeypatch.setattr(task, "_arm_wall_clock_watchdog", lambda _path: None)
    monkeypatch.setattr(task, "_concurrent_router_processes", lambda: [])
    monkeypatch.setattr(
        task.owner_decision_execution,
        "reconcile_receipts",
        lambda **_kwargs: {"ok": True, "receipt_count": 0, "results": [], "errors": []},
    )

    def fail_router(*_args, **_kwargs):
        raise sqlite3.OperationalError("database is locked")

    monkeypatch.setattr(task.agent_router, "run_once", fail_router)

    assert task.main() == 1
    logs = list(tmp_path.glob("agent_router_task_*.json"))
    assert len(logs) == 1
    payload = json.loads(logs[0].read_text(encoding="utf-8"))
    assert payload["ok"] is False
    assert payload["owner_decision_handoffs"]["ok"] is True
    assert "database is locked" in payload["error"]
