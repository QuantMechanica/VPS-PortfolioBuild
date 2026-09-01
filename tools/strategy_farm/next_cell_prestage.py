#!/usr/bin/env python3
"""Detached, non-authoritative preparation for one possible next work item.

This module is deliberately ignorant of the strategy-farm claim state machine.  A
caller supplies a read-only candidate snapshot and the ordinary claimant later
supplies the item it actually claimed.  Preparing a snapshot therefore creates no
queue right, reservation, priority effect, receipt, or terminal-tree mutation.

The feature is inert unless both ``NEXT_CELL_PRESTAGE_ENABLED`` is true and the
worker terminal is present in ``NEXT_CELL_PRESTAGE_TERMINAL_ALLOWLIST``.  An empty
allowlist is the safe default.
"""

from __future__ import annotations

import ctypes
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import sys
import threading
import time
from typing import Any, Callable, Mapping, MutableMapping, Sequence
import uuid


FEATURE_ENV = "NEXT_CELL_PRESTAGE_ENABLED"
ALLOWLIST_ENV = "NEXT_CELL_PRESTAGE_TERMINAL_ALLOWLIST"
TTL_ENV = "NEXT_CELL_PRESTAGE_TTL_SECONDS"
MAX_BYTES_ENV = "NEXT_CELL_PRESTAGE_MAX_BYTES"
IO_MIB_PER_SECOND_ENV = "NEXT_CELL_PRESTAGE_IO_MIB_PER_SECOND"
MIN_FREE_DISK_GB_ENV = "NEXT_CELL_PRESTAGE_MIN_FREE_DISK_GB"
MIN_FREE_RAM_GB_ENV = "NEXT_CELL_PRESTAGE_MIN_FREE_RAM_GB"
MIN_FREE_COMMIT_GB_ENV = "NEXT_CELL_PRESTAGE_MIN_FREE_COMMIT_GB"
MAX_CPU_PERCENT_ENV = "NEXT_CELL_PRESTAGE_MAX_CPU_PERCENT"

SCHEMA = "qm.next-cell-prestage/v1"
TOKEN_SCHEMA = "qm.next-cell-prestage-token/v1"
STATE_SCHEMA = "qm.next-cell-prestage-state/v1"
POLICY_SCHEMA = "qm.next-cell-prestage-policy/2026-09-01.v1"

DEFAULT_TTL_SECONDS = 15 * 60
DEFAULT_MAX_BYTES = 4 * 1024**3
DEFAULT_IO_MIB_PER_SECOND = 64.0
DEFAULT_MIN_FREE_DISK_GB = 60.0
DEFAULT_MIN_FREE_RAM_GB = 12.0
DEFAULT_MIN_FREE_COMMIT_GB = 32.0
DEFAULT_MAX_CPU_PERCENT = 90.0
DEFAULT_CANCEL_JOIN_SECONDS = 5.0
COPY_CHUNK_BYTES = 4 * 1024**2
_TRUE = frozenset({"1", "true", "yes", "on"})


class PrestageError(RuntimeError):
    """A speculative preparation could not be proved safe to adopt."""


class PrestageCancelled(PrestageError):
    """The active child finished or the worker stopped during preparation."""


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="milliseconds")


def _canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_text(value: object) -> str:
    return sha256_bytes(str(value or "").encode("utf-8"))


def sha256_file(path: Path, *, cancel: threading.Event | None = None) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        while True:
            if cancel is not None and cancel.is_set():
                raise PrestageCancelled("cancelled_while_hashing")
            chunk = handle.read(COPY_CHUNK_BYTES)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def _bounded_float(
    env: Mapping[str, str], name: str, default: float, *, minimum: float
) -> float:
    try:
        value = float(str(env.get(name, default)).strip())
    except (TypeError, ValueError):
        return default
    if not math.isfinite(value) or value < minimum:
        return default
    return value


def _bounded_int(
    env: Mapping[str, str], name: str, default: int, *, minimum: int
) -> int:
    try:
        value = int(str(env.get(name, default)).strip())
    except (TypeError, ValueError):
        return default
    return value if value >= minimum else default


