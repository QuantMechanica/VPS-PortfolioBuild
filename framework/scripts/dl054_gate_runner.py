#!/usr/bin/env python3
"""DL-054 gate runner — standalone CLI for Pipeline-Op orchestrators.

Wraps `dl054_gates.py` so PowerShell or Python orchestrators can invoke
gate checks at pre-launch and post-launch points without importing the
library directly. Emits JSON verdicts to stdout.

Usage:

  # Pre-launch (must run before tester is invoked)
  python dl054_gate_runner.py prelaunch \\
      --ea-id QM5_1003 --phase P2 --symbol EURUSD.DWX --terminal T1 \\
      --window-start 2017-10-02 --window-end 2024-12-31 \\
      --setfile-path "D:\\QM\\repo\\framework\\EAs\\QM5_1003_davey_baseline_3bar\\sets\\RISK_FIXED_EURUSD.set"

  # Pre-launch with launch-config JSON file (deposit + currency + leverage)
  python dl054_gate_runner.py prelaunch --pre-spec-json job.json

  # Post-launch (after tester completes; pre-verdict from prelaunch step)
  python dl054_gate_runner.py postlaunch \\
      --pre-verdict-json D:\\QM\\reports\\.\\prelaunch.json \\
      --journal-path "D:\\QM\\mt5\\T1\\Tester\\logs\\20260505.log" \\
      --report-path "D:\\QM\\reports\\pipeline\\QM5_1003\\P2_clean_20260505\\QM5_1003_EURUSD.DWX_report.htm"

Exit codes:
    0  — gate verdict PASS (post) or PRELAUNCH_OK (pre)
    2  — gate verdict INVALID (any pre or post gate failed)
    1  — runner error (bad arguments, file IO, etc.)

Both verdicts always emit JSON to stdout regardless of exit code.

Author: Board Advisor 2026-05-01.
Authority: DL-054.
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

# Local import — dl054_gates.py lives in the same directory.
sys.path.insert(0, str(Path(__file__).parent))
from dl054_gates import (  # noqa: E402
    apply_pre_launch_gates,
    apply_post_launch_gates,
    serialize_verdict,
    MatrixVerdict,
    GateResult,
)


def parse_window_arg(value: str) -> datetime:
    """Accept ISO date (2017-10-02) or epoch seconds."""
    if value.isdigit():
        return datetime.fromtimestamp(int(value), tz=timezone.utc)
    # Try common formats
    for fmt in ("%Y-%m-%d", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%d %H:%M:%S"):
        try:
            dt = datetime.strptime(value, fmt)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt
        except ValueError:
            continue
    raise argparse.ArgumentTypeError(f"unrecognized window date: {value!r}")


def _build_launch_config_from_args(args: argparse.Namespace) -> dict:
    if args.pre_spec_json:
        spec = json.loads(Path(args.pre_spec_json).read_text(encoding="utf-8"))
        return spec.get("launch_config", spec)
    return {
        "initial_deposit": args.initial_deposit,
        "deposit_currency": args.deposit_currency,
        "leverage": args.leverage,
        "setfile_path": args.setfile_path,
    }


def cmd_prelaunch(args: argparse.Namespace) -> int:
    if args.pre_spec_json:
        spec = json.loads(Path(args.pre_spec_json).read_text(encoding="utf-8"))
        ea_id = spec["ea_id"]
        phase = spec["phase"]
        symbol = spec["symbol"]
        terminal = spec["terminal"]
        window_start = parse_window_arg(spec["window_start"])
        window_end = parse_window_arg(spec["window_end"])
        launch_config = spec.get("launch_config", spec)
    else:
        for required in ("ea_id", "phase", "symbol", "terminal", "window_start", "window_end"):
            if getattr(args, required, None) is None:
                print(f"missing --{required.replace('_','-')}", file=sys.stderr)
                return 1
        ea_id = args.ea_id
        phase = args.phase
        symbol = args.symbol
        terminal = args.terminal
        window_start = parse_window_arg(args.window_start)
        window_end = parse_window_arg(args.window_end)
        launch_config = _build_launch_config_from_args(args)

    verdict = apply_pre_launch_gates(
        ea_id=ea_id, phase=phase, symbol=symbol, terminal=terminal,
        window_start=window_start, window_end=window_end, launch_config=launch_config,
    )
    out = serialize_verdict(verdict)
    print(json.dumps(out, indent=2))
    if args.write_to:
        Path(args.write_to).parent.mkdir(parents=True, exist_ok=True)
        Path(args.write_to).write_text(json.dumps(out, indent=2), encoding="utf-8")
    return 0 if verdict.verdict == "PRELAUNCH_OK" else 2


def cmd_postlaunch(args: argparse.Namespace) -> int:
    pre_data = json.loads(Path(args.pre_verdict_json).read_text(encoding="utf-8"))
    pre = MatrixVerdict(
        ea_id=pre_data["ea_id"],
        phase=pre_data["phase"],
        symbol=pre_data["symbol"],
        terminal=pre_data["terminal"],
        gates=[GateResult(**g) for g in pre_data.get("gates", [])],
        verdict=pre_data["verdict"],
        invalidation_reason=pre_data.get("invalidation_reason", ""),
    )
    post = apply_post_launch_gates(
        pre,
        journal_path=Path(args.journal_path),
        report_path=Path(args.report_path),
    )
    out = serialize_verdict(post)
    print(json.dumps(out, indent=2))
    if args.write_to:
        Path(args.write_to).parent.mkdir(parents=True, exist_ok=True)
        Path(args.write_to).write_text(json.dumps(out, indent=2), encoding="utf-8")
    return 0 if post.verdict == "PASS" else 2


def cmd_writerow(args: argparse.Namespace) -> int:
    """Append a row to report.csv with verdict + invalidation_reason + evidence."""
    verdict_data = json.loads(Path(args.verdict_json).read_text(encoding="utf-8"))
    csv_path = Path(args.report_csv)
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    write_header = not csv_path.exists() or csv_path.stat().st_size == 0
    with csv_path.open("a", encoding="utf-8", newline="") as f:
        if write_header:
            f.write("ea_id,phase,symbol,terminal,verdict,invalidation_reason,evidence\n")
        row = (
            verdict_data["ea_id"],
            verdict_data["phase"],
            verdict_data["symbol"],
            verdict_data["terminal"],
            verdict_data["verdict"],
            verdict_data.get("invalidation_reason", "").replace(",", ";").replace("\n", " "),
            args.evidence_path or "",
        )
        f.write(",".join(row) + "\n")
    print(json.dumps({"appended_to": str(csv_path), "row": row}))
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="dl054_gate_runner")
    sub = p.add_subparsers(dest="cmd", required=True)

    pre = sub.add_parser("prelaunch", help="Run G1 + G2 + G5 (pre-launch gates)")
    pre.add_argument("--pre-spec-json", help="JSON file with all pre-launch fields")
    pre.add_argument("--ea-id")
    pre.add_argument("--phase")
    pre.add_argument("--symbol")
    pre.add_argument("--terminal")
    pre.add_argument("--window-start", help="ISO date or epoch")
    pre.add_argument("--window-end", help="ISO date or epoch")
    pre.add_argument("--initial-deposit", type=int, default=100000)
    pre.add_argument("--deposit-currency", default="USD")
    pre.add_argument("--leverage", type=int, default=100)
    pre.add_argument("--setfile-path")
    pre.add_argument("--write-to", help="Optional path to also write the verdict JSON to")
    pre.set_defaults(func=cmd_prelaunch)

    post = sub.add_parser("postlaunch", help="Run G3 + G4 (post-launch gates) on top of pre-verdict")
    post.add_argument("--pre-verdict-json", required=True)
    post.add_argument("--journal-path", required=True)
    post.add_argument("--report-path", required=True)
    post.add_argument("--write-to", help="Optional path to also write the final verdict JSON to")
    post.set_defaults(func=cmd_postlaunch)

    writerow = sub.add_parser("writerow", help="Append verdict row to report.csv with new schema")
    writerow.add_argument("--verdict-json", required=True)
    writerow.add_argument("--report-csv", required=True)
    writerow.add_argument("--evidence-path", default="")
    writerow.set_defaults(func=cmd_writerow)

    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
