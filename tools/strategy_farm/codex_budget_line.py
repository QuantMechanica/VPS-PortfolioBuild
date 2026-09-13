"""Codex weekly budget line - one pace authority for every Codex spawner.

OWNER 2026-09-13 ~07:3xZ (chat, verbatim): "Codex ist nur mehr auf 36%? Wird aber erst in einer
knappen Woche zurueckgesetzt! Bitte Verbrauch an Wochenlimits anpassen (wie bei Claude auch)".

Measured cause (docs/ops/OPEN_ITEMS_STATUS.md 2026-09-13T08:0xZ): the fleet pacer measured its spend
rate over one 15-minute interval of an integer-granular used%, read 0.0 %/h, reported "under_pace"
and spawned a Sol mission every 15-30 min; router tickets with priority >= owner_priority_min (70)
bypass every pace threshold of the spawn gate. Codex went 4 % -> 64 % of the weekly limit in 22 h.

Rule: the REMAINING weekly budget is spread evenly over the time left to the weekly reset.

    line(t) = anchor_used + (target_at_reset - anchor_used) * (t - anchor_ts) / (reset_ts - anchor_ts)

A Codex spawn (pacer mission or router ticket, owner priority included) is allowed only while
used_pct <= line(t) + tolerance.  The anchor is (activation time, used% at activation) when the line is
first enabled or the weekly reset changes; from a fresh week on (anchor ~0 %) this is the same linear
weekly pace the quota governor applies to Claude.  Backtests and deterministic work are never touched.

State: D:/QM/reports/state/codex_budget_line.json (anchor, reset, target).  Rollback switch:
environment QM_CODEX_BUDGET_LINE=0 disables the line everywhere (evaluate() returns enabled=False,
allowed=True); deleting the state file re-anchors at the next evaluation.
"""
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path
from typing import Any

GOV_STATE = Path(r"D:/QM/reports/state/quota_governor_state.json")
STATE_PATH = Path(r"D:/QM/reports/state/codex_budget_line.json")
ENV_SWITCH = "QM_CODEX_BUDGET_LINE"
DEFAULT_TARGET_AT_RESET_PCT = 92.0  # the pacer's SOFT_CEIL: land there, never at the 100 % cap-stop
DEFAULT_TOLERANCE_PTS = 1.0  # used% is integer-granular; one point of slack avoids flapping
REANCHOR_DROP_PTS = 5.0  # used% falling this far below the anchor means the week reset


def enabled() -> bool:
    return os.environ.get(ENV_SWITCH, "1").strip() != "0"


def _parse_ts(value: str) -> dt.datetime:
    parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed


def read_governor_codex(path: Path = GOV_STATE) -> tuple[float, dt.datetime]:
    """Return (weekly used %, weekly reset instant) from the quota governor state."""
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    node = data["agents"]["codex"]
    return float(node["used_pct"]), _parse_ts(str(node["week_reset"]))


def line_at(
    *,
    anchor_ts: dt.datetime,
    anchor_used: float,
    reset_ts: dt.datetime,
    now: dt.datetime,
    target_at_reset: float = DEFAULT_TARGET_AT_RESET_PCT,
) -> float:
    """Allowed used% at `now` on the straight line from the anchor to (reset, target)."""
    span = (reset_ts - anchor_ts).total_seconds()
    if span <= 0:
        return float(target_at_reset)
    frac = (now - anchor_ts).total_seconds() / span
    frac = min(max(frac, 0.0), 1.0)
    return float(anchor_used) + (float(target_at_reset) - float(anchor_used)) * frac


def load_state(path: Path = STATE_PATH) -> dict[str, Any] | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def save_state(state: dict[str, Any], path: Path = STATE_PATH) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)


def _needs_anchor(state: dict[str, Any] | None, used: float, reset_ts: dt.datetime) -> str | None:
    if not state:
        return "no_state"
    try:
        stored_reset = _parse_ts(str(state["reset_ts"]))
        anchor_used = float(state["anchor_used"])
        _parse_ts(str(state["anchor_ts"]))
    except (KeyError, ValueError, TypeError):
        return "state_unreadable"
    if abs((stored_reset - reset_ts).total_seconds()) > 60:
        return "weekly_reset_changed"
    if used < anchor_used - REANCHOR_DROP_PTS:
        return "used_dropped_below_anchor"
    return None


