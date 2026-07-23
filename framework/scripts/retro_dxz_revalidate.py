#!/usr/bin/env python3
"""Retroactive DXZ evaluation over available pipeline artifacts."""

from __future__ import annotations

import argparse
import csv
from datetime import date
from pathlib import Path

from dxz_compliance_gate import check_dxz_compliance


def _has_cols(path: Path) -> bool:
    try:
        with path.open("r", encoding="utf-8", newline="") as handle:
            row = next(csv.DictReader(handle), None)
    except Exception:
        return False
    if not row:
        return False
    keys = {k.lower() for k in row.keys()}
    has_eq = "equity" in keys or "balance" in keys
    has_ts = "timestamp" in keys or "time" in keys or "datetime" in keys or "date" in keys
    return has_eq and has_ts


def _find_curve(ea_root: Path) -> Path | None:
    for path in ea_root.rglob("*.csv"):
        if _has_cols(path):
            return path
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--pipeline-root", default="D:/QM/reports/pipeline")
    ap.add_argument("--eas", default="QM5_1003,QM5_1004,QM5_1017,QM5_SRC04_S03")
    ap.add_argument("--out-md", default="")
    args = ap.parse_args()

    root = Path(args.pipeline_root)
    eas = [ea.strip() for ea in args.eas.split(",") if ea.strip()]
    if args.out_md:
        out_md = Path(args.out_md)
    else:
        out_md = Path("artifacts") / f"QUA-1082_dxz_retro_eval_{date.today().isoformat()}.md"

    lines = [
        f"# QUA-1082 Retroactive DXZ Evaluation ({date.today().isoformat()})",
        "",
        "| EA | per-EA soft DXZ | reason | max_daily_dd_pct | max_total_dd_pct | evidence |",
        "|---|---|---|---:|---:|---|",
    ]
    for ea in eas:
        ea_root = root / ea
        if not ea_root.exists():
            lines.append(f"| {ea} | DATA_MISSING | missing_ea_folder |  |  |  |")
            continue
        curve = _find_curve(ea_root)
        if curve is None:
            lines.append(f"| {ea} | DATA_MISSING | missing_timestamped_equity_curve |  |  |  |")
            continue
        report_csv = next(ea_root.rglob("report.csv"), curve)
        evidence = root / ea / "DXZ" / "retro_dxz_evidence.json"
        verdict = check_dxz_compliance(report_csv, curve, evidence_path=evidence)
        lines.append(
            f"| {ea} | {verdict['verdict']} | {verdict['reason']} | {verdict['max_daily_dd_pct']} | {verdict['max_total_dd_pct']} | {evidence} |"
        )

    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(out_md)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
