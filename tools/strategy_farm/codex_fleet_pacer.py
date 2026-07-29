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
import argparse, json, os, shutil, subprocess, sys
import datetime as dt
from pathlib import Path

try:
    from managed_codex import (
        is_managed_codex_pid_live,
        list_live_managed_codex_processes,
        spawn_managed_codex,
        terminate_managed_codex_pid,
    )
except ModuleNotFoundError:
    from tools.strategy_farm.managed_codex import (
        is_managed_codex_pid_live,
        list_live_managed_codex_processes,
        spawn_managed_codex,
        terminate_managed_codex_pid,
    )

REPO_ROOT = Path(__file__).resolve().parents[2]
FARM_ROOT = Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm"))
GOV_STATE = Path(r"D:/QM/reports/state/quota_governor_state.json")
PACER_DIR = Path(r"D:/QM/strategy_farm/codex_pacer")
PROMPT_DIR = PACER_DIR / "prompts"
LOG_DIR = PACER_DIR / "logs"
STATE = Path(r"D:/QM/reports/state/codex_fleet_pacer_state.json")
LOG = Path(r"D:/QM/reports/state/codex_fleet_pacer.log")
FACTORY_OFF_FLAG = FARM_ROOT / "state" / "FACTORY_OFF.flag"
FACTORY_MUTATION_LOCK = FARM_ROOT / "state" / "FACTORY_MUTATION.lock"

# Pacing parameters
SOFT_CEIL_PCT = 92.0     # stop spawning at/above this weekly-used % (OWNER 2026-06-26: higher utilization)
HARD_CEIL_PCT = 94.0     # kill our agents at/above this (guarantee no 100% cap-stop); 6% buffer to the cap
DEFAULT_MAX_AGENTS = 4   # concurrency cap (CPU/backtest + safety)
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


def _alive(pid: int) -> bool:
    # A bare live PID is not ownership proof because Windows reuses PIDs.
    return is_managed_codex_pid_live(FARM_ROOT, int(pid))


def _factory_off_cleanup(*, dry_run: bool) -> dict[str, object]:
    """Stop only Codex processes registered in the farm's managed lease store.

    Manually started Codex shells are not registered there and are therefore out
    of scope.  The cleanup deliberately covers all managed purposes (pacer,
    orchestration, build and review): disabling the scheduler wrapper alone does
    not guarantee that an already-spawned child exits with it.
    """
    leases = list_live_managed_codex_processes(FARM_ROOT)
    stops: list[dict[str, object]] = []
    for lease in leases:
        pid = int(lease["pid"])
        if dry_run:
            stops.append({
                "pid": pid,
                "purpose": lease.get("purpose"),
                "stopped": False,
                "reason": "dry_run",
            })
            continue
        try:
            stop = dict(terminate_managed_codex_pid(FARM_ROOT, pid))
        except Exception as exc:
            stop = {"pid": pid, "stopped": False, "reason": repr(exc)}
        stop.setdefault("purpose", lease.get("purpose"))
        stops.append(stop)
    remaining = list_live_managed_codex_processes(FARM_ROOT)
    return {
        "managed_before": len(leases),
        "managed_remaining": len(remaining),
        "stops": stops,
    }


def _write_state(state: dict[str, object], *, dry_run: bool) -> None:
    if dry_run:
        return
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2), encoding="utf-8")


def _acquire_spawn_lock() -> int | None:
    """Join the Factory OFF writer handover for the spawn/register window."""
    FACTORY_MUTATION_LOCK.parent.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(
            str(FACTORY_MUTATION_LOCK),
            os.O_CREAT | os.O_EXCL | os.O_WRONLY,
        )
    except FileExistsError:
        _log(f"spawn_skip factory_mutation_lock_busy={FACTORY_MUTATION_LOCK}")
        return None
    try:
        record = {
            "pid": os.getpid(),
            "owner": "codex_fleet_pacer_spawn",
            "created_at": _now().replace(microsecond=0).isoformat(),
        }
        os.write(fd, json.dumps(record, sort_keys=True).encode("utf-8"))
        os.fsync(fd)
    except Exception:
        os.close(fd)
        try:
            FACTORY_MUTATION_LOCK.unlink(missing_ok=True)
        except OSError:
            pass
        raise
    if FACTORY_OFF_FLAG.exists():
        os.close(fd)
        try:
            FACTORY_MUTATION_LOCK.unlink(missing_ok=True)
        except OSError:
            pass
        _log("spawn_skip factory_off_after_lock")
        return None
    return fd


def _release_spawn_lock(fd: int | None) -> None:
    if fd is None:
        return
    os.close(fd)
    try:
        FACTORY_MUTATION_LOCK.unlink(missing_ok=True)
    except OSError:
        pass


