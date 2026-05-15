#!/usr/bin/env python3
"""P1 build validation runner.

Checks whether EA build artifacts exist before downstream phases.
Writes the canonical phase result file so the Phase Orchestrator can advance
or block the EA on subsequent fires (without this, P1 looped indefinitely
because no result.json was ever written).
"""
from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
EA_ROOT = REPO_ROOT / "framework" / "EAs"
PIPELINE_ROOT = Path(r"D:/QM/reports/pipeline")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate P1 build artifacts for an EA")
    p.add_argument("--ea", required=True, help="EA id, e.g. QM5_1014")
    return p.parse_args()


def write_result(ea: str, payload: dict) -> Path:
    out_dir = PIPELINE_ROOT / ea / "P1"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / f"P1_{ea}_result.json"
    tmp = out_file.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    os.replace(tmp, out_file)
    return out_file


def main() -> int:
    a = parse_args()
    ea_prefix = f"{a.ea}_"

    exact_dir = (EA_ROOT / a.ea) if EA_ROOT.exists() else None
    matches = [d for d in EA_ROOT.iterdir() if d.is_dir() and d.name.startswith(ea_prefix)] if EA_ROOT.exists() else []
    matches = sorted(matches, key=lambda d: (d.name.endswith("_build"), d.name))

    if exact_dir is not None and exact_dir.is_dir():
        ea_dir = exact_dir
    else:
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
    # Canonical phase result file (PIPELINE_PHASE_SPEC.md naming).
    # Phase Orchestrator reads this to decide whether to advance to P2.
    payload = {
        "ea": a.ea,
        "phase": "P1",
        "verdict": "PASS" if ok else "FAIL",
        "criterion": "EA dir + .ex5 binary present under framework/EAs/",
        "checks": checks,
        "ea_dir": str(ea_dir) if ea_dir else None,
        "next_action": "run_p2" if ok else "build_ea_first",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "status": "ok" if ok else "error",
    }
    result_path = write_result(a.ea, payload)
    payload["evidence_path"] = str(result_path)
    print(json.dumps(payload, indent=2))
    return 0 if ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
