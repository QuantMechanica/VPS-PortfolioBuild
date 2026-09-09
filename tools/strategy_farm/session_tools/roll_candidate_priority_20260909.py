"""Finite, exact-PID, idle-only rollout of the tested candidate-priority fix.

No terminal64 process is stopped. Existing workers must finish their active
tests; reservations plus the canonical mutation lock close the claim race.
The source hash is pinned, so concurrent edits stop this rollout safely.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import sqlite3
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import farmctl
import start_terminal_workers as starter
from factory_mutation_lock import FactoryMutationLock

ROOT = Path(r"D:\QM\strategy_farm")
REPO = Path(r"C:\QM\repo")
WORKER = REPO / "tools/strategy_farm/terminal_worker.py"
OWNER = "candidate-priority-rollout-20260909"


def targets(values):
    result = {}
    for value in values:
        terminal, raw_pid = value.split("=", 1)
        if terminal not in {f"T{i}" for i in range(1, 11)} or terminal in result:
            raise ValueError("rollout requires unique exact T1-T10 targets")
        pid = int(raw_pid)
        if pid <= 0:
            raise ValueError("rollout requires positive exact PIDs")
        result[terminal] = pid
    if not result:
        raise ValueError("no rollout targets")
    return result


def eligible(terminal, active, reservations):
    return terminal not in active and terminal not in reservations


def active_terminals():
    with sqlite3.connect((ROOT / "state/farm_state.sqlite").as_uri() + "?mode=ro", uri=True, timeout=2) as conn:
        return {row[0] for row in conn.execute("SELECT claimed_by FROM work_items WHERE status='active'")}


def emit(event, **detail):
    print(json.dumps({"event": event, "at_utc": farmctl.utc_now(), **detail}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", action="append", required=True)
    parser.add_argument("--worker-sha256", required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    pending = targets(args.target)
    done = []
    deadline = time.monotonic() + 60 * 60
    next_allowed = 0.0
    while pending and time.monotonic() < deadline:
        if hashlib.sha256(WORKER.read_bytes()).hexdigest() != args.worker_sha256:
            emit("source_drift_stop", remaining=pending)
            return 2
        if time.monotonic() < next_allowed:
            time.sleep(min(10, next_allowed - time.monotonic()))
            continue
        try:
            active = active_terminals()
            reservations = farmctl.terminal_reservations(ROOT)
            candidate = next((term for term in pending if eligible(term, active, reservations)), None)
            if candidate is None:
                if not args.apply:
                    emit("plan_waiting", remaining=pending)
                    return 0
                time.sleep(10)
                continue
            terminal = candidate
            old_pid = pending[terminal]
            actual = starter._scan_running_workers().get(terminal, [])
            if actual != [old_pid]:
                # Never stop a replacement worker or any reused unrelated PID.
                emit("exact_pid_changed_skip", terminal=terminal, expected=old_pid, actual=actual)
                pending.pop(terminal)
                continue
            if not args.apply:
                emit("plan_idle_reload", terminal=terminal, pid=old_pid)
                return 0
            reserved = False
            stopped = False
            try:
                with FactoryMutationLock(ROOT / "state/FACTORY_MUTATION.lock", owner=OWNER + ":" + terminal):
                    if not eligible(terminal, active_terminals(), farmctl.terminal_reservations(ROOT)):
                        continue
                    if hashlib.sha256(WORKER.read_bytes()).hexdigest() != args.worker_sha256:
                        raise RuntimeError("worker source changed before reload")
                    if not starter._pid_alive(old_pid):
                        continue
                    farmctl.set_terminal_reservation(ROOT, terminal, reserved_by=OWNER, minutes=5,
                                                     reason="Tested candidate-priority fix; idle-only exact-PID reload")
                    reserved = True
                    os.kill(old_pid, signal.SIGTERM)
                    stopped = True
                emit("idle_worker_stopped", terminal=terminal, old_pid=old_pid)
                result = subprocess.run([sys.executable, str(REPO / "tools/strategy_farm/start_terminal_workers.py")],
                                        cwd=REPO, capture_output=True, text=True, timeout=55,
                                        creationflags=subprocess.CREATE_NO_WINDOW)
                if result.returncode:
                    raise RuntimeError("canonical worker launcher failed: " + result.stderr[-500:])
                new_pid = json.loads((ROOT / "state/worker_pids.json").read_text()).get(terminal)
                if not new_pid or new_pid == old_pid or not starter._pid_alive(new_pid):
                    raise RuntimeError("worker replacement verification failed")
                emit("idle_reload_verified", terminal=terminal, old_pid=old_pid, new_pid=new_pid,
                     worker_sha256=args.worker_sha256)
                pending.pop(terminal)
                done.append(terminal)
                next_allowed = time.monotonic() + 150
            except (RuntimeError, OSError, subprocess.SubprocessError) as exc:
                if stopped:
                    emit("replacement_failed_stop", terminal=terminal, reason=str(exc), remaining=pending)
                    return 2
                raise
            finally:
                if reserved and farmctl.terminal_reservations(ROOT).get(terminal, {}).get("reserved_by") == OWNER:
                    farmctl.release_terminal_reservation(ROOT, terminal)
        except (RuntimeError, sqlite3.OperationalError) as exc:
            emit("reload_deferred", reason=str(exc), remaining=pending)
            if not args.apply:
                return 2
            time.sleep(10)
    emit("rollout_finished", reloaded=done, remaining=pending)
    return 0 if not pending else 2


if __name__ == "__main__":
    raise SystemExit(main())
