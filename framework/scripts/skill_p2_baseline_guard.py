#!/usr/bin/env python3
"""Deterministic preflight guard for qm-p2-baseline."""
from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timedelta
from pathlib import Path

# Canonical source of truth — always main repo, override via QM_REPO_ROOT for tests.
# DL-062 + DL-028 — guards must agree with launchers across worktrees.
REPO_ROOT = Path(os.environ.get("QM_REPO_ROOT", r"C:\QM\repo"))
EA_ROOT = REPO_ROOT / "framework" / "EAs"
REPORT_ROOT = Path("D:/QM/reports/pipeline")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate P2 baseline prerequisites")
    p.add_argument("--ea-label", required=True, help="EA folder label, e.g. QM5_1003_davey_baseline_3bar")
    p.add_argument("--fresh-minutes", type=int, default=30, help="Fresh report threshold for in-progress detection")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    ea_dir = EA_ROOT / args.ea_label
    ex5 = ea_dir / f"{args.ea_label}.ex5"
    sets_dir = ea_dir / "sets"

    ea_id = args.ea_label.split("_")[0] + "_" + args.ea_label.split("_")[1] if args.ea_label.startswith("QM5_") else args.ea_label
    p2_dir = REPORT_ROOT / ea_id / "P2"

    set_count = len(list(sets_dir.glob("*.set"))) if sets_dir.exists() else 0
    recent_cutoff = datetime.now() - timedelta(minutes=args.fresh_minutes)
    recent_reports = []
    if p2_dir.exists():
        for htm in p2_dir.rglob("*.htm"):
            mtime = datetime.fromtimestamp(htm.stat().st_mtime)
            if mtime >= recent_cutoff:
                recent_reports.append(str(htm))

    checks = {
        "ea_dir_exists": ea_dir.exists(),
        "ex5_exists": ex5.exists(),
        "sets_dir_exists": sets_dir.exists(),
        "setfile_count": set_count,
        "p2_dir_exists": p2_dir.exists(),
        "recent_report_count": len(recent_reports),
    }

    status = "ok"
    next_action = "run_p2_baseline"
    if not checks["ea_dir_exists"] or not checks["ex5_exists"]:
        status = "error"
        next_action = "build_ea_first"
    elif set_count == 0:
        status = "error"
        next_action = "generate_setfiles_first"
    elif recent_reports:
        status = "warning"
        next_action = "wait_or_resume_existing_p2"

    print(
        json.dumps(
            {
                "status": status,
                "checks": checks,
                "ea_id": ea_id,
                "p2_dir": str(p2_dir),
                "sample_recent_reports": recent_reports[:5],
                "next_action": next_action,
            },
            indent=2,
        )
    )
    return 0 if status in {"ok", "warning"} else 2


if __name__ == "__main__":
    raise SystemExit(main())
