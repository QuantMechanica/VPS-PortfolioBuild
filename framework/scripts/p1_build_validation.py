#!/usr/bin/env python3
"""P1 build validation runner.

Checks whether EA build artifacts exist before downstream phases.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
EA_ROOT = REPO_ROOT / "framework" / "EAs"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate P1 build artifacts for an EA")
    p.add_argument("--ea", required=True, help="EA id, e.g. QM5_1014")
    return p.parse_args()


def main() -> int:
    a = parse_args()
    ea_prefix = f"{a.ea}_"

    matches = [d for d in EA_ROOT.iterdir() if d.is_dir() and d.name.startswith(ea_prefix)] if EA_ROOT.exists() else []
    ea_dir = matches[0] if matches else None
    ex5_exists = False
    if ea_dir is not None:
        ex5_exists = any(p.suffix.lower() == ".ex5" for p in ea_dir.glob("*.ex5"))

    checks = {
        "ea_root_exists": EA_ROOT.exists(),
        "ea_dir_exists": ea_dir is not None,
        "ex5_exists": ex5_exists,
    }

    ok = all(checks.values())
    payload = {
        "status": "ok" if ok else "error",
        "ea": a.ea,
        "ea_dir": str(ea_dir) if ea_dir else None,
        "checks": checks,
        "next_action": "run_p2" if ok else "build_ea_first",
    }
    print(json.dumps(payload, indent=2))
    return 0 if ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
