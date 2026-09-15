"""Regression tests for the Claude-lane session fan-out fix.

OWNER-DEC-CBE-20260915 §35 / audit `claude_lane_fanout_defect.md`.

Before the fix, ``--max-sessions 3`` spawned three task-agnostic Claude sessions
that each worked every IN_PROGRESS task, so one ticket was worked N times. The
fix binds each spawned session to exactly one task via a pid-owned exec-lease
(``agent_task_exec:<id>``) acquired BEFORE the spawn, making --max-sessions an
upper bound on concurrently leased tasks rather than an N*M multiplier.
"""

from __future__ import annotations

import datetime as dt
import os
import sys
import threading
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import run_agent_orchestration_task as orch  # noqa: E402


def _prepare_farm(tmp_path, monkeypatch):
    """Point the launcher at an isolated tmp farm DB with the lease schema."""
    farm_root = tmp_path / "farm"
    (farm_root / "state").mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(orch, "FARM_ROOT", farm_root)
    # Create the DB so spawn_leases exists.
    conn = orch.agent_router.connect(farm_root)
    conn.close()
    return farm_root


def _stub_claude_gates(monkeypatch, max_sessions=3):
    monkeypatch.setattr(orch, "CLAUDE_DISABLED_FLAG", Path(r"C:\does\not\exist.flag"))
    monkeypatch.setattr(orch, "_write_lane_heartbeat", lambda *_a, **_k: None)
    monkeypatch.setattr(
        orch,
        "claude_budget_check",
        lambda requested: {"allowed": True, "effective_max_sessions": max_sessions},
    )
    monkeypatch.setattr(orch, "claude_work_available", lambda: {"any_work": True})
    monkeypatch.setattr(
        orch,
        "_quota_lane_check",
        lambda _agent: {"allowed": True, "allowed_task_count": max_sessions, "allowed_invocations": []},
    )


def _record_slots(monkeypatch):
    """Replace run_agent_slot with a thread-safe recorder returning ok."""
    calls: list[dict] = []
    lock = threading.Lock()

    def fake_slot(agent, slot, dry_run, stale_minutes, timeout_minutes,
                  invocation_profile=None, session_lease=None,
                  assigned_task_id=None, exec_lease=None):
        with lock:
            calls.append(
                {
                    "agent": agent,
                    "slot": slot,
                    "assigned_task_id": assigned_task_id,
                    "exec_lease_task": (exec_lease or {}).get("task_id"),
                }
            )
        # In production the child would release its own exec-lease; here the
        # caller's backstop finally handles release, so just return ok.
        return {"ok": True, "slot": slot, "assigned_task_id": assigned_task_id}

    monkeypatch.setattr(orch, "run_agent_slot", fake_slot)
    return calls


def _candidates(*task_ids):
    return [
        {
            "task_id": tid,
            "task_type": "ops_issue",
            "priority": 80 - i,
            "assigned": True,
            "budget_class": "standard",
            "required_capabilities": [],
            "payload": {},
        }
        for i, tid in enumerate(task_ids)
    ]


