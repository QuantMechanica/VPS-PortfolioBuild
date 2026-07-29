"""Cross-process lock for every Strategy Farm state mutation.

The lock file is intentionally shared with ``Factory_OFF.ps1`` and
``Factory_ON.ps1``.  Acquisition is an atomic create-new operation; an existing
file is fail-closed and is never stolen here.  Factory OFF owns stale-owner
inspection because it can also drain the associated scheduled tasks/processes.
"""

from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path
import uuid

if os.name == "nt":
    import ctypes
    from ctypes import wintypes
    import msvcrt

    _KERNEL32 = ctypes.WinDLL("kernel32", use_last_error=True)


DEFAULT_PATH = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")


def _open_exclusive_lock(path: Path) -> int:
    """Create a lock whose Windows handle can delete only its own file object."""

    if os.name != "nt":
        return os.open(path, os.O_CREAT | os.O_EXCL | os.O_RDWR, 0o600)

    create_file = _KERNEL32.CreateFileW
    create_file.argtypes = (
        wintypes.LPCWSTR,
        wintypes.DWORD,
        wintypes.DWORD,
        wintypes.LPVOID,
        wintypes.DWORD,
        wintypes.DWORD,
        wintypes.HANDLE,
    )
    create_file.restype = wintypes.HANDLE
    generic_read = 0x80000000
    generic_write = 0x40000000
    delete_access = 0x00010000
    create_new = 1
    file_attribute_normal = 0x00000080
    handle = create_file(
        str(path),
        generic_read | generic_write | delete_access,
        0,  # no sharing: the open file identity cannot be replaced
        None,
        create_new,
        file_attribute_normal,
        None,
    )
    invalid_handle = ctypes.c_void_p(-1).value
    if handle == invalid_handle:
        error = ctypes.get_last_error()
        if error in {80, 183}:  # ERROR_FILE_EXISTS / ERROR_ALREADY_EXISTS
            raise FileExistsError(error, os.strerror(error), str(path))
        raise OSError(error, os.strerror(error), str(path))
    try:
        return msvcrt.open_osfhandle(
            int(handle),
            os.O_RDWR | getattr(os, "O_BINARY", 0),
        )
    except BaseException:
        _KERNEL32.CloseHandle(handle)
        raise


def _read_open_descriptor(descriptor: int, maximum: int) -> bytes:
    os.lseek(descriptor, 0, os.SEEK_SET)
    chunks: list[bytes] = []
    remaining = maximum
    while remaining > 0:
        chunk = os.read(descriptor, remaining)
        if not chunk:
            break
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def _mark_windows_file_for_delete(descriptor: int) -> bool:
    class FileDispositionInfo(ctypes.Structure):
        _fields_ = [("delete_file", wintypes.BOOL)]

    set_information = _KERNEL32.SetFileInformationByHandle
    set_information.argtypes = (
        wintypes.HANDLE,
        ctypes.c_int,
        wintypes.LPVOID,
        wintypes.DWORD,
    )
    set_information.restype = wintypes.BOOL
    disposition = FileDispositionInfo(True)
    return bool(
        set_information(
            msvcrt.get_osfhandle(descriptor),
            4,  # FILE_INFO_BY_HANDLE_CLASS.FileDispositionInfo
            ctypes.byref(disposition),
            ctypes.sizeof(disposition),
        )
    )


class FactoryMutationLock:
    """Hold the global mutation boundary until the guarded operation finishes."""

    def __init__(self, path: Path = DEFAULT_PATH, *, owner: str) -> None:
        self.path = Path(path)
        self.owner = str(owner)
        if not self.owner.strip():
            raise ValueError("factory mutation lock owner must be non-empty")
        self.nonce = uuid.uuid4().hex
        self._fd: int | None = None
        self._record_bytes: bytes | None = None
        self.release_status: str | None = None

    @property
    def release_succeeded(self) -> bool:
        """Whether this instance left no lock record that it could still own."""

        return self.release_status in {"released", "already_absent"}

    def __enter__(self) -> "FactoryMutationLock":
        self.path.parent.mkdir(parents=True, exist_ok=True)
        try:
            self._fd = _open_exclusive_lock(self.path)
        except FileExistsError as exc:
            raise RuntimeError(f"factory mutation lock is busy: {self.path}") from exc
        record = {
            "pid": os.getpid(),
            "owner": self.owner,
            "nonce": self.nonce,
            "created_at": dt.datetime.now(dt.UTC).isoformat(),
        }
        self._record_bytes = (json.dumps(record, sort_keys=True) + "\n").encode("utf-8")
        try:
            view = memoryview(self._record_bytes)
            while view:
                written = os.write(self._fd, view)
                if written <= 0:
                    raise OSError("factory mutation lock write made no progress")
                view = view[written:]
            os.fsync(self._fd)
        except BaseException:
            self.release_status = self._release_owned_open_file()
            os.close(self._fd)
            self._fd = None
            if self.release_status == "delete_pending":
                self.release_status = "released"
            raise
        return self

    def __exit__(self, exc_type, exc, traceback) -> None:
        if self._fd is not None:
            self.release_status = self._release_owned_open_file()
            try:
                os.close(self._fd)
            except OSError:
                self.release_status = "close_failed"
            self._fd = None
            if self.release_status == "delete_pending":
                self.release_status = "released"
        else:
            self.release_status = self._unlink_if_owned()

        # Never raise a new error after a guarded database transaction may have
        # committed: callers could misread that as a retryable mutation failure
        # and apply the operation twice. The status remains explicit while any
        # changed/unreadable record is retained fail-closed.

    def _release_owned_open_file(self) -> str:
        """Delete the exact still-open file object when its bytes still match."""

        if self._fd is None or self._record_bytes is None:
            return "identity_unavailable"
        try:
            actual = _read_open_descriptor(self._fd, len(self._record_bytes) + 1)
        except OSError:
            return "unreadable"
        if actual != self._record_bytes:
            return "ownership_changed"

        if os.name == "nt":
            try:
                return (
                    "delete_pending"
                    if _mark_windows_file_for_delete(self._fd)
                    else "unlink_failed"
                )
            except OSError:
                return "unlink_failed"

        try:
            descriptor_stat = os.fstat(self._fd)
            path_stat = self.path.stat(follow_symlinks=False)
            if (
                descriptor_stat.st_dev != path_stat.st_dev
                or descriptor_stat.st_ino != path_stat.st_ino
            ):
                return "ownership_changed"
            self.path.unlink()
        except FileNotFoundError:
            return "already_absent"
        except OSError:
            return "unlink_failed"
        return "released"

    def _unlink_if_owned(self) -> str:
        """Release only the exact nonce-bound record created by this instance.

        The content comparison prevents an old context manager from unlinking a
        replacement lock.  A mismatch or unreadable path is deliberately kept
        fail-closed for Factory OFF / OWNER inspection.
        """

        expected = self._record_bytes
        if expected is None:
            return "already_absent" if not self.path.exists() else "identity_unavailable"
        try:
            actual = self.path.read_bytes()
        except FileNotFoundError:
            return "already_absent"
        except OSError:
            return "unreadable"
        if actual != expected:
            return "ownership_changed"
        try:
            self.path.unlink()
        except FileNotFoundError:
            return "already_absent"
        except OSError:
            return "unlink_failed"
        return "released"


def path_for_factory_flag(factory_off_flag: Path) -> Path:
    return Path(factory_off_flag).with_name("FACTORY_MUTATION.lock")
