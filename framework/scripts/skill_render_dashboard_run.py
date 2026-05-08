#!/usr/bin/env python3
"""Deterministic runner for qm-render-dashboard."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

OPS_DIR = Path("C:/QM/paperclip/tools/ops")
DASH_DIR = Path("C:/QM/paperclip/dashboards")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render Paperclip dashboards with sanity checks")
    parser.add_argument("--include-strategies", action="store_true", help="Also render strategies.html")
    parser.add_argument("--min-bytes", type=int, default=10_000, help="Minimum expected file size")
    return parser.parse_args()


def run_cmd(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=OPS_DIR, capture_output=True, text=True)


def main() -> int:
    args = parse_args()
    checks: dict[str, object] = {"ops_dir_exists": OPS_DIR.exists(), "dash_dir_exists": DASH_DIR.exists()}
    if not all(checks.values()):
        print(json.dumps({"status": "error", "checks": checks}, indent=2))
        return 2

    runs = []
    main_run = run_cmd([sys.executable, "render_dashboard.py"])
    runs.append({"command": "render_dashboard.py", "returncode": main_run.returncode})
    if main_run.returncode != 0:
        print(json.dumps({"status": "error", "checks": checks, "runs": runs, "stderr": main_run.stderr[-4000:]}, indent=2))
        return main_run.returncode

    if args.include_strategies:
        strategies_run = run_cmd([sys.executable, "render_strategies.py"])
        runs.append({"command": "render_strategies.py", "returncode": strategies_run.returncode})
        if strategies_run.returncode != 0:
            print(
                json.dumps(
                    {"status": "error", "checks": checks, "runs": runs, "stderr": strategies_run.stderr[-4000:]},
                    indent=2,
                )
            )
            return strategies_run.returncode

    artifacts = []
    for name in ["current.html", "strategies.html"]:
        path = DASH_DIR / name
        exists = path.exists()
        size = path.stat().st_size if exists else 0
        artifacts.append({"name": name, "exists": exists, "size_bytes": size})

    status = "ok"
    if any(not a["exists"] for a in artifacts):
        status = "warning"
    elif any(a["size_bytes"] < args.min_bytes for a in artifacts if a["name"] == "current.html" or args.include_strategies):
        status = "warning"

    print(
        json.dumps(
            {
                "status": status,
                "checks": checks,
                "runs": runs,
                "artifacts": artifacts,
                "next_action": "publish_dashboard_snapshot",
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
