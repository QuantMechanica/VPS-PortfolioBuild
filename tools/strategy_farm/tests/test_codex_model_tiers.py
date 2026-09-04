"""Model routing doctrine 2026-09-04 section 5 - Codex model tier contract.

Covers tier resolution precedence, hold-not-downgrade for the scalpel tier,
the fallback chain and its downgrade marker, 5h ledger window arithmetic,
config validation, dispatcher argv, decision-bound lane pinning and the
QM_CODEX_MODEL_TIERS=0 rollback. Nothing here touches live state: every path
is a tmp_path or a monkeypatched env value.
"""

from __future__ import annotations

import copy
import datetime as dt
import json
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import agent_router  # noqa: E402
import codex_model_tiers as tiers  # noqa: E402
import quota_governor  # noqa: E402
import quota_spawn_gate  # noqa: E402
import run_agent_orchestration_task as orchestration  # noqa: E402

import pytest  # noqa: E402


NOW = dt.datetime(2026, 9, 4, 12, 0, tzinfo=dt.UTC)


@pytest.fixture(autouse=True)
def _isolated_environment(tmp_path, monkeypatch):
    """No live burn flag, no live ledger, no live governor state."""
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(tmp_path / "ledger.jsonl"))
    monkeypatch.delenv(tiers.TIERS_ENV, raising=False)
    mods = {id(quota_governor): quota_governor}
    try:
        from tools.strategy_farm import quota_governor as pkg_gov  # noqa: PLC0415

        mods[id(pkg_gov)] = pkg_gov
    except ModuleNotFoundError:
        pass
    for mod in mods.values():
        for agent in list(mod.BURN_FLAGS):
            monkeypatch.setitem(mod.BURN_FLAGS, agent, tmp_path / f"absent_{agent}.flag")


def _policy() -> dict:
    policy, error = quota_spawn_gate.load_policy()
    assert error is None, error
    assert policy is not None
    return policy


def _codex_matrix() -> dict:
    return _policy()["model_matrix"]["codex"]


def _tier_modules() -> list:
    """Both import shapes of `codex_model_tiers`, so a monkeypatch reaches the
    object `quota_spawn_gate` actually holds (same trick as the conftest uses
    for `quota_governor`)."""
    mods = {id(tiers): tiers}
    try:
        from tools.strategy_farm import codex_model_tiers as pkg_tiers  # noqa: PLC0415

        mods[id(pkg_tiers)] = pkg_tiers
    except ModuleNotFoundError:  # pragma: no cover - import shape dependent
        pass
    return list(mods.values())


def _break_ledger_read(monkeypatch, error: str = "PermissionError") -> None:
    for mod in _tier_modules():
        monkeypatch.setattr(
            mod, "read_ledger", lambda path: ([], {"corrupt_lines": 0, "read_error": error})
        )


def _break_ledger_write(monkeypatch, error: str = "PermissionError") -> None:
    for mod in _tier_modules():
        monkeypatch.setattr(
            mod,
            "_append_record",
            lambda path, record: f"{tiers.LEDGER_WRITE_ERROR_REASON}:{error}",
        )


def _codex_matrix_with_effort_mapping() -> dict:
    """CEO decision D1: the shipped matrix with the OPT-IN effort remap ON."""
    matrix = copy.deepcopy(_codex_matrix())
    matrix[tiers.EFFORT_MAPPING_FIELD] = True
    return matrix


def _policy_with_effort_mapping(tmp_path: Path, monkeypatch) -> Path:
    """Point the whole gate stack at a policy whose D1 remap flag is true."""
    policy = _policy()
    policy["model_matrix"]["codex"][tiers.EFFORT_MAPPING_FIELD] = True
    config_path = tmp_path / "policy_effort_mapping.json"
    config_path.write_text(json.dumps(policy), encoding="utf-8")
    monkeypatch.setattr(quota_spawn_gate, "CONFIG_PATH", config_path)
    return config_path


