"""Ownership-safe lifecycle management for Strategy Farm Codex processes.

The Strategy Farm runs alongside interactive Codex sessions on the same Windows
desktop.  Process name, command line, age, and working directory are therefore
not ownership proofs.  This module records one atomic lease for every
farm-created Codex process tree and only ever acts on those leases.

The lease identity is the wrapper PID plus the operating system's immutable
process creation key.  The creation key prevents a stale lease from targeting a
new process after Windows reuses a PID.
"""

from __future__ import annotations

import ctypes
import datetime as dt
import base64
import hashlib
import json
import math
import os
import signal
import subprocess
import sys
import time
import uuid
from ctypes import wintypes
from pathlib import Path
from typing import Any, Mapping, Sequence


LEASE_SCHEMA_VERSION = 2
LEASE_OWNER = "qm_strategy_farm"
LEASE_DIR_REL = Path("state") / "codex_process_leases"
CLAIM_RECOVERY_SECONDS = 120.0
_WINDOWS_FILETIME_UNIX_EPOCH = 116_444_736_000_000_000
_WINDOWS_TICKS_PER_SECOND = 10_000_000
_JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000
_JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS = 9
_JOB_OBJECT_QUERY = 0x0004
_JOB_OBJECT_TERMINATE = 0x0008
_SYNCHRONIZE = 0x00100000


class _JOBOBJECT_BASIC_LIMIT_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("PerProcessUserTimeLimit", ctypes.c_longlong),
        ("PerJobUserTimeLimit", ctypes.c_longlong),
        ("LimitFlags", wintypes.DWORD),
        ("MinimumWorkingSetSize", ctypes.c_size_t),
        ("MaximumWorkingSetSize", ctypes.c_size_t),
        ("ActiveProcessLimit", wintypes.DWORD),
        ("Affinity", ctypes.c_size_t),
        ("PriorityClass", wintypes.DWORD),
        ("SchedulingClass", wintypes.DWORD),
    ]


class _IO_COUNTERS(ctypes.Structure):
    _fields_ = [
        ("ReadOperationCount", ctypes.c_ulonglong),
        ("WriteOperationCount", ctypes.c_ulonglong),
        ("OtherOperationCount", ctypes.c_ulonglong),
        ("ReadTransferCount", ctypes.c_ulonglong),
        ("WriteTransferCount", ctypes.c_ulonglong),
        ("OtherTransferCount", ctypes.c_ulonglong),
    ]


class _JOBOBJECT_EXTENDED_LIMIT_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("BasicLimitInformation", _JOBOBJECT_BASIC_LIMIT_INFORMATION),
        ("IoInfo", _IO_COUNTERS),
        ("ProcessMemoryLimit", ctypes.c_size_t),
        ("JobMemoryLimit", ctypes.c_size_t),
        ("PeakProcessMemoryUsed", ctypes.c_size_t),
        ("PeakJobMemoryUsed", ctypes.c_size_t),
    ]


class ManagedCodexError(RuntimeError):
    """A managed Codex process could not be safely registered or controlled."""


class ManagedCodexAlreadyRunning(ManagedCodexError):
    """The same logical farm work already has a live managed process."""


def _lease_dir(farm_root: Path | str) -> Path:
    return Path(farm_root) / LEASE_DIR_REL


def _utc_iso(epoch_seconds: float) -> str:
    return dt.datetime.fromtimestamp(epoch_seconds, tz=dt.UTC).isoformat()


def _windows_kernel32() -> Any:
    if os.name != "nt":
        raise ManagedCodexError("Windows Job Objects are unavailable on this platform")
    return ctypes.WinDLL("kernel32", use_last_error=True)


def _create_windows_job(job_name: str) -> int:
    """Create a unique named Job Object with kill-on-last-handle-close."""

    kernel32 = _windows_kernel32()
    kernel32.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
    kernel32.CreateJobObjectW.restype = wintypes.HANDLE
    kernel32.SetInformationJobObject.argtypes = [
        wintypes.HANDLE,
        ctypes.c_int,
        ctypes.c_void_p,
        wintypes.DWORD,
    ]
    kernel32.SetInformationJobObject.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL

    ctypes.set_last_error(0)
    handle = kernel32.CreateJobObjectW(None, str(job_name))
    create_error = ctypes.get_last_error()
    if not handle:
        raise OSError(create_error, f"CreateJobObjectW({job_name!r}) failed")
    if create_error == 183:  # ERROR_ALREADY_EXISTS
        kernel32.CloseHandle(handle)
        raise ManagedCodexError(f"Windows Job Object already exists: {job_name}")

    limits = _JOBOBJECT_EXTENDED_LIMIT_INFORMATION()
    limits.BasicLimitInformation.LimitFlags = _JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
    if not kernel32.SetInformationJobObject(
        handle,
        _JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS,
        ctypes.byref(limits),
        ctypes.sizeof(limits),
    ):
        error = ctypes.get_last_error()
        kernel32.CloseHandle(handle)
        raise OSError(error, f"SetInformationJobObject({job_name!r}) failed")
    return int(handle)