class PrestageConfig:
    """Validated immutable controls for one resident terminal worker."""

    def __init__(
        self,
        *,
        root: Path,
        terminal: str,
        enabled: bool,
        terminal_allowlist: Sequence[str],
        ttl_seconds: int,
        max_bytes: int,
        io_mib_per_second: float,
        min_free_disk_gb: float,
        min_free_ram_gb: float,
        min_free_commit_gb: float,
        max_cpu_percent: float,
        cancel_join_seconds: float = DEFAULT_CANCEL_JOIN_SECONDS,
    ) -> None:
        self.root = Path(root).resolve(strict=False)
        self.terminal = str(terminal).strip().upper()
        self.enabled = bool(enabled)
        self.terminal_allowlist = frozenset(
            str(value).strip().upper()
            for value in terminal_allowlist
            if str(value).strip()
        )
        self.ttl_seconds = int(ttl_seconds)
        self.max_bytes = int(max_bytes)
        self.io_mib_per_second = float(io_mib_per_second)
        self.min_free_disk_gb = float(min_free_disk_gb)
        self.min_free_ram_gb = float(min_free_ram_gb)
        self.min_free_commit_gb = float(min_free_commit_gb)
        self.max_cpu_percent = float(max_cpu_percent)
        self.cancel_join_seconds = float(cancel_join_seconds)

    @classmethod
    def from_env(
        cls,
        root: Path,
        terminal: str,
        env: Mapping[str, str] | None = None,
    ) -> "PrestageConfig":
        values = os.environ if env is None else env
        allowlist = [
            part.strip()
            for part in str(values.get(ALLOWLIST_ENV, "")).split(",")
            if part.strip()
        ]
        return cls(
            root=root,
            terminal=terminal,
            enabled=str(values.get(FEATURE_ENV, "0")).strip().lower() in _TRUE,
            terminal_allowlist=allowlist,
            ttl_seconds=_bounded_int(
                values, TTL_ENV, DEFAULT_TTL_SECONDS, minimum=30
            ),
            max_bytes=_bounded_int(
                values, MAX_BYTES_ENV, DEFAULT_MAX_BYTES, minimum=1024**2
            ),
            io_mib_per_second=_bounded_float(
                values,
                IO_MIB_PER_SECOND_ENV,
                DEFAULT_IO_MIB_PER_SECOND,
                minimum=1.0,
            ),
            min_free_disk_gb=_bounded_float(
                values,
                MIN_FREE_DISK_GB_ENV,
                DEFAULT_MIN_FREE_DISK_GB,
                minimum=1.0,
            ),
            min_free_ram_gb=_bounded_float(
                values,
                MIN_FREE_RAM_GB_ENV,
                DEFAULT_MIN_FREE_RAM_GB,
                minimum=0.0,
            ),
            min_free_commit_gb=_bounded_float(
                values,
                MIN_FREE_COMMIT_GB_ENV,
                DEFAULT_MIN_FREE_COMMIT_GB,
                minimum=0.0,
            ),
            max_cpu_percent=_bounded_float(
                values,
                MAX_CPU_PERCENT_ENV,
                DEFAULT_MAX_CPU_PERCENT,
                minimum=1.0,
            ),
        )

    @property
    def active(self) -> bool:
        return self.enabled and self.terminal in self.terminal_allowlist

    @property
    def cache_root(self) -> Path:
        return self.root / "cache" / "next_cell_prestage"

    def public(self) -> dict[str, Any]:
        return {
            "schema": SCHEMA,
            "enabled": self.enabled,
            "active_for_terminal": self.active,
            "terminal": self.terminal,
            "terminal_allowlist": sorted(self.terminal_allowlist),
            "ttl_seconds": self.ttl_seconds,
            "max_bytes": self.max_bytes,
            "io_mib_per_second": self.io_mib_per_second,
            "min_free_disk_gb": self.min_free_disk_gb,
            "min_free_ram_gb": self.min_free_ram_gb,
            "min_free_commit_gb": self.min_free_commit_gb,
            "max_cpu_percent": self.max_cpu_percent,
            "cache_root": str(self.cache_root),
        }


def file_spec(
    path: Path | str,
    *,
    role: str,
    logical_name: str | None = None,
    expected_sha256: str | None = None,
    cache: bool = True,
    cancel: threading.Event | None = None,
) -> dict[str, Any]:
    """Hash and bind one immutable input without writing outside the cache."""

    source = Path(path)
    if not source.is_absolute():
        raise PrestageError(f"source_path_not_absolute:{source}")
    try:
        before = source.stat()
    except OSError as exc:
        raise PrestageError(f"source_unavailable:{source}:{exc}") from exc
    if not source.is_file():
        raise PrestageError(f"source_not_file:{source}")
    digest = sha256_file(source, cancel=cancel)
    expected = str(expected_sha256 or digest).strip().lower()
    if len(expected) != 64 or any(ch not in "0123456789abcdef" for ch in expected):
        raise PrestageError(f"invalid_expected_sha256:{role}")
    if digest != expected:
        raise PrestageError(
            f"source_sha256_mismatch:{role}:{digest}:expected:{expected}"
        )
    after = source.stat()
    if (
        before.st_size != after.st_size
        or before.st_mtime_ns != after.st_mtime_ns
        or getattr(before, "st_ino", 0) != getattr(after, "st_ino", 0)
    ):
        raise PrestageError(f"source_changed_while_hashing:{role}:{source}")
    return {
        "role": str(role),
        "logical_name": str(logical_name or source.name),
        "source_path": str(source.resolve(strict=True)),
        "source_size": int(after.st_size),
        "source_mtime_ns": int(after.st_mtime_ns),
        "source_inode": int(getattr(after, "st_ino", 0)),
        "sha256": digest,
        "cache": bool(cache),
    }


