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

try:
    import resource_headroom
except ModuleNotFoundError:
    from tools.strategy_farm import resource_headroom

try:
    import farmctl
except ModuleNotFoundError:
    from tools.strategy_farm import farmctl


TERMINALS = tuple(f"T{i}" for i in range(1, 13))
FACTORY_TERMINAL_RE = re.compile(r"^T(?:[1-9]|1[0-2])$", re.IGNORECASE)


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
    pattern = re.compile(r"--terminal\s+(T(?:[1-9]|1[0-2]))\b", re.IGNORECASE)
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


def _governed_terminals(
    installed: tuple[str, ...],
    discovered: dict[str, list[int]],
    decision: dict[str, object],
    reserved: set[str] | frozenset[str] = frozenset(),
) -> tuple[str, ...]:
    """Keep every live worker, then admit unreserved missing workers up to the cap.

    A reservation protects the whole terminal lifecycle, not only work-item
    claims.  In particular, a watchdog must not recreate a deliberately
    quiesced worker during a long terminal-exclusive maintenance session.
    Already-live workers remain visible so this selector never removes or
    rewrites an existing process.
    """
    running = [terminal for terminal in installed if discovered.get(terminal)]
    target = max(len(running), int(decision.get("max_workers") or 0))
    reserved_upper = {str(terminal).upper() for terminal in reserved}
    missing = [
        terminal
        for terminal in installed
        if terminal not in running and terminal.upper() not in reserved_upper
    ]
    return tuple(running + missing[: max(0, target - len(running))])


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



# 2026-09-05 (CEO): the DL-089 scheduling caps live in machine-scope DL089_* vars
# (DL089_PROGRAM_SLOTS=8 since 2026-09-02). The merge only carried QM_* keys, so every
# worker restarted from an interactive session (reload chunks 33-41) silently fell back
# to the code default of 4 program slots and starved the fifth admitted census program.
# Only the program cap is carried. The machine scope also still holds the T11/T12
# canary values (DL089_LANES_PER_PROGRAM=2, DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST) whose
# activation reproduced the lane-preflight decline loop (~88->21 cells/h) and was rolled
# back on 2026-09-02; those stay machine-only until an OWNER decision re-activates them.
MACHINE_FACTORY_ENV_PREFIXES = ("QM_",)
# 2026-09-11 (Orchestrator, OWNER window): OWNER 2026-09-10 "Winsweep ja" re-activated
# L=2 for the allow-listed programs (OWNER-DEC-SAMEPROG-FLEET-20260831 + 2026-09-10),
# so the lane cap and allow-list are carried from machine scope as well; a reboot no
# longer silently drops them to L=1.  DL089_CELL_SLOTS is deliberately NOT carried
# (temporary 48 h cap of 2026-09-10, rollback due 2026-09-12T19:05Z = the reboot).
MACHINE_FACTORY_ENV_EXACT = frozenset({
    "DL089_PROGRAM_SLOTS",
    "DL089_LANES_PER_PROGRAM",
    "DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST",
})


def _is_machine_factory_var(name: object) -> bool:
    upper = str(name).upper()
    if upper in MACHINE_FACTORY_ENV_EXACT:
        return True
    return any(upper.startswith(prefix) for prefix in MACHINE_FACTORY_ENV_PREFIXES)


def machine_qm_environment() -> dict[str, str]:
    """Return the machine-level QM_* and DL089_* environment variables (Windows HKLM), else {}."""
    if sys.platform != "win32":
        return {}
    try:
        import winreg
    except ImportError:  # pragma: no cover - non-Windows
        return {}
    values: dict[str, str] = {}
    try:
        key = winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment",
        )
    except OSError:
        return {}
    try:
        index = 0
        while True:
            try:
                name, value, _kind = winreg.EnumValue(key, index)
            except OSError:
                break
            index += 1
            if _is_machine_factory_var(name) and value is not None:
                values[str(name)] = str(value)
    finally:
        winreg.CloseKey(key)
    return values


