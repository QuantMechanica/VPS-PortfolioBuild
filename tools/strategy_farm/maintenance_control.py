#!/usr/bin/env python3
"""Guarded, auditable maintenance transitions for Strategy Farm work items.

Dry-run is the default.  ``apply`` requires exact SHA-256 bindings for both the
SQLite database and the current FACTORY_OFF flag plus a fresh SQLite snapshot.
The raw work-item row is changed only after its expected pre-state matches; the
before/after transition is recorded in an append-only ledger and in ``events``.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence

from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag
from factory_runtime_activation import (
    RuntimeActivationError,
    validate_runtime_activation_decision,
)


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_FACTORY_OFF = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
DEFAULT_FACTORY_OFF_REQUEST = Path(
    r"D:\QM\strategy_farm\state\FACTORY_OFF_REQUEST.flag"
)
DEFAULT_MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
DEFAULT_DISABLED_TERMINALS = Path(
    r"D:\QM\strategy_farm\state\disabled_terminals.txt"
)

CANONICAL_FACTORY_ON_PATH = Path(r"C:\QM\repo\tools\strategy_farm\Factory_ON.ps1")
CANONICAL_OWNER_DECISION_RELATIVE_PATH = Path(
    "docs/ops/evidence/2026-08-04_factory_preparation_owner_decision_evening.json"
)
CANONICAL_OWNER_DECISION_SHA256 = (
    "9443119ec3ae3bf7ac75a244594ce7baba558400ec686796ee9f1f3347734396"
)
CANONICAL_OWNER_DECISION_COMMIT = "d76c9225c62f50e9c3dc78b592e2111b96f36275"
CANONICAL_OWNER_DECISION_BLOB = "415cede6845b9525fed714b61f5a2c42c7fe81a3"
CANONICAL_WORKER_TERMINALS = (
    "T1",
    "T2",
    "T3",
    "T4",
    "T5",
    "T6",
    "T7",
    "T8",
    "T9",
    "T10",
)
FACTORY_ON_LOCK_OWNER = "factory_on_restart_window"
CANONICAL_FACTORY_ON_PROCESS_IMAGE = Path(
    r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
)

ALLOWED_ACTIONS = {"hold", "requeue_hold", "quarantine"}
ALLOWED_STATUSES = {"pending", "active", "done", "failed"}
WORK_ITEM_ID_RE = re.compile(r"[0-9a-fA-F-]{36}")


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sqlite_state_sha256(path: Path) -> str:
    """Hash the logical SQLite image, including committed WAL-visible pages."""
    with connect_ro(path) as conn:
        try:
            image = conn.serialize()
        except AttributeError as exc:  # pragma: no cover - Python < 3.11
            raise RuntimeError("sqlite3.Connection.serialize() is required") from exc
    return hashlib.sha256(image).hexdigest()


def checkpoint_wal(path: Path) -> dict[str, int]:
    """Checkpoint every committed WAL frame before the post-state file hash."""
    with sqlite3.connect(path, timeout=30, isolation_level=None) as conn:
        conn.execute("PRAGMA busy_timeout=30000")
        row = conn.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()
    busy, log_frames, checkpointed = (int(value or 0) for value in row)
    if busy:
        raise RuntimeError(
            f"SQLite WAL checkpoint remained busy (log={log_frames}, checkpointed={checkpointed})"
        )
    return {"busy": busy, "log_frames": log_frames, "checkpointed_frames": checkpointed}


def connect_ro(path: Path) -> sqlite3.Connection:
    uri = path.resolve().as_uri() + "?mode=ro"
    conn = sqlite3.connect(uri, uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def connect_rw(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(path, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS work_item_holds (
    work_item_id TEXT PRIMARY KEY,
    hold_code TEXT NOT NULL,
    reason TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
    release_on_restart INTEGER NOT NULL DEFAULT 0 CHECK (release_on_restart IN (0,1)),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    released_at TEXT,
    release_note TEXT
);
CREATE INDEX IF NOT EXISTS idx_work_item_holds_active
    ON work_item_holds(active, release_on_restart);

CREATE TABLE IF NOT EXISTS work_item_transition_ledger (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    idempotency_key TEXT NOT NULL UNIQUE,
    ts TEXT NOT NULL,
    work_item_id TEXT NOT NULL,
    action TEXT NOT NULL,
    from_status TEXT,
    to_status TEXT,
    from_verdict TEXT,
    to_verdict TEXT,
    from_claimed_by TEXT,
    to_claimed_by TEXT,
    reason TEXT NOT NULL,
    run_id TEXT,
    detail_json TEXT NOT NULL
);
CREATE TRIGGER IF NOT EXISTS trg_work_item_transition_ledger_no_update
BEFORE UPDATE ON work_item_transition_ledger
BEGIN
    SELECT RAISE(ABORT, 'work_item_transition_ledger is append-only');
END;
CREATE TRIGGER IF NOT EXISTS trg_work_item_transition_ledger_no_delete
BEFORE DELETE ON work_item_transition_ledger
BEGIN
    SELECT RAISE(ABORT, 'work_item_transition_ledger is append-only');
END;

CREATE TABLE IF NOT EXISTS agent_task_transition_ledger (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    idempotency_key TEXT NOT NULL UNIQUE,
    ts TEXT NOT NULL,
    task_id TEXT NOT NULL,
    action TEXT NOT NULL,
    from_state TEXT NOT NULL,
    to_state TEXT NOT NULL,
    reason TEXT NOT NULL,
    detail_json TEXT NOT NULL
);
CREATE TRIGGER IF NOT EXISTS trg_agent_task_transition_ledger_no_update
BEFORE UPDATE ON agent_task_transition_ledger
BEGIN
    SELECT RAISE(ABORT, 'agent_task_transition_ledger is append-only');
END;
CREATE TRIGGER IF NOT EXISTS trg_agent_task_transition_ledger_no_delete
BEFORE DELETE ON agent_task_transition_ledger
BEGIN
    SELECT RAISE(ABORT, 'agent_task_transition_ledger is append-only');
END;
"""


