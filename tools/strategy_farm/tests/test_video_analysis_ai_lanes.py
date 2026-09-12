"""Captions-first video lane (OWNER 2026-09-09), default OFF.

Three contracts are pinned here:

1. LANE MAPPING — with the switch OFF nothing changes (`awaiting_human_lane:owner`);
   with it ON `video_analysis` is servable by codex and claude and NEVER by
   gemini/agy, which hallucinates and would become the default seat at cost_rank 10.
2. DISPATCH PROMPT — a routed video row carries the captions-first execution
   contract in the payload the seat actually reads: fetch_transcript per URL, a
   docs/research VIDEO_*.md evidence file with caption timestamps, a numbered
   OWNER frame list for on-screen-only questions, and an explicit no-guessing rule.
3. RELEASE HELPER — dry-run by default, batched, append-only, fail-closed while
   the switch is OFF.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import agent_router as router  # noqa: E402
import farmctl  # noqa: E402
import release_video_analysis_holds as release  # noqa: E402
import run_agent_orchestration_task as orchestration  # noqa: E402


VIDEO_URL = "https://www.youtube.com/watch?v=Pay-JP34YSI"
SECOND_URL = "https://youtu.be/mOa4dqxAh4g"


@pytest.fixture
def farm_root(tmp_path: Path) -> Path:
    return tmp_path / "farm"


def _arm(monkeypatch: pytest.MonkeyPatch, enabled: bool) -> None:
    monkeypatch.setenv(router.VIDEO_ANALYSIS_AI_LANES_ENV, "1" if enabled else "0")


def _sync(root: Path) -> None:
    router.sync_default_registry(root, claude_disabled_flag=root / "missing.flag")


def _enqueue_video_task(root: Path, *, state: str = "TODO") -> str:
    _sync(root)
    return str(
        router.enqueue_task(
            root,
            "research_strategy",
            state=state,
            priority=99,
            required_skills=["video_analysis"],
            payload={
                "title": "OWNER-VID-TEST",
                "videos": [VIDEO_URL, SECOND_URL],
            },
        )["task_id"]
    )


def _route(root: Path) -> router.RouteDecision:
    return router.route_once(root, claude_disabled_flag=root / "missing.flag")


def _registry_capabilities(root: Path, agent_id: str) -> set[str]:
    with router.connect(root) as conn:
        row = conn.execute(
            "SELECT capabilities_json FROM agent_registry WHERE agent_id=?", (agent_id,)
        ).fetchone()
    return set(json.loads(row["capabilities_json"] or "[]"))


# --------------------------------------------------------------------------
# 1. lane mapping
# --------------------------------------------------------------------------


def test_switch_defaults_to_off_without_env_or_flag(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv(router.VIDEO_ANALYSIS_AI_LANES_ENV, raising=False)
    (farm_root / "state").mkdir(parents=True, exist_ok=True)
    assert router.video_analysis_ai_lanes_enabled(farm_root) is False
    assert router.video_analysis_switch_state(farm_root)["enabled"] is False


def test_flag_file_arms_the_lane_without_an_env_var(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv(router.VIDEO_ANALYSIS_AI_LANES_ENV, raising=False)
    (farm_root / "state").mkdir(parents=True, exist_ok=True)
    (farm_root / "state" / router.VIDEO_ANALYSIS_AI_LANES_FLAG).write_text("armed", encoding="utf-8")
    assert router.video_analysis_ai_lanes_enabled(farm_root) is True


def test_env_off_overrides_a_present_flag_file(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    (farm_root / "state").mkdir(parents=True, exist_ok=True)
    (farm_root / "state" / router.VIDEO_ANALYSIS_AI_LANES_FLAG).write_text("armed", encoding="utf-8")
    _arm(monkeypatch, False)
    assert router.video_analysis_ai_lanes_enabled(farm_root) is False


def test_switch_off_keeps_the_owner_hold(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, False)
    task_id = _enqueue_video_task(farm_root)
    decision = _route(farm_root)
    assert (decision.task_id, decision.assigned_agent) == (task_id, None)
    assert decision.reason == "awaiting_human_lane:owner"
    assert router.VIDEO_ANALYSIS_CAPABILITY not in _registry_capabilities(farm_root, "codex")


def test_switch_on_routes_video_work_to_an_ai_lane(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, True)
    task_id = _enqueue_video_task(farm_root)
    decision = _route(farm_root)
    assert decision.task_id == task_id
    assert decision.reason == "assigned"
    assert decision.assigned_agent in router.VIDEO_ANALYSIS_AI_LANES


def test_gemini_never_declares_video_analysis_in_either_switch_state(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    for enabled in (False, True):
        _arm(monkeypatch, enabled)
        _sync(farm_root)
        assert router.VIDEO_ANALYSIS_CAPABILITY not in _registry_capabilities(farm_root, "gemini")
    assert "gemini" not in router.VIDEO_ANALYSIS_AI_LANES
    assert router.effective_lane_capabilities(
        "gemini", ["research", "strategy"], ai_video_lanes=True
    ) == ["research", "strategy"]


def test_owner_lane_capabilities_are_untouched_by_the_switch(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, True)
    _sync(farm_root)
    assert router.VIDEO_ANALYSIS_CAPABILITY in _registry_capabilities(farm_root, "owner")


@pytest.mark.parametrize("lane", ["codex", "claude"])
def test_second_selection_path_agrees_with_the_router(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch, lane: str
) -> None:
    """`_quota_lane_candidates` must not re-hold what the router now routes."""
    _arm(monkeypatch, True)
    task_id = _enqueue_video_task(farm_root)
    monkeypatch.setattr(orchestration, "FARM_ROOT", farm_root)
    candidates, status = orchestration._quota_lane_candidates(lane)
    assert status == "ok"
    assert task_id in {candidate["task_id"] for candidate in candidates}


def test_second_selection_path_still_hides_video_work_while_off(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, False)
    task_id = _enqueue_video_task(farm_root)
    monkeypatch.setattr(orchestration, "FARM_ROOT", farm_root)
    for lane in ("codex", "claude", "gemini"):
        candidates, status = orchestration._quota_lane_candidates(lane)
        assert status == "ok"
        assert task_id not in {candidate["task_id"] for candidate in candidates}


def test_gemini_is_never_offered_video_work_even_when_armed(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, True)
    task_id = _enqueue_video_task(farm_root)
    monkeypatch.setattr(orchestration, "FARM_ROOT", farm_root)
    candidates, status = orchestration._quota_lane_candidates("gemini")
    assert status == "ok"
    assert task_id not in {candidate["task_id"] for candidate in candidates}


# --------------------------------------------------------------------------
# 2. dispatch-prompt contract
# --------------------------------------------------------------------------


def test_extract_video_references_finds_list_and_prose_urls() -> None:
    references = router.extract_video_references(
        {
            "videos": [VIDEO_URL, SECOND_URL],
            "note": f"see also {VIDEO_URL} and https://www.youtube.com/shorts/AbCdEf12345",
        }
    )
    ids = [item["video_id"] for item in references]
    assert ids == ["Pay-JP34YSI", "mOa4dqxAh4g", "AbCdEf12345"]


def test_dispatch_contract_states_the_captions_first_rules() -> None:
    contract = router.video_analysis_dispatch_contract(
        {"videos": [VIDEO_URL]}, task_id="t1", agent="codex"
    )
    text = contract["instructions"]
    assert contract["schema"] == "qm.video_analysis_dispatch_contract.v1"
    # (a) transcript first, per URL
    assert contract["transcript_commands"] == [
        "python tools/strategy_farm/fetch_transcript.py Pay-JP34YSI"
    ]
    assert router.VIDEO_ANALYSIS_TRANSCRIPT_TOOL in text
    # (b) evidence file in the worked-example style
    assert contract["evidence_dir"] == "docs/research"
    assert "VIDEO_<video_id>" in contract["evidence_path_pattern"]
    assert contract["worked_example"].startswith("docs/research/VIDEO_")
    assert "[hh:mm:ss]" in text
    # (c) numbered OWNER frame list on the vault page
    assert contract["owner_frame_list_surface"] == "12 ToDo/AI ToDos/OWNER Videoanalysen.md"
    assert "NUMBERED frame list" in text
    # (d) never guess
    assert "NEVER fill a visual gap by guessing" in text
    assert any("never guess" in rule for rule in contract["prohibitions"])


def test_dispatch_contract_without_urls_refuses_to_substitute() -> None:
    contract = router.video_analysis_dispatch_contract({"title": "no url here"})
    assert contract["videos"] == []
    assert "do NOT search for a substitute" in contract["instructions"]


def test_routed_video_task_carries_the_contract_in_its_payload(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, True)
    task_id = _enqueue_video_task(farm_root)
    decision = _route(farm_root)
    assert decision.assigned_agent in router.VIDEO_ANALYSIS_AI_LANES
    with router.connect(farm_root) as conn:
        row = conn.execute("SELECT payload_json FROM agent_tasks WHERE id=?", (task_id,)).fetchone()
    contract = json.loads(row["payload_json"])["video_analysis_contract"]
    assert [item["video_id"] for item in contract["videos"]] == ["Pay-JP34YSI", "mOa4dqxAh4g"]
    assert contract["agent"] == decision.assigned_agent
    assert contract["switch"]["enabled"] is True
    assert "captions-first" in contract["instructions"].lower()


def test_non_video_task_gets_no_video_contract(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, True)
    _sync(farm_root)
    task_id = str(
        router.enqueue_task(
            farm_root,
            "ops_issue",
            priority=80,
            required_capabilities=["code", "ops"],
        )["task_id"]
    )
    decision = _route(farm_root)
    assert decision.task_id == task_id
    with router.connect(farm_root) as conn:
        row = conn.execute("SELECT payload_json FROM agent_tasks WHERE id=?", (task_id,)).fetchone()
    assert "video_analysis_contract" not in json.loads(row["payload_json"])


def test_video_contract_cli_renders_read_only(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, False)
    task_id = _enqueue_video_task(farm_root)
    rendered = router.render_task_video_contract(farm_root, task_id)
    assert rendered["rendered"] is True
    assert rendered["contract"]["switch"]["enabled"] is False
    with router.connect(farm_root) as conn:
        state = conn.execute("SELECT state FROM agent_tasks WHERE id=?", (task_id,)).fetchone()[0]
    assert state == "TODO"
    assert router.render_task_video_contract(farm_root, "missing")["reason"] == "task_not_found"


def test_task_requires_video_analysis_reads_every_channel() -> None:
    assert router.task_requires_video_analysis({"video_analysis"})
    assert router.task_requires_video_analysis(set(), skills=["video_analysis"])
    assert router.task_requires_video_analysis(
        set(), payload={"required_capabilities": ["video_analysis"]}
    )
    assert router.task_requires_video_analysis(
        set(),
        payload={"router_human_lane_hold": {"lane": "owner", "required": ["video_analysis"]}},
    )
    assert not router.task_requires_video_analysis({"research"}, payload={"title": "x"})


# --------------------------------------------------------------------------
# 3. release helper
# --------------------------------------------------------------------------


def _blocked_held_task(root: Path, *, index: int = 0) -> str:
    _sync(root)
    task_id = str(
        router.enqueue_task(
            root,
            "research_strategy",
            state="BLOCKED",
            priority=70 + index,
            required_skills=["video_analysis"],
            payload={
                "title": f"OWNER-VID-HELD-{index}",
                "videos": [VIDEO_URL],
                "router_human_lane_hold": {
                    "code": "ROUTER_AWAITING_HUMAN_LANE",
                    "lane": "owner",
                    "required": ["research", "strategy", "video_analysis"],
                },
            },
        )["task_id"]
    )
    return task_id


def _state_and_payload(root: Path, task_id: str) -> tuple[str, dict]:
    with router.connect(root) as conn:
        row = conn.execute(
            "SELECT state, payload_json FROM agent_tasks WHERE id=?", (task_id,)
        ).fetchone()
    return str(row["state"]), json.loads(row["payload_json"] or "{}")


def test_release_is_dry_run_by_default(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, True)
    task_id = _blocked_held_task(farm_root)
    result = release.release_holds(farm_root)
    assert result["apply"] is False
    assert result["reason"] == "dry_run"
    assert result["released"] == 0
    assert [candidate["task_id"] for candidate in result["candidates"]] == [task_id]
    assert result["candidates"][0]["videos"] == ["Pay-JP34YSI"]
    state, payload = _state_and_payload(farm_root, task_id)
    assert state == "BLOCKED"
    assert "router_human_lane_hold" in payload


def test_release_refuses_to_apply_while_the_switch_is_off(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, False)
    task_id = _blocked_held_task(farm_root)
    result = release.release_holds(farm_root, apply=True)
    assert result["refused"] is True
    assert result["reason"] == "video_analysis_ai_lanes_disabled"
    assert _state_and_payload(farm_root, task_id)[0] == "BLOCKED"


def test_release_applies_clears_the_marker_and_journals_append_only(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, True)
    # Full farm schema, so the shared `events` stream is really asserted here
    # (a bare router fixture root has agent_tasks but no events table).
    farmctl.init_db(farm_root)
    task_id = _blocked_held_task(farm_root)
    result = release.release_holds(farm_root, apply=True)
    assert result["released"] == 1
    assert result["released_task_ids"] == [task_id]
    assert "events_journal_degraded" not in result

    state, payload = _state_and_payload(farm_root, task_id)
    assert state == "TODO"
    assert "router_human_lane_hold" not in payload
    assert payload["router_routing_reason"] == release.RELEASE_ROUTING_REASON
    journal = payload["video_analysis_release_journal"]
    assert len(journal) == 1
    # append-only: the cleared hold is preserved inside the journal entry
    assert journal[0]["previous_hold"]["lane"] == "owner"
    assert journal[0]["from_state"] == "BLOCKED"
    assert payload["video_analysis_contract"]["videos"][0]["video_id"] == "Pay-JP34YSI"

    with router.connect(farm_root) as conn:
        events = conn.execute(
            "SELECT event FROM events WHERE entity_type='agent_task' AND entity_id=?",
            (task_id,),
        ).fetchall()
    assert release.RELEASE_EVENT in {str(row["event"]) for row in events}


def test_release_batches_with_limit(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, True)
    ids = [_blocked_held_task(farm_root, index=i) for i in range(3)]
    result = release.release_holds(farm_root, apply=True, limit=2)
    assert result["released"] == 2
    states = [_state_and_payload(farm_root, task_id)[0] for task_id in ids]
    assert sorted(states) == ["BLOCKED", "TODO", "TODO"]


def test_release_only_touches_video_rows(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, True)
    _sync(farm_root)
    other = str(
        router.enqueue_task(
            farm_root,
            "ops_issue",
            state="BLOCKED",
            priority=90,
            required_capabilities=["code", "ops"],
            payload={"title": "unrelated blocked row"},
        )["task_id"]
    )
    video = _blocked_held_task(farm_root)
    result = release.release_holds(farm_root, apply=True)
    assert result["released_task_ids"] == [video]
    assert _state_and_payload(farm_root, other)[0] == "BLOCKED"


def test_released_row_is_routable_and_carries_the_contract(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, True)
    task_id = _blocked_held_task(farm_root)
    release.release_holds(farm_root, apply=True)
    decision = _route(farm_root)
    assert decision.task_id == task_id
    assert decision.assigned_agent in router.VIDEO_ANALYSIS_AI_LANES
    _, payload = _state_and_payload(farm_root, task_id)
    assert payload["video_analysis_contract"]["agent"] == decision.assigned_agent


def test_release_staged_ahead_of_activation_is_marked_as_such(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _arm(monkeypatch, False)
    task_id = _blocked_held_task(farm_root)
    result = release.release_holds(farm_root, apply=True, allow_switch_off=True)
    assert result["released"] == 1
    _, payload = _state_and_payload(farm_root, task_id)
    assert payload["video_analysis_release"]["staged_ahead_of_switch"] is True
    # ... and with the switch still OFF the router keeps holding it for OWNER.
    assert _route(farm_root).reason == "awaiting_human_lane:owner"


def test_release_cli_dry_run_writes_nothing(
    farm_root: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    _arm(monkeypatch, True)
    task_id = _blocked_held_task(farm_root)
    exit_code = release.main(["--root", str(farm_root)])
    payload = json.loads(capsys.readouterr().out)
    assert exit_code == 0
    assert payload["apply"] is False
    assert payload["candidate_count"] == 1
    assert _state_and_payload(farm_root, task_id)[0] == "BLOCKED"
