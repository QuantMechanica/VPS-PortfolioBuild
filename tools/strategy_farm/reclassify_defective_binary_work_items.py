#!/usr/bin/env python3
"""Hash-bound reclassification of completed work items from one defective EX5.

``plan`` is read-only and binds the complete target set by EA, phase, EX5 hash,
expected IDs, and row preimage hashes.  ``apply`` requires that exact plan hash,
holds the global Factory mutation lock, creates an online SQLite backup, uses
compare-and-swap updates, and appends both transition-ledger and event rows.
It never enqueues, claims, cancels, or reruns a work item.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import sys
from typing import Any, Iterable


_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from factory_mutation_lock import FactoryMutationLock  # noqa: E402


PLAN_SCHEMA = "qm.defective-binary-work-item-reclassification-plan/v1"
RECEIPT_SCHEMA = "qm.defective-binary-work-item-reclassification-receipt/v1"
HISTORY_SCHEMA = "qm.defective-binary-work-item-reclassification/v1"
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
DEFAULT_MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
WORK_ITEM_COLUMNS = (
    "id",
    "kind",
    "phase",
    "ea_id",
    "symbol",
    "setfile_path",
    "status",
    "verdict",
    "attempt_count",
    "parent_task_id",
    "evidence_path",
    "claimed_by",
    "payload_json",
    "created_at",
    "updated_at",
)


class ReclassificationError(RuntimeError):
    """Fail-closed selection, preimage, backup, CAS, or audit error."""


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def pretty_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def _atomic_write(path: Path, raw: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(raw)
    temporary.replace(path)


def _connect(path: Path, *, read_only: bool) -> sqlite3.Connection:
    if not path.is_file():
        raise ReclassificationError(f"database not found: {path}")
    if read_only:
        conn = sqlite3.connect(f"file:{path.resolve().as_posix()}?mode=ro", uri=True)
    else:
        conn = sqlite3.connect(path, timeout=30.0)
    conn.row_factory = sqlite3.Row
    return conn


def _row_snapshot(row: sqlite3.Row) -> dict[str, Any]:
    return {column: row[column] for column in WORK_ITEM_COLUMNS}


def _row_state_sha256(row: sqlite3.Row) -> str:
    return sha256_bytes(canonical_json_bytes(_row_snapshot(row)))


def _payload(raw: str) -> dict[str, Any]:
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ReclassificationError(f"invalid payload_json: {exc}") from exc
    if not isinstance(value, dict):
        raise ReclassificationError("payload_json is not an object")
    return value


def _select_rows(
    conn: sqlite3.Connection,
    *,
    ea_id: str,
    phase: str,
    expected_ex5_sha256: str,
) -> list[sqlite3.Row]:
    rows = conn.execute(
        f"SELECT {', '.join(WORK_ITEM_COLUMNS)} FROM work_items "
        "WHERE ea_id=? AND phase=? ORDER BY id",
        (ea_id, phase),
    ).fetchall()
    selected = []
    for row in rows:
        payload = _payload(str(row["payload_json"]))
        if str(payload.get("expected_ex5_sha256") or "").casefold() == expected_ex5_sha256:
            selected.append(row)
    return selected


def _validate_target_rows(
    rows: list[sqlite3.Row],
    *,
    expected_ids: set[str],
    expected_ex5_sha256: str,
) -> None:
    actual_ids = {str(row["id"]) for row in rows}
    if actual_ids != expected_ids:
        raise ReclassificationError(
            f"hash-keyed target set mismatch: expected={sorted(expected_ids)} actual={sorted(actual_ids)}"
        )
    for row in rows:
        if row["status"] != "done":
            raise ReclassificationError(f"target {row['id']} is not completed: {row['status']}")
        if row["claimed_by"] is not None:
            raise ReclassificationError(f"target {row['id']} is still claimed: {row['claimed_by']}")
        payload = _payload(str(row["payload_json"]))
        staged = payload.get("staged_ex5") or {}
        staged_sha = str(staged.get("required_sha256") or "").casefold()
        if staged_sha != expected_ex5_sha256:
            raise ReclassificationError(
                f"target {row['id']} staged EX5 mismatch: {staged_sha or '<missing>'}"
            )
        evidence = Path(str(row["evidence_path"] or ""))
        if not evidence.is_file():
            raise ReclassificationError(f"target {row['id']} evidence missing: {evidence}")


def build_plan(
    db: Path,
    *,
    ea_id: str,
    phase: str,
    expected_ex5_sha256: str,
    expected_ids: Iterable[str],
    authority_task_id: str,
    reason: str,
    evidence_path: str,
    planned_at_utc: str | None = None,
) -> dict[str, Any]:
    expected_ex5_sha256 = expected_ex5_sha256.casefold()
    if not SHA256_RE.fullmatch(expected_ex5_sha256):
        raise ReclassificationError("expected EX5 SHA-256 must be 64 lowercase hex characters")
    expected_id_set = {item.strip() for item in expected_ids if item.strip()}
    if not expected_id_set:
        raise ReclassificationError("at least one exact expected work-item ID is required")
    if not authority_task_id.strip() or not reason.strip() or not evidence_path.strip():
        raise ReclassificationError("authority task, reason, and evidence path are required")

    planned_at = planned_at_utc or utc_now()
    with _connect(db, read_only=True) as conn:
        rows = _select_rows(
            conn,
            ea_id=ea_id,
            phase=phase,
            expected_ex5_sha256=expected_ex5_sha256,
        )
        _validate_target_rows(
            rows,
            expected_ids=expected_id_set,
            expected_ex5_sha256=expected_ex5_sha256,
        )
        plan_rows = []
        for row in rows:
            payload = _payload(str(row["payload_json"]))
            history = list(payload.get("defective_binary_reclassifications") or [])
            history_entry = {
                "schema": HISTORY_SCHEMA,
                "authority_task_id": authority_task_id,
                "evidence_path": evidence_path,
                "expected_ex5_sha256": expected_ex5_sha256,
                "from_verdict": row["verdict"],
                "reason": reason,
                "reclassified_at_utc": planned_at,
            }
            history.append(history_entry)
            payload["defective_binary_reclassifications"] = history
            payload["verdict_reason"] = reason
            payload["verdict_taxonomy"] = "implementation"
            payload["strategy_verdict_voided_by_defective_binary"] = True
            target_payload_json = json.dumps(payload, sort_keys=True, separators=(",", ":"))
            evidence_file = Path(str(row["evidence_path"]))
            plan_rows.append(
                {
                    "id": row["id"],
                    "symbol": row["symbol"],
                    "from_status": row["status"],
                    "to_status": row["status"],
                    "from_verdict": row["verdict"],
                    "to_verdict": "DRAFT_DEFECT",
                    "preimage_state_sha256": _row_state_sha256(row),
                    "preimage_payload_sha256": sha256_bytes(str(row["payload_json"]).encode("utf-8")),
                    "target_payload_json": target_payload_json,
                    "target_payload_sha256": sha256_bytes(target_payload_json.encode("utf-8")),
                    "target_updated_at": planned_at,
                    "evidence_path": str(evidence_file),
                    "evidence_sha256": sha256_file(evidence_file),
                }
            )

    return {
        "schema": PLAN_SCHEMA,
        "planned_at_utc": planned_at,
        "authority_task_id": authority_task_id,
        "operation": "HASH_KEYED_COMPLETED_ROWS_TO_DRAFT_DEFECT",
        "database": str(db.resolve()),
        "selection": {
            "ea_id": ea_id,
            "phase": phase,
            "expected_ex5_sha256": expected_ex5_sha256,
            "expected_ids": sorted(expected_id_set),
            "expected_count": len(expected_id_set),
        },
        "reason": reason,
        "evidence_path": evidence_path,
        "invariants": [
            "selection is keyed by payload expected_ex5_sha256",
            "exact selected ID set equals expected_ids",
            "every target is done and unclaimed",
            "every target staged_ex5.required_sha256 matches",
            "raw summary evidence is preserved",
            "no work item is enqueued, claimed, cancelled, or rerun",
        ],
        "rows": plan_rows,
    }


def plan_sha256(plan: dict[str, Any]) -> str:
    return sha256_bytes(pretty_json_bytes(plan))


def _backup_database(source: Path, backup_dir: Path, *, stamp: str, ea_id: str) -> Path:
    backup_dir.mkdir(parents=True, exist_ok=True)
    safe_stamp = re.sub(r"[^0-9]", "", stamp)[:14]
    destination = backup_dir / f"farm_state_before_{ea_id.lower()}_defective_binary_{safe_stamp}Z.sqlite"
    if destination.exists():
        raise ReclassificationError(f"backup destination already exists: {destination}")
    with sqlite3.connect(source) as source_conn, sqlite3.connect(destination) as backup_conn:
        source_conn.backup(backup_conn)
    with sqlite3.connect(destination) as check_conn:
        result = str(check_conn.execute("PRAGMA quick_check").fetchone()[0])
    if result.casefold() != "ok":
        raise ReclassificationError(f"backup quick_check failed: {result}")
    return destination


def apply_plan(
    plan: dict[str, Any],
    *,
    expected_plan_sha256: str,
    db: Path,
    backup_dir: Path,
    mutation_lock: Path,
) -> dict[str, Any]:
    actual_plan_sha = plan_sha256(plan)
    if actual_plan_sha != expected_plan_sha256.casefold():
        raise ReclassificationError(
            f"plan SHA-256 mismatch: expected={expected_plan_sha256} actual={actual_plan_sha}"
        )
    if plan.get("schema") != PLAN_SCHEMA:
        raise ReclassificationError(f"unsupported plan schema: {plan.get('schema')!r}")
    if Path(str(plan.get("database"))).resolve() != db.resolve():
        raise ReclassificationError("apply database does not match the hash-bound plan")

    selection = dict(plan["selection"])
    rows_by_id = {str(row["id"]): dict(row) for row in plan["rows"]}
    expected_ids = set(selection["expected_ids"])
    if set(rows_by_id) != expected_ids:
        raise ReclassificationError("plan rows do not equal the plan's exact expected ID set")

    with FactoryMutationLock(mutation_lock, owner="reclassify_defective_binary_work_items.apply"):
        backup_path = _backup_database(
            db,
            backup_dir,
            stamp=str(plan["planned_at_utc"]),
            ea_id=str(selection["ea_id"]),
        )
        conn = _connect(db, read_only=False)
        try:
            conn.execute("BEGIN IMMEDIATE")
            current_rows = _select_rows(
                conn,
                ea_id=str(selection["ea_id"]),
                phase=str(selection["phase"]),
                expected_ex5_sha256=str(selection["expected_ex5_sha256"]),
            )
            _validate_target_rows(
                current_rows,
                expected_ids=expected_ids,
                expected_ex5_sha256=str(selection["expected_ex5_sha256"]),
            )
            for current in current_rows:
                target = rows_by_id[str(current["id"])]
                if _row_state_sha256(current) != target["preimage_state_sha256"]:
                    raise ReclassificationError(f"row preimage drift: {current['id']}")
                cursor = conn.execute(
                    "UPDATE work_items SET verdict=?, payload_json=?, updated_at=? "
                    "WHERE id=? AND status=? AND verdict IS ? AND payload_json=? AND updated_at=?",
                    (
                        target["to_verdict"],
                        target["target_payload_json"],
                        target["target_updated_at"],
                        current["id"],
                        target["from_status"],
                        target["from_verdict"],
                        current["payload_json"],
                        current["updated_at"],
                    ),
                )
                if cursor.rowcount != 1:
                    raise ReclassificationError(f"compare-and-swap failed: {current['id']}")
                detail = {
                    "schema": HISTORY_SCHEMA,
                    "authority_task_id": plan["authority_task_id"],
                    "expected_ex5_sha256": selection["expected_ex5_sha256"],
                    "evidence_path": plan["evidence_path"],
                    "plan_sha256": actual_plan_sha,
                    "preimage_state_sha256": target["preimage_state_sha256"],
                    "target_payload_sha256": target["target_payload_sha256"],
                }
                idempotency_key = (
                    f"defective-binary:{selection['expected_ex5_sha256']}:{current['id']}"
                )
                conn.execute(
                    "INSERT INTO work_item_transition_ledger "
                    "(idempotency_key,ts,work_item_id,action,from_status,to_status,"
                    "from_verdict,to_verdict,from_claimed_by,to_claimed_by,reason,run_id,detail_json) "
                    "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    (
                        idempotency_key,
                        plan["planned_at_utc"],
                        current["id"],
                        "reclassify_defective_binary",
                        current["status"],
                        current["status"],
                        current["verdict"],
                        target["to_verdict"],
                        current["claimed_by"],
                        current["claimed_by"],
                        plan["reason"],
                        plan["authority_task_id"],
                        json.dumps(detail, sort_keys=True, separators=(",", ":")),
                    ),
                )
                conn.execute(
                    "INSERT INTO events (ts,entity_type,entity_id,event,detail_json) "
                    "VALUES (?,?,?,?,?)",
                    (
                        plan["planned_at_utc"],
                        "work_item",
                        current["id"],
                        "defective_binary_reclassified",
                        json.dumps(detail, sort_keys=True, separators=(",", ":")),
                    ),
                )
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    with _connect(db, read_only=True) as verify_conn:
        verified = _select_rows(
            verify_conn,
            ea_id=str(selection["ea_id"]),
            phase=str(selection["phase"]),
            expected_ex5_sha256=str(selection["expected_ex5_sha256"]),
        )
        after = []
        for row in verified:
            payload = _payload(str(row["payload_json"]))
            after.append(
                {
                    "id": row["id"],
                    "symbol": row["symbol"],
                    "status": row["status"],
                    "verdict": row["verdict"],
                    "payload_sha256": sha256_bytes(str(row["payload_json"]).encode("utf-8")),
                    "history_count": len(payload.get("defective_binary_reclassifications") or []),
                    "updated_at": row["updated_at"],
                }
            )
        if {row["id"] for row in after} != expected_ids:
            raise ReclassificationError("post-apply target set drift")
        if any(row["verdict"] != "DRAFT_DEFECT" for row in after):
            raise ReclassificationError("post-apply verdict verification failed")

    return {
        "schema": RECEIPT_SCHEMA,
        "applied_at_utc": utc_now(),
        "authority_task_id": plan["authority_task_id"],
        "plan_sha256": actual_plan_sha,
        "database": str(db.resolve()),
        "database_sha256_after": sha256_file(db),
        "backup_path": str(backup_path.resolve()),
        "backup_sha256": sha256_file(backup_path),
        "selection": selection,
        "rows": after,
        "raw_summary_evidence_mutated": False,
        "work_items_enqueued_or_rerun": 0,
    }


def _load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ReclassificationError(f"JSON root is not an object: {path}")
    return value


def _add_runtime_paths(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    plan_parser = sub.add_parser("plan", help="read-only exact-set plan")
    _add_runtime_paths(plan_parser)
    plan_parser.add_argument("--ea-id", required=True)
    plan_parser.add_argument("--phase", default="Q02")
    plan_parser.add_argument("--expected-ex5-sha256", required=True)
    plan_parser.add_argument("--expected-id", action="append", required=True)
    plan_parser.add_argument("--authority-task-id", required=True)
    plan_parser.add_argument("--reason", required=True)
    plan_parser.add_argument("--evidence-path", required=True)
    plan_parser.add_argument("--output", type=Path, required=True)

    apply_parser = sub.add_parser("apply", help="backup + lock + exact CAS apply")
    _add_runtime_paths(apply_parser)
    apply_parser.add_argument("--plan", type=Path, required=True)
    apply_parser.add_argument("--expected-plan-sha256", required=True)
    apply_parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    apply_parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_MUTATION_LOCK)
    apply_parser.add_argument("--receipt", type=Path, required=True)

    args = parser.parse_args()
    try:
        if args.command == "plan":
            plan = build_plan(
                args.db,
                ea_id=args.ea_id,
                phase=args.phase,
                expected_ex5_sha256=args.expected_ex5_sha256,
                expected_ids=args.expected_id,
                authority_task_id=args.authority_task_id,
                reason=args.reason,
                evidence_path=args.evidence_path,
            )
            rendered = pretty_json_bytes(plan)
            _atomic_write(args.output.resolve(), rendered)
            print(json.dumps({"plan": str(args.output.resolve()), "sha256": sha256_bytes(rendered)}, indent=2))
            return 0

        plan = _load_json(args.plan.resolve())
        receipt = apply_plan(
            plan,
            expected_plan_sha256=args.expected_plan_sha256,
            db=args.db,
            backup_dir=args.backup_dir,
            mutation_lock=args.mutation_lock,
        )
        rendered = pretty_json_bytes(receipt)
        _atomic_write(args.receipt.resolve(), rendered)
        print(json.dumps({"receipt": str(args.receipt.resolve()), "sha256": sha256_bytes(rendered)}, indent=2))
        return 0
    except (OSError, sqlite3.Error, ReclassificationError, ValueError) as exc:
        print(f"REFUSED: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
