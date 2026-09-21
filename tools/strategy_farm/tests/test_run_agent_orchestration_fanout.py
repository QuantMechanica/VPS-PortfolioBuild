"""Regression tests for the Claude/Codex pinned session fan-out.

OWNER-DEC-CBE-20260915 §35 / audit `claude_lane_fanout_defect.md`.

Before the fix, ``--max-sessions 3`` spawned three task-agnostic Claude sessions
that each worked every IN_PROGRESS task, so one ticket was worked N times. The
fix binds each spawned session to exactly one task via a pid-owned exec-lease
(``agent_task_exec:<id>``) acquired BEFORE the spawn, making --max-sessions an
upper bound on concurrently leased tasks rather than an N*M multiplier.

The Codex generalisation deliberately activates only for ``--max-sessions > 1``;
its historical single-session path remains task-agnostic.
"""

from __future__ import annotations

import datetime as dt
import os
import subprocess
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


def _prepare_git_repo(tmp_path, monkeypatch):
    repo = tmp_path / "repo"
    worktrees = tmp_path / "worktrees"
    repo.mkdir()

    def git(*args, cwd=repo):
        return subprocess.run(
            ["git", *args], cwd=cwd, check=True, capture_output=True, text=True
        )

    git("init")
    git("config", "user.email", "fanout-tests@example.invalid")
    git("config", "user.name", "Fanout Tests")
    (repo / "seed.txt").write_text("one\n", encoding="utf-8")
    git("add", "seed.txt")
    git("commit", "-m", "seed")
    monkeypatch.setattr(orch, "REPO_ROOT", repo)
    monkeypatch.setattr(orch, "WORKTREE_ROOT", worktrees)
    return repo, worktrees, git


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


def _stub_codex_gates(monkeypatch, allowed_task_count=3, slot_ids=None):
    """Enable Codex without touching real quota state or worktrees."""
    slots = list(slot_ids or range(1, allowed_task_count + 1))
    monkeypatch.setattr(orch, "_write_lane_heartbeat", lambda *_a, **_k: None)
    monkeypatch.setattr(orch, "_agent_tasks_work_available", lambda _a: {"any_work": True})
    monkeypatch.setattr(
        orch,
        "_quota_lane_check",
        lambda _agent: {
            "allowed": True,
            "allowed_task_count": allowed_task_count,
            "allowed_invocations": [],
        },
    )

    def fake_prepare(agent, requested, *, create):
        selected = slots[:requested]
        return {
            "ok": len(selected) == requested,
            "reason": "safe_slots_ready",
            "requested": requested,
            "slot_ids": selected,
            "accepted": [{"slot": slot, "ok": True} for slot in selected],
            "rejected": [],
            "create": create,
        }

    monkeypatch.setattr(orch, "prepare_pinned_worktree_slots", fake_prepare)


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
            "state": "IN_PROGRESS",
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


def test_max_sessions_bounds_concurrent_sessions_and_drains_disjoint(tmp_path, monkeypatch):
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

    # 5 tasks, cap 3: at most 3 CONCURRENT sessions (max_sessions reports the
    # seeded concurrency), and each session drains the remaining tasks so the
    # whole assigned backlog is worked in one cycle (M2). Every task is worked
    # exactly once - never two sessions on one task.
    assert result["max_sessions"] == 3
    ids = [c["assigned_task_id"] for c in calls]
    assert sorted(ids) == ["A", "B", "C", "D", "E"]  # drained, disjoint
    assert len(set(ids)) == len(ids)  # no task worked twice
    assert set(result["leased_task_ids"]) == {"A", "B", "C", "D", "E"}
    assert result["tasks_worked"] == 5
    for c in calls:
        assert c["assigned_task_id"] == c["exec_lease_task"]


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

    # After the TTL it is reclaimed only after the recorded local PID is proven
    # dead. This avoids duplicating a slow but still-live worker whose renewal
    # was delayed.
    monkeypatch.setattr(orch, "_exec_lease_owner_alive", lambda *_a: False)
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


def test_candidate_query_failure_fails_closed_no_unpinned_spawn(tmp_path, monkeypatch):
    """Review c1 M1: a db_missing/db_error candidate query must spawn nothing.

    The pre-fix code left session_count unclamped on this branch, so once
    --max-sessions was raised above 1 a transient DB error re-opened the
    unpinned N*M fan-out. It must now fail closed with a logged reason.
    """
    _prepare_farm(tmp_path, monkeypatch)
    _stub_claude_gates(monkeypatch, max_sessions=3)
    monkeypatch.setattr(
        orch, "_quota_lane_candidates", lambda _a: ([], "db_error:boom")
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "claude", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=3, session_lease=None,
    )

    assert result["skipped"] is True
    assert result["reason"] == "claude_candidate_query_unavailable"
    assert result["candidate_status"] == "db_error:boom"
    assert calls == []  # nothing unpinned spawned


