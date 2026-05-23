#!/usr/bin/env python3
"""Cascade stub for P6 multi-seed runner."""

from __future__ import annotations

import argparse
from pathlib import Path

from _phase_utils import build_result, ensure_dir, update_result_with_evidence_path, write_phase_artifacts


def main() -> int:
    parser = argparse.ArgumentParser(description="P6 multi-seed cascade stub")
    parser.add_argument("--ea", required=True)
    parser.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    parser.add_argument("--symbol", default="")
    parser.add_argument("--period", default="")
    parser.add_argument("--setfile", default="")
    parser.add_argument("--seeds", default="42,17,99,7,2026")
    args, _unknown = parser.parse_known_args()

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P6")
    result = build_result(
        phase="P6",
        ea_id=args.ea,
        verdict="PENDING_IMPLEMENTATION",
        criterion="P6 cascade runner stub: 5-seed evidence generation is not implemented yet.",
        evidence_path="",
        details={"symbol": args.symbol, "period": args.period, "setfile": args.setfile, "seeds": args.seeds},
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P6", ea_id=args.ea, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
