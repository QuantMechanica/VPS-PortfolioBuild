"""Fail-closed Windows Job Object containment for spawned runner processes.

Windows runner processes must be created suspended. They are assigned through
their retained ``subprocess.Popen`` process handle, identity-bound, retained in
the Job registry, and only then resumed. The Job Object uses
``JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`` and its handle is retained in a registry
keyed by ``(pid, creation_identity)`` for the lifetime of the complete process
tree. A daemon observer notes root termination, but the handle closes only when
read-only Job accounting reports ``ActiveProcesses == 0``; the registry also
exposes deterministic polling for callers and tests.

On non-Windows platforms the binding is an explicit metadata-bearing no-op.
No Windows API is imported or invoked there.
"""

from __future__ import annotations

import ctypes
import os
import subprocess
import sys
import threading
from ctypes import wintypes
from dataclasses import dataclass
from typing import Any, Callable, Mapping, Protocol


JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000
JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION_CLASS = 1
JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS = 9
WINDOWS_CREATE_SUSPENDED = 0x00000004
WINDOWS_CREATE_NO_WINDOW = 0x08000000
TH32CS_SNAPTHREAD = 0x00000004
THREAD_SUSPEND_RESUME = 0x0002
THREAD_QUERY_LIMITED_INFORMATION = 0x0800
ERROR_NO_MORE_FILES = 18
DWORD_FAILURE = 0xFFFFFFFF


class JobObjectError(RuntimeError):
    """A spawned process could not be safely contained in a Windows job."""


class _IO_COUNTERS(ctypes.Structure):
    _fields_ = [
        ("ReadOperationCount", ctypes.c_ulonglong),
        ("WriteOperationCount", ctypes.c_ulonglong),
        ("OtherOperationCount", ctypes.c_ulonglong),
        ("ReadTransferCount", ctypes.c_ulonglong),
        ("WriteTransferCount", ctypes.c_ulonglong),
        ("OtherTransferCount", ctypes.c_ulonglong),
    ]


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


class _JOBOBJECT_BASIC_ACCOUNTING_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("TotalUserTime", ctypes.c_longlong),
        ("TotalKernelTime", ctypes.c_longlong),
        ("ThisPeriodTotalUserTime", ctypes.c_longlong),
        ("ThisPeriodTotalKernelTime", ctypes.c_longlong),
        ("TotalPageFaultCount", wintypes.DWORD),
        ("TotalProcesses", wintypes.DWORD),
        ("ActiveProcesses", wintypes.DWORD),
        ("TotalTerminatedProcesses", wintypes.DWORD),
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


class _THREADENTRY32(ctypes.Structure):
    _fields_ = [
        ("dwSize", wintypes.DWORD),
        ("cntUsage", wintypes.DWORD),
        ("th32ThreadID", wintypes.DWORD),
        ("th32OwnerProcessID", wintypes.DWORD),
        ("tpBasePri", wintypes.LONG),
        ("tpDeltaPri", wintypes.LONG),
        ("dwFlags", wintypes.DWORD),
    ]


class JobApi(Protocol):
    """Small WinAPI boundary used by production ctypes and deterministic tests."""

    def create_kill_on_close_job(self) -> int:
        ...

    def assign_process(self, job_handle: int, process_handle: int) -> None:
        ...

    def resume_primary_thread(self, process_handle: int, process_id: int) -> None:
        ...

    def active_process_count(self, job_handle: int) -> int:
        ...

    def close_handle(self, handle: int) -> None:
        ...


