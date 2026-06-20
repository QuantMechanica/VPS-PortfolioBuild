#!/usr/bin/env python3
"""QuantMechanica - Quota Governor (automated weekly-pace throttle).

OWNER policy (2026-06-21): steer Codex AND Claude controllable work so weekly
token spend roughly CORRELATES with the weekly limit along a linear track.
  - Buffer present (spend at/under linear pace)  -> BUILD: EAs get programmed by
    both agents (no throttle flags).
  - Buffer tight  (spend ahead of linear pace)   -> FOCUS: throttle the build/
    research lanes so the remaining budget goes to priority work; at minimum the
    MT5 backtests keep running (they cost $0 agent tokens, never throttled here).

Control variable = WEEKLY utilization vs WEEKLY time elapsed (pace), with
hysteresis to avoid flapping, plus an absolute weekly safety ceiling.

Levers (existing, honored by farmctl.py / agent_router.py):
  - Codex  : D:/QM/strategy_farm/CODEX_LOW_TOKENS.flag
             -> builds=0, G0 mass-review=off, research=off, MAX_PARALLEL_CODEX=1
                (one slot stays for priority repair/orchestration)
  - Claude : D:/QM/strategy_farm/CLAUDE_DISABLED.flag
             -> headless claude builds=0, MAX_PARALLEL_CLAUDE=0
                (interactive Claude is unaffected; it is a separate process)

The MT5 terminal workers are NEVER touched -> backtests always run.

Reads the snapshot written by quota_pull.py (5-min SYSTEM task):
  D:/QM/strategy_farm/state/quota_snapshot.json
Decisions are idempotent and ownership-tracked: the governor only REMOVES a flag
it set itself (recorded in quota_governor_state.json), so a flag set manually or
by another mechanism (e.g. codex auth disable) is never silently cleared.

Run on a timer (e.g. every 15 min, SYSTEM). Safe to run by hand:
    python tools/strategy_farm/quota_governor.py            # apply
    python tools/strategy_farm/quota_governor.py --dry-run  # decide only, no writes
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path

ROOT = Path(r"D:/QM/strategy_farm")
SNAPSHOT = ROOT / "state" / "quota_snapshot.json"
STATE = Path(r"D:/QM/reports/state/quota_governor_state.json")
LOG = Path(r"D:/QM/reports/state/quota_governor.log")

FLAGS = {
    "codex": ROOT / "CODEX_LOW_TOKENS.flag",
    "claude": ROOT / "CLAUDE_DISABLED.flag",
}

WEEK_SECONDS = 7 * 24 * 3600.0

# --- control law (per agent), in percentage points of (used% - elapsed%) -------
FLOOR_USED_PCT = 15.0   # below this weekly-used%, never throttle (ample buffer)
ON_DIFF = 12.0          # start throttling when used% exceeds linear pace by >=12 pts
OFF_DIFF = 4.0          # release only once back within +4 pts of linear pace (hysteresis)
HARD_CEIL_PCT = 90.0    # absolute weekly safety: throttle regardless of pace
STALE_MINUTES = 25      # if snapshot older than this, make NO new decision


def _now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _log(msg: str) -> None:
    line = f"{_now().strftime('%Y-%m-%dT%H:%M:%SZ')} {msg}"
    print(line)
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except Exception:
        pass


def _parse_iso(s: str | None) -> dt.datetime | None:
    if not s:
        return None
    try:
        x = dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
        if x.tzinfo is None:
            x = x.replace(tzinfo=dt.timezone.utc)
        return x
    except Exception:
        return None


def _agent_metrics(snap: dict, agent: str) -> dict | None:
    """Return {used_pct, elapsed_pct, diff, projected, week_reset} or None."""
    node = (snap.get(agent) or {}).get("data") or {}
    structured = node.get("structured") or {}
    raw = node.get("raw") or {}

    used = structured.get("week_pct")
    if used is None:
        used = node.get("week_pct")
    if used is None:
        return None
    used = float(used)

    # precise weekly reset time: prefer raw epoch/iso, fall back to structured string
    reset_dt: dt.datetime | None = None
    if agent == "codex":
        rl = (raw.get("rate_limit") or {}).get("secondary_window") or {}
        epoch = rl.get("reset_at")
        if epoch:
            reset_dt = dt.datetime.fromtimestamp(float(epoch), dt.timezone.utc)
    else:
        reset_dt = _parse_iso(((raw.get("seven_day") or {}).get("resets_at")))
    if reset_dt is None:
        wr = structured.get("week_reset") or node.get("week_reset")
        if wr:
            try:
                reset_dt = dt.datetime.strptime(wr, "%d.%m. %H:%M UTC").replace(
                    tzinfo=dt.timezone.utc, year=_now().year)
            except Exception:
                reset_dt = None
    if reset_dt is None:
        return None

    now = _now()
    week_start = reset_dt - dt.timedelta(seconds=WEEK_SECONDS)
    elapsed = (now - week_start).total_seconds() / WEEK_SECONDS * 100.0
    elapsed = max(0.01, min(100.0, elapsed))
    diff = used - elapsed
    projected = used / elapsed * 100.0
    return {
        "used_pct": round(used, 1),
        "elapsed_pct": round(elapsed, 1),
        "diff": round(diff, 1),
        "projected_eow_pct": round(projected, 0),
        "week_reset": reset_dt.strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def _decide(used: float, diff: float, currently_throttled: bool) -> tuple[bool, str]:
    if used < FLOOR_USED_PCT:
        return False, f"buffer (used {used:.0f}% < floor {FLOOR_USED_PCT:.0f}%)"
    if used >= HARD_CEIL_PCT:
        return True, f"hard ceiling (used {used:.0f}% >= {HARD_CEIL_PCT:.0f}%)"
    if currently_throttled:
        if diff > OFF_DIFF:
            return True, f"hold throttle (still +{diff:.0f}pts ahead of pace > release {OFF_DIFF:.0f})"
        return False, f"release (back to +{diff:.0f}pts <= {OFF_DIFF:.0f} of linear pace)"
    if diff >= ON_DIFF:
        return True, f"engage throttle (+{diff:.0f}pts ahead of pace >= {ON_DIFF:.0f})"
    return False, f"build (within +{diff:.0f}pts of linear pace)"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not SNAPSHOT.exists():
        _log("ABORT: quota_snapshot.json missing — no decision")
        return 1
    age_min = (_now().timestamp() - SNAPSHOT.stat().st_mtime) / 60.0
    if age_min > STALE_MINUTES:
        _log(f"ABORT: snapshot stale ({age_min:.0f}min > {STALE_MINUTES}min) — keep current flags")
        return 1
    try:
        snap = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    except Exception as e:
        _log(f"ABORT: snapshot unreadable: {e}")
        return 1

    try:
        prev = json.loads(STATE.read_text(encoding="utf-8")) if STATE.exists() else {}
    except Exception:
        prev = {}

    out: dict = {"ts": _now().strftime("%Y-%m-%dT%H:%M:%SZ"), "agents": {}}
    for agent, flag in FLAGS.items():
        m = _agent_metrics(snap, agent)
        if m is None:
            _log(f"{agent}: metrics unavailable — skip")
            out["agents"][agent] = {"error": "metrics_unavailable"}
            continue
        flag_exists = flag.exists()
        owned = bool((prev.get("agents", {}).get(agent, {}) or {}).get("owned", False))
        want, why = _decide(m["used_pct"], m["diff"], flag_exists)

        action = "noop"
        if want and not flag_exists:
            action = "THROTTLE"
            if not args.dry_run:
                flag.write_text(
                    f"MANAGED_BY=quota_governor\nset_at={out['ts']}\n"
                    f"reason=weekly pace: used {m['used_pct']}% at {m['elapsed_pct']}% week elapsed "
                    f"(+{m['diff']}pts, projected EOW ~{m['projected_eow_pct']:.0f}%); {why}\n",
                    encoding="utf-8")
            owned = True
        elif want and flag_exists:
            action = "hold"
        elif (not want) and flag_exists:
            if owned:
                action = "RELEASE"
                if not args.dry_run:
                    try:
                        flag.unlink()
                    except Exception as e:
                        _log(f"{agent}: release failed: {e}")
                owned = False
            else:
                action = "leave-external"  # flag present but not governor-owned -> respect it
        else:  # not want, not exists
            owned = False

        out["agents"][agent] = {**m, "want_throttle": want, "flag_exists": flag.exists() if not args.dry_run else (want or (flag_exists and not (action=="RELEASE"))), "owned": owned, "action": action, "why": why}
        _log(f"{agent}: used={m['used_pct']}% elapsed={m['elapsed_pct']}% diff={m['diff']:+}pts "
             f"projEOW~{m['projected_eow_pct']:.0f}% -> {action} ({why})")

    if not args.dry_run:
        try:
            STATE.parent.mkdir(parents=True, exist_ok=True)
            STATE.write_text(json.dumps(out, indent=2), encoding="utf-8")
        except Exception as e:
            _log(f"state write failed: {e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
