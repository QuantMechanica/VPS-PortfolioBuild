"""Read-only Claude re-enable preflight for Friday startup.

This script does not remove the disabled flag, start Claude, or change
scheduled tasks. It only reports whether the machine is in a sane state before
OWNER decides to spend Claude tokens again.
"""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from typing import Any

try:
    from tools.strategy_farm import agent_router, farmctl
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    import agent_router  # type: ignore
    import farmctl  # type: ignore


CLAUDE_TASK_NAMES = (
    "QM_StrategyFarm_BoardAdvisor_Hourly",
    "QM_StrategyFarm_AutonomousWake_Hourly",
)


def _claude_processes() -> list[dict[str, Any]]:
    try:
        result = subprocess.run(
            [
                "powershell.exe",
                "-NoProfile",
                "-Command",
                "Get-Process | Where-Object {$_.Name -match 'claude'} | "
                "Select-Object Id,Name,Path | ConvertTo-Json -Compress",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except Exception as exc:
        return [{"error": repr(exc)}]
    if result.returncode != 0 or not result.stdout.strip():
        return []
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return [{"error": "process_json_decode_failed"}]
    if isinstance(data, dict):
        data = [data]
    return data if isinstance(data, list) else []


def _scheduled_task_state(name: str) -> str:
    try:
        result = subprocess.run(
            ["schtasks.exe", "/Query", "/TN", name, "/FO", "LIST"],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except Exception as exc:
        return f"unknown:{exc!r}"
    if result.returncode != 0:
        return "missing_or_inaccessible"
    for line in result.stdout.splitlines():
        if line.lower().startswith("status:"):
            return line.split(":", 1)[1].strip()
    return "unknown"


def check(root: Path = farmctl.DEFAULT_ROOT, flag: Path = agent_router.CLAUDE_DISABLED_FLAG) -> dict[str, Any]:
    status = agent_router.status(root, claude_disabled_flag=flag)
    claude = next((row for row in status["agents"] if row["agent_id"] == "claude"), None)
    processes = _claude_processes()
    task_states = {name: _scheduled_task_state(name) for name in CLAUDE_TASK_NAMES}
    flag_exists = flag.exists()
    cap_after_flag_removed = agent_router.DEFAULT_AGENT_REGISTRY["claude"]["max_parallel"]

    checks = [
        {
            "name": "disabled_flag_present",
            "status": "FAIL" if flag_exists else "OK",
            "detail": str(flag),
        },
        {
            "name": "unexpected_claude_processes",
            "status": "FAIL" if processes else "OK",
            "detail": processes,
        },
        {
            "name": "router_cap_after_flag_removed",
            "status": "OK" if cap_after_flag_removed == 3 else "FAIL",
            "detail": cap_after_flag_removed,
        },
        {
            "name": "router_current_claude_state",
            "status": "OK" if claude and (flag_exists or claude["enabled"]) else "FAIL",
            "detail": claude,
        },
        {
            "name": "scheduled_task_visibility",
            "status": "OK",
            "detail": task_states,
        },
    ]
    overall = "PASS" if all(row["status"] == "OK" for row in checks) else "BLOCKED"
    return {
        "overall": overall,
        "root": str(root),
        "flag": str(flag),
        "checks": checks,
        "next_action": (
            "OWNER may remove the flag, then run agent_router.py status and enqueue-friday-smoke"
            if overall == "PASS"
            else "Resolve FAIL checks before spending Claude tokens"
        ),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=farmctl.DEFAULT_ROOT)
    parser.add_argument("--flag", type=Path, default=agent_router.CLAUDE_DISABLED_FLAG)
    args = parser.parse_args(argv)
    result = check(args.root, args.flag)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["overall"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
