"""P2 Baseline runner — iterates an EA's symbol matrix and launches MT5 backtests.

Wraps `run_smoke.ps1` per symbol, distributes across T1-T5 round-robin, and
produces a phase-level report.csv aggregating verdicts.

Concurrency model: one worker thread per terminal. Symbols are partitioned
across T1-T5 round-robin; each terminal works through its slice sequentially.
With 36 symbols / 5 terminals ≈ 7-8 per terminal, 5 terminals run in parallel.
Wall-clock time = ceil(36/5) × per-symbol-time. CSV append uses a Lock.

Usage:
    python p2_baseline.py --ea QM5_1003
    python p2_baseline.py --ea QM5_1003 --symbols EURUSD.DWX,GBPUSD.DWX --year 2024
    python p2_baseline.py --ea QM5_1003 --dry-run
    python p2_baseline.py --ea QM5_1003 --resume
    python p2_baseline.py --ea QM5_1003 --terminal T1            # pin all to T1 (serial)
    python p2_baseline.py --ea QM5_1003 --serial                 # round-robin but serial across terminals

Exit codes:
    0  all symbols PASS (or skipped via --resume)
    1  >=1 symbol FAIL but execution completed
    2  invocation error / missing setfiles / fatal infra issue
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

CSV_LOCK = threading.Lock()
PRINT_LOCK = threading.Lock()


def safe_print(msg: str) -> None:
    with PRINT_LOCK:
        print(msg, flush=True)

REPO_ROOT = Path(__file__).resolve().parents[2]
EA_ROOT = REPO_ROOT / "framework" / "EAs"
RUN_SMOKE_PS1 = REPO_ROOT / "framework" / "scripts" / "run_smoke.ps1"
TERMINALS = ["T1", "T2", "T3", "T4", "T5"]
DEFAULT_OUT_PREFIX = Path(r"D:\QM\reports\pipeline")


def find_ea_dir(ea_label: str) -> Path:
    """Resolve QM5_1003 -> framework/EAs/QM5_1003_davey_baseline_3bar/."""
    candidates = [p for p in EA_ROOT.glob(f"{ea_label}_*") if p.is_dir()]
    if not candidates:
        raise SystemExit(f"[FATAL] EA dir not found: {EA_ROOT}/{ea_label}_*")
    if len(candidates) > 1:
        raise SystemExit(f"[FATAL] ambiguous EA dir: {[p.name for p in candidates]}")
    return candidates[0]


def load_symbols(ea_dir: Path, period: str) -> list[str]:
    """Discover symbols from <ea_dir>/sets/<ea_name>_<SYMBOL>_<period>_backtest.set."""
    sets_dir = ea_dir / "sets"
    if not sets_dir.is_dir():
        raise SystemExit(f"[FATAL] no sets dir: {sets_dir}")
    pattern = re.compile(rf"^{re.escape(ea_dir.name)}_(.+?)_{re.escape(period)}_backtest\.set$")
    symbols = []
    for f in sorted(sets_dir.iterdir()):
        m = pattern.match(f.name)
        if m:
            symbols.append(m.group(1))
    if not symbols:
        raise SystemExit(f"[FATAL] no setfiles match pattern in {sets_dir}")
    return symbols


def setfile_for(ea_dir: Path, symbol: str, period: str) -> Path:
    return ea_dir / "sets" / f"{ea_dir.name}_{symbol}_{period}_backtest.set"


def parse_summary(summary_path: Path) -> dict:
    with summary_path.open(encoding="utf-8-sig") as f:
        return json.load(f)


def derive_verdict(summary: dict, min_trades: int) -> tuple[str, str, str]:
    """Return (verdict, invalidation_reason, evidence_summary)."""
    if summary.get("result") != "PASS":
        reasons = summary.get("reason_classes") or ["UNKNOWN"]
        return "FAIL", "run_smoke_fail:" + ";".join(reasons), summary.get("report_dir", "")
    runs = summary.get("runs") or []
    if not runs:
        return "INVALID", "no_runs_in_summary", summary.get("report_dir", "")
    trades = [int(r.get("total_trades", 0) or 0) for r in runs]
    if any(t < min_trades for t in trades):
        return "FAIL", f"trade_count_below_min:got={trades}:min={min_trades}", summary.get("report_dir", "")
    return "PASS", "", summary.get("report_dir", "")


def read_existing_passes(report_csv: Path) -> set[str]:
    if not report_csv.exists():
        return set()
    passes = set()
    with report_csv.open(encoding="utf-8") as f:
        r = csv.DictReader(f)
        for row in r:
            if row.get("verdict") == "PASS":
                passes.add(row.get("symbol", ""))
    return passes


def append_csv_row(report_csv: Path, row: dict) -> None:
    with CSV_LOCK:
        write_header = not report_csv.exists()
        report_csv.parent.mkdir(parents=True, exist_ok=True)
        with report_csv.open("a", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=["ea_id", "phase", "symbol", "terminal", "verdict", "invalidation_reason", "evidence"])
            if write_header:
                w.writeheader()
            w.writerow(row)


def invoke_run_smoke(ea_id: int, symbol: str, year: int, terminal: str, period: str,
                     runs: int, expert: str, setfile: Path, report_root: Path,
                     min_trades: int, timeout_sec: int) -> tuple[int, str, str]:
    """Returns (exit_code, stdout, stderr). Captures full output."""
    arglist = [
        "pwsh.exe", "-NoProfile", "-File", str(RUN_SMOKE_PS1),
        "-EAId", str(ea_id),
        "-Symbol", symbol,
        "-Year", str(year),
        "-Terminal", terminal,
        "-Period", period,
        "-Runs", str(runs),
        "-MinTrades", str(min_trades),
        "-Model", "4",
        "-Expert", expert,
        "-SetFile", str(setfile),
        "-ReportRoot", str(report_root),
        "-AllowRunningTerminal",
        "-AllowMissingRealTicksLogMarker",
        "-TimeoutSeconds", str(timeout_sec),
    ]
    proc = subprocess.run(arglist, capture_output=True, text=True, timeout=timeout_sec + 60)
    return proc.returncode, proc.stdout or "", proc.stderr or ""


def parse_run_smoke_summary_path(stdout: str) -> Path | None:
    m = re.search(r"run_smoke\.summary=(\S+)", stdout)
    if not m:
        return None
    return Path(m.group(1).strip())


def run_one_symbol(ea_id: int, ea_dir: Path, ea_label: str, symbol: str, year: int,
                   period: str, runs: int, terminal: str, report_root_phase: Path,
                   report_csv: Path, min_trades: int, timeout_sec: int, dry_run: bool) -> str:
    """Returns the verdict string."""
    setfile = setfile_for(ea_dir, symbol, period)
    if not setfile.exists():
        msg = f"setfile_missing:{setfile.name}"
        print(f"[INVALID] {symbol} ({terminal}): {msg}")
        append_csv_row(report_csv, {
            "ea_id": ea_id, "phase": "P2", "symbol": symbol, "terminal": terminal,
            "verdict": "INVALID", "invalidation_reason": msg, "evidence": str(setfile),
        })
        return "INVALID"

    if dry_run:
        safe_print(f"[DRY] {symbol} -> {terminal} (setfile={setfile.name})")
        return "DRY"

    expert = f"QM\\{ea_dir.name}"
    safe_print(f"[RUN] {symbol} -> {terminal} ({setfile.name})")
    t0 = time.time()
    try:
        rc, stdout, stderr = invoke_run_smoke(
            ea_id=ea_id, symbol=symbol, year=year, terminal=terminal, period=period,
            runs=runs, expert=expert, setfile=setfile, report_root=report_root_phase,
            min_trades=min_trades, timeout_sec=timeout_sec,
        )
    except subprocess.TimeoutExpired:
        elapsed = time.time() - t0
        safe_print(f"[TIMEOUT] {symbol} ({terminal}): exceeded {timeout_sec}s after {elapsed:.0f}s")
        append_csv_row(report_csv, {
            "ea_id": ea_id, "phase": "P2", "symbol": symbol, "terminal": terminal,
            "verdict": "INVALID", "invalidation_reason": "run_smoke_timeout",
            "evidence": f"timeout_after_{int(elapsed)}s",
        })
        return "INVALID"

    elapsed = time.time() - t0
    summary_path = parse_run_smoke_summary_path(stdout)
    if not summary_path or not summary_path.exists():
        msg = f"no_summary_json:rc={rc}"
        safe_print(f"[INVALID] {symbol} ({terminal}): {msg} ({elapsed:.0f}s)")
        if stderr:
            safe_print(f"  stderr: {stderr[:300]}")
        append_csv_row(report_csv, {
            "ea_id": ea_id, "phase": "P2", "symbol": symbol, "terminal": terminal,
            "verdict": "INVALID", "invalidation_reason": msg, "evidence": stdout[-200:],
        })
        return "INVALID"

    summary = parse_summary(summary_path)
    verdict, reason, evidence = derive_verdict(summary, min_trades)
    safe_print(f"[{verdict}] {symbol} ({terminal}) {elapsed:.0f}s reason={reason or '-'}")
    append_csv_row(report_csv, {
        "ea_id": ea_id, "phase": "P2", "symbol": symbol, "terminal": terminal,
        "verdict": verdict, "invalidation_reason": reason, "evidence": str(summary_path),
    })
    return verdict


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ea", required=True, help="EA label, e.g. QM5_1003")
    ap.add_argument("--year", type=int, default=2024)
    ap.add_argument("--period", default="H1")
    ap.add_argument("--runs", type=int, default=2, help="run count per symbol (run_smoke -Runs)")
    ap.add_argument("--symbols", help="comma-separated subset; default = all setfiles")
    ap.add_argument("--out-prefix", default=str(DEFAULT_OUT_PREFIX))
    ap.add_argument("--min-trades", type=int, default=20, help="trade-count gate (P2 spec: >200, lower default for early validation)")
    ap.add_argument("--timeout", type=int, default=1800, help="per-symbol timeout seconds (run_smoke -TimeoutSeconds)")
    ap.add_argument("--dry-run", action="store_true", help="print plan, no MT5 launch")
    ap.add_argument("--resume", action="store_true", help="skip symbols already verdict=PASS in report.csv")
    ap.add_argument("--terminal", help="pin all runs to one terminal (default: round-robin T1..T5)")
    args = ap.parse_args()

    ea_dir = find_ea_dir(args.ea)
    if "_" not in args.ea:
        raise SystemExit(f"[FATAL] EA label must be QM5_NNNN: got {args.ea}")
    ea_id = int(args.ea.split("_", 1)[1])

    if args.symbols:
        symbols = [s.strip() for s in args.symbols.split(",") if s.strip()]
    else:
        symbols = load_symbols(ea_dir, args.period)

    out_prefix = Path(args.out_prefix)
    report_root_phase = out_prefix / args.ea / "P2"
    report_csv = report_root_phase / "report.csv"

    if args.resume:
        already = read_existing_passes(report_csv)
        before = len(symbols)
        symbols = [s for s in symbols if s not in already]
        print(f"[RESUME] {len(already)} PASS already; skipping. {len(symbols)}/{before} remain.")

    print(f"[P2] EA={args.ea} ea_id={ea_id} period={args.period} year={args.year} runs={args.runs}")
    print(f"[P2] symbols={len(symbols)} report_csv={report_csv}")
    if args.dry_run:
        print(f"[P2] DRY RUN (no MT5 launches)")

    counts = {"PASS": 0, "FAIL": 0, "INVALID": 0, "DRY": 0}
    started_at = datetime.now(timezone.utc).isoformat()
    for i, symbol in enumerate(symbols):
        if args.terminal:
            terminal = args.terminal
        else:
            terminal = TERMINALS[i % len(TERMINALS)]
        verdict = run_one_symbol(
            ea_id=ea_id, ea_dir=ea_dir, ea_label=args.ea, symbol=symbol,
            year=args.year, period=args.period, runs=args.runs, terminal=terminal,
            report_root_phase=report_root_phase, report_csv=report_csv,
            min_trades=args.min_trades, timeout_sec=args.timeout, dry_run=args.dry_run,
        )
        counts[verdict] = counts.get(verdict, 0) + 1

    finished_at = datetime.now(timezone.utc).isoformat()
    summary = {
        "ea": args.ea, "phase": "P2", "year": args.year, "period": args.period,
        "started_at": started_at, "finished_at": finished_at,
        "counts": counts, "report_csv": str(report_csv),
    }
    summary_path = report_root_phase / f"p2_{args.ea}_result.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(f"\n[P2 DONE] {counts}  summary={summary_path}")

    return 0 if counts.get("FAIL", 0) == 0 and counts.get("INVALID", 0) == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
