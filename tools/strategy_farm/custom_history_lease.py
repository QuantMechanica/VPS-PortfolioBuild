#!/usr/bin/env python3
"""Global Custom-history containment lease for the Variant-A migration.

The lease is activated by a separate, hash-bound mode receipt.  When active it
serializes the complete claim-to-artifact lifecycle across all runner workers.
Expiry alone never releases a record: PID creation identity must be absent or
reused, the recorded terminal must be inactive, and its database claim must be
reconciled first.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import threading
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Mapping

try:
    from custom_history_contract import canonical_bytes, utc_now, write_json_atomic
    from factory_mutation_lock import (
        _delete_windows_file_if_content_matches,
        _mark_windows_file_for_delete,
        _open_exclusive_lock,
        _read_open_descriptor,
        _write_all,
    )
    from process_identity import get_process_identity
except ImportError:  # pragma: no cover - package import path
    from tools.strategy_farm.custom_history_contract import (
        canonical_bytes,
        utc_now,
        write_json_atomic,
    )
    from tools.strategy_farm.factory_mutation_lock import (
        _delete_windows_file_if_content_matches,
        _mark_windows_file_for_delete,
        _open_exclusive_lock,
        _read_open_descriptor,
        _write_all,
    )
    from tools.strategy_farm.process_identity import get_process_identity


MODE_SCHEMA = "qm.custom-history-containment-mode/v1"
LEASE_SCHEMA = "qm.custom-history-global-lease/v1"
MODE_RELATIVE_PATH = Path("state/custom_history_containment_mode.json")
LEASE_RELATIVE_PATH = Path("state/custom_history_global.lease")
MAX_RECORD_BYTES = 64 * 1024
DEFAULT_HEARTBEAT_SECONDS = 15.0
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


class CustomHistoryLeaseError(RuntimeError):
    pass


def _mode_sha(payload: Mapping[str, Any]) -> str:
    return hashlib.sha256(
        canonical_bytes({key: value for key, value in payload.items() if key != "mode_sha256"})
    ).hexdigest()


def mode_path(root: Path) -> Path:
    return Path(root) / MODE_RELATIVE_PATH


def lease_path(root: Path) -> Path:
    return Path(root) / LEASE_RELATIVE_PATH


def build_mode_receipt(
    *,
    enabled: bool,
    reason: str,
    source: str,
    authorization_sha256: str,
    previous_mode_sha256: str | None = None,
) -> dict[str, Any]:
    if _SHA256_RE.fullmatch(str(authorization_sha256).casefold()) is None:
        raise CustomHistoryLeaseError("authorization_sha256 is required")
    if (
        previous_mode_sha256 is not None
        and _SHA256_RE.fullmatch(str(previous_mode_sha256).casefold()) is None
    ):
        raise CustomHistoryLeaseError("previous_mode_sha256 is invalid")
    payload: dict[str, Any] = {
        "schema_version": MODE_SCHEMA,
        "enabled": bool(enabled),
        "recorded_at_utc": utc_now(),
        "reason": str(reason).strip(),
        "source": str(source).strip(),
        "authorization_sha256": str(authorization_sha256).casefold(),
        "previous_mode_sha256": previous_mode_sha256,
    }
    if not payload["reason"] or not payload["source"]:
        raise CustomHistoryLeaseError("containment reason and source are required")
    payload["mode_sha256"] = _mode_sha(payload)
    return payload


def validate_mode_receipt(payload: Mapping[str, Any]) -> dict[str, Any]:
    required = {
        "schema_version",
        "enabled",
        "recorded_at_utc",
        "reason",
        "source",
        "authorization_sha256",
        "previous_mode_sha256",
        "mode_sha256",
    }
    if set(payload) != required or payload.get("schema_version") != MODE_SCHEMA:
        raise CustomHistoryLeaseError("invalid containment mode receipt schema")
    expected = _mode_sha(payload)
    if str(payload.get("mode_sha256") or "").casefold() != expected:
        raise CustomHistoryLeaseError("containment mode receipt hash mismatch")
    if not isinstance(payload.get("enabled"), bool):
        raise CustomHistoryLeaseError("containment enabled must be boolean")
    if _SHA256_RE.fullmatch(str(payload.get("authorization_sha256") or "").casefold()) is None:
        raise CustomHistoryLeaseError("containment authorization hash is invalid")
    previous = payload.get("previous_mode_sha256")
    if previous is not None and _SHA256_RE.fullmatch(str(previous).casefold()) is None:
        raise CustomHistoryLeaseError("containment previous-mode hash is invalid")
    if not str(payload.get("reason") or "").strip() or not str(payload.get("source") or "").strip():
        raise CustomHistoryLeaseError("containment reason and source are required")
    return dict(payload)


def load_mode(root: Path) -> dict[str, Any]:
    path = mode_path(root)
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError:
        return {
            "schema_version": MODE_SCHEMA,
            "enabled": False,
            "status": "NOT_CONFIGURED",
            "path": str(path),
        }
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CustomHistoryLeaseError(f"containment mode unreadable: {exc}") from exc
    if not isinstance(payload, dict):
        raise CustomHistoryLeaseError("containment mode root must be an object")
    result = validate_mode_receipt(payload)
    result["status"] = "ENGAGED" if result["enabled"] else "RELEASED"
    result["path"] = str(path)
    return result


def write_mode(root: Path, receipt: Mapping[str, Any]) -> dict[str, Any]:
    validated = validate_mode_receipt(receipt)
    write_json_atomic(mode_path(root), validated)
    return validated


def engage_emergency_mode(
    root: Path,
    *,
    reason: str,
    activation_sha256: str,
) -> dict[str, Any]:
    """Fail-safe re-engagement authorized by the active migration receipt."""

    try:
        previous = load_mode(root)
        previous_hash = previous.get("mode_sha256")
    except CustomHistoryLeaseError:
        previous_hash = None
    receipt = build_mode_receipt(
        enabled=True,
        reason=reason,
        source="automatic_stop_condition",
        authorization_sha256=activation_sha256,
        previous_mode_sha256=str(previous_hash) if previous_hash else None,
    )
    return write_mode(root, receipt)


def _record_bytes(record: Mapping[str, Any]) -> bytes:
    return (json.dumps(record, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _read_existing(path: Path) -> tuple[dict[str, Any], bytes]:
    raw = path.read_bytes()
    if not raw or len(raw) > MAX_RECORD_BYTES:
        raise CustomHistoryLeaseError("lease record is empty or oversized")
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise CustomHistoryLeaseError("lease record is invalid JSON") from exc
    if not isinstance(value, dict) or value.get("schema_version") != LEASE_SCHEMA:
        raise CustomHistoryLeaseError("lease record schema mismatch")
    return value, raw


def _default_owner_identity() -> dict[str, Any]:
    identity = get_process_identity(os.getpid())
    if not identity or not identity.get("creation_key"):
        raise CustomHistoryLeaseError("worker process creation identity unavailable")
    return identity


def _owner_state(record: Mapping[str, Any]) -> str:
    try:
        pid = int(record["owner_pid"])
    except (KeyError, TypeError, ValueError):
        return "unknown"
    identity = get_process_identity(pid)
    if identity is None or not identity.get("is_running", True):
        return "absent"
    if str(identity.get("creation_key") or "") != str(record.get("owner_creation_key") or ""):
        return "reused"
    return "live"


def _delete_posix_if_content_matches(path: Path, expected: bytes) -> str:
    try:
        actual = path.read_bytes()
    except FileNotFoundError:
        return "already_absent"
    except OSError:
        return "unreadable"
    if actual != expected:
        return "ownership_changed"
    try:
        path.unlink()
    except FileNotFoundError:
        return "already_absent"
    except OSError:
        return "unlink_failed"
    return "reaped"


@dataclass
class LeaseAcquireResult:
    required: bool
    acquired: bool
    reason: str
    handle: "LeaseHandle | None" = None
    detail: dict[str, Any] | None = None


class LeaseHandle:
    def __init__(self, path: Path, descriptor: int, record: dict[str, Any]) -> None:
        self.path = Path(path)
        self.descriptor = descriptor
        self.record = dict(record)
        self._bytes = b""
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self.released = False
        self._write_record()

    @property
    def token(self) -> str:
        return str(self.record["token"])

    def _write_record(self) -> None:
        data = _record_bytes(self.record)
        if len(data) > MAX_RECORD_BYTES:
            raise CustomHistoryLeaseError("lease record exceeds size cap")
        os.lseek(self.descriptor, 0, os.SEEK_SET)
        os.ftruncate(self.descriptor, 0)
        _write_all(self.descriptor, data)
        os.fsync(self.descriptor)
        self._bytes = data

    def heartbeat(self) -> None:
        with self._lock:
            if self.released:
                return
            self.record["heartbeat_at_utc"] = utc_now()
            self._write_record()

    def bind_work_item(self, work_item_id: str) -> None:
        with self._lock:
            if self.released:
                raise CustomHistoryLeaseError("cannot bind a released lease")
            self.record["work_item_id"] = str(work_item_id)
            self.record["heartbeat_at_utc"] = utc_now()
            self._write_record()

    def start_heartbeat(self, seconds: float = DEFAULT_HEARTBEAT_SECONDS) -> None:
        if self._thread is not None:
            return

        def run() -> None:
            while not self._stop.wait(seconds):
                try:
                    self.heartbeat()
                except Exception:
                    # The owner continues to hold the exclusive descriptor.  A
                    # failed heartbeat is surfaced by release status/worker log;
                    # it never authorizes another claimant.
                    return

        self._thread = threading.Thread(
            target=run,
            name="custom-history-lease-heartbeat",
            daemon=True,
        )
        self._thread.start()

    def release(self) -> str:
        with self._lock:
            if self.released:
                return "already_released"
            self._stop.set()
            try:
                actual = _read_open_descriptor(self.descriptor, len(self._bytes) + 1)
            except OSError:
                status = "unreadable"
            else:
                if actual != self._bytes:
                    status = "ownership_changed"
                elif os.name == "nt":
                    status = "released" if _mark_windows_file_for_delete(self.descriptor) else "unlink_failed"
                else:
                    status = _delete_posix_if_content_matches(self.path, self._bytes)
                    if status == "reaped":
                        status = "released"
            try:
                os.close(self.descriptor)
            except OSError:
                status = "close_failed"
            self.released = status in {"released", "already_absent"}
            return status

    def abandon_for_test(self) -> None:
        """Simulate process death in tests; never used by production callers."""

        self._stop.set()
        os.close(self.descriptor)
        self.released = True

    def __enter__(self) -> "LeaseHandle":
        return self

    def __exit__(self, exc_type, exc, traceback) -> None:
        self.release()


def acquire_lease(
    root: Path,
    *,
    terminal: str,
    reconcile_stale: Callable[[Mapping[str, Any]], Mapping[str, Any]],
    owner_identity: Mapping[str, Any] | None = None,
    owner_state: Callable[[Mapping[str, Any]], str] = _owner_state,
) -> LeaseAcquireResult:
    mode = load_mode(root)
    if not mode.get("enabled"):
        return LeaseAcquireResult(required=False, acquired=True, reason="containment_not_engaged")
    path = lease_path(root)
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        descriptor = _open_exclusive_lock(path)
    except FileExistsError:
        try:
            existing, raw = _read_existing(path)
        except (OSError, CustomHistoryLeaseError) as exc:
            return LeaseAcquireResult(
                required=True,
                acquired=False,
                reason="lease_busy_or_unreadable",
                detail={"error": repr(exc), "path": str(path)},
            )
        state = owner_state(existing)
        if state not in {"absent", "reused"}:
            return LeaseAcquireResult(
                required=True,
                acquired=False,
                reason="lease_owner_live" if state == "live" else "lease_owner_unknown",
                detail={"owner_state": state, "record": existing},
            )
        reconciliation = dict(reconcile_stale(existing))
        if not reconciliation.get("terminal_inactive") or not reconciliation.get("claim_reconciled"):
            return LeaseAcquireResult(
                required=True,
                acquired=False,
                reason="stale_lease_not_reconciled",
                detail={"owner_state": state, "reconciliation": reconciliation},
            )
        delete_status = (
            _delete_windows_file_if_content_matches(path, raw)
            if os.name == "nt"
            else _delete_posix_if_content_matches(path, raw)
        )
        if delete_status not in {"reaped", "already_absent"}:
            return LeaseAcquireResult(
                required=True,
                acquired=False,
                reason="stale_lease_reap_failed",
                detail={"delete_status": delete_status, "owner_state": state},
            )
        try:
            descriptor = _open_exclusive_lock(path)
        except FileExistsError:
            return LeaseAcquireResult(
                required=True,
                acquired=False,
                reason="lease_race_lost_after_reconcile",
            )
    identity = dict(owner_identity or _default_owner_identity())
    creation_key = str(identity.get("creation_key") or "")
    if not creation_key:
        os.close(descriptor)
        try:
            path.unlink()
        except OSError:
            pass
        raise CustomHistoryLeaseError("owner creation identity missing")
    acquired_at = utc_now()
    record = {
        "schema_version": LEASE_SCHEMA,
        "token": uuid.uuid4().hex,
        "mode_sha256": mode["mode_sha256"],
        "owner_pid": os.getpid(),
        "owner_creation_key": creation_key,
        "owner_image_path": str(identity.get("image_path") or ""),
        "terminal": str(terminal).upper(),
        "work_item_id": None,
        "acquired_at_utc": acquired_at,
        "heartbeat_at_utc": acquired_at,
    }
    try:
        handle = LeaseHandle(path, descriptor, record)
    except Exception:
        os.close(descriptor)
        try:
            path.unlink()
        except OSError:
            pass
        raise
    handle.start_heartbeat()
    return LeaseAcquireResult(
        required=True,
        acquired=True,
        reason="lease_acquired",
        handle=handle,
        detail={"token": handle.token, "mode_sha256": mode["mode_sha256"]},
    )