def _write_ledger(path: Path, entries: list[tuple[str, dt.datetime]]) -> None:
    lines = [
        json.dumps({"ts": stamp.isoformat(), "task_id": f"t{index}", "tier": "x", "model": model})
        for index, (model, stamp) in enumerate(entries)
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


# --- config validation ------------------------------------------------------


def test_shipped_matrix_is_complete_and_keeps_the_current_default_model() -> None:
    codex = _codex_matrix()

    assert tiers.validate_matrix(codex) is None
    assert codex["model"] == "gpt-5.6-sol"
    assert codex["plan_tier"] == "plus"
    assert codex["explicit_tier_payload_field"] == "codex_model_tier"
    assert codex["window_safety_factor"] == 0.8
    assert codex["tiers"]["astra"]["model"] == "gpt-6-astra"
    assert codex["tiers"]["sol"]["five_hour_messages"] == {
        "plus": 10,
        "pro_5x": 50,
        "pro_20x": 200,
    }
    assert codex["tiers"]["astra"]["fallback_tier"] is None


def test_incomplete_tier_matrix_fails_closed(tmp_path: Path) -> None:
    policy = _policy()
    codex = policy["model_matrix"]["codex"]
    broken = dict(codex)
    broken["tiers"] = {name: dict(cfg) for name, cfg in codex["tiers"].items()}
    del broken["tiers"]["sol"]["five_hour_messages"]
    assert str(tiers.validate_matrix(broken)).startswith("codex_model_matrix_incomplete")

    unknown_fallback = dict(codex)
    unknown_fallback["tiers"] = {name: dict(cfg) for name, cfg in codex["tiers"].items()}
    unknown_fallback["tiers"]["terra"]["fallback_tier"] = "does_not_exist"
    assert str(tiers.validate_matrix(unknown_fallback)).startswith("codex_model_matrix_incomplete")

    policy["model_matrix"]["codex"] = broken
    config_path = tmp_path / "policy.json"
    config_path.write_text(json.dumps(policy), encoding="utf-8")
    loaded, error = quota_spawn_gate.load_policy(config_path)
    assert loaded is None
    assert str(error).startswith("codex_model_matrix_incomplete")


def test_policy_without_tier_block_loads_again_under_the_rollback(
    tmp_path: Path, monkeypatch
) -> None:
    policy = _policy()
    codex = dict(policy["model_matrix"]["codex"])
    for key in ("tiers", "plan_tier", "explicit_tier_payload_field"):
        codex.pop(key, None)
    policy["model_matrix"]["codex"] = codex
    config_path = tmp_path / "policy.json"
    config_path.write_text(json.dumps(policy), encoding="utf-8")

    blocked, error = quota_spawn_gate.load_policy(config_path)
    assert blocked is None and error == "codex_model_matrix_incomplete"

    monkeypatch.setenv(tiers.TIERS_ENV, "0")
    loaded, error = quota_spawn_gate.load_policy(config_path)
    assert loaded is not None and error is None


# --- tier resolution precedence --------------------------------------------


@pytest.mark.parametrize(
    ("payload", "task_type", "effort", "expected_tier", "expected_source"),
    [
        ({"codex_model_tier": "luna"}, "ops_issue", "max", "luna", "explicit_payload"),
        ({"codex_model_tier": "sol", "scalpel": True}, "ops_issue", "medium", "sol", "explicit_payload"),
        ({"scalpel": True}, "ops_issue", "medium", "astra", "scalpel"),
        ({}, "strategy_mechanize_source", "medium", "astra", "scalpel"),
        # CEO decision D1: with `effort_class_tier_mapping_enabled` false (the
        # shipped default) an untiered task lands on `default_tier`, i.e. keeps
        # today's model.
        ({}, "ops_issue", "max", "sol", "default_tier"),
        ({}, "build_ea", "high", "sol", "default_tier"),
        ({}, "ops_issue", "medium", "sol", "default_tier"),
    ],
)
def test_tier_precedence(payload, task_type, effort, expected_tier, expected_source) -> None:
    resolution = tiers.resolve_tier(_codex_matrix(), payload, task_type, effort)

    assert resolution["error"] is None
    assert resolution["tier"] == expected_tier
    assert resolution["source"] == expected_source


@pytest.mark.parametrize(
    ("effort", "expected_tier"),
    [("max", "sol"), ("high", "terra"), ("medium", "luna")],
)
def test_effort_class_remap_is_opt_in(effort, expected_tier) -> None:
    """CEO decision D1: the doctrine section 2 remap only fires behind the flag."""
    off = tiers.resolve_tier(_codex_matrix(), {}, "build_ea", effort)
    assert off["tier"] == "sol" and off["source"] == "default_tier"
    assert "effort_class_mapping_disabled" in off["reason"]

    on = tiers.resolve_tier(_codex_matrix_with_effort_mapping(), {}, "build_ea", effort)
    assert on["tier"] == expected_tier and on["source"] == "effort_class"


def test_untiered_tasks_keep_todays_argv_with_the_remap_off(tmp_path, monkeypatch) -> None:
    """CEO decision D1: byte-identical command line for the probed no-tier cases.

    These are exactly the cases round 2 measured as changing model
    (build_ea, ops_issue, research_strategy, a recycled build_ea, the mechanical
    class and an explicit medium effort). With the flag false every one of them
    must render the pre-doctrine argv again.
    """
    monkeypatch.setattr(orchestration, "resolve_cli", lambda agent: f"{agent}.cmd")
    monkeypatch.setattr(orchestration, "_CODEX_MODEL_ENV_OVERRIDE", "")
    probes = [
        ("build_ea", {}, "high"),
        ("ops_issue", {}, "high"),
        ("research_strategy", {}, "high"),
        ("build_ea", {"recycle_count": 1}, "high"),
        ("ops_issue", {"brief": "mechanical edit to a census report script"}, "medium"),
        ("ops_issue", {"codex_reasoning_effort": "medium"}, "medium"),
        ("review_ea", {}, "max"),
    ]
    for task_type, payload, expected_effort in probes:
        profile = quota_spawn_gate.invocation_profile("codex", task_type, payload, now=NOW)
        assert profile["model"] == "gpt-5.6-sol", (task_type, payload)
        assert profile["reasoning_effort"] == expected_effort, (task_type, payload)
        cmd = orchestration.command_for("codex", tmp_path, model_contract=profile)
        assert cmd == [
            "codex.cmd",
            "exec",
            "-m",
            "gpt-5.6-sol",
            "-c",
            f'model_reasoning_effort="{expected_effort}"',
            "--dangerously-bypass-approvals-and-sandbox",
            "--cd",
            str(tmp_path),
        ], (task_type, payload)


def test_untiered_tasks_move_to_the_mapped_tier_with_the_remap_on(
    tmp_path, monkeypatch
) -> None:
    """CEO decision D1, other half: with the flag TRUE the doctrine mapping applies."""
    config_path = _policy_with_effort_mapping(tmp_path, monkeypatch)
    monkeypatch.setattr(orchestration, "resolve_cli", lambda agent: f"{agent}.cmd")
    monkeypatch.setattr(orchestration, "_CODEX_MODEL_ENV_OVERRIDE", "")
    expected = {
        "build_ea": "gpt-5.6-terra",
        "ops_issue": "gpt-5.6-terra",
        "research_strategy": "gpt-5.6-terra",
        "review_ea": "gpt-5.6-sol",
    }
    for task_type, model in expected.items():
        profile = quota_spawn_gate.invocation_profile(
            "codex", task_type, {}, now=NOW, config_path=config_path
        )
        assert profile["model"] == model, task_type
        cmd = orchestration.command_for("codex", tmp_path, model_contract=profile)
        assert cmd[cmd.index("-m") + 1] == model

    bulk = quota_spawn_gate.invocation_profile(
        "codex",
        "ops_issue",
        {"brief": "mechanical edit to a census report script"},
        now=NOW,
        config_path=config_path,
    )
    assert bulk["model"] == "gpt-5.6-luna"


def test_unknown_tier_fails_closed_with_a_structured_reason(tmp_path: Path) -> None:
    resolution = tiers.resolve_tier(_codex_matrix(), {"codex_model_tier": "gpt-9"}, "ops_issue", "max")
    assert resolution["tier"] is None
    assert resolution["error"]["code"] == "codex_model_tier_unknown"
    assert resolution["error"]["requested"] == "gpt-9"

    decision = quota_spawn_gate.evaluate_spawn(
        "codex",
        "ops_issue",
        50,
        state_path=tmp_path / "governor.json",
        summary_path=tmp_path / "summary.json",
        payload={"codex_model_tier": "gpt-9"},
        now=NOW,
    )
    assert decision["allowed"] is False
    assert decision["reason"] == "codex_model_tier_unknown"
    assert decision["invocation"]["model_tier_error"]["requested"] == "gpt-9"


def test_explicit_tier_takes_the_tier_default_effort() -> None:
    profile = quota_spawn_gate.invocation_profile(
        "codex",
        "ops_issue",
        {"codex_model_tier": "astra"},
        now=NOW,
    )
    assert profile["model"] == "gpt-6-astra"
    assert profile["reasoning_effort"] == "max"

    explicit_effort = quota_spawn_gate.invocation_profile(
        "codex",
        "ops_issue",
        {"codex_model_tier": "astra", "codex_reasoning_effort": "medium"},
        now=NOW,
    )
    assert explicit_effort["model"] == "gpt-6-astra"
    assert explicit_effort["reasoning_effort"] == "medium"


# --- window arithmetic, fallback and hold -----------------------------------


def test_window_budget_uses_the_low_end_times_the_safety_factor() -> None:
    codex = _codex_matrix()
    plan = codex["plan_tier"]

    assert tiers.window_budget(codex["tiers"]["astra"], plan, 0.8) == 2
    assert tiers.window_budget(codex["tiers"]["sol"], plan, 0.8) == 8
    assert tiers.window_budget(codex["tiers"]["terra"], plan, 0.8) == 20
    assert tiers.window_budget(codex["tiers"]["luna"], plan, 0.8) == 200
    assert tiers.window_budget(codex["tiers"]["sol"], "pro_20x", 0.8) == 160


def test_ledger_counts_only_the_rolling_five_hour_window(tmp_path: Path) -> None:
    path = tmp_path / "window.jsonl"
    _write_ledger(
        path,
        [
            ("gpt-5.6-sol", NOW - dt.timedelta(minutes=301)),  # left the window
            ("gpt-5.6-sol", NOW - dt.timedelta(minutes=300)),  # exactly 5h -> out
            ("gpt-5.6-sol", NOW - dt.timedelta(minutes=299)),  # inside
            ("gpt-5.6-sol", NOW - dt.timedelta(minutes=1)),  # inside
            ("gpt-5.6-terra", NOW - dt.timedelta(minutes=2)),  # other model
            ("gpt-5.6-sol", NOW + dt.timedelta(minutes=90)),  # clock skew -> counted
        ],
    )
    path.write_text(path.read_text(encoding="utf-8") + "not json\n", encoding="utf-8")

    # Fix round: a record stamped ahead of the reader's clock is COUNTED. The
    # first version dropped it and thereby re-granted the whole budget after a
    # wall-clock jump (8 records 10 minutes in the future -> window_count 0).
    # CEO decision D4: the single corrupt line ("not json") also counts as one
    # consumed message, for every model, because it carries no attribution.
    assert tiers.window_count("gpt-5.6-sol", now=NOW, path=path) == 3 + 1
    assert tiers.window_count("gpt-5.6-terra", now=NOW, path=path) == 1 + 1
    later = NOW + dt.timedelta(minutes=299)
    assert tiers.window_count("gpt-5.6-sol", now=later, path=path) == 1 + 1


def test_fallback_chain_is_primary_then_legacy() -> None:
    tier_cfg = _codex_matrix()["tiers"]

    assert tiers.fallback_chain("sol", tier_cfg) == [
        "sol",
        "terra",
        "luna",
        "gpt55",
        "gpt54",
        "gpt54mini",
    ]
    assert tiers.fallback_chain("terra", tier_cfg) == ["terra", "luna", "gpt54", "gpt54mini"]
    assert tiers.fallback_chain("astra", tier_cfg) == ["astra"]


def test_exhausted_tier_falls_back_and_records_the_downgrade(tmp_path: Path) -> None:
    codex = _codex_matrix()
    path = tmp_path / "window.jsonl"
    _write_ledger(
        path,
        [("gpt-5.6-sol", NOW - dt.timedelta(minutes=index + 1)) for index in range(8)],
    )

    selected = tiers.select_dispatch(codex, {}, "ops_issue", "max", now=NOW, path=path)

    assert selected["model_tier"] == "terra"
    assert selected["model"] == "gpt-5.6-terra"
    assert selected["model_tier_downgraded_from"] == "sol"
    assert selected["reasoning_effort"] == "max"  # depth is never lowered
    assert "downgraded_from:sol" in selected["model_tier_reason"]
    assert "model_tier_refusal" not in selected


def test_whole_chain_exhausted_refuses_with_tier_model_count_budget(tmp_path: Path) -> None:
    codex = _codex_matrix()
    path = tmp_path / "window.jsonl"
    spent: list[tuple[str, dt.datetime]] = []
    for name in tiers.fallback_chain("sol", codex["tiers"]):
        model = codex["tiers"][name]["model"]
        budget = tiers.window_budget(codex["tiers"][name], codex["plan_tier"], 0.8)
        spent += [(model, NOW - dt.timedelta(seconds=index + 1)) for index in range(int(budget))]
    _write_ledger(path, spent)

    blocked = tiers.select_dispatch(codex, {}, "ops_issue", "max", now=NOW, path=path)

    refusal = blocked["model_tier_refusal"]
    assert refusal["code"] == "codex_tier_window_exhausted"
    assert refusal["tier"] == "sol"
    assert refusal["model"] == "gpt-5.6-sol"
    assert refusal["count"] == 8
    assert refusal["budget"] == 8
    assert "model_tier_hold" not in blocked


def test_astra_is_held_not_downgraded_when_its_window_is_spent(tmp_path: Path) -> None:
    codex = _codex_matrix()
    path = tmp_path / "window.jsonl"
    _write_ledger(path, [("gpt-6-astra", NOW - dt.timedelta(minutes=index + 1)) for index in range(2)])

    blocked = tiers.select_dispatch(codex, {"scalpel": True}, "ops_issue", "max", now=NOW, path=path)

    assert blocked["model_tier"] == "astra"
    assert blocked["model"] == "gpt-6-astra"  # never a weaker model
    assert "model_tier_downgraded_from" not in blocked
    assert blocked["model_tier_hold"] == {
        "code": "ROUTER_AWAITING_MODEL_WINDOW",
        "tier": "astra",
        "model": "gpt-6-astra",
        "count": 2,
        "budget": 2,
    }


def test_router_holds_a_scalpel_task_as_awaiting_model_window(tmp_path: Path, monkeypatch) -> None:
    # The router resolves the window against the real clock, so this end-to-end
    # case is anchored on `now` rather than the fixed NOW of the unit cases.
    now = dt.datetime.now(dt.UTC).replace(microsecond=0)
    ledger = tmp_path / "window.jsonl"
    _write_ledger(ledger, [("gpt-6-astra", now - dt.timedelta(minutes=index + 1)) for index in range(2)])
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(ledger))
    state_path = tmp_path / "governor.json"
    state_path.write_text(
        json.dumps(
            {
                "ts": now.isoformat(),
                "agents": {
                    agent: {"used_pct": 10, "elapsed_pct": 50, "five_hour_used_pct": 5}
                    for agent in ("codex", "claude")
                },
            }
        ),
        encoding="utf-8",
    )
    task = agent_router.enqueue_task(
        tmp_path,
        "ops_issue",
        state="TODO",
        priority=50,
        required_capabilities=["ops", "code"],
        payload={"brief": "mechanize a vetted source", "scalpel": True},
        assigned_agent="codex",
    )

    routed = agent_router.route_once(
        tmp_path,
        claude_disabled_flag=tmp_path / "missing.flag",
        quota_gate_enabled=True,
        quota_state_path=state_path,
        quota_summary_path=tmp_path / "summary.json",
    )

    assert routed.reason == "awaiting_model_window:astra"
    assert routed.assigned_agent is None
    held = agent_router.list_tasks(tmp_path, state="TODO")[0]
    assert held["id"] == task["task_id"]
    assert held["payload"]["router_model_window_hold"]["tier"] == "astra"


