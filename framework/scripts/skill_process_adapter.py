#!/usr/bin/env python3
"""Process-adapter entrypoint for deterministic QM skill scripts."""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "framework" / "scripts"

SKILL_SCRIPT_MAP = {
    "qm-p2-baseline-guard": "skill_p2_baseline_guard.py",
    "qm-p3-sweep-guard": "skill_p3_sweep_guard.py",
    "qm-p4-montecarlo-guard": "skill_p4_montecarlo_guard.py",
    "qm-p4-montecarlo-run": "p4_montecarlo.py",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run deterministic QM skill scripts through a single process-adapter entrypoint."
    )
    parser.add_argument(
        "--skill",
        required=True,
        choices=sorted(SKILL_SCRIPT_MAP.keys()),
        help="Skill operation alias to execute.",
    )
    parser.add_argument(
        "script_args",
        nargs=argparse.REMAINDER,
        help="Arguments forwarded to the underlying deterministic script. Prefix with --.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    script_name = SKILL_SCRIPT_MAP[args.skill]
    script_path = SCRIPTS_DIR / script_name
    forwarded_args = args.script_args
    if forwarded_args and forwarded_args[0] == "--":
        forwarded_args = forwarded_args[1:]

    cmd = [sys.executable, str(script_path), *forwarded_args]
    completed = subprocess.run(cmd, check=False)
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
