from __future__ import annotations

import datetime as dt
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import run_agent_orchestration_task as orchestration  # noqa: E402


def test_headless_prompt_reserves_main_integration_for_claude_owner() -> None:
    prompt = orchestration.build_prompt("codex", REPO)

    assert "committed on\n  agents/board-advisor only" in prompt
    assert "Main integration is performed exclusively\n  by Claude+OWNER close-outs" in prompt
    assert "C:/QM/worktrees/cto_main" in prompt
    assert "merged to the main branch" not in prompt


def test_headless_prompt_uses_canonical_control_plane_from_task_worktree() -> None:
    task_worktree = Path(r"C:\QM\worktrees\codex-orchestration-1")
    prompt = orchestration.build_prompt("codex", task_worktree)
    canonical_router = (
        orchestration.REPO_ROOT / "tools" / "strategy_farm" / "agent_router.py"
    ).as_posix()
    canonical_farmctl = (
        orchestration.REPO_ROOT / "tools" / "strategy_farm" / "farmctl.py"
    ).as_posix()

    assert f"python {canonical_router} status" in prompt
    assert f"python {canonical_router} list-tasks --agent codex --state IN_PROGRESS" in prompt
    assert f"python {canonical_router} update-task <task_id>" in prompt
    assert f"python {canonical_farmctl} health" in prompt
    assert "python tools/strategy_farm/agent_router.py status" not in prompt
    assert "`agent_router.py run`, `route-many`, `route-once`, or `replenish`" in prompt
    assert "--dedupe-no-change-task <task_id>" in prompt
    assert "make no no-change commit" in prompt


def test_two_headless_sessions_cannot_hold_the_same_agent_lease(tmp_path, monkeypatch) -> None:
    farm_root = tmp_path / "farm"
    monkeypatch.setattr(orchestration, "FARM_ROOT", farm_root)
    now = dt.datetime.now(dt.UTC)
    prepared = orchestration.agent_router.connect(farm_root)
    prepared.close()

    def acquire(token: str, pid: int):
        return orchestration.acquire_headless_session_lease(
            "claude", now=now, session_token=token, owner_pid=pid, owner_host="host-a"
        )

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda args: acquire(*args), [("session-a", 101), ("session-b", 202)]))

    assert sum(int(acquired) for acquired, _lease in results) == 1
    winner = next(lease for acquired, lease in results if acquired)
    loser = next(lease for acquired, lease in results if not acquired)
    assert loser["reason"] == "foreign_live_headless_session"
    assert loser["existing"]["owner_token"] == winner["session_token"]
    orchestration.release_headless_session_lease(winner)


def test_headless_skips_while_interactive_flag_is_fresh(tmp_path, monkeypatch) -> None:
    flag = tmp_path / "INTERACTIVE_ORCHESTRATOR.flag"
    now = dt.datetime.now(dt.UTC)
    flag.write_text(
        json.dumps({"pid": 4321, "host": "desk", "heartbeat_at": now.isoformat()}),
        encoding="utf-8",
    )
    monkeypatch.setattr(orchestration, "INTERACTIVE_ORCHESTRATOR_FLAG", flag)
    monkeypatch.setattr(orchestration, "LOG_DIR", tmp_path / "logs")
    monkeypatch.setattr(orchestration, "_write_lane_heartbeat", lambda *_a, **_k: None)

    def fail_if_lease_attempted(*_args, **_kwargs):
        raise AssertionError("interactive guard must run before headless lease acquisition")

    monkeypatch.setattr(orchestration, "acquire_headless_session_lease", fail_if_lease_attempted)
    result = orchestration.run_agent(
        "claude", dry_run=False, stale_minutes=250, timeout_minutes=225, max_sessions=1
    )

    assert result["skipped"] is True
    assert result["reason"] == "interactive_orchestrator_active"
    assert result["interactive_guard"]["reason"] == "interactive_flag_fresh"
    journal = tmp_path / "logs" / "headless_orchestration_skip_journal.jsonl"
    assert "interactive_orchestrator_active" in journal.read_text(encoding="utf-8")


def test_no_change_evidence_is_reserved_once_per_stable_state_hash(tmp_path) -> None:
    evidence_root = tmp_path / "evidence"
    artifact = evidence_root / "task_state.json"
    state = {"blocker": "NO_Q09_PASS", "rows": ["a", "b"]}

    first = orchestration.reserve_no_change_evidence(
        "claude",
        "task-1",
        state,
        artifact,
        marker_root=tmp_path / "markers",
        evidence_root=evidence_root,
    )
    second = orchestration.reserve_no_change_evidence(
        "claude",
        "task-1",
        {"rows": ["a", "b"], "blocker": "NO_Q09_PASS"},
        artifact,
        marker_root=tmp_path / "markers",
        evidence_root=evidence_root,
    )
    changed = orchestration.reserve_no_change_evidence(
        "claude",
        "task-1",
        {"blocker": "NO_Q09_PASS", "rows": ["a", "b", "c"]},
        artifact,
        marker_root=tmp_path / "markers",
        evidence_root=evidence_root,
    )

    assert first["write_allowed"] is True
    assert second["write_allowed"] is False
    assert second["state_sha256"] == first["state_sha256"]
    assert changed["write_allowed"] is True


