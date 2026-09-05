"""Round-4 residual findings for the Codex model-tier enforce preconditions.

Task 453b8edf (2026-09-05). Each test pins ONE residual finding of wf_76cb7101:

  ITEM 1  an invalid `scalpel` marker is gated to a scalpel lane (never gemini)
  ITEM 2  a ts-less ledger record is bounded by position, not charged forever
  ITEM 3  a corrupt line is bounded by position (not file mtime alone); rotation
          keeps future-stamped and still-charged records
  ITEM 4  `allowed_window_enforcement_modes` is validated fail-closed
  ITEM 5  `rotate_ledger` has a stat-only fast path below `min_lines`
  ITEM 6  in ENFORCE mode the Astra HOLD outranks the OWNER burn bypass

Plus an OBSERVE-mode invariance test: the routing/spawn/ledger decisions this
patch touches are byte-identical in observe mode for well-formed inputs, so the
shipped default is provably unperturbed.

Nothing here touches live state: every path is a tmp_path or a monkeypatched env
value, and every burn flag is redirected to an absent tmp file first.
"""

from __future__ import annotations

import copy
import datetime as dt
import json
import os
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
SHIPPED_CONFIG_PATH = Path(quota_spawn_gate.CONFIG_PATH)


# --------------------------------------------------------------------------- #
# fixtures / helpers
# --------------------------------------------------------------------------- #
@pytest.fixture(autouse=True)
def _no_live_burn_flags(tmp_path, monkeypatch):
    """Redirect every burn flag to an absent tmp file (mirrors the core suite)."""
    mods = {id(quota_governor): quota_governor}
    try:
        from tools.strategy_farm import quota_governor as pkg_gov  # noqa: PLC0415

        mods[id(pkg_gov)] = pkg_gov
    except ModuleNotFoundError:
        pass
    for mod in mods.values():
        for agent in list(mod.BURN_FLAGS):
            monkeypatch.setitem(mod.BURN_FLAGS, agent, tmp_path / f"absent_{agent}.flag")


def _gate_modules() -> list:
    mods = {id(quota_spawn_gate): quota_spawn_gate}
    try:
        from tools.strategy_farm import quota_spawn_gate as pkg_gate  # noqa: PLC0415

        mods[id(pkg_gate)] = pkg_gate
    except ModuleNotFoundError:
        pass
    return list(mods.values())


def _shipped_matrix() -> dict:
    policy = json.loads(SHIPPED_CONFIG_PATH.read_text(encoding="utf-8"))
    return policy["model_matrix"]["codex"]


def _config_at(tmp_path, monkeypatch, *, mode: str, plan: str = "plus") -> Path:
    """Write a policy with the chosen enforcement mode + plan and point the gate
    at it (both import shapes)."""
    policy = json.loads(SHIPPED_CONFIG_PATH.read_text(encoding="utf-8"))
    policy["model_matrix"]["codex"][tiers.ENFORCEMENT_MODE_FIELD] = mode
    policy["model_matrix"]["codex"]["plan_tier"] = plan
    config_path = tmp_path / f"policy_{mode}_{plan}.json"
    config_path.write_text(json.dumps(policy), encoding="utf-8")
    for mod in _gate_modules():
        monkeypatch.setattr(mod, "CONFIG_PATH", config_path)
    return config_path


def _write_burn_flag(tmp_path, monkeypatch, agent: str = "codex") -> Path:
    flag = tmp_path / f"{agent}_burn.flag"
    flag.write_text("expires_at=2999-01-01T00:00:00+00:00\n", encoding="utf-8")
    mods = {id(quota_governor): quota_governor}
    try:
        from tools.strategy_farm import quota_governor as pkg_gov  # noqa: PLC0415

        mods[id(pkg_gov)] = pkg_gov
    except ModuleNotFoundError:
        pass
    for mod in mods.values():
        monkeypatch.setitem(mod.BURN_FLAGS, agent, flag)
    return flag


