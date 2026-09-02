#!/usr/bin/env python3
"""Append the exact build-task-bound successor for QM5_41285's enqueue incident.

The original COMPILE_EA row was released before a build task existed.  It is
source-fresh and unclaimed, but therefore lacks the immutable build-task
binding used by the paced queue's prerequisite lane.  This utility never edits
that row.  It validates the exact row, source, released hold, and sole open
build task, then appends one held successor plus a canonical supersession edge.

Dry-run is the default.  Apply takes an online SQLite backup and holds the
factory mutation lock for the append transaction.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import time
import uuid
from pathlib import Path
from typing import Any

try:
    import compile_work_items as cwi
    from factory_mutation_lock import FactoryMutationLock
    from work_item_supersedes import ensure_schema as ensure_supersedes_schema
except ModuleNotFoundError:
    from tools.strategy_farm import compile_work_items as cwi
    from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock
    from tools.strategy_farm.work_item_supersedes import (
        ensure_schema as ensure_supersedes_schema,
    )


DEFAULT_ROOT = Path(r"D:\QM\strategy_farm")
DEFAULT_REPO = Path(r"C:\QM\repo")
DEFAULT_BACKUP_DIR = DEFAULT_ROOT / "state" / "backups"
DEFAULT_MUTATION_LOCK = DEFAULT_ROOT / "state" / "FACTORY_MUTATION.lock"
PREDECESSOR_ID = cwi.QM5_41285_UNBOUND_COMPILE_RETRY_PREDECESSOR_ID
EA_LABEL = cwi.QM5_41285_UNBOUND_COMPILE_RETRY_EA_LABEL
EA_ID = "QM5_41285"
NUMERIC_EA_ID = "41285"
SOURCE_SHA256 = cwi.QM5_41285_UNBOUND_COMPILE_RETRY_SOURCE_SHA256
RETRY_CONTRACT = cwi.QM5_41285_UNBOUND_COMPILE_RETRY_CONTRACT_VERSION
RETRY_AUTHORITY = cwi.QM5_41285_UNBOUND_COMPILE_RETRY_AUTHORITY
RETRY_REASON = "COMPILE_ENQUEUED_BEFORE_BUILD_TASK_BINDING"
HOLD_REASON = (
    "Exact append-only QM5_41285 successor is bound to the sole governed build "
    "task; release only through the bounded COMPILE_EA rollout ceremony"
)


class RetryError(RuntimeError):
    """Fail-closed exact-incident, binding, backup, or transaction refusal."""


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).isoformat(timespec="microseconds")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def payload_object(raw: Any) -> dict[str, Any]:
    try:
        value = json.loads(str(raw or "{}"))
    except (TypeError, json.JSONDecodeError) as exc:
        raise RetryError("WORK_ITEM_PAYLOAD_INVALID") from exc
    if not isinstance(value, dict):
        raise RetryError("WORK_ITEM_PAYLOAD_NOT_OBJECT")
    return value


def connect(root: Path, *, read_only: bool) -> sqlite3.Connection:
    db = root / "state" / "farm_state.sqlite"
    if read_only:
        conn = sqlite3.connect(db.resolve().as_uri() + "?mode=ro", uri=True, timeout=30)
    else:
        conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def row_preimage_sha256(row: sqlite3.Row) -> str:
    fields = (
        "id", "kind", "phase", "ea_id", "symbol", "setfile_path", "status",
        "verdict", "attempt_count", "parent_task_id", "evidence_path",
        "claimed_by", "payload_json", "created_at", "updated_at",
    )
    document = {field: row[field] for field in fields}
    return sha256_bytes(
        json.dumps(document, sort_keys=True, separators=(",", ":")).encode("utf-8")
    )


def canonical_source(repo: Path) -> Path:
    return (
        repo / "framework" / "EAs" / EA_LABEL / f"{EA_LABEL}.mq5"
    ).resolve()


def build_task_inventory(conn: sqlite3.Connection) -> dict[str, Any]:
    by_id: dict[str, dict[str, Any]] = {}
    by_ea: dict[str, list[dict[str, Any]]] = {}
    for task_row in conn.execute(
        "SELECT id,status,card_id,payload_json FROM tasks WHERE kind='build_ea'"
    ):
        task = dict(task_row)
        task_id = str(task_row["id"])
        by_id[task_id] = task
        numeric = cwi._numeric_ea_reference(task_row["card_id"])
        if numeric:
            by_ea.setdefault(numeric, []).append(task)
    return {"build_tasks_by_id": by_id, "build_tasks_by_ea": by_ea}


def inspect(root: Path, repo: Path, build_task_id: str) -> dict[str, Any]:
    source = canonical_source(repo)
    reasons: list[str] = []
    with connect(root, read_only=True) as conn:
        predecessor = conn.execute(
            "SELECT * FROM work_items WHERE id=?", (PREDECESSOR_ID,)
        ).fetchone()
        if predecessor is None:
            raise RetryError("EXACT_PREDECESSOR_MISSING")
        old_payload = payload_object(predecessor["payload_json"])
        hold = conn.execute(
            "SELECT * FROM work_item_holds WHERE work_item_id=? AND hold_code=?",
            (PREDECESSOR_ID, cwi.COMPILE_ACTIVATION_HOLD_CODE),
        ).fetchone()
        link = conn.execute(
            "SELECT * FROM work_item_supersedes WHERE work_item_id=?",
            (PREDECESSOR_ID,),
        ).fetchone()
        successors = list(conn.execute(
            "SELECT id,status,verdict,payload_json FROM work_items "
            "WHERE ea_id=? AND phase=? "
            "AND json_extract(payload_json, '$.compile_unbound_task_retry_contract_version')=? "
            "ORDER BY created_at,id",
            (EA_ID, cwi.COMPILE_EA_PHASE, RETRY_CONTRACT),
        ))
        task_binding = cwi._build_task_binding(
            repo,
            EA_LABEL,
            NUMERIC_EA_ID,
            build_task_id,
            build_task_inventory(conn),
        )

    if successors:
        successor = successors[0]
        successor_payload = payload_object(successor["payload_json"])
        valid_existing = bool(
            len(successors) == 1
            and link is not None
            and str(link["superseded_by_work_item_id"]) == str(successor["id"])
            and successor_payload.get("retry_of_work_item_id") == PREDECESSOR_ID
            and successor_payload.get("compile_unbound_task_retry_authority")
            == RETRY_AUTHORITY
            and successor_payload.get("bound_build_task_id") == build_task_id
            and successor_payload.get("unbound_compile_retry_work_item_id")
            == str(successor["id"])
        )
        return {
            "schema_version": RETRY_CONTRACT,
            "mode": "dry_run",
            "classification": "already_applied" if valid_existing else "held",
            "eligible": False,
            "idempotent_noop": valid_existing,
            "hold_reasons": [] if valid_existing else ["EXISTING_SUCCESSOR_INVALID"],
            "predecessor_work_item_id": PREDECESSOR_ID,
            "successor_work_item_id": str(successor["id"]),
            "build_task_id": build_task_id,
            "task_binding": task_binding,
            "source_path": str(source),
            "source_sha256": sha256_file(source) if source.is_file() else None,
        }

    if link is not None:
        reasons.append("PREDECESSOR_ALREADY_SUPERSEDED")
    if not (
        predecessor["kind"] == cwi.COMPILE_WORK_ITEM_KIND
        and predecessor["phase"] == cwi.COMPILE_EA_PHASE
        and predecessor["ea_id"] == EA_ID
        and predecessor["status"] == "pending"
        and predecessor["verdict"] is None
        and int(predecessor["attempt_count"] or 0) == 0
        and predecessor["claimed_by"] is None
        and predecessor["evidence_path"] is None
        and predecessor["parent_task_id"] is None
        and not str(predecessor["setfile_path"] or "")
    ):
        reasons.append("PREDECESSOR_STATE_MISMATCH")
    if not (
        old_payload.get("compile_contract_version") == cwi.COMPILE_CONTRACT_VERSION
        and old_payload.get("ea_label") == EA_LABEL
        and str(old_payload.get("mq5_sha256") or "").lower() == SOURCE_SHA256
        and old_payload.get("utility_phase") is True
        and old_payload.get("no_gate_verdict") is True
        and not old_payload.get("bound_build_task_id")
    ):
        reasons.append("PREDECESSOR_PAYLOAD_MISMATCH")
    if hold is None or int(hold["active"] or 0) != 0 or not hold["released_at"]:
        reasons.append("PREDECESSOR_RELEASED_HOLD_MISMATCH")
    actual_source_sha = sha256_file(source) if source.is_file() else None
    if actual_source_sha != SOURCE_SHA256:
        reasons.append("SOURCE_SHA256_MISMATCH")
    if not task_binding.get("authorized"):
        reasons.append(str(task_binding.get("reason") or "BUILD_TASK_BINDING_INVALID"))

    return {
        "schema_version": RETRY_CONTRACT,
        "mode": "dry_run",
        "classification": "eligible" if not reasons else "held",
        "eligible": not reasons,
        "idempotent_noop": False,
        "hold_reasons": sorted(set(reasons)),
        "predecessor_work_item_id": PREDECESSOR_ID,
        "predecessor_preimage_sha256": row_preimage_sha256(predecessor),
        "successor_work_item_id": None,
        "build_task_id": build_task_id,
        "task_binding": task_binding,
        "source_path": str(source),
        "source_sha256": actual_source_sha,
        "invariants": [
            "the released unbound predecessor remains immutable",
            "only the exact QM5_41285 source hash and predecessor are selectable",
            "the successor is bound to the sole open governed build task",
            "the successor is activation-held, fixed-risk, and carries no gate verdict",
            "the canonical supersession edge removes only the obsolete queue row",
        ],
    }


def backup_database(root: Path, backup_dir: Path) -> tuple[Path, str]:
    source_path = root / "state" / "farm_state.sqlite"
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    destination = backup_dir / (
        f"farm_state_before_qm5_41285_unbound_compile_retry_{stamp}_"
        f"{uuid.uuid4().hex[:8]}.sqlite"
    )
    with sqlite3.connect(source_path, timeout=30) as source, sqlite3.connect(destination) as target:
        source.execute("PRAGMA busy_timeout=30000")
        source.backup(target)
    with sqlite3.connect(destination) as check:
        quick_check = str(check.execute("PRAGMA quick_check").fetchone()[0])
    if quick_check.casefold() != "ok":
        raise RetryError(f"BACKUP_QUICK_CHECK_FAILED:{quick_check}")
    return destination, sha256_file(destination)


def acquire_backup_write_guard(
    root: Path,
    *,
    timeout_seconds: float = 15.0,
) -> tuple[sqlite3.Connection, dict[str, Any]]:
    """Wait for one write window and retain a RESERVED lock during backup.

    SQLite online backups are readers and can be starved indefinitely by the
    farm's queued long writers.  A no-op BEGIN IMMEDIATE waits its turn, blocks
    later writers once admitted, and still permits the separate backup reader.
    The short bound matters: a writer that predates the filesystem lock may
    itself need that lock to finish, so this attempt releases and retries
    instead of creating a cross-lock convoy.  The transaction is always rolled
    back without changing the database.
    """

    db = root / "state" / "farm_state.sqlite"
    started = time.monotonic()
    attempts = 0
    last_error = ""
    while time.monotonic() - started < timeout_seconds:
        attempts += 1
        guard = sqlite3.connect(db, timeout=30)
        guard.execute("PRAGMA busy_timeout=30000")
        try:
            guard.execute("BEGIN IMMEDIATE")
            return guard, {
                "attempts": attempts,
                "wait_seconds": round(time.monotonic() - started, 3),
                "transaction": "BEGIN IMMEDIATE / no writes / ROLLBACK",
            }
        except sqlite3.OperationalError as exc:
            guard.close()
            last_error = str(exc)
            if "locked" not in last_error.casefold() and "busy" not in last_error.casefold():
                raise
            time.sleep(0.5)
    raise RetryError(
        "BACKUP_WRITE_WINDOW_TIMEOUT:"
        f"attempts={attempts}:last_error={last_error or 'unknown'}"
    )


def apply_retry(
    root: Path,
    repo: Path,
    build_task_id: str,
    backup_dir: Path,
    mutation_lock: Path,
) -> dict[str, Any]:
    preflight = inspect(root, repo, build_task_id)
    if preflight["classification"] == "already_applied":
        return {**preflight, "mode": "apply", "applied_count": 0, "backup": None}
    if not preflight["eligible"]:
        return {**preflight, "mode": "apply", "applied_count": 0, "backup": None}

    expected_preimage = str(preflight["predecessor_preimage_sha256"])
    new_id = str(uuid.uuid4())
    lock = FactoryMutationLock(
        mutation_lock,
        owner="retry_qm5_41285_unbound_compile.apply",
    )
    backup_path: Path | None = None
    backup_sha: str | None = None
    backup_guard_detail: dict[str, Any] | None = None
    with lock:
        backup_guard, backup_guard_detail = acquire_backup_write_guard(root)
        try:
            backup_path, backup_sha = backup_database(root, backup_dir)
        finally:
            try:
                backup_guard.rollback()
            finally:
                backup_guard.close()
        recheck = inspect(root, repo, build_task_id)
        if not recheck["eligible"]:
            raise RetryError(
                "ELIGIBILITY_DRIFTED:" + ";".join(recheck.get("hold_reasons") or [])
            )
        if recheck["predecessor_preimage_sha256"] != expected_preimage:
            raise RetryError("PREDECESSOR_PREIMAGE_DRIFTED")

        with connect(root, read_only=False) as conn:
            ensure_supersedes_schema(conn)
            conn.execute("BEGIN IMMEDIATE")
            try:
                predecessor = conn.execute(
                    "SELECT * FROM work_items WHERE id=?", (PREDECESSOR_ID,)
                ).fetchone()
                if predecessor is None or row_preimage_sha256(predecessor) != expected_preimage:
                    raise RetryError("PREDECESSOR_CHANGED_AT_APPLY")
                task_binding = cwi._build_task_binding(
                    repo,
                    EA_LABEL,
                    NUMERIC_EA_ID,
                    build_task_id,
                    build_task_inventory(conn),
                )
                if not task_binding.get("authorized"):
                    raise RetryError(
                        "BUILD_TASK_BINDING_CHANGED_AT_APPLY:"
                        + str(task_binding.get("reason"))
                    )
                if sha256_file(canonical_source(repo)) != SOURCE_SHA256:
                    raise RetryError("SOURCE_CHANGED_AT_APPLY")
                if conn.execute(
                    "SELECT 1 FROM work_item_supersedes WHERE work_item_id=?",
                    (PREDECESSOR_ID,),
                ).fetchone():
                    raise RetryError("PREDECESSOR_SUPERSEDED_AT_APPLY")

                old_payload = payload_object(predecessor["payload_json"])
                now = utc_now()
                new_payload = dict(old_payload)
                new_payload.update({
                    "compile_activation_state": "AWAITING_REVIEWED_WORKER_ROLLOUT",
                    "compile_activation_hold_code": cwi.COMPILE_ACTIVATION_HOLD_CODE,
                    "compile_build_task_binding_contract_version": (
                        cwi.BUILD_TASK_BINDING_CONTRACT_VERSION
                    ),
                    "bound_build_task_id": build_task_id,
                    "bound_build_task_ea_id": EA_ID,
                    "compile_unbound_task_retry_contract_version": RETRY_CONTRACT,
                    "compile_unbound_task_retry_authority": RETRY_AUTHORITY,
                    "retry_of_work_item_id": PREDECESSOR_ID,
                    "unbound_compile_retry_work_item_id": new_id,
                    "retry_reason": RETRY_REASON,
                    "append_only_unbound_task_retry": True,
                    "retry_predecessor_preimage_sha256": expected_preimage,
                    "enqueued_at": now,
                })
                conn.execute(
                    "INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,"
                    "status,verdict,attempt_count,parent_task_id,evidence_path,claimed_by,"
                    "payload_json,created_at,updated_at) VALUES "
                    "(?,'compile','COMPILE_EA',?,'','', 'pending',NULL,0,NULL,NULL,NULL,?,?,?)",
                    (new_id, EA_ID, json.dumps(new_payload, sort_keys=True), now, now),
                )
                conn.execute(
                    "INSERT INTO work_item_holds(work_item_id,hold_code,reason,active,"
                    "release_on_restart,created_at,updated_at,released_at,release_note) "
                    "VALUES (?,?,?,1,1,?,?,NULL,NULL)",
                    (
                        new_id,
                        cwi.COMPILE_ACTIVATION_HOLD_CODE,
                        HOLD_REASON,
                        now,
                        now,
                    ),
                )
                detail = {
                    "schema_version": RETRY_CONTRACT,
                    "authority": RETRY_AUTHORITY,
                    "predecessor_work_item_id": PREDECESSOR_ID,
                    "predecessor_preimage_sha256": expected_preimage,
                    "successor_work_item_id": new_id,
                    "build_task_id": build_task_id,
                    "mq5_sha256": SOURCE_SHA256,
                    "activation_hold_code": cwi.COMPILE_ACTIVATION_HOLD_CODE,
                    "no_gate_verdict": True,
                }
                detail_json = json.dumps(detail, sort_keys=True, separators=(",", ":"))
                conn.execute(
                    "INSERT INTO work_item_supersedes(work_item_id,"
                    "superseded_by_work_item_id,reason,source_encoding,evidence_path,"
                    "recorded_by,recorded_at) VALUES (?,?,?,?,?,'codex',?)",
                    (
                        PREDECESSOR_ID,
                        new_id,
                        RETRY_REASON,
                        "operator:qm5-41285-unbound-compile-retry/v1",
                        "artifacts/qm5_41285_unbound_compile_retry_20260902.json",
                        now,
                    ),
                )
                conn.execute(
                    "INSERT INTO work_item_transition_ledger(idempotency_key,ts,"
                    "work_item_id,action,from_status,to_status,from_verdict,to_verdict,"
                    "from_claimed_by,to_claimed_by,reason,run_id,detail_json) VALUES "
                    "(?,?,?,'append_only_unbound_compile_retry',NULL,'pending',NULL,NULL,"
                    "NULL,NULL,?,?,?)",
                    (
                        f"qm5-41285-unbound-compile-retry:{PREDECESSOR_ID}",
                        now,
                        new_id,
                        RETRY_REASON,
                        RETRY_AUTHORITY,
                        detail_json,
                    ),
                )
                conn.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                    "VALUES (?,'work_item',?,'compile_ea_append_only_unbound_retry',?)",
                    (now, new_id, detail_json),
                )
                conn.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                    "VALUES (?,'work_item',?,'compile_ea_successor_appended',?)",
                    (now, PREDECESSOR_ID, detail_json),
                )
                conn.commit()
            except Exception:
                conn.rollback()
                raise

    post = inspect(root, repo, build_task_id)
    verification_errors: list[str] = []
    if post.get("classification") != "already_applied":
        verification_errors.append("SUCCESSOR_NOT_OBSERVABLE")
    if post.get("successor_work_item_id") != new_id:
        verification_errors.append("SUCCESSOR_ID_MISMATCH")
    return {
        **preflight,
        "mode": "apply",
        "applied_at_utc": utc_now(),
        "applied_count": 1,
        "successor_work_item_id": new_id,
        "backup": {"path": str(backup_path), "sha256": backup_sha},
        "backup_write_guard": backup_guard_detail,
        "post": post,
        "factory_mutation_lock": {
            "path": str(mutation_lock),
            "release_status": lock.release_status,
        },
        "verification_ok": not verification_errors,
        "verification_errors": verification_errors,
    }


def write_json_atomic(path: Path, document: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_text(
        json.dumps(document, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--build-task-id", required=True)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_MUTATION_LOCK)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = (
        apply_retry(
            args.root,
            args.repo,
            args.build_task_id,
            args.backup_dir,
            args.mutation_lock,
        )
        if args.apply
        else inspect(args.root, args.repo, args.build_task_id)
    )
    if args.output:
        write_json_atomic(args.output, result)
    print(json.dumps(result, indent=2, sort_keys=True))
    verification_ok = result.get("verification_ok")
    if verification_ok is not None:
        return 0 if verification_ok else 2
    return 0 if result.get("eligible") or result.get("idempotent_noop") else 2


if __name__ == "__main__":
    raise SystemExit(main())