def seal_snapshot(snapshot: Mapping[str, Any]) -> dict[str, Any]:
    """Bind a caller-produced read-only candidate snapshot to one token."""

    required = {
        "terminal",
        "worker_generation",
        "item",
        "payload_sha256",
        "policy_generation",
        "files",
    }
    missing = sorted(required - set(snapshot))
    if missing:
        raise PrestageError("snapshot_missing_fields:" + ",".join(missing))
    created_at = _utc_now()
    token_body = {
        "schema": TOKEN_SCHEMA,
        "terminal": str(snapshot["terminal"]).upper(),
        "worker_generation": str(snapshot["worker_generation"]),
        "item": dict(snapshot["item"]),
        "payload_sha256": str(snapshot["payload_sha256"]),
        "policy_generation": str(snapshot["policy_generation"]),
        "files": [dict(value) for value in snapshot["files"]],
        "dependencies": dict(snapshot.get("dependencies") or {}),
        "created_at_utc": created_at,
        "ttl_seconds": int(snapshot.get("ttl_seconds") or DEFAULT_TTL_SECONDS),
    }
    token_sha = sha256_bytes(_canonical_bytes(token_body))
    return {
        **token_body,
        "token_sha256": token_sha,
        "metadata": dict(snapshot.get("metadata") or {}),
    }


