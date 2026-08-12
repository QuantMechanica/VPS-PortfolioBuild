"""Exact, read-only process identity queries.

Windows reuses process IDs.  A PID stored in SQLite therefore proves nothing
about the process currently occupying that number.  This module binds liveness
checks to the operating system's immutable creation identity and never sends a
signal or terminates a process.
"""

from __future__ import annotations

import ctypes
import os
from ctypes import wintypes
from pathlib import Path
from typing import Any


_WINDOWS_FILETIME_UNIX_EPOCH = 116_444_736_000_000_000
_WINDOWS_TICKS_PER_SECOND = 10_000_000
_STILL_ACTIVE = 259


class ProcessIdentityError(RuntimeError):
    """The operating system could not establish an exact process identity."""


def _windows_kernel32() -> Any:
    return ctypes.WinDLL("kernel32", use_last_error=True)


def _windows_identity_from_handle(
    kernel32: Any, handle: int, pid: int
) -> dict[str, Any]:
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
        raise OSError(ctypes.get_last_error(), f"GetProcessTimes({pid}) failed")

    creation_ticks = (int(created.dwHighDateTime) << 32) | int(created.dwLowDateTime)
    started_at = (
        creation_ticks - _WINDOWS_FILETIME_UNIX_EPOCH
    ) / _WINDOWS_TICKS_PER_SECOND
    exit_code = wintypes.DWORD()
    if not kernel32.GetExitCodeProcess(handle, ctypes.byref(exit_code)):
        raise OSError(ctypes.get_last_error(), f"GetExitCodeProcess({pid}) failed")

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
        "is_running": int(exit_code.value) == _STILL_ACTIVE,
    }


def _configure_windows_process_api(kernel32: Any) -> None:
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


def _get_windows_process_identity(pid: int) -> dict[str, Any] | None:
    process_query_limited_information = 0x1000
    kernel32 = _windows_kernel32()
    _configure_windows_process_api(kernel32)
    handle = kernel32.OpenProcess(process_query_limited_information, False, int(pid))
    if not handle:
        error = ctypes.get_last_error()
        if error in (6, 87):  # ERROR_INVALID_HANDLE / ERROR_INVALID_PARAMETER
            return None
        raise OSError(error, f"OpenProcess({pid}) failed")
    try:
        return _windows_identity_from_handle(kernel32, handle, int(pid))
    finally:
        kernel32.CloseHandle(handle)


def _get_posix_process_identity(pid: int) -> dict[str, Any] | None:
    proc_dir = Path("/proc") / str(int(pid))
    try:
        raw = (proc_dir / "stat").read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    closing_paren = raw.rfind(")")
    fields = raw[closing_paren + 2 :].split() if closing_paren >= 0 else []
    if len(fields) <= 19:
        raise ProcessIdentityError(f"unexpected /proc stat format for PID {pid}")
    start_ticks = int(fields[19])
    boot_epoch = None
    for line in Path("/proc/stat").read_text(encoding="utf-8").splitlines():
        if line.startswith("btime "):
            boot_epoch = float(line.split()[1])
            break
    if boot_epoch is None:
        raise ProcessIdentityError("cannot determine /proc boot time")
    image_path = ""
    try:
        image_path = os.readlink(proc_dir / "exe")
    except OSError:
        pass
    return {
        "pid": int(pid),
        "creation_key": f"proc-start-ticks:{start_ticks}",
        "started_at_epoch": boot_epoch + (start_ticks / int(os.sysconf("SC_CLK_TCK"))),
        "image_path": image_path,
        "is_running": fields[0] != "Z",
    }


def get_process_identity(pid: int) -> dict[str, Any] | None:
    """Return the immutable creation identity for a live or exited PID."""

    pid = int(pid)
    if pid <= 0:
        return None
    if os.name == "nt":
        return _get_windows_process_identity(pid)
    return _get_posix_process_identity(pid)


def process_identity_matches(pid: int, expected_creation_key: str) -> bool:
    """Return true only for a running process with the exact expected identity."""

    if not str(expected_creation_key or ""):
        return False
    identity = get_process_identity(int(pid))
    return bool(
        identity
        and identity.get("is_running", True)
        and str(identity.get("creation_key") or "") == str(expected_creation_key)
    )