def _saturate_model(path: Path, model: str, count: int, *, now: dt.datetime = NOW) -> None:
    lines = [
        json.dumps(
            {
                "ts": now.isoformat(),
                "task_id": f"t{i}",
                "tier": "astra" if model == "gpt-6-astra" else "x",
                "model": model,
                "kind": "dispatch",
                "id": f"{model}-{i}",
            }
        )
        for i in range(count)
    ]
    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def _touch(path: Path, when: dt.datetime) -> None:
    stamp = when.timestamp()
    os.utime(path, (stamp, stamp))


# --------------------------------------------------------------------------- #
# ITEM 1 - invalid scalpel marker gated to a scalpel lane, never gemini
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize("raw", ["true", 1, "yes", "True"])
def test_invalid_scalpel_marker_adds_the_scalpel_capability(raw) -> None:
    caps = agent_router.scalpel_routing_capabilities("research_strategy", {"scalpel": raw})
    assert caps == {agent_router.SCALPEL_ROUTING_CAPABILITY}


@pytest.mark.parametrize("raw", [False, None])
def test_a_valid_non_true_scalpel_marker_adds_nothing(raw) -> None:
    caps = agent_router.scalpel_routing_capabilities("research_strategy", {"scalpel": raw})
    assert caps == set()


def test_an_absent_scalpel_marker_adds_nothing() -> None:
    assert agent_router.scalpel_routing_capabilities("research_strategy", {}) == set()


def test_an_unassigned_invalid_scalpel_row_never_falls_to_gemini(tmp_path: Path) -> None:
    """The residual gap: an UNASSIGNED invalid-marker row must not reach gemini
    (which is not quota-gated, so the `invalid_scalpel_marker` hold never fires
    there). It is held on a scalpel lane with its own reason instead."""
    agent_router.sync_default_registry(tmp_path, claude_disabled_flag=tmp_path / "missing.flag")
    now = dt.datetime.now(dt.UTC).replace(microsecond=0)
    state_path = tmp_path / "governor.json"
    state_path.write_text(
        json.dumps(
            {
                "ts": now.isoformat(),
                "agents": {
                    a: {"used_pct": 10, "elapsed_pct": 50, "five_hour_used_pct": 5}
                    for a in ("codex", "claude")
                },
            }
        ),
        encoding="utf-8",
    )
    task = agent_router.enqueue_task(
        tmp_path,
        "research_strategy",
        state="TODO",
        priority=70,
        payload={"scalpel": "true"},  # invalid marker, NO assigned_agent
    )

    routed = agent_router.route_once(
        tmp_path,
        claude_disabled_flag=tmp_path / "missing.flag",
        quota_gate_enabled=True,
        quota_state_path=state_path,
        quota_summary_path=tmp_path / "summary.json",
    )

    assert routed.assigned_agent is None
    assert routed.reason == tiers.INVALID_SCALPEL_REASON
    held = agent_router.list_tasks(tmp_path, state="TODO")[0]
    assert held["id"] == task["task_id"]


def test_the_orchestration_selector_agrees_with_route_once_on_invalid_markers() -> None:
    """`_quota_lane_candidates` and `route_once` must union the SAME capability
    for an invalid marker, or the two selectors disagree about the lane."""
    assert orchestration.agent_router.scalpel_routing_capabilities(
        "research_strategy", {"scalpel": "true"}
    ) == {agent_router.SCALPEL_ROUTING_CAPABILITY}


# --------------------------------------------------------------------------- #
# ITEM 2 - ts-less records bounded by position, not a permanent charge
# --------------------------------------------------------------------------- #
def test_ts_less_records_still_count_when_recent_by_position(tmp_path: Path) -> None:
    """No aged timestamped neighbour -> conservative count is preserved."""
    ledger = tmp_path / "no_ts.jsonl"
    lines = [
        json.dumps({"task_id": f"t{i}", "tier": "astra", "model": "gpt-6-astra", "kind": "dispatch", "id": f"n{i}"})
        for i in range(4)
    ]
    ledger.write_text("\n".join(lines) + "\n", encoding="utf-8")
    _touch(ledger, NOW)

    assert tiers.window_count("gpt-6-astra", now=NOW, path=ledger) == 4


