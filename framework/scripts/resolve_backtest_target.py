#!/usr/bin/env python3
"""Resolve target terminal for a backtest job."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from framework.scripts.pipeline_dispatcher import load_dispatch_state, resolve_target_terminal, save_dispatch_state


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Resolve target terminal for a backtest job.")
    parser.add_argument("--job-json", required=True, help="Path to JSON job payload.")
    parser.add_argument("--state-json", default=r"D:\QM\Reports\pipeline\dispatch_state.json", help="Dispatch state path.")
    parser.add_argument("--max-per-terminal", type=int, default=3, help="Max active runs per terminal.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    job_path = Path(args.job_json)
    with job_path.open("r", encoding="utf-8") as handle:
        job: dict[str, Any] = json.load(handle)

    state_path = Path(args.state_json)
    state = load_dispatch_state(state_path)
    decision = resolve_target_terminal(job, state, max_per_terminal=args.max_per_terminal)
    if decision.get("status") == "scheduled":
        save_dispatch_state(state, state_path)
    print(json.dumps(decision, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