def _assign_current_process_to_windows_job(job_handle: int) -> None:
    kernel32 = _windows_kernel32()
    kernel32.GetCurrentProcess.argtypes = []
    kernel32.GetCurrentProcess.restype = wintypes.HANDLE
    kernel32.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
    kernel32.AssignProcessToJobObject.restype = wintypes.BOOL
    if not kernel32.AssignProcessToJobObject(
        wintypes.HANDLE(int(job_handle)), kernel32.GetCurrentProcess()
    ):
        error = ctypes.get_last_error()
        raise OSError(error, "AssignProcessToJobObject(current process) failed")


def _terminate_windows_job(
    job_name: str,
    *,
    expected_pid: int | None = None,
    timeout_seconds: float = 30.0,
) -> dict[str, Any]:
    """Atomically terminate one owned Job Object and verify all members exited."""

    kernel32 = _windows_kernel32()
    kernel32.OpenJobObjectW.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.LPCWSTR]
    kernel32.OpenJobObjectW.restype = wintypes.HANDLE
    kernel32.TerminateJobObject.argtypes = [wintypes.HANDLE, wintypes.UINT]
    kernel32.TerminateJobObject.restype = wintypes.BOOL
    kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel32.OpenProcess.restype = wintypes.HANDLE
    kernel32.IsProcessInJob.argtypes = [
        wintypes.HANDLE,
        wintypes.HANDLE,
        ctypes.POINTER(wintypes.BOOL),
    ]
    kernel32.IsProcessInJob.restype = wintypes.BOOL
    kernel32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel32.WaitForSingleObject.restype = wintypes.DWORD
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL

    handle = kernel32.OpenJobObjectW(
        _SYNCHRONIZE | _JOB_OBJECT_QUERY | _JOB_OBJECT_TERMINATE,
        False,
        str(job_name),
    )
    if not handle:
        error = ctypes.get_last_error()
        if error in (2, 6):  # ERROR_FILE_NOT_FOUND / ERROR_INVALID_HANDLE
            return {"stopped": False, "reason": "job_not_found", "job_name": job_name}
        return {
            "stopped": False,
            "reason": "job_open_failed",
            "job_name": job_name,
            "error": error,
        }
    try:
        if expected_pid is not None:
            process_query_limited_information = 0x1000
            process_handle = kernel32.OpenProcess(
                process_query_limited_information, False, int(expected_pid)
            )
            if not process_handle:
                return {
                    "stopped": False,
                    "reason": "job_owner_process_open_failed",
                    "job_name": job_name,
                    "pid": int(expected_pid),
                    "error": ctypes.get_last_error(),
                }
            try:
                is_member = wintypes.BOOL(False)
                if not kernel32.IsProcessInJob(
                    process_handle, handle, ctypes.byref(is_member)
                ):
                    return {
                        "stopped": False,
                        "reason": "job_membership_check_failed",
                        "job_name": job_name,
                        "pid": int(expected_pid),
                        "error": ctypes.get_last_error(),
                    }
                if not bool(is_member.value):
                    return {
                        "stopped": False,
                        "reason": "job_membership_mismatch",
                        "job_name": job_name,
                        "pid": int(expected_pid),
                    }
            finally:
                kernel32.CloseHandle(process_handle)
        if not kernel32.TerminateJobObject(handle, 1):
            error = ctypes.get_last_error()
            return {
                "stopped": False,
                "reason": "job_terminate_failed",
                "job_name": job_name,
                "error": error,
            }
        wait_ms = max(1, min(int(timeout_seconds * 1000), 0xFFFFFFFE))
        wait_result = int(kernel32.WaitForSingleObject(handle, wait_ms))
        if wait_result != 0:  # WAIT_OBJECT_0
            return {
                "stopped": False,
                "reason": "job_termination_unconfirmed",
                "job_name": job_name,
                "wait_result": wait_result,
            }
        return {"stopped": True, "reason": "job_terminated", "job_name": job_name}
    finally:
        kernel32.CloseHandle(handle)


