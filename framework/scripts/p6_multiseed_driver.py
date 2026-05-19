#!/usr/bin/env python3
"""Run deterministic P6 multi-seed smoke dispatch and emit seeds CSV."""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from itertools import cycle
from pathlib import Path

from _phase_utils import ensure_dir, parse_float, parse_int

TERMINALS = tuple(f"T{i}" for i in range(1, 11))


def _infer_parent_worker_terminal() -> str:
    if sys.platform != "win32":
        return ""
    command = (
        "$p=(Get-CimInstance Win32_Process -Filter \"ProcessId=%d\").CommandLine; "
        "if($p){[Console]::Out.Write($p)}"
    ) % os.getppid()
    proc = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", command],
        capture_output=True,
        text=True,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )
    match = re.search(r"--terminal\s+(T(?:10|[1-9]))\b", proc.stdout or "", re.IGNORECASE)
    return match.group(1).upper() if match else ""


def _ea_label_from_setfile(base_setfile: Path | None, ea: str) -> str:
    if base_setfile:
        for parent in [base_setfile.parent, *base_setfile.parents]:
            if parent.name.startswith(f"{ea}_"):
                return parent.name
    return ea


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
    ea_label: str,
    setfile: Path | None,
    allow_running_terminal: bool,
    smoke_timeout_seconds: int,
) -> dict[str, float]:
    cmd = [
        "pwsh",
        "-NoProfile",
        "-File",
        str(smoke_script),
        "-EAId",
        str(ea_id),
        "-EALabel",
        ea_label,
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
    summary = json.loads(Path(summary_line.split("=", 1)[1].strip()).read_text(encoding="utf-8"))
    ok_runs = [r for r in summary.get("runs", []) if str(r.get("status", "")).upper() == "OK"]
    first = ok_runs[0] if ok_runs else {}
    return {
        "pf": parse_float(first.get("profit_factor", 0.0)),
        "trades": parse_int(first.get("total_trades", 0)),
        "seed_pass": 1.0 if str(summary.get("result", "")).upper() == "PASS" else 0.0,
    }


def _run_smoke_parallel(
    smoke_script: Path,
    *,
    jobs: list[dict],
    max_parallel: int,
    smoke_timeout_seconds: int,
) -> tuple[dict[str, dict[str, float]], list[dict[str, str | int | float]]]:
    terminals = cycle(TERMINALS)
    queue = list(jobs)
    running: dict[str, dict] = {}
    results: dict[str, dict[str, float]] = {}
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
                "-EALabel",
                str(job["ea_label"]),
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
                "-SetFile",
                str(job["setfile"]),
            ]
            if job.get("allow_running_terminal"):
                cmd.append("-AllowRunningTerminal")
            creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
            safe_job_id = re.sub(r"[^A-Za-z0-9_.-]+", "_", str(job["id"]))
            log_dir = Path(str(job.get("log_dir") or Path(str(job.get("setfile") or tempfile.gettempdir())).parent))
            log_dir.mkdir(parents=True, exist_ok=True)
            log_path = log_dir / f"p6_run_smoke_{safe_job_id}.log"
            log_fh = log_path.open("w", encoding="utf-8")
            log_fh.write("cmd=" + " ".join(cmd) + "\n")
            log_fh.flush()
            proc = subprocess.Popen(cmd, stdout=log_fh, stderr=subprocess.STDOUT, text=True, creationflags=creationflags)
            starts.append({"job_id": str(job["id"]), "terminal": terminal, "started_epoch": time.time()})
            running[str(job["id"])] = {"proc": proc, "job": job, "started": time.monotonic(), "log_fh": log_fh, "log_path": log_path}
        finished: list[str] = []
        for job_id, meta in list(running.items()):
            proc: subprocess.Popen[str] = meta["proc"]
            if proc.poll() is None:
                elapsed = time.monotonic() - float(meta["started"])
                if elapsed > smoke_timeout_seconds:
                    proc.kill()
                    proc.wait(timeout=30)
                    meta["log_fh"].close()
                    log_text = Path(meta["log_path"]).read_text(encoding="utf-8", errors="replace")
                    raise RuntimeError(f"run_smoke timed out after {smoke_timeout_seconds}s\nlog={meta['log_path']}\n{log_text[-8000:]}")
                continue
            meta["log_fh"].close()
            stdout = Path(meta["log_path"]).read_text(encoding="utf-8", errors="replace")
            stderr = ""
            summary_line = ""
            for line in stdout.splitlines():
                if line.startswith("run_smoke.summary="):
                    summary_line = line
            if not summary_line:
                if proc.returncode != 0:
                    raise RuntimeError(f"run_smoke failed for {job_id}\nlog={meta['log_path']}\nstdout={stdout}\nstderr={stderr}")
                raise RuntimeError(f"run_smoke summary path missing for {job_id}\nstdout={stdout}\nstderr={stderr}")
            summary = json.loads(Path(summary_line.split("=", 1)[1].strip()).read_text(encoding="utf-8"))
            ok_runs = [r for r in summary.get("runs", []) if str(r.get("status", "")).upper() == "OK"]
            first = ok_runs[0] if ok_runs else {}
            results[job_id] = {
                "pf": parse_float(first.get("profit_factor", 0.0)),
                "trades": parse_int(first.get("total_trades", 0)),
                "seed_pass": 1.0 if str(summary.get("result", "")).upper() == "PASS" else 0.0,
            }
            finished.append(job_id)
        for job_id in finished:
            running.pop(job_id, None)
        if running:
            time.sleep(0.25)
    return results, starts


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--year", type=int, required=True)
    ap.add_argument("--period", default="H1")
    ap.add_argument("--terminal", default="any")
    ap.add_argument("--runs", type=int, default=2)
    ap.add_argument("--min-trades", type=int, default=20)
    ap.add_argument("--seeds", default="42,17,99,7,2026")
    ap.add_argument("--base-setfile", default="")
    ap.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    ap.add_argument("--smoke-script", default="framework/scripts/run_smoke.ps1")
    ap.add_argument("--allow-running-terminal", action="store_true")
    ap.add_argument("--smoke-timeout-seconds", type=int, default=1200)
    ap.add_argument("--max-parallel", type=int, default=5)
    ap.add_argument("--mock-seeds-csv", default="")
    args = ap.parse_args()

    inferred_terminal = _infer_parent_worker_terminal() if str(args.terminal).lower() in ("", "any") else ""
    if inferred_terminal:
        args.terminal = inferred_terminal
        args.max_parallel = 1
        args.allow_running_terminal = False

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P6")
    seeds = [int(tok.strip()) for tok in args.seeds.split(",") if tok.strip()]
    out_csv = out_dir / "p6_seeds.csv"
    if args.mock_seeds_csv:
        out_csv.write_text(Path(args.mock_seeds_csv).read_text(encoding="utf-8"), encoding="utf-8")
        print(out_csv)
        return 0

    ea_num = int(args.ea.split("_")[1])
    base_setfile = Path(args.base_setfile) if args.base_setfile else None
    ea_label = _ea_label_from_setfile(base_setfile, args.ea)
    base_lines: list[str] = []
    if args.base_setfile:
        base_lines = base_setfile.read_text(encoding="utf-8", errors="replace").splitlines()

    tmp_csv = out_dir / "p6_seeds.tmp.csv"
    setfiles: list[tuple[int, Path]] = []
    for seed in seeds:
        set_path = out_dir / f"{args.ea}_{args.symbol.replace('.', '_')}_seed_{seed}.set"
        set_lines = list(base_lines) + [f"Inp_RngSeed={seed}", f"Inp_MonteCarloSeed={seed}"]
        set_path.write_text("\n".join(set_lines) + "\n", encoding="utf-8")
        setfiles.append((seed, set_path))

    jobs = [
        {
            "id": f"seed:{seed}",
            "ea_id": ea_num,
            "ea_label": ea_label,
            "symbol": args.symbol,
            "year": args.year,
            "period": args.period,
            "terminal": args.terminal,
            "runs": args.runs,
            "min_trades": args.min_trades,
            "setfile": set_path,
            "log_dir": out_dir,
            "allow_running_terminal": args.allow_running_terminal,
        }
        for seed, set_path in setfiles
    ]
    results, starts = _run_smoke_parallel(
        Path(args.smoke_script),
        jobs=jobs,
        max_parallel=args.max_parallel,
        smoke_timeout_seconds=args.smoke_timeout_seconds,
    )

    with tmp_csv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["seed", "seed_pass", "profit_factor", "trade_count"])
        writer.writeheader()
        for seed in seeds:
            metrics = results[f"seed:{seed}"]
            writer.writerow(
                {
                    "seed": seed,
                    "seed_pass": "PASS" if metrics["seed_pass"] >= 1 else "FAIL",
                    "profit_factor": metrics["pf"],
                    "trade_count": int(metrics["trades"]),
                }
            )
    tmp_csv.replace(out_csv)
    (out_dir / "p6_parallel_timing.json").write_text(
        json.dumps({"starts": starts, "max_parallel": args.max_parallel}, indent=2) + "\n",
        encoding="utf-8",
    )
    print(out_csv)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
