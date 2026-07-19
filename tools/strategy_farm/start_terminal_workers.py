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


TERMINALS = tuple(f"T{i}" for i in range(1, 11))
FACTORY_TERMINAL_RE = re.compile(r"^T(?:[1-9]|10)$", re.IGNORECASE)


def _pid_alive(pid: int) -> bool:
    # 2026-07-06: in-process ctypes check instead of a tasklist subprocess.
    # Console children (tasklist/powershell) can die under 0xC0000142-class
    # console-init failures, which made BOTH duplicate protections (CIM scan +
    # pid-file) report "nothing alive" at once and triggered a full re-spawn of
    # already-running workers (midnight 07-06 incident). OpenProcess cannot fail
    # that way.
    if pid <= 0:
        return False
    if sys.platform == "win32":
        import ctypes
        kernel32 = ctypes.windll.kernel32
        PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        STILL_ACTIVE = 259
        handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, int(pid))
        if not handle:
            return False
        try:
            code = ctypes.c_ulong(0)
            if not kernel32.GetExitCodeProcess(handle, ctypes.byref(code)):
                return False
            return code.value == STILL_ACTIVE
        finally:
            kernel32.CloseHandle(handle)
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def _scan_running_workers() -> dict[str, list[int]]:
    if sys.platform != "win32":
        return {}
    command = (
        "Get-CimInstance Win32_Process -Filter \"Name='python.exe' OR Name='pythonw.exe'\" "
        "| Where-Object { $_.CommandLine -match 'terminal_worker.py' } "
        "| Select-Object ProcessId,CommandLine | ConvertTo-Json -Depth 3"
    )
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command", command],
            capture_output=True,
            text=True,
            errors="replace",
            timeout=45,  # 15s starved out under the :00 scheduled-task burst (07-06)
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


# Operator-controlled concurrency cap. One terminal name per line (e.g. "T9").
# Lets the factory run fewer than the 10 installed terminals when RAM/disk headroom
# is the binding constraint (heavy tick backtests use ~6-7GB RAM each; 10 concurrent
# exhaust the 63GB box and wedge terminal64 launches). Reversible: empty/delete the
# file -> back to all installed terminals. Honored by Factory_ON + watchdog respawns
# because they all route through _installed_terminals.
_DISABLED_TERMINALS_FILE = Path(r"D:\QM\strategy_farm\state\disabled_terminals.txt")


def _disabled_terminals() -> set[str]:
    try:
        text = _DISABLED_TERMINALS_FILE.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeDecodeError):
        return set()
    out: set[str] = set()
    for line in text.splitlines():
        name = line.strip().upper()
        if name and FACTORY_TERMINAL_RE.fullmatch(name):
            out.add(name)
    return out


def _installed_terminals(mt5_root: Path) -> tuple[str, ...]:
    disabled = _disabled_terminals()
    return tuple(
        terminal
        for terminal in TERMINALS
        if FACTORY_TERMINAL_RE.fullmatch(terminal)
        and terminal.upper() not in disabled
        and (mt5_root / terminal / "terminal64.exe").exists()
    )


def _stop_pid(pid: int) -> bool:
    # A bare PID is not a safe termination authority because it may be reused
    # between discovery and this call. Fail closed until an identity-bound stop exists.
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
        # PID-reuse guard (incident class 2026-07-08): a PID from worker_pids.json
        # counts only if the live commandline scan also returned it for THIS
        # terminal. purge/watchdog kill workers without updating the JSON, so a
        # bare-alive stale PID may be a reused, unrelated process — keeping it
        # silently starves the slot; deduping it kills an innocent process.
        if existing_pid and existing_pid in discovered.get(terminal, []) and _pid_alive(existing_pid) and existing_pid not in candidates:
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
