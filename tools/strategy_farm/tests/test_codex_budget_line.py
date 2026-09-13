"""Codex weekly budget line + pacer rate window (OWNER 2026-09-13: pace Codex to the weekly limit).

Pure decision-logic coverage: line arithmetic, explicit activation, allow/deny with tolerance,
re-anchoring on a new weekly reset, the environment rollback switch, the pacer's governor-log rate
window, and the spawn gate denying an owner-priority Codex ticket once the line is exceeded.
No spawning, no farm mutation; every state file lives in tmp_path.
"""
import datetime as dt
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import codex_budget_line as bl  # noqa: E402
import codex_fleet_pacer as pacer  # noqa: E402
import quota_spawn_gate as gate  # noqa: E402

UTC = dt.timezone.utc
T0 = dt.datetime(2026, 9, 13, 7, 40, tzinfo=UTC)
RESET = dt.datetime(2026, 9, 19, 8, 29, tzinfo=UTC)


def test_line_is_straight_from_anchor_to_reset_target():
    assert bl.line_at(anchor_ts=T0, anchor_used=64.0, reset_ts=RESET, now=T0) == 64.0
    assert bl.line_at(anchor_ts=T0, anchor_used=64.0, reset_ts=RESET, now=RESET) == 92.0
    mid = T0 + (RESET - T0) / 2
    assert abs(bl.line_at(anchor_ts=T0, anchor_used=64.0, reset_ts=RESET, now=mid) - 78.0) < 1e-9
    # never extrapolates past the reset or before the anchor
    assert bl.line_at(anchor_ts=T0, anchor_used=64.0, reset_ts=RESET, now=RESET + dt.timedelta(hours=5)) == 92.0
    assert bl.line_at(anchor_ts=T0, anchor_used=64.0, reset_ts=RESET, now=T0 - dt.timedelta(hours=5)) == 64.0


def test_inactive_without_state_then_activation_allows_within_tolerance_and_denies_above(tmp_path, monkeypatch):
    monkeypatch.delenv(bl.ENV_SWITCH, raising=False)
    state = tmp_path / "line.json"
    inactive = bl.evaluate(used=99.0, reset=RESET, now=T0, state_path=state)
    assert inactive["enabled"] and inactive["allowed"] and inactive["reason"] == "budget_line_not_activated"
    assert not state.exists()
    bl.activate(used=64.0, reset=RESET, now=T0, state_path=state)
    assert json.loads(state.read_text())["anchor_used"] == 64.0
    at_anchor = bl.evaluate(used=64.0, reset=RESET, now=T0, state_path=state)
    assert at_anchor["allowed"] and not at_anchor["anchored_now"]
    # +1 pt right after anchoring is inside the tolerance band
    ok = bl.evaluate(used=65.0, reset=RESET, now=T0 + dt.timedelta(minutes=10), state_path=state)
    assert ok["allowed"]
    # +2 pts is over the line: denied, with an ETA that follows the slope (~0.193 %/h)
    over = bl.evaluate(used=66.0, reset=RESET, now=T0 + dt.timedelta(minutes=10), state_path=state)
    assert not over["allowed"] and over["reason"] == "codex_budget_line_exceeded"
    assert over["next_allowed_in_hours"] and 4.5 < over["next_allowed_in_hours"] < 5.5
    # five and a half hours later the line has caught up
    later = bl.evaluate(used=66.0, reset=RESET, now=T0 + dt.timedelta(hours=5.5), state_path=state)
    assert later["allowed"]


def test_evaluate_reanchors_on_new_weekly_reset_and_on_used_drop(tmp_path, monkeypatch):
    monkeypatch.delenv(bl.ENV_SWITCH, raising=False)
    state = tmp_path / "line.json"
    bl.activate(used=64.0, reset=RESET, now=T0, state_path=state)
    new_reset = RESET + dt.timedelta(days=7)
    fresh = bl.evaluate(used=3.0, reset=new_reset, now=RESET + dt.timedelta(hours=1), state_path=state)
    assert fresh["anchored_now"] and fresh["anchor_used"] == 3.0 and fresh["allowed"]
    # from a fresh week the line is the linear weekly pace: ~0.53 %/h to 92 % at the next reset
    assert 0.5 < fresh["slope_pct_per_hr"] < 0.56
    # a rise never re-anchors; a fall of more than REANCHOR_DROP_PTS below the anchor does
    steady = bl.evaluate(used=6.0, reset=new_reset, now=RESET + dt.timedelta(hours=6), state_path=state)
    assert not steady["anchored_now"]
    state.write_text(json.dumps({**json.loads(state.read_text()), "anchor_used": 30.0}))
    dropped = bl.evaluate(used=20.0, reset=new_reset, now=RESET + dt.timedelta(hours=7), state_path=state)
    assert dropped["anchored_now"] and dropped["anchor_used"] == 20.0


