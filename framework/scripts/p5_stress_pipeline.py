#!/usr/bin/env python3
"""Run P5 stress evidence generation, then evaluate the P5 hard gate."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent


def _run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    return subprocess.run(cmd, cwd=str(SCRIPT_DIR.parents[1]), capture_output=True, text=True, creationflags=creationflags)


def _infer_parent_worker_terminal() -> str:
    if sys.platform != "win32":
        return ""
    creationflags = subprocess.CREATE_NO_WINDOW
    command = (
        "$p=(Get-CimInstance Win32_Process -Filter \"ProcessId=%d\").CommandLine; "
        "if($p){[Console]::Out.Write($p)}"
    ) % os.getppid()
    proc = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", command],
        capture_output=True,
        text=True,
        creationflags=creationflags,
    )
    match = re.search(r"--terminal\s+(T(?:10|[1-9]))\b", proc.stdout or "", re.IGNORECASE)
    return match.group(1).upper() if match else ""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--year", required=True)
    ap.add_argument("--period", default="H1")
    ap.add_argument("--calibration-json", required=True)
    ap.add_argument("--base-setfile", default="")
    ap.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    ap.add_argument("--terminal", default="")
    ap.add_argument("--allow-running-terminal", action="store_true")
    ap.add_argument("--max-parallel", default="5")
    args = ap.parse_args()

    inferred_terminal = args.terminal.strip() or _infer_parent_worker_terminal()
    max_parallel = "1" if inferred_terminal else str(args.max_parallel)

    driver_cmd = [
        sys.executable,
        str(SCRIPT_DIR / "p5_stress_driver.py"),
        "--ea", args.ea,
        "--symbol", args.symbol,
        "--year", str(args.year),
        "--period", args.period,
        "--calibration-json", args.calibration_json,
        "--out-prefix", args.out_prefix,
        "--max-parallel", max_parallel,
    ]
    if inferred_terminal:
        driver_cmd.extend(["--terminal", inferred_terminal])
    if args.base_setfile:
        driver_cmd.extend(["--base-setfile", args.base_setfile])
    if args.allow_running_terminal and not inferred_terminal:
        driver_cmd.append("--allow-running-terminal")

    driver = _run(driver_cmd)
    if driver.returncode != 0:
        sys.stdout.write(driver.stdout)
        sys.stderr.write(driver.stderr)
        return driver.returncode
    payload = json.loads(driver.stdout.strip().splitlines()[-1])

    runner_cmd = [
        sys.executable,
        str(SCRIPT_DIR / "p5_stress_runner.py"),
        "--ea", args.ea,
        "--out-prefix", args.out_prefix,
        "--symbol", args.symbol,
        "--period", args.period,
        "--calibration-json", args.calibration_json,
        "--clean-metrics-json", payload["clean_metrics_json"],
        "--stress-metrics-json", payload["stress_metrics_json"],
        "--full-history-from", "2023-01-01",
        "--full-history-to", "2025-12-31",
    ]
    runner = _run(runner_cmd)
    sys.stdout.write(runner.stdout)
    sys.stderr.write(runner.stderr)
    return runner.returncode


if __name__ == "__main__":
    raise SystemExit(main())