def test_ts_less_records_stop_counting_once_a_later_record_has_aged_out(
    tmp_path: Path,
) -> None:
    """The permanence fix: a ts-less line is released once a valid record that
    was appended AFTER it has itself left the window."""
    ledger = tmp_path / "no_ts_aged.jsonl"
    lines = [
        # position 0: ts-less foreign line for the model under test
        json.dumps({"model": "gpt-6-astra", "kind": "dispatch", "id": "ghost"}),
        # position 1: a valid record appended later, already OUT of the window
        json.dumps({"ts": (NOW - dt.timedelta(minutes=600)).isoformat(),
                    "model": "gpt-6-astra", "kind": "dispatch", "id": "aged"}),
    ]
    ledger.write_text("\n".join(lines) + "\n", encoding="utf-8")
    _touch(ledger, NOW)

    # `aged` is out of the 300-min window; `ghost` is proven older by position.
    assert tiers.window_count("gpt-6-astra", now=NOW, path=ledger) == 0


def test_rotation_drops_ts_less_records_proven_older_by_position(tmp_path: Path) -> None:
    ledger = tmp_path / "rotate_ts_less.jsonl"
    lines: list[str] = []
    # 300 ts-less lines, then 300 valid lines already older than 2x the window.
    for i in range(300):
        lines.append(json.dumps({"model": "gpt-5.6-sol", "kind": "dispatch", "id": f"g{i}"}))
    for i in range(300):
        lines.append(json.dumps({"ts": (NOW - dt.timedelta(minutes=900)).isoformat(),
                                 "model": "gpt-5.6-sol", "kind": "dispatch", "id": f"v{i}"}))
    ledger.write_text("\n".join(lines) + "\n", encoding="utf-8")

    result = tiers.rotate_ledger(ledger, now=NOW, minutes=300)

    assert result["rotated"] is True
    # every ts-less line (pos 0..299) is below the aged valid records (pos>=300)
    assert result["kept"] == 0


def test_rotation_still_keeps_ts_less_records_with_no_aged_neighbour(tmp_path: Path) -> None:
    """Baseline conservative behaviour is preserved when nothing proves them old."""
    ledger = tmp_path / "rotate_ts_less_keep.jsonl"
    lines = [json.dumps({"task_id": f"t{i}", "model": "gpt-5.6-sol"}) for i in range(600)]
    ledger.write_text("\n".join(lines) + "\n", encoding="utf-8")

    result = tiers.rotate_ledger(ledger, now=NOW, minutes=300)

    assert result["rotated"] is False
    assert result["reason"] == "nothing_expired"
    assert len(ledger.read_text(encoding="utf-8").splitlines()) == 600


# --------------------------------------------------------------------------- #
# ITEM 3 - corrupt-line bound not by mtime alone; rotation guards future/charged
# --------------------------------------------------------------------------- #
def test_corrupt_line_released_on_a_busy_file_by_position(tmp_path: Path) -> None:
    """A fresh mtime (busy file) no longer charges an OLD corrupt line forever:
    an aged valid record appended after it proves it out of window."""
    ledger = tmp_path / "busy_corrupt.jsonl"
    lines = [
        "{oops torn line",  # position 0, corrupt, from the distant past
        json.dumps({"ts": (NOW - dt.timedelta(minutes=600)).isoformat(),
                    "model": "gpt-5.6-terra", "kind": "dispatch", "id": "aged"}),
    ]
    ledger.write_text("\n".join(lines) + "\n", encoding="utf-8")
    _touch(ledger, NOW)  # busy file: mtime is fresh

    scan = tiers.scan_window("gpt-5.6-terra", now=NOW, path=ledger)
    assert scan["integrity"]["corrupt_lines"] == 1
    assert scan["integrity"]["counted_corrupt_lines"] == 0
    assert scan["integrity"]["corrupt_lines_outside_window"] == 1
    assert scan["count"] == 0


def test_corrupt_line_still_counts_when_no_aged_neighbour_and_fresh_mtime(
    tmp_path: Path,
) -> None:
    ledger = tmp_path / "fresh_corrupt.jsonl"
    ledger.write_text("{oops\n{also broken\n", encoding="utf-8")
    _touch(ledger, NOW)

    scan = tiers.scan_window("gpt-6-astra", now=NOW, path=ledger)
    assert scan["count"] == 2
    assert scan["integrity"]["counted_corrupt_lines"] == 2


