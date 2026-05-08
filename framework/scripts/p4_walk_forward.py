#!/usr/bin/env python3
"""P4 walk-forward gate runner."""

from __future__ import annotations

import argparse
import csv
from datetime import date
from pathlib import Path

from _phase_utils import (
    add_common_args,
    build_result,
    ensure_dir,
    load_csv_rows,
    parse_bool_like,
    row_passes,
    update_result_with_evidence_path,
    write_phase_artifacts,
)


def _parse_date(text: str, field: str) -> date:
    raw = (text or "").strip()
    if not raw:
        raise ValueError(f"Missing required date field: {field}")
    try:
        return date.fromisoformat(raw)
    except ValueError as exc:
        raise ValueError(f"Invalid ISO date in {field}: {raw}") from exc


def _check_clean_oos(row: dict[str, str]) -> tuple[bool, str]:
    if "oos_clean" in row:
        clean = parse_bool_like(row.get("oos_clean"))
        return clean, "oos_clean"

    for key in ("verdict", "status", "result", "pass", "PASS"):
        if key in row:
            return row_passes(row), key

    return False, "missing"


def main() -> int:
    parser = argparse.ArgumentParser(description="Run P4 walk-forward gate checks.")
    add_common_args(parser)
    parser.add_argument("--walk-forward-csv", required=True)
    args = parser.parse_args()

    ea_id = args.ea
    out_dir = ensure_dir(Path(args.out_prefix) / ea_id / "P4")
    rows = load_csv_rows(Path(args.walk_forward_csv))

    fold_count = len(rows)
    verdict = "FAIL"
    criterion = "P4 requires >= 6 walk-forward folds with clean OOS evidence."
    issues: list[str] = []
    details_folds: list[dict[str, object]] = []
    first_dev_start: date | None = None
    last_oos_end: date | None = None

    last_dev_end: date | None = None
    last_oos_start: date | None = None
    anchored_start: date | None = None

    for i, row in enumerate(rows, start=1):
        fold_id = (row.get("fold_id") or str(i)).strip()
        regime = (row.get("regime") or "").strip()
        if not regime:
            issues.append(f"fold {fold_id}: missing regime label")

        dev_start = _parse_date(row.get("dev_start", ""), "dev_start")
        dev_end = _parse_date(row.get("dev_end", ""), "dev_end")
        oos_start = _parse_date(row.get("oos_start", ""), "oos_start")
        oos_end = _parse_date(row.get("oos_end", ""), "oos_end")

        if dev_end >= oos_start:
            issues.append(f"fold {fold_id}: DEV→HO embargo violated (dev_end >= oos_start)")
        if dev_start >= dev_end:
            issues.append(f"fold {fold_id}: invalid DEV window (dev_start >= dev_end)")
        if oos_start >= oos_end:
            issues.append(f"fold {fold_id}: invalid OOS window (oos_start >= oos_end)")

        if anchored_start is None:
            anchored_start = dev_start
        elif dev_start != anchored_start:
            issues.append(f"fold {fold_id}: not anchored (dev_start drift)")

        if last_dev_end is not None and dev_end <= last_dev_end:
            issues.append(f"fold {fold_id}: not anchored (dev_end not strictly increasing)")
        if last_oos_start is not None and oos_start <= last_oos_start:
            issues.append(f"fold {fold_id}: OOS start not strictly increasing")

        if first_dev_start is None:
            first_dev_start = dev_start
        last_oos_end = oos_end

        clean_ok, clean_source = _check_clean_oos(row)
        if not clean_ok:
            if clean_source == "missing":
                issues.append(
                    f"fold {fold_id}: missing explicit OOS cleanliness field "
                    "(expected oos_clean or pass/verdict/status/result)"
                )
            else:
                issues.append(f"fold {fold_id}: OOS not clean ({clean_source})")

        details_folds.append(
            {
                "fold_id": fold_id,
                "regime": regime,
                "dev_start": str(dev_start),
                "dev_end": str(dev_end),
                "oos_start": str(oos_start),
                "oos_end": str(oos_end),
                "oos_clean": clean_ok,
            }
        )

        last_dev_end = dev_end
        last_oos_start = oos_start

    if fold_count < 6:
        issues.append(f"fold count is {fold_count}; minimum is 6")
    if first_dev_start is None or first_dev_start > date(2017, 1, 1):
        issues.append("walk-forward coverage must start in 2017 or earlier")
    if last_oos_end is None or last_oos_end < date(2022, 12, 31):
        issues.append("walk-forward coverage must extend through 2022-12-31")

    if not issues:
        verdict = "PASS"
        criterion = "P4 passed: >=6 anchored folds, DEV→HO embargo intact, regime-labelled, clean OOS."

    result = build_result(
        phase="P4",
        ea_id=ea_id,
        verdict=verdict,
        criterion=criterion,
        evidence_path="",
        details={
            "fold_count": fold_count,
            "folds": details_folds,
            "issues": issues,
        },
    )

    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P4", ea_id=ea_id, result=result)
    update_result_with_evidence_path(result_path, result)
    report_csv = out_dir / "report.csv"
    with report_csv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["ea_id", "phase", "fold_id", "regime", "dev_start", "dev_end", "oos_start", "oos_end", "verdict"],
        )
        writer.writeheader()
        for fold in details_folds:
            writer.writerow(
                {
                    "ea_id": ea_id,
                    "phase": "P4",
                    "fold_id": fold["fold_id"],
                    "regime": fold["regime"],
                    "dev_start": fold["dev_start"],
                    "dev_end": fold["dev_end"],
                    "oos_start": fold["oos_start"],
                    "oos_end": fold["oos_end"],
                    "verdict": "PASS" if bool(fold["oos_clean"]) else "FAIL",
                }
            )
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
