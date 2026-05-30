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


REPO_ROOT = Path(r"C:\QM\repo")
LOG_DIR = Path(r"D:\QM\strategy_farm\logs")
FARMCTL = REPO_ROOT / "tools" / "strategy_farm" / "farmctl.py"
LOCK_PATH = LOG_DIR / "pump_task.lock"
LOCK_STALE_SECONDS = 20 * 60


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
            if time.time() - LOCK_PATH.stat().st_mtime > LOCK_STALE_SECONDS:
                LOCK_PATH.unlink()
                fd = os.open(str(LOCK_PATH), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            else:
                return None
        except OSError:
            return None
    os.write(fd, str(os.getpid()).encode("ascii"))
    return fd


def main() -> int:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    lock_fd = _acquire_lock()
    if lock_fd is None:
        return 0
    stamp = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
    log_path = LOG_DIR / f"pump_task_{stamp}.log"
    try:
        with log_path.open("w", encoding="utf-8", newline="\n") as log:
            proc = subprocess.run(
                [_console_python(), str(FARMCTL), "pump"],
                cwd=str(REPO_ROOT),
                stdout=log,
                stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL,
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
