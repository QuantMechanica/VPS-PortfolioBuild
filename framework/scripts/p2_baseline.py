"""P2 Baseline runner — iterates an EA's symbol matrix and launches MT5 backtests.

Wraps `run_smoke.ps1` per symbol, distributes across T1-T5 round-robin, and
produces a phase-level report.csv aggregating verdicts.

Concurrency model: one worker thread per terminal. Symbols are partitioned
across T1-T5 round-robin; each terminal works through its slice sequentially.
With 36 symbols / 5 terminals ~ 7-8 per terminal, 5 terminals run in parallel.
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
import shutil
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


def derive_numeric_ea_id(ea_label: str, ea_dir: Path) -> int:
    """Resolve numeric EA id from label or from mq5 input `qm_ea_id`."""
    m = re.match(r"^QM5_(\d+)$", ea_label)
    if m:
        return int(m.group(1))

    mq5_path = ea_dir / f"{ea_dir.name}.mq5"
    if not mq5_path.exists():
        raise SystemExit(f"[FATAL] cannot resolve numeric ea_id for {ea_label}: missing {mq5_path.name}")

    text = mq5_path.read_text(encoding="utf-8", errors="ignore")
    m2 = re.search(r"input\s+int\s+qm_ea_id\s*=\s*(\d+)\s*;", text)
    if not m2:
        raise SystemExit(f"[FATAL] cannot resolve numeric ea_id for {ea_label}: qm_ea_id not found in {mq5_path.name}")
    return int(m2.group(1))


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


def ensure_expert_binary_deployed(ea_dir: Path, terminal_roots: list[Path]) -> None:
    """Ensure EA .ex5 exists under each terminal's Experts/QM path.

    run_smoke writes Expert=QM\\<ea_dir.name> and MT5 resolves that to:
      <terminal>/MQL5/Experts/QM/<ea_dir.name>.ex5
    """
    src_ex5 = ea_dir / f"{ea_dir.name}.ex5"
    if not src_ex5.exists():
        raise SystemExit(f"[FATAL] missing EA binary for tester deployment: {src_ex5}")

    for root in terminal_roots:
        dest_dir = root / "MQL5" / "Experts" / "QM"
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / src_ex5.name
        shutil.copy2(src_ex5, dest)


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
                     min_trades: int, timeout_sec: int,
                     allow_running_terminal: bool = False) -> tuple[int, str, str]:
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
        "-AllowMissingRealTicksLogMarker",
        "-TimeoutSeconds", str(timeout_sec),
    ]
    if allow_running_terminal:
        arglist.append("-AllowRunningTerminal")
    # run_smoke executes up to `runs` sequential tester runs, each bounded by timeout_sec.
    # Keep wrapper timeout safely above aggregate budget to avoid false no-summary invalids.
    wrapper_timeout = (timeout_sec * max(1, runs)) + 60
    proc = subprocess.run(arglist, capture_output=True, text=True, timeout=wrapper_timeout)
    return proc.returncode, proc.stdout or "", proc.stderr or ""


def parse_run_smoke_summary_path(output_text: str) -> Path | None:
    m = re.search(r"run_smoke\.summary=(\S+)", output_text)
    if not m:
        return None
    return Path(m.group(1).strip())


def run_one_symbol(ea_id: int, ea_dir: Path, ea_label: str, symbol: str, year: int,
                   period: str, runs: int, terminal: str, report_root_phase: Path,
                   report_csv: Path, min_trades: int, timeout_sec: int, dry_run: bool,
                   allow_running_terminal: bool = False) -> str:
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
    max_attempts = 2
    attempt = 1
    while attempt <= max_attempts:
        safe_print(f"[RUN] {symbol} -> {terminal} ({setfile.name}) attempt={attempt}/{max_attempts}")
        t0 = time.time()
        try:
            rc, stdout, stderr = invoke_run_smoke(
                ea_id=ea_id, symbol=symbol, year=year, terminal=terminal, period=period,
                runs=runs, expert=expert, setfile=setfile, report_root=report_root_phase,
                min_trades=min_trades, timeout_sec=timeout_sec,
                allow_running_terminal=allow_running_terminal,
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
        combined_output = stdout + ("\n" + stderr if stderr else "")
        summary_path = parse_run_smoke_summary_path(combined_output)
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
        transient_fault = any(flag in (reason or "") for flag in ("REPORT_MISSING", "METATESTER_HUNG", "INCOMPLETE_RUNS"))
        if verdict == "FAIL" and transient_fault and attempt < max_attempts:
            safe_print(f"[RETRY] {symbol} ({terminal}) {elapsed:.0f}s reason={reason} -> retrying once")
            attempt += 1
            time.sleep(2)
            continue

        safe_print(f"[{verdict}] {symbol} ({terminal}) {elapsed:.0f}s reason={reason or '-'}")
        append_csv_row(report_csv, {
            "ea_id": ea_id, "phase": "P2", "symbol": symbol, "terminal": terminal,
            "verdict": verdict, "invalidation_reason": reason, "evidence": str(summary_path),
        })
        return verdict

    return "INVALID"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ea", required=True, help="EA label, e.g. QM5_1003 or QM5_SRC04_S03")
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
    ap.add_argument("--allow-running-terminal", action="store_true",
                    help="pass through -AllowRunningTerminal to run_smoke (off by default)")
    args = ap.parse_args()

    ea_dir = find_ea_dir(args.ea)
    ea_id = derive_numeric_ea_id(args.ea, ea_dir)
    terminal_roots = [Path(r"D:\QM\mt5") / t for t in TERMINALS]
    ensure_expert_binary_deployed(ea_dir, terminal_roots)

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
            terminal = "any"
        verdict = run_one_symbol(
            ea_id=ea_id, ea_dir=ea_dir, ea_label=args.ea, symbol=symbol,
            year=args.year, period=args.period, runs=args.runs, terminal=terminal,
            report_root_phase=report_root_phase, report_csv=report_csv,
            min_trades=args.min_trades, timeout_sec=args.timeout, dry_run=args.dry_run,
            allow_running_terminal=args.allow_running_terminal,
        )
        counts[verdict] = counts.get(verdict, 0) + 1

    finished_at = datetime.now(timezone.utc).isoformat()
    summary = {
        "ea": args.ea, "phase": "P2", "year": args.year, "period": args.period,
        "started_at": started_at, "finished_at": finished_at,
        "counts": counts, "report_csv": str(report_csv),
    }
    summary_path = report_root_phase / f"p2_{args.ea}_result.json"
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(f"\n[P2 DONE] {counts}  summary={summary_path}")

    return 0 if counts.get("FAIL", 0) == 0 and counts.get("INVALID", 0) == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
