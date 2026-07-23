#!/usr/bin/env python3
"""P5c crisis-slice report runner (report-first, no auto-fail)."""

from __future__ import annotations

import argparse
from pathlib import Path

from _phase_utils import (
    add_common_args,
    build_result,
    ensure_dir,
    load_csv_rows,
    parse_float,
    parse_int,
    update_result_with_evidence_path,
    write_phase_artifacts,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate P5c crisis-slice summary")
    add_common_args(parser)
    parser.add_argument("--slices-csv", required=True)
    parser.add_argument("--clean-metrics-json")
    args = parser.parse_args()

    ea_id = args.ea
    out_dir = ensure_dir(Path(args.out_prefix) / ea_id / "P5c")

    rows = load_csv_rows(Path(args.slices_csv))
    anomalies: list[dict[str, object]] = []

    for row in rows:
        pf = parse_float(row.get("pf"), 0.0)
        trades = parse_int(row.get("trades"), 0)
        dd = parse_float(row.get("drawdown_pct"), 0.0)
        flags: list[str] = []
        if pf < 1.0:
            flags.append("PF_INVERSION")
        if trades <= 0:
            flags.append("TRADE_DROPOUT")
        if dd > 20.0:
            flags.append("DD_SPIKE")
        if flags:
            anomalies.append(
                {
                    "drawdown_pct": dd,
                    "flags": flags,
                    "pf": pf,
                    "slice": row.get("slice", "UNKNOWN"),
                    "trades": trades,
                }
            )

    details = {
        "anomaly_count": len(anomalies),
        "anomaly_rows": anomalies,
        "slice_count": len(rows),
    }

    result = build_result(
        phase="P5c",
        ea_id=ea_id,
        verdict="REPORT_ONLY",
        criterion="Report-first phase; anomalies surfaced for human review",
        evidence_path="",
        details=details,
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P5c", ea_id=ea_id, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
