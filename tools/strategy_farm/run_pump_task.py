"""Scheduled-task wrapper for the strategy farm pump.

Task Scheduler should invoke this script directly with python.exe. It gives
each pump run its own log file so long-running child processes cannot keep the
next scheduled run from opening a shared redirected log.
"""

from __future__ import annotations

import datetime as dt
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(r"C:\QM\repo")
LOG_DIR = Path(r"D:\QM\strategy_farm\logs")
FARMCTL = REPO_ROOT / "tools" / "strategy_farm" / "farmctl.py"


def main() -> int:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
    log_path = LOG_DIR / f"pump_task_{stamp}.log"
    with log_path.open("w", encoding="utf-8", newline="\n") as log:
        proc = subprocess.run(
            [sys.executable, str(FARMCTL), "pump"],
            cwd=str(REPO_ROOT),
            stdout=log,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            close_fds=True,
        )
    return int(proc.returncode)


if __name__ == "__main__":
    raise SystemExit(main())
