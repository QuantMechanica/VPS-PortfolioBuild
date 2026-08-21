from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import run_agent_orchestration_task as orchestration  # noqa: E402


router = orchestration.agent_router


def _enqueue_video_task(root: Path) -> str:
    router.sync_default_registry(
        root,
        claude_disabled_flag=root / "missing-claude-disabled.flag",
    )
    return str(
        router.enqueue_task(
            root,
            "research_strategy",
            priority=99,
            required_skills=["video_analysis"],
        )["task_id"]
    )


@pytest.mark.parametrize(
    ("selection_path", "lane"),
    [
        ("router", None),
        ("quota_lane", "gemini"),
        ("quota_lane", "codex"),
        ("quota_lane", "claude"),
        ("agent_wake", "gemini"),
        ("agent_wake", "codex"),
        ("claude_wake", "claude"),
    ],
)
def test_human_owned_skill_is_never_offered_to_an_ai_selection_path(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    selection_path: str,
    lane: str | None,
) -> None:
    """System invariant for every capability-aware work-selection path."""
    root = tmp_path / "farm"
    task_id = _enqueue_video_task(root)
    monkeypatch.setattr(orchestration, "FARM_ROOT", root)

    if selection_path == "router":
        decision = router.route_once(
            root,
            claude_disabled_flag=root / "missing-claude-disabled.flag",
        )
        assert decision.task_id == task_id
        assert decision.assigned_agent is None
        assert decision.reason == "awaiting_human_lane:owner"
        return

    if selection_path == "claude_wake":
        availability = orchestration.claude_work_available()
        assert availability["candidate_status"] == "ok"
        assert availability["any_work"] is False
        return

    if selection_path == "agent_wake":
        assert lane is not None
        availability = orchestration._agent_tasks_work_available(lane)
        assert availability["candidate_status"] == "ok"
        assert availability["any_work"] is False
        return

    assert lane is not None
    candidates, status = orchestration._quota_lane_candidates(lane)
    assert status == "ok"
    assert task_id not in {candidate["task_id"] for candidate in candidates}


@pytest.mark.parametrize("lane", ["gemini", "codex", "claude"])
def test_stale_ai_assignment_cannot_bypass_human_skill_gate(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    lane: str,
) -> None:
    root = tmp_path / "farm"
    task_id = _enqueue_video_task(root)
    monkeypatch.setattr(orchestration, "FARM_ROOT", root)
    with router.connect(root) as conn:
        conn.execute(
            "UPDATE agent_tasks SET state='IN_PROGRESS', assigned_agent=? WHERE id=?",
            (lane, task_id),
        )
        conn.commit()

    candidates, status = orchestration._quota_lane_candidates(lane)

    assert status == "ok"
    assert task_id not in {candidate["task_id"] for candidate in candidates}


def test_undeclared_skill_label_remains_descriptive_metadata(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    root = tmp_path / "farm"
    router.sync_default_registry(
        root,
        claude_disabled_flag=root / "missing-claude-disabled.flag",
    )
    task_id = str(
        router.enqueue_task(
            root,
            "ops_issue",
            priority=80,
            required_capabilities=["code", "ops"],
            required_skills=["descriptive-skill-not-in-any-lane"],
        )["task_id"]
    )
    monkeypatch.setattr(orchestration, "FARM_ROOT", root)

    candidates, status = orchestration._quota_lane_candidates("codex")
    selected = next(candidate for candidate in candidates if candidate["task_id"] == task_id)

    assert status == "ok"
    assert selected["required_capabilities"] == ["code", "ops"]


def test_owner_budget_class_alone_does_not_wake_claude(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    root = tmp_path / "farm"
    router.sync_default_registry(
        root,
        claude_disabled_flag=root / "missing-claude-disabled.flag",
    )
    router.enqueue_task(
        root,
        "ops_issue",
        priority=80,
        required_capabilities=["code", "ops"],
        budget_class="owner",
    )
    monkeypatch.setattr(orchestration, "FARM_ROOT", root)

    availability = orchestration.claude_work_available()

    assert availability == {
        "any_work": False,
        "claude_assigned": 0,
        "premium_backlog": 0,
        "candidate_status": "ok",
    }


def test_compatible_premium_task_still_wakes_claude(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    root = tmp_path / "farm"
    router.sync_default_registry(
        root,
        claude_disabled_flag=root / "missing-claude-disabled.flag",
    )
    router.enqueue_task(
        root,
        "ops_issue",
        priority=80,
        required_capabilities=["code", "ops"],
        budget_class="premium",
    )
    monkeypatch.setattr(orchestration, "FARM_ROOT", root)

    availability = orchestration.claude_work_available()

    assert availability["any_work"] is True
    assert availability["premium_backlog"] == 1


def test_effective_skill_contract_uses_governed_defaults_during_live_drift(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    root = tmp_path / "farm"
    task_id = _enqueue_video_task(root)
    monkeypatch.setattr(orchestration, "FARM_ROOT", root)
    with router.connect(root) as conn:
        owner = conn.execute(
            "SELECT capabilities_json FROM agent_registry WHERE agent_id='owner'"
        ).fetchone()
        capabilities = set(json.loads(owner["capabilities_json"] or "[]"))
        capabilities.discard("video_analysis")
        conn.execute(
            "UPDATE agent_registry SET capabilities_json=? WHERE agent_id='owner'",
            (json.dumps(sorted(capabilities)),),
        )
        conn.commit()

    for lane in ("gemini", "codex", "claude"):
        candidates, status = orchestration._quota_lane_candidates(lane)
        assert status == "ok"
        assert task_id not in {candidate["task_id"] for candidate in candidates}
