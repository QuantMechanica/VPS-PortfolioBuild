#!/usr/bin/env python3
"""Guarded, auditable maintenance transitions for Strategy Farm work items.

Dry-run is the default.  ``apply`` requires exact SHA-256 bindings for both the
SQLite database and the current FACTORY_OFF flag plus a fresh SQLite snapshot.
The raw work-item row is changed only after its expected pre-state matches; the
before/after transition is recorded in an append-only ledger and in ``events``.
"""

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import hashlib
import json
import re
import sqlite3
import sys
from pathlib import Path
from typing import Any

from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_FACTORY_OFF = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")

ALLOWED_ACTIONS = {"hold", "requeue_hold", "quarantine"}
ALLOWED_STATUSES = {"pending", "active", "done", "failed"}


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


def _validate_held_mutation_lock(
    lock_path: Path,
    *,
    expected_owner_pid: int,
    expected_owner: str,
    expected_nonce: str,
) -> dict[str, Any]:
    """Authenticate a live lock held by the coordinating Factory_ON process.

    Factory_ON opens the lock with read sharing only.  The nonce prevents this
    narrowly scoped bypass from turning into a generic `--ignore-lock` switch.
    """
    if expected_owner_pid <= 0 or not expected_owner.strip() or not expected_nonce.strip():
        raise RuntimeError("held mutation lock identity is incomplete")
    try:
        payload = json.loads(lock_path.read_text(encoding="utf-8-sig"))
    except Exception as exc:
        raise RuntimeError(f"held mutation lock cannot be authenticated: {lock_path}: {exc}") from exc
    expected = {
        "pid": int(expected_owner_pid),
        "owner": expected_owner,
        "nonce": expected_nonce,
    }
    actual = {key: payload.get(key) for key in expected}
    if actual != expected:
        raise RuntimeError(f"held mutation lock identity mismatch: expected={expected!r} actual={actual!r}")
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


def release_restart_holds(
    db: Path,
    *,
    factory_off_flag: Path,
    expected_db_sha256: str | None,
    apply: bool,
    release_note: str,
    mutation_lock_path: Path | None = None,
    held_lock_owner_pid: int | None = None,
    held_lock_owner: str | None = None,
    held_lock_nonce: str | None = None,
) -> dict[str, Any]:
    lock_path = mutation_lock_path or path_for_factory_flag(factory_off_flag)
    if not apply:
        if factory_off_flag.exists():
            raise RuntimeError("release-on-restart is forbidden while FACTORY_OFF.flag exists")
        if expected_db_sha256 and sha256_file(db).lower() != expected_db_sha256.lower():
            raise RuntimeError("DB SHA-256 mismatch")
        with connect_ro(db) as conn:
            try:
                rows = conn.execute(
                    "SELECT * FROM work_item_holds WHERE active=1 AND release_on_restart=1 ORDER BY work_item_id"
                ).fetchall()
            except sqlite3.OperationalError:
                rows = []
        return {
            "mode": "dry_run",
            "release_count": len(rows),
            "work_item_ids": [row["work_item_id"] for row in rows],
        }

    if held_lock_owner_pid is None:
        lock_context: Any = FactoryMutationLock(
            lock_path, owner="maintenance_control.release_restart_holds"
        )
        lock_mode = "acquired"
    else:
        _validate_held_mutation_lock(
            lock_path,
            expected_owner_pid=held_lock_owner_pid,
            expected_owner=held_lock_owner or "",
            expected_nonce=held_lock_nonce or "",
        )
        lock_context = contextlib.nullcontext()
        lock_mode = "authenticated_factory_on_lock"

    with lock_context:
        if factory_off_flag.exists():
            raise RuntimeError("release-on-restart is forbidden while FACTORY_OFF.flag exists")
        if expected_db_sha256 and sha256_file(db).lower() != expected_db_sha256.lower():
            raise RuntimeError("DB SHA-256 mismatch")
        with connect_rw(db) as conn:
            try:
                rows = conn.execute(
                    "SELECT * FROM work_item_holds WHERE active=1 AND release_on_restart=1 ORDER BY work_item_id"
                ).fetchall()
            except sqlite3.OperationalError:
                rows = []
            now = utc_now()
            conn.execute("BEGIN IMMEDIATE")
            for row in rows:
                key = f"restart-release:{row['work_item_id']}:{row['created_at']}"
                conn.execute(
                    "UPDATE work_item_holds SET active=0, updated_at=?, released_at=?, release_note=? WHERE work_item_id=? AND active=1",
                    (now, now, release_note, row["work_item_id"]),
                )
                conn.execute(
                    """
                    INSERT OR IGNORE INTO work_item_transition_ledger(
                        idempotency_key, ts, work_item_id, action, reason, run_id, detail_json
                    ) VALUES (?, ?, ?, 'release_hold', ?, 'coordinated_restart', '{}')
                    """,
                    (key, now, row["work_item_id"], release_note),
                )
                conn.execute(
                    "INSERT INTO events(ts, entity_type, entity_id, event, detail_json) VALUES (?, 'work_item', ?, 'maintenance_hold_released', ?)",
                    (now, row["work_item_id"], json.dumps({"release_note": release_note})),
                )
            conn.commit()
        wal_checkpoint = checkpoint_wal(db)
        return {
            "mode": "apply",
            "released": [row["work_item_id"] for row in rows],
            "post_db_sha256": sha256_file(db),
            "post_db_state_sha256": sqlite_state_sha256(db),
            "wal_checkpoint": wal_checkpoint,
            "mutation_lock_path": str(lock_path),
            "mutation_lock_mode": lock_mode,
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
    release.add_argument("--expected-db-sha256")
    release.add_argument("--release-note", default="coordinated factory restart gate passed")
    release.add_argument("--held-lock-owner-pid", type=int)
    release.add_argument("--held-lock-owner")
    release.add_argument("--held-lock-nonce")

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
            held_lock_owner_pid=args.held_lock_owner_pid,
            held_lock_owner=args.held_lock_owner,
            held_lock_nonce=args.held_lock_nonce,
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
