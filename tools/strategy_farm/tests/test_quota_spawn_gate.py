from __future__ import annotations

import datetime as dt
import json
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import agent_router  # noqa: E402
import quota_governor  # noqa: E402
import quota_spawn_gate  # noqa: E402


def _state(now: dt.datetime, *, used: float, elapsed: float, five_hour: float | None) -> dict:
    agents = {}
    for agent in ("codex", "claude"):
        agents[agent] = {
            "used_pct": used,
            "elapsed_pct": elapsed,
            "five_hour_used_pct": five_hour,
        }
    return {"ts": now.isoformat(), "agents": agents}


def _write_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state), encoding="utf-8")


def _evaluate(
    tmp_path: Path,
    now: dt.datetime,
    task_type: str,
    priority: int,
    state: dict | None,
):
    state_path = tmp_path / "governor.json"
    if state is not None:
        _write_state(state_path, state)
    return quota_spawn_gate.evaluate_spawn(
        "codex",
        task_type,
        priority,
        state_path=state_path,
        summary_path=tmp_path / "summary.json",
        now=now,
    )


def test_research_gates_before_build_and_build_before_ops(tmp_path: Path) -> None:
    now = dt.datetime(2026, 8, 3, 12, 0, tzinfo=dt.UTC)

    slightly_ahead = _state(now, used=50, elapsed=52, five_hour=40)
    research = _evaluate(tmp_path, now, "research_strategy", 50, slightly_ahead)
    build = _evaluate(tmp_path, now, "build_ea", 50, slightly_ahead)
    assert research["allowed"] is False
    assert "weekly_pace_threshold" in research["violations"]
    assert build["allowed"] is True

    further_ahead = _state(now, used=60, elapsed=55, five_hour=40)
    build = _evaluate(tmp_path, now, "build_ea", 50, further_ahead)
    ops = _evaluate(tmp_path, now, "ops_issue", 50, further_ahead)
    assert build["allowed"] is False
    assert ops["allowed"] is True


def test_ops_review_is_allowed_on_pace_surplus_below_hard_exhaustion(tmp_path: Path) -> None:
    now = dt.datetime(2026, 8, 3, 12, 0, tzinfo=dt.UTC)
    decision = _evaluate(
        tmp_path,
        now,
        "review_ea",
        50,
        _state(now, used=94, elapsed=96, five_hour=92),
    )
    assert decision["allowed"] is True
    assert decision["reason"] == "pace_surplus_continuity"


def test_owner_priority_bypasses_class_threshold_but_not_hard_exhaustion(tmp_path: Path) -> None:
    now = dt.datetime(2026, 8, 3, 12, 0, tzinfo=dt.UTC)
    bypass = _evaluate(
        tmp_path,
        now,
        "research_strategy",
        70,
        _state(now, used=90, elapsed=40, five_hour=90),
    )
    exhausted = _evaluate(
        tmp_path,
        now,
        "ops_issue",
        99,
        _state(now, used=98, elapsed=99, five_hour=20),
    )
    assert bypass["allowed"] is True
    assert bypass["reason"] == "owner_priority_bypass"
    assert exhausted["allowed"] is False
    assert exhausted["reason"] == "hard_exhaustion"


def test_missing_and_stale_state_fail_open_for_ops_but_closed_for_research(tmp_path: Path) -> None:
    now = dt.datetime(2026, 8, 3, 12, 0, tzinfo=dt.UTC)
    missing_ops = _evaluate(tmp_path, now, "ops_issue", 50, None)
    missing_research = _evaluate(tmp_path, now, "research_strategy", 50, None)
    stale = _state(now - dt.timedelta(minutes=31), used=20, elapsed=20, five_hour=10)
    stale_review = _evaluate(tmp_path, now, "review_strategy", 50, stale)
    stale_research = _evaluate(tmp_path, now, "research_strategy", 50, stale)
    assert missing_ops["allowed"] is True
    assert missing_research["allowed"] is False
    assert stale_review["allowed"] is True
    assert stale_research["allowed"] is False


def test_deterministic_backtests_are_never_quota_gated(tmp_path: Path) -> None:
    now = dt.datetime(2026, 8, 3, 12, 0, tzinfo=dt.UTC)
    decision = quota_spawn_gate.evaluate_spawn(
        "codex",
        "backtest_q08",
        1,
        config_path=tmp_path / "missing-policy.json",
        state_path=tmp_path / "missing-state.json",
        summary_path=tmp_path / "summary.json",
        now=now,
    )
    assert decision["allowed"] is True
    assert decision["reason"] == "deterministic_no_llm_never_gated"


