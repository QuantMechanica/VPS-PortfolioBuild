#!/usr/bin/env python3
"""V5 standalone aggregator loop for last_check_state.json.

State writer only:
- no dashboard push integration
- no V4 T3 disk-pause policy block
- hard exclusion of T6 paths
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

LOCK_TIMEOUT_SEC = 2.0
LOCK_POLL_SEC = 0.05
LOCK_STALE_SEC = 300.0
STATE_SCHEMA_VERSION = "qm.v5.last_check_state.v1"
ALLOWED_TERMINAL_STATUS = {
    "active",
    "active_no_reports",
    "orphan_scanner_stale_reports",
    "scanner_missing_recent_reports",
    "idle_or_stalled",
}


@dataclass(frozen=True)
class TerminalSpec:
    name: str
    root: Path


TERMINALS: tuple[TerminalSpec, ...] = (
    TerminalSpec("T1", Path(r"D:\QM\mt5\T1")),
    TerminalSpec("T2", Path(r"D:\QM\mt5\T2")),
    TerminalSpec("T3", Path(r"D:\QM\mt5\T3")),
    TerminalSpec("T4", Path(r"D:\QM\mt5\T4")),
    TerminalSpec("T5", Path(r"D:\QM\mt5\T5")),
)

# Hard safety exclusion from CEO scope comment + CLAUDE.md.
EXCLUDED_TERMINAL_ROOTS: tuple[Path, ...] = (
    Path(r"C:\QM\mt5\T6_Live"),
    Path(r"D:\QM\mt5\T6_Live"),
    Path(r"C:\QM\mt5\T6_Demo"),
    Path(r"D:\QM\mt5\T6_Demo"),
)


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def local_now_iso_second() -> str:
    return datetime.now().strftime("%Y-%m-%dT%H:%M:%S")


def safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except Exception:
        return default


def parse_json_file(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def is_pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except Exception:
        return False


def try_break_stale_lock(lock_path: Path) -> bool:
    try:
        stat = lock_path.stat()
    except FileNotFoundError:
        return False
    except Exception:
        return False

    age_sec = max(0.0, time.time() - stat.st_mtime)
    if age_sec < LOCK_STALE_SEC:
        return False

    stale = True
    try:
        raw = lock_path.read_text(encoding="ascii", errors="ignore").strip()
        owner_pid = safe_int(raw, default=0)
        if owner_pid > 0 and is_pid_alive(owner_pid):
            stale = False
    except Exception:
        stale = True

    if not stale:
        return False

    try:
        lock_path.unlink()
        return True
    except Exception:
        return False


def acquire_lock(lock_path: Path, timeout_sec: float = LOCK_TIMEOUT_SEC) -> int:
    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        try:
            fd = os.open(str(lock_path), os.O_CREAT | os.O_EXCL | os.O_RDWR)
            os.write(fd, str(os.getpid()).encode("ascii", errors="ignore"))
            return fd
        except FileExistsError:
            try_break_stale_lock(lock_path)
            time.sleep(LOCK_POLL_SEC)
    raise TimeoutError(f"state lock timeout: {lock_path}")


def release_lock(fd: int, lock_path: Path) -> None:
    try:
        os.close(fd)
    finally:
        try:
            lock_path.unlink()
        except FileNotFoundError:
            pass


def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lock_path = Path(str(path) + ".lock")
    lock_fd: int | None = None
    tmp_path = Path(str(path) + f".tmp.{os.getpid()}")
    try:
        lock_fd = acquire_lock(lock_path)
        with tmp_path.open("w", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(str(tmp_path), str(path))
    finally:
        try:
            if tmp_path.exists():
                tmp_path.unlink()
        except Exception:
            pass
        if lock_fd is not None:
            release_lock(lock_fd, lock_path)


def run_powershell_json(script: str) -> list[dict[str, Any]]:
    cmd = ["powershell", "-NoProfile", "-Command", script]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
    except Exception:
        return []
    if result.returncode != 0:
        return []
    output = (result.stdout or "").strip()
    if not output:
        return []
    try:
        parsed = json.loads(output)
    except Exception:
        return []
    if isinstance(parsed, list):
        return [item for item in parsed if isinstance(item, dict)]
    if isinstance(parsed, dict):
        return [parsed]
    return []


def normalize_for_match(path_text: str) -> str:
    return path_text.replace("/", "\\").lower().rstrip("\\")


def path_is_under(path_text: str, candidate_root: Path) -> bool:
    text = normalize_for_match(path_text)
    root = normalize_for_match(str(candidate_root))
    return text.startswith(root + "\\") or text == root


def detect_scanner_pids(terminals: tuple[TerminalSpec, ...], disable_detection: bool) -> dict[str, list[int]]:
    out = {item.name: [] for item in terminals}
    if disable_detection:
        return out

    rows = run_powershell_json(
        "Get-CimInstance Win32_Process | "
        "Where-Object { $_.Name -match '^python' -and $_.CommandLine -match 'full_baseline_scan.py' } | "
        "Select-Object ProcessId,CommandLine,ExecutablePath | ConvertTo-Json -Compress"
    )

    for row in rows:
        pid = safe_int(row.get("ProcessId"), 0)
        if pid <= 0:
            continue
        cmd = str(row.get("CommandLine") or "")
        mapped_term: str | None = None
        for item in terminals:
            if f"--terminal {item.name}" in cmd:
                mapped_term = item.name
                break
        if mapped_term is None:
            for item in terminals:
                if str(item.root) in cmd:
                    mapped_term = item.name
                    break
        if mapped_term is None:
            mapped_term = terminals[0].name
        out[mapped_term].append(pid)
    return out


def detect_terminal_pids(
    terminals: tuple[TerminalSpec, ...],
    excluded_roots: tuple[Path, ...],
    disable_detection: bool,
) -> dict[str, list[int]]:
    out = {item.name: [] for item in terminals}
    if disable_detection:
        return out

    rows = run_powershell_json(
        "Get-CimInstance Win32_Process | "
        "Where-Object { $_.Name -eq 'terminal64.exe' } | "
        "Select-Object ProcessId,CommandLine,ExecutablePath | ConvertTo-Json -Compress"
    )

    for row in rows:
        pid = safe_int(row.get("ProcessId"), 0)
        if pid <= 0:
            continue

        executable = str(row.get("ExecutablePath") or "")
        command_line = str(row.get("CommandLine") or "")
        combined = f"{executable} {command_line}"

        if any(path_is_under(combined, root) for root in excluded_roots):
            continue

        matched = False
        for item in terminals:
            if path_is_under(executable, item.root) or path_is_under(command_line, item.root):
                out[item.name].append(pid)
                matched = True
                break
        if not matched:
            # Ignore unknown terminal64.exe instances instead of forcing classification.
            continue

    return out


def file_age_seconds(path: Path) -> float:
    return max(0.0, time.time() - path.stat().st_mtime)


def maybe_terminal_from_path(path: Path) -> str | None:
    lower = str(path).lower()
    for idx in range(1, 6):
        tag = f"t{idx}"
        if f"\\{tag}\\" in lower or f"_{tag}_" in lower or lower.endswith(f"_{tag}.htm"):
            return tag.upper()
    return None


def scan_report_directories(report_root: Path) -> list[dict[str, Any]]:
    if not report_root.exists():
        return []

    groups: dict[Path, list[Path]] = {}
    for htm in report_root.rglob("*.htm"):
        if not htm.is_file():
            continue
        parent = htm.parent
        groups.setdefault(parent, []).append(htm)

    records: list[dict[str, Any]] = []
    for directory, files in groups.items():
        latest = max(files, key=lambda item: item.stat().st_mtime)
        records.append(
            {
                "directory": str(directory),
                "terminal_hint": maybe_terminal_from_path(directory),
                "htm_count": len(files),
                "latest_report": latest.name,
                "latest_report_path": str(latest),
                "latest_report_mtime_utc": datetime.fromtimestamp(latest.stat().st_mtime, tz=timezone.utc).strftime(
                    "%Y-%m-%dT%H:%M:%SZ"
                ),
                "latest_report_age_sec": round(file_age_seconds(latest), 1),
            }
        )

    records.sort(key=lambda item: (item["directory"].lower()))
    return records


def summarize_terminal(
    name: str,
    prev_term: dict[str, Any],
    scanner_pids: list[int],
    terminal_pids: list[int],
    report_dirs: list[dict[str, Any]],
    active_age_sec: int,
) -> dict[str, Any]:
    tagged_dirs = [item for item in report_dirs if item.get("terminal_hint") == name]
    if not tagged_dirs and name == "T1":
        # Most current V5 runs report under generic smoke folders without terminal tag.
        tagged_dirs = [item for item in report_dirs if item.get("terminal_hint") is None]

    total_htm = sum(safe_int(item.get("htm_count"), 0) for item in tagged_dirs)
    latest = None
    if tagged_dirs:
        latest = min(tagged_dirs, key=lambda item: safe_int(item.get("latest_report_age_sec"), default=10**9))

    current = safe_int(prev_term.get("current"), 0)
    total = safe_int(prev_term.get("total"), 0)
    ea_label = str(prev_term.get("ea") or "unknown")
    scanner_pid = scanner_pids[0] if scanner_pids else None
    terminal_pid = terminal_pids[0] if terminal_pids else None

    report_age_sec = latest.get("latest_report_age_sec") if latest else None

    if scanner_pid and report_age_sec is not None and report_age_sec <= active_age_sec:
        status = "active"
    elif scanner_pid and report_age_sec is not None and report_age_sec > active_age_sec:
        status = "orphan_scanner_stale_reports"
    elif scanner_pid:
        status = "active_no_reports"
    elif (not scanner_pid) and report_age_sec is not None and report_age_sec <= active_age_sec:
        status = "scanner_missing_recent_reports"
    else:
        status = "idle_or_stalled"

    return {
        "pid": scanner_pid if scanner_pid is not None else "none",
        "terminal_pid": terminal_pid if terminal_pid is not None else "none",
        "current": current,
        "total": total,
        "ea": ea_label,
        "status": status,
        "latest_report": latest.get("latest_report") if latest else "none",
        "latest_report_mtime_utc": latest.get("latest_report_mtime_utc") if latest else "none",
        "report_age_sec": report_age_sec if report_age_sec is not None else "unknown",
        "tracked_report_dirs": len(tagged_dirs),
        "tracked_htm_count": total_htm,
    }


def build_state(
    previous: dict[str, Any],
    terminals: tuple[TerminalSpec, ...],
    excluded_roots: tuple[Path, ...],
    report_root: Path,
    active_age_sec: int,
    disable_process_detection: bool,
) -> dict[str, Any]:
    state = dict(previous) if isinstance(previous, dict) else {}
    prev_bl = state.get("bl_progress") if isinstance(state.get("bl_progress"), dict) else {}
    report_dirs = scan_report_directories(report_root)

    scanner_map = detect_scanner_pids(terminals, disable_process_detection)
    terminal_map = detect_terminal_pids(terminals, excluded_roots, disable_process_detection)

    bl: dict[str, Any] = {}
    for item in terminals:
        prev_term = prev_bl.get(item.name) if isinstance(prev_bl.get(item.name), dict) else {}
        bl[item.name] = summarize_terminal(
            name=item.name,
            prev_term=prev_term,
            scanner_pids=scanner_map.get(item.name, []),
            terminal_pids=terminal_map.get(item.name, []),
            report_dirs=report_dirs,
            active_age_sec=active_age_sec,
        )

    total_htm = sum(safe_int(item.get("htm_count"), 0) for item in report_dirs)
    newest_age = min((float(item.get("latest_report_age_sec")) for item in report_dirs), default=None)

    prev_iteration = safe_int(state.get("iteration"), 0)
    state = {
        "schema_version": STATE_SCHEMA_VERSION,
        "timestamp": datetime.now().strftime("%Y-%m-%dT%H:%M"),
        "timestamp_utc": utc_now_iso(),
        "iteration": prev_iteration + 1,
        "status": "standalone_aggregator_loop_v5",
        "writer_pid": os.getpid(),
        "reports_root": str(report_root),
        "excluded_terminal_roots": [str(item) for item in excluded_roots],
        "report_directory_count": len(report_dirs),
        "report_htm_total": total_htm,
        "latest_report_age_sec_global": round(newest_age, 1) if newest_age is not None else "unknown",
        "bl_progress": bl,
        "report_directories": report_dirs,
        "last_push": (
            f"[{datetime.now().strftime('%H:%M')}] standalone loop "
            + " ".join(f"{item.name}:{bl[item.name]['current']}/{bl[item.name]['total']}:{bl[item.name]['status']}" for item in terminals)
        ),
    }
    return state


def validate_state_for_consumers(state: dict[str, Any], terminal_names: list[str]) -> None:
    if not isinstance(state, dict):
        raise ValueError("state must be an object")
    if state.get("schema_version") != STATE_SCHEMA_VERSION:
        raise ValueError("state.schema_version invalid")
    if not isinstance(state.get("report_directories"), list):
        raise ValueError("state.report_directories must be a list")

    bl = state.get("bl_progress")
    if not isinstance(bl, dict):
        raise ValueError("state.bl_progress must be an object")

    for term in terminal_names:
        row = bl.get(term)
        if not isinstance(row, dict):
            raise ValueError(f"state.bl_progress.{term} must be an object")
        for required_key in ("current", "total", "ea", "status", "latest_report"):
            if required_key not in row:
                raise ValueError(f"state.bl_progress.{term}.{required_key} missing")
        status = row.get("status")
        if not isinstance(status, str) or status not in ALLOWED_TERMINAL_STATUS:
            raise ValueError(f"state.bl_progress.{term}.status invalid: {status!r}")


def write_heartbeat(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "wall_clock_utc": state.get("timestamp_utc"),
        "iteration": state.get("iteration"),
        "status": state.get("status"),
        "writer_pid": state.get("writer_pid"),
    }
    path.write_text(json.dumps(payload, ensure_ascii=True), encoding="ascii")


def parse_terminals(terminal_roots: list[str]) -> tuple[TerminalSpec, ...]:
    out: list[TerminalSpec] = []
    for item in terminal_roots:
        if "=" not in item:
            raise ValueError(f"invalid terminal root '{item}', expected NAME=PATH")
        name, raw_path = item.split("=", 1)
        key = name.strip().upper()
        if not key or not key.startswith("T"):
            raise ValueError(f"invalid terminal name '{name}'")
        out.append(TerminalSpec(name=key, root=Path(raw_path)))
    if not out:
        raise ValueError("at least one terminal root is required")
    return tuple(out)


def parse_path_list(values: list[str]) -> tuple[Path, ...]:
    return tuple(Path(item) for item in values)


def run_loop(
    *,
    interval_sec: int,
    active_age_sec: int,
    once: bool,
    state_path: Path,
    report_root: Path,
    heartbeat_path: Path,
    terminals: tuple[TerminalSpec, ...],
    excluded_roots: tuple[Path, ...],
    disable_process_detection: bool,
) -> None:
    while True:
        prev = parse_json_file(state_path)
        state = build_state(
            previous=prev,
            terminals=terminals,
            excluded_roots=excluded_roots,
            report_root=report_root,
            active_age_sec=active_age_sec,
            disable_process_detection=disable_process_detection,
        )
        validate_state_for_consumers(state, [item.name for item in terminals])
        atomic_write_json(state_path, state)
        write_heartbeat(heartbeat_path, state)

        print(
            f"{local_now_iso_second()} wrote {state_path} iteration={state.get('iteration')} "
            f"dirs={state.get('report_directory_count')} htm_total={state.get('report_htm_total')}",
            flush=True,
        )

        if once:
            return
        time.sleep(max(5, interval_sec))


def main() -> None:
    parser = argparse.ArgumentParser(description="V5 standalone state aggregator loop")
    parser.add_argument("--interval-sec", type=int, default=60, help="State write cadence")
    parser.add_argument("--active-age-sec", type=int, default=900, help="Report freshness threshold")
    parser.add_argument(
        "--state-path",
        default=r"D:\QM\reports\state\last_check_state.json",
        help="Target last_check_state.json path",
    )
    parser.add_argument("--report-root", default=r"D:\QM\reports", help="Root to scan for .htm reports")
    parser.add_argument(
        "--heartbeat-path",
        default=r"C:\QM\logs\aggregator\heartbeat.txt",
        help="Heartbeat file path for monitoring",
    )
    parser.add_argument(
        "--terminal-root",
        action="append",
        default=[],
        help="Override terminal root mapping with NAME=PATH (repeatable).",
    )
    parser.add_argument(
        "--exclude-root",
        action="append",
        default=[],
        help="Additional excluded terminal roots (repeatable).",
    )
    parser.add_argument("--disable-process-detection", action="store_true", help="Skip terminal/scanner PID detection.")
    parser.add_argument("--once", action="store_true", help="Run one iteration then exit")
    args = parser.parse_args()

    terminals = parse_terminals(args.terminal_root) if args.terminal_root else TERMINALS
    excluded = EXCLUDED_TERMINAL_ROOTS + parse_path_list(args.exclude_root)

    run_loop(
        interval_sec=args.interval_sec,
        active_age_sec=args.active_age_sec,
        once=args.once,
        state_path=Path(args.state_path),
        report_root=Path(args.report_root),
        heartbeat_path=Path(args.heartbeat_path),
        terminals=terminals,
        excluded_roots=excluded,
        disable_process_detection=bool(args.disable_process_detection),
    )


if __name__ == "__main__":
    main()
