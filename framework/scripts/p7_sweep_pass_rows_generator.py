#!/usr/bin/env python3
"""Generate P7 sweep_pass_rows.csv from P3/P2 evidence."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from _phase_utils import ensure_dir, load_csv_rows


def _pass_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    return [r for r in load_csv_rows(path) if str(r.get("verdict") or r.get("status") or "").upper() == "PASS"]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ea", required=True)
    ap.add_argument("--p3-report", required=True)
    ap.add_argument("--p2-report", default="")
    ap.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    args = ap.parse_args()

    p3_pass = _pass_rows(Path(args.p3_report))
    p2_pass = _pass_rows(Path(args.p2_report)) if args.p2_report else []
    unique_symbols = {str(r.get("symbol") or "").strip() for r in p3_pass + p2_pass if str(r.get("symbol") or "").strip()}
    pass_count = len(p3_pass)

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P3")
    out_csv = out_dir / "sweep_pass_rows.csv"
    with out_csv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "pass_rows", "symbol_count", "proxy_only"])
        writer.writeheader()
        writer.writerow(
            {
                "ea_id": args.ea,
                "pass_rows": pass_count,
                "symbol_count": len(unique_symbols),
                "proxy_only": "1",
            }
        )
    print(out_csv)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
