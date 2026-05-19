#!/usr/bin/env python3
"""Build P5 clean/stress metrics by driving run_smoke.ps1 deterministically."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from itertools import cycle
from pathlib import Path

from _phase_utils import ensure_dir, load_json, normalize_symbol, parse_float, parse_int, write_json

TERMINALS = tuple(f"T{i}" for i in range(1, 11))


def _read_smoke_summary(path: Path) -> dict:
    data = load_json(path)
    runs = [r for r in data.get("runs", []) if str(r.get("status", "")).upper() == "OK"]
    first = runs[0] if runs else {}
    return {
        "pf": parse_float(first.get("profit_factor", 0.0)),
        "trade_count": parse_int(first.get("total_trades", 0)),
        "net_profit": parse_float(first.get("net_profit", 0.0)),
        "summary_path": str(path),
    }


def _run_smoke(
    smoke_script: Path,
    *,
    ea_id: int,
    symbol: str,
    year: int,
    period: str,
    terminal: str,
    runs: int,
    min_trades: int,
    setfile: Path | None,
    allow_running_terminal: bool,
    smoke_timeout_seconds: int,
) -> Path:
    cmd = [
        "pwsh",
        "-NoProfile",
        "-File",
        str(smoke_script),
        "-EAId",
        str(ea_id),
        "-Symbol",
        symbol,
        "-Year",
        str(year),
        "-Period",
        period,
        "-Terminal",
        terminal,
        "-Runs",
        str(runs),
        "-MinTrades",
        str(min_trades),
    ]
    if setfile:
        cmd.extend(["-SetFile", str(setfile)])
    if allow_running_terminal:
        cmd.append("-AllowRunningTerminal")
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=smoke_timeout_seconds, creationflags=creationflags)
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"run_smoke timed out after {smoke_timeout_seconds}s\ncmd={' '.join(cmd)}") from exc
    if proc.returncode != 0:
        raise RuntimeError(f"run_smoke failed\ncmd={' '.join(cmd)}\nstdout={proc.stdout}\nstderr={proc.stderr}")
    summary_line = ""
    for line in proc.stdout.splitlines():
        if line.startswith("run_smoke.summary="):
            summary_line = line
    if not summary_line:
        raise RuntimeError(f"run_smoke summary path missing\nstdout={proc.stdout}\nstderr={proc.stderr}")
    return Path(summary_line.split("=", 1)[1].strip())


def _run_smoke_parallel(
    smoke_script: Path,
    *,
    jobs: list[dict],
    max_parallel: int,
    smoke_timeout_seconds: int,
) -> tuple[dict[str, Path], list[dict[str, str | int | float]]]:
    terminals = cycle(TERMINALS)
    queue = list(jobs)
    running: dict[str, dict] = {}
    results: dict[str, Path] = {}
    starts: list[dict[str, str | int | float]] = []
    while queue or running:
        while queue and len(running) < max(1, max_parallel):
            job = queue.pop(0)
            pinned_terminal = str(job.get("terminal", "")).strip()
            terminal = next(terminals) if pinned_terminal.lower() in ("", "any") else pinned_terminal
            cmd = [
                "pwsh",
                "-NoProfile",
                "-File",
                str(smoke_script),
                "-EAId",
                str(job["ea_id"]),
                "-Symbol",
                str(job["symbol"]),
                "-Year",
                str(job["year"]),
                "-Period",
                str(job["period"]),
                "-Terminal",
                terminal,
                "-Runs",
                str(job["runs"]),
                "-MinTrades",
                str(job["min_trades"]),
            ]
            if job.get("setfile"):
                cmd.extend(["-SetFile", str(job["setfile"])])
            if job.get("allow_running_terminal"):
                cmd.append("-AllowRunningTerminal")
            creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, creationflags=creationflags)
            starts.append({"job_id": str(job["id"]), "terminal": terminal, "started_epoch": time.time()})
            running[str(job["id"])] = {"proc": proc, "job": job, "started": time.monotonic()}
        finished: list[str] = []
        for job_id, meta in list(running.items()):
            proc: subprocess.Popen[str] = meta["proc"]
            if proc.poll() is None:
                elapsed = time.monotonic() - float(meta["started"])
                if elapsed > smoke_timeout_seconds:
                    proc.kill()
                    stdout, stderr = proc.communicate()
                    raise RuntimeError(f"run_smoke timed out after {smoke_timeout_seconds}s\nstdout={stdout}\nstderr={stderr}")
                continue
            stdout, stderr = proc.communicate()
            if proc.returncode != 0:
                raise RuntimeError(f"run_smoke failed for {job_id}\nstdout={stdout}\nstderr={stderr}")
            summary_line = ""
            for line in stdout.splitlines():
                if line.startswith("run_smoke.summary="):
                    summary_line = line
            if not summary_line:
                raise RuntimeError(f"run_smoke summary path missing for {job_id}\nstdout={stdout}\nstderr={stderr}")
            results[job_id] = Path(summary_line.split("=", 1)[1].strip())
            finished.append(job_id)
        for job_id in finished:
            running.pop(job_id, None)
        if running:
            time.sleep(0.25)
    return results, starts


def _write_stress_setfile(base_setfile: Path | None, out_path: Path, *, commission_cents_per_lot: float, spread_points: float) -> None:
    lines: list[str] = []
    if base_setfile and base_setfile.exists():
        lines.extend(base_setfile.read_text(encoding="utf-8", errors="replace").splitlines())
    lines.append(f"Inp_CommissionCentsPerLot={commission_cents_per_lot}")
    lines.append(f"Inp_SpreadPoints={spread_points}")
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ea", required=True, help="QM5_<id>")
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--symbols", default="")
    ap.add_argument("--year", type=int, required=True)
    ap.add_argument("--period", default="H1")
    ap.add_argument("--terminal", default="any")
    ap.add_argument("--runs", type=int, default=2)
    ap.add_argument("--min-trades", type=int, default=20)
    ap.add_argument("--calibration-json", required=True)
    ap.add_argument("--base-setfile", default="")
    ap.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    ap.add_argument("--smoke-script", default="framework/scripts/run_smoke.ps1")
    ap.add_argument("--allow-running-terminal", action="store_true")
    ap.add_argument("--smoke-timeout-seconds", type=int, default=1200)
    ap.add_argument("--max-parallel", type=int, default=5)
    ap.add_argument("--mock-clean-summary", default="")
    ap.add_argument("--mock-stress-summary", default="")
    args = ap.parse_args()

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P5")
    calibration = load_json(Path(args.calibration_json))
    symbols = [s.strip() for s in args.symbols.split(",") if s.strip()] if args.symbols else [args.symbol]

    base_setfile = Path(args.base_setfile) if args.base_setfile else None
    ea_num = int(args.ea.split("_")[1])
    stress_setfiles: dict[str, Path] = {}
    for symbol in symbols:
        symbol_key = symbol if symbol in calibration.get("symbols", {}) else f"{normalize_symbol(symbol)}.DWX"
        block = calibration.get("symbols", {}).get(symbol_key, {})
        commission = parse_float(block.get("commission_cents_per_lot", 0.0))
        spread = parse_float(block.get("spread_points", {}).get("p95", 0.0))
        stress_setfile = out_dir / f"{args.ea}_{normalize_symbol(symbol)}_P5_STRESS.set"
        _write_stress_setfile(base_setfile, stress_setfile, commission_cents_per_lot=commission, spread_points=spread)
        stress_setfiles[symbol] = stress_setfile

    metrics_by_symbol: dict[str, dict] = {}
    timing_evidence: list[dict[str, str | int | float]] = []
    if args.mock_clean_summary and args.mock_stress_summary and len(symbols) == 1:
        clean_metrics = _read_smoke_summary(Path(args.mock_clean_summary))
        stress_metrics = _read_smoke_summary(Path(args.mock_stress_summary))
        metrics_by_symbol[symbols[0]] = {"clean": clean_metrics, "stress": stress_metrics}
    else:
        clean_jobs = []
        stress_jobs = []
        for symbol in symbols:
            clean_jobs.append(
                {
                    "id": f"{symbol}:clean",
                    "ea_id": ea_num,
                    "symbol": symbol,
                    "year": args.year,
                    "period": args.period,
                    "terminal": args.terminal,
                    "runs": args.runs,
                    "min_trades": args.min_trades,
                    "setfile": base_setfile,
                    "allow_running_terminal": args.allow_running_terminal,
                }
            )
            stress_jobs.append(
                {
                    "id": f"{symbol}:stress",
                    "ea_id": ea_num,
                    "symbol": symbol,
                    "year": args.year,
                    "period": args.period,
                    "terminal": args.terminal,
                    "runs": args.runs,
                    "min_trades": args.min_trades,
                    "setfile": stress_setfiles[symbol],
                    "allow_running_terminal": args.allow_running_terminal,
                }
            )
        clean_paths, clean_starts = _run_smoke_parallel(Path(args.smoke_script), jobs=clean_jobs, max_parallel=args.max_parallel, smoke_timeout_seconds=args.smoke_timeout_seconds)
        stress_paths, stress_starts = _run_smoke_parallel(Path(args.smoke_script), jobs=stress_jobs, max_parallel=args.max_parallel, smoke_timeout_seconds=args.smoke_timeout_seconds)
        timing_evidence = clean_starts + stress_starts
        for symbol in symbols:
            metrics_by_symbol[symbol] = {
                "clean": _read_smoke_summary(clean_paths[f"{symbol}:clean"]),
                "stress": _read_smoke_summary(stress_paths[f"{symbol}:stress"]),
            }

    clean_payload = {"symbols": []}
    stress_payload = {"symbols": []}
    for symbol in symbols:
        clean_payload["symbols"].append(
            {
                "symbol": symbol,
                "pf": metrics_by_symbol[symbol]["clean"]["pf"],
                "trade_count": metrics_by_symbol[symbol]["clean"]["trade_count"],
                "net_profit": metrics_by_symbol[symbol]["clean"]["net_profit"],
            }
        )
        stress_payload["symbols"].append(
            {
                "symbol": symbol,
                "pf": metrics_by_symbol[symbol]["stress"]["pf"],
                "trade_count": metrics_by_symbol[symbol]["stress"]["trade_count"],
                "net_profit": metrics_by_symbol[symbol]["stress"]["net_profit"],
            }
        )
    clean_path = out_dir / "p5_clean_metrics.json"
    stress_path = out_dir / "p5_stress_metrics.json"
    if len(symbols) == 1:
        only = symbols[0]
        clean_payload.update(
            {
                "symbol": only,
                "pf": metrics_by_symbol[only]["clean"]["pf"],
                "trade_count": metrics_by_symbol[only]["clean"]["trade_count"],
                "net_profit": metrics_by_symbol[only]["clean"]["net_profit"],
            }
        )
        stress_payload.update(
            {
                "symbol": only,
                "pf": metrics_by_symbol[only]["stress"]["pf"],
                "trade_count": metrics_by_symbol[only]["stress"]["trade_count"],
                "net_profit": metrics_by_symbol[only]["stress"]["net_profit"],
            }
        )
    write_json(clean_path, clean_payload)
    write_json(stress_path, stress_payload)
    if timing_evidence:
        write_json(out_dir / "p5_parallel_timing.json", {"starts": timing_evidence, "max_parallel": args.max_parallel})
    print(json.dumps({"clean_metrics_json": str(clean_path), "stress_metrics_json": str(stress_path), "stress_setfiles": {k: str(v) for k, v in stress_setfiles.items()}}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