# --- decision-bound lane pinning -------------------------------------------


def test_ops_issue_with_owner_decision_is_never_routed_to_codex(tmp_path: Path) -> None:
    """Regression: 2026-09-04 01:00Z three claude-reserved rows ran on codex."""
    task = agent_router.enqueue_task(
        tmp_path,
        "ops_issue",
        state="TODO",
        priority=50,
        required_capabilities=["ops", "code"],
        payload={
            "owner_decision": "OWNER-DEC-DL082-EXT-Q08-20260901",
            "allowed_actions": ["execute option D"],
        },
    )

    routed = agent_router.route_once(tmp_path, claude_disabled_flag=tmp_path / "missing.flag")

    assert routed.task_id == task["task_id"]
    assert routed.assigned_agent == "claude"
    assert not agent_router.list_tasks(tmp_path, agent_id="codex", state="IN_PROGRESS")


def test_explicit_pin_wins_over_cost_rank_and_waits_for_its_own_lane(tmp_path: Path) -> None:
    agent_router.enqueue_task(
        tmp_path,
        "ops_issue",
        state="TODO",
        priority=50,
        payload={"brief": "pinned to the claude lane"},
        assigned_agent="claude",
    )
    stored = agent_router.list_tasks(tmp_path, state="TODO")[0]
    assert stored["payload"]["decision_bound_agent"] == "claude"

    routed = agent_router.route_once(tmp_path, claude_disabled_flag=tmp_path / "missing.flag")
    assert routed.assigned_agent == "claude"

    agent_router.enqueue_task(
        tmp_path,
        "ops_issue",
        state="TODO",
        priority=50,
        payload={"brief": "pinned to a lane with no seat"},
        assigned_agent="owner",
    )
    with agent_router.connect(tmp_path) as con:
        con.execute("UPDATE agent_tasks SET state='PASSED' WHERE state='IN_PROGRESS'")
        con.commit()

    held = agent_router.route_once(tmp_path, claude_disabled_flag=tmp_path / "missing.flag")
    assert held.reason == "awaiting_decision_bound_agent:owner"
    assert held.assigned_agent is None


def test_payload_required_capabilities_are_honoured_at_enqueue_and_routing(tmp_path: Path) -> None:
    task = agent_router.enqueue_task(
        tmp_path,
        "research_strategy",
        state="TODO",
        priority=50,
        payload={"required_capabilities": ["video_analysis", "review"]},
    )
    with agent_router.connect(tmp_path) as con:
        stored = con.execute(
            "SELECT id, required_capabilities_json FROM agent_tasks"
        ).fetchone()
    assert stored["id"] == task["task_id"]
    # CEO decision D7: the column is the UNION of the task-type contract and the
    # declared payload capabilities, never a bare replacement, so the enqueue
    # path and the two routing selectors agree on exactly one set.
    assert json.loads(stored["required_capabilities_json"]) == [
        "research",
        "strategy",
        "review",
        "video_analysis",
    ]

    routed = agent_router.route_once(tmp_path, claude_disabled_flag=tmp_path / "missing.flag")

    assert routed.reason == "awaiting_human_lane:owner"
    assert routed.assigned_agent is None


def test_a_video_analysis_skill_still_holds_the_owner_lane(tmp_path: Path) -> None:
    """The union must not disturb the human-lane hold, which rides on SKILLS."""
    task = agent_router.enqueue_task(
        tmp_path,
        "research_strategy",
        state="TODO",
        priority=50,
        required_skills=["video_analysis"],
    )
    routed = agent_router.route_once(tmp_path, claude_disabled_flag=tmp_path / "missing.flag")

    assert routed.task_id == task["task_id"]
    assert routed.assigned_agent is None
    assert routed.reason == "awaiting_human_lane:owner"


def test_route_once_and_enqueue_agree_on_the_capability_union(tmp_path: Path) -> None:
    """CEO decision D7: both paths produce the SAME required-capability set."""
    agent_router.sync_default_registry(tmp_path, claude_disabled_flag=tmp_path / "missing.flag")
    payload = {"required_capabilities": ["review"]}
    task = agent_router.enqueue_task(
        tmp_path, "ops_issue", state="TODO", priority=50, payload=payload
    )
    with agent_router.connect(tmp_path) as con:
        column = json.loads(
            con.execute(
                "SELECT required_capabilities_json FROM agent_tasks WHERE id=?",
                (task["task_id"],),
            ).fetchone()["required_capabilities_json"]
        )
    assert set(column) == {"ops", "code", "review"}

    # A row written OUTSIDE enqueue_task keeps the bare task-type column; the
    # router unions the payload declaration onto it and lands on the same set.
    other = agent_router.enqueue_task(tmp_path, "ops_issue", state="TODO", priority=49)
    with agent_router.connect(tmp_path) as con:
        con.execute(
            "UPDATE agent_tasks SET payload_json=?, required_capabilities_json=? WHERE id=?",
            (json.dumps(payload), json.dumps(["ops", "code"]), other["task_id"]),
        )
        con.commit()
    routed = agent_router.route_once(tmp_path, claude_disabled_flag=tmp_path / "missing.flag")
    assert routed.task_id == task["task_id"]
    stored = {row["id"]: row for row in agent_router.list_tasks(tmp_path)}
    assert set(stored[task["task_id"]]["payload"]["required_capabilities"]) == set(column)


# --- dispatcher argv --------------------------------------------------------


def test_dispatcher_emits_the_tier_model_and_effort(tmp_path: Path, monkeypatch) -> None:
    config_path = _policy_with_effort_mapping(tmp_path, monkeypatch)
    monkeypatch.setattr(orchestration, "resolve_cli", lambda agent: f"{agent}.cmd")
    monkeypatch.setattr(orchestration, "_CODEX_MODEL_ENV_OVERRIDE", "")
    bulk = quota_spawn_gate.invocation_profile(
        "codex",
        "ops_issue",
        {"brief": "mechanical edit to a census report script"},
        now=NOW,
        config_path=config_path,
    )
    deep = quota_spawn_gate.invocation_profile(
        "codex",
        "ops_issue",
        {"acceptance": "change fail-closed runtime decision-bound contract"},
        now=NOW,
        config_path=config_path,
    )

    bulk_cmd = orchestration.command_for("codex", tmp_path, model_contract=bulk)
    deep_cmd = orchestration.command_for("codex", tmp_path, model_contract=deep)

    assert bulk_cmd[bulk_cmd.index("-m") + 1] == "gpt-5.6-luna"
    assert 'model_reasoning_effort="medium"' in bulk_cmd
    assert deep_cmd[deep_cmd.index("-m") + 1] == "gpt-5.6-sol"
    assert 'model_reasoning_effort="max"' in deep_cmd


def test_farmctl_build_dispatch_uses_the_same_contract() -> None:
    import farmctl  # noqa: PLC0415

    model_args, effort_args, contract = farmctl._codex_dispatch_model_args(
        "build_ea", {"ea_id": "QM5_10000"}
    )

    # Remap off (D1): build_ea keeps today's model and its high effort class.
    assert model_args == "-m gpt-5.6-sol "
    assert effort_args == '-c model_reasoning_effort="high" '
    # A rendered command must not book a message.
    assert contract["ledger"]["recorded"] is False
    assert contract["refusal"] is None