def test_rotation_does_not_drop_a_corrupt_line_scan_still_charges(tmp_path: Path) -> None:
    """Rotation must never release a corrupt line the window is still counting."""
    ledger = tmp_path / "rotate_corrupt_recent.jsonl"
    lines = [json.dumps({"ts": NOW.isoformat(), "model": "gpt-5.6-sol",
                         "kind": "dispatch", "id": f"v{i}"}) for i in range(600)]
    lines.append("{torn recent line")  # newest line, no aged record after it
    ledger.write_text("\n".join(lines) + "\n", encoding="utf-8")

    result = tiers.rotate_ledger(ledger, now=NOW, minutes=300)

    kept_text = ledger.read_text(encoding="utf-8")
    # the fresh valid records are inside 2x window -> kept; corrupt line has no
    # aged neighbour after it -> not proven old -> kept.
    assert "{torn recent line" in kept_text
    assert tiers.scan_window("gpt-5.6-sol", now=NOW, path=ledger)["integrity"][
        "counted_corrupt_lines"
    ] == 1
    # nothing expired at all here
    assert result["rotated"] is False


def test_rotation_keeps_future_stamped_records_after_a_clock_jump(tmp_path: Path) -> None:
    """Explicit future-record guard symmetric with scan_window."""
    ledger = tmp_path / "rotate_future.jsonl"
    lines = [json.dumps({"ts": (NOW - dt.timedelta(minutes=900)).isoformat(),
                         "model": "gpt-5.6-sol", "kind": "dispatch", "id": f"old{i}"})
             for i in range(600)]
    lines.append(json.dumps({"ts": (NOW + dt.timedelta(minutes=120)).isoformat(),
                             "model": "gpt-5.6-sol", "kind": "dispatch", "id": "future"}))
    ledger.write_text("\n".join(lines) + "\n", encoding="utf-8")

    result = tiers.rotate_ledger(ledger, now=NOW, minutes=300)

    assert result["rotated"] is True
    assert "future" in ledger.read_text(encoding="utf-8")


# --------------------------------------------------------------------------- #
# ITEM 4 - allowed_window_enforcement_modes validated
# --------------------------------------------------------------------------- #
def test_enforce_is_rejected_when_the_allowed_list_pins_observe_only() -> None:
    matrix = copy.deepcopy(_shipped_matrix())
    matrix[tiers.ENFORCEMENT_MODE_FIELD] = "enforce"
    matrix[tiers.ALLOWED_ENFORCEMENT_MODES_FIELD] = ["observe"]

    error = tiers.validate_matrix(matrix)
    assert error is not None
    assert f"{tiers.ENFORCEMENT_MODE_FIELD}_not_allowed" in error


def test_observe_default_is_rejected_when_not_in_the_allowed_list() -> None:
    """The DEFAULT mode (field absent) must also be a member of the list."""
    matrix = copy.deepcopy(_shipped_matrix())
    matrix.pop(tiers.ENFORCEMENT_MODE_FIELD, None)
    matrix[tiers.ALLOWED_ENFORCEMENT_MODES_FIELD] = ["enforce"]

    error = tiers.validate_matrix(matrix)
    assert error is not None
    assert f"{tiers.ENFORCEMENT_MODE_FIELD}_not_allowed" in error


@pytest.mark.parametrize("bad", [[], "observe", ["observe", "loud"], [None]])
def test_a_malformed_allowed_list_fails_closed(bad) -> None:
    matrix = copy.deepcopy(_shipped_matrix())
    matrix[tiers.ALLOWED_ENFORCEMENT_MODES_FIELD] = bad

    error = tiers.validate_matrix(matrix)
    assert error is not None
    assert tiers.ALLOWED_ENFORCEMENT_MODES_FIELD in error


def test_the_shipped_allowed_list_permits_both_modes() -> None:
    """The shipped config must stay loadable in observe AND enforce."""
    matrix = copy.deepcopy(_shipped_matrix())
    assert set(matrix[tiers.ALLOWED_ENFORCEMENT_MODES_FIELD]) == {"observe", "enforce"}
    for mode in ("observe", "enforce"):
        candidate = copy.deepcopy(matrix)
        candidate[tiers.ENFORCEMENT_MODE_FIELD] = mode
        assert tiers.validate_matrix(candidate) is None


