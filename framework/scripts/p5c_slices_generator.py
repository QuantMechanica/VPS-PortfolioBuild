#!/usr/bin/env python3
"""Generate canonical P5c crisis-slice windows.

This file intentionally does not generate metrics. P5c metrics must come from
real MT5 runs over these date windows.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from _phase_utils import ensure_dir


SLICES = [
    ("GFC_2008", "2008.09.01", "2009.03.31"),
    ("CHINA_DEVAL_2015", "2015.08.01", "2015.09.30"),
    ("COVID_CRASH_2020", "2020.02.15", "2020.04.30"),
    ("INFLATION_2022", "2022.01.01", "2022.12.31"),
]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ea", required=True)
    ap.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    args = ap.parse_args()

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P5")
    out_csv = out_dir / "p5_slices.csv"
    with out_csv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["slice", "start", "end"])
        writer.writeheader()
        for name, start, end in SLICES:
            writer.writerow({"slice": name, "start": start, "end": end})
    print(out_csv)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