def test_single_session_drains_multiple_tasks_sequentially(tmp_path, monkeypatch):
    """Review c1 M2: --max-sessions 1 must not degrade to one task per cycle.

    One session leases the next eligible task after finishing the current one and
    drains the assigned backlog sequentially, each task leased exactly once.
    """
    _prepare_farm(tmp_path, monkeypatch)
    _stub_claude_gates(monkeypatch, max_sessions=1)
    monkeypatch.setattr(
        orch, "_quota_lane_candidates", lambda _a: (_candidates("T1", "T2", "T3"), "ok")
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "claude", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=1, session_lease=None,
    )

    assert result["ok"] is True
    assert result["max_sessions"] == 1  # a single concurrent session
    assert result["tasks_worked"] == 3
    ids = [c["assigned_task_id"] for c in calls]
    assert sorted(ids) == ["T1", "T2", "T3"]  # all drained
    assert len(set(ids)) == 3  # never the same task twice
    # Every slot is slot 1 (the single session) and its pin matches its lease.
    for c in calls:
        assert c["slot"] == 1
        assert c["assigned_task_id"] == c["exec_lease_task"]


def test_max_tasks_per_session_caps_the_drain(tmp_path, monkeypatch):
    """Review c1 M2: the per-session drain honours max_tasks_per_session."""
    _prepare_farm(tmp_path, monkeypatch)
    _stub_claude_gates(monkeypatch, max_sessions=1)
    monkeypatch.setattr(orch, "_claude_max_tasks_per_session", lambda: 2)
    monkeypatch.setattr(
        orch,
        "_quota_lane_candidates",
        lambda _a: (_candidates("T1", "T2", "T3", "T4", "T5"), "ok"),
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "claude", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=1, session_lease=None,
    )

    # One session, cap 2 tasks: only two tasks are worked this cycle.
    assert result["tasks_worked"] == 2
    assert len(calls) == 2
    assert len(set(c["assigned_task_id"] for c in calls)) == 2


def test_chaining_never_double_works_a_task_under_concurrency(tmp_path, monkeypatch):
    """Review c1 M2: with several concurrent sessions no task is worked twice."""
    _prepare_farm(tmp_path, monkeypatch)
    _stub_claude_gates(monkeypatch, max_sessions=3)
    task_ids = [f"K{i}" for i in range(9)]
    monkeypatch.setattr(
        orch, "_quota_lane_candidates", lambda _a: (_candidates(*task_ids), "ok")
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "claude", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=3, session_lease=None,
    )

    worked = [c["assigned_task_id"] for c in calls]
    assert sorted(worked) == sorted(task_ids)  # all drained
    assert len(set(worked)) == len(worked)  # each exactly once
    assert sorted(result["leased_task_ids"]) == sorted(task_ids)
    assert result["max_sessions"] == 3


