"""Scheduled-task wrapper for the strategy-farm agent router.

This is the autonomous control tick for capability-based agent tickets. It
does not spawn Claude directly and does not execute MT5 terminals. The router
only replenishes low strategy backlog and assigns waiting agent_tasks according
to capabilities, budgets, WIP limits, and guardrails.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys
import threading
from pathlib import Path


REPO_ROOT = Path(r"C:\QM\repo")
LOG_DIR = Path(r"D:\QM\strategy_farm\logs")

# 2026-08-10: two concurrent router processes froze mid-read for 45+ minutes
# while the scheduled task stayed 'Running', which starved Factory_ON's
# post-start health gate into its 1800s timeout and rolled the whole restart
# back. The wrapper therefore enforces two liveness contracts:
#  - a hard wall-clock watchdog, so a frozen run always terminates the task
#    (the 5-minute cadence then retries with a fresh process), and
#  - single-instance takeover, so a stale concurrent router (whatever spawned
#    it) is killed instead of contending with this run forever. A young
#    concurrent instance is respected with a benign skip.
WALL_CLOCK_TIMEOUT_SECONDS = 600
STALE_ROUTER_TAKEOVER_SECONDS = 900
CREATE_NO_WINDOW = 0x08000000

if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.strategy_farm import agent_router  # noqa: E402


def _write_log(log_path: Path, payload: dict) -> None:
    try:
        log_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    except OSError:
        pass


def _arm_wall_clock_watchdog(log_path: Path) -> None:
    def _abort() -> None:
        # 2026-08-13: dump every thread's stack BEFORE dying. Three SYSTEM-context
        # instances froze to this watchdog tonight while the identical run_once
        # completed in 60s interactively; the kill was eating the only evidence
        # of WHERE they freeze. The stack file turns the next freeze into a
        # diagnosis instead of a mystery.
        stack_path = log_path.with_suffix(".freeze_stack.txt")
        try:
            import faulthandler

            with open(stack_path, "w", encoding="utf-8") as stream:
                faulthandler.dump_traceback(file=stream, all_threads=True)
        except Exception:
            pass
        _write_log(
            log_path,
            {
                "ok": False,
                "error": "wall_clock_timeout",
                "timeout_seconds": WALL_CLOCK_TIMEOUT_SECONDS,
                "pid": os.getpid(),
                "freeze_stack": str(stack_path),
            },
        )
        os._exit(75)

    timer = threading.Timer(WALL_CLOCK_TIMEOUT_SECONDS, _abort)
    timer.daemon = True
    timer.start()


def _concurrent_router_processes() -> list[dict]:
    """Return other python processes whose command line mentions agent_router."""

    script = (
        "Get-CimInstance Win32_Process -Filter \"Name='python.exe' OR Name='pythonw.exe'\" | "
        f"Where-Object {{ $_.CommandLine -match 'agent_router' -and $_.ProcessId -ne {os.getpid()} }} | "
        "ForEach-Object { '{0}|{1}' -f $_.ProcessId, $_.CreationDate.ToUniversalTime().ToString('o') }"
    )
    try:
        proc = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
            capture_output=True,
            text=True,
            timeout=45,
            creationflags=CREATE_NO_WINDOW,
        )
    except (OSError, subprocess.SubprocessError):
        return []
    rows: list[dict] = []
    for line in (proc.stdout or "").splitlines():
        line = line.strip()
        if not line or "|" not in line:
            continue
        pid_text, created_text = line.split("|", 1)
        try:
            rows.append(
                {
                    "pid": int(pid_text),
                    "created_utc": dt.datetime.fromisoformat(created_text),
                }
            )
        except ValueError:
            continue
    return rows


def _kill_process_tree(pid: int) -> bool:
    try:
        proc = subprocess.run(
            ["taskkill", "/F", "/T", "/PID", str(pid)],
            capture_output=True,
            text=True,
            timeout=30,
            creationflags=CREATE_NO_WINDOW,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    return proc.returncode == 0


def main() -> int:
    os.environ.setdefault("QM_AGENT_ID", "controller")
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
    log_path = LOG_DIR / f"agent_router_task_{stamp}.json"
    _arm_wall_clock_watchdog(log_path)

    now = dt.datetime.now(dt.UTC)
    concurrent = _concurrent_router_processes()
    young = [
        row
        for row in concurrent
        if (now - row["created_utc"]).total_seconds() < STALE_ROUTER_TAKEOVER_SECONDS
    ]
    if young:
        _write_log(
            log_path,
            {
                "ok": True,
                "result": "skipped_concurrent_router",
                "concurrent_pids": [row["pid"] for row in young],
            },
        )
        return 0
    takeovers = []
    for row in concurrent:
        takeovers.append({"pid": row["pid"], "killed": _kill_process_tree(row["pid"])})

    try:
        result = agent_router.run_once(agent_router.DEFAULT_ROOT, max_routes=5)
        payload = {"ok": True, "result": result}
        rc = 0
    except Exception as exc:
        payload = {"ok": False, "error": repr(exc)}
        rc = 1
    if takeovers:
        payload["stale_router_takeovers"] = takeovers
    _write_log(log_path, payload)
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
