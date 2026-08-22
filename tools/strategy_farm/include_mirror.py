#!/usr/bin/env python3
"""Fail-closed, atomic include mirroring for governed COMPILE_EA work.

The live factory may keep terminal include files open.  A compile is therefore
allowed beside live terminals only when it belongs to a claimed COMPILE_EA
work item, the claimed terminal itself is quiescent, and this module owns the
single global mirror mutex.  File content is installed by same-directory
``os.replace`` so interruption can leave a mix of old/new files, but never a
partially written destination file.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any, Iterable


DEFAULT_LOCK_PATH = Path(r"D:\QM\strategy_farm\state\locks\include_mirror.lock")
PIPELINE_HINT = (
    "python tools/strategy_farm/farmctl.py enqueue-compile <EA label>"
)


class IncludeMirrorRefusal(RuntimeError):
    def __init__(self, failure_class: str, detail: str) -> None:
        super().__init__(detail)
        self.failure_class = failure_class
        self.retry_attempted = False


def _pid_exists(pid: Any) -> bool:
    """PID liveness probe that never signals the target.

    ``os.kill(pid, 0)`` is NOT a probe on Windows: CPython maps unsupported
    signals to ``TerminateProcess`` and would kill the probed process (the
    codex kill-safety audit blocks the pump on exactly this pattern; see
    ``health._pid_alive_no_signal`` for the canonical OpenProcess probe).
    """
    try:
        pid_int = int(pid)
    except (TypeError, ValueError):
        return False
    if pid_int <= 0:
        return False
    if sys.platform == "win32":
        import ctypes

        PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        STILL_ACTIVE = 259
        kernel32 = ctypes.windll.kernel32
        handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid_int)
        if not handle:
            return False
        try:
            code = ctypes.c_ulong()
            ok = kernel32.GetExitCodeProcess(handle, ctypes.byref(code))
            return bool(ok) and code.value == STILL_ACTIVE
        finally:
            kernel32.CloseHandle(handle)
    try:
        os.kill(pid_int, 0)
        return True
    except OSError:
        return False


class IncludeMirrorMutex:
    """Exclusive, process-owned file mutex with conservative stale recovery."""

    def __init__(self, path: Path = DEFAULT_LOCK_PATH, timeout_seconds: float = 300.0) -> None:
        self.path = Path(path)
        self.timeout_seconds = max(0.0, float(timeout_seconds))
        self.token = uuid.uuid4().hex
        self.fd: int | None = None
        self.held = False

    def _remove_stale(self) -> bool:
        try:
            payload = json.loads(self.path.read_text(encoding="utf-8"))
            owner_pid = payload.get("pid")
        except (OSError, ValueError, TypeError):
            # Another process can observe the file between O_EXCL creation and
            # the metadata fsync.  Never delete a fresh, temporarily empty lock.
            try:
                if time.time() - self.path.stat().st_mtime < 300.0:
                    return False
            except OSError:
                return False
            owner_pid = None
        if owner_pid is not None and _pid_exists(owner_pid):
            return False
        try:
            self.path.unlink()
            return True
        except FileNotFoundError:
            return True
        except OSError:
            return False

    def acquire(self) -> "IncludeMirrorMutex":
        self.path.parent.mkdir(parents=True, exist_ok=True)
        deadline = time.monotonic() + self.timeout_seconds
        while True:
            try:
                self.fd = os.open(
                    str(self.path),
                    os.O_CREAT | os.O_EXCL | os.O_WRONLY,
                )
                payload = {
                    "pid": os.getpid(),
                    "token": self.token,
                    "acquired_at_epoch": time.time(),
                }
                os.write(self.fd, json.dumps(payload, sort_keys=True).encode("utf-8"))
                os.fsync(self.fd)
                self.held = True
                return self
            except FileExistsError:
                if self._remove_stale():
                    continue
                if time.monotonic() >= deadline:
                    raise IncludeMirrorRefusal(
                        "INCLUDE_MIRROR_MUTEX_BUSY",
                        f"global include mirror mutex is held: {self.path}",
                    )
                time.sleep(0.1)

    def release(self) -> None:
        if self.fd is not None:
            try:
                os.close(self.fd)
            except OSError:
                pass
            self.fd = None
        if self.held:
            try:
                payload = json.loads(self.path.read_text(encoding="utf-8"))
                if payload.get("token") == self.token:
                    self.path.unlink()
            except (FileNotFoundError, OSError, ValueError, TypeError):
                pass
        self.held = False

    def __enter__(self) -> "IncludeMirrorMutex":
        return self.acquire()

    def __exit__(self, *_exc: object) -> None:
        self.release()


def running_terminal_names() -> set[str]:
    """Return T<n> names for live terminal64 processes; fail closed on probe error."""
    if sys.platform != "win32":
        return set()
    probe = subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-Command",
            "$ErrorActionPreference='Stop'; "
            "@(Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" | "
            "ForEach-Object { $_.ExecutablePath })",
        ],
        capture_output=True,
        text=True,
        timeout=20,
        check=False,
    )
    if probe.returncode != 0:
        raise IncludeMirrorRefusal(
            "TERMINAL_PROCESS_PROBE_FAILED",
            (probe.stderr or probe.stdout or "terminal64 process probe failed").strip(),
        )
    terminals: set[str] = set()
    for raw_path in (probe.stdout or "").splitlines():
        path = raw_path.strip()
        if not path:
            continue
        # The guard protects FACTORY quiescence (T1-T10 share the include
        # mirror). The live terminal and the FTMO demo terminal run 24/7 by
        # design, own frozen deploys, and never consume the mirror — counting
        # them (via the UNKNOWN bucket) made the ad-hoc path permanently dead
        # on this host, even with the factory fully OFF (2026-08-22 ceremony:
        # refusal at zero factory terminals). Anything else unrecognized still
        # blocks fail-closed.
        if re.search(r"(?i)[\\/]mt5[\\/]T_Live[\\/]", path):
            continue
        if re.search(r"(?i)FTMO[^\\/]*MT5", path):
            continue
        match = re.search(r"(?i)[\\/]mt5[\\/](T\d+)[\\/]terminal64\.exe$", path)
        terminals.add(match.group(1).upper() if match else "UNKNOWN")
    return terminals


def validate_compile_contract(
    *,
    running_terminals: Iterable[str],
    pipeline_work_item_id: str | None,
    claimed_terminal: str | None,
    lock_held: bool,
    preflight: bool = False,
) -> None:
    """Refuse live-factory ad-hoc compiles and non-quiescent claimed slots."""
    running = {str(value).strip().upper() for value in running_terminals if str(value).strip()}
    work_item_id = str(pipeline_work_item_id or "").strip()
    terminal = str(claimed_terminal or "").strip().upper()
    if running and not work_item_id:
        raise IncludeMirrorRefusal(
            "LIVE_FACTORY_AD_HOC_COMPILE_REFUSED",
            "terminal64 processes are alive; ad-hoc compile/build_check is refused. "
            f"Use the governed pipeline path: {PIPELINE_HINT}. No retry was attempted.",
        )
    if work_item_id and not re.fullmatch(r"[0-9a-fA-F-]{8,64}", work_item_id):
        raise IncludeMirrorRefusal(
            "COMPILE_WORK_ITEM_ID_INVALID",
            f"invalid COMPILE_EA work-item id: {work_item_id!r}",
        )
    if work_item_id and not re.fullmatch(r"T(?:10|[1-9])", terminal):
        raise IncludeMirrorRefusal(
            "COMPILE_CLAIMED_TERMINAL_INVALID",
            f"pipeline compile requires a claimed T1-T10 terminal, got {terminal!r}",
        )
    if work_item_id and terminal in running:
        raise IncludeMirrorRefusal(
            "COMPILE_CLAIMED_TERMINAL_RUNNING",
            f"{terminal} is running; include mirroring is DEFERRED to its next quiescent claim. "
            "No process was stopped and no retry was attempted.",
        )
    if not preflight and not lock_held:
        raise IncludeMirrorRefusal(
            "INCLUDE_MIRROR_MUTEX_REQUIRED",
            "include mirroring requires the global include-mirror mutex; "
            f"use {PIPELINE_HINT} while the factory is live",
        )


def _atomic_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temp = destination.with_name(
        f".{destination.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp"
    )
    try:
        with source.open("rb") as src, temp.open("xb") as dst:
            shutil.copyfileobj(src, dst, length=1024 * 1024)
            dst.flush()
            os.fsync(dst.fileno())
        os.replace(temp, destination)
    finally:
        try:
            temp.unlink()
        except FileNotFoundError:
            pass


def mirror_targets(
    source_root: Path,
    target_roots: Iterable[Path],
    *,
    mutex: IncludeMirrorMutex,
    fail_after_files: int | None = None,
) -> dict[str, Any]:
    """Mirror regular files; each destination independently remains old or new."""
    if not mutex.held:
        raise IncludeMirrorRefusal(
            "INCLUDE_MIRROR_MUTEX_REQUIRED",
            "mirror_targets called without the held global mutex",
        )
    source = Path(source_root).resolve()
    if not source.is_dir():
        raise IncludeMirrorRefusal(
            "INCLUDE_SOURCE_MISSING",
            f"framework include source does not exist: {source}",
        )
    targets = [Path(target).resolve() for target in target_roots]
    if not targets:
        raise IncludeMirrorRefusal(
            "INCLUDE_TARGETS_EMPTY",
            "no include target belongs to the claimed terminal",
        )
    source_files = sorted(path for path in source.rglob("*") if path.is_file())
    copied = 0
    per_target: dict[str, int] = {}
    for target in targets:
        target_count = 0
        for source_file in source_files:
            if fail_after_files is not None and copied >= fail_after_files:
                raise RuntimeError("simulated mid-mirror failure")
            relative = source_file.relative_to(source)
            _atomic_copy(source_file, target / relative)
            copied += 1
            target_count += 1
        per_target[str(target)] = target_count
    return {
        "atomic_replace": True,
        "copied_file_count": copied,
        "files_per_target": per_target,
        "source_root": str(source),
        "target_roots": [str(target) for target in targets],
    }


def run_mirror(
    *,
    source_root: Path,
    target_roots: Iterable[Path],
    pipeline_work_item_id: str | None,
    claimed_terminal: str | None,
    lock_path: Path = DEFAULT_LOCK_PATH,
    lock_timeout_seconds: float = 300.0,
    running_terminals: Iterable[str] | None = None,
) -> dict[str, Any]:
    running = set(running_terminals) if running_terminals is not None else running_terminal_names()
    validate_compile_contract(
        running_terminals=running,
        pipeline_work_item_id=pipeline_work_item_id,
        claimed_terminal=claimed_terminal,
        lock_held=False,
        preflight=True,
    )
    with IncludeMirrorMutex(lock_path, lock_timeout_seconds) as mutex:
        validate_compile_contract(
            running_terminals=running,
            pipeline_work_item_id=pipeline_work_item_id,
            claimed_terminal=claimed_terminal,
            lock_held=True,
        )
        mirrored = mirror_targets(source_root, target_roots, mutex=mutex)
    return {
        "ok": True,
        "schema_version": "qm.include-mirror/v1",
        "mutex_path": str(Path(lock_path).resolve()),
        "running_terminals": sorted(str(value).upper() for value in running),
        "pipeline_work_item_id": pipeline_work_item_id,
        "claimed_terminal": str(claimed_terminal or "").upper() or None,
        "retry_attempted": False,
        **mirrored,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    guard = sub.add_parser("guard", help="Fail-closed live-factory compile preflight")
    mirror = sub.add_parser("mirror", help="Acquire mutex and atomically mirror includes")
    for command in (guard, mirror):
        command.add_argument("--pipeline-work-item-id")
        command.add_argument("--claimed-terminal")
    mirror.add_argument("--source", type=Path, required=True)
    mirror.add_argument("--target", type=Path, action="append", required=True)
    mirror.add_argument("--lock-timeout-seconds", type=float, default=300.0)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        running = running_terminal_names()
        if args.command == "guard":
            validate_compile_contract(
                running_terminals=running,
                pipeline_work_item_id=args.pipeline_work_item_id,
                claimed_terminal=args.claimed_terminal,
                lock_held=False,
                preflight=True,
            )
            result = {
                "ok": True,
                "schema_version": "qm.include-mirror-guard/v1",
                "running_terminals": sorted(running),
                "pipeline_work_item_id": args.pipeline_work_item_id,
                "claimed_terminal": args.claimed_terminal,
                "pipeline_hint": PIPELINE_HINT,
                "retry_attempted": False,
            }
        else:
            result = run_mirror(
                source_root=args.source,
                target_roots=args.target,
                pipeline_work_item_id=args.pipeline_work_item_id,
                claimed_terminal=args.claimed_terminal,
                lock_path=DEFAULT_LOCK_PATH,
                lock_timeout_seconds=args.lock_timeout_seconds,
                running_terminals=running,
            )
        print(json.dumps(result, sort_keys=True))
        return 0
    except IncludeMirrorRefusal as exc:
        print(
            json.dumps(
                {
                    "ok": False,
                    "failure_class": exc.failure_class,
                    "detail": str(exc),
                    "pipeline_hint": PIPELINE_HINT,
                    "retry_attempted": exc.retry_attempted,
                },
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 2
    except Exception as exc:
        print(
            json.dumps(
                {
                    "ok": False,
                    "failure_class": "INCLUDE_MIRROR_EXCEPTION",
                    "detail": repr(exc),
                    "retry_attempted": False,
                },
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