def test_ledger_records_one_line_per_dispatch(tmp_path: Path) -> None:
    path = tmp_path / "record.jsonl"
    first = tiers.record_dispatch(
        task_id="task-1",
        tier="terra",
        model="gpt-5.6-terra",
        path=path,
        now=NOW,
    )
    tiers.record_dispatch(task_id="task-2", tier="terra", model="gpt-5.6-terra", path=path, now=NOW)

    assert first["recorded"] is True
    assert tiers.window_count("gpt-5.6-terra", now=NOW, path=path) == 2
    assert [json.loads(line)["task_id"] for line in path.read_text(encoding="utf-8").splitlines()] == [
        "task-1",
        "task-2",
    ]


# --- fix round: every REAL Codex spawn site is on the contract + ledger -----
# The first implementation instrumented only `run_agent_slot`, so the rolling
# 5h count undercounted and `codex_tier_window_exhausted` fired late.


def test_farmctl_pump_spawn_emits_the_tier_model_and_counts_one_message(
    tmp_path: Path, monkeypatch
) -> None:
    import farmctl  # noqa: PLC0415

    ledger = tmp_path / "pump.jsonl"
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(ledger))
    prompt = tmp_path / "prompt.md"
    prompt.write_text("do the thing", encoding="utf-8")
    live_log = tmp_path / "live.log"
    seen: dict = {}

    def _fake_spawn(root, command, **kwargs):
        seen["command"] = list(command)
        seen["metadata"] = dict(kwargs.get("metadata") or {})
        return object(), {"lease_id": "lease-1"}

    monkeypatch.setattr(farmctl, "_resolve_codex", lambda: "codex.cmd")
    monkeypatch.setattr(farmctl, "spawn_managed_codex", _fake_spawn)
    monkeypatch.setattr(farmctl, "_codex_env", dict)

    _proc, lease = farmctl._spawn_owned_codex(
        tmp_path,
        prompt,
        live_log,
        purpose="build",
        dedupe_key="build:task-9",
        metadata={"task_id": "task-9", "ea_id": "QM5_10000"},
    )

    command = seen["command"]
    # Remap off (D1): the build class keeps gpt-5.6-sol with its high effort.
    assert command[command.index("-m") + 1] == "gpt-5.6-sol"
    assert 'model_reasoning_effort="high"' in command
    # -m must precede the sandbox flag, i.e. the previous command is intact.
    assert command.index("-m") < command.index("-s")
    assert seen["metadata"]["model_tier"] == "sol"
    assert lease["model_window_ledger"]["recorded"] is True
    assert tiers.window_count("gpt-5.6-sol", now=dt.datetime.now(dt.UTC), path=ledger) == 1
    record = json.loads(ledger.read_text(encoding="utf-8").splitlines()[0])
    assert record["task_id"] == "task-9"
    assert record["model"] == "gpt-5.6-sol"


def test_fleet_pacer_and_mailbox_intake_use_the_same_contract() -> None:
    import codex_fleet_pacer  # noqa: PLC0415
    import mailbox_source_intake  # noqa: PLC0415

    pacer = codex_fleet_pacer._codex_spawn_contract()
    mailbox = mailbox_source_intake._codex_spawn_contract()

    # Both used to bypass the contract: the pacer with no -m at all, the
    # mailbox intake with a hardcoded `-m gpt-5.6-sol`.
    for contract in (pacer, mailbox):
        assert contract["allowed"] is True
        flags = contract["flags"]
        assert flags[0] == "-m" and flags[1] == contract["invocation"]["model"]
        assert contract["invocation"]["model_tier"]
        # A real spawn site books its message BEFORE the launch.
        assert contract["ledger"]["recorded"] is True


# --- fix round: no frozen import-time tier snapshot -------------------------


def test_module_default_invocation_carries_no_frozen_window() -> None:
    # The import-time fallback must be the pre-doctrine single-model contract:
    # a tier profile is only valid for the instant its window was measured.
    assert orchestration._DEFAULT_CODEX_INVOCATION["model"] == "gpt-5.6-sol"
    assert "model_tier" not in orchestration._DEFAULT_CODEX_INVOCATION
    assert "model_window" not in orchestration._DEFAULT_CODEX_INVOCATION
    assert orchestration.CODEX_HEADLESS_MODEL == "gpt-5.6-sol"


def test_contract_without_a_gate_invocation_resolves_freshly(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(orchestration, "_CODEX_MODEL_ENV_OVERRIDE", "")
    ledger = tmp_path / "fresh.jsonl"
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(ledger))

    fresh = orchestration.headless_model_contract("codex", None)
    assert fresh["model_contract_source"] == "resolved_at_dispatch"
    # Remap off (D1): build_ea lands on default_tier sol, today's model.
    assert fresh["model"] == "gpt-5.6-sol"
    assert not fresh.get("model_tier_refused")

    # Saturate the whole sol->terra->luna->legacy chain; the SAME call must now
    # report a refusal instead of handing back a stale in-budget snapshot.
    now = dt.datetime.now(dt.UTC)
    _write_ledger(
        ledger,
        [(model, now) for model in ["gpt-5.6-sol"] * 8 + ["gpt-5.6-terra"] * 20
         + ["gpt-5.6-luna"] * 200 + ["gpt-5.5"] * 12 + ["gpt-5.4"] * 16
         + ["gpt-5.4-mini"] * 48],
    )
    refused = orchestration.headless_model_contract("codex", None)
    assert refused["model_tier_refused"] is True
    assert refused["model_tier_refusal"]["code"] == tiers.WINDOW_EXHAUSTED_REASON


# --- fix round: enqueue must not strand a row on a descriptive label --------


def test_enqueue_ignores_a_capability_label_no_lane_declares(tmp_path: Path) -> None:
    # The union of D7 never adds a label no lane declares, so the row stays
    # routable on its task-type contract alone.
    agent_router.enqueue_task(
        tmp_path,
        "ops_issue",
        state="TODO",
        priority=50,
        payload={"required_capabilities": ["totally-descriptive-label"]},
    )
    with agent_router.connect(tmp_path) as con:
        stored = con.execute("SELECT required_capabilities_json FROM agent_tasks").fetchone()

    # The undeclared label is dropped (route_once applies the same
    # intersection); the row falls back to the task-type contract and routes.
    assert json.loads(stored["required_capabilities_json"]) == ["ops", "code"]
    routed = agent_router.route_once(tmp_path, claude_disabled_flag=tmp_path / "missing.flag")
    assert routed.assigned_agent == "codex"


# --- fix round: default_tier is a real fallback, not decoration -------------


def test_default_tier_catches_an_unresolvable_effort_class() -> None:
    codex = _codex_matrix()

    resolved = tiers.resolve_tier(codex, {}, "ops_issue", "not_an_effort_class")

    assert resolved["error"] is None
    assert resolved["tier"] == codex["default_tier"] == "sol"
    assert resolved["source"] == "default_tier"


# --- rollback ---------------------------------------------------------------


def test_rollback_env_restores_the_single_model_and_writes_no_ledger(
    tmp_path: Path, monkeypatch
) -> None:
    monkeypatch.setenv(tiers.TIERS_ENV, "0")
    path = tmp_path / "rollback.jsonl"
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(path))

    profile = quota_spawn_gate.invocation_profile(
        "codex",
        "ops_issue",
        {"acceptance": "change fail-closed runtime decision-bound contract"},
        now=NOW,
    )
    scalpel = quota_spawn_gate.invocation_profile("codex", "ops_issue", {"scalpel": True}, now=NOW)
    recorded = quota_spawn_gate.record_codex_dispatch(
        task_id="task-1",
        contract=profile,
        ledger_path=path,
        now=NOW,
    )

    assert profile["model"] == "gpt-5.6-sol"
    assert profile["reasoning_effort"] == "max"
    assert "model_tier" not in profile
    assert scalpel["model"] == "gpt-5.6-sol"
    assert recorded == {"recorded": False, "reason": "codex_model_tiers_disabled"}
    assert not path.exists()  # the rollback writes no ledger at all

    # CEO decision D2: the orchestration dispatcher's argv is the pre-doctrine
    # one as well (this site always emitted -m; the other three did not).
    monkeypatch.setattr(orchestration, "resolve_cli", lambda agent: f"{agent}.cmd")
    monkeypatch.setattr(orchestration, "_CODEX_MODEL_ENV_OVERRIDE", "")
    assert orchestration.command_for("codex", tmp_path, model_contract=profile) == [
        "codex.cmd",
        "exec",
        "-m",
        "gpt-5.6-sol",
        "-c",
        'model_reasoning_effort="max"',
        "--dangerously-bypass-approvals-and-sandbox",
        "--cd",
        str(tmp_path),
    ]


# ===========================================================================
# Fix round 2026-09-04 — the findings of the first review, one test each.
# ===========================================================================


