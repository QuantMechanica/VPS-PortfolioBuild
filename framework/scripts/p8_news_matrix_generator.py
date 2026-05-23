#!/usr/bin/env python3
"""Deprecated P8 news-matrix generator.

P8 is now a real MT5 news-mode rerun plus deal replay gate. This compatibility
entry point only writes a marker CSV so old runbooks/tests do not fail; it never
creates passable synthetic P8 metrics.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


MODES = [
    "disabled",
    "pause_high_impact",
    "pause_high_medium",
    "pause_all",
    "close_before_high",
    "close_before_all",
    "news_only",
]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", default="")
    ap.add_argument("--metrics-json", default="")
    ap.add_argument("--calendar-csv", default="")
    ap.add_argument("--out-prefix", default="")
    args = ap.parse_args()

    out_dir = Path(args.out_prefix or ".") / args.ea / "P7"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "news_matrix.csv"
    with out_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea", "symbol", "mode", "proxy_only", "deprecated_reason"])
        writer.writeheader()
        for mode in MODES:
            writer.writerow({
                "ea": args.ea,
                "symbol": args.symbol,
                "mode": mode,
                "proxy_only": 1,
                "deprecated_reason": "P8 requires p8_news_driver.py real MT5 news-mode reruns.",
            })
    print(out_path)
    return 0


if __name__ == "__main__":
    main()
