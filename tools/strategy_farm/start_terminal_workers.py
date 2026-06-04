#!/usr/bin/env python3
"""Start or refresh the long-running per-terminal strategy-farm workers."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


TERMINALS = tuple(f"T{i}" for i in range(1, 15))  # T1-T14 (OWNER 2026-06-04: +T11-T14)
FACTORY_TERMINAL_RE = re.compile(r"^T(?:[1-9]|1[0-4])$", re.IGNORECASE)


def _pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0
        result = subprocess.run(
            ["tasklist", "/FI", f"PID eq {pid}", "/FO", "CSV", "/NH"],
            capture_output=True,
            text=True,
            errors="replace",
            creationflags=creationflags,
        )
        return str(pid) in (result.stdout or "")
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def _scan_running_workers() -> dict[str, list[int]]:
    if sys.platform != "win32":
        return {}
    command = (
        "Get-CimInstance Win32_Process "
        "| Where-Object { $_.CommandLine -match 'terminal_worker.py' } "
        "| Select-Object ProcessId,CommandLine | ConvertTo-Json -Depth 3"
    )
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command", command],
            capture_output=True,
            text=True,
            errors="replace",
            timeout=15,
            creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0,
        )
    except Exception:
        return {}
    if result.returncode != 0 or not (result.stdout or "").strip():
        return {}
    try:
        rows = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {}
    if isinstance(rows, dict):
        rows = [rows]
    found: dict[str, list[int]] = {t: [] for t in TERMINALS}
    pattern = re.compile(r"--terminal\s+(T(?:[1-9]|10))\b", re.IGNORECASE)
    for row in rows if isinstance(rows, list) else []:
        cmd = str(row.get("CommandLine") or "")
        match = pattern.search(cmd)
        if not match:
            continue
        try:
            pid = int(row.get("ProcessId"))
        except (TypeError, ValueError):
            continue
        found.setdefault(match.group(1).upper(), []).append(pid)
    return {terminal: pids for terminal, pids in found.items() if pids}


def _installed_terminals(mt5_root: Path) -> tuple[str, ...]:
    return tuple(
        terminal
        for terminal in TERMINALS
        if FACTORY_TERMINAL_RE.fullmatch(terminal) and (mt5_root / terminal / "terminal64.exe").exists()
    )


def _stop_pid(pid: int) -> bool:
    if pid <= 0 or sys.platform != "win32":
        return False
    try:
        result = subprocess.run(
            ["taskkill", "/PID", str(pid), "/T", "/F"],
            capture_output=True,
            text=True,
            timeout=15,
            creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0,
        )
        return result.returncode == 0
    except Exception:
        return False


def _load_existing(pid_file: Path) -> dict[str, int]:
    if not pid_file.exists():
        return {}
    try:
        raw = json.loads(pid_file.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError, TypeError):
        return {}
    if not isinstance(raw, dict):
        return {}
    out: dict[str, int] = {}
    for key, value in raw.items():
        try:
            out[str(key).upper()] = int(value)
        except (TypeError, ValueError):
            continue
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Start strategy-farm terminal workers.")
    parser.add_argument("--repo-root", default=r"C:\QM\repo")
    parser.add_argument("--farm-root", default=r"D:\QM\strategy_farm")
    parser.add_argument("--mt5-root", default=r"D:\QM\mt5")
    parser.add_argument("--dedupe", action="store_true", help="Stop duplicate terminal_worker.py processes per terminal.")
    args = parser.parse_args()

    repo_root = Path(args.repo_root)
    farm_root = Path(args.farm_root)
    mt5_root = Path(args.mt5_root)
    state_dir = farm_root / "state"
    log_dir = farm_root / "logs"
    pid_file = state_dir / "worker_pids.json"
    worker = repo_root / "tools" / "strategy_farm" / "terminal_worker.py"

    state_dir.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)

    existing = _load_existing(pid_file)
    discovered = _scan_running_workers()
    updated: dict[str, int] = {}
    stopped_duplicates: dict[str, list[int]] = {}
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0

    python_exe = Path(sys.executable)
    if python_exe.name.lower() == "python.exe":
        pythonw = python_exe.with_name("pythonw.exe")
        if pythonw.exists():
            python_exe = pythonw

    terminals = _installed_terminals(mt5_root)
    for terminal in terminals:
        candidates = [pid for pid in discovered.get(terminal, []) if _pid_alive(pid)]
        existing_pid = existing.get(terminal, 0)
        if existing_pid and _pid_alive(existing_pid) and existing_pid not in candidates:
            candidates.insert(0, existing_pid)

        if candidates:
            keep = existing_pid if existing_pid in candidates else candidates[0]
            updated[terminal] = keep
            duplicates = [pid for pid in candidates if pid != keep]
            if args.dedupe and duplicates:
                stopped_duplicates[terminal] = [pid for pid in duplicates if _stop_pid(pid)]
            continue

        log_path = log_dir / f"terminal_worker_{terminal}.log"
        err_path = log_dir / f"terminal_worker_{terminal}.log.err"
        out = log_path.open("ab")
        err = err_path.open("ab")
        proc = subprocess.Popen(
            [
                str(python_exe),
                "-u",
                str(worker),
                "--terminal",
                terminal,
                "--root",
                str(farm_root),
            ],
            cwd=str(repo_root),
            stdout=out,
            stderr=err,
            stdin=subprocess.DEVNULL,
            close_fds=True,
            creationflags=creationflags,
        )
        out.close()
        err.close()
        updated[terminal] = int(proc.pid)

    pid_file.write_text(json.dumps(updated, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps({"workers": updated, "stopped_duplicates": stopped_duplicates, "installed_terminals": list(terminals)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