def _saturate(path: Path, model: str, count: int, *, now: dt.datetime = NOW) -> None:
    lines = [
        json.dumps(
            {
                "ts": (now - dt.timedelta(minutes=index + 1)).isoformat(),
                "task_id": f"burn{index}",
                "tier": "x",
                "model": model,
                "kind": "dispatch",
                "id": f"burn{index}",
            }
        )
        for index in range(count)
    ]
    with path.open("a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


# --- M1: the refusal is the RESULT, not a side-band field -------------------


def test_spawn_contract_refuses_when_the_whole_chain_is_exhausted(tmp_path: Path) -> None:
    ledger = tmp_path / "exhausted.jsonl"
    matrix = _codex_matrix()
    plan = tiers.plan_tier(matrix)
    factor = tiers.safety_factor(matrix)
    for name in ("sol", "terra", "luna", "gpt55", "gpt54", "gpt54mini"):
        cfg = matrix["tiers"][name]
        _saturate(ledger, cfg["model"], tiers.window_budget(cfg, plan, factor))

    contract = quota_spawn_gate.codex_spawn_contract(
        "build_ea",
        {"runtime_decision_bound": True},
        task_id="task-refused",
        now=NOW,
        ledger_path=ledger,
    )

    assert contract["allowed"] is False
    assert contract["flags"] == []
    assert contract["refusal"]["reason"] == tiers.WINDOW_EXHAUSTED_REASON
    # And no line was written: the refusal must not raise the count further.
    assert tiers.window_count("gpt-5.6-sol", now=NOW, path=ledger) == tiers.window_budget(
        matrix["tiers"]["sol"], plan, factor
    )


def test_pump_spawn_refuses_instead_of_dispatching_over_budget(
    tmp_path: Path, monkeypatch
) -> None:
    import farmctl  # noqa: PLC0415

    ledger = tmp_path / "pump_refuse.jsonl"
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(ledger))
    matrix = _codex_matrix()
    plan = tiers.plan_tier(matrix)
    factor = tiers.safety_factor(matrix)
    now = dt.datetime.now(dt.UTC)
    for name in ("sol", "terra", "luna", "gpt55", "gpt54", "gpt54mini"):
        cfg = matrix["tiers"][name]
        _saturate(ledger, cfg["model"], tiers.window_budget(cfg, plan, factor), now=now)
    before = ledger.read_text(encoding="utf-8").count("\n")

    prompt = tmp_path / "prompt.md"
    prompt.write_text("do the thing", encoding="utf-8")

    def _must_not_spawn(*_args, **_kwargs):  # pragma: no cover - asserts by failing
        raise AssertionError("spawned despite an exhausted 5h window")

    monkeypatch.setattr(farmctl, "_resolve_codex", lambda: "codex.cmd")
    monkeypatch.setattr(farmctl, "spawn_managed_codex", _must_not_spawn)
    monkeypatch.setattr(farmctl, "_codex_env", dict)

    with pytest.raises(farmctl.CodexModelWindowRefused) as excinfo:
        farmctl._spawn_owned_codex(
            tmp_path,
            prompt,
            tmp_path / "live.log",
            purpose="build",
            dedupe_key="build:task-9",
            metadata={"task_id": "task-9"},
        )

    assert excinfo.value.refusal["reason"] == tiers.WINDOW_EXHAUSTED_REASON
    # The refusal is a ManagedCodexError, so every existing pump call site
    # already reports `spawned: False` instead of crashing the pump.
    assert isinstance(excinfo.value, farmctl.ManagedCodexError)
    assert farmctl._managed_spawn_failure_reason(excinfo.value) == tiers.WINDOW_EXHAUSTED_REASON
    assert ledger.read_text(encoding="utf-8").count("\n") == before


def test_unknown_payload_tier_refuses_at_every_spawn_site(tmp_path: Path) -> None:
    contract = quota_spawn_gate.codex_spawn_contract(
        "build_ea",
        {"codex_model_tier": "gpt-6-turbo"},
        task_id="task-unknown",
        now=NOW,
        ledger_path=tmp_path / "unknown.jsonl",
    )

    assert contract["allowed"] is False
    assert contract["refusal"]["reason"] == tiers.UNKNOWN_TIER_REASON
    assert contract["flags"] == []
    assert not (tmp_path / "unknown.jsonl").exists()


def test_astra_hold_is_a_refusal_at_the_spawn_site_too(tmp_path: Path) -> None:
    ledger = tmp_path / "astra.jsonl"
    matrix = _codex_matrix()
    budget = tiers.window_budget(
        matrix["tiers"]["astra"], tiers.plan_tier(matrix), tiers.safety_factor(matrix)
    )
    _saturate(ledger, "gpt-6-astra", budget)

    contract = quota_spawn_gate.codex_spawn_contract(
        "ops_issue",
        {"scalpel": True},
        task_id="task-astra",
        now=NOW,
        ledger_path=ledger,
    )

    assert contract["allowed"] is False
    assert contract["refusal"]["reason"] == tiers.WINDOW_EXHAUSTED_REASON
    assert contract["invocation"]["model_tier_hold"]["tier"] == "astra"
    # Hold never downgrades: no weaker model was booked.
    assert tiers.window_count("gpt-5.6-sol", now=NOW, path=ledger) == 0


# --- M1b: the tier is resolved from the TASK payload, not pump metadata -----


def test_pump_resolves_the_tier_from_the_stored_task_payload(
    tmp_path: Path, monkeypatch
) -> None:
    import farmctl  # noqa: PLC0415

    ledger = tmp_path / "payload_tier.jsonl"
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(ledger))
    prompt = tmp_path / "prompt.md"
    prompt.write_text("do the thing", encoding="utf-8")
    seen: dict = {}

    def _fake_spawn(root, command, **kwargs):
        seen["command"] = list(command)
        seen["metadata"] = dict(kwargs.get("metadata") or {})
        return object(), {"lease_id": "lease-1"}

    monkeypatch.setattr(farmctl, "_resolve_codex", lambda: "codex.cmd")
    monkeypatch.setattr(farmctl, "spawn_managed_codex", _fake_spawn)
    monkeypatch.setattr(farmctl, "_codex_env", dict)

    _proc, lease = farmctl._spawn_owned_codex(
        tmp_path,
        prompt,
        tmp_path / "live.log",
        purpose="build",
        dedupe_key="build:task-astra",
        metadata={"task_id": "task-astra", "ea_id": "QM5_10000"},
        task_payload={"codex_model_tier": "astra"},
    )

    command = seen["command"]
    assert command[command.index("-m") + 1] == "gpt-6-astra"
    assert seen["metadata"]["model_tier"] == "astra"
    assert lease["model_window_ledger"]["recorded"] is True
    assert tiers.window_count("gpt-6-astra", now=dt.datetime.now(dt.UTC), path=ledger) == 1


def test_pump_refunds_the_booked_message_when_the_launch_fails(
    tmp_path: Path, monkeypatch
) -> None:
    import farmctl  # noqa: PLC0415

    ledger = tmp_path / "refund.jsonl"
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(ledger))
    prompt = tmp_path / "prompt.md"
    prompt.write_text("do the thing", encoding="utf-8")

    def _boom(*_args, **_kwargs):
        raise farmctl.ManagedCodexError("registration failed")

    monkeypatch.setattr(farmctl, "_resolve_codex", lambda: "codex.cmd")
    monkeypatch.setattr(farmctl, "spawn_managed_codex", _boom)
    monkeypatch.setattr(farmctl, "_codex_env", dict)

    with pytest.raises(farmctl.ManagedCodexError):
        farmctl._spawn_owned_codex(
            tmp_path,
            prompt,
            tmp_path / "live.log",
            purpose="build",
            dedupe_key="build:task-x",
            metadata={"task_id": "task-x"},
        )

    now = dt.datetime.now(dt.UTC)
    assert tiers.window_count("gpt-5.6-terra", now=now, path=ledger) == 0
    kinds = [json.loads(line)["kind"] for line in ledger.read_text(encoding="utf-8").splitlines()]
    assert kinds == ["dispatch", "release"]


# --- M2: a tier with no usable model id must not validate -------------------


@pytest.mark.parametrize("model", ["", None, 7])
def test_a_tier_without_a_model_id_fails_validation(model) -> None:
    import copy  # noqa: PLC0415

    matrix = copy.deepcopy(_codex_matrix())
    matrix["tiers"]["terra"]["model"] = model

    error = tiers.validate_matrix(matrix)
    assert error is not None and error.startswith(tiers.MATRIX_INCOMPLETE)
    assert "terra_model_not_a_model_id" in error


def test_an_unknown_default_effort_fails_validation() -> None:
    import copy  # noqa: PLC0415

    matrix = copy.deepcopy(_codex_matrix())
    matrix["tiers"]["terra"]["default_reasoning_effort"] = "turbo"

    error = tiers.validate_matrix(matrix)
    assert error is not None
    assert "terra_default_reasoning_effort_unknown:turbo" in error


