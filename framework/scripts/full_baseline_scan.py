#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from framework.scripts.pipeline_dispatcher import load_dispatch_state

RUN_SMOKE = REPO_ROOT / "framework" / "scripts" / "run_smoke.ps1"
RESOLVER = REPO_ROOT / "framework" / "scripts" / "resolve_backtest_target.py"
EA_ROOT = REPO_ROOT / "framework" / "EAs"
FACTORY_TERMINALS = tuple(f"T{i}" for i in range(1, 11))
CREATE_NO_WINDOW = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0


@dataclass
class ScheduledJob:
    key: str
    ea_id: str
    version: str
    symbol: str
    phase: str
    cfg_hash: str
    terminal: str
    setfile_path: Path | None
    year: int
    period: str


def _parse_period_year(cfg_hash: str) -> tuple[str, int]:
    period = "H1"
    year = 2024
    parts = cfg_hash.split("-")
    if parts:
        period = parts[0] or period
    if parts and parts[-1].isdigit():
        year = int(parts[-1])
    return period, year


def _derive_setfile_path(ea_id: str, symbol: str, period: str) -> Path | None:
    candidates = [p for p in EA_ROOT.glob(f"{ea_id}_*") if p.is_dir()]
    if not candidates:
        return None
    ea_dir = candidates[0]
    target = ea_dir / "sets" / f"{ea_dir.name}_{symbol}_{period}_backtest.set"
    return target if target.exists() else None


def _fallback_profile_setfile(ea_id: str) -> Path | None:
    candidates = list(Path(r"D:\QM\mt5\T1\MQL5\Profiles\Tester").glob(f"{ea_id}_*.set"))
    if candidates:
        return candidates[0]
    return None


def _collect_scheduled_jobs(state: dict[str, Any]) -> list[ScheduledJob]:
    dedup = state.get("dedup", {})
    if not isinstance(dedup, dict):
        return []
    jobs: list[ScheduledJob] = []
    for key, record in dedup.items():
        if not isinstance(record, dict):
            continue
        if str(record.get("status", "")).lower() == "complete":
            continue
        parts = key.split("|")
        if len(parts) != 5:
            continue
        ea_id, version, symbol, phase, cfg_hash = parts
        if phase.upper() != "P2":
            continue
        terminal = str(record.get("terminal", ""))
        if terminal not in FACTORY_TERMINALS:
            continue
        period, year = _parse_period_year(cfg_hash)
        setfile_path: Path | None = None
        job_meta = record.get("job")
        if isinstance(job_meta, dict):
            raw = str(job_meta.get("setfile_path", "")).strip()
            if raw:
                candidate = Path(raw)
                if not candidate.is_absolute():
                    candidate = (REPO_ROOT / candidate).resolve()
                if candidate.exists():
                    setfile_path = candidate
        if setfile_path is None:
            setfile_path = _derive_setfile_path(ea_id, symbol, period)
        if setfile_path is None:
            setfile_path = _fallback_profile_setfile(ea_id)
        jobs.append(
            ScheduledJob(
                key=key,
                ea_id=ea_id,
                version=version,
                symbol=symbol,
                phase=phase,
                cfg_hash=cfg_hash,
                terminal=terminal,
                setfile_path=setfile_path,
                year=year,
                period=period,
            )
        )
    return jobs


def _ea_numeric_id(ea_id: str) -> int | None:
    try:
        return int(ea_id.split("_", 1)[1])
    except Exception:
        return None


def _invoke_dispatch_complete(job: ScheduledJob, state_json: Path) -> None:
    payload = {
        "ea_id": job.ea_id,
        "version": job.version,
        "symbol": job.symbol,
        "phase": job.phase,
        "sub_gate_config_hash": job.cfg_hash,
        "target_terminal": "any",
        "setfile_path": str(job.setfile_path) if job.setfile_path is not None else "legacy_placeholder.set",
    }
    tmp = Path(f"{state_json}.complete_job.json")
    tmp.write_text(json.dumps(payload), encoding="utf-8")
    try:
        subprocess.run(
            [sys.executable, str(RESOLVER), "--job-json", str(tmp), "--state-json", str(state_json), "--event", "complete", "--prune-completed"],
            check=False,
            capture_output=True,
            text=True,
            timeout=60,
            creationflags=CREATE_NO_WINDOW,
        )
    finally:
        try:
            tmp.unlink()
        except OSError:
            pass


def _run_one(job: ScheduledJob, timeout_sec: int, state_json: Path) -> int:
    ea_num = _ea_numeric_id(job.ea_id)
    if ea_num is None:
        return 2
    report_root = Path(r"D:\QM\reports\pipeline") / job.ea_id / job.phase
    cmd = [
        "pwsh.exe",
        "-NoProfile",
        "-File",
        str(RUN_SMOKE),
        "-EAId",
        str(ea_num),
        "-Symbol",
        job.symbol,
        "-Year",
        str(job.year),
        "-Terminal",
        job.terminal,
        "-Period",
        job.period,
        "-Runs",
        "2",
        "-MinTrades",
        "20",
        "-Model",
        "4",
        "-TimeoutSeconds",
        str(timeout_sec),
        "-ReportRoot",
        str(report_root),
    ]
    if job.setfile_path is not None:
        cmd.extend(["-SetFile", str(job.setfile_path)])
    proc = subprocess.run(
        cmd,
        check=False,
        capture_output=True,
        text=True,
        timeout=(timeout_sec * 2) + 120,
        creationflags=CREATE_NO_WINDOW,
    )
    _invoke_dispatch_complete(job, state_json=state_json)
    return int(proc.returncode)


def main() -> int:
    ap = argparse.ArgumentParser(description="Consume scheduled P2 dispatch keys and execute run_smoke jobs.")
    ap.add_argument("--state-json", default=r"D:\QM\Reports\pipeline\dispatch_state.json")
    ap.add_argument("--poll-sec", type=int, default=20)
    ap.add_argument("--max-jobs", type=int, default=3)
    ap.add_argument("--timeout-sec", type=int, default=1800)
    ap.add_argument("--once", action="store_true")
    args = ap.parse_args()

    state_path = Path(args.state_json)
    while True:
        state = load_dispatch_state(state_path)
        jobs = _collect_scheduled_jobs(state)
        if not jobs:
            if args.once:
                print("full_baseline_scan: no scheduled P2 jobs")
                return 0
            time.sleep(max(5, args.poll_sec))
            continue

        selected = jobs[: max(1, args.max_jobs)]
        print(f"full_baseline_scan: executing {len(selected)} scheduled jobs")
        for job in selected:
            print(f"full_baseline_scan: {job.key} terminal={job.terminal}")
            _run_one(job, timeout_sec=args.timeout_sec, state_json=state_path)

        if args.once:
            return 0
        time.sleep(max(5, args.poll_sec))


if __name__ == "__main__":
    raise SystemExit(main())