def _atomic_write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp")
    try:
        with temporary.open("xb") as handle:
            handle.write(_canonical_bytes(value) + b"\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _safe_terminal_cache_root(config: PrestageConfig) -> Path:
    base = config.cache_root.resolve(strict=False)
    target = (base / config.terminal).resolve(strict=False)
    try:
        target.relative_to(base)
    except ValueError as exc:
        raise PrestageError("terminal_cache_path_escape") from exc
    return target


def cleanup_expired(config: PrestageConfig, *, now: float | None = None) -> int:
    """Delete only expired detached plan directories for this exact terminal."""

    terminal_root = _safe_terminal_cache_root(config)
    if not terminal_root.is_dir():
        return 0
    cutoff = (time.time() if now is None else now) - config.ttl_seconds * 2
    removed = 0
    for item_dir in list(terminal_root.iterdir()):
        if not item_dir.is_dir():
            continue
        try:
            if item_dir.stat().st_mtime >= cutoff:
                continue
            resolved = item_dir.resolve(strict=True)
            resolved.relative_to(terminal_root.resolve(strict=True))
            shutil.rmtree(resolved)
            removed += 1
        except (FileNotFoundError, OSError, ValueError):
            continue
    return removed


class _FleetIOSlot:
    """One non-blocking, fleet-wide heavy-I/O permit."""

    _WINDOWS_NAME = "Global\\QM_NextCellPrestageIO_v1"

    def __init__(self, config: PrestageConfig) -> None:
        self.config = config
        self.acquired = False
        self._handle: int | None = None
        self._kernel32: Any | None = None
        self._lock_path = config.cache_root / "NEXT_CELL_PRESTAGE_IO.lock"
        self._fd: int | None = None

    def __enter__(self) -> "_FleetIOSlot":
        if sys.platform == "win32":
            kernel32 = ctypes.windll.kernel32
            kernel32.CreateSemaphoreW.argtypes = (
                ctypes.c_void_p,
                ctypes.c_long,
                ctypes.c_long,
                ctypes.c_wchar_p,
            )
            kernel32.CreateSemaphoreW.restype = ctypes.c_void_p
            kernel32.WaitForSingleObject.argtypes = (
                ctypes.c_void_p,
                ctypes.c_ulong,
            )
            kernel32.WaitForSingleObject.restype = ctypes.c_ulong
            kernel32.ReleaseSemaphore.argtypes = (
                ctypes.c_void_p,
                ctypes.c_long,
                ctypes.c_void_p,
            )
            kernel32.ReleaseSemaphore.restype = ctypes.c_int
            kernel32.CloseHandle.argtypes = (ctypes.c_void_p,)
            kernel32.CloseHandle.restype = ctypes.c_int
            handle = kernel32.CreateSemaphoreW(None, 1, 1, self._WINDOWS_NAME)
            if not handle:
                return self
            self._kernel32 = kernel32
            self._handle = int(handle)
            wait_result = kernel32.WaitForSingleObject(
                ctypes.c_void_p(self._handle), 0
            )
            self.acquired = wait_result == 0
            if not self.acquired:
                kernel32.CloseHandle(ctypes.c_void_p(self._handle))
                self._handle = None
                self._kernel32 = None
            return self
        self._lock_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            self._fd = os.open(
                self._lock_path,
                os.O_CREAT | os.O_EXCL | os.O_WRONLY,
                0o600,
            )
            os.write(self._fd, f"{os.getpid()}\n".encode("ascii"))
            self.acquired = True
        except FileExistsError:
            self.acquired = False
        return self

    def __exit__(self, _exc_type: object, _exc: object, _tb: object) -> None:
        if sys.platform == "win32" and self._handle is not None:
            kernel32 = self._kernel32 or ctypes.windll.kernel32
            if self.acquired:
                kernel32.ReleaseSemaphore(
                    ctypes.c_void_p(self._handle), 1, None
                )
            kernel32.CloseHandle(ctypes.c_void_p(self._handle))
            self._handle = None
            self._kernel32 = None
        if self._fd is not None:
            try:
                os.close(self._fd)
            finally:
                self._fd = None
                self._lock_path.unlink(missing_ok=True)
        self.acquired = False


def _lower_thread_priority() -> None:
    if sys.platform != "win32":
        return
    try:
        # THREAD_PRIORITY_BELOW_NORMAL. Failure is harmless: the byte-rate and
        # fleet semaphore still bound the speculative work.
        ctypes.windll.kernel32.SetThreadPriority(
            ctypes.windll.kernel32.GetCurrentThread(), -1
        )
    except Exception:
        pass


def _throttle_copy(
    *,
    copied_bytes: int,
    started: float,
    mib_per_second: float,
    cancel: threading.Event,
) -> None:
    expected_elapsed = copied_bytes / (mib_per_second * 1024**2)
    remaining = expected_elapsed - (time.monotonic() - started)
    while remaining > 0:
        if cancel.wait(min(0.25, remaining)):
            raise PrestageCancelled("cancelled_while_throttling")
        remaining = expected_elapsed - (time.monotonic() - started)


def _copy_to_content_address(
    spec: Mapping[str, Any],
    *,
    plan_dir: Path,
    cancel: threading.Event,
    mib_per_second: float,
) -> dict[str, Any]:
    source = Path(str(spec["source_path"]))
    expected = str(spec["sha256"])
    objects = plan_dir / "objects" / expected[:2]
    destination = objects / expected
    objects.mkdir(parents=True, exist_ok=True)
    if destination.is_file() and destination.stat().st_size == int(spec["source_size"]):
        return {**dict(spec), "cache_path": str(destination), "cache_reused": True}
    # Keep the temporary name short enough for the default Windows MAX_PATH
    # surface; the containing plan and final object still bind full hashes.
    temporary = destination.with_name(
        f".tmp.{os.getpid()}.{uuid.uuid4().hex[:12]}"
    )
    digest = hashlib.sha256()
    copied = 0
    started = time.monotonic()
    try:
        with source.open("rb") as reader, temporary.open("xb") as writer:
            while True:
                if cancel.is_set():
                    raise PrestageCancelled("cancelled_while_copying")
                chunk = reader.read(COPY_CHUNK_BYTES)
                if not chunk:
                    break
                writer.write(chunk)
                digest.update(chunk)
                copied += len(chunk)
                _throttle_copy(
                    copied_bytes=copied,
                    started=started,
                    mib_per_second=mib_per_second,
                    cancel=cancel,
                )
            writer.flush()
            os.fsync(writer.fileno())
        if copied != int(spec["source_size"]):
            raise PrestageError(
                f"copy_size_mismatch:{spec['role']}:{copied}:expected:{spec['source_size']}"
            )
        actual = digest.hexdigest()
        if actual != expected:
            raise PrestageError(
                f"copy_sha256_mismatch:{spec['role']}:{actual}:expected:{expected}"
            )
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)
    return {**dict(spec), "cache_path": str(destination), "cache_reused": False}


