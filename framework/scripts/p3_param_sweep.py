"""P3 parameter sweep runner.

Runs a parameter grid for selected symbols/timeframes using run_smoke.ps1.
"""
from __future__ import annotations

import argparse
import csv
import itertools
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
EA_ROOT = REPO_ROOT / "framework" / "EAs"
RUN_SMOKE_PS1 = REPO_ROOT / "framework" / "scripts" / "run_smoke.ps1"
DEFAULT_OUT_PREFIX = Path(r"D:\QM\reports\pipeline")


def find_ea_dir(ea_label: str) -> Path:
    candidates = [p for p in EA_ROOT.glob(f"{ea_label}_*") if p.is_dir()]
    if not candidates:
        raise SystemExit(f"[FATAL] EA dir not found: {EA_ROOT}/{ea_label}_*")
    if len(candidates) > 1:
        raise SystemExit(f"[FATAL] ambiguous EA dir: {[p.name for p in candidates]}")
    return candidates[0]


def derive_numeric_ea_id(ea_label: str) -> int:
    m = re.match(r"^QM5_(\d+)$", ea_label)
    if not m:
        raise SystemExit(f"[FATAL] unsupported EA label format: {ea_label}")
    return int(m.group(1))


def setfile_for(ea_dir: Path, symbol: str, period: str) -> Path:
    return ea_dir / "sets" / f"{ea_dir.name}_{symbol}_{period}_backtest.set"


def parse_input_names(mq5_path: Path) -> set[str]:
    text = mq5_path.read_text(encoding="utf-8", errors="ignore")
    return set(re.findall(r"^\s*input\s+\w+\s+([A-Za-z_]\w*)\s*=", text, flags=re.M))


def build_param_grid(axes: dict[str, list[float | int]], available_inputs: set[str]) -> list[dict[str, float | int]]:
    keys = [k for k in axes.keys() if k in available_inputs]
    if not keys:
        return [{}]
    values = [axes[k] for k in keys]
    return [dict(zip(keys, combo)) for combo in itertools.product(*values)]


def write_temp_setfile(source: Path, out_dir: Path, run_id: str, overrides: dict[str, float | int]) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / f"{run_id}.set"
    base = source.read_text(encoding="utf-8", errors="ignore").rstrip() + "\n"
    lines = [base, "; P3 sweep overrides\n"]
    for key, value in overrides.items():
        lines.append(f"{key}={value}\n")
    target.write_text("".join(lines), encoding="utf-8")
    return target


def invoke_run_smoke(*, ea_id: int, symbol: str, year: int, period: str, setfile: Path, report_root: Path, timeout_sec: int) -> tuple[int, str, str]:
    args = [
        "pwsh.exe", "-NoProfile", "-File", str(RUN_SMOKE_PS1),
        "-EAId", str(ea_id),
        "-Symbol", symbol,
        "-Year", str(year),
        "-Terminal", "any",
        "-Period", period,
        "-Runs", "2",
        "-MinTrades", "20",
        "-Model", "4",
        "-SetFile", str(setfile),
        "-ReportRoot", str(report_root),
        "-AllowMissingRealTicksLogMarker",
        "-TimeoutSeconds", str(timeout_sec),
    ]
    proc = subprocess.run(args, capture_output=True, text=True, timeout=(timeout_sec * 2) + 60)
    return proc.returncode, proc.stdout or "", proc.stderr or ""


def append_report_row(report_csv: Path, row: dict[str, str]) -> None:
    report_csv.parent.mkdir(parents=True, exist_ok=True)
    write_header = not report_csv.exists()
    with report_csv.open("a", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["ea_id", "phase", "symbol", "period", "run_id", "verdict", "params", "summary_marker", "stderr_tail"],
        )
        if write_header:
            writer.writeheader()
        writer.writerow(row)


