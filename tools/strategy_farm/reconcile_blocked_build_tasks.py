#!/usr/bin/env python3
"""Hash-bound MNT-012 reconciliation for pending build tasks with active blocks.

``forecast`` is the default and opens SQLite read-only.  ``apply`` is an
explicit maintenance operation: it requires an exact manifest hash, an exact
run-id confirmation, FACTORY_OFF, the global mutation lock, unchanged database
and card hashes, a fresh SQLite snapshot, and compare-and-swap task updates.
It never edits Strategy Cards.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any

try:
    from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag
except ModuleNotFoundError:  # pragma: no cover - package import
    from tools.strategy_farm.factory_mutation_lock import (
        FactoryMutationLock,
        path_for_factory_flag,
    )


SCHEMA_VERSION = "qm.mnt012.blocked-build-reconciliation.v1"
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_FACTORY_OFF = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
ACTIVE_BLOCK_FIELDS = ("blocked_reason", "blocked_at", "blocked_at_utc")
LEDGER_TABLE = "build_task_reconciliation_ledger"
LEDGER_SCHEMA_STATEMENTS = (
    """
    CREATE TABLE IF NOT EXISTS build_task_reconciliation_ledger (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        idempotency_key TEXT NOT NULL UNIQUE,
        ts TEXT NOT NULL,
        task_id TEXT NOT NULL,
        run_id TEXT NOT NULL,
        manifest_sha256 TEXT NOT NULL,
        from_status TEXT NOT NULL,
        to_status TEXT NOT NULL,
        expected_payload_sha256 TEXT NOT NULL,
        target_payload_sha256 TEXT NOT NULL,
        detail_json TEXT NOT NULL
    )
    """,
    """
    CREATE TRIGGER IF NOT EXISTS trg_build_task_reconciliation_ledger_no_update
    BEFORE UPDATE ON build_task_reconciliation_ledger
    BEGIN
        SELECT RAISE(ABORT, 'build_task_reconciliation_ledger is append-only');
    END
    """,
    """
    CREATE TRIGGER IF NOT EXISTS trg_build_task_reconciliation_ledger_no_delete
    BEFORE DELETE ON build_task_reconciliation_ledger
    BEGIN
        SELECT RAISE(ABORT, 'build_task_reconciliation_ledger is append-only');
    END
    """,
)


class ReconciliationError(RuntimeError):
    pass


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def sqlite_state_sha256(path: Path) -> str:
    with connect_ro(path) as conn:
        try:
            image = conn.serialize()
        except AttributeError as exc:  # pragma: no cover - Python < 3.11
            raise ReconciliationError("sqlite3.Connection.serialize() is required") from exc
    return hashlib.sha256(image).hexdigest()


def connect_ro(path: Path) -> sqlite3.Connection:
    uri = Path(path).resolve().as_uri() + "?mode=ro"
    conn = sqlite3.connect(uri, uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def connect_rw(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(path, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def sqlite_snapshot(source: Path, target: Path) -> str:
    if target.exists():
        raise ReconciliationError(f"snapshot target already exists: {target}")
    target.parent.mkdir(parents=True, exist_ok=True)
    source_conn = sqlite3.connect(source, timeout=30)
    target_conn = sqlite3.connect(target)
    try:
        source_conn.backup(target_conn)
    finally:
        target_conn.close()
        source_conn.close()
    return sha256_file(target)


def _nonempty(value: Any) -> bool:
    if value is None or value is False:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    return True


def _validate_operation(raw: Any, index: int) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise ReconciliationError(f"operations[{index}] must be an object")
    operation = dict(raw)
    expected = operation.get("expected")
    target = operation.get("target")
    card = operation.get("card")
    source = operation.get("source_diagnostic")
    if not isinstance(expected, dict) or not isinstance(target, dict):
        raise ReconciliationError(f"operations[{index}] requires expected and target objects")
    if not isinstance(card, dict):
        raise ReconciliationError(f"operations[{index}].card must be an object")
    if not isinstance(source, dict):
        raise ReconciliationError(f"operations[{index}].source_diagnostic must be an object")
    if str(expected.get("kind")) != "build_ea" or str(expected.get("status")) != "pending":
        raise ReconciliationError(f"operations[{index}] must bind pending build_ea pre-state")
    if str(target.get("status")) != "blocked":
        raise ReconciliationError(f"operations[{index}].target.status must be blocked")
    patch = target.get("payload_patch")
    if not isinstance(patch, dict) or not _nonempty(patch.get("blocked_reason")):
        raise ReconciliationError(
            f"operations[{index}].target.payload_patch.blocked_reason is required"
        )
    if not isinstance(patch.get("mnt012_reconciliation"), dict):
        raise ReconciliationError(
            f"operations[{index}].target.payload_patch.mnt012_reconciliation is required"
        )
    for owner, key in (
        (operation, "task_id"),
        (expected, "card_id"),
        (expected, "updated_at"),
        (expected, "payload_sha256"),
        (target, "updated_at"),
        (target, "payload_sha256"),
        (card, "path"),
        (card, "sha256"),
        (source, "path"),
        (source, "sha256"),
    ):
        if not str(owner.get(key) or "").strip():
            raise ReconciliationError(f"operations[{index}] missing {key}")
    return operation


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ReconciliationError(f"manifest unreadable: {path}: {exc}") from exc
    if not isinstance(payload, dict) or payload.get("schema_version") != SCHEMA_VERSION:
        raise ReconciliationError(f"manifest schema must be {SCHEMA_VERSION}")
    if not str(payload.get("run_id") or "").strip():
        raise ReconciliationError("manifest.run_id is required")
    bindings = payload.get("bindings")
    if not isinstance(bindings, dict):
        raise ReconciliationError("manifest.bindings is required")
    database = bindings.get("database")
    factory_off = bindings.get("factory_off")
    if not isinstance(database, dict) or not isinstance(factory_off, dict):
        raise ReconciliationError("manifest database/factory_off bindings are required")
    for owner, key in (
        (database, "file_sha256"),
        (database, "logical_state_sha256"),
        (factory_off, "sha256"),
    ):
        if not str(owner.get(key) or "").strip():
            raise ReconciliationError(f"manifest binding {key} is required")
    operations = payload.get("operations")
    if not isinstance(operations, list) or not operations:
        raise ReconciliationError("manifest.operations must be a non-empty array")
    seen: set[str] = set()
    payload["operations"] = []
    for index, raw in enumerate(operations):
        operation = _validate_operation(raw, index)
        task_id = str(operation["task_id"])
        if task_id in seen:
            raise ReconciliationError(f"duplicate task_id: {task_id}")
        seen.add(task_id)
        payload["operations"].append(operation)
    return payload


def proposed_payload(operation: dict[str, Any], current_payload_json: str) -> str:
    try:
        payload = json.loads(current_payload_json)
    except (json.JSONDecodeError, TypeError) as exc:
        raise ReconciliationError(f"{operation['task_id']} payload is invalid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise ReconciliationError(f"{operation['task_id']} payload is not an object")
    payload.update(operation["target"]["payload_patch"])
    return canonical_json(payload)


def _row_mismatches(row: sqlite3.Row | None, operation: dict[str, Any]) -> list[str]:
    if row is None:
        return ["task_missing"]
    expected = operation["expected"]
    checks = {
        "id": operation["task_id"],
        "kind": expected["kind"],
        "status": expected["status"],
        "card_id": expected["card_id"],
        "updated_at": expected["updated_at"],
    }
    mismatches = [
        f"{key}:expected={value!r}:actual={row[key]!r}"
        for key, value in checks.items()
        if row[key] != value
    ]
    actual_payload_sha = sha256_text(str(row["payload_json"] or ""))
    if actual_payload_sha.lower() != str(expected["payload_sha256"]).lower():
        mismatches.append(
            "payload_sha256:"
            f"expected={expected['payload_sha256']}:actual={actual_payload_sha}"
        )
    return mismatches


def _operation_forecast(conn: sqlite3.Connection, operation: dict[str, Any]) -> dict[str, Any]:
    row = conn.execute("SELECT * FROM tasks WHERE id=?", (operation["task_id"],)).fetchone()
    mismatches = _row_mismatches(row, operation)
    card_path = Path(operation["card"]["path"])
    if not card_path.is_file():
        mismatches.append(f"card_missing:{card_path}")
        actual_card_sha = None
    else:
        actual_card_sha = sha256_file(card_path)
        if actual_card_sha.lower() != str(operation["card"]["sha256"]).lower():
            mismatches.append(
                f"card_sha256:expected={operation['card']['sha256']}:actual={actual_card_sha}"
            )
    source_path = Path(operation["source_diagnostic"]["path"])
    if not source_path.is_file():
        mismatches.append(f"source_missing:{source_path}")
        actual_source_sha = None
    else:
        actual_source_sha = sha256_file(source_path)
        if actual_source_sha.lower() != str(operation["source_diagnostic"]["sha256"]).lower():
            mismatches.append(
                "source_sha256:"
                f"expected={operation['source_diagnostic']['sha256']}:actual={actual_source_sha}"
            )
    current_payload_json = str(row["payload_json"] or "") if row is not None else "{}"
    proposed = proposed_payload(operation, current_payload_json) if row is not None else ""
    proposed_sha = sha256_text(proposed) if proposed else None
    if proposed_sha != str(operation["target"]["payload_sha256"]).lower():
        mismatches.append(
            "target_payload_sha256:"
            f"expected={operation['target']['payload_sha256']}:actual={proposed_sha}"
        )
    active_markers: dict[str, Any] = {}
    if row is not None:
        current_payload = json.loads(current_payload_json)
        active_markers = {
            field: current_payload.get(field)
            for field in ACTIVE_BLOCK_FIELDS
            if _nonempty(current_payload.get(field))
        }
        if not active_markers:
            mismatches.append("active_block_marker_missing")
    return {
        "task_id": operation["task_id"],
        "card_id": operation["expected"]["card_id"],
        "ready": not mismatches,
        "mismatches": mismatches,
        "active_block_markers": active_markers,
        "current_status": row["status"] if row is not None else None,
        "target_status": operation["target"]["status"],
        "current_payload_sha256": (
            sha256_text(current_payload_json) if row is not None else None
        ),
        "target_payload_sha256": proposed_sha,
        "card_sha256": actual_card_sha,
        "source_sha256": actual_source_sha,
    }


def _binding_report(
    db: Path,
    factory_off_flag: Path,
    manifest: dict[str, Any],
) -> dict[str, Any]:
    expected_db = manifest["bindings"]["database"]
    expected_flag = manifest["bindings"]["factory_off"]
    actual = {
        "database_file_sha256": sha256_file(db),
        "database_logical_state_sha256": sqlite_state_sha256(db),
        "factory_off_exists": factory_off_flag.is_file(),
        "factory_off_sha256": sha256_file(factory_off_flag) if factory_off_flag.is_file() else None,
    }
    mismatches: list[str] = []
    for actual_key, expected_key in (
        ("database_file_sha256", "file_sha256"),
        ("database_logical_state_sha256", "logical_state_sha256"),
    ):
        if actual[actual_key].lower() != str(expected_db[expected_key]).lower():
            mismatches.append(
                f"{actual_key}:expected={expected_db[expected_key]}:actual={actual[actual_key]}"
            )
    if not actual["factory_off_exists"]:
        mismatches.append(f"factory_off_missing:{factory_off_flag}")
    elif str(actual["factory_off_sha256"]).lower() != str(expected_flag["sha256"]).lower():
        mismatches.append(
            "factory_off_sha256:"
            f"expected={expected_flag['sha256']}:actual={actual['factory_off_sha256']}"
        )
    return {"ready": not mismatches, "mismatches": mismatches, **actual}


def forecast(
    db: Path,
    factory_off_flag: Path,
    manifest: dict[str, Any],
    *,
    manifest_path: Path | None = None,
) -> dict[str, Any]:
    bindings = _binding_report(db, factory_off_flag, manifest)
    with connect_ro(db) as conn:
        operations = [_operation_forecast(conn, operation) for operation in manifest["operations"]]
    return {
        "mode": "forecast_read_only",
        "schema_version": SCHEMA_VERSION,
        "run_id": manifest["run_id"],
        "manifest_path": str(manifest_path) if manifest_path is not None else None,
        "manifest_sha256": sha256_file(manifest_path) if manifest_path is not None else None,
        "bindings": bindings,
        "operations": operations,
        "ready_to_apply": bindings["ready"] and all(item["ready"] for item in operations),
        "mutated": False,
    }


def _assert_apply_identity(
    manifest_path: Path,
    manifest: dict[str, Any],
    *,
    expected_manifest_sha256: str,
    confirm_run_id: str,
) -> str:
    actual_manifest_sha = sha256_file(manifest_path)
    if actual_manifest_sha.lower() != expected_manifest_sha256.strip().lower():
        raise ReconciliationError(
            "manifest SHA-256 mismatch:"
            f" expected={expected_manifest_sha256} actual={actual_manifest_sha}"
        )
    if str(manifest["run_id"]) != str(confirm_run_id):
        raise ReconciliationError(
            f"run-id confirmation mismatch: expected={manifest['run_id']} actual={confirm_run_id}"
        )
    return actual_manifest_sha


def _idempotency_key(manifest: dict[str, Any], operation: dict[str, Any]) -> str:
    return f"{manifest['run_id']}:{operation['task_id']}"


def _table_exists(conn: sqlite3.Connection, table: str) -> bool:
    return conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
        (table,),
    ).fetchone() is not None


def _external_idempotency_mismatches(
    factory_off_flag: Path,
    manifest: dict[str, Any],
) -> list[str]:
    mismatches: list[str] = []
    if not factory_off_flag.is_file():
        mismatches.append(f"factory_off_missing:{factory_off_flag}")
    else:
        actual_flag = sha256_file(factory_off_flag)
        expected_flag = str(manifest["bindings"]["factory_off"]["sha256"])
        if actual_flag.lower() != expected_flag.lower():
            mismatches.append(
                f"factory_off_sha256:expected={expected_flag}:actual={actual_flag}"
            )
    for operation in manifest["operations"]:
        for label, binding in (
            ("card", operation["card"]),
            ("source", operation["source_diagnostic"]),
        ):
            path = Path(binding["path"])
            if not path.is_file():
                mismatches.append(f"{label}_missing:{path}")
                continue
            actual = sha256_file(path)
            expected = str(binding["sha256"])
            if actual.lower() != expected.lower():
                mismatches.append(
                    f"{operation['task_id']}:{label}_sha256:expected={expected}:actual={actual}"
                )
    return mismatches


def _idempotent_apply_result(
    db: Path,
    factory_off_flag: Path,
    manifest: dict[str, Any],
    *,
    manifest_sha256: str,
    snapshot_path: Path,
) -> dict[str, Any] | None:
    """Return a verified no-op result when this exact manifest already committed."""
    with connect_ro(db) as conn:
        if not _table_exists(conn, LEDGER_TABLE):
            return None
        ledger_rows: list[sqlite3.Row] = []
        for operation in manifest["operations"]:
            ledger = conn.execute(
                f"SELECT * FROM {LEDGER_TABLE} WHERE idempotency_key=?",
                (_idempotency_key(manifest, operation),),
            ).fetchone()
            if ledger is not None:
                ledger_rows.append(ledger)
        if not ledger_rows:
            return None
        if len(ledger_rows) != len(manifest["operations"]):
            raise ReconciliationError(
                "partial idempotency ledger: refusing mixed already-applied/unapplied manifest"
            )

        verified: list[dict[str, Any]] = []
        for operation, ledger in zip(manifest["operations"], ledger_rows, strict=True):
            expected_ledger = {
                "task_id": operation["task_id"],
                "run_id": manifest["run_id"],
                "manifest_sha256": manifest_sha256,
                "from_status": operation["expected"]["status"],
                "to_status": operation["target"]["status"],
                "expected_payload_sha256": operation["expected"]["payload_sha256"],
                "target_payload_sha256": operation["target"]["payload_sha256"],
            }
            ledger_mismatches = [
                f"ledger.{key}:expected={value!r}:actual={ledger[key]!r}"
                for key, value in expected_ledger.items()
                if str(ledger[key]).lower() != str(value).lower()
            ]
            try:
                detail = json.loads(ledger["detail_json"])
            except (json.JSONDecodeError, TypeError) as exc:
                ledger_mismatches.append(f"ledger.detail_json_invalid:{exc}")
                detail = {}
            if str(detail.get("snapshot_path") or "") != str(snapshot_path):
                ledger_mismatches.append(
                    "ledger.snapshot_path:"
                    f"expected={snapshot_path!s}:actual={detail.get('snapshot_path')!s}"
                )
            snapshot_sha = str(detail.get("snapshot_sha256") or "")
            if not snapshot_path.is_file():
                ledger_mismatches.append(f"snapshot_missing:{snapshot_path}")
            elif not snapshot_sha or sha256_file(snapshot_path).lower() != snapshot_sha.lower():
                ledger_mismatches.append("snapshot_sha256_mismatch")
            task = conn.execute(
                "SELECT status, updated_at, payload_json FROM tasks WHERE id=?",
                (operation["task_id"],),
            ).fetchone()
            if task is None:
                ledger_mismatches.append("target_task_missing")
            else:
                if task["status"] != operation["target"]["status"]:
                    ledger_mismatches.append(
                        f"target.status:expected={operation['target']['status']}:actual={task['status']}"
                    )
                if task["updated_at"] != operation["target"]["updated_at"]:
                    ledger_mismatches.append(
                        "target.updated_at:"
                        f"expected={operation['target']['updated_at']}:actual={task['updated_at']}"
                    )
                target_sha = sha256_text(str(task["payload_json"] or ""))
                if target_sha.lower() != str(operation["target"]["payload_sha256"]).lower():
                    ledger_mismatches.append(
                        "target.payload_sha256:"
                        f"expected={operation['target']['payload_sha256']}:actual={target_sha}"
                    )
            if ledger_mismatches:
                raise ReconciliationError(
                    f"{operation['task_id']} idempotency verification failed: "
                    + "; ".join(ledger_mismatches)
                )
            verified.append(
                {
                    "task_id": operation["task_id"],
                    "ledger_seq": ledger["seq"],
                    "already_applied": True,
                }
            )
    external_mismatches = _external_idempotency_mismatches(factory_off_flag, manifest)
    if external_mismatches:
        raise ReconciliationError(
            "idempotent external binding mismatch: " + "; ".join(external_mismatches)
        )
    return {
        "mode": "apply_idempotent_noop",
        "schema_version": SCHEMA_VERSION,
        "run_id": manifest["run_id"],
        "manifest_sha256": manifest_sha256,
        "snapshot_path": str(snapshot_path),
        "snapshot_sha256": sha256_file(snapshot_path),
        "applied": verified,
        "already_applied": True,
        "database_file_sha256_after": sha256_file(db),
        "database_logical_state_sha256_after": sqlite_state_sha256(db),
        "mutated": False,
    }


def apply_reconciliation(
    db: Path,
    factory_off_flag: Path,
    manifest_path: Path,
    manifest: dict[str, Any],
    *,
    expected_manifest_sha256: str,
    confirm_run_id: str,
    snapshot_path: Path,
    mutation_lock_path: Path | None = None,
) -> dict[str, Any]:
    manifest_sha = _assert_apply_identity(
        manifest_path,
        manifest,
        expected_manifest_sha256=expected_manifest_sha256,
        confirm_run_id=confirm_run_id,
    )
    lock_path = mutation_lock_path or path_for_factory_flag(factory_off_flag)
    with FactoryMutationLock(lock_path, owner=f"mnt012:{manifest['run_id']}"):
        idempotent = _idempotent_apply_result(
            db,
            factory_off_flag,
            manifest,
            manifest_sha256=manifest_sha,
            snapshot_path=snapshot_path,
        )
        if idempotent is not None:
            return idempotent
        before = forecast(
            db,
            factory_off_flag,
            manifest,
            manifest_path=manifest_path,
        )
        if not before["ready_to_apply"]:
            raise ReconciliationError(
                "forecast preconditions failed: " + canonical_json(before)
            )
        snapshot_sha = sqlite_snapshot(db, snapshot_path)
        apply_wallclock = utc_now()
        applied: list[dict[str, Any]] = []
        with connect_rw(db) as conn:
            conn.execute("BEGIN IMMEDIATE")
            try:
                external_mismatches = _external_idempotency_mismatches(
                    factory_off_flag,
                    manifest,
                )
                if external_mismatches:
                    raise ReconciliationError(
                        "external binding changed after forecast: "
                        + "; ".join(external_mismatches)
                    )
                for statement in LEDGER_SCHEMA_STATEMENTS:
                    conn.execute(statement)
                for operation in manifest["operations"]:
                    row = conn.execute(
                        "SELECT * FROM tasks WHERE id=?",
                        (operation["task_id"],),
                    ).fetchone()
                    mismatches = _row_mismatches(row, operation)
                    if mismatches:
                        raise ReconciliationError(
                            f"{operation['task_id']} CAS pre-state mismatch: {'; '.join(mismatches)}"
                        )
                    assert row is not None
                    proposed = proposed_payload(operation, str(row["payload_json"] or ""))
                    proposed_sha = sha256_text(proposed)
                    if proposed_sha != str(operation["target"]["payload_sha256"]).lower():
                        raise ReconciliationError(
                            f"{operation['task_id']} target payload SHA-256 mismatch"
                        )
                    cursor = conn.execute(
                        """
                        UPDATE tasks
                        SET status=?, payload_json=?, updated_at=?
                        WHERE id=? AND kind=? AND status=? AND card_id=?
                          AND updated_at=? AND payload_json=?
                        """,
                        (
                            operation["target"]["status"],
                            proposed,
                            operation["target"]["updated_at"],
                            operation["task_id"],
                            operation["expected"]["kind"],
                            operation["expected"]["status"],
                            operation["expected"]["card_id"],
                            operation["expected"]["updated_at"],
                            row["payload_json"],
                        ),
                    )
                    if cursor.rowcount != 1:
                        raise ReconciliationError(
                            f"{operation['task_id']} compare-and-swap updated {cursor.rowcount} rows"
                        )
                    event_detail = {
                        "run_id": manifest["run_id"],
                        "manifest_sha256": manifest_sha,
                        "manifest_target_updated_at": operation["target"]["updated_at"],
                        "from_status": operation["expected"]["status"],
                        "to_status": operation["target"]["status"],
                        "reason": operation["target"]["payload_patch"]["blocked_reason"],
                        "expected_payload_sha256": operation["expected"]["payload_sha256"],
                        "target_payload_sha256": operation["target"]["payload_sha256"],
                    }
                    conn.execute(
                        """
                        INSERT INTO events(ts, entity_type, entity_id, event, detail_json)
                        VALUES (?, 'task', ?, 'mnt012_build_task_reconciled', ?)
                        """,
                        (
                            apply_wallclock,
                            operation["task_id"],
                            canonical_json(event_detail),
                        ),
                    )
                    ledger_detail = {
                        **event_detail,
                        "card_path": operation["card"]["path"],
                        "card_sha256": operation["card"]["sha256"],
                        "source_path": operation["source_diagnostic"]["path"],
                        "source_sha256": operation["source_diagnostic"]["sha256"],
                        "snapshot_path": str(snapshot_path),
                        "snapshot_sha256": snapshot_sha,
                    }
                    ledger_cursor = conn.execute(
                        f"""
                        INSERT INTO {LEDGER_TABLE}(
                            idempotency_key, ts, task_id, run_id, manifest_sha256,
                            from_status, to_status, expected_payload_sha256,
                            target_payload_sha256, detail_json
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            _idempotency_key(manifest, operation),
                            apply_wallclock,
                            operation["task_id"],
                            manifest["run_id"],
                            manifest_sha,
                            operation["expected"]["status"],
                            operation["target"]["status"],
                            operation["expected"]["payload_sha256"],
                            operation["target"]["payload_sha256"],
                            canonical_json(ledger_detail),
                        ),
                    )
                    applied.append(
                        {
                            "task_id": operation["task_id"],
                            "from_status": operation["expected"]["status"],
                            "to_status": operation["target"]["status"],
                            "target_payload_sha256": proposed_sha,
                            "ledger_seq": ledger_cursor.lastrowid,
                            "already_applied": False,
                        }
                    )
                conn.commit()
            except BaseException:
                conn.rollback()
                raise
        return {
            "mode": "apply",
            "schema_version": SCHEMA_VERSION,
            "run_id": manifest["run_id"],
            "manifest_sha256": manifest_sha,
            "snapshot_path": str(snapshot_path),
            "snapshot_sha256": snapshot_sha,
            "applied": applied,
            "already_applied": False,
            "database_file_sha256_after": sha256_file(db),
            "database_logical_state_sha256_after": sqlite_state_sha256(db),
            "mutated": True,
        }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", choices=("forecast", "apply"), default="forecast")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--factory-off-flag", type=Path, default=DEFAULT_FACTORY_OFF)
    parser.add_argument("--expected-manifest-sha256")
    parser.add_argument("--confirm-run-id")
    parser.add_argument("--snapshot", type=Path)
    parser.add_argument("--mutation-lock", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    manifest_path = args.manifest.resolve()
    manifest = load_manifest(manifest_path)
    try:
        if args.action == "forecast":
            result = forecast(
                args.db,
                args.factory_off_flag,
                manifest,
                manifest_path=manifest_path,
            )
            print(json.dumps(result, indent=2, ensure_ascii=False))
            return 0 if result["ready_to_apply"] else 2
        if not args.expected_manifest_sha256 or not args.confirm_run_id or args.snapshot is None:
            raise ReconciliationError(
                "apply requires --expected-manifest-sha256, --confirm-run-id, and --snapshot"
            )
        result = apply_reconciliation(
            args.db,
            args.factory_off_flag,
            manifest_path,
            manifest,
            expected_manifest_sha256=args.expected_manifest_sha256,
            confirm_run_id=args.confirm_run_id,
            snapshot_path=args.snapshot,
            mutation_lock_path=args.mutation_lock,
        )
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0
    except (OSError, sqlite3.Error, ReconciliationError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