class CtypesWindowsJobApi:
    """ctypes implementation of the WinAPI calls needed by the contract."""

    def __init__(self, kernel32: Any | None = None) -> None:
        if os.name != "nt" and kernel32 is None:
            raise JobObjectError("Windows Job Objects are unavailable on this platform")
        if kernel32 is None:
            kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)  # type: ignore[attr-defined]
        self._kernel32 = kernel32
        self._configure_signatures()

    def _configure_signatures(self) -> None:
        # Test doubles may expose plain callables without writable ctypes
        # signature attributes; those doubles already define their own ABI.
        signatures = (
            (
                "CreateJobObjectW",
                [ctypes.c_void_p, wintypes.LPCWSTR],
                wintypes.HANDLE,
            ),
            (
                "SetInformationJobObject",
                [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD],
                wintypes.BOOL,
            ),
            (
                "AssignProcessToJobObject",
                [wintypes.HANDLE, wintypes.HANDLE],
                wintypes.BOOL,
            ),
            (
                "QueryInformationJobObject",
                [
                    wintypes.HANDLE,
                    ctypes.c_int,
                    ctypes.c_void_p,
                    wintypes.DWORD,
                    ctypes.POINTER(wintypes.DWORD),
                ],
                wintypes.BOOL,
            ),
            (
                "CreateToolhelp32Snapshot",
                [wintypes.DWORD, wintypes.DWORD],
                wintypes.HANDLE,
            ),
            (
                "Thread32First",
                [wintypes.HANDLE, ctypes.POINTER(_THREADENTRY32)],
                wintypes.BOOL,
            ),
            (
                "Thread32Next",
                [wintypes.HANDLE, ctypes.POINTER(_THREADENTRY32)],
                wintypes.BOOL,
            ),
            (
                "OpenThread",
                [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD],
                wintypes.HANDLE,
            ),
            ("ResumeThread", [wintypes.HANDLE], wintypes.DWORD),
            ("GetProcessId", [wintypes.HANDLE], wintypes.DWORD),
            ("CloseHandle", [wintypes.HANDLE], wintypes.BOOL),
        )
        for name, argtypes, restype in signatures:
            function = getattr(self._kernel32, name)
            try:
                function.argtypes = argtypes
                function.restype = restype
            except (AttributeError, TypeError):
                continue

    @staticmethod
    def _last_error(action: str, code: int | None = None) -> JobObjectError:
        get_last_error = getattr(ctypes, "get_last_error", lambda: 0)
        code = get_last_error() if code is None else int(code)
        if code:
            win_error = getattr(ctypes, "WinError", lambda value: OSError(value))
            return JobObjectError(f"{action} failed: winerror={code}: {win_error(code)}")
        return JobObjectError(f"{action} failed without a Windows error code")

    @staticmethod
    def _clear_last_error() -> None:
        set_last_error = getattr(ctypes, "set_last_error", None)
        if set_last_error is not None:
            set_last_error(0)

    def create_kill_on_close_job(self) -> int:
        raw_handle = self._kernel32.CreateJobObjectW(None, None)
        handle = int(raw_handle or 0)
        if not handle:
            raise self._last_error("CreateJobObjectW")
        info = _JOBOBJECT_EXTENDED_LIMIT_INFORMATION()
        info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        ok = self._kernel32.SetInformationJobObject(
            handle,
            JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS,
            ctypes.byref(info),
            ctypes.sizeof(info),
        )
        if not ok:
            error_code = ctypes.get_last_error()
            try:
                self.close_handle(handle)
            finally:
                raise self._last_error(
                    "SetInformationJobObject(KILL_ON_JOB_CLOSE)", error_code
                )
        return handle

    def assign_process(self, job_handle: int, process_handle: int) -> None:
        if not self._kernel32.AssignProcessToJobObject(job_handle, process_handle):
            raise self._last_error("AssignProcessToJobObject")

    def resume_primary_thread(self, process_handle: int, process_id: int) -> None:
        """Resume the sole thread of an exact CREATE_SUSPENDED process.

        CPython closes the thread handle returned by ``CreateProcess`` before
        ``Popen`` returns. A suspended process cannot create another thread, so
        enumerating the exact retained process PID must yield exactly one thread.
        PID reuse is excluded by cross-checking the still-open process handle.
        """

        expected_pid = int(process_id)
        handle_pid = int(self._kernel32.GetProcessId(process_handle) or 0)
        if handle_pid <= 0:
            raise self._last_error("GetProcessId")
        if handle_pid != expected_pid:
            raise JobObjectError(
                f"retained process handle PID mismatch: {handle_pid} != {expected_pid}"
            )

        raw_snapshot = self._kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0)
        snapshot = int(raw_snapshot or 0)
        invalid_handle = int(ctypes.c_void_p(-1).value or DWORD_FAILURE)
        if not snapshot or snapshot == invalid_handle:
            raise self._last_error("CreateToolhelp32Snapshot(THREAD)")

        thread_ids: list[int] = []
        enumeration_error: JobObjectError | None = None
        try:
            entry = _THREADENTRY32()
            entry.dwSize = ctypes.sizeof(entry)
            self._clear_last_error()
            has_entry = bool(self._kernel32.Thread32First(snapshot, ctypes.byref(entry)))
            if not has_entry:
                enumeration_error = self._last_error("Thread32First")
            else:
                while True:
                    if int(entry.th32OwnerProcessID) == expected_pid:
                        thread_ids.append(int(entry.th32ThreadID))
                    entry.dwSize = ctypes.sizeof(entry)
                    self._clear_last_error()
                    if self._kernel32.Thread32Next(snapshot, ctypes.byref(entry)):
                        continue
                    get_last_error = getattr(ctypes, "get_last_error", lambda: 0)
                    error_code = int(get_last_error())
                    if error_code not in {0, ERROR_NO_MORE_FILES}:
                        enumeration_error = self._last_error("Thread32Next", error_code)
                    break
        finally:
            try:
                self.close_handle(snapshot)
            except JobObjectError as exc:
                if enumeration_error is None:
                    enumeration_error = exc
        if enumeration_error is not None:
            raise enumeration_error
        if len(thread_ids) != 1:
            raise JobObjectError(
                "CREATE_SUSPENDED process must expose exactly one primary thread; "
                f"pid={expected_pid}, threads={thread_ids}"
            )

        raw_thread = self._kernel32.OpenThread(
            THREAD_SUSPEND_RESUME | THREAD_QUERY_LIMITED_INFORMATION,
            False,
            thread_ids[0],
        )
        thread_handle = int(raw_thread or 0)
        if not thread_handle:
            raise self._last_error("OpenThread(primary)")
        resume_error: JobObjectError | None = None
        try:
            prior_suspend_count = int(self._kernel32.ResumeThread(thread_handle))
            if prior_suspend_count == DWORD_FAILURE:
                resume_error = self._last_error("ResumeThread(primary)")
            elif prior_suspend_count != 1:
                resume_error = JobObjectError(
                    "primary thread was not suspended exactly once; "
                    f"pid={expected_pid}, prior_suspend_count={prior_suspend_count}"
                )
        finally:
            try:
                self.close_handle(thread_handle)
            except JobObjectError as exc:
                if resume_error is None:
                    resume_error = exc
        if resume_error is not None:
            raise resume_error

    def active_process_count(self, job_handle: int) -> int:
        """Return the number of processes still alive anywhere in the job."""

        info = _JOBOBJECT_BASIC_ACCOUNTING_INFORMATION()
        returned_length = wintypes.DWORD(0)
        ok = self._kernel32.QueryInformationJobObject(
            job_handle,
            JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION_CLASS,
            ctypes.byref(info),
            ctypes.sizeof(info),
            ctypes.byref(returned_length),
        )
        if not ok:
            raise self._last_error("QueryInformationJobObject(BasicAccounting)")
        return int(info.ActiveProcesses)

    def close_handle(self, handle: int) -> None:
        if handle and not self._kernel32.CloseHandle(handle):
            raise self._last_error("CloseHandle")


