#!/usr/bin/env python3
"""Deterministic preflight guard for qm-p4-montecarlo."""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

REPORT_ROOT = Path("D:/QM/reports/pipeline")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate P4 Monte Carlo prerequisites")
    p.add_argument("--ea-id", required=True, help="EA id, e.g. QM5_1003")
    return p.parse_args()


def main() -> int:
    p = parse_args()
    p35_report = REPORT_ROOT / p.ea_id / "P3.5" / "report.csv"
    if not p35_report.exists():
        p35_report = REPORT_ROOT / p.ea_id / "P3_5" / "report.csv"

    pass_rows = []
    if p35_report.exists():
        with p35_report.open("r", encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                if row.get("verdict") == "PASS":
                    pass_rows.append(row)

    status = "ok" if pass_rows else "error"
    symbols = sorted({r.get("symbol", "") for r in pass_rows if r.get("symbol")})
    print(
        json.dumps(
            {
                "status": status,
                "ea_id": p.ea_id,
                "checks": {
                    "p35_report_exists": p35_report.exists(),
                    "p35_pass_count": len(pass_rows),
                },
                "eligible_symbols": symbols,
                "next_action": "run_p4_montecarlo_1000_passes" if pass_rows else "stop_no_p35_pass",
            },
            indent=2,
        )
    )
    return 0 if status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())
