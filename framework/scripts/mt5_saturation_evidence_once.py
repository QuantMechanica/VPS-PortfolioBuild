#!/usr/bin/env python3
"""Capture one deterministic MT5 saturation evidence bundle."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

if __package__ is None or __package__ == "":
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts.mt5_queue_status import queue_status
from framework.scripts.mt5_saturation_scheduler import run_tick


def _iso_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Capture before/tick/after MT5 saturation evidence.")
    parser.add_argument("--sqlite", required=True, help="Path to SQLite queue DB.")
    parser.add_argument("--dispatch-state", required=True, help="Path to dispatch_state.json.")
    parser.add_argument("--out", required=True, help="Output JSON artifact path.")
    parser.add_argument("--max-per-terminal", type=int, default=5)
    parser.add_argument("--scan-limit", type=int, default=500)
    parser.add_argument("--limit", type=int, default=5, help="Top rows limit in queue status snapshots.")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    sqlite_path = Path(args.sqlite)
    dispatch_state_path = Path(args.dispatch_state)
    out_path = Path(args.out)

    before = queue_status(sqlite_path, limit=args.limit)
    tick = run_tick(
        sqlite_path=sqlite_path,
        dispatch_state_path=dispatch_state_path,
        max_per_terminal=max(1, int(args.max_per_terminal)),
        scan_limit=max(1, int(args.scan_limit)),
        dry_run=bool(args.dry_run),
    )
    after = queue_status(sqlite_path, limit=args.limit)
    payload: dict[str, Any] = {
        "timestamp_utc": _iso_now(),
        "sqlite": str(sqlite_path),
        "dispatch_state": str(dispatch_state_path),
        "dry_run": bool(args.dry_run),
        "before": before,
        "tick": tick,
        "after": after,
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": "ok", "out": str(out_path)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