def load_completed_run_ids(report_csv: Path) -> set[str]:
    if not report_csv.exists():
        return set()
    done: set[str] = set()
    with report_csv.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            verdict = (row.get("verdict") or "").strip().upper()
            if verdict in {"PASS", "FAIL", "INVALID"}:
                run_id = (row.get("run_id") or "").strip()
                if run_id:
                    done.add(run_id)
    return done


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbols", required=True, help="comma-separated, e.g. AUDCHF.DWX,EURNZD.DWX")
    ap.add_argument("--periods", default="H1,M15")
    ap.add_argument("--year", type=int, default=2024)
    ap.add_argument("--out-prefix", default=str(DEFAULT_OUT_PREFIX))
    ap.add_argument("--max-runs", type=int, default=24)
    ap.add_argument("--timeout", type=int, default=1800)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    ea_dir = find_ea_dir(args.ea)
    ea_id = derive_numeric_ea_id(args.ea)
    mq5_path = ea_dir / f"{ea_dir.name}.mq5"
    available = parse_input_names(mq5_path)

    raw_axes: dict[str, list[float | int]] = {
        # QM5_1003 (davey-baseline-3bar) card §8 sweep axes mapped to EA inputs:
        # ssl1, ssl_usd_cap (card "ssl"), strategy_atr_period (card "ATR_period").
        "ssl1": [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
        "ssl_usd_cap": [1000, 2000, 3000, 5000],
        "strategy_atr_period": [10, 14, 20, 30],
    }
    grid = build_param_grid(raw_axes, available)

    symbols = [s.strip() for s in args.symbols.split(",") if s.strip()]
    periods = [p.strip() for p in args.periods.split(",") if p.strip()]

    report_root_phase = Path(args.out_prefix) / args.ea / "P3"
    report_csv = report_root_phase / "report.csv"
    temp_set_root = report_root_phase / "temp_setfiles"
    completed_run_ids = load_completed_run_ids(report_csv)
    summary = {"PASS": 0, "FAIL": 0, "DRY": 0}
    started = datetime.now(timezone.utc).isoformat()

    run_count = 0
    for symbol in symbols:
        for period in periods:
            base_set = setfile_for(ea_dir, symbol, period)
            if not base_set.exists():
                append_report_row(
                    report_csv,
                    {
                        "ea_id": str(ea_id),
                        "phase": "P3",
                        "symbol": symbol,
                        "period": period,
                        "run_id": f"{symbol}_{period}_MISSING_SETFILE",
                        "verdict": "FAIL",
                        "params": "{}",
                        "summary_marker": "setfile_missing",
                        "stderr_tail": str(base_set),
                    },
                )
                summary["FAIL"] += 1
                continue
            for idx, params in enumerate(grid, start=1):
                if run_count >= args.max_runs:
                    break
                run_id = f"{symbol}_{period}_{idx:03d}"
                if run_id in completed_run_ids:
                    continue
                run_count += 1
                if args.dry_run:
                    append_report_row(
                        report_csv,
                        {
                            "ea_id": str(ea_id),
                            "phase": "P3",
                            "symbol": symbol,
                            "period": period,
                            "run_id": run_id,
                            "verdict": "DRY",
                            "params": json.dumps(params, sort_keys=True),
                            "summary_marker": "dry_run",
                            "stderr_tail": "",
                        },
                    )
                    summary["DRY"] += 1
                    continue
                temp_set = write_temp_setfile(base_set, temp_set_root, run_id, params)
                rc, stdout, stderr = invoke_run_smoke(
                    ea_id=ea_id,
                    symbol=symbol,
                    year=args.year,
                    period=period,
                    setfile=temp_set,
                    report_root=report_root_phase,
                    timeout_sec=args.timeout,
                )
                verdict = "PASS" if rc == 0 else "FAIL"
                summary[verdict] += 1
                marker = "run_smoke.summary=" if "run_smoke.summary=" in stdout else "missing_summary_marker"
                append_report_row(
                    report_csv,
                    {
                        "ea_id": str(ea_id),
                        "phase": "P3",
                        "symbol": symbol,
                        "period": period,
                        "run_id": run_id,
                        "verdict": verdict,
                        "params": json.dumps(params, sort_keys=True),
                        "summary_marker": marker,
                        "stderr_tail": (stderr or "")[-240:],
                    },
                )
            if run_count >= args.max_runs:
                break
        if run_count >= args.max_runs:
            break

    result = {
        "ea": args.ea,
        "phase": "P3",
        "year": args.year,
        "symbols": symbols,
        "periods": periods,
        "available_inputs": sorted(available),
        "runs_executed": run_count,
        "counts": summary,
        "report_csv": str(report_csv),
        "started_at": started,
        "finished_at": datetime.now(timezone.utc).isoformat(),
    }
    result_path = report_root_phase / f"p3_{args.ea}_result.json"
    result_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"[P3 DONE] runs={run_count} counts={summary} report={report_csv} result={result_path}")
    return 0 if summary["FAIL"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
