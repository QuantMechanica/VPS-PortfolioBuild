"""Cross-process lock for every Strategy Farm state mutation.

The lock file is intentionally shared with ``Factory_OFF.ps1`` and
``Factory_ON.ps1``. Acquisition is an atomic create-new operation. A readable,
old record whose original PID is provably dead may be reaped with a byte-for-byte
identity check; every other existing record remains fail-closed.
"""

from __future__ import annotations

import datetime as dt
import hashlib
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
DEFAULT_REAP_EVIDENCE_PATH = Path(
    r"D:\QM\reports\state\mutation_lock_reaps.jsonl"
)
DEFAULT_STALE_REAP_SECONDS = 120.0
MAX_RECORD_BYTES = 64 * 1024
FUTURE_CLOCK_TOLERANCE_SECONDS = 5.0
PID_START_TOLERANCE_SECONDS = 1.0


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


def _open_existing_exclusive_for_delete(path: Path) -> int:
    """Open an existing Windows lock with no sharing for a content-CAS delete."""

    if os.name != "nt":
        raise OSError("identity-safe stale reap is supported only on Windows")

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
    delete_access = 0x00010000
    open_existing = 3
    file_attribute_normal = 0x00000080
    handle = create_file(
        str(path),
        generic_read | delete_access,
        0,  # a live owner holds the file with no sharing, so this must fail
        None,
        open_existing,
        file_attribute_normal,
        None,
    )
    invalid_handle = ctypes.c_void_p(-1).value
    if handle == invalid_handle:
        error = ctypes.get_last_error()
        if error in {2, 3}:  # ERROR_FILE_NOT_FOUND / ERROR_PATH_NOT_FOUND
            raise FileNotFoundError(error, os.strerror(error), str(path))
        raise OSError(error, os.strerror(error), str(path))
    try:
        return msvcrt.open_osfhandle(
            int(handle),
            os.O_RDONLY | getattr(os, "O_BINARY", 0),
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


def _write_all(descriptor: int, payload: bytes) -> None:
    view = memoryview(payload)
    while view:
        written = os.write(descriptor, view)
        if written <= 0:
            raise OSError("factory mutation lock write made no progress")
        view = view[written:]


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


def _utc_now() -> dt.datetime:
    return dt.datetime.now(dt.UTC)


def _parse_lock_record(
    raw: bytes,
    *,
    now: dt.datetime | None = None,
) -> tuple[dict, dt.datetime, float]:
    """Validate the complete nonce-bound record and return its age."""

    if not raw or len(raw) > MAX_RECORD_BYTES:
        raise ValueError("lock record is empty or exceeds the size cap")
    try:
        record = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("lock record is not valid UTF-8 JSON") from exc
    if not isinstance(record, dict):
        raise ValueError("lock record must be a JSON object")

    pid = record.get("pid")
    owner = record.get("owner")
    nonce = record.get("nonce")
    created_text = record.get("created_at")
    if isinstance(pid, bool) or not isinstance(pid, int) or pid <= 0:
        raise ValueError("lock record pid must be a positive integer")
    if not isinstance(owner, str) or not owner.strip():
        raise ValueError("lock record owner must be non-empty")
    if (
        not isinstance(nonce, str)
        or len(nonce) != 32
        or any(ch not in "0123456789abcdefABCDEF" for ch in nonce)
    ):
        raise ValueError("lock record nonce must be 32 hexadecimal characters")
    if not isinstance(created_text, str):
        raise ValueError("lock record created_at must be an ISO-8601 string")
    try:
        created_at = dt.datetime.fromisoformat(created_text.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError("lock record created_at is not valid ISO-8601") from exc
    if created_at.tzinfo is None or created_at.utcoffset() is None:
        raise ValueError("lock record created_at must carry a UTC offset")
    created_at = created_at.astimezone(dt.UTC)

    current = (now or _utc_now()).astimezone(dt.UTC)
    age_seconds = (current - created_at).total_seconds()
    if age_seconds < -FUTURE_CLOCK_TOLERANCE_SECONDS:
        raise ValueError("lock record created_at is in the future")
    return record, created_at, max(0.0, age_seconds)


def _read_path_capped(path: Path) -> bytes:
    with path.open("rb") as stream:
        raw = stream.read(MAX_RECORD_BYTES + 1)
    if len(raw) > MAX_RECORD_BYTES:
        raise ValueError("lock record exceeds the size cap")
    return raw


def _pid_identity_state(pid: int, lock_created_at: dt.datetime) -> str:
    """Return live, dead, reused, or unknown without ever signalling a PID."""

    if pid <= 0:
        return "unknown"
    if os.name != "nt":
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return "dead"
        except PermissionError:
            return "live"  # fail closed when liveness is permission-protected
        except OSError:
            return "unknown"
        return "live"

    process_query_limited_information = 0x1000
    still_active = 259
    error_invalid_parameter = 87
    open_process = _KERNEL32.OpenProcess
    open_process.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
    open_process.restype = wintypes.HANDLE
    get_exit_code = _KERNEL32.GetExitCodeProcess
    get_exit_code.argtypes = (wintypes.HANDLE, wintypes.LPDWORD)
    get_exit_code.restype = wintypes.BOOL
    get_process_times = _KERNEL32.GetProcessTimes
    get_process_times.argtypes = (
        wintypes.HANDLE,
        wintypes.LPFILETIME,
        wintypes.LPFILETIME,
        wintypes.LPFILETIME,
        wintypes.LPFILETIME,
    )
    get_process_times.restype = wintypes.BOOL
    close_handle = _KERNEL32.CloseHandle
    close_handle.argtypes = (wintypes.HANDLE,)
    close_handle.restype = wintypes.BOOL
    handle = open_process(
        process_query_limited_information,
        False,
        int(pid),
    )
    if not handle:
        return (
            "dead"
            if ctypes.get_last_error() == error_invalid_parameter
            else "unknown"
        )
    try:
        exit_code = wintypes.DWORD()
        if not get_exit_code(handle, ctypes.byref(exit_code)):
            return "unknown"
        if exit_code.value != still_active:
            return "dead"

        creation = wintypes.FILETIME()
        exit_time = wintypes.FILETIME()
        kernel = wintypes.FILETIME()
        user = wintypes.FILETIME()
        if not get_process_times(
            handle,
            ctypes.byref(creation),
            ctypes.byref(exit_time),
            ctypes.byref(kernel),
            ctypes.byref(user),
        ):
            return "unknown"
        ticks = (creation.dwHighDateTime << 32) | creation.dwLowDateTime
        process_started_unix = (ticks / 10_000_000.0) - 11_644_473_600.0
        if (
            process_started_unix
            > lock_created_at.timestamp() + PID_START_TOLERANCE_SECONDS
        ):
            return "reused"
        return "live"
    finally:
        close_handle(handle)


def inspect_factory_mutation_lock(
    path: Path = DEFAULT_PATH,
    *,
    now: dt.datetime | None = None,
) -> dict:
    """Read-only lock snapshot used by health checks and acquisition."""

    lock_path = Path(path)
    current = (now or _utc_now()).astimezone(dt.UTC)
    try:
        stat = lock_path.stat()
    except FileNotFoundError:
        return {"status": "absent", "path": str(lock_path), "age_seconds": 0.0}
    except OSError as exc:
        return {
            "status": "unreadable",
            "path": str(lock_path),
            "age_seconds": None,
            "error": repr(exc),
        }

    mtime_age = max(0.0, current.timestamp() - stat.st_mtime)
    try:
        raw = _read_path_capped(lock_path)
    except FileNotFoundError:
        return {"status": "absent", "path": str(lock_path), "age_seconds": 0.0}
    except (OSError, ValueError) as exc:
        return {
            "status": "unreadable",
            "path": str(lock_path),
            "age_seconds": mtime_age,
            "error": repr(exc),
        }
    try:
        record, created_at, age_seconds = _parse_lock_record(raw, now=current)
    except ValueError as exc:
        return {
            "status": "invalid",
            "path": str(lock_path),
            "age_seconds": mtime_age,
            "error": str(exc),
        }
    return {
        "status": _pid_identity_state(int(record["pid"]), created_at),
        "path": str(lock_path),
        "age_seconds": age_seconds,
        "record": record,
        "content_sha256": hashlib.sha256(raw).hexdigest(),
    }


def _delete_windows_file_if_content_matches(path: Path, expected: bytes) -> str:
    """Delete only the exact readable file object whose full bytes still match."""

    if os.name != "nt":
        return "unsupported_platform"
    try:
        descriptor = _open_existing_exclusive_for_delete(path)
    except FileNotFoundError:
        return "already_absent"
    except OSError:
        return "unreadable"

    result = "unreadable"
    try:
        try:
            actual = _read_open_descriptor(descriptor, MAX_RECORD_BYTES + 1)
        except OSError:
            return "unreadable"
        if actual != expected:
            return "ownership_changed"
        try:
            if not _mark_windows_file_for_delete(descriptor):
                return "unlink_failed"
        except OSError:
            return "unlink_failed"
        result = "reaped"
    finally:
        try:
            os.close(descriptor)
        except OSError:
            result = "close_failed"
    return result


class FactoryMutationLock:
    """Hold the global mutation boundary until the guarded operation finishes."""

    def __init__(
        self,
        path: Path = DEFAULT_PATH,
        *,
        owner: str,
        stale_reap_seconds: float = DEFAULT_STALE_REAP_SECONDS,
        reap_evidence_path: Path = DEFAULT_REAP_EVIDENCE_PATH,
    ) -> None:
        self.path = Path(path)
        self.owner = str(owner)
        if not self.owner.strip():
            raise ValueError("factory mutation lock owner must be non-empty")
        self.stale_reap_seconds = float(stale_reap_seconds)
        if self.stale_reap_seconds < 0:
            raise ValueError("stale_reap_seconds must be non-negative")
        self.reap_evidence_path = Path(reap_evidence_path)
        self.nonce = uuid.uuid4().hex
        self._fd: int | None = None
        self._record_bytes: bytes | None = None
        self.release_status: str | None = None
        self.reap_status: str | None = None

    @property
    def release_succeeded(self) -> bool:
        """Whether this instance left no lock record that it could still own."""

        return self.release_status in {"released", "already_absent"}

    def __enter__(self) -> "FactoryMutationLock":
        self.path.parent.mkdir(parents=True, exist_ok=True)
        try:
            self._fd = _open_exclusive_lock(self.path)
        except FileExistsError as exc:
            self.reap_status = self._try_reap_stale_lock()
            if self.reap_status != "reaped":
                raise RuntimeError(
                    f"factory mutation lock is busy: {self.path} "
                    f"(stale_reap={self.reap_status})"
                ) from exc
            try:
                self._fd = _open_exclusive_lock(self.path)
            except FileExistsError as retry_exc:
                raise RuntimeError(
                    f"factory mutation lock is busy after stale reap: {self.path}"
                ) from retry_exc
        record = {
            "pid": os.getpid(),
            "owner": self.owner,
            "nonce": self.nonce,
            "created_at": _utc_now().isoformat(),
        }
        self._record_bytes = (json.dumps(record, sort_keys=True) + "\n").encode("utf-8")
        try:
            _write_all(self._fd, self._record_bytes)
            os.fsync(self._fd)
        except BaseException:
            self.release_status = self._release_owned_open_file()
            os.close(self._fd)
            self._fd = None
            if self.release_status == "delete_pending":
                self.release_status = "released"
            raise
        return self

    def _try_reap_stale_lock(self) -> str:
        """Reap one old, readable, provably orphaned record and audit it."""

        if os.name != "nt":
            return "unsupported_platform"
        now = _utc_now()
        try:
            expected = _read_path_capped(self.path)
        except FileNotFoundError:
            return "already_absent"
        except (OSError, ValueError):
            return "unreadable"
        try:
            record, created_at, age_seconds = _parse_lock_record(expected, now=now)
        except ValueError:
            return "invalid_record"
        if age_seconds < self.stale_reap_seconds:
            return "not_stale"

        pid_state = _pid_identity_state(int(record["pid"]), created_at)
        if pid_state not in {"dead", "reused"}:
            return f"pid_{pid_state}"

        # Open the journal first. If evidence cannot be made durable, retain the
        # orphan fail-closed instead of silently deleting it.
        flags = os.O_WRONLY | os.O_CREAT | os.O_APPEND
        flags |= getattr(os, "O_BINARY", 0) | getattr(os, "O_NOINHERIT", 0)
        try:
            self.reap_evidence_path.parent.mkdir(parents=True, exist_ok=True)
            evidence_fd = os.open(self.reap_evidence_path, flags, 0o600)
        except OSError:
            return "evidence_unwritable"

        delete_status = "unreadable"
        try:
            # This second, no-sharing open and full read is the content CAS. A
            # live holder or a replacement record makes it fail without delete.
            delete_status = _delete_windows_file_if_content_matches(
                self.path,
                expected,
            )
            if delete_status != "reaped":
                return delete_status
            evidence = {
                "schema": "qm.factory-mutation-lock-reap/v1",
                "reaped_at_utc": _utc_now().isoformat(),
                "reaper_pid": os.getpid(),
                "reaper_owner": self.owner,
                "lock_path": str(self.path),
                "lock_record": record,
                "lock_age_seconds": round(age_seconds, 3),
                "stale_threshold_seconds": self.stale_reap_seconds,
                "pid_state": pid_state,
                "reason": (
                    "owner_pid_reused"
                    if pid_state == "reused"
                    else "owner_pid_dead"
                ),
                "content_sha256": hashlib.sha256(expected).hexdigest(),
            }
            payload = (
                json.dumps(evidence, sort_keys=True, separators=(",", ":"))
                + "\n"
            ).encode("utf-8")
            try:
                _write_all(evidence_fd, payload)
                os.fsync(evidence_fd)
            except OSError as exc:
                raise RuntimeError(
                    "stale factory mutation lock was reaped but audit append failed"
                ) from exc
            return "reaped"
        finally:
            try:
                os.close(evidence_fd)
            except OSError:
                if delete_status == "reaped":
                    raise RuntimeError(
                        "stale factory mutation lock was reaped but audit close failed"
                    )

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
