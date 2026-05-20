"""Scheduled-task wrapper for the strategy-farm agent router.

This is the autonomous control tick for capability-based agent tickets. It
does not spawn Claude directly and does not execute MT5 terminals. The router
only replenishes low strategy backlog and assigns waiting agent_tasks according
to capabilities, budgets, WIP limits, and guardrails.
"""

from __future__ import annotations

import datetime as dt
import json
import sys
from pathlib import Path


REPO_ROOT = Path(r"C:\QM\repo")
LOG_DIR = Path(r"D:\QM\strategy_farm\logs")

if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.strategy_farm import agent_router  # noqa: E402


def main() -> int:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y%m%dT%H%M%SZ")
    log_path = LOG_DIR / f"agent_router_task_{stamp}.json"
    try:
        result = agent_router.run_once(agent_router.DEFAULT_ROOT, max_routes=5)
        payload = {"ok": True, "result": result}
        rc = 0
    except Exception as exc:
        payload = {"ok": False, "error": repr(exc)}
        rc = 1
    log_path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