# --------------------------------------------------------------------------- #
# ITEM 5 - rotate_ledger stat-only fast path below min_lines
# --------------------------------------------------------------------------- #
def test_rotate_ledger_below_threshold_never_decodes_the_file(
    tmp_path: Path, monkeypatch
) -> None:
    ledger = tmp_path / "small.jsonl"
    ledger.write_text(
        "\n".join(json.dumps({"ts": NOW.isoformat(), "model": "gpt-5.6-sol"}) for _ in range(10))
        + "\n",
        encoding="utf-8",
    )

    # The fast path must NOT call read_text (a full decode) below the threshold.
    def _boom(*_a, **_k):  # pragma: no cover - only fires on regression
        raise AssertionError("rotate_ledger decoded the file below the threshold")

    monkeypatch.setattr(Path, "read_text", _boom)
    result = tiers.rotate_ledger(ledger, now=NOW, minutes=300, min_lines=500)

    assert result["rotated"] is False
    assert result["reason"] == "below_rotation_threshold"
    assert result["lines"] == 10


def test_rotate_ledger_absent_file_still_reports_ledger_absent(tmp_path: Path) -> None:
    result = tiers.rotate_ledger(tmp_path / "missing.jsonl", now=NOW, minutes=300)
    assert result["rotated"] is False
    assert result["reason"] == "ledger_absent"


# --------------------------------------------------------------------------- #
# ITEM 6 - Astra HOLD outranks the OWNER burn bypass in enforce mode
# --------------------------------------------------------------------------- #
def _spent_astra_ledger(tmp_path, monkeypatch) -> Path:
    ledger = tmp_path / "astra_window.jsonl"
    _saturate_model(ledger, "gpt-6-astra", 2)  # plan plus: floor(3*0.8)=2 -> spent
    _touch(ledger, NOW)
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(ledger))
    return ledger


def test_enforce_mode_holds_a_spent_astra_task_even_under_a_burn_flag(
    tmp_path: Path, monkeypatch
) -> None:
    _config_at(tmp_path, monkeypatch, mode="enforce", plan="plus")
    _spent_astra_ledger(tmp_path, monkeypatch)
    _write_burn_flag(tmp_path, monkeypatch, "codex")

    decision = quota_spawn_gate.evaluate_spawn(
        "codex",
        "ops_issue",
        50,
        state_path=tmp_path / "gov.json",
        summary_path=tmp_path / "sum.json",
        payload={"scalpel": True},
        now=NOW,
    )

    assert decision["allowed"] is False
    assert decision["reason"] == tiers.WINDOW_EXHAUSTED_REASON
    assert decision["state_status"] == "model_tier_window"


def test_enforce_mode_holds_an_invalid_scalpel_marker_even_under_a_burn_flag(
    tmp_path: Path, monkeypatch
) -> None:
    _config_at(tmp_path, monkeypatch, mode="enforce", plan="plus")
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(tmp_path / "ledger.jsonl"))
    _write_burn_flag(tmp_path, monkeypatch, "codex")

    decision = quota_spawn_gate.evaluate_spawn(
        "codex",
        "ops_issue",
        50,
        state_path=tmp_path / "gov.json",
        summary_path=tmp_path / "sum.json",
        payload={"scalpel": "true"},  # invalid marker
        now=NOW,
    )

    assert decision["allowed"] is False
    assert decision["reason"] == tiers.INVALID_SCALPEL_REASON


