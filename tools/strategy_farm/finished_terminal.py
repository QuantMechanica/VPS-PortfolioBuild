"""Recover an owned terminal after completed testing, without stopping its runner.

Read probes are bounded; time spent continuously observing a finished run must
exceed five minutes. Native process termination uses an identity-checked handle.
"""
from __future__ import annotations

import ctypes
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

GRACE_SECONDS = 300.0
POLL_SECONDS = 30.0
TAIL_BYTES = 2 * 1024 * 1024
_SPAWN = re.compile(r"run_smoke\.stage=terminal_spawn_confirmed terminal_pid=(\d+) start_time='([^']+)'")
_START = re.compile(r"run_smoke\.stage=terminal_start exe='([^']+)' args='[^']*?/config:([^']+)'")
_CONFIG = re.compile(r'(?:successfully initialized from start config "|launched with )([^\r\n"]+tester\.ini)', re.I)
_LOG_TIME = re.compile(r"^\S+\t\d+\t(\d{2}:\d{2}:\d{2}\.\d+)\t", re.M)
_TEST_START = re.compile(r"testing of Experts|agent process started|MetaTester 5 started", re.I)


def _normal(path) -> str:
    return os.path.normcase(str(Path(path).resolve()))


def _tail(path: Path) -> str:
    with path.open("rb") as stream:
        size = path.stat().st_size
        start = max(0, size - TAIL_BYTES)
        start += start % 2  # retain UTF-16 alignment
        stream.seek(start)
        raw = stream.read(TAIL_BYTES)
    sample = raw[:512]
    return raw.decode("utf-16-le" if sample.count(0) > len(sample) // 4 else "utf-8-sig", errors="replace")


def _daily_logs(directory: Path) -> list[tuple[Path, str]]:
    paths = sorted(p for p in directory.glob("*.log") if re.fullmatch(r"\d{8}\.log", p.name))
    return [(p, _tail(p)) for p in paths[-3:]]


def windows_creation_key(start_time: str) -> str:
    """Preserve all seven .NET fractional digits; no floating timestamp match."""
    stamp = datetime.fromisoformat(start_time)
    if stamp.tzinfo is None: raise ValueError("spawn time must include offset")
    fraction = re.search(r"T\d{2}:\d{2}:\d{2}\.(\d{1,7})(?:Z|[+-]\d{2}:\d{2})$", start_time)
    fractional_ticks = int(fraction.group(1).ljust(7, "0")) if fraction else 0
    delta = stamp.astimezone(timezone.utc).replace(microsecond=0) - datetime(1970, 1, 1, tzinfo=timezone.utc)
    ticks = 116444736000000000 + (delta.days * 86400 + delta.seconds) * 10000000 + fractional_ticks
    return f"windows-filetime:{ticks}"


def inspect_candidate(item_id: str, terminal: str, payload: dict, mt5_root: Path,
                      identity_provider, *, now_utc: datetime | None = None) -> dict | None:
    """Require the last spawn, exact startup INI, current finish and no report."""
    if not re.fullmatch(r"T(?:[1-9]|10)", terminal): return None
    if not payload.get("log_path") or not payload.get("report_root"): return None
    try:
        runner_log = _tail(Path(payload["log_path"]))
        starts, spawns = list(_START.finditer(runner_log)), list(_SPAWN.finditer(runner_log))
        if not starts or not spawns: return None
        start, spawn = starts[-1], spawns[-1]
        if spawn.start() < start.start(): return None
        after_spawn = runner_log[spawn.end():]
        if any(token in after_spawn for token in ("run_smoke.stage=terminal_exit", "run_smoke.stage=valid_report_latched",
                                                  "run_smoke.stage=terminal_start", "run_smoke.stage=start_terminal",
                                                  "run_smoke.stage=ini_written")):
            return None
        terminal_dir = mt5_root / terminal
        expected_image = terminal_dir / "terminal64.exe"
        if _normal(start.group(1)) != _normal(expected_image): return None
        ini_path = Path(start.group(2).strip().strip('"')).resolve()
        report_root = Path(payload["report_root"]).resolve()
        if not ini_path.is_relative_to(report_root) or item_id.lower() not in str(ini_path).lower(): return None
        raw_dir = ini_path.parent
        if not re.fullmatch(r"run_\d+", raw_dir.name) or raw_dir.parent.name != "raw": return None
        if any(raw_dir.glob("*.htm")) or any(raw_dir.glob("*.html")): return None
        settings = {}
        for line in _tail(ini_path).splitlines():
            if "=" in line:
                key, value = line.split("=", 1); settings[key.strip().lower()] = value.strip()
        if settings.get("optimization") != "0" or settings.get("shutdownterminal") != "1": return None
        report_name = settings.get("report", "")
        if not report_name or Path(report_name).name != report_name or Path(report_name).is_absolute(): return None
        source_report = terminal_dir / report_name
        candidates = [raw_dir / "report.htm", raw_dir / "report.html", source_report,
                      source_report.with_suffix(".htm"), source_report.with_suffix(".html")]
        if any(path.exists() for path in candidates): return None
        pid, started_at = int(spawn.group(1)), spawn.group(2)
        expected_key = windows_creation_key(started_at)
        identity = identity_provider(pid)
        if not identity or not identity.get("is_running") or identity.get("creation_key") != expected_key:
            return None
        if _normal(identity.get("image_path", "")) != _normal(expected_image): return None
        terminal_logs = _daily_logs(terminal_dir / "logs")
        config_matches = [(path, match) for path, text in terminal_logs for match in _CONFIG.finditer(text)]
        if not config_matches or _normal(config_matches[-1][1].group(1)) != _normal(ini_path): return None
        tester_logs = _daily_logs(terminal_dir / "Tester/logs")
        last_finish = None
        for path, text in tester_logs:
            for line in text.splitlines():
                if _TEST_START.search(line): last_finish = None
                if "automatic testing finished" in line.lower():
                    stamp = _LOG_TIME.match(line)
                    if not stamp: return None
                    civil = datetime.strptime(path.stem + " " + stamp.group(1), "%Y%m%d %H:%M:%S.%f")
                    last_finish = (path, line, civil)
        if last_finish is None: return None
        path, finish_line, finish_civil = last_finish
        start_dt = datetime.fromisoformat(started_at)
        current = now_utc or datetime.now(timezone.utc)
        if not start_dt.replace(tzinfo=None) <= finish_civil <= current.astimezone(start_dt.tzinfo).replace(tzinfo=None):
            return None
        fingerprint = hashlib.sha256(json.dumps([item_id, pid, expected_key, str(ini_path), str(path), finish_line]).encode()).hexdigest()
        return {"fingerprint": fingerprint, "item_id": item_id, "terminal": terminal,
                "terminal_pid": pid, "terminal_creation_key": expected_key, "terminal_image": str(expected_image),
                "terminal_started_at": started_at, "tester_finished_at_local": finish_civil.isoformat(),
                "tester_log_path": str(path), "tester_finish_line": finish_line,
                "ini_path": str(ini_path), "raw_run_dir": str(raw_dir), "source_report": str(source_report),
                "report_absent_paths": [str(p) for p in candidates]}
    except (OSError, ValueError, TypeError, OverflowError):
        return None


def terminate_verified_terminal(candidate: dict) -> bool:
    """Terminate exactly the terminal handle whose immutable identity matches.

    Called only by its owning terminal worker after completion/grace checks.
    The controller's disabled generic PID-kill capability remains unchanged.
    """
    if sys.platform != "win32": return False
    import process_identity as pi
    from ctypes import wintypes
    kernel = pi._windows_kernel32()
    pi._configure_windows_process_api(kernel)
    kernel.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
    kernel.TerminateProcess.restype = wintypes.BOOL
    handle = kernel.OpenProcess(0x1000 | 0x0001, False, int(candidate["terminal_pid"]))
    if not handle: return False
    try:
        identity = pi._windows_identity_from_handle(kernel, handle, candidate["terminal_pid"])
        if (not identity.get("is_running") or identity.get("creation_key") != candidate["terminal_creation_key"]
                or _normal(identity.get("image_path", "")) != _normal(candidate["terminal_image"])):
            return False
        return bool(kernel.TerminateProcess(handle, 1))
    except OSError:
        return False
    finally:
        kernel.CloseHandle(handle)


def poll(item_id: str, terminal: str, payload: dict, mt5_root: Path, state: dict,
         now_monotonic: float, identity_provider, terminate=terminate_verified_terminal,
         *, now_utc: datetime | None = None) -> dict | None:
    if now_monotonic - state.get("last_poll", -1e30) < POLL_SECONDS: return None
    state["last_poll"] = now_monotonic
    candidate = inspect_candidate(item_id, terminal, payload, mt5_root, identity_provider, now_utc=now_utc)
    if candidate is None:
        state.pop("fingerprint", None); state.pop("first_seen", None)
        return None
    key = candidate["fingerprint"]
    if state.get("fingerprint") != key:
        state.update(fingerprint=key, first_seen=now_monotonic, first_seen_at_utc=(now_utc or datetime.now(timezone.utc)).isoformat())
        return None
    elapsed = now_monotonic - state["first_seen"]
    if elapsed <= GRACE_SECONDS or state.get("acted") == key: return None
    # Report/identity/config checks repeat immediately before opening the handle.
    fresh = inspect_candidate(item_id, terminal, payload, mt5_root, identity_provider, now_utc=now_utc)
    if not fresh or fresh["fingerprint"] != key: return None
    state["acted"] = key
    stopped = terminate(fresh)
    return {"event": "terminal_finished_but_alive", **fresh, "terminal_stopped": bool(stopped),
            "observed_finished_seconds": elapsed, "first_seen_at_utc": state["first_seen_at_utc"],
            "acted_at_utc": (now_utc or datetime.now(timezone.utc)).isoformat()}
