"""P2 Matrix Launcher — spawns installed factory p2_baseline.py workers.

Why this exists: launching from PowerShell tools / cmd /c / Start-Process with -PassThru
all create child processes that get killed when the parent (claude tool session, sshd shell,
etc.) terminates. This launcher uses Windows DETACHED_PROCESS + CREATE_NEW_PROCESS_GROUP
flags so each worker is a true independent process that survives parent death.

Usage:
    python p2_matrix_launcher.py --ea QM5_1003 --year 2020
    python p2_matrix_launcher.py --ea QM5_1003 --year 2020 --symbols-T1 "AUDCAD.DWX,..." --symbols-T2 "..."

If you don't pass per-terminal symbol lists, it auto-partitions all setfile-discovered
symbols round-robin across installed T1-T10.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# Canonical source of truth for EAs, setfiles, and the p2_baseline runner. Always
# main repo, never a worktree, regardless of where this script is invoked from.
# Load-bearing for cross-worktree consistency: DL-062 + DL-028. Override via
# QM_REPO_ROOT env var for testing only.
REPO_ROOT = Path(os.environ.get("QM_REPO_ROOT", r"C:\QM\repo"))
EA_ROOT = REPO_ROOT / "framework" / "EAs"
P2_RUNNER = REPO_ROOT / "framework" / "scripts" / "p2_baseline.py"
MT5_ROOT = Path(os.environ.get("QM_MT5_ROOT", r"D:\QM\mt5"))
TERMINALS = [f"T{i}" for i in range(1, 11)]

# Windows process creation flags
DETACHED_PROCESS = 0x00000008
CREATE_NEW_PROCESS_GROUP = 0x00000200
CREATE_NO_WINDOW = 0x08000000


def installed_terminals() -> list[str]:
    terminals = [terminal for terminal in TERMINALS if (MT5_ROOT / terminal / "terminal64.exe").exists()]
    return terminals or list(TERMINALS)


def find_ea_dir(ea_label: str) -> Path:
    candidates = [p for p in EA_ROOT.glob(f"{ea_label}_*") if p.is_dir()]
    if not candidates:
        raise SystemExit(f"[FATAL] EA dir not found: {EA_ROOT}/{ea_label}_*")
    return candidates[0]


def discover_symbols(ea_label: str, period: str) -> list[str]:
    ea_dir = find_ea_dir(ea_label)
    pat = re.compile(rf"^{re.escape(ea_dir.name)}_(.+?)_{re.escape(period)}_backtest\.set$")
    out = []
    for f in sorted((ea_dir / "sets").iterdir()):
        m = pat.match(f.name)
        if m:
            out.append(m.group(1))
    return out


def filter_full_data_symbols(symbols: list[str], year: int, threshold_bytes: int = 1_000_000) -> list[str]:
    """Keep only symbols with full .hcc for the given year."""
    history = Path(rf"D:\QM\mt5\T1\bases\Custom\history")
    out = []
    for s in symbols:
        hcc = history / s / f"{year}.hcc"
        try:
            if hcc.exists() and hcc.stat().st_size >= threshold_bytes:
                out.append(s)
        except OSError:
            continue
    return out


def launch_worker(ea_label: str, year: int, period: str, runs: int, terminal: str,
                  symbols: list[str], log_dir: Path, timeout_sec: int,
                  allow_running_terminal: bool) -> int:
    """Launch one p2_baseline.py worker, return its PID. Truly detached."""
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_path = log_dir / f"p2_launcher_{terminal}_{ts}.log"
    err_path = log_dir / f"p2_launcher_{terminal}_{ts}.err"
    log_dir.mkdir(parents=True, exist_ok=True)

    args = [
        sys.executable,
        str(P2_RUNNER),
        "--ea", ea_label,
        "--year", str(year),
        "--period", period,
        "--runs", str(runs),
        "--symbols", ",".join(symbols),
        "--terminal", terminal,
        "--timeout", str(timeout_sec),
        "--resume",
    ]
    if allow_running_terminal:
        args.append("--allow-running-terminal")

    log_f = log_path.open("w", encoding="utf-8")
    err_f = err_path.open("w", encoding="utf-8")

    creationflags = DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP | CREATE_NO_WINDOW
    proc = subprocess.Popen(
        args,
        stdout=log_f,
        stderr=err_f,
        stdin=subprocess.DEVNULL,
        creationflags=creationflags,
        close_fds=True,
    )
    print(f"[LAUNCH] {terminal}: PID {proc.pid} | {len(symbols)} symbols | log {log_path}")
    return proc.pid


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ea", required=True)
    ap.add_argument("--year", type=int, default=2020)
    ap.add_argument("--period", default="H1")
    ap.add_argument("--runs", type=int, default=2)
    ap.add_argument("--timeout", type=int, default=2400)
    ap.add_argument("--filter-full-data", action="store_true",
                    help=f"only keep symbols with .hcc >= 1MB for the requested year")
    ap.add_argument("--log-dir", default=r"D:\QM\reports\pipeline\p2_launcher")
    ap.add_argument("--allow-running-terminal", action="store_true",
                    help="pass --allow-running-terminal through to p2_baseline workers")
    args = ap.parse_args()

    symbols = discover_symbols(args.ea, args.period)
    print(f"[discover] {len(symbols)} setfiles found for {args.ea}")

    if args.filter_full_data:
        before = len(symbols)
        symbols = filter_full_data_symbols(symbols, args.year)
        print(f"[filter] {len(symbols)}/{before} symbols have full {args.year} .hcc")

    if not symbols:
        print("[FATAL] no symbols to dispatch")
        return 2

    terminals = installed_terminals()

    # Round-robin partition
    buckets: dict[str, list[str]] = {t: [] for t in terminals}
    for i, s in enumerate(symbols):
        buckets[terminals[i % len(terminals)]].append(s)

    log_dir = Path(args.log_dir)
    pids = {}
    for t in terminals:
        if not buckets[t]:
            continue
        pid = launch_worker(
            args.ea,
            args.year,
            args.period,
            args.runs,
            t,
            buckets[t],
            log_dir,
            args.timeout,
            args.allow_running_terminal,
        )
        pids[t] = pid

    print()
    print(f"[OK] launched {len(pids)} workers (year={args.year}, ea={args.ea})")
    for t, p in pids.items():
        print(f"  {t}: PID {p} | symbols={buckets[t]}")
    print()
    print("Workers are detached. Monitor via:")
    print(f"  ls {log_dir}\\")
    print(f"  tasklist | findstr python")
    return 0


if __name__ == "__main__":
    sys.exit(main())