def load_manifest(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(payload, dict):
        raise ValueError("manifest must be a JSON object")
    run_id = str(payload.get("run_id") or "").strip()
    if not run_id:
        raise ValueError("manifest.run_id is required")
    operations = payload.get("operations")
    if not isinstance(operations, list) or not operations:
        raise ValueError("manifest.operations must be a non-empty array")
    seen: set[str] = set()
    normalized: list[dict[str, Any]] = []
    for index, raw in enumerate(operations):
        if not isinstance(raw, dict):
            raise ValueError(f"operations[{index}] must be an object")
        op = dict(raw)
        work_item_id = str(op.get("work_item_id") or "").strip()
        action = str(op.get("action") or "").strip()
        if not work_item_id or work_item_id in seen:
            raise ValueError(f"operations[{index}].work_item_id is missing or duplicated")
        if action not in ALLOWED_ACTIONS:
            raise ValueError(f"operations[{index}].action must be one of {sorted(ALLOWED_ACTIONS)}")
        expected = op.get("expected")
        if not isinstance(expected, dict) or not expected.get("status"):
            raise ValueError(f"operations[{index}].expected.status is required")
        if expected["status"] not in ALLOWED_STATUSES:
            raise ValueError(f"operations[{index}].expected.status is invalid")
        hold_code = str(op.get("hold_code") or "").strip()
        reason = str(op.get("reason") or "").strip()
        if not hold_code or not reason:
            raise ValueError(f"operations[{index}] requires hold_code and reason")
        if action == "quarantine":
            op.setdefault("to_status", "failed")
            op.setdefault("to_verdict", "BLOCKED_MAINTENANCE")
            op.setdefault("release_on_restart", False)
        elif action == "requeue_hold":
            op.setdefault("to_status", "pending")
            op.setdefault("to_verdict", None)
            op.setdefault("release_on_restart", True)
        else:
            op.setdefault("to_status", expected["status"])
            op.setdefault("to_verdict", expected.get("verdict"))
            op.setdefault("release_on_restart", False)
        if op["to_status"] not in ALLOWED_STATUSES:
            raise ValueError(f"operations[{index}].to_status is invalid")
        op["work_item_id"] = work_item_id
        op["action"] = action
        op["hold_code"] = hold_code
        op["reason"] = reason
        op["idempotency_key"] = str(
            op.get("idempotency_key") or f"{run_id}:{index:03d}:{work_item_id}:{action}"
        )
        seen.add(work_item_id)
        normalized.append(op)
    return {**payload, "run_id": run_id, "operations": normalized}


def _row_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {key: row[key] for key in row.keys()}


def _expected_mismatches(row: sqlite3.Row, expected: dict[str, Any]) -> list[str]:
    mismatches: list[str] = []
    for key in ("status", "verdict", "claimed_by", "phase", "ea_id", "symbol"):
        if key in expected and row[key] != expected[key]:
            mismatches.append(f"{key}: expected={expected[key]!r} actual={row[key]!r}")
    return mismatches


def inspect_manifest(db: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    errors: list[str] = []
    with connect_ro(db) as conn:
        ledger_available = conn.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='work_item_transition_ledger'"
        ).fetchone() is not None
        holds_available = conn.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='work_item_holds'"
        ).fetchone() is not None
        for op in manifest["operations"]:
            row = conn.execute("SELECT * FROM work_items WHERE id=?", (op["work_item_id"],)).fetchone()
            if row is None:
                errors.append(f"missing work_item {op['work_item_id']}")
                rows.append({"operation": op, "found": False})
                continue
            prior_ledger = None
            if ledger_available:
                prior_ledger = conn.execute(
                    "SELECT seq, work_item_id FROM work_item_transition_ledger WHERE idempotency_key=?",
                    (op["idempotency_key"],),
                ).fetchone()
            if prior_ledger is not None:
                post_mismatches: list[str] = []
                if prior_ledger["work_item_id"] != op["work_item_id"]:
                    post_mismatches.append("ledger work_item_id does not match manifest")
                expected_post = {
                    "status": op["to_status"],
                    "verdict": op.get("to_verdict"),
                    "claimed_by": None,
                }
                post_mismatches.extend(_expected_mismatches(row, expected_post))
                hold = None
                if holds_available:
                    hold = conn.execute(
                        "SELECT hold_code, active, release_on_restart FROM work_item_holds WHERE work_item_id=?",
                        (op["work_item_id"],),
                    ).fetchone()
                if hold is None:
                    post_mismatches.append("maintenance hold is missing")
                else:
                    if hold["hold_code"] != op["hold_code"]:
                        post_mismatches.append(
                            f"hold_code: expected={op['hold_code']!r} actual={hold['hold_code']!r}"
                        )
                    if int(hold["active"]) != 1:
                        post_mismatches.append("maintenance hold is not active")
                    if int(hold["release_on_restart"]) != int(bool(op.get("release_on_restart"))):
                        post_mismatches.append("release_on_restart does not match manifest")
                if post_mismatches:
                    errors.extend(f"{op['work_item_id']}: {item}" for item in post_mismatches)
                rows.append({
                    "operation": op,
                    "found": True,
                    "already_applied": True,
                    "ledger_seq": prior_ledger["seq"],
                    "current": {
                        key: row[key]
                        for key in ("id", "phase", "ea_id", "symbol", "status", "verdict", "claimed_by")
                    },
                    "mismatches": post_mismatches,
                })
                continue
            mismatches = _expected_mismatches(row, op["expected"])
            if mismatches:
                errors.extend(f"{op['work_item_id']}: {item}" for item in mismatches)
            rows.append({
                "operation": op,
                "found": True,
                "current": {
                    key: row[key]
                    for key in ("id", "phase", "ea_id", "symbol", "status", "verdict", "claimed_by")
                },
                "mismatches": mismatches,
            })
    return {
        "mode": "dry_run",
        "run_id": manifest["run_id"],
        "db": str(db),
        "db_sha256": sha256_file(db),
        "db_state_sha256": sqlite_state_sha256(db),
        "valid": not errors,
        "errors": errors,
        "operations": rows,
    }


def _reject_duplicate_json_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise RuntimeError(f"duplicate JSON key in guarded record: {key}")
        result[key] = value
    return result


def _canonical_repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _validated_restart_hold_ids(value: Any, *, label: str) -> list[str]:
    if not isinstance(value, list):
        raise RuntimeError(f"{label} must be a list")
    if any(
        not isinstance(work_item_id, str)
        or not work_item_id
        or WORK_ITEM_ID_RE.fullmatch(work_item_id) is None
        for work_item_id in value
    ):
        raise RuntimeError(f"{label} must contain UUID-shaped strings")
    if len(value) != len(set(value)):
        raise RuntimeError(f"{label} must contain unique strings")
    return list(value)


def _runtime_restart_hold_ids(runtime_authorization: dict[str, Any]) -> list[str]:
    return _validated_restart_hold_ids(
        runtime_authorization.get("restart_hold_ids"),
        label="runtime authorization restart_hold_ids",
    )


def _validate_canonical_restart_owner_decision() -> dict[str, Any]:
    """Verify immutable OWNER provenance and return the pinned decision payload."""

    repo_root = _canonical_repo_root()
    decision_path = repo_root / CANONICAL_OWNER_DECISION_RELATIVE_PATH
    try:
        raw = decision_path.read_bytes()
    except OSError as exc:
        raise RuntimeError(
            f"canonical OWNER decision cannot be read: {decision_path}: {exc}"
        ) from exc
    actual_sha256 = hashlib.sha256(raw).hexdigest()
    if actual_sha256 != CANONICAL_OWNER_DECISION_SHA256:
        raise RuntimeError(
            "canonical OWNER decision SHA-256 mismatch: "
            f"expected={CANONICAL_OWNER_DECISION_SHA256} actual={actual_sha256}"
        )
    actual_blob = hashlib.sha1(
        f"blob {len(raw)}\0".encode("ascii") + raw,
        usedforsecurity=False,
    ).hexdigest()
    if actual_blob != CANONICAL_OWNER_DECISION_BLOB:
        raise RuntimeError(
            "canonical OWNER decision Git blob mismatch: "
            f"expected={CANONICAL_OWNER_DECISION_BLOB} actual={actual_blob}"
        )
    try:
        payload = json.loads(
            raw.decode("utf-8"), object_pairs_hook=_reject_duplicate_json_keys
        )
    except (UnicodeDecodeError, json.JSONDecodeError, RuntimeError) as exc:
        raise RuntimeError(f"canonical OWNER decision is invalid: {exc}") from exc
    if not isinstance(payload, dict):
        raise RuntimeError("canonical OWNER decision must be a JSON object")

    expected_scalar = {
        "decision_id": "FACTORY_PREPARATION_20260804_EVENING_TEN_WORKER_ZERO_HOLD",
        "authority": "OWNER",
        "status": "APPROVED",
    }
    actual_scalar = {key: payload.get(key) for key in expected_scalar}
    if actual_scalar != expected_scalar:
        raise RuntimeError(
            "canonical OWNER decision identity mismatch: "
            f"expected={expected_scalar!r} actual={actual_scalar!r}"
        )
    restart_holds = payload.get("restart_holds")
    worker_policy = payload.get("worker_policy")
    if not isinstance(restart_holds, dict) or not isinstance(worker_policy, dict):
        raise RuntimeError("canonical OWNER decision lacks restart_holds/worker_policy")
    restart_hold_ids = _validated_restart_hold_ids(
        restart_holds.get("authorized_work_item_ids"),
        label="canonical OWNER authorized_work_item_ids",
    )
    if (
        type(restart_holds.get("authorized_release_count")) is not int
        or restart_holds.get("authorized_release_count") != len(restart_hold_ids)
        or restart_holds.get("release_policy")
        != "ONLY_AFTER_POST_START_HEALTH_GATE_PASS"
    ):
        raise RuntimeError("canonical OWNER restart-hold authorization mismatch")
    if (
        worker_policy.get("t5_quarantine_ratified") is not False
        or worker_policy.get("t5_quarantine_lifted") is not True
        or worker_policy.get("expected_terminals") != list(CANONICAL_WORKER_TERMINALS)
        or worker_policy.get("expected_worker_count") != len(CANONICAL_WORKER_TERMINALS)
    ):
        raise RuntimeError("canonical OWNER worker policy mismatch")
    if (
        payload.get("restore_intent", {}).get("factory_on_authorized") is not False
        or payload.get("restore_intent", {}).get("runtime_flag_upgrade_authorized")
        is not False
        or payload.get("explicit_exclusions", {}).get("hold_release_now") is not False
    ):
        raise RuntimeError(
            "preparation decision semantics changed; it must remain non-runtime authority"
        )

    commit_spec = f"{CANONICAL_OWNER_DECISION_COMMIT}^{{commit}}"
    blob_spec = (
        f"{CANONICAL_OWNER_DECISION_COMMIT}:"
        f"{CANONICAL_OWNER_DECISION_RELATIVE_PATH.as_posix()}"
    )
    try:
        provenance = subprocess.run(
            ["git", "-C", str(repo_root), "rev-parse", commit_spec, blob_spec],
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="strict",
            timeout=15,
        )
    except (OSError, subprocess.SubprocessError, UnicodeError) as exc:
        raise RuntimeError(f"canonical OWNER Git provenance cannot be verified: {exc}") from exc
    resolved = [line.strip().lower() for line in provenance.stdout.splitlines() if line.strip()]
    expected_provenance = [
        CANONICAL_OWNER_DECISION_COMMIT,
        CANONICAL_OWNER_DECISION_BLOB,
    ]
    if provenance.returncode != 0 or resolved != expected_provenance:
        raise RuntimeError(
            "canonical OWNER Git provenance mismatch: "
            f"expected={expected_provenance!r} actual={resolved!r} "
            f"stderr={provenance.stderr.strip()!r}"
        )
    return payload


