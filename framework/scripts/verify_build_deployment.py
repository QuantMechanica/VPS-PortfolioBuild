#!/usr/bin/env python3
"""Verify EA build artifacts exist to prevent ghost-build enqueue.

Usage:
  python framework/scripts/verify_build_deployment.py --ea-id 1039 --ea-dir-glob "*singh*swap*fly*"
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


MIN_EX5_SIZE_BYTES = 50 * 1024


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--ea-id", required=True)
    p.add_argument("--ea-dir-glob", required=True)
    p.add_argument("--repo-root", default=None)
    p.add_argument("--min-ex5-bytes", type=int, default=MIN_EX5_SIZE_BYTES)
    return p.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.repo_root).resolve() if args.repo_root else Path(__file__).resolve().parents[2]
    eas_root = root / "framework" / "EAs"

    result: dict[str, object] = {
        "ea_id": str(args.ea_id),
        "ea_dir_glob": args.ea_dir_glob,
        "checks": {},
        "verdict": "",
        "exit_code": 1,
        "evidence": {},
    }

    ea_dirs = sorted([p for p in eas_root.glob(args.ea_dir_glob) if p.is_dir()]) if eas_root.exists() else []
    result["evidence"] = {"ea_dirs": [str(p.relative_to(root)) for p in ea_dirs]}

    checks = result["checks"]
    assert isinstance(checks, dict)

    checks["ea_dir_exists"] = len(ea_dirs) > 0
    if not checks["ea_dir_exists"]:
        result["verdict"] = "GHOST_BUILD"
        print(json.dumps(result, indent=2))
        return 1

    ex5_candidates: list[Path] = []
    for d in ea_dirs:
        ex5_candidates.extend(sorted(d.glob("*.ex5")))

    checks["ex5_exists"] = len(ex5_candidates) > 0
    checks["ex5_size_gt_min"] = any(p.stat().st_size > args.min_ex5_bytes for p in ex5_candidates)

    ex5_evidence = [
        {
            "path": str(p.relative_to(root)),
            "size": p.stat().st_size,
        }
        for p in ex5_candidates
    ]
    assert isinstance(result["evidence"], dict)
    result["evidence"]["ex5_files"] = ex5_evidence

    if checks["ex5_exists"] and checks["ex5_size_gt_min"]:
        result["verdict"] = "PASS"
        result["exit_code"] = 0
        print(json.dumps(result, indent=2))
        return 0

    result["verdict"] = "GHOST_BUILD"
    print(json.dumps(result, indent=2))
    return 1


if __name__ == "__main__":
    sys.exit(main())
