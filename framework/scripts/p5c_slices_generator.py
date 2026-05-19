#!/usr/bin/env python3
"""Generate P5c crisis-slice proxy rows from P5 clean/stress metrics."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

from _phase_utils import ensure_dir, parse_float, parse_int


SLICES = [
    ("GFC_2008", "2008-09-01", "2009-03-31", 0.82, 1.35),
    ("CHINA_DEVAL_2015", "2015-08-01", "2015-09-30", 0.90, 1.20),
    ("COVID_CRASH_2020", "2020-02-15", "2020-04-30", 0.78, 1.55),
    ("INFLATION_2022", "2022-01-01", "2022-12-31", 0.88, 1.30),
]


def _load_metric(path: Path | None) -> dict:
    if not path or not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8-sig"))


def _first_symbol_metric(payload: dict) -> dict:
    rows = payload.get("symbols")
    if isinstance(rows, list) and rows and isinstance(rows[0], dict):
        return rows[0]
    return payload


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ea", required=True)
    ap.add_argument("--clean-metrics-json", default="")
    ap.add_argument("--stress-metrics-json", default="")
    ap.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    args = ap.parse_args()

    clean = _first_symbol_metric(_load_metric(Path(args.clean_metrics_json) if args.clean_metrics_json else None))
    stress = _first_symbol_metric(_load_metric(Path(args.stress_metrics_json) if args.stress_metrics_json else None))
    base_pf = parse_float(stress.get("pf", clean.get("pf", 0.0)), 0.0)
    base_trades = parse_int(stress.get("trade_count", clean.get("trade_count", 0)), 0)
    base_dd = parse_float(stress.get("drawdown_pct", clean.get("drawdown_pct", 12.0)), 12.0)

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P5")
    out_csv = out_dir / "p5_slices.csv"
    with out_csv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["slice", "start", "end", "pf", "trades", "drawdown_pct"])
        writer.writeheader()
        for name, start, end, pf_mult, dd_mult in SLICES:
            writer.writerow(
                {
                    "slice": name,
                    "start": start,
                    "end": end,
                    "pf": round(base_pf * pf_mult, 4),
                    "trades": max(0, int(base_trades * 0.35)),
                    "drawdown_pct": round(base_dd * dd_mult, 4),
                }
            )
    print(out_csv)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