def _same_path(left: Path, right: Path) -> bool:
    return os.path.normcase(str(left.resolve(strict=False))) == os.path.normcase(
        str(right.resolve(strict=False))
    )


def _require_canonical_restart_release_paths(
    db: Path, factory_off_flag: Path, lock_path: Path
) -> None:
    mismatches: list[str] = []
    for label, actual, expected in (
        ("db", db, DEFAULT_DB),
        ("factory_off_flag", factory_off_flag, DEFAULT_FACTORY_OFF),
        ("mutation_lock", lock_path, DEFAULT_MUTATION_LOCK),
    ):
        if not _same_path(Path(actual), expected):
            mismatches.append(f"{label}={actual!s} expected={expected!s}")
    if mismatches:
        raise RuntimeError(
            "release-on-restart apply is restricted to canonical production paths: "
            + "; ".join(mismatches)
        )


def _is_lock_actively_held(lock_path: Path) -> bool:
    """Prove another process still owns a non-write-sharing Windows handle."""

    if os.name != "nt":
        return False
    import ctypes
    from ctypes import wintypes

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    create_file = kernel32.CreateFileW
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
    handle = create_file(
        str(lock_path),
        0x40000000,  # GENERIC_WRITE: conflicts with Factory_ON's FileShare.Read
        0x00000001 | 0x00000002 | 0x00000004,
        None,
        3,  # OPEN_EXISTING
        0x00000080,
        None,
    )
    invalid_handle = ctypes.c_void_p(-1).value
    if handle == invalid_handle:
        error = ctypes.get_last_error()
        if error == 32:  # ERROR_SHARING_VIOLATION
            return True
        raise RuntimeError(
            f"canonical Factory_ON lock liveness probe failed: winerror={error}"
        )
    close_handle = kernel32.CloseHandle
    close_handle.argtypes = (wintypes.HANDLE,)
    close_handle.restype = wintypes.BOOL
    close_handle(handle)
    return False


def _windows_command_line_args(command_line: str) -> list[str]:
    if os.name != "nt" or not command_line.strip():
        raise RuntimeError("canonical Factory_ON parent command line is unavailable")
    import ctypes
    from ctypes import wintypes

    shell32 = ctypes.WinDLL("shell32", use_last_error=True)
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    command_line_to_argv = shell32.CommandLineToArgvW
    command_line_to_argv.argtypes = (
        wintypes.LPCWSTR,
        ctypes.POINTER(ctypes.c_int),
    )
    command_line_to_argv.restype = ctypes.POINTER(wintypes.LPWSTR)
    local_free = kernel32.LocalFree
    local_free.argtypes = (wintypes.HLOCAL,)
    local_free.restype = wintypes.HLOCAL
    argc = ctypes.c_int()
    argv = command_line_to_argv(command_line, ctypes.byref(argc))
    if not argv:
        raise RuntimeError("canonical Factory_ON parent command line cannot be tokenized")
    try:
        return [argv[index] for index in range(argc.value)]
    finally:
        local_free(argv)


def _query_windows_process_identity(pid: int) -> dict[str, Any]:
    if os.name != "nt" or pid <= 0:
        raise RuntimeError("canonical Factory_ON parent identity requires Windows and a live PID")
    probe = (
        "$ErrorActionPreference='Stop';"
        f"$c=Get-CimInstance Win32_Process -Filter \"ProcessId={pid}\";"
        "if($null -eq $c){throw 'missing process'};"
        f"$p=Get-Process -Id {pid} -ErrorAction Stop;"
        "[ordered]@{"
        "process_id=[int64]$c.ProcessId;"
        "executable_path=[string]$c.ExecutablePath;"
        "command_line=[string]$c.CommandLine;"
        "session_id=[int]$c.SessionId;"
        "process_started_at_utc=$p.StartTime.ToUniversalTime().ToString('o')"
        "}|ConvertTo-Json -Compress"
    )
    try:
        result = subprocess.run(
            (
                str(CANONICAL_FACTORY_ON_PROCESS_IMAGE),
                "-NoProfile",
                "-NonInteractive",
                "-Command",
                probe,
            ),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="strict",
            timeout=20,
            check=False,
        )
    except (OSError, subprocess.SubprocessError, UnicodeError) as exc:
        raise RuntimeError(f"canonical Factory_ON parent process probe failed: {exc}") from exc
    if result.returncode != 0:
        raise RuntimeError(
            "canonical Factory_ON parent process probe failed: "
            f"{result.stderr.strip()}"
        )
    try:
        identity = json.loads(result.stdout)
    except (json.JSONDecodeError, TypeError) as exc:
        raise RuntimeError("canonical Factory_ON parent process probe returned invalid JSON") from exc
    if not isinstance(identity, dict):
        raise RuntimeError("canonical Factory_ON parent process identity is not an object")
    return identity


def _parse_lock_utc(value: Any, *, label: str) -> dt.datetime:
    if not isinstance(value, str):
        raise RuntimeError(f"canonical Factory_ON {label} is missing")
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise RuntimeError(f"canonical Factory_ON {label} is invalid") from exc
    if parsed.tzinfo is None:
        raise RuntimeError(f"canonical Factory_ON {label} is not timezone-aware")
    return parsed.astimezone(dt.UTC)


def _windows_process_session_id(pid: int) -> int:
    if os.name != "nt":
        raise RuntimeError("Windows session validation is unavailable")
    import ctypes
    from ctypes import wintypes

    session_id = wintypes.DWORD()
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    process_id_to_session = kernel32.ProcessIdToSessionId
    process_id_to_session.argtypes = (wintypes.DWORD, ctypes.POINTER(wintypes.DWORD))
    process_id_to_session.restype = wintypes.BOOL
    if not process_id_to_session(int(pid), ctypes.byref(session_id)):
        raise RuntimeError(f"cannot resolve Windows session for PID {pid}")
    return int(session_id.value)


def _parent_handle_targets_lock(
    parent_pid: int, parent_handle_value: int, lock_path: Path
) -> bool:
    """Duplicate the claimed parent handle and compare its Windows file ID."""

    if os.name != "nt" or parent_pid <= 0 or parent_handle_value <= 0:
        return False
    import ctypes
    from ctypes import wintypes

    class ByHandleFileInformation(ctypes.Structure):
        _fields_ = [
            ("file_attributes", wintypes.DWORD),
            ("creation_time", wintypes.FILETIME),
            ("last_access_time", wintypes.FILETIME),
            ("last_write_time", wintypes.FILETIME),
            ("volume_serial_number", wintypes.DWORD),
            ("file_size_high", wintypes.DWORD),
            ("file_size_low", wintypes.DWORD),
            ("number_of_links", wintypes.DWORD),
            ("file_index_high", wintypes.DWORD),
            ("file_index_low", wintypes.DWORD),
        ]

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    open_process = kernel32.OpenProcess
    open_process.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
    open_process.restype = wintypes.HANDLE
    duplicate_handle = kernel32.DuplicateHandle
    duplicate_handle.argtypes = (
        wintypes.HANDLE,
        wintypes.HANDLE,
        wintypes.HANDLE,
        ctypes.POINTER(wintypes.HANDLE),
        wintypes.DWORD,
        wintypes.BOOL,
        wintypes.DWORD,
    )
    duplicate_handle.restype = wintypes.BOOL
    get_current_process = kernel32.GetCurrentProcess
    get_current_process.argtypes = ()
    get_current_process.restype = wintypes.HANDLE
    get_file_information = kernel32.GetFileInformationByHandle
    get_file_information.argtypes = (
        wintypes.HANDLE,
        ctypes.POINTER(ByHandleFileInformation),
    )
    get_file_information.restype = wintypes.BOOL
    close_handle = kernel32.CloseHandle
    close_handle.argtypes = (wintypes.HANDLE,)
    close_handle.restype = wintypes.BOOL
    process = open_process(0x0040, False, int(parent_pid))  # PROCESS_DUP_HANDLE
    if not process:
        return False
    duplicated = wintypes.HANDLE()
    path_handle = wintypes.HANDLE()
    try:
        if not duplicate_handle(
            process,
            wintypes.HANDLE(parent_handle_value),
            get_current_process(),
            ctypes.byref(duplicated),
            0,
            False,
            0x00000002,  # DUPLICATE_SAME_ACCESS
        ):
            return False
        create_file = kernel32.CreateFileW
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
        path_handle = create_file(
            str(lock_path),
            0x80000000,
            0x00000001 | 0x00000002 | 0x00000004,
            None,
            3,
            0x00000080,
            None,
        )
        if path_handle == ctypes.c_void_p(-1).value:
            return False
        duplicated_info = ByHandleFileInformation()
        path_info = ByHandleFileInformation()
        if not get_file_information(
            duplicated, ctypes.byref(duplicated_info)
        ) or not get_file_information(
            path_handle, ctypes.byref(path_info)
        ):
            return False
        return (
            duplicated_info.volume_serial_number,
            duplicated_info.file_index_high,
            duplicated_info.file_index_low,
        ) == (
            path_info.volume_serial_number,
            path_info.file_index_high,
            path_info.file_index_low,
        )
    finally:
        if duplicated:
            close_handle(duplicated)
        if path_handle and path_handle != ctypes.c_void_p(-1).value:
            close_handle(path_handle)
        close_handle(process)


