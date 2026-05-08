#!/usr/bin/env python3
"""Deterministic runner for qm-new-setfiles."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
EA_ROOT = REPO_ROOT / "framework" / "EAs"
GEN_PS1 = REPO_ROOT / "framework" / "scripts" / "gen_setfile.ps1"
EXCLUDED_SYMBOLS = {"NDXm.DWX", "GDAXIm.DWX"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate and validate backtest setfiles")
    parser.add_argument("--ea-label", required=True, help="EA folder label, e.g. QM5_1003_davey_baseline_3bar")
    parser.add_argument("--period", default="H1", help="MT5 period token")
    parser.add_argument("--expected-count", type=int, default=None, help="Expected output file count in sets/ (defaults to discovered seed count)")
    parser.add_argument("--dry-run", action="store_true", help="Validate inputs only")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    ea_dir = EA_ROOT / args.ea_label
    sets_dir = ea_dir / "sets"
    ex5 = ea_dir / f"{args.ea_label}.ex5"

    checks = {
        "ea_dir_exists": ea_dir.exists(),
        "ex5_exists": ex5.exists(),
        "generator_exists": GEN_PS1.exists(),
    }
    if not all(checks.values()):
        print(json.dumps({"status": "error", "checks": checks}, indent=2))
        return 2

    pattern = f"{args.ea_label}_*_{args.period}_backtest.set"
    existing = sorted(sets_dir.glob(pattern))
    symbols = []
    for setfile in existing:
        prefix = f"{args.ea_label}_"
        suffix = f"_{args.period}_backtest.set"
        name = setfile.name
        if not name.startswith(prefix) or not name.endswith(suffix):
            continue
        symbol = name[len(prefix) : -len(suffix)]
        if symbol and symbol not in EXCLUDED_SYMBOLS:
            symbols.append(symbol)

    if not symbols:
        print(
            json.dumps(
                {
                    "status": "error",
                    "checks": checks,
                    "reason": "no_seed_setfiles",
                    "pattern": pattern,
                    "sets_dir": str(sets_dir),
                },
                indent=2,
            )
        )
        return 2

    if not args.dry_run:
        for symbol in symbols:
            command = [
                "pwsh",
                str(GEN_PS1),
                "-EaSlug",
                args.ea_label,
                "-Symbol",
                symbol,
                "-TF",
                args.period,
                "-Env",
                "backtest",
            ]
            proc = subprocess.run(command, cwd=REPO_ROOT, capture_output=True, text=True)
            if proc.returncode != 0:
                print(
                    json.dumps(
                        {
                            "status": "error",
                            "checks": checks,
                            "command": command,
                            "symbol": symbol,
                            "stderr": proc.stderr[-4000:],
                            "stdout": proc.stdout[-4000:],
                        },
                        indent=2,
                    )
                )
                return proc.returncode

    expected_count = args.expected_count if args.expected_count is not None else len(symbols)
    setfiles = sorted(sets_dir.glob(f"{args.ea_label}_*_{args.period}_backtest.set"))
    output = {
        "status": "ok" if len(setfiles) >= expected_count else "warning",
        "checks": checks,
        "dry_run": args.dry_run,
        "generation_command_template": [
            "pwsh",
            str(GEN_PS1),
            "-EaSlug",
            args.ea_label,
            "-Symbol",
            "<SYMBOL>",
            "-TF",
            args.period,
            "-Env",
            "backtest",
        ],
        "symbols_regenerated": symbols if not args.dry_run else [],
        "seed_symbol_count": len(symbols),
        "setfile_count": len(setfiles),
        "expected_count": expected_count,
        "excluded_symbols": sorted(EXCLUDED_SYMBOLS),
        "sets_dir": str(sets_dir),
        "sample_files": [p.name for p in setfiles[:5]],
        "next_action": "run_qm_p2_baseline" if len(setfiles) >= expected_count else "inspect_setfile_generation",
    }
    print(json.dumps(output, indent=2))
    return 0 if output["status"] in {"ok", "warning"} else 1


if __name__ == "__main__":
    sys.exit(main())