def test_a_model_less_tier_is_skipped_instead_of_dispatched_flagless(tmp_path: Path) -> None:
    matrix = copy.deepcopy(_codex_matrix())
    matrix["tiers"]["terra"]["model"] = ""

    selected = tiers.select_dispatch(
        matrix,
        {"codex_model_tier": "terra"},
        "build_ea",
        "high",
        now=NOW,
        path=tmp_path / "unusable.jsonl",
    )

    # It must NOT emit an empty model (silent account default, uncounted window).
    assert selected["model"] == "gpt-5.6-luna"
    assert selected["model_tier_downgraded_from"] == "terra"
    detail = {entry["tier"]: entry for entry in selected["model_tier_chain_detail"]}
    assert detail["terra"]["unusable"] == "model_id_missing"


# --- M3: budget arithmetic under repeated / concurrent booking --------------


def test_five_consecutive_bookings_cannot_exceed_the_astra_budget(tmp_path: Path) -> None:
    ledger = tmp_path / "astra_budget.jsonl"
    matrix = _codex_matrix()
    budget = tiers.window_budget(
        matrix["tiers"]["astra"], tiers.plan_tier(matrix), tiers.safety_factor(matrix)
    )
    assert budget == 2  # plus: floor(3 * 0.8)

    allowed = 0
    refused = 0
    for index in range(5):
        contract = quota_spawn_gate.codex_spawn_contract(
            "ops_issue",
            {"scalpel": True},
            task_id=f"astra-{index}",
            now=NOW,
            ledger_path=ledger,
        )
        if contract["allowed"]:
            allowed += 1
        else:
            refused += 1
            assert contract["refusal"]["reason"] == tiers.WINDOW_EXHAUSTED_REASON

    assert (allowed, refused) == (budget, 5 - budget)
    assert tiers.window_count("gpt-6-astra", now=NOW, path=ledger) == budget


def test_commit_is_the_choke_point_even_when_the_preview_said_yes(tmp_path: Path) -> None:
    # Two spawners preview the same free slot; only one may book it.
    ledger = tmp_path / "race.jsonl"
    matrix = _codex_matrix()
    budget = tiers.window_budget(
        matrix["tiers"]["astra"], tiers.plan_tier(matrix), tiers.safety_factor(matrix)
    )
    _saturate(ledger, "gpt-6-astra", budget - 1)

    preview_a = tiers.select_dispatch(matrix, {"scalpel": True}, "ops_issue", None, now=NOW, path=ledger)
    preview_b = tiers.select_dispatch(matrix, {"scalpel": True}, "ops_issue", None, now=NOW, path=ledger)
    assert preview_a["model"] == preview_b["model"] == "gpt-6-astra"

    first = tiers.commit_dispatch(
        task_id="a", chain=preview_a["model_tier_chain_detail"], path=ledger, now=NOW
    )
    second = tiers.commit_dispatch(
        task_id="b", chain=preview_b["model_tier_chain_detail"], path=ledger, now=NOW
    )

    assert first["recorded"] is True
    assert second["recorded"] is False
    assert second["reason"] == tiers.WINDOW_EXHAUSTED_REASON
    assert tiers.window_count("gpt-6-astra", now=NOW, path=ledger) == budget


def test_commit_lands_one_tier_lower_when_the_preferred_model_filled_up(
    tmp_path: Path,
) -> None:
    ledger = tmp_path / "late_fill.jsonl"
    matrix = _codex_matrix()
    plan = tiers.plan_tier(matrix)
    factor = tiers.safety_factor(matrix)
    preview = tiers.select_dispatch(
        matrix, {"codex_model_tier": "terra"}, "build_ea", "high", now=NOW, path=ledger
    )
    assert preview["model"] == "gpt-5.6-terra"

    # terra fills between preview and commit.
    _saturate(ledger, "gpt-5.6-terra", tiers.window_budget(matrix["tiers"]["terra"], plan, factor))

    booked = tiers.commit_dispatch(
        task_id="late", chain=preview["model_tier_chain_detail"], path=ledger, now=NOW
    )

    assert booked["recorded"] is True
    assert booked["model"] == "gpt-5.6-luna"
    assert booked["downgraded_from"] == "terra"


# --- M4: a malformed decision-bound pin must fail closed --------------------


@pytest.mark.parametrize("raw", [["claude"], {"agent": "claude"}, 1, True])
def test_a_malformed_pin_holds_the_row_instead_of_unpinning_it(tmp_path: Path, raw) -> None:
    task = agent_router.enqueue_task(
        tmp_path,
        "ops_issue",
        state="TODO",
        priority=50,
        payload={"decision_bound_agent": raw},
    )

    pin = agent_router.decision_bound_pin({"decision_bound_agent": raw})
    assert pin["invalid"] is True
    assert agent_router.decision_bound_agent({"decision_bound_agent": raw}) == (
        agent_router.DECISION_BOUND_INVALID
    )

    decision = agent_router.route_once(tmp_path, claude_disabled_flag=tmp_path / "missing.flag")
    assert decision.assigned_agent is None
    assert decision.reason == (
        f"awaiting_decision_bound_agent:{agent_router.DECISION_BOUND_INVALID}"
    )
    stored = agent_router.list_tasks(tmp_path, state="TODO")[0]
    assert stored["id"] == task["task_id"]
    hold = stored["payload"]["router_decision_bound_hold"]
    assert hold["invalid_pin"] is True


@pytest.mark.parametrize("raw", [0, False, None, ""])
def test_owner_decision_pins_on_key_presence(raw) -> None:
    assert agent_router.decision_bound_agent({"owner_decision": raw}) == "claude"


# --- L2 / L4 / L5 / L6 ------------------------------------------------------


def test_a_torn_ledger_line_is_reported_not_swallowed(tmp_path: Path) -> None:
    ledger = tmp_path / "torn.jsonl"
    _saturate(ledger, "gpt-5.6-terra", 1)
    with ledger.open("a", encoding="utf-8") as handle:
        handle.write('{"ts": "2026-09-04T11:5\n')

    scan = tiers.scan_window("gpt-5.6-terra", now=NOW, path=ledger)
    # CEO decision D4: the torn line is COUNTED as a consumed message as well
    # as reported, so a partial write can never hand budget back.
    assert scan["count"] == 2
    assert scan["integrity"]["corrupt_lines"] == 1
    assert scan["integrity"]["counted_corrupt_lines"] == 1

    selected = tiers.select_dispatch(
        _codex_matrix(),
        {"codex_model_tier": "terra"},
        "build_ea",
        "high",
        now=NOW,
        path=ledger,
    )
    assert selected["model_window"]["ledger_integrity"]["corrupt_lines"] == 1
    assert selected["model_tier_ledger_integrity"]["corrupt_lines"] == 1


def test_a_fallback_cycle_fails_validation_instead_of_truncating_the_chain() -> None:
    matrix = copy.deepcopy(_codex_matrix())
    matrix["tiers"]["terra"]["fallback_tier"] = "sol"

    error = tiers.validate_matrix(matrix)
    assert error is not None
    assert "fallback_cycle" in error


def test_the_scalpel_task_type_can_be_enqueued(tmp_path: Path) -> None:
    task = agent_router.enqueue_task(
        tmp_path, "strategy_mechanize_source", state="TODO", priority=70
    )

    stored = agent_router.list_tasks(tmp_path, state="TODO")[0]
    assert stored["id"] == task["task_id"]
    with agent_router.connect(tmp_path) as conn:
        row = conn.execute(
            "SELECT required_capabilities_json FROM agent_tasks WHERE id=?",
            (task["task_id"],),
        ).fetchone()
    assert json.loads(row["required_capabilities_json"]) == ["research", "strategy"]
    resolution = tiers.resolve_tier(_codex_matrix(), {}, "strategy_mechanize_source", "high")
    assert resolution["tier"] == "astra"


def test_lane_candidates_apply_the_same_payload_capability_union(
    tmp_path: Path, monkeypatch
) -> None:
    agent_router.sync_default_registry(tmp_path, claude_disabled_flag=tmp_path / "missing.flag")
    task = agent_router.enqueue_task(tmp_path, "ops_issue", state="TODO", priority=95)
    # Simulate a row written outside enqueue_task (the asymmetric case): the
    # column keeps the task-type defaults, the payload declares more.
    with agent_router.connect(tmp_path) as conn:
        conn.execute(
            "UPDATE agent_tasks SET payload_json=? WHERE id=?",
            (json.dumps({"required_capabilities": ["summary"]}), task["task_id"]),
        )
        conn.commit()

    monkeypatch.setattr(orchestration, "FARM_ROOT", tmp_path)
    codex_candidates, status = orchestration._quota_lane_candidates("codex")
    assert status == "ok"
    assert [candidate["task_id"] for candidate in codex_candidates] == []

    claude_candidates, status = orchestration._quota_lane_candidates("claude")
    assert status == "ok"
    assert task["task_id"] in [candidate["task_id"] for candidate in claude_candidates]


# ===========================================================================
# Round 3, 2026-09-04 - the seven CEO decisions, one test block each.
# ===========================================================================


# --- D2: the rollback restores the EXACT pre-patch argv at EVERY site -------