def prepare_snapshot(
    snapshot: Mapping[str, Any],
    *,
    config: PrestageConfig,
    cancel: threading.Event,
    resource_probe: Callable[[], Mapping[str, Any]],
    candidate_is_current: Callable[[Mapping[str, Any]], tuple[bool, str]],
    emit: Callable[[str, Mapping[str, Any]], None],
    io_slot_held: bool = False,
) -> dict[str, Any]:
    """Publish a detached PREPARED plan, or raise without affecting authority."""

    token = seal_snapshot({**dict(snapshot), "ttl_seconds": config.ttl_seconds})
    copied_specs = [value for value in token["files"] if value.get("cache")]
    total_bytes = sum(int(value["source_size"]) for value in copied_specs)
    if total_bytes > config.max_bytes:
        raise PrestageError(
            f"byte_cap_exceeded:{total_bytes}:cap:{config.max_bytes}"
        )
    resources = dict(resource_probe())
    if not resources.get("allowed"):
        raise PrestageError(
            "resource_decline:" + str(resources.get("reason") or "unspecified")
        )
    cleanup_expired(config)
    # The full token and item identity live in state.json. A 24-hex directory
    # prefix keeps detached-cache paths below Windows MAX_PATH while retaining
    # a 96-bit collision boundary; any collision still fails on the full state
    # key before adoption.
    plan_dir = _safe_terminal_cache_root(config) / token["token_sha256"][:24]
    state_path = plan_dir / "state.json"
    selected_state = {
        "schema": STATE_SCHEMA,
        "state": "SELECTED",
        "terminal": config.terminal,
        "item_id": token["item"].get("id"),
        "token_sha256": token["token_sha256"],
        "selected_at_utc": _utc_now(),
    }
    _atomic_write_json(state_path, selected_state)
    emit(
        "prestage_started",
        {
            "item_id": token["item"].get("id"),
            "token_sha256": token["token_sha256"],
            "input_count": len(token["files"]),
            "copy_input_count": len(copied_specs),
            "planned_bytes": total_bytes,
            "resources": resources,
        },
    )
    prepared_files: list[dict[str, Any]] = []

    def _copy_all() -> None:
        for spec in token["files"]:
            if cancel.is_set():
                raise PrestageCancelled("cancelled_before_input")
            if spec.get("cache"):
                prepared = _copy_to_content_address(
                    spec,
                    plan_dir=plan_dir,
                    cancel=cancel,
                    mib_per_second=config.io_mib_per_second,
                )
            else:
                prepared = dict(spec)
            prepared_files.append(prepared)

    if io_slot_held:
        _copy_all()
    else:
        with _FleetIOSlot(config) as io_slot:
            if not io_slot.acquired:
                raise PrestageError("io_budget_busy")
            _copy_all()
    if cancel.is_set():
        raise PrestageCancelled("cancelled_before_publication")
    current, current_reason = candidate_is_current(token)
    if not current:
        raise PrestageError(f"candidate_stale:{current_reason}")
    prepared_at = _utc_now()
    plan = {
        **token,
        "files": prepared_files,
        "state": "PREPARED",
        "state_path": str(state_path),
        "plan_dir": str(plan_dir),
        "prepared_at_utc": prepared_at,
        "prepared_bytes": total_bytes,
        "resource_snapshot": resources,
    }
    _atomic_write_json(
        state_path,
        {
            "schema": STATE_SCHEMA,
            "state": "PREPARED",
            "terminal": config.terminal,
            "item_id": token["item"].get("id"),
            "token_sha256": token["token_sha256"],
            "selected_at_utc": selected_state["selected_at_utc"],
            "prepared_at_utc": prepared_at,
            "plan_sha256": sha256_bytes(_canonical_bytes(plan)),
        },
    )
    return plan


def _age_seconds(plan: Mapping[str, Any], *, now: dt.datetime | None = None) -> float:
    try:
        created = dt.datetime.fromisoformat(str(plan["created_at_utc"]))
    except (KeyError, TypeError, ValueError) as exc:
        raise PrestageError("invalid_created_at") from exc
    if created.tzinfo is None:
        created = created.replace(tzinfo=dt.timezone.utc)
    current = now or dt.datetime.now(dt.timezone.utc)
    return max(0.0, (current.astimezone(dt.timezone.utc) - created).total_seconds())