@dataclass
class _RetainedJob:
    pid: int
    creation_key: str
    process: subprocess.Popen[Any]
    job_handle: int
    api: JobApi

    @property
    def key(self) -> tuple[int, str]:
        return (self.pid, self.creation_key)


class JobObjectRegistry:
    """Own Job handles until the exact spawned process is observed stopped."""

    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._jobs: dict[tuple[int, str], _RetainedJob] = {}

    def retain(
        self,
        *,
        process: subprocess.Popen[Any],
        creation_key: str,
        job_handle: int,
        api: JobApi,
        start_observer: bool = True,
    ) -> str:
        pid = int(process.pid)
        if pid <= 0 or not creation_key:
            raise JobObjectError("registry requires positive PID and creation identity")
        record = _RetainedJob(pid, creation_key, process, int(job_handle), api)
        with self._lock:
            if record.key in self._jobs:
                raise JobObjectError(
                    f"duplicate Job Object registry identity: {pid}/{creation_key}"
                )
            self._jobs[record.key] = record
        if start_observer:
            try:
                watcher = threading.Thread(
                    target=self._observe_process_end,
                    args=(record.key,),
                    name=f"qm-job-{pid}",
                    daemon=True,
                )
                watcher.start()
            except Exception:
                with self._lock:
                    self._jobs.pop(record.key, None)
                raise
        return registry_key(pid, creation_key)

    def _observe_process_end(self, key: tuple[int, str]) -> None:
        with self._lock:
            record = self._jobs.get(key)
        if record is None:
            return
        try:
            record.process.wait()
        except Exception:
            # Unknown status is not an observed process end. Retain containment;
            # a later explicit reap can safely retry through Popen.poll().
            return
        try:
            self.release_observed(*key)
        except JobObjectError:
            # The record is restored by release_observed so an explicit reap
            # can retry; daemon observers must not emit an unhandled traceback.
            return

    def release_observed(self, pid: int, creation_key: str) -> bool:
        """Close only after root end *and* zero active processes in the job.

        A short-lived phase driver can exit while its run_smoke/MT5 descendants
        continue. Closing a KILL_ON_JOB_CLOSE handle at root exit would kill
        those legitimate descendants, so job accounting is the authoritative
        tree-lifetime check. Query failure retains containment and raises.
        """

        key = (int(pid), str(creation_key))
        with self._lock:
            record = self._jobs.get(key)
        if record is None:
            return False
        try:
            ended = record.process.poll() is not None
        except Exception:
            ended = False
        if not ended:
            return False
        try:
            active_processes = record.api.active_process_count(record.job_handle)
        except Exception as exc:
            raise JobObjectError(
                f"failed to query active processes for {registry_key(*key)}: {exc}"
            ) from exc
        if active_processes < 0:
            raise JobObjectError(
                f"invalid negative active-process count for {registry_key(*key)}"
            )
        if active_processes != 0:
            return False
        with self._lock:
            # Exact-key CAS: another observer may have completed the close.
            if self._jobs.get(key) is not record:
                return False
            self._jobs.pop(key)
        try:
            record.api.close_handle(record.job_handle)
        except Exception as exc:
            with self._lock:
                self._jobs.setdefault(key, record)
            # The process is already observed ended; containment succeeded. A
            # close failure is still surfaced to explicit callers/tests.
            raise JobObjectError(
                f"failed to close observed Job Object {registry_key(*key)}: {exc}"
            ) from exc
        return True

    def reap_finished(self) -> int:
        """Poll retained Popen handles and close jobs whose root has ended."""

        with self._lock:
            records = list(self._jobs.values())
        ended: list[tuple[int, str]] = []
        for record in records:
            try:
                if record.process.poll() is not None:
                    ended.append(record.key)
            except Exception:
                continue
        count = 0
        for key in ended:
            if self.release_observed(*key):
                count += 1
        return count

    def active_keys(self) -> tuple[str, ...]:
        with self._lock:
            return tuple(registry_key(*key) for key in sorted(self._jobs))

    def abort_retained(self, pid: int, creation_key: str) -> bool:
        """Close one exact retained Job immediately, killing its process tree."""

        key = (int(pid), str(creation_key))
        with self._lock:
            record = self._jobs.get(key)
            if record is None:
                return False
            self._jobs.pop(key)
        try:
            record.api.close_handle(record.job_handle)
        except Exception as exc:
            with self._lock:
                self._jobs.setdefault(key, record)
            raise JobObjectError(
                f"failed to abort retained Job Object {registry_key(*key)}: {exc}"
            ) from exc
        return True

    def discard_for_test(self) -> None:
        """Close all retained mock handles; intended only for isolated tests."""

        with self._lock:
            records = list(self._jobs.values())
            self._jobs.clear()
        for record in records:
            record.api.close_handle(record.job_handle)


