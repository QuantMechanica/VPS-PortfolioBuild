#!/usr/bin/env python3
"""Cascade stub for P8 news-impact runner."""

from __future__ import annotations

import argparse
from pathlib import Path

from _phase_utils import build_result, ensure_dir, update_result_with_evidence_path, write_phase_artifacts


def main() -> int:
    parser = argparse.ArgumentParser(description="P8 news-impact cascade stub")
    parser.add_argument("--ea", required=True)
    parser.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    parser.add_argument("--symbol", default="")
    parser.add_argument("--period", default="")
    parser.add_argument("--setfile", default="")
    parser.add_argument("--modes", default="OFF,PAUSE,SKIP_DAY,FTMO_PAUSE,5ers_PAUSE,no_news,news_only")
    args, _unknown = parser.parse_known_args()

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P8")
    result = build_result(
        phase="P8",
        ea_id=args.ea,
        verdict="PENDING_IMPLEMENTATION",
        criterion="P8 cascade runner stub: 7-mode news-impact evidence generation is not implemented yet.",
        evidence_path="",
        details={"symbol": args.symbol, "period": args.period, "setfile": args.setfile, "modes": args.modes.split(",")},
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P8", ea_id=args.ea, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