def test_rollback_restores_the_pump_spawn_argv(tmp_path: Path, monkeypatch) -> None:
    """farmctl._spawn_owned_codex under QM_CODEX_MODEL_TIERS=0."""
    import farmctl  # noqa: PLC0415

    monkeypatch.setenv(tiers.TIERS_ENV, "0")
    ledger = tmp_path / "rollback_pump.jsonl"
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(ledger))
    prompt = tmp_path / "prompt.md"
    prompt.write_text("do the thing", encoding="utf-8")
    seen: dict = {}

    def _fake_spawn(root, command, **kwargs):
        seen["command"] = list(command)
        return object(), {"lease_id": "lease-1"}

    monkeypatch.setattr(farmctl, "_resolve_codex", lambda: "codex.cmd")
    monkeypatch.setattr(farmctl, "spawn_managed_codex", _fake_spawn)
    monkeypatch.setattr(farmctl, "_codex_env", dict)

    farmctl._spawn_owned_codex(
        tmp_path,
        prompt,
        tmp_path / "live.log",
        purpose="build",
        dedupe_key="build:task-9",
        metadata={"task_id": "task-9"},
    )

    assert seen["command"] == [
        "codex.cmd",
        "exec",
        "-s",
        "danger-full-access",
        "--cd",
        str(farmctl.REPO_ROOT),
    ]
    assert not ledger.exists()


def test_rollback_restores_the_fleet_pacer_argv(tmp_path: Path, monkeypatch) -> None:
    """codex_fleet_pacer._spawn_agent under QM_CODEX_MODEL_TIERS=0."""
    import codex_fleet_pacer as pacer  # noqa: PLC0415

    monkeypatch.setenv(tiers.TIERS_ENV, "0")
    ledger = tmp_path / "rollback_pacer.jsonl"
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(ledger))
    prompt_dir = tmp_path / "prompts"
    prompt_dir.mkdir()
    (prompt_dir / "agent.md").write_text("work", encoding="utf-8")
    seen: dict = {}

    class _Proc:
        pid = 4242

    def _fake_spawn(root, command, **kwargs):
        seen["command"] = list(command)
        return _Proc(), {"lease_id": "lease-1"}

    monkeypatch.setattr(pacer, "PROMPT_DIR", prompt_dir)
    monkeypatch.setattr(pacer, "LOG_DIR", tmp_path / "logs")
    monkeypatch.setattr(pacer, "_acquire_spawn_lock", lambda: object())
    monkeypatch.setattr(pacer, "_release_spawn_lock", lambda lock: None)
    monkeypatch.setattr(pacer, "_resolve_codex", lambda: "codex.cmd")
    monkeypatch.setattr(pacer, "_log", lambda msg: None)
    monkeypatch.setattr(pacer, "spawn_managed_codex", _fake_spawn)

    assert pacer._spawn_agent("agent.md") == 4242
    assert seen["command"] == [
        "codex.cmd",
        "exec",
        "-s",
        "danger-full-access",
        "--cd",
        str(pacer.REPO_ROOT),
    ]
    assert not ledger.exists()


def test_rollback_restores_the_mailbox_intake_argv(tmp_path: Path, monkeypatch) -> None:
    """mailbox_source_intake.dispatch_analyst under QM_CODEX_MODEL_TIERS=0.

    This site's pre-doctrine argv was NOT flag-free: it hardcoded
    `-m gpt-5.6-sol -c model_reasoning_effort=high` (unquoted) after --cd.
    """
    import mailbox_source_intake as mailbox  # noqa: PLC0415

    monkeypatch.setenv(tiers.TIERS_ENV, "0")
    ledger = tmp_path / "rollback_mailbox.jsonl"
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(ledger))
    codex = tmp_path / "codex.cmd"
    codex.write_text("@exit /b 0", encoding="utf-8")
    seen: dict = {}

    class _Proc:
        pid = 99

        @staticmethod
        def wait(timeout):
            return 0

    def _fake_spawn(root, command, **kwargs):
        seen["command"] = list(command)
        return _Proc(), {"lease_id": "lease-1"}

    monkeypatch.setattr(mailbox, "CODEX_CMD", str(codex))
    monkeypatch.setattr(mailbox, "PROMPT_OUT_DIR", tmp_path / "prompts")
    monkeypatch.setattr(mailbox, "FARM_ROOT", tmp_path / "farm")
    monkeypatch.setattr(mailbox, "active_managed_codex_count", lambda root: 0)
    monkeypatch.setattr(
        mailbox, "release_managed_codex_process", lambda root, lease_id: True
    )
    monkeypatch.setattr(mailbox, "spawn_managed_codex", _fake_spawn)

    mailbox.dispatch_analyst("prompt")

    assert seen["command"] == [
        str(codex),
        "exec",
        "-s",
        "danger-full-access",
        "--cd",
        str(mailbox.REPO_ROOT),
        "-m",
        "gpt-5.6-sol",
        "-c",
        "model_reasoning_effort=high",
    ]
    assert not ledger.exists()


def test_rollback_restores_the_rendered_build_command(tmp_path: Path, monkeypatch) -> None:
    """farmctl._codex_dispatch_model_args / render_codex_build_prompt."""
    import farmctl  # noqa: PLC0415

    monkeypatch.setenv(tiers.TIERS_ENV, "0")
    ledger = tmp_path / "rollback_render.jsonl"
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(ledger))

    model_args, effort_args, contract = farmctl._codex_dispatch_model_args("build_ea", {})

    assert (model_args, effort_args) == ("", "")
    assert contract["allowed"] is True
    assert contract["flags"] == []
    assert contract["ledger"]["reason"] == "codex_model_tiers_disabled"
    assert not ledger.exists()


# --- D3: book first, render second -----------------------------------------


def _slot_harness(tmp_path: Path, monkeypatch) -> None:
    """Minimal fakes so `run_agent_slot` can run without touching live state."""
    monkeypatch.setattr(orchestration, "LOG_DIR", tmp_path / "logs")
    monkeypatch.setattr(orchestration, "FARM_ROOT", tmp_path / "farm")
    monkeypatch.setattr(orchestration, "resolve_cli", lambda agent: f"{agent}.cmd")
    monkeypatch.setattr(orchestration, "_CODEX_MODEL_ENV_OVERRIDE", "")
    monkeypatch.setattr(orchestration, "build_prompt", lambda agent, cwd: "prompt")
    monkeypatch.setattr(
        orchestration,
        "ensure_worktree",
        lambda agent, slot: {"path": str(tmp_path), "shared_repo": True},
    )
    monkeypatch.setattr(
        orchestration, "acquire_lock", lambda agent, stale, slot=0: (True, {"slot": slot})
    )
    monkeypatch.setattr(orchestration, "release_lock", lambda info: None)
    monkeypatch.setattr(orchestration, "_write_lane_heartbeat", lambda agent, slot=0: None)
    monkeypatch.setattr(orchestration, "agent_env", lambda agent: {})
    monkeypatch.setattr(
        orchestration, "release_managed_codex_process", lambda root, lease_id: True
    )

    class _Proc:
        pid = 777

        @staticmethod
        def wait(timeout=None):
            return 0

    monkeypatch.setattr(
        orchestration,
        "spawn_managed_codex",
        lambda root, command, **kwargs: (_Proc(), {"lease_id": "lease-slot"}),
    )


