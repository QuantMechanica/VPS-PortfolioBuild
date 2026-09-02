#!/usr/bin/env python3
"""Append an evidence-bound COMPILE_EA retry after stale build binding failure."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

try:
    import compile_work_items
except ModuleNotFoundError:
    from tools.strategy_farm import compile_work_items


DEFAULT_ROOT = Path(
    os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm")
)
REPO_ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Retry one unchanged-source COMPILE_EA predecessor that failed only "
            "because its bound build task was no longer open."
        )
    )
    parser.add_argument("--predecessor", required=True, help="Failed COMPILE_EA work-item ID")
    parser.add_argument("--build-task-id", required=True, help="Sole open build_ea task for the same EA")
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--apply", action="store_true", help="Append the successor; default is dry-run")
    args = parser.parse_args()

    result = compile_work_items.enqueue_recheck_successor(
        args.root,
        REPO_ROOT,
        args.predecessor,
        args.build_task_id,
        apply=args.apply,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result.get("ok") else 2


if __name__ == "__main__":
    raise SystemExit(main())
