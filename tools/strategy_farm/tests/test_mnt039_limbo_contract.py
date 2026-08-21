from __future__ import annotations

import datetime as dt
import json
import sqlite3
import tempfile
from pathlib import Path

from tools.strategy_farm import agent_router, farmctl, health, work_identity


def _memory_db() -> sqlite3.Connection:
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.executescript(
        """
        CREATE TABLE agent_tasks (
            id TEXT PRIMARY KEY, task_type TEXT, state TEXT, parent_id TEXT,
            payload_json TEXT, updated_at TEXT
        );
        CREATE TABLE work_items (
            id TEXT PRIMARY KEY, phase TEXT, ea_id TEXT, symbol TEXT,
            attempt_count INTEGER, parent_task_id TEXT, payload_json TEXT
        );
        """
    )
    return con


def test_canonical_identity_unifies_agent_link_with_append_only_retry_root() -> None:
    con = _memory_db()
    con.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?)",
        ("wi-root", "P2", "QM5_9", "EURUSD.DWX", 0, "farm-parent", "{}"),
    )
    con.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?)",
        (
            "wi-retry",
            "Q02",
            "QM5_9",
            "EURUSD.DWX",
            1,
            "farm-parent",
            json.dumps({"append_only_rerun_of_work_item": "wi-root"}),
        ),
    )
    con.execute(
        "INSERT INTO agent_tasks VALUES (?,?,?,?,?,?)",
        ("agent-root", "ops_issue", "REVIEW", None, "{}", "2026-08-21T00:00:00Z"),
    )
    con.execute(
        "INSERT INTO agent_tasks VALUES (?,?,?,?,?,?)",
        (
            "agent-review",
            "review_ea",
            "RECYCLE",
            "agent-root",
            json.dumps({"source_work_item_id": "wi-retry", "recycle_count": 2}),
            "2026-08-21T00:00:00Z",
        ),
    )
    row = con.execute("SELECT * FROM agent_tasks WHERE id='agent-review'").fetchone()
    ident = work_identity.agent_task_identity(con, row)
    assert ident["schema_version"] == "qm.work_identity.v1"
    assert ident["stable_key"] == "work_item:wi-root"
    assert ident["root_agent_task_id"] == "agent-root"
    assert ident["root_work_item_id"] == "wi-root"
    assert ident["work_item_retry_chain"] == ["wi-retry", "wi-root"]
    assert ident["retry_ordinal"] == 2


def test_recycle_sweeper_records_stable_identity_and_second_run_is_noop() -> None:
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        root = Path(tmp)
        farmctl.init_db(root)
        created = agent_router.enqueue_task(
            root,
            "build_ea",
            state="RECYCLE",
            payload={"ea_id": "QM5_9009"},
        )
        first = agent_router.reconcile_task_exits(
            root, apply=True, states=["RECYCLE"]
        )
        second = agent_router.reconcile_task_exits(
            root, apply=True, states=["RECYCLE"]
        )
        assert first["moved_count"] == 1
        assert first["moved"][0]["work_identity_key"] == (
            f"agent_task:{created['task_id']}"
        )
        assert second["moved_count"] == 0
        assert second["would_move"] == {}
        with agent_router.connect(root) as con:
            row = con.execute(
                "SELECT state, payload_json FROM agent_tasks WHERE id=?",
                (created["task_id"],),
            ).fetchone()
        payload = json.loads(row["payload_json"])
        assert row["state"] == "TODO"
        assert payload["work_identity"]["stable_key"] == (
            f"agent_task:{created['task_id']}"
        )
        assert payload["exit_reconciliations"][-1]["work_identity_key"] == (
            f"agent_task:{created['task_id']}"
        )


def test_per_class_aging_slo_fires_on_synthetic_stale_fixture(monkeypatch) -> None:
    con = _memory_db()
    now = dt.datetime(2026, 8, 21, 12, 0, tzinfo=dt.timezone.utc)
    monkeypatch.setattr(health, "_utc_now", lambda: now)
    stale = "2026-08-17T11:59:59Z"
    fresh = "2026-08-20T12:00:00Z"
    for index, state in enumerate(("RECYCLE", "PIPELINE", "BLOCKED")):
        con.execute(
            "INSERT INTO agent_tasks VALUES (?,?,?,?,?,?)",
            (f"stale-{index}", "ops_issue", state, None, "{}", stale),
        )
    con.execute(
        "INSERT INTO agent_tasks VALUES (?,?,?,?,?,?)",
        ("fresh", "ops_issue", "RECYCLE", None, "{}", fresh),
    )
    result = health.chk_agent_task_aging_slo(con)
    assert result["name"] == "agent_task_aging_slo"
    assert result["status"] == "FAIL"
    assert result["value"] == 3
    for state in ("RECYCLE", "PIPELINE", "BLOCKED"):
        assert f"{state}=1" in result["detail"]


def test_per_class_aging_slo_is_registered_and_green_without_stale_rows(monkeypatch) -> None:
    con = _memory_db()
    now = dt.datetime(2026, 8, 21, 12, 0, tzinfo=dt.timezone.utc)
    monkeypatch.setattr(health, "_utc_now", lambda: now)
    con.execute(
        "INSERT INTO agent_tasks VALUES (?,?,?,?,?,?)",
        ("fresh", "ops_issue", "BLOCKED", None, "{}", "2026-08-20T12:00:00Z"),
    )
    result = health.chk_agent_task_aging_slo(con)
    assert result["status"] == "OK"
    assert any(name == "agent_task_aging_slo" for name, _, _ in health.ALL_CHECKS)