def activate(
    *,
    used: float | None = None,
    reset: dt.datetime | None = None,
    now: dt.datetime | None = None,
    state_path: Path | None = None,
    governor_path: Path | None = None,
    target_at_reset: float = DEFAULT_TARGET_AT_RESET_PCT,
    reason: str = "orchestrator_activation",
) -> dict[str, Any]:
    """Anchor the line at (now, used) and persist it; evaluate() is inactive until this ran once."""
    now = now or dt.datetime.now(dt.timezone.utc)
    state_path = state_path or STATE_PATH
    governor_path = governor_path or GOV_STATE
    if used is None or reset is None:
        gov_used, gov_reset = read_governor_codex(governor_path)
        used = gov_used if used is None else used
        reset = gov_reset if reset is None else reset
    state = {
        "schema": "qm.codex-budget-line/v1",
        "anchor_ts": now.replace(microsecond=0).isoformat(),
        "anchor_used": float(used),
        "reset_ts": reset.replace(microsecond=0).isoformat(),
        "target_at_reset": float(target_at_reset),
        "anchored_because": reason,
        "owner_decision": "OWNER 2026-09-13: Codex-Verbrauch an Wochenlimit anpassen (wie Claude)",
    }
    save_state(state, state_path)
    return state


def evaluate(
    *,
    used: float | None = None,
    reset: dt.datetime | None = None,
    now: dt.datetime | None = None,
    state_path: Path | None = None,
    governor_path: Path | None = None,
    target_at_reset: float = DEFAULT_TARGET_AT_RESET_PCT,
    tolerance: float = DEFAULT_TOLERANCE_PTS,
    persist: bool = True,
) -> dict[str, Any]:
    """Allow/deny one prospective Codex spawn against the budget line.

    Fails toward DENY when the governor state is unreadable (a spawner must not guess the budget) and
    toward ALLOW only through the explicit rollback switch.
    """
    now = now or dt.datetime.now(dt.timezone.utc)
    governor_path = governor_path or GOV_STATE
    # A non-production governor state (tests, fixtures, rehearsals) gets its own line state next to it,
    # so evaluating against a fixture can never re-anchor or persist the production line.
    if state_path is None:
        state_path = STATE_PATH if governor_path == GOV_STATE else governor_path.parent / STATE_PATH.name
    if not enabled():
        return {"enabled": False, "allowed": True, "reason": "budget_line_disabled_by_env"}
    if used is None or reset is None:
        try:
            gov_used, gov_reset = read_governor_codex(governor_path)
        except (OSError, ValueError, KeyError, TypeError) as exc:
            return {
                "enabled": True,
                "allowed": False,
                "reason": f"governor_state_unreadable:{type(exc).__name__}",
            }
        used = gov_used if used is None else used
        reset = gov_reset if reset is None else reset
    state = load_state(state_path)
    if not state:
        return {"enabled": True, "allowed": True, "reason": "budget_line_not_activated", "state_path": str(state_path)}
    anchor_reason = _needs_anchor(state, float(used), reset)
    if anchor_reason:
        state = {
            "schema": "qm.codex-budget-line/v1",
            "anchor_ts": now.replace(microsecond=0).isoformat(),
            "anchor_used": float(used),
            "reset_ts": reset.replace(microsecond=0).isoformat(),
            "target_at_reset": float(target_at_reset),
            "anchored_because": anchor_reason,
            "owner_decision": "OWNER 2026-09-13: Codex-Verbrauch an Wochenlimit anpassen (wie Claude)",
        }
        if persist:
            save_state(state, state_path)
    anchor_ts = _parse_ts(str(state["anchor_ts"]))
    anchor_used = float(state["anchor_used"])
    target = float(state.get("target_at_reset") or target_at_reset)
    line = line_at(anchor_ts=anchor_ts, anchor_used=anchor_used, reset_ts=reset, now=now, target_at_reset=target)
    hours_to_reset = max((reset - now).total_seconds() / 3600.0, 0.0)
    slope = (target - anchor_used) / max((reset - anchor_ts).total_seconds() / 3600.0, 1e-6)
    over = float(used) - (line + tolerance)
    allowed = over <= 0.0
    return {
        "enabled": True,
        "allowed": allowed,
        "reason": "within_budget_line" if allowed else "codex_budget_line_exceeded",
        "used_pct": float(used),
        "line_pct": round(line, 3),
        "tolerance_pts": tolerance,
        "slope_pct_per_hr": round(slope, 4),
        "over_line_pts": round(max(over, 0.0), 3),
        "next_allowed_in_hours": (0.0 if allowed else round(over / slope, 2) if slope > 0 else None),
        "hours_to_reset": round(hours_to_reset, 2),
        "anchor_ts": state["anchor_ts"],
        "anchor_used": anchor_used,
        "reset_ts": state["reset_ts"],
        "target_at_reset": target,
        "anchored_now": bool(anchor_reason),
    }


def main(argv: list[str] | None = None) -> int:
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--activate", action="store_true", help="anchor the line now at the current used%% (orchestrator step)")
    args = ap.parse_args(argv)
    if args.activate:
        print(json.dumps(activate(), indent=2, sort_keys=True))
    print(json.dumps(evaluate(), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