def test_env_switch_disables_line_and_unreadable_governor_denies(tmp_path, monkeypatch):
    monkeypatch.setenv(bl.ENV_SWITCH, "0")
    off = bl.evaluate(used=99.0, reset=RESET, now=T0, state_path=tmp_path / "x.json")
    assert off == {"enabled": False, "allowed": True, "reason": "budget_line_disabled_by_env"}
    monkeypatch.delenv(bl.ENV_SWITCH, raising=False)
    missing = bl.evaluate(now=T0, state_path=tmp_path / "y.json", governor_path=tmp_path / "nope.json")
    assert missing["enabled"] and not missing["allowed"]
    assert missing["reason"].startswith("governor_state_unreadable")


def test_pacer_rate_window_uses_governor_samples_not_one_tick(tmp_path):
    log = tmp_path / "quota_governor.log"
    lines = []
    for i in range(9):  # 15-min samples over two hours, integer-granular used%
        ts = T0 - dt.timedelta(hours=2) + dt.timedelta(minutes=15 * i)
        used = 60 + (i // 2)  # rises one point every 30 min -> 2 %/h
        lines.append(f"{ts.strftime('%Y-%m-%dT%H:%M:%SZ')} codex: used={used}.0% elapsed=13.0% diff=+47.0pts -> hold")
        lines.append(f"{ts.strftime('%Y-%m-%dT%H:%M:%SZ')} claude: used=27.0% elapsed=34.0% diff=-7.0pts -> noop")
    log.write_text("\n".join(lines) + "\n", encoding="utf-8")
    rate = pacer.rate_from_governor_log(T0, log_path=log)
    assert rate is not None and 1.9 < rate < 2.1
    # a single 15-min span is not enough evidence
    short = tmp_path / "short.log"
    short.write_text("\n".join(lines[-4:]) + "\n", encoding="utf-8")
    assert pacer.rate_from_governor_log(T0, log_path=short) is None
    assert pacer.rate_from_governor_log(T0, log_path=tmp_path / "missing.log") is None


def _governor_state(path: Path, used: float, now: dt.datetime) -> None:
    path.write_text(json.dumps({
        "ts": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "agents": {
            "codex": {"used_pct": used, "elapsed_pct": 14.0, "diff": used - 14.0,
                      "week_reset": RESET.strftime("%Y-%m-%dT%H:%M:%SZ"), "five_hour_used_pct": 10.0},
            "claude": {"used_pct": 27.0, "elapsed_pct": 34.0, "diff": -7.0,
                       "week_reset": "2026-09-17T22:00:00Z", "five_hour_used_pct": 5.0},
        },
    }), encoding="utf-8")


def test_gate_denies_owner_priority_codex_ticket_above_line_and_honours_exemption(tmp_path, monkeypatch):
    monkeypatch.delenv(bl.ENV_SWITCH, raising=False)
    gov = tmp_path / "gov.json"
    line_state = tmp_path / bl.STATE_PATH.name  # the line state lives next to a non-production governor state
    _governor_state(gov, 64.0, T0)
    # not activated: the owner-priority bypass behaves exactly as before
    _governor_state(gov, 67.0, T0 + dt.timedelta(minutes=30))
    before = gate.evaluate_spawn(
        agent="codex", task_type="ops_issue", priority=90, payload={},
        state_path=gov, now=T0 + dt.timedelta(minutes=30), write_summary=False,
    )
    assert before["allowed"] and before["reason"] == "owner_priority_bypass"
    bl.activate(used=64.0, reset=RESET, now=T0, state_path=line_state)
    denied = gate.evaluate_spawn(
        agent="codex", task_type="ops_issue", priority=90, payload={},
        state_path=gov, now=T0 + dt.timedelta(minutes=30), write_summary=False,
    )
    assert not denied["allowed"] and denied["reason"] == "codex_budget_line_exceeded"
    assert denied["violations"] == ["codex_budget_line"] and denied["budget_line"]["line_pct"] < 67.0
    exempt = gate.evaluate_spawn(
        agent="codex", task_type="ops_issue", priority=90, payload={"codex_budget_line_exempt": True},
        state_path=gov, now=T0 + dt.timedelta(minutes=30), write_summary=False,
    )
    assert exempt["allowed"] and exempt["reason"] == "owner_priority_bypass"
    claude = gate.evaluate_spawn(
        agent="claude", task_type="ops_issue", priority=90, payload={},
        state_path=gov, now=T0 + dt.timedelta(minutes=30), write_summary=False,
    )
    assert claude["allowed"]
