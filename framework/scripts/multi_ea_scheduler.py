#!/usr/bin/env python3
"""Cross-EA scheduler that keeps T1-T5 saturated across multiple EAs."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from framework.scripts.build_multi_ea_queue import build_queue as _build_queue_from_sources
from framework.scripts.build_multi_ea_queue import load_source as _load_queue_sources

TERMINALS = ("T1", "T2", "T3", "T4", "T5")
DEFAULT_QUEUE_PATH = Path(r"D:\QM\Reports\pipeline\multi_ea_job_queue.json")
DEFAULT_STATE_PATH = Path(r"D:\QM\Reports\pipeline\multi_ea_scheduler_state.json")
DEFAULT_RUNS_DIR = Path(r"D:\QM\Reports\pipeline\multi_ea_scheduler_runs")
DEFAULT_IDLE_ALARM_PATH = Path(r"D:\QM\Reports\pipeline\multi_ea_idle_alarm.json")
DEFAULT_IDLE_SECONDS = 600
SECONDS_24H = 24 * 60 * 60
REPO_ROOT = Path(__file__).resolve().parents[2]
EA_ROOT = REPO_ROOT / "framework" / "EAs"


@dataclass(frozen=True)
class Job:
    ea_id: str
    phase: str
    symbol: str
    config_hash: str

    @property
    def job_id(self) -> str:
        return f"{self.ea_id}|{self.phase}|{self.symbol}|{self.config_hash}"


class SchedulerError(RuntimeError):
    pass


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")


def validate_queue_item(raw: dict[str, Any]) -> Job:
    if not isinstance(raw, dict):
        raise SchedulerError("queue item must be an object")
    fields = ("ea_id", "phase", "symbol", "config_hash")
    values: dict[str, str] = {}
    for field in fields:
        value = raw.get(field)
        if not isinstance(value, str) or not value.strip():
            raise SchedulerError(f"queue item field '{field}' must be non-empty string")
        values[field] = value.strip()
    if not values["symbol"].endswith(".DWX"):
        raise SchedulerError("queue item symbol must end with .DWX")
    return Job(**values)


def load_queue(path: Path) -> list[Job]:
    payload = _load_json(path, default=[])
    if not isinstance(payload, list):
        raise SchedulerError("queue payload must be an array")
    return [validate_queue_item(item) for item in payload]


def save_queue(path: Path, queue: list[Job]) -> None:
    payload = [
        {"ea_id": job.ea_id, "phase": job.phase, "symbol": job.symbol, "config_hash": job.config_hash}
        for job in queue
    ]
    _write_json(path, payload)


def load_state(path: Path) -> dict[str, Any]:
    state = _load_json(path, default={})
    if not isinstance(state, dict):
        state = {}
    state.setdefault("running", {})
    state.setdefault("last_active_utc", None)
    state.setdefault("history", [])
    state.setdefault("utilization_samples", [])
    state.setdefault("idle_alarm", {"active": False, "last_alarm_utc": None})
    return state


def persist_run_record(runs_dir: Path, record: dict[str, Any]) -> None:
    runs_dir.mkdir(parents=True, exist_ok=True)
    ts = record["started_at_utc"].replace(":", "-")
    path = runs_dir / f"{ts}_{record['job_id'].replace('|', '_')}.json"
    _write_json(path, record)


def _resolve_ea_numeric_and_expert(ea_id: str) -> tuple[int, str]:
    """Resolve numeric EA id and explicit MT5 expert path from queue EA label."""
    raw = ea_id.strip()
    m = re.match(r"^QM5_(\d+)(?:_.+)?$", raw)
    if m:
        numeric = int(m.group(1))
        if "_" in raw[len(f"QM5_{numeric}"):]:
            return numeric, f"QM\\{raw}"
        canonical = f"QM5_{numeric}"
    elif raw.isdigit():
        numeric = int(raw)
        canonical = f"QM5_{numeric}"
    else:
        raise SchedulerError(f"unsupported ea_id format: {ea_id}")

    candidates = [p for p in EA_ROOT.glob(f"{canonical}_*") if p.is_dir()]
    if len(candidates) == 1:
        return numeric, f"QM\\{candidates[0].name}"
    if len(candidates) > 1:
        names = ", ".join(sorted(p.name for p in candidates))
        raise SchedulerError(f"ambiguous EA directory for {canonical}: {names}")
    return numeric, f"QM\\{canonical}"


def build_launch_command(job: Job, terminal: str) -> list[str]:
    script_root = Path(__file__).resolve().parent
    if job.phase in {"P0", "P1"}:
        numeric_ea_id, expert = _resolve_ea_numeric_and_expert(job.ea_id)
        return [
            "powershell",
            "-NoProfile",
            "-Command",
            (
                f"& '{(script_root / 'run_smoke.ps1').as_posix()}'"
                f" -EAId {numeric_ea_id}"
                f" -Expert '{expert}'"
                f" -Symbol '{job.symbol}'"
                f" -Year 2025"
                f" -Terminal {terminal}"
            ),
        ]
    if job.phase in {"P3.5", "P5", "P5b", "P5c", "P6", "P7", "P8", "P10"}:
        return [
            "powershell",
            "-NoProfile",
            "-Command",
            (
                f"& '{(script_root / 'run_phase.ps1').as_posix()}'"
                f" -EAId {job.ea_id}"
                f" -Phase {job.phase}"
                f" -Symbols @('{job.symbol}')"
            ),
        ]
    raise SchedulerError(f"unsupported phase for dispatch: {job.phase}")


def _pid_is_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    if os.name == "nt":
        import ctypes
        from ctypes import wintypes

        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        open_process = kernel32.OpenProcess
        open_process.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
        open_process.restype = wintypes.HANDLE
        get_exit_code_process = kernel32.GetExitCodeProcess
        get_exit_code_process.argtypes = (wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD))
        get_exit_code_process.restype = wintypes.BOOL
        close_handle = kernel32.CloseHandle
        close_handle.argtypes = (wintypes.HANDLE,)
        close_handle.restype = wintypes.BOOL

        handle = open_process(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
        if not handle:
            return False
        try:
            exit_code = wintypes.DWORD()
            if not get_exit_code_process(handle, ctypes.byref(exit_code)):
                return False
            return exit_code.value == 259  # STILL_ACTIVE
        finally:
            close_handle(handle)
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def reconcile_finished_jobs(state: dict[str, Any], runs_dir: Path) -> None:
    running = state.get("running", {})
    finished: list[str] = []
    for terminal, slot in list(running.items()):
        pid = int(slot.get("pid", 0))
        if pid <= 0:
            finished.append(terminal)
            continue
        if _pid_is_alive(pid):
            continue
        started = slot.get("started_at_utc")
        record = {
            "job_id": slot.get("job_id"),
            "ea_id": slot.get("ea_id"),
            "phase": slot.get("phase"),
            "symbol": slot.get("symbol"),
            "terminal": terminal,
            "status": "finished_or_exited",
            "reason": "process_not_running",
            "started_at_utc": started,
            "ended_at_utc": _iso(utc_now()),
            "duration_sec": None,
            "exit_code": None,
            "evidence_paths": [],
        }
        persist_run_record(runs_dir, record)
        state["history"].append(record)
        finished.append(terminal)
    for terminal in finished:
        running.pop(terminal, None)


def select_jobs(queue: list[Job], running_terminals: set[str], max_launches: int) -> list[tuple[str, Job]]:
    free_terminals = [terminal for terminal in TERMINALS if terminal not in running_terminals]
    launches: list[tuple[str, Job]] = []
    for job in queue:
        if not free_terminals or len(launches) >= max_launches:
            break
        terminal = free_terminals.pop(0)
        launches.append((terminal, job))
    return launches


def emit_idle_alarm(path: Path, idle_since_utc: str, now_utc: str, queue_len: int) -> None:
    payload = {
        "severity": "class_2",
        "kind": "mission_failure_signal",
        "reason": "queue_empty_10m_plus",
        "idle_since_utc": idle_since_utc,
        "alarm_at_utc": now_utc,
        "queue_len": queue_len,
        "target": "board-advisor",
    }
    _write_json(path, payload)


def update_phase_state_kpi(*, state: dict[str, Any], phase_state_path: Path, now_utc: str) -> None:
    samples = state.get("utilization_samples", [])
    if not isinstance(samples, list) or not samples:
        return
    total = 0.0
    count = 0
    for item in samples:
        if not isinstance(item, dict):
            continue
        ratio = item.get("active_ratio")
        if isinstance(ratio, (int, float)):
            total += float(ratio)
            count += 1
    if count == 0:
        return
    pct = (total / count) * 100.0
    kpi_line = f"- MT5 saturation last 24h: {pct:.1f}% avg active ({now_utc})"

    existing = ""
    if phase_state_path.exists():
        existing = phase_state_path.read_text(encoding="utf-8")
    lines = existing.splitlines() if existing else ["# PHASE STATE", ""]
    replaced = False
    for idx, line in enumerate(lines):
        if line.strip().startswith("- MT5 saturation last 24h:"):
            lines[idx] = kpi_line
            replaced = True
            break
    if not replaced:
        if lines and lines[-1] != "":
            lines.append("")
        lines.append(kpi_line)
    phase_state_path.parent.mkdir(parents=True, exist_ok=True)
    phase_state_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def scheduler_tick(
    queue_source_path: Path | None,
    queue_path: Path,
    state_path: Path,
    runs_dir: Path,
    idle_alarm_path: Path,
    phase_state_path: Path,
    *,
    idle_seconds: int,
    max_launches: int,
    dry_run: bool = False,
) -> dict[str, Any]:
    now = utc_now()
    now_s = _iso(now)
    if queue_source_path is not None and queue_source_path.exists():
        approved, transition_ready = _load_queue_sources(queue_source_path)
        source_queue = _build_queue_from_sources(approved, transition_ready)
        save_queue(
            queue_path,
            [
                Job(
                    ea_id=item["ea_id"],
                    phase=item["phase"],
                    symbol=item["symbol"],
                    config_hash=item["config_hash"],
                )
                for item in source_queue
            ],
        )
    queue = load_queue(queue_path)
    state = load_state(state_path)
    running: dict[str, Any] = state["running"]

    # Reap first so new work can use reclaimed terminals.
    reconcile_finished_jobs(state, runs_dir)

    launches = select_jobs(queue, set(running.keys()), max_launches=max_launches)
    scheduled_ids = {job.job_id for _, job in launches}
    remaining_queue = [job for job in queue if job.job_id not in scheduled_ids]
    scheduled = 0
    for terminal, job in launches:
        if dry_run:
            command = ["dry_run", job.ea_id, job.phase, job.symbol, terminal]
            pid = -1
        else:
            command = build_launch_command(job, terminal)
            proc = subprocess.Popen(command)
            pid = int(proc.pid)
        running[terminal] = {
            "pid": pid,
            "job_id": job.job_id,
            "ea_id": job.ea_id,
            "phase": job.phase,
            "symbol": job.symbol,
            "config_hash": job.config_hash,
            "started_at_utc": now_s,
            "command": command,
        }
        scheduled += 1

    if queue or running:
        state["last_active_utc"] = now_s
        state["idle_alarm"] = {"active": False, "last_alarm_utc": state.get("idle_alarm", {}).get("last_alarm_utc")}
    else:
        last_active = state.get("last_active_utc")
        if not last_active:
            state["last_active_utc"] = now_s
        else:
            start = datetime.fromisoformat(last_active.replace("Z", "+00:00"))
            idle_for = (now - start).total_seconds()
            if idle_for >= idle_seconds and not bool(state.get("idle_alarm", {}).get("active")):
                emit_idle_alarm(idle_alarm_path, idle_since_utc=last_active, now_utc=now_s, queue_len=0)
                state["idle_alarm"] = {"active": True, "last_alarm_utc": now_s}

    samples = state.setdefault("utilization_samples", [])
    samples.append(
        {
            "ts_utc": now_s,
            "active_terminals": len(running),
            "active_ratio": len(running) / len(TERMINALS),
        }
    )
    now_epoch = int(now.timestamp())
    keep_cutoff = now_epoch - SECONDS_24H
    pruned: list[dict[str, Any]] = []
    for item in samples:
        ts = str(item.get("ts_utc", ""))
        try:
            item_epoch = int(datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp())
        except Exception:
            continue
        if item_epoch >= keep_cutoff:
            pruned.append(item)
    state["utilization_samples"] = pruned

    _write_json(state_path, state)
    save_queue(queue_path, remaining_queue)
    update_phase_state_kpi(state=state, phase_state_path=phase_state_path, now_utc=now_s)
    return {
        "scheduled": scheduled,
        "running": len(running),
        "queue": len(remaining_queue),
        "timestamp_utc": now_s,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Cross-EA terminal saturator scheduler")
    parser.add_argument("--queue", type=Path, default=DEFAULT_QUEUE_PATH)
    parser.add_argument("--queue-source", type=Path, default=None)
    parser.add_argument("--state", type=Path, default=DEFAULT_STATE_PATH)
    parser.add_argument("--runs-dir", type=Path, default=DEFAULT_RUNS_DIR)
    parser.add_argument("--idle-alarm", type=Path, default=DEFAULT_IDLE_ALARM_PATH)
    parser.add_argument("--phase-state", type=Path, default=Path("PHASE_STATE.md"))
    parser.add_argument("--idle-seconds", type=int, default=DEFAULT_IDLE_SECONDS)
    parser.add_argument("--max-launches", type=int, default=5)
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--sleep-seconds", type=int, default=30)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    while True:
        summary = scheduler_tick(
            args.queue_source,
            args.queue,
            args.state,
            args.runs_dir,
            args.idle_alarm,
            args.phase_state,
            idle_seconds=args.idle_seconds,
            max_launches=args.max_launches,
            dry_run=bool(args.dry_run),
        )
        print(json.dumps(summary, sort_keys=True))
        if args.once:
            return 0
        time.sleep(args.sleep_seconds)


if __name__ == "__main__":
    raise SystemExit(main())
