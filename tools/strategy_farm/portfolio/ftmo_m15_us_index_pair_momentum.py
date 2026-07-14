"""Disclosed M15 follow-up screen for US-index pair relative momentum."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

try:
    from . import ftmo_m15_us_index_pair_reversion as pair
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_m15_us_index_pair_reversion as pair  # type: ignore


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-root", type=Path, default=Path(r"D:\QM\mt5\T_Export\MQL5\Files")
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    frames, instruments = pair.load_inputs(args.data_root)
    output = pair.screen(frames, instruments, mode="momentum")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "status": output["status"],
                "evaluated": output["evaluated_configurations"],
                "preholdout_pass": output["preholdout_pass_count"],
                "holdout_pass": output["holdout_pass_count"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