def test_launcher_claims_distinct_tasks_before_spawn(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    _stub_claude_gates(monkeypatch, max_sessions=3)
    monkeypatch.setattr(
        orch, "_quota_lane_candidates", lambda _a: (_candidates("T1", "T2"), "ok")
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "claude", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=3, session_lease=None,
    )

    # Two eligible tasks, --max-sessions 3 => exactly two sessions, no third.
    assert result["ok"] is True
    assert len(calls) == 2
    assert result["max_sessions"] == 2
    ids = {c["assigned_task_id"] for c in calls}
    assert ids == {"T1", "T2"}
    # Every session's pin matches its exec-lease.
    for c in calls:
        assert c["assigned_task_id"] == c["exec_lease_task"]
    assert set(result["leased_task_ids"]) == {"T1", "T2"}


def test_max_sessions_bounds_disjoint_task_sets(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    _stub_claude_gates(monkeypatch, max_sessions=3)
    monkeypatch.setattr(
        orch,
        "_quota_lane_candidates",
        lambda _a: (_candidates("A", "B", "C", "D", "E"), "ok"),
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "claude", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=3, session_lease=None,
    )

    # 5 tasks, cap 3 => at most 3 sessions with a disjoint task set.
    assert len(calls) == 3
    ids = [c["assigned_task_id"] for c in calls]
    assert len(set(ids)) == 3  # disjoint
    assert set(ids).issubset({"A", "B", "C", "D", "E"})


def test_second_launcher_cannot_reclaim_pinned_task(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    # A foreign live session already pins T.
    acquired, foreign = orch.acquire_task_exec_lease("claude", "T", owner_pid=999_999)
    assert acquired is True

    # The launcher's claim helper refuses the pinned task.
    won = orch.claim_task_exec_leases("claude", ["T"], 3, owner_pid=os.getpid())
    assert won == []

    # And end-to-end the launcher spawns nothing rather than a duplicate.
    _stub_claude_gates(monkeypatch, max_sessions=3)
    monkeypatch.setattr(
        orch, "_quota_lane_candidates", lambda _a: (_candidates("T"), "ok")
    )
    calls = _record_slots(monkeypatch)
    result = orch._run_agent_with_session_lease(
        "claude", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=3, session_lease=None,
    )
    assert result["skipped"] is True
    assert result["reason"] == "no_unpinned_claude_task"
    assert calls == []
    orch.release_task_exec_lease(foreign)


def test_crashed_owner_lease_is_stolen_after_ttl(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    t0 = dt.datetime(2026, 9, 15, 12, 0, tzinfo=dt.UTC)
    # A crashed owner's lease (foreign pid) acquired at t0, TTL 30 min.
    acquired, _crashed = orch.acquire_task_exec_lease(
        "claude", "T", now=t0, owner_pid=999_999
    )
    assert acquired is True

    # Before expiry a healthy launcher cannot steal it.
    early, _info = orch.acquire_task_exec_lease(
        "claude", "T", now=t0 + dt.timedelta(minutes=29), owner_pid=os.getpid()
    )
    assert early is False

    # After the TTL the expired lease is stolen by pid liveness fail-safe (expiry).
    stolen, info = orch.acquire_task_exec_lease(
        "claude", "T", now=t0 + dt.timedelta(minutes=31), owner_pid=os.getpid()
    )
    assert stolen is True
    assert info["owner_pid"] == os.getpid()


def test_exec_lease_owner_tuple_persisted(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    acquired, lease = orch.acquire_task_exec_lease("claude", "T", owner_pid=os.getpid())
    assert acquired is True

    conn = orch.agent_router.connect(orch.FARM_ROOT)
    try:
        row = conn.execute(
            "SELECT owner_pid, owner_host, owner_token FROM spawn_leases WHERE task_key=?",
            ("agent_task_exec:T",),
        ).fetchone()
    finally:
        conn.close()
    assert row is not None
    assert int(row["owner_pid"]) == os.getpid()
    assert row["owner_host"]
    assert row["owner_token"]
    # Clean release removes the row (a slot exit frees its task immediately).
    orch.release_task_exec_lease(lease)
    conn = orch.agent_router.connect(orch.FARM_ROOT)
    try:
        gone = conn.execute(
            "SELECT 1 FROM spawn_leases WHERE task_key=?", ("agent_task_exec:T",)
        ).fetchone()
    finally:
        conn.close()
    assert gone is None


def test_exec_lease_key_is_distinct_from_router_lease():
    # The router's own lease (agent_task:<id>, NULL owner) must be untouched;
    # this fix uses a separate additive key.
    key = orch._task_exec_lease_key("abc123")
    assert key == "agent_task_exec:abc123"
    assert not key.startswith("agent_task:abc")


def test_pinned_prompt_names_single_task_only():
    pinned = orch.build_prompt("claude", REPO, "abc123")
    assert "abc123" in pinned
    assert "Work ONLY task `abc123`" in pinned
    assert "For every IN_PROGRESS task assigned to" not in pinned

    generic = orch.build_prompt("claude", REPO)
    assert "For every IN_PROGRESS task assigned to claude" in generic
    assert "Work ONLY task" not in generic


def test_assigned_task_id_is_exported_to_child_env():
    env = orch.agent_env("claude", "abc123")
    assert env["QM_ASSIGNED_TASK_ID"] == "abc123"
    # Absent for the task-agnostic single-session lanes.
    assert "QM_ASSIGNED_TASK_ID" not in orch.agent_env("codex")