GLOBAL_JOB_REGISTRY = JobObjectRegistry()


def registry_key(pid: int, creation_key: str) -> str:
    return f"{int(pid)}|{creation_key}"


def suspended_runner_creation_flags(*, platform: str | None = None) -> int:
    """Return flags that guarantee no Windows runner instruction executes early."""

    current_platform = platform if platform is not None else sys.platform
    if current_platform != "win32":
        return 0
    return int(getattr(subprocess, "CREATE_NO_WINDOW", WINDOWS_CREATE_NO_WINDOW)) | int(
        getattr(subprocess, "CREATE_SUSPENDED", WINDOWS_CREATE_SUSPENDED)
    )


def _retained_process_handle(process: subprocess.Popen[Any]) -> int:
    raw = getattr(process, "_handle", None)
    try:
        handle = int(raw)
    except (TypeError, ValueError, OSError) as exc:
        raise JobObjectError("spawned Windows Popen has no usable retained process handle") from exc
    if handle <= 0:
        raise JobObjectError("spawned Windows Popen retained process handle is invalid")
    return handle


def _kill_and_wait_retained(process: subprocess.Popen[Any]) -> None:
    """Best-effort termination using only the retained Popen process handle."""

    try:
        process.kill()
    except Exception:
        pass
    try:
        process.wait(timeout=10)
    except Exception:
        pass


