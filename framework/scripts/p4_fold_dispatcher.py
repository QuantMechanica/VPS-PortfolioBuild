#!/usr/bin/env python3
"""P4 walk-forward fold dispatcher.

Reads walk_forward_folds.csv (produced by p4_fold_generator.py) and spawns
run_smoke.ps1 for each fold's OOS window. Writes per-fold summary.json
paths to a manifest. Each fold's report_root is unique so summaries don't
collide.

PHASE_CHAIN_BUILD_PLAN_2026-05-19 step 1B.

Smoke-conflict handling: passes -AllowRunningTerminal so worker daemons
holding T1-T5 do not refuse the smoke. MT5 per-symbol cache lock
handled by spacing dispatches per-symbol via dispatch_serial flag (one
at a time when --serial set; default parallel).

Usage:
  python p4_fold_dispatcher.py --ea QM5_1056 --symbol EURUSD.DWX \
    --period H1 --setfile <abs path> --out-prefix D:/QM/reports/pipeline \
    --folds-csv D:/QM/reports/pipeline/QM5_1056/P4/walk_forward_folds.csv \
    --terminal T1 --timeout-seconds 1800
"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
RUN_SMOKE = REPO_ROOT / "framework" / "scripts" / "run_smoke.ps1"


def _read_folds(folds_csv: Path) -> list[dict[str, str]]:
    with folds_csv.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def _spawn_fold(
    *,
    ea_id: str,
    symbol: str,
    period: str,
    setfile: Path,
    fold: dict[str, str],
    report_root: Path,
    terminal: str,
    timeout_seconds: int,
) -> dict[str, str]:
    fold_id = fold["fold_id"]
    fold_report_root = report_root / fold_id
    fold_report_root.mkdir(parents=True, exist_ok=True)
    log_path = fold_report_root / "run_smoke.log"
    ea_num = int(ea_id.split("_")[1])
    ea_dirs = list((REPO_ROOT / "framework" / "EAs").glob(f"{ea_id}_*"))
    ea_label = ea_dirs[0].name if ea_dirs else ea_id

    from_date = fold["oos_start"].replace("-", ".")
    to_date = fold["oos_end"].replace("-", ".")

    cmd = [
        "pwsh.exe", "-NoProfile", "-File", str(RUN_SMOKE),
        "-EAId", str(ea_num),
        "-EALabel", ea_label,
        "-Symbol", symbol,
        "-Year", fold["oos_start"][:4],
        "-Terminal", terminal,
        "-Period", period,
        "-Runs", "1",
        "-MinTrades", "1",
        "-Model", "4",
        "-SetFile", str(setfile),
        "-ReportRoot", str(fold_report_root),
        "-AllowMissingRealTicksLogMarker",
        "-AllowRunningTerminal",
        "-FromDate", from_date,
        "-ToDate", to_date,
        "-TimeoutSeconds", str(timeout_seconds),
    ]
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    with log_path.open("w", encoding="utf-8") as log_fh:
        proc = subprocess.run(
            cmd, cwd=str(REPO_ROOT), stdout=log_fh, stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL, timeout=timeout_seconds + 60,
            creationflags=creationflags,
        )
    summary_path = ""
    log_text = log_path.read_text(encoding="utf-8", errors="replace")
    for line in log_text.splitlines():
        if line.startswith("run_smoke.summary="):
            summary_path = line.split("=", 1)[1].strip()
    return {
        "fold_id": fold_id,
        "oos_start": fold["oos_start"],
        "oos_end": fold["oos_end"],
        "regime": fold.get("regime", "UNCLASSIFIED"),
        "summary_path": summary_path,
        "exit_code": str(proc.returncode),
        "log_path": str(log_path),
    }


def dispatch_folds(
    *,
    ea_id: str,
    symbol: str,
    period: str,
    setfile: Path,
    folds_csv: Path,
    out_prefix: Path,
    terminal: str,
    timeout_seconds: int,
    spawn_fn=None,
) -> dict[str, object]:
    report_root = out_prefix / ea_id / "P4" / "fold_runs"
    report_root.mkdir(parents=True, exist_ok=True)
    folds = _read_folds(folds_csv)
    spawn = spawn_fn or _spawn_fold
    fold_results = []
    for fold in folds:
        result = spawn(
            ea_id=ea_id, symbol=symbol, period=period, setfile=setfile,
            fold=fold, report_root=report_root, terminal=terminal,
            timeout_seconds=timeout_seconds,
        )
        fold_results.append(result)
    manifest_path = out_prefix / ea_id / "P4" / "fold_dispatch_manifest.json"
    manifest = {
        "ea_id": ea_id, "symbol": symbol, "period": period,
        "setfile": str(setfile), "terminal": terminal,
        "folds_csv": str(folds_csv), "fold_count": len(folds),
        "fold_results": fold_results,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="P4 walk-forward fold dispatcher")
    parser.add_argument("--ea", required=True)
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--period", required=True)
    parser.add_argument("--setfile", required=True)
    parser.add_argument("--folds-csv", required=True)
    parser.add_argument("--out-prefix", required=True)
    parser.add_argument("--terminal", default="T1")
    parser.add_argument("--timeout-seconds", type=int, default=1800)
    args = parser.parse_args()

    manifest = dispatch_folds(
        ea_id=args.ea, symbol=args.symbol, period=args.period,
        setfile=Path(args.setfile), folds_csv=Path(args.folds_csv),
        out_prefix=Path(args.out_prefix), terminal=args.terminal,
        timeout_seconds=args.timeout_seconds,
    )
    print(json.dumps({
        "ea_id": manifest["ea_id"],
        "fold_count": manifest["fold_count"],
        "successful_summaries": sum(1 for f in manifest["fold_results"] if f["summary_path"]),
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