def _get_windows_process_identity(pid: int) -> dict[str, Any] | None:
    """Return an exact Windows process identity using GetProcessTimes.

    ``None`` means the PID no longer exists.  Access and API failures raise so
    callers fail closed and leave the lease untouched.
    """

    process_query_limited_information = 0x1000
    error_invalid_parameter = 87
    error_invalid_handle = 6

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel32.OpenProcess.restype = wintypes.HANDLE
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL
    kernel32.GetProcessTimes.argtypes = [
        wintypes.HANDLE,
        ctypes.POINTER(wintypes.FILETIME),
        ctypes.POINTER(wintypes.FILETIME),
        ctypes.POINTER(wintypes.FILETIME),
        ctypes.POINTER(wintypes.FILETIME),
    ]
    kernel32.GetProcessTimes.restype = wintypes.BOOL
    kernel32.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    kernel32.GetExitCodeProcess.restype = wintypes.BOOL
    kernel32.QueryFullProcessImageNameW.argtypes = [
        wintypes.HANDLE,
        wintypes.DWORD,
        wintypes.LPWSTR,
        ctypes.POINTER(wintypes.DWORD),
    ]
    kernel32.QueryFullProcessImageNameW.restype = wintypes.BOOL

    handle = kernel32.OpenProcess(process_query_limited_information, False, int(pid))
    if not handle:
        error = ctypes.get_last_error()
        if error in (error_invalid_parameter, error_invalid_handle):
            return None
        raise OSError(error, f"OpenProcess({pid}) failed")

    try:
        created = wintypes.FILETIME()
        exited = wintypes.FILETIME()
        kernel = wintypes.FILETIME()
        user = wintypes.FILETIME()
        if not kernel32.GetProcessTimes(
            handle,
            ctypes.byref(created),
            ctypes.byref(exited),
            ctypes.byref(kernel),
            ctypes.byref(user),
        ):
            error = ctypes.get_last_error()
            if error == error_invalid_handle:
                return None
            raise OSError(error, f"GetProcessTimes({pid}) failed")

        creation_ticks = (int(created.dwHighDateTime) << 32) | int(created.dwLowDateTime)
        started_at = (
            creation_ticks - _WINDOWS_FILETIME_UNIX_EPOCH
        ) / _WINDOWS_TICKS_PER_SECOND

        exit_code = wintypes.DWORD()
        if not kernel32.GetExitCodeProcess(handle, ctypes.byref(exit_code)):
            error = ctypes.get_last_error()
            if error == error_invalid_handle:
                return None
            raise OSError(error, f"GetExitCodeProcess({pid}) failed")

        image_buffer = ctypes.create_unicode_buffer(32768)
        image_size = wintypes.DWORD(len(image_buffer))
        image_path = ""
        if kernel32.QueryFullProcessImageNameW(
            handle, 0, image_buffer, ctypes.byref(image_size)
        ):
            image_path = image_buffer.value

        return {
            "pid": int(pid),
            "creation_key": f"windows-filetime:{creation_ticks}",
            "started_at_epoch": float(started_at),
            "image_path": image_path,
            # GetProcessTimes documents lpExitTime as undefined while a process
            # is running.  GetExitCodeProcess is the authoritative liveness
            # signal; STILL_ACTIVE is 259.
            "is_running": int(exit_code.value) == 259,
        }
    finally:
        kernel32.CloseHandle(handle)


def _get_posix_process_identity(pid: int) -> dict[str, Any] | None:
    """Best-effort process identity for developer/test hosts with ``/proc``."""

    proc_dir = Path("/proc") / str(int(pid))
    stat_path = proc_dir / "stat"
    try:
        raw = stat_path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise OSError(exc.errno, f"cannot read {stat_path}") from exc

    closing_paren = raw.rfind(")")
    fields = raw[closing_paren + 2 :].split() if closing_paren >= 0 else []
    if len(fields) <= 19:
        raise ManagedCodexError(f"unexpected /proc stat format for PID {pid}")
    start_ticks = int(fields[19])  # field 22; tail begins at field 3

    boot_epoch = None
    try:
        for line in Path("/proc/stat").read_text(encoding="utf-8").splitlines():
            if line.startswith("btime "):
                boot_epoch = float(line.split()[1])
                break
    except OSError:
        pass
    if boot_epoch is None:
        raise ManagedCodexError("cannot determine /proc boot time")

    clock_ticks = int(os.sysconf("SC_CLK_TCK"))
    image_path = ""
    try:
        image_path = os.readlink(proc_dir / "exe")
    except OSError:
        pass
    return {
        "pid": int(pid),
        "creation_key": f"proc-start-ticks:{start_ticks}",
        "started_at_epoch": boot_epoch + (start_ticks / clock_ticks),
        "image_path": image_path,
        "is_running": fields[0] != "Z",
    }


def _get_process_identity(pid: int) -> dict[str, Any] | None:
    if os.name == "nt":
        return _get_windows_process_identity(pid)
    return _get_posix_process_identity(pid)


