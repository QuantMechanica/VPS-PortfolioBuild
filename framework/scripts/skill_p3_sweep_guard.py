#!/usr/bin/env python3
"""Deterministic preflight guard for qm-p3-sweep."""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

REPORT_ROOT = Path("D:/QM/reports/pipeline")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Validate P3 sweep prerequisites")
    p.add_argument("--ea-id", required=True, help="EA id, e.g. QM5_1003")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    p2_report = REPORT_ROOT / args.ea_id / "P2" / "report.csv"

    pass_symbols = []
    if p2_report.exists():
        with p2_report.open("r", encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                if row.get("verdict") == "PASS":
                    pass_symbols.append(row.get("symbol", ""))

    status = "ok" if pass_symbols else "error"
    next_action = "run_p3_sweep_on_pass_symbols" if pass_symbols else "stop_no_p2_pass_symbols"

    print(
        json.dumps(
            {
                "status": status,
                "ea_id": args.ea_id,
                "checks": {
                    "p2_report_exists": p2_report.exists(),
                    "p2_pass_symbol_count": len(pass_symbols),
                },
                "pass_symbols": pass_symbols,
                "next_action": next_action,
            },
            indent=2,
        )
    )
    return 0 if status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())
