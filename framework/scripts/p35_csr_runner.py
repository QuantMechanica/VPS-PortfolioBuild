#!/usr/bin/env python3
"""P3.5 Cross-Sectional Robustness runner."""

from __future__ import annotations

import argparse
from pathlib import Path

from _phase_utils import (
    add_common_args,
    build_result,
    classify_symbol,
    ensure_dir,
    load_csv_rows,
    row_passes,
    row_symbol,
    write_phase_artifacts,
    update_result_with_evidence_path,
)


def evaluate_classes(rows: list[dict[str, str]]) -> set[str]:
    classes: set[str] = set()
    for row in rows:
        if not row_passes(row):
            continue
        cls = classify_symbol(row_symbol(row))
        if cls != "UNKNOWN":
            classes.add(cls)
    return classes


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate P3.5 CSR verdict")
    add_common_args(parser)
    parser.add_argument("--baseline-csv", required=True)
    parser.add_argument("--csr-results-csv")
    args = parser.parse_args()

    ea_id = args.ea
    out_dir = ensure_dir(Path(args.out_prefix) / ea_id / "P3_5")
    baseline_rows = load_csv_rows(Path(args.baseline_csv))
    baseline_classes = evaluate_classes(baseline_rows)

    if not baseline_classes:
        verdict = "NO_PASS_BASELINE"
        criterion = "No PASS rows in baseline CSV"
        details = {
            "baseline_pass_class_count": 0,
            "baseline_pass_classes": [],
            "csr_rerun_used": False,
        }
    elif len(baseline_classes) >= 2:
        verdict = "AUTO_PASS"
        criterion = "Baseline PASS set covers >= 2 broad classes"
        details = {
            "baseline_pass_class_count": len(baseline_classes),
            "baseline_pass_classes": sorted(baseline_classes),
            "csr_rerun_used": False,
        }
    elif not args.csr_results_csv:
        verdict = "NEEDS_RERUN"
        criterion = "Baseline PASS set has only 1 broad class; CSR rerun required"
        details = {
            "baseline_pass_class_count": len(baseline_classes),
            "baseline_pass_classes": sorted(baseline_classes),
            "csr_rerun_used": False,
        }
    else:
        csr_rows = load_csv_rows(Path(args.csr_results_csv))
        csr_classes = evaluate_classes(csr_rows)
        combined = baseline_classes | csr_classes
        verdict = "PASS" if len(combined) >= 2 else "FAIL"
        criterion = "Post-rerun PASS classes >= 2" if verdict == "PASS" else "Post-rerun still single-class"
        details = {
            "baseline_pass_classes": sorted(baseline_classes),
            "combined_pass_class_count": len(combined),
            "combined_pass_classes": sorted(combined),
            "csr_pass_classes": sorted(csr_classes),
            "csr_rerun_used": True,
        }

    result = build_result(
        phase="P3.5",
        ea_id=ea_id,
        verdict=verdict,
        criterion=criterion,
        evidence_path="",
        details=details,
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P3.5", ea_id=ea_id, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