def _atomic_write_json(path: Path, payload: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        with temporary.open("w", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        try:
            temporary.unlink(missing_ok=True)
        except OSError:
            pass


def _json_safe_metadata(metadata: Mapping[str, Any] | None) -> dict[str, Any]:
    if not metadata:
        return {}
    return json.loads(json.dumps(dict(metadata), default=str))


def _dedupe_hash(dedupe_key: str) -> str:
    return hashlib.sha256(str(dedupe_key).encode("utf-8")).hexdigest()


def register_managed_codex_process(
    farm_root: Path | str,
    pid: int,
    *,
    purpose: str,
    argv: Sequence[str],
    cwd: Path | str,
    max_age_minutes: int,
    windows_job_name: str | None = None,
    dedupe_key: str | None = None,
    metadata: Mapping[str, Any] | None = None,
    now: float | None = None,
) -> dict[str, Any]:
    """Atomically register a farm-owned process tree.

    Registration raises on failure.  Callers that just spawned the process must
    then terminate that exact new tree rather than allow an unowned farm process
    to escape lifecycle management.
    """

    pid = int(pid)
    if pid <= 0:
        raise ManagedCodexError(f"invalid managed process PID: {pid}")
    if not str(purpose).strip():
        raise ManagedCodexError("managed process purpose must not be empty")
    if int(max_age_minutes) <= 0:
        raise ManagedCodexError("max_age_minutes must be positive")
    if os.name == "nt" and not str(windows_job_name or "").strip():
        raise ManagedCodexError("Windows managed processes require a named Job Object")

    identity = _get_process_identity(pid)
    if identity is None or not _identity_is_running(identity):
        raise ManagedCodexError(f"managed process PID {pid} exited before registration")

    registered_at = float(time.time() if now is None else now)
    started_at = float(identity["started_at_epoch"])
    lease_id = uuid.uuid4().hex
    argv_text = "\0".join(str(part) for part in argv)
    lease = {
        "schema_version": LEASE_SCHEMA_VERSION,
        "owner": LEASE_OWNER,
        "lease_id": lease_id,
        "pid": pid,
        "process_creation_key": str(identity["creation_key"]),
        "process_started_at": _utc_iso(started_at),
        "process_started_at_epoch": started_at,
        "registered_at": _utc_iso(registered_at),
        "registered_at_epoch": registered_at,
        "max_age_minutes": int(max_age_minutes),
        "expires_at_epoch": started_at + (int(max_age_minutes) * 60),
        "purpose": str(purpose),
        "cwd": str(Path(cwd)),
        "launcher_image": str(identity.get("image_path") or ""),
        "argv_sha256": hashlib.sha256(argv_text.encode("utf-8")).hexdigest(),
        "metadata": _json_safe_metadata(metadata),
    }
    if windows_job_name:
        lease["windows_job_name"] = str(windows_job_name)
    if dedupe_key:
        lease["dedupe_key_sha256"] = _dedupe_hash(dedupe_key)
    lease_path = _lease_dir(farm_root) / f"{lease_id}.json"
    _atomic_write_json(lease_path, lease)
    result = {
        "registered": True,
        "lease_id": lease_id,
        "lease_path": str(lease_path),
        "pid": pid,
        "process_creation_key": lease["process_creation_key"],
        "expires_at_epoch": lease["expires_at_epoch"],
    }
    if windows_job_name:
        result["windows_job_name"] = str(windows_job_name)
    return result


def _load_lease(path: Path) -> dict[str, Any]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ManagedCodexError("lease is not a JSON object")
    required = {
        "schema_version",
        "owner",
        "lease_id",
        "pid",
        "process_creation_key",
        "expires_at_epoch",
        "purpose",
    }
    missing = sorted(required - set(raw))
    if missing:
        raise ManagedCodexError(f"lease missing fields: {', '.join(missing)}")
    if int(raw["schema_version"]) != LEASE_SCHEMA_VERSION:
        raise ManagedCodexError(f"unsupported lease schema: {raw['schema_version']!r}")
    if raw["owner"] != LEASE_OWNER:
        raise ManagedCodexError(f"foreign lease owner: {raw['owner']!r}")
    if int(raw["pid"]) <= 0:
        raise ManagedCodexError("lease PID must be positive")
    if not str(raw["process_creation_key"]):
        raise ManagedCodexError("lease creation key is empty")
    expires_at = float(raw["expires_at_epoch"])
    if not math.isfinite(expires_at):
        raise ManagedCodexError("lease expiry must be finite")
    lease_id = str(raw["lease_id"])
    if len(lease_id) != 32 or any(char not in "0123456789abcdef" for char in lease_id):
        raise ManagedCodexError("lease ID is not a lowercase UUID hex value")
    expected_name = f"{lease_id}.json"
    if path.name != expected_name and not path.name.startswith(f"{expected_name}.reaping-"):
        raise ManagedCodexError("lease ID does not match its file name")
    if os.name == "nt" and not str(raw.get("windows_job_name") or "").strip():
        raise ManagedCodexError("Windows lease is missing its Job Object name")
    return raw


def _quarantine_lease(path: Path) -> Path | None:
    quarantine = path.parent / "quarantine"
    try:
        quarantine.mkdir(parents=True, exist_ok=True)
        target = quarantine / f"{path.name}.{uuid.uuid4().hex}.invalid"
        os.replace(path, target)
        return target
    except OSError:
        return None


def _lease_files(farm_root: Path | str) -> list[Path]:
    directory = _lease_dir(farm_root)
    if not directory.exists():
        return []
    return sorted(directory.glob("*.json"), key=lambda item: item.name)


def _claim_files(farm_root: Path | str) -> list[Path]:
    directory = _lease_dir(farm_root)
    if not directory.exists():
        return []
    return sorted(directory.glob("*.json.reaping-*"), key=lambda item: item.name)


def _all_lease_files(farm_root: Path | str) -> list[Path]:
    return sorted(
        {*_lease_files(farm_root), *_claim_files(farm_root)},
        key=lambda item: item.name,
    )


def _identity_matches(lease: Mapping[str, Any], identity: Mapping[str, Any] | None) -> bool:
    return bool(
        identity
        and int(identity.get("pid", -1)) == int(lease["pid"])
        and str(identity.get("creation_key", "")) == str(lease["process_creation_key"])
    )


def _identity_is_running(identity: Mapping[str, Any] | None) -> bool:
    # Older test doubles and non-Windows identity providers may omit the field;
    # an identity returned by those providers historically meant "running".
    return bool(identity and identity.get("is_running", True))


def _stop_pid_tree(
    pid: int, expected_creation_key: str, *, windows_job_name: str | None = None
) -> dict[str, Any]:
    """Stop an owned tree without using a reusable Windows PID as kill target."""

    before = _get_process_identity(int(pid))
    if before is None or not _identity_is_running(before):
        return {"stopped": True, "reason": "already_exited", "pid": int(pid)}
    if str(before["creation_key"]) != str(expected_creation_key):
        return {"stopped": False, "reason": "identity_mismatch", "pid": int(pid)}

    if os.name == "nt":
        if not windows_job_name:
            return {
                "stopped": False,
                "reason": "ownership_job_missing",
                "pid": int(pid),
            }
        result = _terminate_windows_job(
            str(windows_job_name), expected_pid=int(pid)
        )
        result["pid"] = int(pid)
        return result
    else:
        try:
            os.kill(int(pid), signal.SIGKILL)
            result = subprocess.CompletedProcess(["kill", str(pid)], 0, "", "")
        except ProcessLookupError:
            result = subprocess.CompletedProcess(["kill", str(pid)], 0, "", "")
        except OSError as exc:
            result = subprocess.CompletedProcess(["kill", str(pid)], 1, "", repr(exc))

    deadline = time.monotonic() + 2.0
    while True:
        after = _get_process_identity(int(pid))
        original_gone = bool(
            after is None
            or str(after["creation_key"]) != str(expected_creation_key)
            or not _identity_is_running(after)
        )
        if original_gone or time.monotonic() >= deadline:
            break
        time.sleep(0.05)
    stopped = bool(original_gone)
    return {
        "stopped": stopped,
        "reason": (
            "stopped"
            if stopped and result.returncode == 0
            else "already_exited_during_stop"
            if stopped
            else "stop_failed"
        ),
        "pid": int(pid),
        "returncode": int(result.returncode),
        "stderr": (result.stderr or "").strip()[:500],
    }


def _spawn_windows_job_supervisor(
    farm_root: Path | str,
    argv: Sequence[str],
    *,
    cwd: Path | str,
    popen_kwargs: Mapping[str, Any],
) -> tuple[subprocess.Popen[Any], str]:
    """Launch the internal supervisor and wait until its Job Object is ready."""

    launch_id = uuid.uuid4().hex
    job_name = f"Global\\QMStrategyFarmCodex_{launch_id}"
    lease_dir = _lease_dir(farm_root)
    lease_dir.mkdir(parents=True, exist_ok=True)
    ready_path = lease_dir / f".launch-{launch_id}.ready"

    child_shell = bool(popen_kwargs.get("shell", False))
    child_creationflags = int(popen_kwargs.get("creationflags", 0) or 0)
    payload = {
        "argv": [str(part) for part in argv],
        "cwd": str(cwd),
        "shell": child_shell,
        "creationflags": child_creationflags,
    }
    payload_b64 = base64.urlsafe_b64encode(
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
    ).decode("ascii")
    supervisor_path = Path(__file__).with_name("managed_codex_supervisor.py")
    supervisor_command = [
        sys.executable,
        str(supervisor_path),
        "--job-name",
        job_name,
        "--ready-path",
        str(ready_path),
        "--payload-b64",
        payload_b64,
    ]
    supervisor_kwargs = dict(popen_kwargs)
    supervisor_kwargs["shell"] = False
    supervisor_kwargs["creationflags"] = child_creationflags

    proc: subprocess.Popen[Any] | None = None
    try:
        proc = subprocess.Popen(
            supervisor_command,
            cwd=str(cwd),
            **supervisor_kwargs,
        )
        deadline = time.monotonic() + 15.0
        while time.monotonic() < deadline:
            if ready_path.exists():
                ready = json.loads(ready_path.read_text(encoding="utf-8"))
                if (
                    ready.get("job_name") != job_name
                    or int(ready.get("supervisor_pid") or 0) != int(proc.pid)
                ):
                    raise ManagedCodexError("managed supervisor readiness identity mismatch")
                return proc, job_name
            returncode = proc.poll()
            if returncode is not None:
                raise ManagedCodexError(
                    f"managed supervisor exited before readiness (rc={returncode})"
                )
            time.sleep(0.025)
        raise ManagedCodexError("managed supervisor readiness timed out")
    except Exception as exc:
        cleanup = _terminate_windows_job(job_name, timeout_seconds=10.0)
        if proc is not None and not cleanup.get("stopped"):
            try:
                # Popen.kill uses the retained process HANDLE, not a reopened
                # PID, so this fallback cannot target a reused process ID.
                proc.kill()
                proc.wait(timeout=10)
            except Exception:
                pass
        if isinstance(exc, ManagedCodexError):
            raise
        raise ManagedCodexError(f"managed supervisor spawn failed: {exc!r}") from exc
    finally:
        ready_path.unlink(missing_ok=True)


def _acquire_dedupe_lock(farm_root: Path | str, dedupe_key: str) -> Path:
    directory = _lease_dir(farm_root)
    directory.mkdir(parents=True, exist_ok=True)
    key_hash = _dedupe_hash(dedupe_key)
    lock_path = directory / f".dedupe-{key_hash}.lock"
    for _attempt in range(3):
        try:
            fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            try:
                age = time.time() - lock_path.stat().st_mtime
            except OSError:
                continue
            if age < 60.0:
                raise ManagedCodexAlreadyRunning(
                    f"managed Codex launch already in progress for dedupe={key_hash[:12]}"
                )
            stale = lock_path.with_name(f"{lock_path.name}.{uuid.uuid4().hex}.stale")
            try:
                os.replace(lock_path, stale)
                stale.unlink(missing_ok=True)
            except OSError:
                continue
            continue
        try:
            os.write(
                fd,
                json.dumps(
                    {"pid": os.getpid(), "created_at_epoch": time.time()},
                    sort_keys=True,
                ).encode("utf-8"),
            )
            os.fsync(fd)
        finally:
            os.close(fd)
        return lock_path
    raise ManagedCodexAlreadyRunning(
        f"could not acquire managed Codex dedupe lock {key_hash[:12]}"
    )


def _assert_no_live_dedupe(farm_root: Path | str, dedupe_key: str) -> None:
    expected_hash = _dedupe_hash(dedupe_key)
    for path in _all_lease_files(farm_root):
        try:
            lease = _load_lease(path)
            if str(lease.get("dedupe_key_sha256") or "") != expected_hash:
                continue
            identity = _get_process_identity(int(lease["pid"]))
        except Exception:
            continue
        if _identity_matches(lease, identity) and _identity_is_running(identity):
            raise ManagedCodexAlreadyRunning(
                f"managed Codex work already running for dedupe={expected_hash[:12]} "
                f"lease={lease['lease_id']}"
            )


def spawn_managed_codex(
    farm_root: Path | str,
    argv: Sequence[str],
    *,
    purpose: str,
    cwd: Path | str,
    max_age_minutes: int,
    dedupe_key: str | None = None,
    metadata: Mapping[str, Any] | None = None,
    **popen_kwargs: Any,
) -> tuple[subprocess.Popen[Any], dict[str, Any]]:
    """Spawn Codex and fail closed if its ownership lease cannot be written."""

    proc: subprocess.Popen[Any] | None = None
    windows_job_name: str | None = None
    dedupe_lock: Path | None = None
    try:
        if dedupe_key:
            dedupe_lock = _acquire_dedupe_lock(farm_root, dedupe_key)
            _assert_no_live_dedupe(farm_root, dedupe_key)
        if os.name == "nt":
            proc, windows_job_name = _spawn_windows_job_supervisor(
                farm_root,
                argv,
                cwd=cwd,
                popen_kwargs=popen_kwargs,
            )
        else:
            proc = subprocess.Popen(list(argv), cwd=str(cwd), **popen_kwargs)
        lease = register_managed_codex_process(
            farm_root,
            proc.pid,
            purpose=purpose,
            argv=argv,
            cwd=cwd,
            max_age_minutes=max_age_minutes,
            windows_job_name=windows_job_name,
            dedupe_key=dedupe_key,
            metadata=metadata,
        )
        return proc, lease
    except Exception as exc:
        if proc is not None:
            cleanup: dict[str, Any] = {"stopped": False, "reason": "not_attempted"}
            if os.name == "nt" and windows_job_name:
                cleanup = _terminate_windows_job(windows_job_name, timeout_seconds=10.0)
            if not cleanup.get("stopped"):
                try:
                    # Exact retained HANDLE fallback; never reopen by PID.
                    proc.kill()
                    proc.wait(timeout=10)
                    cleanup = {"stopped": True, "reason": "popen_handle_kill"}
                except Exception:
                    pass
            if not cleanup.get("stopped"):
                raise ManagedCodexError(
                    f"managed Codex registration failed and cleanup was unconfirmed: "
                    f"{cleanup!r}; original_error={exc!r}"
                ) from exc
        if isinstance(exc, ManagedCodexError):
            raise
        raise ManagedCodexError(f"managed Codex spawn failed: {exc!r}") from exc
    finally:
        if dedupe_lock is not None:
            dedupe_lock.unlink(missing_ok=True)


def release_managed_codex_process(
    farm_root: Path | str, *, lease_id: str
) -> int:
    """Remove one completed lease; refuse to release a still-running owner."""

    for path in _lease_files(farm_root):
        try:
            lease = _load_lease(path)
        except Exception:
            continue
        if lease["lease_id"] != lease_id:
            continue
        try:
            identity = _get_process_identity(int(lease["pid"]))
        except Exception:
            return 0
        if _identity_matches(lease, identity) and _identity_is_running(identity):
            return 0
        try:
            path.unlink()
            return 1
        except FileNotFoundError:
            return 0
    return 0


def _restore_claim(claim_path: Path, lease: Mapping[str, Any]) -> None:
    canonical = claim_path.parent / f"{lease['lease_id']}.json"
    try:
        os.replace(claim_path, canonical)
    except OSError:
        pass


def _claim_lease(path: Path, *, now: float | None = None) -> Path | None:
    claimed_at_ns = int((time.time() if now is None else float(now)) * 1_000_000_000)
    canonical_name = path.name.split(".json", 1)[0] + ".json"
    claim = path.with_name(
        f"{canonical_name}.reaping-{claimed_at_ns}-{uuid.uuid4().hex}"
    )
    try:
        os.replace(path, claim)
        return claim
    except FileNotFoundError:
        return None
    except OSError:
        return None


def _claim_age_seconds(path: Path, now: float) -> float:
    marker = ".reaping-"
    try:
        suffix = path.name.rsplit(marker, 1)[1]
        claimed_at_ns = int(suffix.split("-", 1)[0])
        return max(0.0, float(now) - (claimed_at_ns / 1_000_000_000.0))
    except (IndexError, TypeError, ValueError):
        try:
            return max(0.0, float(now) - path.stat().st_mtime)
        except OSError:
            return 0.0


def _reaped_lease_summary(lease: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "lease_id": str(lease["lease_id"]),
        "pid": int(lease["pid"]),
        "purpose": str(lease.get("purpose") or ""),
        "metadata": _json_safe_metadata(lease.get("metadata")),
    }


def reap_managed_codex_processes(
    farm_root: Path | str, *, now: float | None = None
) -> dict[str, Any]:
    """Reap only expired, identity-matching Strategy Farm process leases."""

    now_epoch = float(time.time() if now is None else now)
    report: dict[str, Any] = {
        "reaped": 0,
        "pids": [],
        "active": 0,
        "cleaned_exited": 0,
        "pid_reused": 0,
        "invalid_leases": 0,
        "claims_in_progress": 0,
        "reaped_leases": [],
        "errors": [],
    }

    def handle_claim(claim: Path, lease: Mapping[str, Any]) -> None:
        pid = int(lease["pid"])
        try:
            current = _get_process_identity(pid)
            if current is None or not _identity_is_running(current):
                claim.unlink(missing_ok=True)
                report["cleaned_exited"] += 1
                return
            if not _identity_matches(lease, current):
                claim.unlink(missing_ok=True)
                report["pid_reused"] += 1
                return
            stopped = _stop_pid_tree(
                pid,
                str(lease["process_creation_key"]),
                windows_job_name=lease.get("windows_job_name"),
            )
            if stopped.get("stopped"):
                claim.unlink(missing_ok=True)
                report["reaped"] += 1
                report["pids"].append(pid)
                report["reaped_leases"].append(_reaped_lease_summary(lease))
            else:
                report["errors"].append(
                    {
                        "lease_id": lease["lease_id"],
                        "pid": pid,
                        "error": stopped.get("reason", "stop_failed"),
                    }
                )
                _restore_claim(claim, lease)
        except Exception as exc:
            report["errors"].append(
                {"lease_id": lease["lease_id"], "error": repr(exc)[:300]}
            )
            _restore_claim(claim, lease)

    # Canonical leases are the only normally claimable records.  A concurrent
    # terminator wins the atomic rename; this reaper then leaves its claim alone.
    for path in _lease_files(farm_root):
        try:
            lease = _load_lease(path)
        except FileNotFoundError:
            continue
        except Exception as exc:
            _quarantine_lease(path)
            report["invalid_leases"] += 1
            report["errors"].append({"lease": path.name, "error": repr(exc)[:300]})
            continue

        pid = int(lease["pid"])
        try:
            identity = _get_process_identity(pid)
        except Exception as exc:
            report["errors"].append({"lease_id": lease["lease_id"], "error": repr(exc)[:300]})
            continue

        if identity is None or not _identity_is_running(identity):
            try:
                path.unlink()
            except FileNotFoundError:
                pass
            report["cleaned_exited"] += 1
            continue
        if not _identity_matches(lease, identity):
            try:
                path.unlink()
            except FileNotFoundError:
                pass
            report["pid_reused"] += 1
            continue
        if now_epoch < float(lease["expires_at_epoch"]):
            report["active"] += 1
            continue

        claim = _claim_lease(path, now=now_epoch)
        if claim is None:
            continue
        try:
            claimed_lease = _load_lease(claim)
        except Exception as exc:
            report["errors"].append({"lease_id": lease["lease_id"], "error": repr(exc)[:300]})
            _restore_claim(claim, lease)
            continue
        handle_claim(claim, claimed_lease)

    # A claim can survive process/controller failure.  Fresh claims are an
    # active mutex and are never touched.  Only a demonstrably stale claim is
    # atomically taken over, so two recovery runs still cannot stop it twice.
    for stale_candidate in _claim_files(farm_root):
        if _claim_age_seconds(stale_candidate, now_epoch) < CLAIM_RECOVERY_SECONDS:
            report["claims_in_progress"] += 1
            continue
        recovered = _claim_lease(stale_candidate, now=now_epoch)
        if recovered is None:
            continue
        try:
            recovered_lease = _load_lease(recovered)
        except Exception as exc:
            _quarantine_lease(recovered)
            report["invalid_leases"] += 1
            report["errors"].append(
                {"lease": recovered.name, "error": repr(exc)[:300]}
            )
            continue
        handle_claim(recovered, recovered_lease)

    report["errors"] = report["errors"][:20]
    return report


def count_live_managed_codex_processes(farm_root: Path | str) -> int:
    """Count live, identity-matching leases without inspecting global Codex PIDs."""

    count = 0
    counted: set[str] = set()
    for path in _all_lease_files(farm_root):
        try:
            lease = _load_lease(path)
            if str(lease["lease_id"]) in counted:
                continue
            identity = _get_process_identity(int(lease["pid"]))
        except Exception:
            continue
        if _identity_matches(lease, identity) and _identity_is_running(identity):
            count += 1
            counted.add(str(lease["lease_id"]))
    return count


def list_live_managed_codex_processes(
    farm_root: Path | str, *, purpose: str | None = None
) -> list[dict[str, Any]]:
    """List identity-validated leases, optionally restricted to one purpose."""

    live: list[dict[str, Any]] = []
    seen: set[str] = set()
    for path in _all_lease_files(farm_root):
        try:
            lease = _load_lease(path)
            lease_id = str(lease["lease_id"])
            if lease_id in seen:
                continue
            if purpose is not None and str(lease.get("purpose") or "") != purpose:
                continue
            identity = _get_process_identity(int(lease["pid"]))
        except Exception:
            continue
        if not (_identity_matches(lease, identity) and _identity_is_running(identity)):
            continue
        seen.add(lease_id)
        live.append(
            {
                "lease_id": lease_id,
                "pid": int(lease["pid"]),
                "purpose": str(lease.get("purpose") or ""),
                "metadata": _json_safe_metadata(lease.get("metadata")),
                "expires_at_epoch": float(lease["expires_at_epoch"]),
            }
        )
    return live


def is_managed_codex_pid_live(farm_root: Path | str, pid: int) -> bool:
    """Return true only when PID and creation identity match a farm lease."""

    for path in _all_lease_files(farm_root):
        try:
            lease = _load_lease(path)
            if int(lease["pid"]) != int(pid):
                continue
            identity = _get_process_identity(int(pid))
        except Exception:
            continue
        if _identity_matches(lease, identity) and _identity_is_running(identity):
            return True
    return False


def terminate_managed_codex_pid(farm_root: Path | str, pid: int) -> dict[str, Any]:
    """Stop a live farm-owned PID; never fall back to a global process search."""

    for path in _lease_files(farm_root):
        try:
            lease = _load_lease(path)
        except Exception:
            continue
        if int(lease["pid"]) != int(pid):
            continue
        claim = _claim_lease(path)
        if claim is None:
            continue
        try:
            current = _get_process_identity(int(pid))
            if current is None or not _identity_is_running(current):
                claim.unlink(missing_ok=True)
                return {"stopped": True, "reason": "already_exited", "pid": int(pid)}
            if not _identity_matches(lease, current):
                claim.unlink(missing_ok=True)
                return {"stopped": False, "reason": "identity_mismatch", "pid": int(pid)}
            result = _stop_pid_tree(
                int(pid),
                str(lease["process_creation_key"]),
                windows_job_name=lease.get("windows_job_name"),
            )
            if result.get("stopped"):
                claim.unlink(missing_ok=True)
            else:
                _restore_claim(claim, lease)
            return result
        except Exception as exc:
            _restore_claim(claim, lease)
            return {"stopped": False, "reason": repr(exc), "pid": int(pid)}
    for claim in _claim_files(farm_root):
        try:
            lease = _load_lease(claim)
        except Exception:
            continue
        if int(lease["pid"]) == int(pid):
            return {"stopped": False, "reason": "stop_in_progress", "pid": int(pid)}
    return {"stopped": False, "reason": "not_managed", "pid": int(pid)}