def test_summary_contract_is_one_line_and_exposes_both_agents(tmp_path: Path) -> None:
    now = dt.datetime(2026, 8, 3, 12, 0, tzinfo=dt.UTC)
    state = _state(now, used=26, elapsed=33, five_hour=12)
    state["agents"]["claude"]["used_pct"] = 35
    state_path = tmp_path / "governor.json"
    summary_path = tmp_path / "headroom.json"
    _write_state(state_path, state)

    quota_spawn_gate.evaluate_spawn(
        "codex",
        "ops_issue",
        65,
        state_path=state_path,
        summary_path=summary_path,
        now=now,
    )

    raw = summary_path.read_text(encoding="utf-8")
    summary = json.loads(raw)
    assert len(raw.splitlines()) == 1
    assert summary["codex"]["weekly_used_pct"] == 26
    assert summary["claude"]["weekly_used_pct"] == 35
    assert summary["last_gate"]["allowed"] is True


def test_owner_model_matrix_selects_max_high_medium_and_deliberate_opus() -> None:
    decision_bound = quota_spawn_gate.invocation_profile(
        "codex",
        "ops_issue",
        {"acceptance": "change fail-closed runtime decision-bound contract"},
    )
    ordinary_build = quota_spawn_gate.invocation_profile("codex", "build_ea", {})
    mechanical = quota_spawn_gate.invocation_profile(
        "codex",
        "ops_issue",
        {"brief": "mechanical edit to a census report script"},
    )
    claude_default = quota_spawn_gate.invocation_profile("claude", "build_ea", {})
    claude_opus = quota_spawn_gate.invocation_profile(
        "claude",
        "review_strategy",
        {"claude_headless_model": "opus"},
    )
    assert decision_bound is not None and decision_bound["reasoning_effort"] == "max"
    assert ordinary_build is not None and ordinary_build["reasoning_effort"] == "high"
    assert mechanical is not None and mechanical["reasoning_effort"] == "medium"
    assert claude_default is not None and claude_default["model"] == "sonnet"
    assert claude_opus is not None and claude_opus["model"] == "opus"


def test_quota_governor_carries_reported_five_hour_usage(monkeypatch) -> None:
    now = dt.datetime(2026, 8, 3, 12, 0, tzinfo=dt.UTC)
    reset = now + dt.timedelta(days=4)
    snap = {
        "claude": {
            "data": {
                "structured": {"week_pct": 35, "hour_pct": 9},
                "raw": {"seven_day": {"resets_at": reset.isoformat()}},
            }
        }
    }
    monkeypatch.setattr(quota_governor, "_now", lambda: now)
    metrics = quota_governor._agent_metrics(snap, "claude")
    assert metrics is not None
    assert metrics["five_hour_used_pct"] == 9


def test_router_filters_quota_blocked_agents_before_claiming_lease(tmp_path: Path) -> None:
    now = dt.datetime.now(dt.UTC).replace(microsecond=0)
    state_path = tmp_path / "governor.json"
    summary_path = tmp_path / "summary.json"
    _write_state(state_path, _state(now, used=60, elapsed=40, five_hour=20))
    task = agent_router.enqueue_task(
        tmp_path,
        "ops_issue",
        state="TODO",
        priority=50,
        required_capabilities=["ops", "code"],
        payload={"brief": "quota integration test"},
    )

    blocked = agent_router.route_once(
        tmp_path,
        claude_disabled_flag=tmp_path / "missing.flag",
        quota_gate_enabled=True,
        quota_state_path=state_path,
        quota_summary_path=summary_path,
    )
    assert blocked.reason == "quota_gate_blocked"
    assert agent_router.list_tasks(tmp_path, state="TODO")[0]["id"] == task["task_id"]

    with agent_router.connect(tmp_path) as con:
        con.execute("UPDATE agent_tasks SET priority=70 WHERE id=?", (task["task_id"],))
        con.commit()
    routed = agent_router.route_once(
        tmp_path,
        claude_disabled_flag=tmp_path / "missing.flag",
        quota_gate_enabled=True,
        quota_state_path=state_path,
        quota_summary_path=summary_path,
    )
    assert routed.reason == "assigned"
    assert routed.assigned_agent == "codex"
    assigned = agent_router.list_tasks(tmp_path, agent_id="codex", state="IN_PROGRESS")[0]
    assert assigned["payload"]["quota_gate"]["reason"] == "owner_priority_bypass"


def test_router_scans_past_quota_blocked_research_for_ops_continuity(tmp_path: Path) -> None:
    now = dt.datetime.now(dt.UTC).replace(microsecond=0)
    state_path = tmp_path / "governor.json"
    _write_state(state_path, _state(now, used=60, elapsed=55, five_hour=20))
    for index in range(30):
        agent_router.enqueue_task(
            tmp_path,
            "research_strategy",
            state="TODO",
            priority=60,
            required_capabilities=["ops", "code"],
            payload={"brief": f"blocked research {index}"},
        )
    ops = agent_router.enqueue_task(
        tmp_path,
        "ops_issue",
        state="TODO",
        priority=50,
        required_capabilities=["ops", "code"],
        payload={"brief": "continuity incident"},
    )

    routed = agent_router.route_once(
        tmp_path,
        claude_disabled_flag=tmp_path / "missing.flag",
        quota_gate_enabled=True,
        quota_state_path=state_path,
        quota_summary_path=tmp_path / "summary.json",
    )
    assert routed.reason == "assigned"
    assert routed.task_id == ops["task_id"]
