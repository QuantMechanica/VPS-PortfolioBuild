"""Codex fleet pacer — the active-utilization counterpart to the quota governor.

Goal (OWNER 2026-06-26): keep a fleet of headless Codex agents working continuously until the
weekly cap reset, consuming the weekly budget *evenly* — using the full budget but NEVER hitting the
cap (which would stop Codex). Self-correcting: it measures the recent spend rate and ramps the agent
count up when under-pace, holds when over-pace, stops spawning at a soft ceiling, and emergency-kills
its own agents at a hard ceiling so a 100% cap-stop cannot happen.

Run every ~15 min via QM_StrategyFarm_CodexFleetPacer. Idempotent. Spawns paced headless Codex
(`codex exec -s danger-full-access`) on rotating diverse-EA-building prompts so the spend does real
work (more certified portfolio sleeves), not idle burn.
"""
from __future__ import annotations
import argparse, json, os, shutil, subprocess, sys, time
import datetime as dt
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
GOV_STATE = Path(r"D:/QM/reports/state/quota_governor_state.json")
PACER_DIR = Path(r"D:/QM/strategy_farm/codex_pacer")
PROMPT_DIR = PACER_DIR / "prompts"
LOG_DIR = PACER_DIR / "logs"
STATE = Path(r"D:/QM/reports/state/codex_fleet_pacer_state.json")
LOG = Path(r"D:/QM/reports/state/codex_fleet_pacer.log")

# Pacing parameters
SOFT_CEIL_PCT = 88.0     # stop spawning at/above this weekly-used %
HARD_CEIL_PCT = 94.0     # kill our agents at/above this (guarantee no 100% cap-stop)
DEFAULT_MAX_AGENTS = 4   # concurrency cap (CPU/backtest + safety)
AGENT_FRESH_SEC = 240    # a live-log written within this window => agent still running
MIN_HOURS_TO_RESET = 0.25
PROMPT_ROTATION = ["focus_fx.md", "focus_commodity.md", "focus_backlog.md"]


def _now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _log(msg: str) -> None:
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as fh:
        fh.write(f"{_now().replace(microsecond=0).isoformat()} {msg}\n")


def _read_quota() -> tuple[float, dt.datetime]:
    g = json.loads(GOV_STATE.read_text(encoding="utf-8"))
    cod = g["agents"]["codex"]
    used = float(cod["used_pct"])
    reset = dt.datetime.fromisoformat(str(cod["week_reset"]).replace("Z", "+00:00"))
    return used, reset


def _resolve_codex() -> str:
    return shutil.which("codex.cmd") or shutil.which("codex") or "codex"


def _running_agents() -> int:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    n = 0
    for f in LOG_DIR.glob("agent_*.live.log"):
        try:
            if time.time() - f.stat().st_mtime < AGENT_FRESH_SEC:
                n += 1
        except OSError:
            pass
    return n


def _alive(pid: int) -> bool:
    try:
        out = subprocess.run(["tasklist", "/FI", f"PID eq {pid}"], capture_output=True, text=True)
        return str(pid) in out.stdout
    except Exception:
        return False


def _spawn_agent(prompt_name: str) -> int | None:
    prompt = PROMPT_DIR / prompt_name
    if not prompt.exists():
        _log(f"spawn_skip missing_prompt={prompt}")
        return None
    stamp = _now().strftime("%Y%m%d_%H%M%S")
    live_log = LOG_DIR / f"agent_{stamp}_{prompt_name.split('.')[0]}.live.log"
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    try:
        stdin_f = prompt.open("rb")
        stdout_f = live_log.open("wb")
        proc = subprocess.Popen(
            [_resolve_codex(), "exec", "-s", "danger-full-access", "--cd", str(REPO_ROOT)],
            stdin=stdin_f, stdout=stdout_f, stderr=subprocess.STDOUT,
            creationflags=creationflags,
        )
        _log(f"spawned agent pid={proc.pid} prompt={prompt_name} log={live_log.name}")
        return proc.pid
    except Exception as exc:
        _log(f"spawn_failed prompt={prompt_name} err={exc}")
        return None


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Pace a headless Codex fleet to the weekly cap.")
    ap.add_argument("--max-agents", type=int, default=DEFAULT_MAX_AGENTS)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)

    try:
        used, reset = _read_quota()
    except Exception as exc:
        _log(f"abort no_quota err={exc}")
        return 0

    prev = {}
    if STATE.exists():
        try:
            prev = json.loads(STATE.read_text(encoding="utf-8"))
        except Exception:
            prev = {}

    hours_to_reset = max((reset - _now()).total_seconds() / 3600.0, MIN_HOURS_TO_RESET)
    rotation_idx = int(prev.get("rotation_idx", 0))
    pids = [p for p in prev.get("agent_pids", []) if _alive(int(p))]
    running = _running_agents()

    # recent spend rate (%/hr) from our last observation
    rate = None
    if prev.get("ts") and "used" in prev:
        dt_h = (_now() - dt.datetime.fromisoformat(prev["ts"])).total_seconds() / 3600.0
        if dt_h > 0.05:
            rate = (used - float(prev["used"])) / dt_h

    headroom = SOFT_CEIL_PCT - used
    target_rate = max(headroom / hours_to_reset, 0.0)  # %/hr to land at SOFT_CEIL at reset

    action = "hold"
    if used >= HARD_CEIL_PCT:
        # emergency: kill our agents so we never reach the 100% cap-stop
        for p in pids:
            try:
                subprocess.run(["taskkill", "/PID", str(p), "/T", "/F"], capture_output=True)
            except Exception:
                pass
        pids = []
        target = 0
        action = "HARD_CEIL_kill"
    elif used >= SOFT_CEIL_PCT:
        target = running
        action = "soft_ceil_no_spawn"
    elif rate is None:
        target = min(1, args.max_agents)  # conservative until we have a measured spend rate
        action = "bootstrap"
    elif rate < target_rate * 0.85:
        target = min(args.max_agents, running + 1)
        action = "under_pace_rampup"
    elif rate > target_rate * 1.15:
        target = running
        action = "over_pace_hold"
    else:
        target = running
        action = "on_pace_hold"

    to_spawn = max(0, target - running)
    spawned = 0
    if not args.dry_run:
        for _ in range(to_spawn):
            if used >= SOFT_CEIL_PCT:
                break
            pid = _spawn_agent(PROMPT_ROTATION[rotation_idx % len(PROMPT_ROTATION)])
            rotation_idx += 1
            if pid:
                pids.append(pid)
                spawned += 1

    state = {
        "ts": _now().replace(microsecond=0).isoformat(),
        "used": used, "rate_pct_per_hr": (round(rate, 3) if rate is not None else None),
        "target_rate_pct_per_hr": round(target_rate, 3), "hours_to_reset": round(hours_to_reset, 1),
        "running_before": running, "target": target, "spawned": spawned,
        "agent_pids": pids, "rotation_idx": rotation_idx, "action": action,
        "soft_ceil": SOFT_CEIL_PCT, "hard_ceil": HARD_CEIL_PCT, "max_agents": args.max_agents,
    }
    if not args.dry_run:
        STATE.parent.mkdir(parents=True, exist_ok=True)
        STATE.write_text(json.dumps(state, indent=2), encoding="utf-8")
    _log(f"used={used:.1f}% rate={state['rate_pct_per_hr']} target_rate={target_rate:.3f}/hr "
         f"h_to_reset={hours_to_reset:.1f} running={running} target={target} spawned={spawned} action={action}")
    print(json.dumps(state, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