def _validate_canonical_factory_on_lock(
    lock_path: Path,
    *,
    expected_nonce: str,
    runtime_authorization: dict[str, Any],
) -> dict[str, Any]:
    """Authenticate the live parent-held lock created by canonical Factory_ON."""

    if not expected_nonce.strip():
        raise RuntimeError("canonical Factory_ON lock nonce is missing")
    try:
        payload = json.loads(
            lock_path.read_text(encoding="utf-8-sig"),
            object_pairs_hook=_reject_duplicate_json_keys,
        )
    except Exception as exc:
        raise RuntimeError(
            f"canonical Factory_ON lock cannot be authenticated: {lock_path}: {exc}"
        ) from exc
    restart_hold_ids = _runtime_restart_hold_ids(runtime_authorization)
    factory_source = runtime_authorization.get("source_bindings", {}).get("factory_on", {})
    expected = {
        "pid": os.getppid(),
        "owner": FACTORY_ON_LOCK_OWNER,
        "nonce": expected_nonce,
        "process_image": str(CANONICAL_FACTORY_ON_PROCESS_IMAGE),
        "factory_on_path": str(CANONICAL_FACTORY_ON_PATH),
        "owner_decision_sha256": CANONICAL_OWNER_DECISION_SHA256,
        "owner_decision_commit": CANONICAL_OWNER_DECISION_COMMIT,
        "owner_decision_blob": CANONICAL_OWNER_DECISION_BLOB,
        "restart_hold_ids": restart_hold_ids,
        "runtime_decision_id": runtime_authorization.get("decision_id"),
        "runtime_activation_nonce": runtime_authorization.get("activation_nonce"),
        "runtime_decision_sha256": runtime_authorization.get("decision_sha256"),
        "runtime_decision_commit": runtime_authorization.get("decision_git_commit"),
        "runtime_decision_blob": runtime_authorization.get("decision_git_blob"),
        "factory_on_source_sha256": factory_source.get("sha256"),
        "factory_on_source_commit": factory_source.get("git_commit"),
        "factory_on_source_blob": factory_source.get("git_blob"),
        "factory_off_flag_sha256": runtime_authorization.get(
            "factory_off_flag_sha256"
        ),
        "factory_off_request_path": str(DEFAULT_FACTORY_OFF_REQUEST),
        "task_enabled_before_sha256": runtime_authorization.get(
            "task_enabled_before_sha256"
        ),
    }
    actual = {key: payload.get(key) for key in expected}
    if actual != expected:
        raise RuntimeError(
            "canonical Factory_ON lock identity mismatch: "
            f"expected={expected!r} actual={actual!r}"
        )
    parent_pid = os.getppid()
    identity = _query_windows_process_identity(parent_pid)
    if int(identity.get("process_id", -1)) != parent_pid:
        raise RuntimeError("canonical Factory_ON live parent PID mismatch")
    actual_image = Path(str(identity.get("executable_path") or ""))
    if not _same_path(actual_image, CANONICAL_FACTORY_ON_PROCESS_IMAGE):
        raise RuntimeError(
            "canonical Factory_ON parent image mismatch: "
            f"actual={actual_image} expected={CANONICAL_FACTORY_ON_PROCESS_IMAGE}"
        )
    argv = _windows_command_line_args(str(identity.get("command_line") or ""))
    canonical_argv = [
        str(CANONICAL_FACTORY_ON_PROCESS_IMAGE),
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(CANONICAL_FACTORY_ON_PATH),
        "-CanonicalRuntimeHost",
    ]
    allowed_argv = (canonical_argv, canonical_argv + ["-NoPause"])
    folded_argv = [item.casefold() for item in argv]
    if folded_argv not in ([item.casefold() for item in allowed] for allowed in allowed_argv):
        raise RuntimeError(
            "canonical Factory_ON parent argv mismatch; exact -File host required and "
            "-Command/-EncodedCommand/extras are forbidden"
        )
    session_id = identity.get("session_id")
    if (
        not isinstance(payload.get("session_id"), int)
        or int(session_id) != payload["session_id"]
        or _windows_process_session_id(os.getpid()) != payload["session_id"]
    ):
        raise RuntimeError("canonical Factory_ON parent/child session identity mismatch")
    process_started = _parse_lock_utc(
        identity.get("process_started_at_utc"), label="live parent start time"
    )
    recorded_process_started = _parse_lock_utc(
        payload.get("process_started_at_utc"), label="recorded parent start time"
    )
    lock_created = _parse_lock_utc(payload.get("created_at"), label="lock creation time")
    now = dt.datetime.now(dt.UTC)
    if abs((process_started - recorded_process_started).total_seconds()) > 1:
        raise RuntimeError("canonical Factory_ON recorded parent start time mismatch")
    if lock_created < process_started or lock_created > now + dt.timedelta(seconds=5):
        raise RuntimeError("canonical Factory_ON lock creation time is inconsistent")
    if now - lock_created > dt.timedelta(minutes=30):
        raise RuntimeError("canonical Factory_ON lock is stale")
    if not _is_lock_actively_held(lock_path):
        raise RuntimeError(
            "canonical Factory_ON lock is not actively held by the parent process"
        )
    handle_value = payload.get("lock_handle_value")
    if (
        not isinstance(handle_value, int)
        or not _parent_handle_targets_lock(parent_pid, handle_value, lock_path)
    ):
        raise RuntimeError(
            "canonical Factory_ON parent handle does not identify the mutation-lock file"
        )
    expected_disabled_sha = payload.get("disabled_terminals_sha256")
    if (
        not isinstance(expected_disabled_sha, str)
        or re.fullmatch(r"[0-9a-f]{64}", expected_disabled_sha) is None
    ):
        raise RuntimeError("canonical Factory_ON lock lacks disabled-terminal SHA-256")
    try:
        disabled_raw = DEFAULT_DISABLED_TERMINALS.read_bytes()
        disabled_text = disabled_raw.decode("utf-8-sig")
    except (OSError, UnicodeError) as exc:
        raise RuntimeError(
            f"canonical disabled-terminal policy cannot be verified: {exc}"
        ) from exc
    actual_disabled_sha = hashlib.sha256(disabled_raw).hexdigest()
    disabled_rows = tuple(
        line.strip().upper()
        for line in disabled_text.splitlines()
        if line.strip()
    )
    # The expected disabled set is generation content and comes from the
    # validated runtime decision's worker policy — never a code literal
    # (nine-worker leftover ("T5",) blocked the 2026-08-02 zero-disabled
    # activation with expected_sha == actual_sha).
    authorized_disabled = runtime_authorization.get(
        "worker_policy_disabled_terminals"
    )
    if not isinstance(authorized_disabled, list) or not all(
        isinstance(item, str) and item.strip() for item in authorized_disabled
    ):
        raise RuntimeError(
            "runtime authorization lacks the worker-policy disabled-terminal list"
        )
    expected_disabled_rows = tuple(
        item.strip().upper() for item in authorized_disabled
    )
    if (
        actual_disabled_sha != expected_disabled_sha
        or disabled_rows != expected_disabled_rows
    ):
        raise RuntimeError(
            "canonical disabled-terminal policy changed under Factory_ON lock: "
            f"expected_sha={expected_disabled_sha} actual_sha={actual_disabled_sha} "
            f"rows={disabled_rows!r}"
        )
    return payload


def sqlite_snapshot(source: Path, target: Path) -> str:
    if target.exists():
        raise FileExistsError(f"snapshot target already exists: {target}")
    target.parent.mkdir(parents=True, exist_ok=True)
    src = sqlite3.connect(source, timeout=30)
    dst = sqlite3.connect(target)
    try:
        src.backup(dst)
    finally:
        dst.close()
        src.close()
    return sha256_file(target)


def _verify_apply_bindings(
    db: Path,
    factory_off_flag: Path,
    expected_db_sha256: str,
    expected_db_state_sha256: str,
    expected_factory_off_sha256: str,
) -> tuple[str, str, str]:
    if not factory_off_flag.is_file():
        raise RuntimeError(f"FACTORY_OFF flag missing: {factory_off_flag}")
    actual_db = sha256_file(db)
    actual_state = sqlite_state_sha256(db)
    actual_flag = sha256_file(factory_off_flag)
    if actual_db.lower() != expected_db_sha256.strip().lower():
        raise RuntimeError(f"DB SHA-256 mismatch: expected {expected_db_sha256}, actual {actual_db}")
    if actual_state.lower() != expected_db_state_sha256.strip().lower():
        raise RuntimeError(
            f"logical DB state SHA-256 mismatch: expected {expected_db_state_sha256}, actual {actual_state}"
        )
    if actual_flag.lower() != expected_factory_off_sha256.strip().lower():
        raise RuntimeError(
            f"FACTORY_OFF SHA-256 mismatch: expected {expected_factory_off_sha256}, actual {actual_flag}"
        )
    return actual_db, actual_state, actual_flag


