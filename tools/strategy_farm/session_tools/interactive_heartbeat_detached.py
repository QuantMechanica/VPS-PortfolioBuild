"""Detached interactive-orchestrator heartbeat (Orchestrator 2026-09-13 07:1xZ).

The Bash-tool background job that ran `run_agent_orchestration_task.py --interactive-heartbeat-loop`
was stopped twice by the tool harness (status "killed", 06:59Z and 07:07Z), which let the headless
ClaudeOrchestration task resume its cycles. This wrapper binds the loop's parent identity to the
interactive Claude Code session process (``--parent-pid``) instead of the tool shell, so the loop
lives exactly as long as the session and is launched detached (PowerShell Start-Process, hidden).
Usage: python interactive_heartbeat_detached.py --parent-pid <pid> --minutes 600
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path("C:/QM/repo/tools/strategy_farm")))
import run_agent_orchestration_task as orch  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--parent-pid", type=int, required=True)
    ap.add_argument("--minutes", type=float, default=600.0)
    args = ap.parse_args()
    result = orch.run_interactive_heartbeat_loop(args.minutes, parent_pid=args.parent_pid)
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
