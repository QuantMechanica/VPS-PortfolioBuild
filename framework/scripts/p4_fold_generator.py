#!/usr/bin/env python3
"""Generate anchored P4 walk-forward fold windows."""

from __future__ import annotations

import argparse
import csv
import sys
from datetime import date, timedelta
from pathlib import Path

from _phase_utils import ensure_dir

CSV_COLUMNS = ["ea_id", "fold_id", "regime", "dev_start", "dev_end", "oos_start", "oos_end"]


def _add_months(value: date, months: int) -> date:
    month_index = value.month - 1 + months
    year = value.year + month_index // 12
    month = month_index % 12 + 1
    return date(year, month, value.day)


def _generate_folds(
    *,
    ea_id: str,
    train_from_year: int,
    oos_from_year: int,
    oos_to_year: int,
    fold_months: int,
    embargo_days: int,
) -> list[dict[str, str]]:
    train_start = date(train_from_year, 1, 1)
    oos_start = date(oos_from_year, 1, 1)
    final_oos_end = date(oos_to_year, 12, 31)
    folds: list[dict[str, str]] = []

    while oos_start <= final_oos_end:
        next_oos_start = _add_months(oos_start, fold_months)
        oos_end = min(next_oos_start - timedelta(days=1), final_oos_end)
        dev_end = oos_start - timedelta(days=embargo_days + 1)

        folds.append(
            {
                "ea_id": ea_id,
                "fold_id": f"F{len(folds) + 1}",
                # TODO regime classification via benchmark-symbol trend/range heuristic (separate component).
                "regime": "UNCLASSIFIED",
                "dev_start": train_start.isoformat(),
                "dev_end": dev_end.isoformat(),
                "oos_start": oos_start.isoformat(),
                "oos_end": oos_end.isoformat(),
            }
        )
        oos_start = next_oos_start

    return folds


def _positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be > 0")
    return parsed


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate P4 anchored walk-forward fold windows.")
    parser.add_argument("--ea", required=True, help="EA identifier, e.g. QM5_1056")
    parser.add_argument("--out-prefix", default="D:/QM/reports/pipeline", help="Output directory root")
    parser.add_argument("--train-from-year", type=int, default=2017)
    parser.add_argument("--oos-from-year", type=int, default=2023)
    parser.add_argument("--oos-to-year", type=int, default=2025)
    parser.add_argument("--fold-months", type=_positive_int, default=6)
    parser.add_argument("--embargo-days", type=_positive_int, default=7)
    parser.add_argument("--min-folds", type=_positive_int, default=6)
    args = parser.parse_args()

    try:
        if args.oos_to_year < args.oos_from_year:
            raise ValueError("--oos-to-year must be >= --oos-from-year")
        if 12 % args.fold_months != 0:
            raise ValueError("--fold-months must divide 12 for calendar-aligned OOS windows")

        rows = _generate_folds(
            ea_id=args.ea,
            train_from_year=args.train_from_year,
            oos_from_year=args.oos_from_year,
            oos_to_year=args.oos_to_year,
            fold_months=args.fold_months,
            embargo_days=args.embargo_days,
        )
        if len(rows) < args.min_folds:
            raise ValueError(f"generated {len(rows)} folds; minimum required is {args.min_folds}")

        out_dir = ensure_dir(Path(args.out_prefix).resolve() / args.ea / "P4")
        csv_path = out_dir / "walk_forward_folds.csv"
        with csv_path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=CSV_COLUMNS)
            writer.writeheader()
            writer.writerows(rows)

        print(csv_path)
        return 0
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