def apply_manifest(
    db: Path,
    manifest: dict[str, Any],
    *,
    factory_off_flag: Path,
    expected_db_sha256: str,
    expected_db_state_sha256: str,
    expected_factory_off_sha256: str,
    snapshot_path: Path,
    mutation_lock_path: Path | None = None,
) -> dict[str, Any]:
    lock_path = mutation_lock_path or path_for_factory_flag(factory_off_flag)
    with FactoryMutationLock(lock_path, owner="maintenance_control.apply_manifest"):
        # Bindings and snapshot belong to the same global writer critical section
        # as the SQLite transaction. Factory ON cannot release the interlock
        # between the hash check and commit.
        pre_db_sha, pre_state_sha, flag_sha = _verify_apply_bindings(
            db,
            factory_off_flag,
            expected_db_sha256,
            expected_db_state_sha256,
            expected_factory_off_sha256,
        )
        snapshot_sha = sqlite_snapshot(db, snapshot_path)
        applied: list[dict[str, Any]] = []
        now = utc_now()
        with connect_rw(db) as conn:
            # Additive schema activation may commit in sqlite3.executescript; finish
            # it before acquiring the transaction that protects all row changes.
            conn.executescript(SCHEMA_SQL)
            conn.commit()
            conn.execute("BEGIN IMMEDIATE")
            try:
                for op in manifest["operations"]:
                    prior_ledger = conn.execute(
                        "SELECT seq FROM work_item_transition_ledger WHERE idempotency_key=?",
                        (op["idempotency_key"],),
                    ).fetchone()
                    if prior_ledger:
                        applied.append({
                            "work_item_id": op["work_item_id"],
                            "already_applied": True,
                            "ledger_seq": prior_ledger["seq"],
                        })
                        continue
                    row = conn.execute(
                        "SELECT * FROM work_items WHERE id=?", (op["work_item_id"],)
                    ).fetchone()
                    if row is None:
                        raise RuntimeError(f"missing work_item {op['work_item_id']}")
                    mismatches = _expected_mismatches(row, op["expected"])
                    if mismatches:
                        raise RuntimeError(
                            f"{op['work_item_id']} pre-state mismatch: {'; '.join(mismatches)}"
                        )
                    old_payload = json.loads(row["payload_json"] or "{}")
                    transition = {
                        "run_id": manifest["run_id"],
                        "action": op["action"],
                        "reason": op["reason"],
                        "hold_code": op["hold_code"],
                        "at": now,
                        "from": {
                            "status": row["status"],
                            "verdict": row["verdict"],
                            "claimed_by": row["claimed_by"],
                        },
                        "to": {
                            "status": op["to_status"],
                            "verdict": op.get("to_verdict"),
                            "claimed_by": None,
                        },
                    }
                    history = list(old_payload.get("maintenance_transitions") or [])
                    history.append(transition)
                    old_payload["maintenance_transitions"] = history
                    old_payload["maintenance_hold_code"] = op["hold_code"]
                    old_payload["maintenance_run_id"] = manifest["run_id"]
                    conn.execute(
                        """
                        UPDATE work_items
                        SET status=?, verdict=?, claimed_by=NULL, payload_json=?, updated_at=?
                        WHERE id=?
                        """,
                        (
                            op["to_status"],
                            op.get("to_verdict"),
                            json.dumps(old_payload, sort_keys=True),
                            now,
                            op["work_item_id"],
                        ),
                    )
                    conn.execute(
                        """
                        INSERT INTO work_item_holds(
                            work_item_id, hold_code, reason, active, release_on_restart,
                            created_at, updated_at, released_at, release_note
                        ) VALUES (?, ?, ?, 1, ?, ?, ?, NULL, NULL)
                        ON CONFLICT(work_item_id) DO UPDATE SET
                            hold_code=excluded.hold_code,
                            reason=excluded.reason,
                            active=1,
                            release_on_restart=excluded.release_on_restart,
                            updated_at=excluded.updated_at,
                            released_at=NULL,
                            release_note=NULL
                        """,
                        (
                            op["work_item_id"],
                            op["hold_code"],
                            op["reason"],
                            1 if op.get("release_on_restart") else 0,
                            now,
                            now,
                        ),
                    )
                    detail = {
                        "manifest": manifest.get("description"),
                        "expected": op["expected"],
                        "release_on_restart": bool(op.get("release_on_restart")),
                    }
                    cursor = conn.execute(
                        """
                        INSERT INTO work_item_transition_ledger(
                            idempotency_key, ts, work_item_id, action,
                            from_status, to_status, from_verdict, to_verdict,
                            from_claimed_by, to_claimed_by, reason, run_id, detail_json
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?)
                        """,
                        (
                            op["idempotency_key"],
                            now,
                            op["work_item_id"],
                            op["action"],
                            row["status"],
                            op["to_status"],
                            row["verdict"],
                            op.get("to_verdict"),
                            row["claimed_by"],
                            op["reason"],
                            manifest["run_id"],
                            json.dumps(detail, sort_keys=True),
                        ),
                    )
                    conn.execute(
                        "INSERT INTO events(ts, entity_type, entity_id, event, detail_json) VALUES (?, 'work_item', ?, ?, ?)",
                        (
                            now,
                            op["work_item_id"],
                            f"maintenance_{op['action']}",
                            json.dumps(transition, sort_keys=True),
                        ),
                    )
                    applied.append({
                        "work_item_id": op["work_item_id"],
                        "already_applied": False,
                        "ledger_seq": cursor.lastrowid,
                        "from_status": row["status"],
                        "to_status": op["to_status"],
                    })
                conn.commit()
            except Exception:
                conn.rollback()
                raise
        wal_checkpoint = checkpoint_wal(db)
        return {
            "mode": "apply",
            "run_id": manifest["run_id"],
            "pre_db_sha256": pre_db_sha,
            "pre_db_state_sha256": pre_state_sha,
            "post_db_sha256": sha256_file(db),
            "post_db_state_sha256": sqlite_state_sha256(db),
            "wal_checkpoint": wal_checkpoint,
            "factory_off_sha256": flag_sha,
            "snapshot_path": str(snapshot_path),
            "snapshot_sha256": snapshot_sha,
            "mutation_lock_path": str(lock_path),
            "applied": applied,
        }


