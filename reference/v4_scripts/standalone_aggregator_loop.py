#!/usr/bin/env python3
"""Standalone aggregator loop for state/feed cadence.

Keeps last_check_state.json and TODO feed updates alive independently of scanner
code paths. This is designed as an incident-safe sidecar process.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

TERMINALS = {
    "T1": {
        "root": r"C:\Users\fabia\AppData\Roaming\MetaQuotes\Terminal\6C3C6A11D1C3791DD4DBF45421BF8028",
    },
    "T2": {
        "root": r"C:\Users\fabia\AppData\Roaming\MetaQuotes\Terminal\D0E73AF0F17162F32C13B3D22CCF0323",
    },
    "T3": {
        "root": r"C:\Users\fabia\AppData\Roaming\MetaQuotes\Terminal\35E1BC295E58086216981F2888C37961",
    },
}

STATE_PATH = Path(TERMINALS["T1"]["root"]) / "MQL5" / "Experts" / "EA_Testing" / "last_check_state.json"
PUSH_STATUS_PATH = Path(TERMINALS["T1"]["root"]) / "MQL5" / "Experts" / "EA_Testing" / "push_status.py"
PROGRESS_RE = re.compile(r"\[(\d+)/(\d+)\]\s+BL_([A-Z0-9_]+)")
LOCK_TIMEOUT_SEC = 2.0
LOCK_POLL_SEC = 0.05
T3_RECOVERY_DISK_GB = 80.0
T3_RECOVERY_SUSTAIN_SEC = 30 * 60
DEFAULT_T3_DISK_PAUSE_ACTIVE = True


def now_iso_minute() -> str:
    return datetime.now().strftime("%Y-%m-%dT%H:%M")


def now_iso_second() -> str:
    return datetime.now().strftime("%Y-%m-%dT%H:%M:%S")


def parse_iso_timestamp(value) -> float | None:
    if not isinstance(value, str) or not value:
        return None
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M"):
        try:
            return datetime.strptime(value, fmt).timestamp()
        except ValueError:
            continue
    return None


def safe_int(value, default=0):
    try:
        return int(value)
    except Exception:
        return default


def acquire_lock(lock_path: Path, timeout_sec: float = LOCK_TIMEOUT_SEC):
    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        try:
            fd = os.open(str(lock_path), os.O_CREAT | os.O_EXCL | os.O_RDWR)
            os.write(fd, str(os.getpid()).encode("ascii", errors="ignore"))
            return fd
        except FileExistsError:
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


def load_json(path: Path) -> dict:
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        if isinstance(data, dict):
            return data
    except FileNotFoundError:
        return {}
    except Exception:
        return {}
    return {}


def atomic_write_json(path: Path, payload: dict) -> None:
    lock_path = Path(str(path) + ".lock")
    lock_fd = None
    try:
        lock_fd = acquire_lock(lock_path)
        tmp_path = Path(str(path) + f".tmp.{os.getpid()}")
        with tmp_path.open("w", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(str(tmp_path), str(path))
    finally:
        if lock_fd is not None:
            release_lock(lock_fd, lock_path)


def run_powershell_json(script: str):
    cmd = [
        "powershell",
        "-NoProfile",
        "-Command",
        script,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
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
        return parsed
    if isinstance(parsed, dict):
        return [parsed]
    return []


def detect_scanner_pids() -> dict[str, list[int]]:
    out = {"T1": [], "T2": [], "T3": []}
    rows = run_powershell_json(
        "Get-CimInstance Win32_Process | "
        "Where-Object { $_.Name -match '^python' -and $_.CommandLine -match 'full_baseline_scan.py' } | "
        "Select-Object ProcessId,CommandLine,ExecutablePath | ConvertTo-Json -Compress"
    )
    for row in rows:
        cmd = str(row.get("CommandLine") or "")
        pid = safe_int(row.get("ProcessId"), 0)
        if pid <= 0:
            continue

        term = None
        for key in ("T1", "T2", "T3"):
            if f"--terminal {key}" in cmd:
                term = key
                break
        if term is None:
            if TERMINALS["T2"]["root"] in cmd:
                term = "T2"
            elif TERMINALS["T3"]["root"] in cmd:
                term = "T3"
            else:
                term = "T1"

        out[term].append(pid)

    return out


def detect_terminal_pids() -> dict[str, list[int]]:
    out = {"T1": [], "T2": [], "T3": []}
    rows = run_powershell_json(
        "Get-CimInstance Win32_Process | "
        "Where-Object { $_.Name -eq 'terminal64.exe' } | "
        "Select-Object ProcessId,CommandLine,ExecutablePath | ConvertTo-Json -Compress"
    )
    for row in rows:
        pid = safe_int(row.get("ProcessId"), 0)
        if pid <= 0:
            continue

        where = f"{row.get('ExecutablePath') or ''} {row.get('CommandLine') or ''}"
        if "Forward" in where:
            out["T2"].append(pid)
        elif "Next" in where:
            out["T3"].append(pid)
        else:
            out["T1"].append(pid)

    return out


def latest_report_info(root: str):
    files = glob.glob(os.path.join(root, "*.htm"))
    if not files:
        return None, None, None
    latest = max(files, key=os.path.getmtime)
    mtime = os.path.getmtime(latest)
    age_sec = max(0.0, time.time() - mtime)
    return os.path.basename(latest), datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M:%S"), round(age_sec, 1)


def latest_progress_info(root: str, term: str):
    ea_dir = os.path.join(root, "MQL5", "Experts", "EA_Testing")
    logs = glob.glob(os.path.join(ea_dir, f"bl_scan_{term}_*.log"))
    if not logs:
        return None, None, None, None
    latest = max(logs, key=os.path.getmtime)
    try:
        with open(latest, "r", encoding="utf-8", errors="replace") as handle:
            tail = handle.readlines()[-300:]
    except Exception:
        return None, None, None, os.path.basename(latest)

    for line in reversed(tail):
        match = PROGRESS_RE.search(line)
        if match:
            current = safe_int(match.group(1), 0)
            total = safe_int(match.group(2), 0)
            ea_label = match.group(3)
            return current, total, ea_label, os.path.basename(latest)
    return None, None, None, os.path.basename(latest)


def evaluate_t3_disk_pause_policy(previous_state: dict, disk_free_gb: float, now_ts: float) -> dict:
    prev_policy = previous_state.get("t3_disk_pause_policy")
    policy = dict(prev_policy) if isinstance(prev_policy, dict) else {}

    active_raw = policy.get("active")
    if isinstance(active_raw, bool):
        active = active_raw
    else:
        prev_bl = previous_state.get("bl_progress")
        prev_t3 = prev_bl.get("T3") if isinstance(prev_bl, dict) else {}
        prev_status = prev_t3.get("status") if isinstance(prev_t3, dict) else None
        active = (prev_status == "paused_disk_constraint") or DEFAULT_T3_DISK_PAUSE_ACTIVE
        policy.setdefault("activated_at", now_iso_second())
        policy.setdefault("activation_reason", "bootstrap_default_active")

    was_active = active

    if active:
        if disk_free_gb >= T3_RECOVERY_DISK_GB:
            since_ts = parse_iso_timestamp(policy.get("recovery_sustained_since"))
            if since_ts is None:
                policy["recovery_sustained_since"] = now_iso_second()
            elif (now_ts - since_ts) >= T3_RECOVERY_SUSTAIN_SEC:
                active = False
                policy["active"] = False
                policy["deactivated_at"] = now_iso_second()
                policy["deactivation_reason"] = (
                    f"disk_free_gb>={T3_RECOVERY_DISK_GB:g} sustained {int(T3_RECOVERY_SUSTAIN_SEC / 60)}m"
                )
                policy["recovery_sustained_since"] = None
        else:
            policy["recovery_sustained_since"] = None
    else:
        policy["recovery_sustained_since"] = None

    policy["active"] = active
    policy["just_deactivated"] = bool(was_active and not active)
    policy["recovery_condition_met"] = bool((not active) and (disk_free_gb >= T3_RECOVERY_DISK_GB))
    policy["recover_when_disk_free_gb_ge"] = T3_RECOVERY_DISK_GB
    policy["recover_sustain_seconds"] = T3_RECOVERY_SUSTAIN_SEC
    policy["last_eval_utc"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    policy["last_eval_disk_free_gb"] = disk_free_gb
    return policy


def summarize_terminal(
    term: str,
    prev_term: dict,
    scanner_pids: list[int],
    terminal_pids: list[int],
    active_age_sec: int,
    force_paused_disk_constraint: bool = False,
    force_active_status: bool = False,
) -> dict:
    root = TERMINALS[term]["root"]
    latest_report, latest_report_mtime, report_age_sec = latest_report_info(root)
    current, total, ea_label, latest_log = latest_progress_info(root, term)

    if current is None:
        current = safe_int(prev_term.get("current"), 0)
    if total is None:
        total = safe_int(prev_term.get("total"), 0)
    if not ea_label:
        ea_label = prev_term.get("ea") or "unknown"

    scanner_pid = scanner_pids[0] if scanner_pids else None
    terminal_pid = terminal_pids[0] if terminal_pids else None

    if scanner_pid and report_age_sec is not None and report_age_sec <= active_age_sec:
        computed_status = "active"
    elif scanner_pid and report_age_sec is not None and report_age_sec > active_age_sec:
        computed_status = "orphan_scanner_stale_reports"
    elif scanner_pid:
        computed_status = "active_no_reports"
    elif (not scanner_pid) and report_age_sec is not None and report_age_sec <= active_age_sec:
        computed_status = "scanner_missing_recent_reports"
    else:
        computed_status = "idle_or_stalled"

    status = computed_status
    if term == "T3" and force_paused_disk_constraint:
        status = "paused_disk_constraint"
    elif term == "T3" and force_active_status:
        status = "active"

    summary = {
        "pid": scanner_pid if scanner_pid is not None else "none",
        "terminal_pid": terminal_pid if terminal_pid is not None else "none",
        "current": current,
        "total": total,
        "ea": ea_label,
        "status": status,
        "latest_report": latest_report or "none",
        "latest_report_mtime": latest_report_mtime or "none",
        "report_age_sec": report_age_sec if report_age_sec is not None else "unknown",
        "latest_log": latest_log or "none",
    }
    if term == "T3" and status != computed_status:
        summary["status_unpaused"] = computed_status
    return summary


def build_state(previous: dict, active_age_sec: int) -> dict:
    state = dict(previous) if isinstance(previous, dict) else {}
    prev_bl = state.get("bl_progress") if isinstance(state.get("bl_progress"), dict) else {}

    disk_free_gb = round(shutil.disk_usage("C:/").free / 1e9, 1)
    policy = evaluate_t3_disk_pause_policy(state, disk_free_gb, time.time())
    t3_paused = bool(policy.get("active"))
    t3_force_active = bool(policy.get("recovery_condition_met"))

    scanner_map = detect_scanner_pids()
    terminal_map = detect_terminal_pids()

    bl = {}
    for term in ("T1", "T2", "T3"):
        prev_term = prev_bl.get(term) if isinstance(prev_bl.get(term), dict) else {}
        bl[term] = summarize_terminal(
            term,
            prev_term,
            scanner_map.get(term, []),
            terminal_map.get(term, []),
            active_age_sec,
            force_paused_disk_constraint=(term == "T3" and t3_paused),
            force_active_status=(term == "T3" and (not t3_paused) and t3_force_active),
        )

    prev_iteration = safe_int(state.get("iteration"), 0)

    state["timestamp"] = now_iso_minute()
    state["iteration"] = prev_iteration + 1
    state["disk_free_gb"] = disk_free_gb
    state["status"] = "standalone_aggregator_loop"
    state["writer_pid"] = os.getpid()
    state["bl_progress"] = bl
    state["t3_disk_pause_policy"] = policy

    state["last_push"] = (
        f"[{datetime.now().strftime('%H:%M')}] standalone loop "
        f"T1:{bl['T1']['current']}/{bl['T1']['total']}:{bl['T1']['status']} "
        f"T2:{bl['T2']['current']}/{bl['T2']['total']}:{bl['T2']['status']} "
        f"T3:{bl['T3']['current']}/{bl['T3']['total']}:{bl['T3']['status']}"
    )

    return state


def validate_state_for_consumers(state: dict) -> None:
    if not isinstance(state, dict):
        raise ValueError("state must be an object")

    bl = state.get("bl_progress")
    if not isinstance(bl, dict):
        raise ValueError("state.bl_progress must be an object")

    allowed_status = {
        "active",
        "active_no_reports",
        "orphan_scanner_stale_reports",
        "scanner_missing_recent_reports",
        "idle_or_stalled",
        "paused_disk_constraint",
    }

    for term in ("T1", "T2", "T3"):
        row = bl.get(term)
        if not isinstance(row, dict):
            raise ValueError(f"state.bl_progress.{term} must be an object")
        for required_key in ("current", "total", "ea", "status", "latest_report"):
            if required_key not in row:
                raise ValueError(f"state.bl_progress.{term}.{required_key} missing")
        status = row.get("status")
        if not isinstance(status, str) or status not in allowed_status:
            raise ValueError(f"state.bl_progress.{term}.status invalid: {status!r}")

    policy = state.get("t3_disk_pause_policy")
    if not isinstance(policy, dict):
        raise ValueError("state.t3_disk_pause_policy must be an object")
    if not isinstance(policy.get("active"), bool):
        raise ValueError("state.t3_disk_pause_policy.active must be bool")


def push_once() -> None:
    if not PUSH_STATUS_PATH.exists():
        print("WARN push_status.py missing; skip push", flush=True)
        return

    try:
        result = subprocess.run(
            [sys.executable, str(PUSH_STATUS_PATH)],
            capture_output=True,
            text=True,
            timeout=40,
        )
    except Exception as exc:
        print(f"WARN push_status invoke failed: {exc}", flush=True)
        return

    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "").strip()
        print(f"WARN push_status failed: {detail}", flush=True)
        return

    lines = (result.stdout or "").strip().splitlines()
    detail = lines[-1] if lines else "ok"
    print(f"push_status: {detail}", flush=True)


def run_loop(interval_sec: int, push_interval_sec: int, active_age_sec: int, once: bool) -> None:
    next_push_at = 0.0
    while True:
        prev = load_json(STATE_PATH)
        state = build_state(prev, active_age_sec)
        validate_state_for_consumers(state)
        atomic_write_json(STATE_PATH, state)

        now_epoch = time.time()
        if now_epoch >= next_push_at:
            push_once()
            next_push_at = now_epoch + max(30, push_interval_sec)

        print(
            f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} wrote state iteration={state.get('iteration')} "
            f"status={state.get('status')}",
            flush=True,
        )

        if once:
            return
        time.sleep(max(5, interval_sec))


def main() -> None:
    parser = argparse.ArgumentParser(description="Standalone state/feed aggregator loop")
    parser.add_argument("--interval-sec", type=int, default=60, help="State write cadence")
    parser.add_argument("--push-interval-sec", type=int, default=300, help="Feed push cadence")
    parser.add_argument("--active-age-sec", type=int, default=900, help="Report freshness threshold")
    parser.add_argument("--once", action="store_true", help="Run one iteration then exit")
    args = parser.parse_args()

    run_loop(args.interval_sec, args.push_interval_sec, args.active_age_sec, args.once)


if __name__ == "__main__":
    main()