def test_live_lock_owner_is_never_displaced_by_age(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(orchestration, "LOCK_DIR", tmp_path)
    acquired, first = orchestration.acquire_lock("codex", stale_minutes=1)
    assert acquired is True
    lock_path = Path(first["lock_path"])
    old = time.time() - 10_000
    os.utime(lock_path, (old, old))

    acquired_again, second = orchestration.acquire_lock("codex", stale_minutes=1)

    assert acquired_again is False
    assert second["reason"] == "previous_run_active"
    orchestration.release_lock(first)


def test_recent_dead_owner_lock_is_retained_until_stale_window(
    tmp_path, monkeypatch
) -> None:
    monkeypatch.setattr(orchestration, "LOCK_DIR", tmp_path)
    lock_path = tmp_path / "codex_orchestration.lock"
    lock_path.write_text(
        json.dumps({"pid": 2_000_000_000, "owner_token": "dead"}),
        encoding="utf-8",
    )

    acquired, result = orchestration.acquire_lock("codex", stale_minutes=250)

    assert acquired is False
    assert result["reason"] == "recent_lock_owner_not_live"
    assert lock_path.exists()


def test_stale_dead_lock_takeover_is_atomic_and_token_owned(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(orchestration, "LOCK_DIR", tmp_path)
    lock_path = tmp_path / "codex_orchestration.lock"
    lock_path.write_text(
        json.dumps({"pid": 2_000_000_000, "owner_token": "dead"}),
        encoding="utf-8",
    )
    old = time.time() - 120
    os.utime(lock_path, (old, old))

    acquired, lock_info = orchestration.acquire_lock("codex", stale_minutes=1)

    assert acquired is True
    payload = json.loads(lock_path.read_text(encoding="utf-8"))
    assert payload["owner_token"] == lock_info["owner_token"]
    orchestration.release_lock(lock_info)
    assert not lock_path.exists()


def test_old_owner_token_cannot_release_replacement_lock(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(orchestration, "LOCK_DIR", tmp_path)
    acquired, lock_info = orchestration.acquire_lock("codex", stale_minutes=1)
    assert acquired is True
    lock_path = Path(lock_info["lock_path"])
    payload = json.loads(lock_path.read_text(encoding="utf-8"))
    payload["owner_token"] = "replacement-owner"
    lock_path.write_text(json.dumps(payload), encoding="utf-8")

    orchestration.release_lock(lock_info)

    assert lock_path.exists()


def test_pythonw_excepthook_persists_uncaught_traceback(tmp_path, monkeypatch) -> None:
    crash_log = tmp_path / "orchestration_pythonw_crash.log"
    monkeypatch.setattr(orchestration, "PYTHONW_CRASH_LOG", crash_log)
    try:
        raise RuntimeError("orchestration-hook-probe")
    except RuntimeError:
        exc_type, exc, tb = sys.exc_info()
        assert exc_type is not None and exc is not None
        orchestration._pythonw_excepthook(exc_type, exc, tb)

    text = crash_log.read_text(encoding="utf-8")
    assert "uncaught top-level exception" in text
    assert "RuntimeError: orchestration-hook-probe" in text


def test_quota_gate_blocks_before_any_codex_slot_spawn(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(orchestration, "FARM_ROOT", tmp_path)
    monkeypatch.setattr(orchestration, "CLAUDE_DISABLED_FLAG", tmp_path / "claude.disabled")
    monkeypatch.setattr(orchestration, "_write_lane_heartbeat", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(
        orchestration,
        "_agent_tasks_work_available",
        lambda _agent: {"any_work": True},
    )
    monkeypatch.setattr(
        orchestration,
        "_quota_lane_check",
        lambda _agent: {"allowed": False, "reason": "all_candidate_tasks_quota_blocked"},
    )

    def fail_if_spawned(*_args, **_kwargs):
        raise AssertionError("run_agent_slot must not be called when quota gate denies")

    monkeypatch.setattr(orchestration, "run_agent_slot", fail_if_spawned)
    result = orchestration.run_agent(
        "codex",
        dry_run=False,
        stale_minutes=250,
        timeout_minutes=225,
        max_sessions=1,
    )
    assert result["skipped"] is True
    assert result["reason"] == "quota_gate_blocked"


def test_headless_model_contract_applies_selected_matrix_tier(monkeypatch, tmp_path) -> None:
    monkeypatch.setattr(orchestration, "resolve_cli", lambda agent: f"{agent}.cmd")
    monkeypatch.setattr(orchestration, "_CODEX_MODEL_ENV_OVERRIDE", "")
    monkeypatch.setattr(orchestration, "_CLAUDE_MODEL_ENV_OVERRIDE", "")
    selected = orchestration.quota_spawn_gate.invocation_profile(
        "codex",
        "ops_issue",
        {"acceptance": "change fail-closed quota gate decision-bound logic"},
    )

    codex = orchestration.command_for("codex", tmp_path, model_contract=selected)
    claude = orchestration.command_for("claude", tmp_path)

    assert 'model_reasoning_effort="max"' in codex
    assert codex[codex.index("-m") + 1] == "gpt-5.6-sol"
    assert claude[claude.index("--model") + 1] == "sonnet"
    assert orchestration.headless_model_contract("codex", selected)["reasoning_effort"] == "max"
