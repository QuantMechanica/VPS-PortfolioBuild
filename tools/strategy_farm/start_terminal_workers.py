#!/usr/bin/env python3
"""Start or refresh the long-running per-terminal strategy-farm workers."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


TERMINALS = ("T1", "T2", "T3", "T4", "T5")


def _pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    if sys.platform == "win32":
        creationflags = subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0
        result = subprocess.run(
            ["tasklist", "/FI", f"PID eq {pid}", "/FO", "CSV", "/NH"],
            capture_output=True,
            text=True,
            creationflags=creationflags,
        )
        return str(pid) in (result.stdout or "")
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


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
    args = parser.parse_args()

    repo_root = Path(args.repo_root)
    farm_root = Path(args.farm_root)
    state_dir = farm_root / "state"
    log_dir = farm_root / "logs"
    pid_file = state_dir / "worker_pids.json"
    worker = repo_root / "tools" / "strategy_farm" / "terminal_worker.py"

    state_dir.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)

    existing = _load_existing(pid_file)
    updated: dict[str, int] = {}
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0

    python_exe = Path(sys.executable)
    if python_exe.name.lower() == "python.exe":
        pythonw = python_exe.with_name("pythonw.exe")
        if pythonw.exists():
            python_exe = pythonw

    for terminal in TERMINALS:
        pid = existing.get(terminal, 0)
        if _pid_alive(pid):
            updated[terminal] = pid
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
    print(json.dumps(updated, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
