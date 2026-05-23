#!/usr/bin/env python3
"""Deterministic preflight guard for qm-run-pipeline-phase."""
from __future__ import annotations

import argparse
import csv
import json
import os
from pathlib import Path

# Canonical source of truth — DL-062 + DL-028.
REPO_ROOT = Path(os.environ.get("QM_REPO_ROOT", r"C:\QM\repo"))
EA_ROOT = REPO_ROOT / "framework" / "EAs"
MAGIC_CSV = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
VALID_PHASES = {"P3.5", "P5", "P5b", "P5c", "P6", "P7", "P8"}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate autonomous phase-run prerequisites")
    p.add_argument("--ea-id", required=True, help="EA id, e.g. QM5_1003")
    p.add_argument("--phase", required=True, help="One of P3.5,P5,P5b,P5c,P6,P7,P8")
    return p.parse_args()


def active_symbol_count(ea_id: str) -> int:
    if not MAGIC_CSV.exists():
        return 0
    n = 0
    with MAGIC_CSV.open("r", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            if row.get("ea_id") == ea_id and row.get("status") == "active":
                n += 1
    return n


def ex5_candidates(ea_id: str) -> list[Path]:
    return list(EA_ROOT.glob(f"{ea_id}_*/{ea_id}_*.ex5"))


def main() -> int:
    args = parse_args()
    phase_ok = args.phase in VALID_PHASES
    ex5s = ex5_candidates(args.ea_id)
    active_symbols = active_symbol_count(args.ea_id)

    checks = {
        "phase_valid": phase_ok,
        "magic_registry_exists": MAGIC_CSV.exists(),
        "active_symbol_count": active_symbols,
        "ex5_count": len(ex5s),
    }

    status = "ok"
    next_action = "run_phase_ps1"
    if not phase_ok:
        status = "error"
        next_action = "fix_phase_argument"
    elif len(ex5s) == 0:
        status = "error"
        next_action = "compile_ea_first"
    elif active_symbols == 0:
        status = "error"
        next_action = "fix_magic_registry"

    print(
        json.dumps(
            {
                "status": status,
                "ea_id": args.ea_id,
                "phase": args.phase,
                "checks": checks,
                "sample_ex5": [str(p) for p in ex5s[:3]],
                "next_action": next_action,
            },
            indent=2,
        )
    )
    return 0 if status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())
