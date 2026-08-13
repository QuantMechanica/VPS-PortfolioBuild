from __future__ import annotations

import json
import os
import sys
import time
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