def test_codex_three_slots_claim_three_distinct_tasks_before_spawn(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    _stub_codex_gates(monkeypatch, allowed_task_count=3, slot_ids=[2, 3, 4])
    monkeypatch.setattr(
        orch, "_quota_lane_candidates", lambda _a: (_candidates("C1", "C2", "C3"), "ok")
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "codex", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=3, session_lease=None,
    )

    assert result["ok"] is True
    assert result["max_sessions"] == 3
    assert result["slots"] == [2, 3, 4]
    assert len(calls) == 3
    assert {call["assigned_task_id"] for call in calls} == {"C1", "C2", "C3"}
    assert len({call["slot"] for call in calls}) == 3
    for call in calls:
        assert call["assigned_task_id"] == call["exec_lease_task"]


def test_codex_fanout_never_pins_assigned_todo_row(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    _stub_codex_gates(monkeypatch, allowed_task_count=2)
    candidates = _candidates("IN_PROGRESS_TASK", "TODO_TASK")
    candidates[1]["state"] = "TODO"
    monkeypatch.setattr(orch, "_quota_lane_candidates", lambda _a: (candidates, "ok"))
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "codex", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=2, session_lease=None,
    )

    assert result["leased_task_ids"] == ["IN_PROGRESS_TASK"]
    assert [call["assigned_task_id"] for call in calls] == ["IN_PROGRESS_TASK"]


def test_codex_contention_never_double_leases_task(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    acquired, foreign = orch.acquire_task_exec_lease(
        "codex", "C1", owner_pid=os.getpid(), session_token="foreign-live"
    )
    assert acquired is True
    _stub_codex_gates(monkeypatch, allowed_task_count=3)
    monkeypatch.setattr(
        orch, "_quota_lane_candidates", lambda _a: (_candidates("C1"), "ok")
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "codex", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=3, session_lease=None,
    )

    assert result["skipped"] is True
    assert result["reason"] == "no_unpinned_codex_task"
    assert calls == []
    orch.release_task_exec_lease(foreign)


def test_codex_sessions_chain_to_next_distinct_tasks(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    _stub_codex_gates(monkeypatch, allowed_task_count=5, slot_ids=[1, 2])
    monkeypatch.setattr(orch, "_pinned_max_tasks_per_session", lambda _a: 4)
    monkeypatch.setattr(
        orch,
        "_quota_lane_candidates",
        lambda _a: (_candidates("C1", "C2", "C3", "C4", "C5"), "ok"),
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "codex", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=2, session_lease=None,
    )

    worked = [call["assigned_task_id"] for call in calls]
    assert result["max_sessions"] == 2
    assert result["tasks_worked"] == 5
    assert sorted(worked) == ["C1", "C2", "C3", "C4", "C5"]
    assert len(set(worked)) == len(worked)


def test_codex_single_session_keeps_legacy_task_agnostic_path(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    _stub_codex_gates(monkeypatch, allowed_task_count=3)
    monkeypatch.setattr(
        orch,
        "prepare_pinned_worktree_slots",
        lambda *_a, **_k: (_ for _ in ()).throw(AssertionError("pinned worktree path used")),
    )
    monkeypatch.setattr(
        orch,
        "_quota_lane_candidates",
        lambda *_a: (_ for _ in ()).throw(AssertionError("candidate query used")),
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "codex", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=1, session_lease=None,
    )

    assert result["ok"] is True
    assert result["max_sessions"] == 1
    assert result["leased_task_ids"] == []
    assert calls == [
        {
            "agent": "codex",
            "slot": 1,
            "assigned_task_id": None,
            "exec_lease_task": None,
        }
    ]


def test_codex_candidate_query_failure_fails_closed(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    _stub_codex_gates(monkeypatch, allowed_task_count=3)
    monkeypatch.setattr(
        orch, "_quota_lane_candidates", lambda _a: ([], "db_error:visibility_lost")
    )
    monkeypatch.setattr(
        orch,
        "prepare_pinned_worktree_slots",
        lambda *_a, **_k: (_ for _ in ()).throw(AssertionError("worktree prepared")),
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "codex", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=3, session_lease=None,
    )

    assert result["skipped"] is True
    assert result["reason"] == "codex_candidate_query_unavailable"
    assert result["candidate_status"] == "db_error:visibility_lost"
    assert calls == []


def test_codex_quota_candidate_query_failure_cannot_fail_open(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    _stub_codex_gates(monkeypatch, allowed_task_count=1)
    monkeypatch.setattr(
        orch,
        "_quota_lane_check",
        lambda _agent: {
            "allowed": True,
            "reason": "lane_db_unavailable_ops_continuity",
            "candidate_status": "db_error:transient",
            "allowed_task_count": 1,
            "allowed_invocations": [],
        },
    )
    monkeypatch.setattr(
        orch,
        "_quota_lane_candidates",
        lambda *_a: (_ for _ in ()).throw(AssertionError("candidate query retried")),
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "codex", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=3, session_lease=None,
    )

    assert result["skipped"] is True
    assert result["reason"] == "codex_candidate_query_unavailable"
    assert result["candidate_status"] == "db_error:transient"
    assert calls == []


def test_codex_allowed_task_count_bounds_concurrent_sessions(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    _stub_codex_gates(monkeypatch, allowed_task_count=2, slot_ids=[4, 5, 6])
    monkeypatch.setattr(
        orch, "_quota_lane_candidates", lambda _a: (_candidates("C1", "C2", "C3"), "ok")
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "codex", dry_run=False, stale_minutes=250, timeout_minutes=225,
        max_sessions=3, session_lease=None,
    )

    assert result["max_sessions"] == 2
    assert result["slots"] == [4, 5]
    assert {call["assigned_task_id"] for call in calls} == {"C1", "C2", "C3"}


def test_codex_fanout_dry_run_is_read_only_plan(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    prepared: list[tuple[str, int, bool]] = []
    monkeypatch.setattr(orch, "_write_lane_heartbeat", lambda *_a, **_k: None)
    monkeypatch.setattr(
        orch, "_quota_lane_candidates", lambda _a: (_candidates("C1", "C2", "C3"), "ok")
    )

    def fake_prepare(agent, requested, *, create):
        prepared.append((agent, requested, create))
        return {"ok": True, "slot_ids": [2, 3, 4], "accepted": [], "rejected": []}

    monkeypatch.setattr(orch, "prepare_pinned_worktree_slots", fake_prepare)
    monkeypatch.setattr(
        orch,
        "acquire_task_exec_lease",
        lambda *_a, **_k: (_ for _ in ()).throw(AssertionError("lease acquired")),
    )
    calls = _record_slots(monkeypatch)

    result = orch._run_agent_with_session_lease(
        "codex", dry_run=True, stale_minutes=250, timeout_minutes=225,
        max_sessions=3, session_lease=None,
    )

    assert result["dry_run_verified"] is True
    assert result["planned_task_ids"] == ["C1", "C2", "C3"]
    assert result["planned_slots"] == [2, 3, 4]
    assert prepared == [("codex", 3, False)]
    assert calls == []


def test_expired_exec_lease_is_not_reclaimed_while_owner_pid_lives(tmp_path, monkeypatch):
    _prepare_farm(tmp_path, monkeypatch)
    t0 = dt.datetime(2026, 9, 15, 12, 0, tzinfo=dt.UTC)
    acquired, live = orch.acquire_task_exec_lease(
        "codex", "C1", now=t0, owner_pid=os.getpid(), session_token="live-owner"
    )
    assert acquired is True
    monkeypatch.setattr(orch, "_exec_lease_owner_alive", lambda *_a: True)

    reacquired, info = orch.acquire_task_exec_lease(
        "codex", "C1", now=t0 + dt.timedelta(minutes=31), owner_pid=999_999
    )

    assert reacquired is False
    assert info["reason"] == "task_exec_lease_expired_owner_pid_alive"
    orch.release_task_exec_lease(live)


def test_codex_pinned_prompt_and_env_name_only_assigned_task():
    pinned = orch.build_prompt("codex", REPO, "codex-task-1")
    assert "Work ONLY task `codex-task-1`" in pinned
    assert "For every IN_PROGRESS task assigned to codex" not in pinned
    assert orch.agent_env("codex", "codex-task-1")["QM_ASSIGNED_TASK_ID"] == "codex-task-1"


def test_codex_pinned_worktree_is_created_at_exact_canonical_head(tmp_path, monkeypatch):
    repo, worktrees, git = _prepare_git_repo(tmp_path, monkeypatch)
    required_head = git("rev-parse", "HEAD").stdout.strip()

    plan = orch.prepare_pinned_worktree_slots("codex", 1, create=True)

    slot_path = worktrees / "codex-orchestration-1"
    slot_head = git("rev-parse", "HEAD", cwd=slot_path).stdout.strip()
    assert plan["ok"] is True
    assert plan["slot_ids"] == [1]
    assert slot_head == required_head
    assert plan["accepted"][0]["branch"] == "agents/codex-orchestration-1"


def test_codex_pinned_worktree_skips_dirty_slot_without_reset(tmp_path, monkeypatch):
    _repo, worktrees, _git = _prepare_git_repo(tmp_path, monkeypatch)
    created = orch.prepare_pinned_worktree_slots("codex", 1, create=True)
    assert created["slot_ids"] == [1]
    dirty_path = worktrees / "codex-orchestration-1" / "seed.txt"
    dirty_path.write_text("operator work\n", encoding="utf-8")

    plan = orch.prepare_pinned_worktree_slots("codex", 1, create=False)

    assert plan["ok"] is True
    assert plan["slot_ids"] == [2]
    assert plan["rejected"][0]["slot"] == 1
    assert plan["rejected"][0]["reason"] == "worktree_dirty_refuse_update"
    assert dirty_path.read_text(encoding="utf-8") == "operator work\n"


def test_gemini_and_kimi_remain_single_session(monkeypatch):
    monkeypatch.setattr(orch, "_write_lane_heartbeat", lambda *_a, **_k: None)
    monkeypatch.setattr(orch, "_agent_tasks_work_available", lambda _a: {"any_work": True})
    calls = _record_slots(monkeypatch)

    for agent in ("gemini", "kimi"):
        result = orch._run_agent_with_session_lease(
            agent, dry_run=False, stale_minutes=250, timeout_minutes=225,
            max_sessions=3, session_lease=None,
        )
        assert result["max_sessions"] == 1

    assert [(call["agent"], call["slot"]) for call in calls] == [
        ("gemini", 1),
        ("kimi", 1),
    ]