def merge_machine_qm_env(environ: dict[str, str], machine: dict[str, str]) -> dict[str, str]:
    """Return a spawn env carrying the machine-scoped factory values.

    Incident 2026-09-02: workers restarted from an interactive session inherited
    that session's environment, which lacked QM_TOPDOWN_GATE_PRIORITY_ENABLED,
    QM_ENABLE_DL089_PRUNING and QM_SQLITE_BUSY_TIMEOUT_MS, so the fleet ran the
    cold claim order and without worker-side pruning for most of the day.

    Incident 2026-10-15: the watchdog inherited a stale
    DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST and recreated T1 with governance bytes
    different from the pre-quiesce worker.  Machine scope is therefore the only
    source for the exact DL089 scheduling keys: caller values are dropped and
    replaced, and a key absent from machine scope is absent from the worker.

    QM_* keys keep setdefault semantics (an explicit process value wins): the
    tester memory-limit rollout uses a per-process ``QM_TESTER_MEMORY_LIMIT_V1=0``
    as its rollback authority, which a machine-scope ``=1`` must not override.
    """
    merged = dict(environ)
    for name in MACHINE_FACTORY_ENV_EXACT:
        merged.pop(name, None)
    for name, value in machine.items():
        if str(name).upper() in MACHINE_FACTORY_ENV_EXACT:
            merged[name] = value
        elif _is_machine_factory_var(name):
            merged.setdefault(name, value)
    return merged


def canonical_worker_environment(environ: dict[str, str] | None = None) -> dict[str, str]:
    """Build the one governed environment used by every worker restarter."""
    return merge_machine_qm_env(
        dict(os.environ if environ is None else environ),
        machine_qm_environment(),
    )