def validate_plan_sources(plan: Mapping[str, Any]) -> tuple[bool, str]:
    """Revalidate bound identities; final consumers still hash copied bytes."""

    for spec in plan.get("files") or []:
        source = Path(str(spec.get("source_path") or ""))
        try:
            stat = source.stat()
        except OSError:
            return False, f"source_missing:{spec.get('role')}"
        if (
            int(stat.st_size) != int(spec.get("source_size", -1))
            or int(stat.st_mtime_ns) != int(spec.get("source_mtime_ns", -1))
            or int(getattr(stat, "st_ino", 0)) != int(spec.get("source_inode", 0))
        ):
            return False, f"source_identity_changed:{spec.get('role')}"
        if spec.get("cache"):
            cached = Path(str(spec.get("cache_path") or ""))
            try:
                if not cached.is_file() or cached.stat().st_size != int(spec["source_size"]):
                    return False, f"cache_identity_changed:{spec.get('role')}"
            except OSError:
                return False, f"cache_missing:{spec.get('role')}"
        else:
            try:
                if sha256_file(source) != str(spec.get("sha256") or ""):
                    return False, f"dependency_hash_changed:{spec.get('role')}"
            except (OSError, PrestageError):
                return False, f"dependency_unreadable:{spec.get('role')}"
    return True, "match"


def cached_file(
    plan: Mapping[str, Any] | None,
    *,
    role: str,
    logical_name: str | None = None,
) -> dict[str, Any] | None:
    if not plan:
        return None
    for value in plan.get("files") or []:
        if str(value.get("role")) != role or not value.get("cache_path"):
            continue
        if logical_name is not None and str(value.get("logical_name")) != logical_name:
            continue
        return dict(value)
    return None


def cached_history_sources(plan: Mapping[str, Any] | None) -> dict[str, dict[str, Any]]:
    if not plan:
        return {}
    return {
        str(value["logical_name"]): dict(value)
        for value in plan.get("files") or []
        if value.get("role") == "custom_history_archive" and value.get("cache_path")
    }