def bind_spawned_process_to_kill_job(
    process: subprocess.Popen[Any],
    capture_identity: Callable[[subprocess.Popen[Any]], Mapping[str, Any]],
    *,
    platform: str | None = None,
    api: JobApi | None = None,
    registry: JobObjectRegistry = GLOBAL_JOB_REGISTRY,
    start_observer: bool = True,
    process_created_suspended: bool = False,
) -> dict[str, Any]:
    """Contain, identity-bind, retain, and resume a just-spawned runner.

    Windows callers must have used :func:`suspended_runner_creation_flags`.
    Assignment and identity capture therefore happen before the child can run
    or spawn descendants. Any assignment, identity, registry, or resume failure
    closes the Job handle and calls ``kill``/``wait`` on the original Popen.
    """

    current_platform = platform if platform is not None else sys.platform
    if current_platform != "win32":
        identity = dict(capture_identity(process))
        return {
            **identity,
            "job_object_assigned": False,
            "job_object_mode": "NON_WINDOWS_NOOP",
            "job_object_registry_key": None,
            "process_started_suspended": False,
            "primary_thread_resumed": False,
        }

    if not process_created_suspended:
        _kill_and_wait_retained(process)
        raise JobObjectError(
            "Windows runner containment requires CREATE_SUSPENDED at Popen"
        )

    selected_api = api or CtypesWindowsJobApi()
    job_handle: int | None = None
    retained = False
    creation_key = ""
    try:
        # The process handle came from this exact Popen creation. No PID reopen
        # or name matching is permitted between spawn and assignment.
        process_handle = _retained_process_handle(process)
        job_handle = selected_api.create_kill_on_close_job()
        selected_api.assign_process(job_handle, process_handle)
        identity = dict(capture_identity(process))
        creation_key = str(identity.get("process_creation_key") or "")
        if not creation_key:
            raise JobObjectError("identity capture did not return process_creation_key")
        key = registry.retain(
            process=process,
            creation_key=creation_key,
            job_handle=job_handle,
            api=selected_api,
            start_observer=start_observer,
        )
        retained = True
        selected_api.resume_primary_thread(process_handle, int(process.pid))
        return {
            **identity,
            "job_object_assigned": True,
            "job_object_mode": "KILL_ON_JOB_CLOSE",
            "job_object_registry_key": key,
            "process_started_suspended": True,
            "primary_thread_resumed": True,
        }
    except Exception as exc:
        if retained:
            try:
                registry.abort_retained(int(process.pid), creation_key)
            except Exception:
                # Keep the exact registry record if CloseHandle failed; the
                # retained handle remains the fail-closed containment owner.
                pass
        elif job_handle is not None:
            try:
                selected_api.close_handle(job_handle)
            except Exception:
                pass
        _kill_and_wait_retained(process)
        if isinstance(exc, JobObjectError):
            raise
        raise JobObjectError(f"failed to contain spawned process {getattr(process, 'pid', '?')}: {exc}") from exc


def reap_finished_job_objects(
    *, registry: JobObjectRegistry = GLOBAL_JOB_REGISTRY, platform: str | None = None
) -> int:
    """Close Job handles for runner roots observed ended; non-Windows is no-op."""

    current_platform = platform if platform is not None else sys.platform
    if current_platform != "win32":
        return 0
    return registry.reap_finished()


__all__ = [
    "CtypesWindowsJobApi",
    "GLOBAL_JOB_REGISTRY",
    "JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION_CLASS",
    "JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE",
    "JobObjectError",
    "JobObjectRegistry",
    "WINDOWS_CREATE_NO_WINDOW",
    "WINDOWS_CREATE_SUSPENDED",
    "bind_spawned_process_to_kill_job",
    "reap_finished_job_objects",
    "registry_key",
    "suspended_runner_creation_flags",
]
