#!/usr/bin/env python3
"""P4 anchored walk-forward fold generator.

Emits walk_forward_folds.csv for a given EA: anchored train windows
(always starting from --train-from-year) growing forward, OOS windows
of --fold-months length, DEV->HO embargo of --embargo-days days.

PHASE_CHAIN_BUILD_PLAN_2026-05-19 step 1A. Regime classification is
stub (UNCLASSIFIED) — separate component will populate.

Usage:
  python p4_fold_generator.py --ea QM5_1056 --out-prefix D:/QM/reports/pipeline \\
    --train-from-year 2017 --oos-from-year 2023 --oos-to-year 2025 \\
    --fold-months 6 --embargo-days 7 --min-folds 6
"""

from __future__ import annotations

import argparse
import csv
import sys
from datetime import date, timedelta
from pathlib import Path


FIELDNAMES = ["ea_id", "fold_id", "regime", "dev_start", "dev_end", "oos_start", "oos_end"]


def _add_months(d: date, months: int) -> date:
    month_zero = d.month - 1 + months
    year = d.year + month_zero // 12
    month = month_zero % 12 + 1
    # always anchor to first of month for fold cadence
    return date(year, month, 1)


def generate_folds(
    *,
    ea_id: str,
    train_from_year: int,
    oos_from_year: int,
    oos_to_year: int,
    fold_months: int,
    embargo_days: int,
    min_folds: int,
) -> list[dict[str, str]]:
    train_start = date(train_from_year, 1, 1)
    folds: list[dict[str, str]] = []
    cur_oos_start = date(oos_from_year, 1, 1)
    oos_window_end_limit = date(oos_to_year, 12, 31)
    fold_idx = 1
    while True:
        oos_end = _add_months(cur_oos_start, fold_months) - timedelta(days=1)
        if oos_end > oos_window_end_limit:
            oos_end = oos_window_end_limit
        dev_end = cur_oos_start - timedelta(days=embargo_days)
        if dev_end <= train_start:
            break
        folds.append({
            "ea_id": ea_id,
            "fold_id": f"F{fold_idx}",
            "regime": "UNCLASSIFIED",
            "dev_start": train_start.isoformat(),
            "dev_end": dev_end.isoformat(),
            "oos_start": cur_oos_start.isoformat(),
            "oos_end": oos_end.isoformat(),
        })
        if oos_end >= oos_window_end_limit:
            break
        cur_oos_start = _add_months(cur_oos_start, fold_months)
        fold_idx += 1
    if len(folds) < min_folds:
        raise ValueError(
            f"only {len(folds)} folds produced; need >= {min_folds}. "
            f"Increase oos_to_year or reduce fold_months."
        )
    return folds


def main() -> int:
    parser = argparse.ArgumentParser(description="P4 anchored walk-forward fold generator")
    parser.add_argument("--ea", required=True)
    parser.add_argument("--out-prefix", required=True)
    parser.add_argument("--train-from-year", type=int, default=2017)
    parser.add_argument("--oos-from-year", type=int, default=2023)
    parser.add_argument("--oos-to-year", type=int, default=2025)
    parser.add_argument("--fold-months", type=int, default=6)
    parser.add_argument("--embargo-days", type=int, default=7)
    parser.add_argument("--min-folds", type=int, default=6)
    args = parser.parse_args()

    folds = generate_folds(
        ea_id=args.ea,
        train_from_year=args.train_from_year,
        oos_from_year=args.oos_from_year,
        oos_to_year=args.oos_to_year,
        fold_months=args.fold_months,
        embargo_days=args.embargo_days,
        min_folds=args.min_folds,
    )

    out_dir = Path(args.out_prefix) / args.ea / "P4"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_csv = out_dir / "walk_forward_folds.csv"
    with out_csv.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        for fold in folds:
            writer.writerow(fold)
    print(str(out_csv.resolve()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