def main() -> int:
    # DL-065: spawned terminal workers inherit this env. The spawner and the
    # workers are deterministic factory machinery (trusted base 'controller');
    # a spawn context without QM_AGENT_ID must not produce 'unknown' workers
    # whose cascade enqueues die fail-closed (fleet churn 2026-08-01).
    os.environ.setdefault("QM_AGENT_ID", "controller")
    parser = argparse.ArgumentParser(description="Start strategy-farm terminal workers.")
    parser.add_argument("--repo-root", default=r"C:\QM\repo")
    parser.add_argument("--farm-root", default=r"D:\QM\strategy_farm")
    parser.add_argument("--mt5-root", default=r"D:\QM\mt5")
    parser.add_argument("--dedupe", action="store_true", help="Stop duplicate terminal_worker.py processes per terminal.")
    parser.add_argument(
        "--only-terminal",
        help=(
            "start/dedupe only one exact T1-T10 worker while preserving every "
            "other discovered worker in worker_pids.json"
        ),
    )
    parser.add_argument(
        "--expected-count",
        type=int,
        default=0,
        help="Workers the caller needs running afterwards (0 = no expectation). A shortfall exits 5 with "
        "launch_status=SHORTFALL instead of reporting success with fewer workers than expected.",
    )
    args = parser.parse_args()

    only_terminal = str(args.only_terminal or "").strip().upper() or None
    if only_terminal and not re.fullmatch(r"T(?:[1-9]|10)", only_terminal):
        parser.error("--only-terminal accepts exactly T1 through T10")

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
    if only_terminal:
        # A targeted canary/rollback restart must not erase the PID identities
        # for untouched workers from the shared receipt file.
        for name, pids in discovered.items():
            live = [pid for pid in pids if _pid_alive(pid)]
            if not live:
                continue
            recorded = existing.get(name, 0)
            updated[name] = recorded if recorded in live else live[0]
    stopped_duplicates: dict[str, list[int]] = {}
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    spawn_env = canonical_worker_environment()
    memory_limit_enabled = (
        str(spawn_env.get("QM_TESTER_MEMORY_LIMIT_V1", "")).strip() == "1"
    )
    canary_id = str(
        spawn_env.get("QM_TESTER_MEMORY_LIMIT_CANARY_WORK_ITEM_ID", "")
    ).strip()
    canary_bytes = str(
        spawn_env.get("QM_TESTER_MEMORY_LIMIT_CANARY_BYTES", "")
    ).strip()
    production_a2 = str(
        spawn_env.get("QM_TESTER_MEMORY_LIMIT_A2_PRODUCTION_V1", "")
    ).strip() == "1"
    if not memory_limit_enabled:
        # An explicit per-process ``=0`` is the rollback authority.  Do not
        # allow stale machine-scope canary bindings to be filled back into the
        # replacement worker by setdefault inheritance.
        spawn_env.pop("QM_TESTER_MEMORY_LIMIT_CANARY_WORK_ITEM_ID", None)
        spawn_env.pop("QM_TESTER_MEMORY_LIMIT_CANARY_BYTES", None)
        spawn_env.pop("QM_TESTER_MEMORY_LIMIT_A2_PRODUCTION_V1", None)
        canary_id = ""
        canary_bytes = ""
        production_a2 = False
    if memory_limit_enabled and only_terminal is None:
        print(json.dumps({
            "launch_status": "REFUSED",
            "reason": "memory_limit_activation_requires_only_terminal",
        }, sort_keys=True))
        return 6
    if memory_limit_enabled and production_a2 and (canary_id or canary_bytes):
        print(json.dumps({
            "launch_status": "REFUSED",
            "reason": "memory_limit_production_and_canary_mutually_exclusive",
            "only_terminal": only_terminal,
        }, sort_keys=True))
        return 6
    if memory_limit_enabled and not production_a2 and (not canary_id or not canary_bytes):
        print(json.dumps({
            "launch_status": "REFUSED",
            "reason": "memory_limit_exact_canary_binding_required",
            "only_terminal": only_terminal,
        }, sort_keys=True))
        return 6
    if memory_limit_enabled and production_a2:
        try:
            configured_cap = int(
                str(spawn_env.get("QM_RESEARCH_BACKTEST_MAX_ACTIVE", "1"))
            )
        except ValueError:
            configured_cap = 0
        if configured_cap != 1:
            print(json.dumps({
                "launch_status": "REFUSED",
                "reason": "memory_limit_a2_production_requires_cap_1",
                "only_terminal": only_terminal,
                "configured_research_cap": configured_cap,
            }, sort_keys=True))
            return 6

    python_exe = Path(sys.executable)
    if python_exe.name.lower() == "python.exe":
        pythonw = python_exe.with_name("pythonw.exe")
        if pythonw.exists():
            python_exe = pythonw

    installed_terminals = _installed_terminals(mt5_root)
    snapshot = resource_headroom.probe(farm_root)
    running_installed = sum(bool(discovered.get(terminal)) for terminal in installed_terminals)
    headroom_decision = resource_headroom.concurrency_decision(
        snapshot,
        installed_workers=len(installed_terminals),
        running_workers=running_installed,
    )
    reservations = farmctl.terminal_reservations(farm_root)
    reserved_terminals = frozenset(reservations)
    skipped_reserved = {
        terminal
        for terminal in reserved_terminals
        if terminal in installed_terminals and not discovered.get(terminal)
    }
    governed_terminals = _governed_terminals(
        installed_terminals, discovered, headroom_decision, reserved_terminals
    )
    if only_terminal:
        if only_terminal not in installed_terminals:
            print(json.dumps({
                "launch_status": "REFUSED",
                "reason": "target_terminal_not_installed_or_enabled",
                "only_terminal": only_terminal,
                "installed_terminals": list(installed_terminals),
            }, sort_keys=True))
            return 6
        if only_terminal in reserved_terminals and not discovered.get(only_terminal):
            print(json.dumps({
                "launch_status": "REFUSED",
                "reason": "target_terminal_reserved",
                "only_terminal": only_terminal,
                "reservation": reservations.get(only_terminal),
            }, sort_keys=True, default=str))
            return 6
        if (
            only_terminal not in governed_terminals
            and not discovered.get(only_terminal)
        ):
            print(json.dumps({
                "launch_status": "REFUSED",
                "reason": "resource_headroom_did_not_admit_target",
                "only_terminal": only_terminal,
                "resource_headroom": headroom_decision,
            }, sort_keys=True))
            return 6
        terminals = (only_terminal,)
    else:
        terminals = governed_terminals
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

        # Close the selection-to-spawn race: an exclusive session may acquire
        # its reservation after the fleet snapshot above.  Its own stable-worker
        # check will abort if a launch wins the remaining sub-millisecond race.
        if farmctl.terminal_reservation(farm_root, terminal) is not None:
            skipped_reserved.add(terminal)
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
            env=spawn_env,
        )
        out.close()
        err.close()
        updated[terminal] = int(proc.pid)

    pid_file.write_text(json.dumps(updated, indent=2, sort_keys=True), encoding="utf-8")
    expected_count = max(0, int(args.expected_count))
    observed_count = (
        int(only_terminal in updated) if only_terminal else len(updated)
    )
    shortfall = observed_count < expected_count
    print(json.dumps({
        "launch_status": "SHORTFALL" if shortfall else "PASS",
        "expected_count": expected_count,
        "running_count": len(updated),
        "workers": updated,
        "only_terminal": only_terminal,
        "target_running": (
            bool(only_terminal and only_terminal in updated)
            if only_terminal
            else None
        ),
        "stopped_duplicates": stopped_duplicates,
        "installed_terminals": list(installed_terminals),
        "governed_terminals": list(terminals),
        "reserved_terminals_skipped": sorted(skipped_reserved),
        "resource_headroom": headroom_decision,
    }, sort_keys=True))
    return 5 if shortfall else 0


if __name__ == "__main__":
    raise SystemExit(main())
