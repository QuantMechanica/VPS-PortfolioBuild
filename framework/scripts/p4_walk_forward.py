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

from p4_fold_dispatcher import dispatch_folds
from p4_fold_generator import generate_folds


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


def _summary_verdict(summary_path: str) -> tuple[str, str]:
    if not summary_path:
        return "FAIL", "missing_summary"
    path = Path(summary_path)
    if not path.exists():
        return "FAIL", "summary_path_not_found"
    try:
        import json

        data = json.loads(path.read_text(encoding="utf-8", errors="replace"))
    except Exception as exc:
        return "FAIL", f"summary_parse_error:{type(exc).__name__}"

    verdict = str(data.get("verdict") or data.get("classification") or "").upper()
    if verdict == "PASS":
        return "PASS", str(data.get("reason") or "fold_summary_pass")
    return "FAIL", str(data.get("reason") or verdict or "fold_summary_not_pass")


def _write_walk_forward_csv_from_manifest(manifest: dict[str, object], out_dir: Path) -> Path:
    rows = []
    for fold in manifest.get("fold_results", []):
        if not isinstance(fold, dict):
            continue
        verdict, reason = _summary_verdict(str(fold.get("summary_path") or ""))
        rows.append(
            {
                "fold_id": str(fold.get("fold_id") or ""),
                "regime": str(fold.get("regime") or "UNCLASSIFIED"),
                "dev_start": str(fold.get("dev_start") or ""),
                "dev_end": str(fold.get("dev_end") or ""),
                "oos_start": str(fold.get("oos_start") or ""),
                "oos_end": str(fold.get("oos_end") or ""),
                "oos_clean": "true" if verdict == "PASS" else "false",
                "verdict": verdict,
                "summary_path": str(fold.get("summary_path") or ""),
                "reason": reason,
            }
        )

    csv_path = out_dir / "walk_forward.csv"
    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "fold_id",
                "regime",
                "dev_start",
                "dev_end",
                "oos_start",
                "oos_end",
                "oos_clean",
                "verdict",
                "summary_path",
                "reason",
            ],
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
    return csv_path


def _run_fold_vertical_slice(args: argparse.Namespace, out_dir: Path) -> Path:
    folds = generate_folds(
        ea_id=args.ea,
        train_from_year=int(args.train_from_year or 2017),
        oos_from_year=int(args.oos_from_year or 2023),
        oos_to_year=int(args.oos_to_year or 2025),
        fold_months=args.fold_months,
        embargo_days=args.embargo_days,
        min_folds=args.min_folds,
    )
    folds_csv = out_dir / "walk_forward_folds.csv"
    with folds_csv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["ea_id", "fold_id", "regime", "dev_start", "dev_end", "oos_start", "oos_end"],
        )
        writer.writeheader()
        for fold in folds:
            writer.writerow(fold)

    if not args.setfile:
        raise ValueError("P4 fold dispatch requires --setfile when --walk-forward-csv is absent")
    symbol = args.symbol or (args.symbols.split(",")[0].strip() if args.symbols else "")
    if not symbol:
        raise ValueError("P4 fold dispatch requires --symbol or --symbols when --walk-forward-csv is absent")

    manifest = dispatch_folds(
        ea_id=args.ea,
        symbol=symbol,
        period=args.period,
        setfile=Path(args.setfile),
        folds_csv=folds_csv,
        out_prefix=Path(args.out_prefix),
        terminal=args.terminal,
        timeout_seconds=args.timeout_seconds,
    )
    fold_by_id = {fold["fold_id"]: fold for fold in folds}
    for result in manifest.get("fold_results", []):
        if isinstance(result, dict):
            result.update(fold_by_id.get(str(result.get("fold_id") or ""), {}))
    return _write_walk_forward_csv_from_manifest(manifest, out_dir)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run P4 walk-forward gate checks.")
    add_common_args(parser)
    parser.add_argument("--walk-forward-csv")
    parser.add_argument("--symbols", default="")
    parser.add_argument("--symbol", default="")
    parser.add_argument("--period", default="")
    parser.add_argument("--setfile", default="")
    parser.add_argument("--train-from-year", default="")
    parser.add_argument("--train-to-year", default="")
    parser.add_argument("--oos-from-year", default="")
    parser.add_argument("--oos-to-year", default="")
    parser.add_argument("--min-folds", type=int, default=6)
    parser.add_argument("--fold-months", type=int, default=6)
    parser.add_argument("--embargo-days", type=int, default=7)
    parser.add_argument("--terminal", default="T1")
    parser.add_argument("--timeout-seconds", type=int, default=1800)
    args = parser.parse_args()

    ea_id = args.ea
    out_dir = ensure_dir(Path(args.out_prefix) / ea_id / "P4")
    if not args.walk_forward_csv:
        try:
            args.walk_forward_csv = str(_run_fold_vertical_slice(args, out_dir))
        except Exception as exc:
            result = build_result(
                phase="P4",
                ea_id=ea_id,
                verdict="WAITING_INPUT",
                criterion="P4 could not run fold dispatch; required setup input is missing or invalid.",
                evidence_path="",
                details={
                    "symbols": args.symbols or args.symbol,
                    "period": args.period,
                    "setfile": args.setfile,
                    "train_from_year": args.train_from_year,
                    "train_to_year": args.train_to_year,
                    "oos_from_year": args.oos_from_year,
                    "oos_to_year": args.oos_to_year,
                    "min_folds": args.min_folds,
                    "error": str(exc),
                },
            )
            result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P4", ea_id=ea_id, result=result)
            update_result_with_evidence_path(result_path, result)
            print(result_path)
            return 0

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