def _load_state(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise PrestageError(f"state_unreadable:{exc}") from exc
    if not isinstance(value, dict) or value.get("schema") != STATE_SCHEMA:
        raise PrestageError("state_schema_mismatch")
    return value


def adopt_plan(
    plan: Mapping[str, Any],
    *,
    config: PrestageConfig,
    claim: Mapping[str, Any],
    current_policy_generation: str,
    dependency_validator: Callable[[Mapping[str, Any]], tuple[bool, str]],
) -> tuple[dict[str, Any] | None, str]:
    """Perform the local PREPARED->ADOPTED CAS after an ordinary claim."""

    item = claim.get("item") or {}
    item_id = str(item.get("id") or "")
    if item_id != str((plan.get("item") or {}).get("id") or ""):
        return None, "claimed_different_item"
    if str(plan.get("terminal") or "").upper() != config.terminal:
        return None, "terminal_mismatch"
    if str(claim.get("preclaim_payload_sha256") or "") != str(
        plan.get("payload_sha256") or ""
    ):
        return None, "preclaim_payload_changed"
    if str(plan.get("policy_generation") or "") != str(current_policy_generation):
        return None, "policy_generation_changed"
    if _age_seconds(plan) > min(config.ttl_seconds, int(plan.get("ttl_seconds") or 0)):
        return None, "expired"
    sources_ok, sources_reason = validate_plan_sources(plan)
    if not sources_ok:
        return None, sources_reason
    dependencies_ok, dependencies_reason = dependency_validator(plan)
    if not dependencies_ok:
        return None, dependencies_reason
    state_path = Path(str(plan.get("state_path") or ""))
    state = _load_state(state_path)
    token_sha = str(plan.get("token_sha256") or "")
    if (
        str(state.get("token_sha256") or "") != token_sha
        or str(state.get("item_id") or "") != item_id
    ):
        return None, "state_key_mismatch"
    if state.get("state") == "ADOPTED":
        return {**dict(plan), "state": "ADOPTED", "idempotent": True}, "adopted_idempotent"
    if state.get("state") != "PREPARED":
        return None, "state_not_prepared"
    adopted_at = _utc_now()
    _atomic_write_json(
        state_path,
        {
            **state,
            "state": "ADOPTED",
            "adopted_at_utc": adopted_at,
            "claimed_item_id": item_id,
        },
    )
    return {
        **dict(plan),
        "state": "ADOPTED",
        "adopted_at_utc": adopted_at,
        "idempotent": False,
    }, "adopted"


def mark_plan_missed(plan: Mapping[str, Any], reason: str) -> None:
    try:
        state_path = Path(str(plan.get("state_path") or ""))
        state = _load_state(state_path)
        if state.get("state") != "PREPARED":
            return
        _atomic_write_json(
            state_path,
            {
                **state,
                "state": "MISSED",
                "missed_at_utc": _utc_now(),
                "miss_reason": str(reason),
            },
        )
    except (OSError, PrestageError):
        return


class PrestageController:
    """One speculative slot and duty-cycle clock for a resident worker."""

    def __init__(
        self,
        config: PrestageConfig,
        *,
        snapshot_loader: Callable[[str, threading.Event], Mapping[str, Any]],
        candidate_is_current: Callable[[Mapping[str, Any]], tuple[bool, str]],
        resource_probe: Callable[[], Mapping[str, Any]],
        policy_generation: Callable[[], str],
        dependency_validator: Callable[[Mapping[str, Any]], tuple[bool, str]],
        telemetry: Callable[[Mapping[str, Any]], None],
    ) -> None:
        self.config = config
        self.snapshot_loader = snapshot_loader
        self.candidate_is_current = candidate_is_current
        self.resource_probe = resource_probe
        self.policy_generation = policy_generation
        self.dependency_validator = dependency_validator
        self.telemetry = telemetry
        self.worker_generation = uuid.uuid4().hex
        self._lock = threading.Lock()
        self._thread: threading.Thread | None = None
        self._cancel: threading.Event | None = None
        self._prepared: dict[str, Any] | None = None
        self._current_item_id: str | None = None
        self._current_started_monotonic: float | None = None
        self._last_runtime_seconds: float | None = None
        self._last_exit_monotonic: float | None = None
        self._emit("config", self.config.public())

    def _emit(self, stage_event: str, detail: Mapping[str, Any] | None = None) -> None:
        value = {
            "event": "next_cell_prestage",
            "stage_event": stage_event,
            "terminal": self.config.terminal,
            "worker_generation": self.worker_generation,
            "at_utc": _utc_now(),
            "at_monotonic": round(time.monotonic(), 6),
            **dict(detail or {}),
        }
        try:
            self.telemetry(value)
        except Exception:
            pass

    def _prepare_worker(self, current_item_id: str, cancel: threading.Event) -> None:
        _lower_thread_priority()
        try:
            early_resources = dict(self.resource_probe())
            if not early_resources.get("allowed"):
                raise PrestageError(
                    "resource_decline:"
                    + str(early_resources.get("reason") or "unspecified")
                )
            with _FleetIOSlot(self.config) as io_slot:
                if not io_slot.acquired:
                    raise PrestageError("io_budget_busy")
                snapshot = dict(self.snapshot_loader(self.worker_generation, cancel))
                if not snapshot:
                    raise PrestageError("no_candidate")
                snapshot.setdefault("terminal", self.config.terminal)
                snapshot.setdefault("worker_generation", self.worker_generation)
                self._emit(
                    "candidate_observed",
                    {
                        "current_item_id": current_item_id,
                        "candidate_item_id": (snapshot.get("item") or {}).get("id"),
                    },
                )
                plan = prepare_snapshot(
                    snapshot,
                    config=self.config,
                    cancel=cancel,
                    resource_probe=self.resource_probe,
                    candidate_is_current=self.candidate_is_current,
                    emit=self._emit,
                    io_slot_held=True,
                )
            with self._lock:
                if cancel.is_set() or self._current_item_id != current_item_id:
                    raise PrestageCancelled("current_child_changed_before_publish")
                self._prepared = plan
            self._emit(
                "prepared",
                {
                    "current_item_id": current_item_id,
                    "candidate_item_id": (plan.get("item") or {}).get("id"),
                    "token_sha256": plan.get("token_sha256"),
                    "bytes_copied": plan.get("prepared_bytes"),
                    "prepared_file_count": len(plan.get("files") or []),
                },
            )
        except PrestageCancelled as exc:
            self._emit("declined", {"reason": str(exc), "class": "cancelled"})
        except Exception as exc:
            self._emit(
                "declined",
                {
                    "reason": str(exc),
                    "class": type(exc).__name__,
                },
            )

    def child_spawned(
        self,
        *,
        item_id: str,
        pid: object,
        adopted_existing: bool = False,
    ) -> None:
        now = time.monotonic()
        gap: float | None = None
        duty_cycle: float | None = None
        if self._last_exit_monotonic is not None:
            gap = max(0.0, now - self._last_exit_monotonic)
            if self._last_runtime_seconds is not None:
                denominator = self._last_runtime_seconds + gap
                duty_cycle = (
                    self._last_runtime_seconds / denominator if denominator > 0 else 1.0
                )
        self._emit(
            "next_child_process_created",
            {
                "item_id": item_id,
                "pid": pid,
                "adopted_existing": adopted_existing,
                "idle_gap_seconds": round(gap, 3) if gap is not None else None,
                "previous_tester_runtime_seconds": (
                    round(self._last_runtime_seconds, 3)
                    if self._last_runtime_seconds is not None
                    else None
                ),
                "duty_cycle": round(duty_cycle, 6) if duty_cycle is not None else None,
            },
        )
        self._current_item_id = str(item_id)
        self._current_started_monotonic = now
        if not self.config.active:
            return
        self._cancel_running(clear_prepared=False)
        cancel = threading.Event()
        thread = threading.Thread(
            target=self._prepare_worker,
            args=(str(item_id), cancel),
            name=f"next_cell_prestage_{self.config.terminal}",
            daemon=True,
        )
        with self._lock:
            self._cancel = cancel
            self._thread = thread
        thread.start()

    def child_finished(self, *, item_id: str) -> None:
        now = time.monotonic()
        runtime: float | None = None
        if self._current_started_monotonic is not None:
            runtime = max(0.0, now - self._current_started_monotonic)
        self._last_runtime_seconds = runtime
        self._last_exit_monotonic = now
        self._emit(
            "current_child_exit",
            {
                "item_id": item_id,
                "tester_runtime_seconds": round(runtime, 3) if runtime is not None else None,
            },
        )
        cancel = self._cancel
        thread = self._thread
        if cancel is not None:
            cancel.set()
        if thread is not None and thread.is_alive():
            thread.join(self.config.cancel_join_seconds)
        with self._lock:
            self._thread = None
            self._cancel = None
        self._current_item_id = None
        self._current_started_monotonic = None

    def claim_attempt(self) -> None:
        self._emit(
            "next_claim_attempt",
            {
                "prepared_candidate_item_id": (
                    (self._prepared.get("item") or {}).get("id")
                    if self._prepared
                    else None
                )
            },
        )

    def claim_result(self, claim: Mapping[str, Any]) -> dict[str, Any] | None:
        self._emit(
            "claim_result",
            {
                "claimed": bool(claim.get("claimed")),
                "claimed_item_id": (claim.get("item") or {}).get("id"),
                "reason": claim.get("reason"),
            },
        )
        if not claim.get("claimed") or not self.config.active:
            return None
        with self._lock:
            plan = self._prepared
        if plan is None:
            self._emit("miss", {"reason": "no_prepared_plan"})
            return None
        try:
            adopted, reason = adopt_plan(
                plan,
                config=self.config,
                claim=claim,
                current_policy_generation=self.policy_generation(),
                dependency_validator=self.dependency_validator,
            )
        except Exception as exc:
            adopted = None
            reason = f"adoption_error:{type(exc).__name__}:{exc}"
        if adopted is None:
            mark_plan_missed(plan, reason)
            with self._lock:
                if self._prepared is plan:
                    self._prepared = None
            self._emit(
                "miss",
                {
                    "reason": reason,
                    "prepared_item_id": (plan.get("item") or {}).get("id"),
                    "claimed_item_id": (claim.get("item") or {}).get("id"),
                },
            )
            return None
        with self._lock:
            if self._prepared is plan:
                self._prepared = None
        self._emit(
            "adoption_complete",
            {
                "item_id": (claim.get("item") or {}).get("id"),
                "token_sha256": adopted.get("token_sha256"),
                "cache_age_seconds": round(_age_seconds(adopted), 3),
                "prepared_bytes": adopted.get("prepared_bytes"),
                "idempotent": adopted.get("idempotent"),
            },
        )
        return adopted

    def _cancel_running(self, *, clear_prepared: bool) -> None:
        cancel = self._cancel
        thread = self._thread
        if cancel is not None:
            cancel.set()
        if thread is not None and thread.is_alive():
            thread.join(self.config.cancel_join_seconds)
        with self._lock:
            self._thread = None
            self._cancel = None
            if clear_prepared:
                self._prepared = None

    def shutdown(self) -> None:
        self._cancel_running(clear_prepared=False)
        self._emit("shutdown")


__all__ = [
    "ALLOWLIST_ENV",
    "FEATURE_ENV",
    "POLICY_SCHEMA",
    "PrestageConfig",
    "PrestageController",
    "PrestageError",
    "adopt_plan",
    "cached_file",
    "cached_history_sources",
    "file_spec",
    "seal_snapshot",
    "sha256_file",
    "sha256_text",
    "validate_plan_sources",
]