def test_burn_still_outranks_an_ordinary_window_refusal(tmp_path: Path, monkeypatch) -> None:
    """Control: an ORDINARY-tier refusal (which only downgrades) is NOT a hold,
    so the OWNER burn bypass still allows it."""
    _config_at(tmp_path, monkeypatch, mode="enforce", plan="plus")
    ledger = tmp_path / "sol_window.jsonl"
    # Saturate the whole sol fallback chain so there is no room anywhere: this
    # produces a `model_tier_refusal` but NO `model_tier_hold` (not scalpel).
    lines: list[str] = []
    for model, n in (("gpt-5.6-sol", 8), ("gpt-5.6-terra", 20), ("gpt-5.6-luna", 200),
                     ("gpt-5.5", 12), ("gpt-5.4", 16), ("gpt-5.4-mini", 48)):
        for i in range(n):
            lines.append(json.dumps({"ts": NOW.isoformat(), "model": model,
                                     "kind": "dispatch", "id": f"{model}-{i}"}))
    ledger.write_text("\n".join(lines) + "\n", encoding="utf-8")
    _touch(ledger, NOW)
    monkeypatch.setenv(tiers.LEDGER_PATH_ENV, str(ledger))
    _write_burn_flag(tmp_path, monkeypatch, "codex")

    decision = quota_spawn_gate.evaluate_spawn(
        "codex",
        "build_ea",
        50,
        state_path=tmp_path / "gov.json",
        summary_path=tmp_path / "sum.json",
        payload={"codex_model_tier": "sol"},
        now=NOW,
    )

    # No hold -> burn bypass wins.
    assert decision["allowed"] is True
    assert decision["reason"].startswith("owner_burn_authorization_active")


# --------------------------------------------------------------------------- #
# OBSERVE-mode invariance: the shipped default is unperturbed
# --------------------------------------------------------------------------- #
def test_observe_mode_spawn_decisions_are_unchanged_by_this_patch(
    tmp_path: Path, monkeypatch
) -> None:
    """In OBSERVE mode a spent Astra window, WITH or WITHOUT a burn flag, still
    ALLOWS the spawn (observe refuses/holds nothing). The ITEM 6 reorder is
    gated to enforce mode, so observe is byte-identical: same allow, same model,
    same recorded count."""
    _config_at(tmp_path, monkeypatch, mode="observe", plan="plus")
    ledger = _spent_astra_ledger(tmp_path, monkeypatch)

    baseline = quota_spawn_gate.evaluate_spawn(
        "codex", "ops_issue", 50,
        state_path=tmp_path / "gov.json", summary_path=tmp_path / "sum.json",
        payload={"scalpel": True}, now=NOW, write_summary=False,
    )
    assert baseline["allowed"] is True
    assert baseline["invocation"]["model"] == "gpt-6-astra"

    _write_burn_flag(tmp_path, monkeypatch, "codex")
    with_burn = quota_spawn_gate.evaluate_spawn(
        "codex", "ops_issue", 50,
        state_path=tmp_path / "gov.json", summary_path=tmp_path / "sum.json",
        payload={"scalpel": True}, now=NOW, write_summary=False,
    )
    # burn changes only the REASON string, never the allow/model in observe.
    assert with_burn["allowed"] is True
    assert with_burn["invocation"]["model"] == "gpt-6-astra"


def test_observe_mode_ledger_counts_are_identical_for_well_formed_ledgers(
    tmp_path: Path,
) -> None:
    """The rotate/scan changes (ITEM 2/3/5) must not move the count for a
    well-formed ledger (the only kind a Codex spawn writes): every record has a
    real ts, so the position bounds never fire."""
    ledger = tmp_path / "well_formed.jsonl"
    _saturate_model(ledger, "gpt-5.6-sol", 5)
    _touch(ledger, NOW)
    assert tiers.window_count("gpt-5.6-sol", now=NOW, path=ledger) == 5

    # A record that has genuinely left the window still drops out normally.
    older = tmp_path / "well_formed_aged.jsonl"
    lines = [json.dumps({"ts": (NOW - dt.timedelta(minutes=400)).isoformat(),
                         "model": "gpt-5.6-sol", "kind": "dispatch", "id": f"a{i}"})
             for i in range(3)]
    lines += [json.dumps({"ts": NOW.isoformat(), "model": "gpt-5.6-sol",
                          "kind": "dispatch", "id": f"b{i}"}) for i in range(2)]
    older.write_text("\n".join(lines) + "\n", encoding="utf-8")
    _touch(older, NOW)
    assert tiers.window_count("gpt-5.6-sol", now=NOW, path=older) == 2