def test_run_agent_slot_renders_the_committed_tier_not_the_preview(
    tmp_path: Path, monkeypatch
) -> None:
    """CEO decision D3: a commit that lands one tier LOWER drives the argv.

    Round 2 measured the defect end-to-end: the argv was frozen from the
    preview (`gpt-5.6-terra`) while the commit booked the fallback, so the
    process ran the preview model over its budget and the fallback tier was
    charged a message it never spent.
    """
    ledger = tmp_path / "committed.jsonl"
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(ledger))
    _slot_harness(tmp_path, monkeypatch)
    matrix = _codex_matrix()
    now = dt.datetime.now(dt.UTC)
    preview = tiers.select_dispatch(
        matrix, {"codex_model_tier": "terra"}, "build_ea", "high", now=now, path=ledger
    )
    assert preview["model"] == "gpt-5.6-terra"

    # terra fills between the preview and the spawn.
    _saturate(
        ledger,
        "gpt-5.6-terra",
        tiers.window_budget(matrix["tiers"]["terra"], tiers.plan_tier(matrix), tiers.safety_factor(matrix)),
        now=now,
    )

    payload = orchestration.run_agent_slot(
        "codex",
        0,
        dry_run=False,
        stale_minutes=60,
        timeout_minutes=1,
        invocation_profile=dict(preview, task_id="slot-task"),
    )

    booked = payload["model_window_ledger"]
    assert booked["recorded"] is True
    assert booked["model"] == "gpt-5.6-luna"
    assert booked["downgraded_from"] == "terra"
    command = payload["command"]
    assert command[command.index("-m") + 1] == "gpt-5.6-luna"
    assert payload["model_contract"]["model_tier"] == "luna"
    assert payload["model_contract"]["model_tier_downgraded_from"] == "terra"
    charged = [
        json.loads(line)
        for line in ledger.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    assert [record["model"] for record in charged if record.get("task_id") == "slot-task"] == [
        "gpt-5.6-luna"
    ]


def test_command_for_renders_no_model_flag_for_a_refused_contract(tmp_path: Path) -> None:
    """CEO decision D3: a refused contract yields no argv at all."""
    refused = {
        "model": "gpt-6-astra",
        "reasoning_effort": "max",
        "model_tier": "astra",
        "model_tier_refused": True,
    }
    assert orchestration.command_for("codex", tmp_path, model_contract=refused) is None


# --- D4: ledger I/O fails CLOSED in both directions ------------------------


def test_an_unreadable_ledger_refuses_instead_of_regranting_the_budget(
    tmp_path: Path, monkeypatch
) -> None:
    ledger = tmp_path / "unreadable.jsonl"
    _break_ledger_read(monkeypatch)

    committed = tiers.record_dispatch(
        task_id="t",
        tier="sol",
        model="gpt-5.6-sol",
        path=ledger,
        now=NOW,
        codex_matrix=_codex_matrix(),
    )
    assert committed["recorded"] is False
    assert committed["reason"] == tiers.LEDGER_READ_ERROR_REASON

    previewed = tiers.select_dispatch(
        _codex_matrix(), {}, "build_ea", "high", now=NOW, path=ledger
    )
    assert previewed["model_tier_refusal"]["code"] == tiers.LEDGER_READ_ERROR_REASON

    contract = quota_spawn_gate.codex_spawn_contract(
        "build_ea", {}, task_id="t", now=NOW, ledger_path=ledger
    )
    assert contract["allowed"] is False
    assert contract["flags"] == []
    assert contract["refusal"]["reason"] == tiers.LEDGER_READ_ERROR_REASON


def test_an_unwritable_ledger_refuses_instead_of_dispatching_uncounted(
    tmp_path: Path, monkeypatch
) -> None:
    ledger = tmp_path / "unwritable.jsonl"
    _break_ledger_write(monkeypatch)

    contract = quota_spawn_gate.codex_spawn_contract(
        "build_ea", {}, task_id="t", now=NOW, ledger_path=ledger
    )

    assert contract["allowed"] is False
    assert contract["flags"] == []
    assert contract["refusal"]["reason"].startswith(tiers.LEDGER_WRITE_ERROR_REASON)


def test_an_unresolvable_policy_refuses_instead_of_dispatching_uncounted(
    tmp_path: Path,
) -> None:
    missing = tmp_path / "no_policy.json"

    booked = quota_spawn_gate.record_codex_dispatch(
        task_id="t",
        contract={"model": "gpt-5.6-sol", "model_tier": "sol"},
        config_path=missing,
        ledger_path=tmp_path / "policy.jsonl",
        now=NOW,
    )
    assert booked["recorded"] is False
    assert str(booked["reason"]).startswith("policy_unavailable")

    contract = quota_spawn_gate.codex_spawn_contract(
        "build_ea", {}, task_id="t", config_path=missing, now=NOW
    )
    assert contract["allowed"] is False
    assert contract["flags"] == []


def test_an_astra_hold_survives_an_unreadable_ledger(tmp_path: Path, monkeypatch) -> None:
    """The scalpel hold must not evaporate when the ledger cannot be read."""
    _break_ledger_read(monkeypatch)

    contract = quota_spawn_gate.codex_spawn_contract(
        "ops_issue",
        {"scalpel": True},
        task_id="t",
        now=NOW,
        ledger_path=tmp_path / "unreadable.jsonl",
    )

    assert contract["allowed"] is False
    assert contract["flags"] == []


# --- D5: strict markers -----------------------------------------------------


@pytest.mark.parametrize("raw", ["true", "True", 1, "yes", 0, "false", ["x"]])
def test_a_non_boolean_scalpel_marker_is_invalid_and_never_downgrades(
    tmp_path: Path, raw
) -> None:
    resolution = tiers.resolve_tier(_codex_matrix(), {"scalpel": raw}, "ops_issue", "high")
    assert resolution["tier"] is None
    assert resolution["error"]["code"] == tiers.INVALID_SCALPEL_REASON

    selected = tiers.select_dispatch(
        _codex_matrix(), {"scalpel": raw}, "ops_issue", "high", now=NOW, path=tmp_path / "l.jsonl"
    )
    assert selected["model_tier_hold"]["route_reason"] == tiers.INVALID_SCALPEL_REASON

    decision = quota_spawn_gate.evaluate_spawn(
        "codex",
        "ops_issue",
        50,
        state_path=tmp_path / "governor.json",
        summary_path=tmp_path / "summary.json",
        payload={"scalpel": raw},
        now=NOW,
    )
    assert decision["allowed"] is False
    assert decision["reason"] == tiers.INVALID_SCALPEL_REASON


def test_router_holds_an_invalid_scalpel_marker_with_its_own_reason(
    tmp_path: Path, monkeypatch
) -> None:
    now = dt.datetime.now(dt.UTC).replace(microsecond=0)
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(tmp_path / "window.jsonl"))
    state_path = tmp_path / "governor.json"
    state_path.write_text(
        json.dumps(
            {
                "ts": now.isoformat(),
                "agents": {
                    agent: {"used_pct": 10, "elapsed_pct": 50, "five_hour_used_pct": 5}
                    for agent in ("codex", "claude")
                },
            }
        ),
        encoding="utf-8",
    )
    task = agent_router.enqueue_task(
        tmp_path,
        "ops_issue",
        state="TODO",
        priority=50,
        required_capabilities=["ops", "code"],
        payload={"scalpel": "true"},
        assigned_agent="codex",
    )

    routed = agent_router.route_once(
        tmp_path,
        claude_disabled_flag=tmp_path / "missing.flag",
        quota_gate_enabled=True,
        quota_state_path=state_path,
        quota_summary_path=tmp_path / "summary.json",
    )

    # NOT `awaiting_model_window:astra`: this is a malformed marker, not a
    # spent budget.
    assert routed.reason == tiers.INVALID_SCALPEL_REASON
    assert routed.assigned_agent is None
    held = agent_router.list_tasks(tmp_path, state="TODO")[0]
    assert held["id"] == task["task_id"]
    assert held["payload"]["router_model_window_hold"]["code"] == (
        tiers.HOLD_CODE_INVALID_SCALPEL
    )


@pytest.mark.parametrize("raw", [True, False, None])
def test_a_json_boolean_or_absent_scalpel_marker_is_valid(raw) -> None:
    resolution = tiers.resolve_tier(_codex_matrix(), {"scalpel": raw}, "ops_issue", "max")
    assert resolution["error"] is None
    assert resolution["tier"] == ("astra" if raw is True else "sol")


def test_an_explicit_null_pin_is_unpinned_unless_a_decision_receipt_is_present(
    tmp_path: Path,
) -> None:
    """CEO decision D5: JSON null = unset; null + owner_decision = claude."""
    assert agent_router.decision_bound_agent({"decision_bound_agent": None}) is None
    assert (
        agent_router.decision_bound_agent(
            {"decision_bound_agent": None, "owner_decision": "OWNER-DEC-1"}
        )
        == "claude"
    )

    agent_router.enqueue_task(
        tmp_path,
        "ops_issue",
        state="TODO",
        priority=50,
        payload={"decision_bound_agent": None},
    )
    routed = agent_router.route_once(tmp_path, claude_disabled_flag=tmp_path / "missing.flag")
    assert routed.assigned_agent == "codex"


# --- D6: the window arithmetic knobs are validated -------------------------


@pytest.mark.parametrize(
    ("field", "value", "fragment"),
    [
        ("five_hour_window_minutes", 1, "five_hour_window_minutes_out_of_range"),
        ("five_hour_window_minutes", 5, "five_hour_window_minutes_out_of_range"),
        ("five_hour_window_minutes", 2000, "five_hour_window_minutes_out_of_range"),
        ("five_hour_window_minutes", "abc", "five_hour_window_minutes_not_a_number"),
        ("window_safety_factor", 5.0, "window_safety_factor_out_of_range"),
        ("window_safety_factor", 0.05, "window_safety_factor_out_of_range"),
        ("window_safety_factor", "abc", "window_safety_factor_not_a_number"),
        ("effort_class_tier_mapping_enabled", "true", "not_a_bool"),
    ],
)
def test_window_knobs_fail_closed(field, value, fragment) -> None:
    matrix = copy.deepcopy(_codex_matrix())
    matrix[field] = value

    error = tiers.validate_matrix(matrix)

    assert error is not None
    assert error.startswith(tiers.MATRIX_INCOMPLETE)
    assert fragment in error


def test_an_out_of_range_window_blocks_the_whole_policy(tmp_path: Path) -> None:
    policy = _policy()
    policy["model_matrix"]["codex"]["five_hour_window_minutes"] = 5
    config_path = tmp_path / "policy.json"
    config_path.write_text(json.dumps(policy), encoding="utf-8")

    loaded, error = quota_spawn_gate.load_policy(config_path)

    assert loaded is None
    assert "five_hour_window_minutes_out_of_range" in str(error)


def test_the_shipped_window_knobs_are_in_range() -> None:
    codex = _codex_matrix()

    assert tiers.window_minutes(codex) == 300.0
    assert tiers.safety_factor(codex) == 0.8
    assert tiers.effort_class_tier_mapping_enabled(codex) is False