def _spawn_agent(prompt_name: str) -> int | None:
    prompt = PROMPT_DIR / prompt_name
    if not prompt.exists():
        _log(f"spawn_skip missing_prompt={prompt}")
        return None
    try:
        spawn_lock_fd = _acquire_spawn_lock()
    except Exception as exc:
        _log(f"spawn_skip factory_mutation_lock_error={exc!r}")
        return None
    if spawn_lock_fd is None:
        return None
    stamp = _now().strftime("%Y%m%d_%H%M%S")
    live_log = LOG_DIR / f"agent_{stamp}_{prompt_name.split('.')[0]}.live.log"
    live_log.parent.mkdir(parents=True, exist_ok=True)
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    try:
        command = [_resolve_codex(), "exec", "-s", "danger-full-access", "--cd", str(REPO_ROOT)]
        with prompt.open("rb") as stdin_f, live_log.open("wb") as stdout_f:
            proc, lease = spawn_managed_codex(
                FARM_ROOT,
                command,
                purpose="fleet_pacer",
                cwd=REPO_ROOT,
                max_age_minutes=60,
                metadata={"prompt": prompt_name, "live_log": str(live_log)},
                stdin=stdin_f,
                stdout=stdout_f,
                stderr=subprocess.STDOUT,
                creationflags=creationflags,
            )
        _log(
            f"spawned agent pid={proc.pid} lease={lease['lease_id']} "
            f"prompt={prompt_name} log={live_log.name}"
        )
        return proc.pid
    except Exception as exc:
        _log(f"spawn_failed prompt={prompt_name} err={exc}")
        return None
    finally:
        _release_spawn_lock(spawn_lock_fd)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Pace a headless Codex fleet to the weekly cap.")
    ap.add_argument("--max-agents", type=int, default=DEFAULT_MAX_AGENTS)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)

    # MNT-052: FACTORY_OFF is a software interlock, not merely a scheduler
    # preference.  Check it before quota reads or prompt discovery and drain all
    # farm-owned Codex children that may have outlived their scheduled wrapper.
    if FACTORY_OFF_FLAG.exists():
        cleanup = _factory_off_cleanup(dry_run=args.dry_run)
        state: dict[str, object] = {
            "ts": _now().replace(microsecond=0).isoformat(),
            "action": "factory_off_cleanup",
            "factory_off_flag": str(FACTORY_OFF_FLAG),
            "dry_run": args.dry_run,
            **cleanup,
        }
        _write_state(state, dry_run=args.dry_run)
        _log(
            "factory_off_cleanup "
            f"managed_before={cleanup['managed_before']} "
            f"managed_remaining={cleanup['managed_remaining']} "
            f"dry_run={args.dry_run}"
        )
        print(json.dumps(state, indent=2))
        return 0 if args.dry_run or cleanup["managed_remaining"] == 0 else 1

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
    fleet_leases = list_live_managed_codex_processes(FARM_ROOT, purpose="fleet_pacer")
    pids = sorted({int(item["pid"]) for item in fleet_leases})
    running = len(pids)

    # recent spend rate (%/hr) from our last observation
    rate = None
    if prev.get("ts") and "used" in prev:
        dt_h = (_now() - dt.datetime.fromisoformat(prev["ts"])).total_seconds() / 3600.0
        if dt_h > 0.05:
            rate = (used - float(prev["used"])) / dt_h

    headroom = SOFT_CEIL_PCT - used
    target_rate = max(headroom / hours_to_reset, 0.0)  # %/hr to land at SOFT_CEIL at reset

    action = "hold"
    hard_ceiling_stops: list[dict[str, object]] = []
    if used >= HARD_CEIL_PCT:
        # emergency: kill our agents so we never reach the 100% cap-stop
        for p in pids:
            try:
                stop = terminate_managed_codex_pid(FARM_ROOT, int(p))
            except Exception as exc:
                stop = {"stopped": False, "reason": repr(exc), "pid": int(p)}
            hard_ceiling_stops.append(stop)
        pids = [p for p in pids if _alive(int(p))]
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
            # Close the check/spawn race with Factory_OFF.ps1.  OFF writes the
            # interlock before it disables tasks, and then waits for cleanup.
            if used >= SOFT_CEIL_PCT or FACTORY_OFF_FLAG.exists():
                if FACTORY_OFF_FLAG.exists():
                    action = "factory_off_no_spawn"
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
        "hard_ceiling_stops": hard_ceiling_stops,
        "soft_ceil": SOFT_CEIL_PCT, "hard_ceil": HARD_CEIL_PCT, "max_agents": args.max_agents,
    }
    _write_state(state, dry_run=args.dry_run)
    _log(f"used={used:.1f}% rate={state['rate_pct_per_hr']} target_rate={target_rate:.3f}/hr "
         f"h_to_reset={hours_to_reset:.1f} running={running} target={target} spawned={spawned} action={action}")
    print(json.dumps(state, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
