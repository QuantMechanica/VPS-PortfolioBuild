"""Scheduled-task wrapper for the strategy farm pump.

Task Scheduler should invoke this script directly with python.exe. It gives
each pump run its own log file so long-running child processes cannot keep the
next scheduled run from opening a shared redirected log.
"""

from __future__ import annotations

import datetime as dt
import os
import subprocess
import sys
import time
from pathlib import Path

try:
    from process_identity import get_process_identity
except ModuleNotFoundError:  # package import in tests
    from tools.strategy_farm.process_identity import get_process_identity


REPO_ROOT = Path(r"C:\QM\repo")
LOG_DIR = Path(r"D:\QM\strategy_farm\logs")
FARMCTL = REPO_ROOT / "tools" / "strategy_farm" / "farmctl.py"
CODEX_KILL_SAFETY_AUDIT = (
    REPO_ROOT / "tools" / "strategy_farm" / "codex_kill_safety_audit.py"
)
LOCK_PATH = LOG_DIR / "pump_task.lock"
LOCK_STALE_SECONDS = 20 * 60
FACTORY_OFF_FLAG = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
# 2026-08-29: while a Factory_ON ceremony is mid-flight the ceremony process holds
# the factory mutation lock until after its post-start health gate.  A full pump
# cycle then spends the whole gate in lock/sqlite retry sleeps and can never
# complete (R2/R4 gates starved on Pump for 3600s each).  Mirror the existing
# FACTORY_OFF no-op: report an honest, instant no-op success while the ceremony
# marker exists; the next 5-minute trigger after ceremony completion pumps fully.
FACTORY_ON_CEREMONY_MARKER = Path(
    r"D:\QM\strategy_farm\state\FACTORY_ON_CEREMONY_INCOMPLETE.json"
)


def _console_python() -> str:
    exe = Path(sys.executable)
    if exe.name.lower() == "pythonw.exe":
        candidate = exe.with_name("python.exe")
        if candidate.exists():
            return str(candidate)
    return sys.executable


def _acquire_lock() -> int | None:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(str(LOCK_PATH), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        try:
            lock_age = time.time() - LOCK_PATH.stat().st_mtime
            try:
                owner_pid = int(LOCK_PATH.read_text(encoding="ascii").strip())
            except (OSError, UnicodeError, ValueError):
                owner_pid = 0
            owner_dead = False
            if owner_pid > 0:
                try:
                    identity = get_process_identity(owner_pid)
                except (OSError, RuntimeError):
                    # Fail closed when Windows cannot establish liveness.
                    identity = {"is_running": True}
                owner_dead = not identity or not bool(identity.get("is_running", True))
            if owner_dead or lock_age > LOCK_STALE_SECONDS:
                LOCK_PATH.unlink()
                fd = os.open(str(LOCK_PATH), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            else:
                return None
        except OSError:
            return None
    os.write(fd, str(os.getpid()).encode("ascii"))
    return fd


def main() -> int:
    if FACTORY_OFF_FLAG.exists():
        return 0  # FACTORY_OFF.flag is set; pump is suspended
    if FACTORY_ON_CEREMONY_MARKER.exists():
        return 0  # Factory_ON ceremony in progress; pump no-ops until it completes
    os.environ.setdefault("QM_AGENT_ID", "controller")
    # Control-plane override: the pump is a singleton whose cycle dies wholesale
    # on one lost write.  15s busy timeout rides out news-runner write bursts;
    # worker/claim paths keep the short 750ms doctrine (they don't run through
    # this wrapper).  See sqlite_busy.BUSY_TIMEOUT_MS.
    os.environ.setdefault("QM_SQLITE_BUSY_TIMEOUT_MS", "15000")
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    lock_fd = _acquire_lock()
    if lock_fd is None:
        return 0
    stamp = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
    log_path = LOG_DIR / f"pump_task_{stamp}.log"
    try:
        with log_path.open("w", encoding="utf-8", newline="\n") as log:
            env = os.environ.copy()
            env.setdefault("QM_AGENT_ID", "controller")
            audit = subprocess.run(
                [_console_python(), str(CODEX_KILL_SAFETY_AUDIT), "--json"],
                cwd=str(REPO_ROOT),
                stdout=log,
                stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL,
                env=env,
                close_fds=True,
            )
            if audit.returncode != 0:
                log.write(
                    "\nPUMP_BLOCKED: unsafe process lifecycle code found in a local worktree\n"
                )
                return 86
            proc = subprocess.run(
                [_console_python(), str(FARMCTL), "pump"],
                cwd=str(REPO_ROOT),
                stdout=log,
                stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL,
                env=env,
                close_fds=True,
            )
        return int(proc.returncode)
    finally:
        os.close(lock_fd)
        try:
            LOCK_PATH.unlink()
        except OSError:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