def _active_restart_hold_rows(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    try:
        return conn.execute(
            "SELECT * FROM work_item_holds "
            "WHERE active=1 AND release_on_restart=1 ORDER BY work_item_id"
        ).fetchall()
    except sqlite3.OperationalError as exc:
        raise RuntimeError("active release-on-restart holds cannot be read") from exc


def _require_no_factory_off_intent(
    factory_off_flag: Path, factory_off_request: Path
) -> None:
    present: list[str] = []
    for label, path in (
        ("FACTORY_OFF.flag", factory_off_flag),
        ("FACTORY_OFF_REQUEST.flag", factory_off_request),
    ):
        try:
            os.lstat(path)
        except FileNotFoundError:
            continue
        except OSError as exc:
            raise RuntimeError(f"{label} absence cannot be proven: {exc}") from exc
        present.append(str(path))
    if present:
        raise RuntimeError(
            "OFF wins: restart-hold release refused because a Factory OFF intent "
            f"is present: {present!r}"
        )


def _require_exact_restart_hold_set(
    rows: Sequence[sqlite3.Row], expected_work_item_ids: Sequence[str]
) -> None:
    actual_work_item_ids = tuple(str(row["work_item_id"]) for row in rows)
    actual_set = set(actual_work_item_ids)
    expected_set = set(expected_work_item_ids)
    missing = sorted(expected_set - actual_set)
    extra = sorted(actual_set - expected_set)
    if (
        missing
        or extra
        or len(actual_work_item_ids) != len(actual_set)
        or len(actual_work_item_ids) != len(expected_work_item_ids)
    ):
        raise RuntimeError(
            "release-on-restart exact-set mismatch: "
            f"missing=[{','.join(missing)}] extra=[{','.join(extra)}]"
        )


def _apply_restart_hold_release_transaction(
    db: Path,
    *,
    release_note: str,
    runtime_authorization: dict[str, Any],
    factory_off_flag: Path | None = None,
    factory_off_request: Path | None = None,
) -> dict[str, Any]:
    expected_ids = tuple(sorted(_runtime_restart_hold_ids(runtime_authorization)))
    activation_nonce = runtime_authorization.get("activation_nonce")
    decision_id = runtime_authorization.get("decision_id")
    decision_sha256 = runtime_authorization.get("decision_sha256")
    if not all(isinstance(value, str) and value for value in (
        activation_nonce,
        decision_id,
        decision_sha256,
    )):
        raise RuntimeError("runtime activation consumption identity is incomplete")
    with connect_rw(db) as conn:
        try:
            if factory_off_flag is not None and factory_off_request is not None:
                _require_no_factory_off_intent(
                    factory_off_flag, factory_off_request
                )
            conn.execute("BEGIN IMMEDIATE")
            if factory_off_flag is not None and factory_off_request is not None:
                _require_no_factory_off_intent(
                    factory_off_flag, factory_off_request
                )
            rows = _active_restart_hold_rows(conn)
            _require_exact_restart_hold_set(rows, expected_ids)
            now = utc_now()
            conn.execute(
                """CREATE TABLE IF NOT EXISTS factory_runtime_activation_consumptions_v2 (
                    activation_nonce TEXT PRIMARY KEY,
                    decision_id TEXT NOT NULL,
                    decision_sha256 TEXT NOT NULL,
                    consumed_at_utc TEXT NOT NULL,
                    released_hold_count INTEGER NOT NULL CHECK(released_hold_count>=0)
                )"""
            )
            conn.execute(
                """CREATE TRIGGER IF NOT EXISTS trg_factory_runtime_activation_v2_no_update
                BEFORE UPDATE ON factory_runtime_activation_consumptions_v2
                BEGIN SELECT RAISE(ABORT, 'factory runtime activation consumption is append-only'); END"""
            )
            conn.execute(
                """CREATE TRIGGER IF NOT EXISTS trg_factory_runtime_activation_v2_no_delete
                BEFORE DELETE ON factory_runtime_activation_consumptions_v2
                BEGIN SELECT RAISE(ABORT, 'factory runtime activation consumption is append-only'); END
                """
            )
            legacy_table_exists = conn.execute(
                "SELECT 1 FROM sqlite_master WHERE type='table' "
                "AND name='factory_runtime_activation_consumptions'"
            ).fetchone()
            consumed_in_v1 = (
                legacy_table_exists is not None
                and conn.execute(
                    "SELECT 1 FROM factory_runtime_activation_consumptions "
                    "WHERE activation_nonce=?",
                    (activation_nonce,),
                ).fetchone()
                is not None
            )
            consumed_in_v2 = conn.execute(
                "SELECT 1 FROM factory_runtime_activation_consumptions_v2 "
                "WHERE activation_nonce=?",
                (activation_nonce,),
            ).fetchone()
            if consumed_in_v1 or consumed_in_v2 is not None:
                consumed_table = (
                    "factory_runtime_activation_consumptions"
                    if consumed_in_v1
                    else "factory_runtime_activation_consumptions_v2"
                )
                raise RuntimeError(
                    "runtime activation nonce was already consumed in "
                    f"{consumed_table}"
                )
            conn.execute(
                """
                INSERT INTO factory_runtime_activation_consumptions_v2(
                    activation_nonce, decision_id, decision_sha256,
                    consumed_at_utc, released_hold_count
                ) VALUES (?, ?, ?, ?, ?)
                """,
                (
                    activation_nonce,
                    decision_id,
                    decision_sha256,
                    now,
                    len(rows),
                ),
            )
            for row in rows:
                key = f"restart-release:{row['work_item_id']}:{row['created_at']}"
                cursor = conn.execute(
                    "UPDATE work_item_holds "
                    "SET active=0, updated_at=?, released_at=?, release_note=? "
                    "WHERE work_item_id=? AND active=1 AND release_on_restart=1",
                    (now, now, release_note, row["work_item_id"]),
                )
                if cursor.rowcount != 1:
                    raise RuntimeError(
                        "release-on-restart CAS failed for "
                        f"work item {row['work_item_id']}: rowcount={cursor.rowcount}"
                    )
                conn.execute(
                    """
                    INSERT INTO work_item_transition_ledger(
                        idempotency_key, ts, work_item_id, action, reason, run_id, detail_json
                    ) VALUES (?, ?, ?, 'release_hold', ?, 'coordinated_restart', '{}')
                    """,
                    (key, now, row["work_item_id"], release_note),
                )
                conn.execute(
                    "INSERT INTO events(ts, entity_type, entity_id, event, detail_json) "
                    "VALUES (?, 'work_item', ?, 'maintenance_hold_released', ?)",
                    (
                        now,
                        row["work_item_id"],
                        json.dumps({"release_note": release_note}),
                    ),
                )
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
    return {
        "mutation_committed": True,
        "committed_at_utc": now,
        "runtime_activation_nonce_consumed": activation_nonce,
        "released": [row["work_item_id"] for row in rows],
    }


def _collect_restart_release_post_commit_evidence(db: Path) -> dict[str, Any]:
    """Collect best-effort evidence without turning a commit into a false failure."""

    evidence: dict[str, Any] = {}
    errors: list[str] = []
    probes = (
        ("wal_checkpoint", lambda: checkpoint_wal(db)),
        ("post_db_sha256", lambda: sha256_file(db)),
        ("post_db_state_sha256", lambda: sqlite_state_sha256(db)),
    )
    for label, probe in probes:
        try:
            evidence[label] = probe()
        except BaseException as exc:
            evidence[label] = None
            errors.append(f"{label}: {type(exc).__name__}: {exc}")
    evidence["status"] = "PASS" if not errors else "FAILED_AFTER_COMMIT"
    evidence["errors"] = errors
    return evidence


def release_restart_holds(
    db: Path,
    *,
    factory_off_flag: Path,
    expected_db_sha256: str | None,
    apply: bool,
    release_note: str,
    factory_on_lock_nonce: str | None = None,
) -> dict[str, Any]:
    owner_decision = _validate_canonical_restart_owner_decision()
    preparation_plan = _validated_restart_hold_ids(
        owner_decision["restart_holds"]["authorized_work_item_ids"],
        label="canonical OWNER authorized_work_item_ids",
    )
    expected_ids = tuple(sorted(preparation_plan))
    lock_path = path_for_factory_flag(factory_off_flag)
    if not apply:
        _require_no_factory_off_intent(
            factory_off_flag, DEFAULT_FACTORY_OFF_REQUEST
        )
        if expected_db_sha256 and sha256_file(db).lower() != expected_db_sha256.lower():
            raise RuntimeError("DB SHA-256 mismatch")
        with connect_ro(db) as conn:
            rows = _active_restart_hold_rows(conn)
            _require_exact_restart_hold_set(rows, expected_ids)
        return {
            "mode": "dry_run",
            "release_count": len(rows),
            "work_item_ids": [row["work_item_id"] for row in rows],
            "expected_work_item_ids": list(expected_ids),
            "owner_decision_sha256": CANONICAL_OWNER_DECISION_SHA256,
            "owner_decision_commit": CANONICAL_OWNER_DECISION_COMMIT,
            "owner_decision_blob": CANONICAL_OWNER_DECISION_BLOB,
        }

    try:
        runtime_authorization = validate_runtime_activation_decision()
    except RuntimeActivationError as exc:
        raise RuntimeError(
            f"release-on-restart lacks fresh canonical OWNER runtime authority: {exc}"
        ) from exc
    runtime_plan = _runtime_restart_hold_ids(runtime_authorization)
    if runtime_plan != preparation_plan:
        raise RuntimeError(
            "runtime restart-hold plan does not equal the canonical preparation plan"
        )
    expected_ids = tuple(sorted(runtime_plan))
    _require_canonical_restart_release_paths(db, factory_off_flag, lock_path)
    _validate_canonical_factory_on_lock(
        lock_path,
        expected_nonce=factory_on_lock_nonce or "",
        runtime_authorization=runtime_authorization,
    )
    _require_no_factory_off_intent(
        factory_off_flag, DEFAULT_FACTORY_OFF_REQUEST
    )
    if expected_db_sha256 and sha256_file(db).lower() != expected_db_sha256.lower():
        raise RuntimeError("DB SHA-256 mismatch")

    committed = _apply_restart_hold_release_transaction(
        db,
        release_note=release_note,
        runtime_authorization=runtime_authorization,
        factory_off_flag=factory_off_flag,
        factory_off_request=DEFAULT_FACTORY_OFF_REQUEST,
    )
    post_commit_evidence = _collect_restart_release_post_commit_evidence(db)
    return {
        "mode": "apply",
        **committed,
        "expected_work_item_ids": list(expected_ids),
        "owner_decision_sha256": CANONICAL_OWNER_DECISION_SHA256,
        "owner_decision_commit": CANONICAL_OWNER_DECISION_COMMIT,
        "owner_decision_blob": CANONICAL_OWNER_DECISION_BLOB,
        "runtime_decision_id": runtime_authorization["decision_id"],
        "runtime_decision_sha256": runtime_authorization["decision_sha256"],
        "runtime_decision_commit": runtime_authorization["decision_git_commit"],
        "runtime_decision_blob": runtime_authorization["decision_git_blob"],
        "post_commit_evidence": post_commit_evidence,
        "mutation_lock_path": str(lock_path),
        "mutation_lock_mode": "authenticated_live_factory_on_parent_lock",
    }


def release_completed_hold(
    db: Path,
    *,
    factory_off_flag: Path,
    work_item_id: str,
    expected_hold_code: str,
    expected_status: str,
    expected_verdict: str,
    expected_db_sha256: str | None,
    expected_db_state_sha256: str | None,
    expected_factory_off_sha256: str | None,
    snapshot_path: Path | None,
    apply: bool,
    release_note: str,
    mutation_lock_path: Path | None = None,
) -> dict[str, Any]:
    """Release one non-restart hold after an isolated item completed.

    The operation is legal only while Factory OFF remains asserted. It binds
    one terminal work item, one hold code, both SQLite identities, the OFF flag,
    and a fresh pre-mutation snapshot.
    """
    work_item_id = work_item_id.strip()
    expected_hold_code = expected_hold_code.strip()
    expected_status = expected_status.strip()
    expected_verdict = expected_verdict.strip()
    release_note = release_note.strip()
    if not all((work_item_id, expected_hold_code, expected_status, expected_verdict, release_note)):
        raise ValueError("completed-hold release identity is incomplete")
    if expected_status not in {"done", "failed"}:
        raise ValueError("completed-hold release requires a terminal expected status")

    def inspect(
        conn: sqlite3.Connection,
    ) -> tuple[sqlite3.Row, sqlite3.Row, sqlite3.Row | None]:
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
        if row is None:
            raise RuntimeError(f"missing work_item {work_item_id}")
        if row["status"] != expected_status or row["verdict"] != expected_verdict:
            raise RuntimeError(
                f"{work_item_id} terminal pre-state mismatch: "
                f"expected={expected_status}/{expected_verdict} "
                f"actual={row['status']}/{row['verdict']}"
            )
        hold = conn.execute(
            "SELECT * FROM work_item_holds WHERE work_item_id=?", (work_item_id,)
        ).fetchone()
        if hold is None:
            raise RuntimeError(f"missing maintenance hold for {work_item_id}")
        if hold["hold_code"] != expected_hold_code:
            raise RuntimeError(
                f"{work_item_id} hold mismatch: expected={expected_hold_code!r} "
                f"actual={hold['hold_code']!r}"
            )
        key = f"completed-release:{work_item_id}:{hold['created_at']}"
        ledger = conn.execute(
            "SELECT * FROM work_item_transition_ledger WHERE idempotency_key=?", (key,)
        ).fetchone()
        if int(hold["active"]) == 0 and ledger is None:
            raise RuntimeError(f"{work_item_id} hold is inactive without the expected release ledger")
        return row, hold, ledger

    if not apply:
        with connect_ro(db) as conn:
            row, hold, ledger = inspect(conn)
        return {
            "mode": "dry_run",
            "work_item_id": work_item_id,
            "status": row["status"],
            "verdict": row["verdict"],
            "hold_code": hold["hold_code"],
            "active": bool(hold["active"]),
            "already_released": ledger is not None and not bool(hold["active"]),
        }

    if not all((expected_db_sha256, expected_db_state_sha256, expected_factory_off_sha256)):
        raise ValueError("apply requires DB file, logical DB state, and FACTORY_OFF SHA-256 bindings")
    if snapshot_path is None:
        raise ValueError("apply requires --snapshot-path")

    lock_path = mutation_lock_path or path_for_factory_flag(factory_off_flag)
    with FactoryMutationLock(lock_path, owner="maintenance_control.release_completed_hold"):
        pre_db_sha, pre_state_sha, flag_sha = _verify_apply_bindings(
            db,
            factory_off_flag,
            expected_db_sha256,
            expected_db_state_sha256,
            expected_factory_off_sha256,
        )
        snapshot_sha = sqlite_snapshot(db, snapshot_path)
        now = utc_now()
        with connect_rw(db) as conn:
            conn.executescript(SCHEMA_SQL)
            conn.commit()
            conn.execute("BEGIN IMMEDIATE")
            try:
                row, hold, ledger = inspect(conn)
                already_released = ledger is not None and not bool(hold["active"])
                if not already_released:
                    key = f"completed-release:{work_item_id}:{hold['created_at']}"
                    updated = conn.execute(
                        """
                        UPDATE work_item_holds
                        SET active=0, updated_at=?, released_at=?, release_note=?
                        WHERE work_item_id=? AND active=1 AND hold_code=?
                        """,
                        (now, now, release_note, work_item_id, expected_hold_code),
                    )
                    if updated.rowcount != 1:
                        raise RuntimeError(f"{work_item_id} hold changed before release")
                    detail = {
                        "hold_code": expected_hold_code,
                        "expected_status": expected_status,
                        "expected_verdict": expected_verdict,
                        "factory_off_sha256": flag_sha,
                    }
                    conn.execute(
                        """
                        INSERT INTO work_item_transition_ledger(
                            idempotency_key, ts, work_item_id, action,
                            from_status, to_status, from_verdict, to_verdict,
                            from_claimed_by, to_claimed_by, reason, run_id, detail_json
                        ) VALUES (?, ?, ?, 'release_completed_hold', ?, ?, ?, ?, ?, ?, ?,
                                  'isolated_completion', ?)
                        """,
                        (
                            key,
                            now,
                            work_item_id,
                            row["status"],
                            row["status"],
                            row["verdict"],
                            row["verdict"],
                            row["claimed_by"],
                            row["claimed_by"],
                            release_note,
                            json.dumps(detail, sort_keys=True),
                        ),
                    )
                    conn.execute(
                        """
                        INSERT INTO events(ts, entity_type, entity_id, event, detail_json)
                        VALUES (?, 'work_item', ?, 'maintenance_completed_hold_released', ?)
                        """,
                        (now, work_item_id, json.dumps(detail, sort_keys=True)),
                    )
                conn.commit()
            except Exception:
                conn.rollback()
                raise
        wal_checkpoint = checkpoint_wal(db)
        return {
            "mode": "apply",
            "work_item_id": work_item_id,
            "already_released": already_released,
            "pre_db_sha256": pre_db_sha,
            "pre_db_state_sha256": pre_state_sha,
            "post_db_sha256": sha256_file(db),
            "post_db_state_sha256": sqlite_state_sha256(db),
            "factory_off_sha256": flag_sha,
            "snapshot_path": str(snapshot_path),
            "snapshot_sha256": snapshot_sha,
            "wal_checkpoint": wal_checkpoint,
            "mutation_lock_path": str(lock_path),
        }


def reclassify_safe_defer_task(
    db: Path,
    *,
    factory_off_flag: Path,
    task_id: str,
    expected_task_type: str,
    expected_verdict_sha256: str,
    expected_db_sha256: str | None,
    expected_db_state_sha256: str | None,
    expected_factory_off_sha256: str | None,
    snapshot_path: Path | None,
    apply: bool,
    reason: str,
    mutation_lock_path: Path | None = None,
) -> dict[str, Any]:
    """Correct one historical SAFE_DEFER false-PASS to BLOCKED."""
    task_id = task_id.strip()
    expected_task_type = expected_task_type.strip()
    expected_verdict_sha256 = expected_verdict_sha256.strip().lower()
    reason = reason.strip()
    if not all((task_id, expected_task_type, expected_verdict_sha256, reason)):
        raise ValueError("SAFE_DEFER correction identity is incomplete")
    if not re.fullmatch(r"[0-9a-f]{64}", expected_verdict_sha256):
        raise ValueError("expected verdict SHA-256 must be 64 lowercase hex characters")
    key = f"safe-defer-reclassify:{task_id}:{expected_verdict_sha256}"

    def inspect(
        conn: sqlite3.Connection,
    ) -> tuple[sqlite3.Row, dict[str, Any], sqlite3.Row | None]:
        row = conn.execute("SELECT * FROM agent_tasks WHERE id=?", (task_id,)).fetchone()
        if row is None:
            raise RuntimeError(f"missing agent_task {task_id}")
        actual_verdict_sha = hashlib.sha256(str(row["verdict"] or "").encode("utf-8")).hexdigest()
        if row["task_type"] != expected_task_type:
            raise RuntimeError(
                f"{task_id} task_type mismatch: expected={expected_task_type!r} "
                f"actual={row['task_type']!r}"
            )
        if actual_verdict_sha != expected_verdict_sha256:
            raise RuntimeError(
                f"{task_id} verdict SHA-256 mismatch: expected={expected_verdict_sha256} "
                f"actual={actual_verdict_sha}"
            )
        try:
            payload = json.loads(row["payload_json"] or "{}")
        except json.JSONDecodeError as exc:
            raise RuntimeError(f"{task_id} payload_json is invalid") from exc
        review_verdict = str(payload.get("review_close_verdict") or row["verdict"] or "")
        if re.match(r"^SAFE(?:[\s_-]+)DEFER\b", review_verdict.strip(), re.IGNORECASE) is None:
            raise RuntimeError(f"{task_id} is not an explicit SAFE_DEFER verdict")
        if payload.get("review_close_state") != "APPROVED":
            raise RuntimeError(f"{task_id} was not closed through APPROVED")
        try:
            ledger = conn.execute(
                "SELECT * FROM agent_task_transition_ledger WHERE idempotency_key=?", (key,)
            ).fetchone()
        except sqlite3.OperationalError:
            ledger = None
        if row["state"] == "BLOCKED" and ledger is not None:
            return row, payload, ledger
        if row["state"] != "PASSED":
            raise RuntimeError(
                f"{task_id} state mismatch: expected historical PASSED, actual={row['state']!r}"
            )
        return row, payload, ledger

    if not apply:
        with connect_ro(db) as conn:
            row, _, ledger = inspect(conn)
        return {
            "mode": "dry_run",
            "task_id": task_id,
            "task_type": row["task_type"],
            "from_state": row["state"],
            "to_state": "BLOCKED",
            "already_reclassified": ledger is not None and row["state"] == "BLOCKED",
        }

    if not all((expected_db_sha256, expected_db_state_sha256, expected_factory_off_sha256)):
        raise ValueError("apply requires DB file, logical DB state, and FACTORY_OFF SHA-256 bindings")
    if snapshot_path is None:
        raise ValueError("apply requires --snapshot-path")

    lock_path = mutation_lock_path or path_for_factory_flag(factory_off_flag)
    with FactoryMutationLock(lock_path, owner="maintenance_control.reclassify_safe_defer_task"):
        pre_db_sha, pre_state_sha, flag_sha = _verify_apply_bindings(
            db,
            factory_off_flag,
            expected_db_sha256,
            expected_db_state_sha256,
            expected_factory_off_sha256,
        )
        snapshot_sha = sqlite_snapshot(db, snapshot_path)
        now = utc_now()
        with connect_rw(db) as conn:
            conn.executescript(SCHEMA_SQL)
            conn.commit()
            conn.execute("BEGIN IMMEDIATE")
            try:
                row, payload, ledger = inspect(conn)
                already_reclassified = ledger is not None and row["state"] == "BLOCKED"
                if not already_reclassified:
                    history = list(payload.get("maintenance_reclassifications") or [])
                    history.append(
                        {
                            "at": now,
                            "from_state": "PASSED",
                            "to_state": "BLOCKED",
                            "reason": reason,
                            "source": "MNT-037",
                        }
                    )
                    payload["maintenance_reclassifications"] = history
                    updated = conn.execute(
                        """
                        UPDATE agent_tasks
                        SET state='BLOCKED', payload_json=?, updated_at=?
                        WHERE id=? AND state='PASSED' AND verdict=?
                        """,
                        (json.dumps(payload, sort_keys=True), now, task_id, row["verdict"]),
                    )
                    if updated.rowcount != 1:
                        raise RuntimeError(f"{task_id} changed before SAFE_DEFER correction")
                    detail = {
                        "expected_verdict_sha256": expected_verdict_sha256,
                        "review_close_state": payload.get("review_close_state"),
                        "source": "MNT-037",
                    }
                    conn.execute(
                        """
                        INSERT INTO agent_task_transition_ledger(
                            idempotency_key, ts, task_id, action,
                            from_state, to_state, reason, detail_json
                        ) VALUES (?, ?, ?, 'reclassify_safe_defer', 'PASSED', 'BLOCKED', ?, ?)
                        """,
                        (key, now, task_id, reason, json.dumps(detail, sort_keys=True)),
                    )
                    conn.execute(
                        """
                        INSERT INTO events(ts, entity_type, entity_id, event, detail_json)
                        VALUES (?, 'agent_task', ?, 'maintenance_safe_defer_reclassified', ?)
                        """,
                        (now, task_id, json.dumps(detail, sort_keys=True)),
                    )
                conn.commit()
            except Exception:
                conn.rollback()
                raise
        wal_checkpoint = checkpoint_wal(db)
        return {
            "mode": "apply",
            "task_id": task_id,
            "from_state": "PASSED",
            "to_state": "BLOCKED",
            "already_reclassified": already_reclassified,
            "pre_db_sha256": pre_db_sha,
            "pre_db_state_sha256": pre_state_sha,
            "post_db_sha256": sha256_file(db),
            "post_db_state_sha256": sqlite_state_sha256(db),
            "factory_off_sha256": flag_sha,
            "snapshot_path": str(snapshot_path),
            "snapshot_sha256": snapshot_sha,
            "wal_checkpoint": wal_checkpoint,
            "mutation_lock_path": str(lock_path),
        }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--factory-off-flag", type=Path, default=DEFAULT_FACTORY_OFF)
    sub = parser.add_subparsers(dest="command", required=True)

    plan = sub.add_parser("plan", help="Read-only manifest validation (default-safe)")
    plan.add_argument("--manifest", type=Path, required=True)

    apply_cmd = sub.add_parser("apply", help="Apply an exact hash-bound manifest")
    apply_cmd.add_argument("--manifest", type=Path, required=True)
    apply_cmd.add_argument("--expected-db-sha256", required=True)
    apply_cmd.add_argument("--expected-db-state-sha256", required=True)
    apply_cmd.add_argument("--expected-factory-off-sha256", required=True)
    apply_cmd.add_argument("--snapshot-path", type=Path, required=True)

    release = sub.add_parser("release-on-restart", help="Release only holds explicitly marked release_on_restart")
    release.add_argument("--apply", action="store_true")
    release.add_argument(
        "--factory-on-lock-nonce",
        required=False,
        help="Nonce of the live parent-held canonical Factory_ON mutation lock",
    )
    release.add_argument("--expected-db-sha256")
    release.add_argument("--release-note", default="coordinated factory restart gate passed")

    completed = sub.add_parser(
        "release-completed-hold",
        help="Release one exact non-restart hold after an isolated terminal result",
    )
    completed.add_argument("--apply", action="store_true")
    completed.add_argument("--work-item-id", required=True)
    completed.add_argument("--expected-hold-code", required=True)
    completed.add_argument("--expected-status", default="done")
    completed.add_argument("--expected-verdict", required=True)
    completed.add_argument("--expected-db-sha256")
    completed.add_argument("--expected-db-state-sha256")
    completed.add_argument("--expected-factory-off-sha256")
    completed.add_argument("--snapshot-path", type=Path)
    completed.add_argument("--release-note", required=True)

    safe_defer = sub.add_parser(
        "reclassify-safe-defer",
        help="Correct one exact historical SAFE_DEFER false-PASS to BLOCKED",
    )
    safe_defer.add_argument("--apply", action="store_true")
    safe_defer.add_argument("--task-id", required=True)
    safe_defer.add_argument("--expected-task-type", required=True)
    safe_defer.add_argument("--expected-verdict-sha256", required=True)
    safe_defer.add_argument("--expected-db-sha256")
    safe_defer.add_argument("--expected-db-state-sha256")
    safe_defer.add_argument("--expected-factory-off-sha256")
    safe_defer.add_argument("--snapshot-path", type=Path)
    safe_defer.add_argument("--reason", required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "plan":
        result = inspect_manifest(args.db, load_manifest(args.manifest))
    elif args.command == "apply":
        result = apply_manifest(
            args.db,
            load_manifest(args.manifest),
            factory_off_flag=args.factory_off_flag,
            expected_db_sha256=args.expected_db_sha256,
            expected_db_state_sha256=args.expected_db_state_sha256,
            expected_factory_off_sha256=args.expected_factory_off_sha256,
            snapshot_path=args.snapshot_path,
        )
    elif args.command == "release-on-restart":
        result = release_restart_holds(
            args.db,
            factory_off_flag=args.factory_off_flag,
            expected_db_sha256=args.expected_db_sha256,
            apply=args.apply,
            release_note=args.release_note,
            factory_on_lock_nonce=args.factory_on_lock_nonce,
        )
    elif args.command == "release-completed-hold":
        result = release_completed_hold(
            args.db,
            factory_off_flag=args.factory_off_flag,
            work_item_id=args.work_item_id,
            expected_hold_code=args.expected_hold_code,
            expected_status=args.expected_status,
            expected_verdict=args.expected_verdict,
            expected_db_sha256=args.expected_db_sha256,
            expected_db_state_sha256=args.expected_db_state_sha256,
            expected_factory_off_sha256=args.expected_factory_off_sha256,
            snapshot_path=args.snapshot_path,
            apply=args.apply,
            release_note=args.release_note,
        )
    else:
        result = reclassify_safe_defer_task(
            args.db,
            factory_off_flag=args.factory_off_flag,
            task_id=args.task_id,
            expected_task_type=args.expected_task_type,
            expected_verdict_sha256=args.expected_verdict_sha256,
            expected_db_sha256=args.expected_db_sha256,
            expected_db_state_sha256=args.expected_db_state_sha256,
            expected_factory_off_sha256=args.expected_factory_off_sha256,
            snapshot_path=args.snapshot_path,
            apply=args.apply,
            reason=args.reason,
        )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result.get("valid", True) else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2), file=sys.stderr)
        raise SystemExit(1)
