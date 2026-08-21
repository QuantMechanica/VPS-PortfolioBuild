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


def _phase_slo_db() -> sqlite3.Connection:
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.execute(
        """
        CREATE TABLE work_items (
            id TEXT PRIMARY KEY, phase TEXT, status TEXT, ea_id TEXT, symbol TEXT,
            created_at TEXT, updated_at TEXT
        )
        """
    )
    return con


def test_phase_age_slo_uses_own_measured_p95_and_refuses_stale_row() -> None:
    con = _phase_slo_db()
    # Twenty terminal Q02/P2 rows make nearest-rank p95 exactly 19 hours.
    for hour in range(1, 21):
        con.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?)",
            (
                f"done-{hour}", "P2" if hour % 2 else "Q02", "done", "QM5_9",
                "EURUSD.DWX", "2026-08-01T00:00:00Z",
                f"2026-08-01T{hour:02d}:00:00Z",
            ),
        )
    con.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?)",
        (
            "stale", "Q02", "pending", "QM5_10", "GBPUSD.DWX",
            "2026-08-01T00:00:00Z", "2026-08-01T00:00:00Z",
        ),
    )
    snapshot = health.phase_age_slo_snapshot(
        con, now=dt.datetime(2026, 8, 1, 20, 0, tzinfo=dt.timezone.utc)
    )
    q02 = snapshot["phases"]["Q02"]
    assert q02["terminal_sample_count"] == 20
    assert q02["threshold_seconds"] == 19 * 3600
    assert q02["violation_count"] == 1
    assert q02["violations"][0]["id"] == "stale"


def test_phase_age_slo_surfaces_unknown_history_and_is_registered(monkeypatch) -> None:
    con = _phase_slo_db()
    con.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?)",
        (
            "open", "Q09_NEWS", "pending", "QM5_11", "USDJPY.DWX",
            "2026-08-01T00:00:00Z", "2026-08-01T00:00:00Z",
        ),
    )
    monkeypatch.setattr(
        health,
        "_utc_now",
        lambda: dt.datetime(2026, 8, 2, 0, 0, tzinfo=dt.timezone.utc),
    )
    result = health.chk_work_item_phase_age_slo(con)
    assert result["status"] == "WARN"
    assert result["value"] == "UNKNOWN"
    assert "Q09_NEWS=1 open/no terminal sample" in result["detail"]
    assert any(name == "work_item_phase_age_slo" for name, _, _ in health.ALL_CHECKS)
