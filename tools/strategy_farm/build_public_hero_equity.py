#!/usr/bin/env python3
"""build_public_hero_equity.py — generate public-data/hero-equity.json

Ported verbatim (same algorithm) from the deploy-side
``tools/site-build/build_public_charts.py`` into the main repo so the hero
equity curve is produced by the governed hourly public snapshot pipeline
instead of a hand-run deploy script.

Reads the Q10-passed sleeve set's daily return series, sums the sleeves into one
aggregate curve, cumulates, rebases to index 100 at the first date, samples
weekly (Fridays plus the first and last date) and writes an additive
public-data JSON.

The OUTPUT deliberately carries NO sleeve names, EA ids, symbols, EUR amounts or
file paths — only an aggregate index series, a sleeve count, a basis string and
a timestamp.  The disclosure level of the public archive stays
``terminal_pass_fail_without_metrics``.

Run:
    python tools/strategy_farm/build_public_hero_equity.py            # write file
    python tools/strategy_farm/build_public_hero_equity.py --stdout   # JSON only
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import glob
import json
import os
import sys
from collections import defaultdict

# --- source (build-time only; never referenced from anything under Website/) ---
SOURCE_DIR = r"D:/QM/reports/portfolio/invvol_stage1_20260804/daily"
SOURCE_GLOB = "*_daily_returns.csv"
RETURN_COLUMN = "daily_return_eur_at_RISK_FIXED_1000"

# per-sleeve RISK_FIXED notional; the aggregate book's base = N_sleeves * this
RISK_FIXED_NOTIONAL = 1000.0

# --- output (inside the repo public-data dir; must stay clean) ---
_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.normpath(os.path.join(_HERE, "..", ".."))
DEFAULT_OUT_PATH = os.path.normpath(
    os.path.join(_REPO_ROOT, "public-data", "hero-equity.json")
)

BASIS = (
    "illustrative combined backtest of the Q10-passed sleeve set, "
    "RISK_FIXED-normalised, not live"
)

SIZE_BUDGET_BYTES = 60 * 1024


def load_sleeves(source_dir: str) -> tuple[dict[str, float], int]:
    """Sum the daily EUR return of every sleeve into one per-date aggregate."""
    files = sorted(glob.glob(os.path.join(source_dir, SOURCE_GLOB)))
    if not files:
        raise SystemExit(f"no sleeve CSVs found under {source_dir!r}")

    agg: dict[str, float] = defaultdict(float)
    for path in files:
        with open(path, newline="") as fh:
            reader = csv.DictReader(fh)
            if RETURN_COLUMN not in (reader.fieldnames or []):
                raise SystemExit(
                    f"{os.path.basename(path)}: missing column {RETURN_COLUMN!r}"
                )
            for row in reader:
                date = (row.get("date") or "").strip()
                if not date:
                    continue
                try:
                    agg[date] += float(row[RETURN_COLUMN])
                except (TypeError, ValueError):
                    # a blank / malformed cell contributes nothing
                    continue
    return agg, len(files)


def build_series(agg: dict[str, float], sleeves: int) -> list[list]:
    """Cumulative sum -> index 100 at first date -> weekly (Friday) sample."""
    dates = sorted(agg)
    if not dates:
        raise SystemExit("aggregate is empty")

    base_notional = sleeves * RISK_FIXED_NOTIONAL

    # cumulative EUR P&L and the index rebased to 100 at the first date
    index_by_date: dict[str, float] = {}
    running = 0.0
    for d in dates:
        running += agg[d]
        index_by_date[d] = 100.0 * (base_notional + running) / base_notional

    first, last = dates[0], dates[-1]

    # anchor (first date, exactly 100) + every Friday + final date, de-duplicated
    keep: list[str] = [first]
    for d in dates:
        if dt.date.fromisoformat(d).weekday() == 4:  # Friday
            keep.append(d)
    if last not in keep:
        keep.append(last)

    seen: set[str] = set()
    series: list[list] = []
    for d in sorted(keep):
        if d in seen:
            continue
        seen.add(d)
        series.append([d, round(index_by_date[d], 2)])
    return series


def build_payload(source_dir: str = SOURCE_DIR) -> dict:
    """Assemble the public hero-equity payload (pure; writes nothing)."""
    agg, sleeves = load_sleeves(source_dir)
    series = build_series(agg, sleeves)
    return {
        "schema_version": 1,
        "generated_at": dt.datetime.now(dt.timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z"),
        "basis": BASIS,
        "sleeves": sleeves,
        "series": series,
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Build public hero-equity JSON.")
    ap.add_argument("--source-dir", default=SOURCE_DIR)
    ap.add_argument("--out", default=DEFAULT_OUT_PATH)
    ap.add_argument(
        "--stdout",
        action="store_true",
        help="emit the compact JSON on stdout and write no file",
    )
    args = ap.parse_args(argv)

    payload = build_payload(args.source_dir)
    encoded = json.dumps(payload, separators=(",", ":"))

    if args.stdout:
        # Single compact JSON line for the PowerShell exporter to capture.
        sys.stdout.write(encoded + "\n")
        return 0

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", newline="\n") as fh:
        fh.write(encoded)
        fh.write("\n")

    series = payload["series"]
    size = os.path.getsize(args.out)
    first_d, first_i = series[0]
    last_d, last_i = series[-1]
    idx_vals = [p[1] for p in series]
    print(f"wrote {args.out}")
    print(f"  sleeves={payload['sleeves']} points={len(series)} size={size} bytes")
    print(f"  {first_d} index {first_i}  ->  {last_d} index {last_i}")
    print(f"  index min {min(idx_vals)}  max {max(idx_vals)}")
    if size >= SIZE_BUDGET_BYTES:
        print(f"WARNING: output {size} bytes exceeds 60 KB budget", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
