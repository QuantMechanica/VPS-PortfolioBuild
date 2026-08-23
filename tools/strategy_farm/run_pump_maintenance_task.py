"""Scheduled-task wrapper for the strategy-farm lower-frequency maintenance.

`farmctl pump-maintenance` runs the aggregate/statistics work that was removed
from the latency-sensitive 5-min pump (2026-08-23 rebaseline): ea_metrics
refresh, zero-trade terminal event census, and — most importantly for
durability — the hourly `farm_state.sqlite` backup. The 5-min pump now only
leaves a `{"db_backup": {"deferred": true}}` marker, so if this task is not
scheduled the backups silently stop. Register it hourly with
`install_pump_maintenance_scheduled_task.ps1`; freshness is monitored by
`chk_db_backup_fresh` in health.py.

Each run gets its own log file and a stale-tolerant lock, mirroring
run_pump_task.py. Maintenance never dispatches, promotes, enqueues, or alters
verdicts; it does write ea_metrics into the DB, so it honors FACTORY_OFF the
same way the pump does (quiescence during operator OFF windows — expected
backup pause is treated as OK by the health check).
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
LOCK_PATH = LOG_DIR / "pump_maintenance_task.lock"
LOCK_STALE_SECONDS = 55 * 60  # hourly cadence; clear a lock the next hour
FACTORY_OFF_FLAG = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")


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
    if FACTORY_OFF_FLAG.exists():
        return 0  # FACTORY_OFF.flag is set; maintenance writer is quiesced
    os.environ.setdefault("QM_AGENT_ID", "controller")
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    lock_fd = _acquire_lock()
    if lock_fd is None:
        return 0
    stamp = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
    log_path = LOG_DIR / f"pump_maintenance_task_{stamp}.log"
    try:
        with log_path.open("w", encoding="utf-8", newline="\n") as log:
            env = os.environ.copy()
            env.setdefault("QM_AGENT_ID", "controller")
            proc = subprocess.run(
                [_console_python(), str(FARMCTL), "pump-maintenance"],
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
