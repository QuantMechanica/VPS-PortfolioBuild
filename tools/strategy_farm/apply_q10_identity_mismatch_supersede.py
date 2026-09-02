#!/usr/bin/env python3
"""Supersede the 16 malformed Q10_NEWS identity rows from 2026-09-02.

The rows are historical evidence and are never edited.  Apply records a
canonical supersession edge with no replacement row, under the shared factory
mutation lock and after one online SQLite backup.  Dry-run emits a hash-bound
plan; apply revalidates every exact source identity before one transaction.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import uuid
from pathlib import Path
from typing import Any

try:
    from factory_mutation_lock import FactoryMutationLock
except ModuleNotFoundError:  # pragma: no cover
    from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
DEFAULT_MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
EVIDENCE_PATH = Path(
    r"C:\QM\repo\docs\ops\evidence\2026-09-02_ceo_wave1_q10-news-gate-unblock-plan.md"
)
ROUTER_TASK_ID = "45800644-c186-4215-895c-a0fc67925a8d"
PLAN_SCHEMA = "qm.q10-identity-mismatch-supersede-plan/v1"
RECEIPT_SCHEMA = "qm.q10-identity-mismatch-supersede-receipt/v1"
SOURCE_ENCODING = f"router:q10-identity-mismatch-batch:{ROUTER_TASK_ID}"
REASON = (
    "Q10_NEWS row was created by heuristic cascade with a Q08_INPUT identity "
    "mismatch; no readable exact Q08 evidence can authenticate the frozen input"
)
TARGET_IDS = (
    "bd840961-23a1-4fea-99ce-2e285c0d1914",
    "cec67ad5-2ca5-4d84-b347-a0c370415329",
    "9d3f470e-5071-4398-86c7-7de4be979c3d",
    "d3312a9e-038a-4ab8-b392-0dbdfa2728e0",
    "1d9a2d26-4407-4554-acbb-4e4c258f0b04",
    "70171429-8d84-49bd-8082-7034c924dbf4",
    "e8ec3223-886a-400b-ba1b-096a82cebd9f",
    "58ae0036-5bc4-4711-8bfa-eb3465af298b",
    "9f691044-d481-4f69-8823-267d80fff89d",
    "9b69d492-82df-4703-9350-fea30afac98f",
    "f3f1cedc-c0d6-4485-917c-7f3b98957453",
    "42c8debd-ca2a-4618-8aaf-b9c3ee379f61",
    "a8e36fba-36e7-419a-9d2b-5b3116cbdde2",
    "15e7deca-13e8-4760-9e8e-5918040f948d",
    "60ce66e6-8c40-493a-aa8f-40c8714a3e85",
    "120d68ff-bf61-4b16-abf8-1867aee53bb3",
)


class SupersedeBatchError(RuntimeError):
    pass


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_new_json(path: Path, value: dict[str, Any]) -> str:
    if path.exists():
        raise SupersedeBatchError(f"output_exists:{path}")
    data = canonical_bytes(value)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_bytes(data)
    temporary.replace(path)
    return sha256_bytes(data)


def connect(db: Path, *, read_only: bool) -> sqlite3.Connection:
    if read_only:
        conn = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True, timeout=30)
    else:
        conn = sqlite3.connect(str(db), timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def source_identity(row: sqlite3.Row) -> dict[str, Any]:
    payload = json.loads(str(row["payload_json"] or "{}"))
    return {
        "id": row["id"],
        "ea_id": row["ea_id"],
        "symbol": row["symbol"],
        "phase": row["phase"],
        "kind": row["kind"],
        "status": row["status"],
        "verdict": row["verdict"],
        "claimed_by": row["claimed_by"],
        "setfile_path": row["setfile_path"],
        "created_at": row["created_at"],
        "promoted_from_work_item": payload.get("promoted_from_work_item"),
    }


def validate_source(conn: sqlite3.Connection, source_id: str) -> tuple[sqlite3.Row, dict[str, Any]]:
    row = conn.execute("SELECT * FROM work_items WHERE id=?", (source_id,)).fetchone()
    if row is None:
        raise SupersedeBatchError(f"source_missing:{source_id}")
    identity = source_identity(row)
    if (
        row["phase"] != "Q10_NEWS"
        or row["kind"] != "backtest"
        or row["status"] != "pending"
        or row["verdict"] is not None
        or str(row["claimed_by"] or "").strip()
        or not identity["promoted_from_work_item"]
    ):
        raise SupersedeBatchError(f"source_prestate_mismatch:{source_id}")
    hold = conn.execute(
        "SELECT * FROM work_item_holds WHERE work_item_id=?", (source_id,)
    ).fetchone()
    if hold is None or hold["hold_code"] != "Q09_AWAITING_SEALED_PLAN" or int(hold["active"]) != 1:
        raise SupersedeBatchError(f"active_sealed_plan_hold_missing:{source_id}")
    parent = conn.execute(
        "SELECT id,phase,ea_id,symbol,status,verdict FROM work_items WHERE id=?",
        (identity["promoted_from_work_item"],),
    ).fetchone()
    # This exact malformed cohort was promoted from a Q09 row where the Q10
    # binder requires a frozen Q08 input.  Requiring that wrong-but-observed
    # parent shape keeps the one-shot scope fail-closed.
    if (
        parent is None
        or parent["phase"] != "Q09"
        or parent["status"] != "done"
        or parent["verdict"] != "PASS"
        or parent["ea_id"] != row["ea_id"]
        or parent["symbol"] != row["symbol"]
    ):
        raise SupersedeBatchError(f"malformed_q09_parent_prestate_mismatch:{source_id}")
    if conn.execute(
        "SELECT 1 FROM work_item_supersedes WHERE work_item_id=?", (source_id,)
    ).fetchone():
        raise SupersedeBatchError(f"source_already_superseded:{source_id}")
    return row, identity


def build_plan(db: Path) -> dict[str, Any]:
    if not EVIDENCE_PATH.is_file():
        raise SupersedeBatchError(f"evidence_missing:{EVIDENCE_PATH}")
    conn = connect(db, read_only=True)
    try:
        targets = []
        for source_id in TARGET_IDS:
            row, identity = validate_source(conn, source_id)
            targets.append({
                "source_work_item_id": source_id,
                "source_identity_sha256": sha256_bytes(canonical_bytes(identity)),
                "ea_id": row["ea_id"],
                "symbol": row["symbol"],
                "setfile_path": row["setfile_path"],
                "promoted_from_work_item": identity["promoted_from_work_item"],
            })
    finally:
        conn.close()
    plan = {
        "schema": PLAN_SCHEMA,
        "generated_at_utc": utc_now(),
        "database": str(db.resolve()),
        "router_task_id": ROUTER_TASK_ID,
        "evidence_path": str(EVIDENCE_PATH.resolve()),
        "evidence_sha256": sha256_file(EVIDENCE_PATH),
        "source_encoding": SOURCE_ENCODING,
        "reason": REASON,
        "mutation": "APPEND_SUPERSESSION_EDGES_ONLY",
        "historical_work_item_updates": 0,
        "historical_hold_updates": 0,
        "targets": targets,
    }
    plan["targets_sha256"] = sha256_bytes(canonical_bytes(targets))
    return plan


def validate_plan(plan: dict[str, Any]) -> None:
    targets = plan.get("targets") or []
    if plan.get("schema") != PLAN_SCHEMA or plan.get("router_task_id") != ROUTER_TASK_ID:
        raise SupersedeBatchError("wrong_plan_authority")
    if plan.get("source_encoding") != SOURCE_ENCODING or plan.get("reason") != REASON:
        raise SupersedeBatchError("wrong_plan_disposition")
    if [row.get("source_work_item_id") for row in targets] != list(TARGET_IDS):
        raise SupersedeBatchError("target_scope_changed")
    if sha256_bytes(canonical_bytes(targets)) != plan.get("targets_sha256"):
        raise SupersedeBatchError("target_manifest_hash_mismatch")
    if sha256_file(EVIDENCE_PATH) != plan.get("evidence_sha256"):
        raise SupersedeBatchError("evidence_drift")


def backup_database(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    destination = backup_dir / (
        f"farm_state_before_q10_identity_mismatch_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    )
    source = sqlite3.connect(str(db), timeout=30)
    target = sqlite3.connect(str(destination))
    try:
        source.backup(target)
    finally:
        target.close()
        source.close()
    return destination, sha256_file(destination)


def apply_plan(
    *, db: Path, plan_path: Path, expected_plan_sha256: str, receipt_out: Path,
    backup_dir: Path, mutation_lock: Path,
) -> dict[str, Any]:
    expected = expected_plan_sha256.lower()
    if sha256_file(plan_path) != expected:
        raise SupersedeBatchError("plan_sha256_mismatch")
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    validate_plan(plan)
    applied_at = utc_now()
    inserted: list[str] = []
    with FactoryMutationLock(mutation_lock, owner=f"q10-mismatch:{ROUTER_TASK_ID}"):
        backup_path, backup_sha = backup_database(db, backup_dir)
        conn = connect(db, read_only=False)
        try:
            conn.execute("BEGIN IMMEDIATE")
            for target in plan["targets"]:
                row, identity = validate_source(conn, target["source_work_item_id"])
                del row
                if sha256_bytes(canonical_bytes(identity)) != target["source_identity_sha256"]:
                    raise SupersedeBatchError(
                        f"source_identity_drift:{target['source_work_item_id']}"
                    )
            for target in plan["targets"]:
                source_id = target["source_work_item_id"]
                conn.execute(
                    """INSERT INTO work_item_supersedes(
                         work_item_id,superseded_by_work_item_id,reason,source_encoding,
                         evidence_path,recorded_by,recorded_at) VALUES(?,NULL,?,?,?,?,?)""",
                    (source_id, REASON, SOURCE_ENCODING, str(EVIDENCE_PATH.resolve()), "codex", applied_at),
                )
                conn.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)",
                    (
                        applied_at, "work_item", source_id, "work_item_superseded",
                        json.dumps({
                            "reason": REASON,
                            "source_encoding": SOURCE_ENCODING,
                            "router_task_id": ROUTER_TASK_ID,
                            "superseded_by_work_item_id": None,
                        }, sort_keys=True),
                    ),
                )
                inserted.append(source_id)
            readback = conn.execute(
                "SELECT COUNT(*) FROM work_item_supersedes WHERE source_encoding=?",
                (SOURCE_ENCODING,),
            ).fetchone()[0]
            if int(readback) != len(TARGET_IDS):
                raise SupersedeBatchError(f"pre_commit_readback:{readback}!={len(TARGET_IDS)}")
            conn.commit()
            quick_check = conn.execute("PRAGMA quick_check").fetchone()[0]
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
    receipt = {
        "schema": RECEIPT_SCHEMA,
        "applied_at_utc": applied_at,
        "router_task_id": ROUTER_TASK_ID,
        "plan_path": str(plan_path.resolve()),
        "plan_sha256": expected,
        "backup": {"path": str(backup_path.resolve()), "sha256": backup_sha},
        "source_encoding": SOURCE_ENCODING,
        "superseded_work_item_ids": inserted,
        "superseded_count": len(inserted),
        "successor_rows_created": 0,
        "historical_work_item_updates": 0,
        "historical_hold_updates": 0,
        "quick_check": quick_check,
    }
    receipt["receipt_sha256"] = write_new_json(receipt_out, receipt)
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_MUTATION_LOCK)
    parser.add_argument("--plan-out", type=Path)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--expected-plan-sha256")
    parser.add_argument("--receipt-out", type=Path)
    args = parser.parse_args()
    try:
        if args.apply:
            if not args.plan or not args.expected_plan_sha256 or not args.receipt_out:
                raise SupersedeBatchError("apply_requires_plan_hash_and_receipt")
            result = apply_plan(
                db=args.db, plan_path=args.plan,
                expected_plan_sha256=args.expected_plan_sha256,
                receipt_out=args.receipt_out, backup_dir=args.backup_dir,
                mutation_lock=args.mutation_lock,
            )
        else:
            result = build_plan(args.db)
            if args.plan_out:
                result["plan_file_sha256"] = write_new_json(args.plan_out, result)
        result["status"] = "ok"
        print(json.dumps(result, indent=1, default=str))
        return 0
    except (SupersedeBatchError, sqlite3.Error, OSError, RuntimeError, ValueError) as exc:
        print(json.dumps({
            "schema": RECEIPT_SCHEMA if args.apply else PLAN_SCHEMA,
            "status": "aborted",
            "reason": f"{type(exc).__name__}: {exc}",
        }, indent=1))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
