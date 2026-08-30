#!/usr/bin/env python3
"""Apply OWNER-DEC-Q09HOLD-RETIRE-2-20260829 append-only dispositions.

This one-shot tool is deliberately bound to two exact Q10_NEWS rows. Dry-run
writes a content-addressed plan. Apply requires the plan hash, takes an online
SQLite backup, revalidates the exact rows under the shared mutation lock,
appends two terminal RETIRE rows, records claim-proof supersession edges, and
closes only the two authorized holds. Original work-item rows are never edited.
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
DEFAULT_DECISIONS = Path(r"D:\QM\reports\state\owner_decisions.json")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
DEFAULT_MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
EVIDENCE_PATH = Path(
    r"C:\QM\repo\docs\ops\evidence\2026-08-30_026de980_q09_retire2.md"
)

AUTHORIZED_ROUTER_TASK_ID = "026de980-3788-40b3-ac27-521100428b7a"
OWNER_DECISION_ID = "OWNER-DEC-Q09HOLD-RETIRE-2-20260829"
OWNER_RECEIPT_ID = "7bfa4067"
HOLD_CODE = "Q09_AWAITING_SEALED_PLAN"
NEWS_PHASE = "Q10_NEWS"
PLAN_SCHEMA = "qm.q09-retire2-plan/v1"
RECEIPT_SCHEMA = "qm.q09-retire2-receipt/v1"
DISPOSITION_NAMESPACE = uuid.UUID("580862ea-433d-4ceb-8f00-610b6491483a")
REPAIR_NAMESPACE = uuid.UUID("72f77a93-19c2-4e50-b75f-a93f3d20779a")
TARGETS = (
    ("49a059da-82ab-4835-9c46-f18ba9b94dcf", "QM5_10847", "GDAXI.DWX"),
    ("84c6e9e9-76a8-4cd4-87b4-647d7fad3c1a", "QM5_13301", "GDAXI.DWX"),
)


class Retire2Error(RuntimeError):
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
        raise Retire2Error(f"output_exists:{path}")
    data = canonical_bytes(value)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_bytes(data)
    temporary.replace(path)
    return sha256_bytes(data)


def connect(db: Path, *, read_only: bool) -> sqlite3.Connection:
    if read_only:
        connection = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True, timeout=30)
    else:
        connection = sqlite3.connect(str(db), timeout=30)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA busy_timeout=30000")
    return connection


def disposition_id(source_id: str) -> str:
    return str(uuid.uuid5(DISPOSITION_NAMESPACE, f"{OWNER_DECISION_ID}|{source_id}"))


def repaired_disposition_id(source_id: str) -> str:
    return str(uuid.uuid5(REPAIR_NAMESPACE, f"{OWNER_DECISION_ID}|{source_id}|canonical-retire"))


def decision_record(path: Path) -> tuple[dict[str, Any], str]:
    payload = json.loads(path.read_text(encoding="utf-8-sig"))
    matches = [row for row in payload.get("items", []) if row.get("id") == OWNER_DECISION_ID]
    if len(matches) != 1:
        raise Retire2Error(f"owner_decision_count:{len(matches)}")
    record = matches[0]
    if record.get("status") != "DECIDED" or record.get("last_decision") != "YES":
        raise Retire2Error("owner_decision_not_yes")
    receipt_id = str(record.get("last_receipt_id") or "")
    if not receipt_id.startswith(OWNER_RECEIPT_ID):
        raise Retire2Error(f"wrong_owner_receipt:{receipt_id}")
    return record, sha256_bytes(canonical_bytes(record))


def _active_hold_count(connection: sqlite3.Connection) -> int:
    return int(connection.execute(
        "SELECT COUNT(*) FROM work_item_holds WHERE hold_code=? AND active=1",
        (HOLD_CODE,),
    ).fetchone()[0])


def build_plan(db: Path, decisions: Path) -> dict[str, Any]:
    record, record_sha = decision_record(decisions)
    if not EVIDENCE_PATH.is_file():
        raise Retire2Error(f"evidence_missing:{EVIDENCE_PATH}")
    connection = connect(db, read_only=True)
    try:
        rows: list[dict[str, Any]] = []
        for source_id, ea_id, symbol in TARGETS:
            row = connection.execute(
                """SELECT w.*,h.hold_code,h.active AS hold_active,
                          h.release_on_restart,h.created_at AS hold_created_at,
                          h.updated_at AS hold_updated_at,h.release_note
                   FROM work_items w JOIN work_item_holds h ON h.work_item_id=w.id
                   WHERE w.id=?""",
                (source_id,),
            ).fetchone()
            if row is None:
                raise Retire2Error(f"target_missing:{source_id}")
            if (
                row["ea_id"] != ea_id
                or row["symbol"] != symbol
                or row["phase"] != NEWS_PHASE
                or row["status"] != "pending"
                or row["verdict"] is not None
                or str(row["claimed_by"] or "").strip()
                or row["hold_code"] != HOLD_CODE
                or int(row["hold_active"]) != 1
                or int(row["release_on_restart"]) != 0
                or row["release_note"] is not None
            ):
                raise Retire2Error(f"target_prestate_mismatch:{source_id}")
            new_id = disposition_id(source_id)
            if connection.execute("SELECT 1 FROM work_items WHERE id=?", (new_id,)).fetchone():
                raise Retire2Error(f"disposition_exists:{new_id}")
            if connection.execute(
                "SELECT 1 FROM work_item_supersedes WHERE work_item_id=?", (source_id,)
            ).fetchone():
                raise Retire2Error(f"source_already_superseded:{source_id}")
            rows.append({
                "source_work_item_id": source_id,
                "source_identity_sha256": sha256_bytes(canonical_bytes({
                    "id": row["id"], "ea_id": row["ea_id"], "symbol": row["symbol"],
                    "phase": row["phase"], "status": row["status"],
                    "verdict": row["verdict"], "created_at": row["created_at"],
                    "setfile_path": row["setfile_path"],
                })),
                "ea_id": ea_id,
                "symbol": symbol,
                "setfile_path": row["setfile_path"],
                "gate_contract_version": row["gate_contract_version"] or "legacy",
                "disposition_work_item_id": new_id,
                "hold_created_at": row["hold_created_at"],
                "hold_updated_at": row["hold_updated_at"],
            })
        active_before = _active_hold_count(connection)
    finally:
        connection.close()
    plan = {
        "schema": PLAN_SCHEMA,
        "generated_at_utc": utc_now(),
        "database": str(db.resolve()),
        "router_task_id": AUTHORIZED_ROUTER_TASK_ID,
        "owner_decision": {"id": OWNER_DECISION_ID, "record_sha256": record_sha},
        "evidence_path": str(EVIDENCE_PATH.resolve()),
        "evidence_sha256": sha256_file(EVIDENCE_PATH),
        "active_news_holds_before": active_before,
        "targets": rows,
        "historical_work_item_updates": 0,
    }
    plan["targets_sha256"] = sha256_bytes(canonical_bytes(rows))
    return plan


def validate_plan(plan: dict[str, Any], decisions: Path) -> None:
    if plan.get("schema") != PLAN_SCHEMA:
        raise Retire2Error("wrong_plan_schema")
    if plan.get("router_task_id") != AUTHORIZED_ROUTER_TASK_ID:
        raise Retire2Error("wrong_router_task_id")
    if plan.get("owner_decision", {}).get("id") != OWNER_DECISION_ID:
        raise Retire2Error("wrong_owner_decision")
    record, record_sha = decision_record(decisions)
    del record
    if record_sha != plan.get("owner_decision", {}).get("record_sha256"):
        raise Retire2Error("owner_decision_record_drift")
    targets = plan.get("targets") or []
    if len(targets) != 2 or sha256_bytes(canonical_bytes(targets)) != plan.get("targets_sha256"):
        raise Retire2Error("target_manifest_invalid")
    actual_scope = {(row["source_work_item_id"], row["ea_id"], row["symbol"]) for row in targets}
    if actual_scope != set(TARGETS):
        raise Retire2Error("target_scope_changed")
    if sha256_file(EVIDENCE_PATH) != plan.get("evidence_sha256"):
        raise Retire2Error("evidence_drift")


def backup_database(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    destination = backup_dir / f"farm_state_before_q09_retire2_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    source = sqlite3.connect(str(db), timeout=30)
    target = sqlite3.connect(str(destination))
    try:
        source.backup(target)
    finally:
        target.close()
        source.close()
    return destination, sha256_file(destination)


def apply_plan(
    *, db: Path, decisions: Path, plan_path: Path, expected_plan_sha256: str,
    receipt_out: Path, backup_dir: Path, mutation_lock: Path,
) -> dict[str, Any]:
    if sha256_file(plan_path) != expected_plan_sha256.lower():
        raise Retire2Error("plan_sha256_mismatch")
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    validate_plan(plan, decisions)
    backup_path, backup_sha = backup_database(db, backup_dir)
    applied_at = utc_now()
    release_note = (
        f"OWNER-approved pair retirement; {OWNER_DECISION_ID}; "
        f"router_task={AUTHORIZED_ROUTER_TASK_ID}; disposition-only"
    )
    inserted: list[str] = []
    released: list[str] = []
    with FactoryMutationLock(mutation_lock, owner=f"q09-retire2:{AUTHORIZED_ROUTER_TASK_ID}"):
        connection = connect(db, read_only=False)
        try:
            connection.execute("BEGIN IMMEDIATE")
            active_before = _active_hold_count(connection)
            if active_before != int(plan["active_news_holds_before"]):
                raise Retire2Error(
                    f"active_hold_count_drift:{active_before}!={plan['active_news_holds_before']}"
                )
            for target in plan["targets"]:
                source = connection.execute("SELECT * FROM work_items WHERE id=?", (
                    target["source_work_item_id"],
                )).fetchone()
                if source is None:
                    raise Retire2Error(f"source_vanished:{target['source_work_item_id']}")
                identity = {
                    "id": source["id"], "ea_id": source["ea_id"], "symbol": source["symbol"],
                    "phase": source["phase"], "status": source["status"],
                    "verdict": source["verdict"], "created_at": source["created_at"],
                    "setfile_path": source["setfile_path"],
                }
                if sha256_bytes(canonical_bytes(identity)) != target["source_identity_sha256"]:
                    raise Retire2Error(f"source_identity_drift:{source['id']}")
                hold = connection.execute(
                    "SELECT * FROM work_item_holds WHERE work_item_id=?", (source["id"],)
                ).fetchone()
                if hold is None or hold["hold_code"] != HOLD_CODE or int(hold["active"]) != 1:
                    raise Retire2Error(f"hold_prestate_drift:{source['id']}")
                if connection.execute(
                    "SELECT 1 FROM work_items WHERE id=?", (target["disposition_work_item_id"],)
                ).fetchone():
                    raise Retire2Error(f"disposition_raced:{target['disposition_work_item_id']}")
                if connection.execute(
                    "SELECT 1 FROM work_item_supersedes WHERE work_item_id=?", (source["id"],)
                ).fetchone():
                    raise Retire2Error(f"supersession_raced:{source['id']}")

            for target in plan["targets"]:
                payload = {
                    "append_only_disposition": True,
                    "disposition": "RETIRE",
                    "economic_failure_lineage": True,
                    "historical_evidence_preserved": True,
                    "historical_verdicts_preserved": True,
                    "owner_decision_id": OWNER_DECISION_ID,
                    "owner_decision_record_sha256": plan["owner_decision"]["record_sha256"],
                    "plan_sha256": expected_plan_sha256.lower(),
                    "router_task_id": AUTHORIZED_ROUTER_TASK_ID,
                    "source_work_item_id": target["source_work_item_id"],
                    "verdict_reason": "OWNER_APPROVED_ECONOMIC_FAIL_PAIR_RETIREMENT",
                }
                connection.execute(
                    """INSERT INTO work_items(
                         id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                         attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,
                         created_at,updated_at,verdict_taxonomy_stored,clean_status_stored,
                         gate_contract_version,verdict_taxonomy,sh3_enforced
                       ) VALUES(?,'disposition',?,?,?,?, 'failed','RETIRED_ARCHIVED',0,
                         NULL,?,NULL,?,?,?,'strategy','failed',?,'strategy',0)""",
                    (
                        target["disposition_work_item_id"], NEWS_PHASE, target["ea_id"],
                        target["symbol"], target["setfile_path"], str(EVIDENCE_PATH.resolve()),
                        json.dumps(payload, sort_keys=True), applied_at, applied_at,
                        target["gate_contract_version"],
                    ),
                )
                connection.execute(
                    """INSERT INTO work_item_supersedes(
                         work_item_id,superseded_by_work_item_id,reason,source_encoding,
                         evidence_path,recorded_by,recorded_at) VALUES(?,?,?,?,?,?,?)""",
                    (
                        target["source_work_item_id"], target["disposition_work_item_id"],
                        f"OWNER-approved economic-fail pair retirement; {OWNER_DECISION_ID}",
                        "owner:q09-retire2/v1", str(EVIDENCE_PATH.resolve()),
                        "codex", applied_at,
                    ),
                )
                cursor = connection.execute(
                    """UPDATE work_item_holds SET active=0,updated_at=?,released_at=?,release_note=?
                       WHERE work_item_id=? AND hold_code=? AND active=1
                         AND release_on_restart=0 AND release_note IS NULL""",
                    (
                        applied_at, applied_at, release_note,
                        target["source_work_item_id"], HOLD_CODE,
                    ),
                )
                if cursor.rowcount != 1:
                    raise Retire2Error(f"hold_release_cas_failed:{target['source_work_item_id']}")
                detail = json.dumps({
                    "decision": OWNER_DECISION_ID,
                    "disposition_work_item_id": target["disposition_work_item_id"],
                    "release_note": release_note,
                }, sort_keys=True)
                connection.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)",
                    (applied_at, "work_item", target["source_work_item_id"],
                     "owner_pair_retired_hold_released", detail),
                )
                inserted.append(target["disposition_work_item_id"])
                released.append(target["source_work_item_id"])

            active_after = _active_hold_count(connection)
            if active_after != active_before - 2:
                raise Retire2Error(f"hold_count_delta_invalid:{active_before}->{active_after}")
            connection.commit()
            quick_check = connection.execute("PRAGMA quick_check").fetchone()[0]
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    receipt = {
        "schema": RECEIPT_SCHEMA,
        "applied_at_utc": applied_at,
        "router_task_id": AUTHORIZED_ROUTER_TASK_ID,
        "owner_decision_id": OWNER_DECISION_ID,
        "plan_path": str(plan_path.resolve()),
        "plan_sha256": expected_plan_sha256.lower(),
        "backup": {"path": str(backup_path.resolve()), "sha256": backup_sha},
        "inserted_dispositions": inserted,
        "released_holds": released,
        "active_news_holds_before": active_before,
        "active_news_holds_after": active_after,
        "active_news_hold_delta": active_after - active_before,
        "historical_work_item_updates": 0,
        "quick_check": quick_check,
    }
    receipt["receipt_sha256"] = write_new_json(receipt_out, receipt)
    return receipt


def build_repair_plan(db: Path, decisions: Path) -> dict[str, Any]:
    """Bind the two SH-3-normalized first-attempt rows for append-only repair."""
    record, record_sha = decision_record(decisions)
    del record
    connection = connect(db, read_only=True)
    try:
        targets: list[dict[str, Any]] = []
        for source_id, ea_id, symbol in TARGETS:
            first_id = disposition_id(source_id)
            first = connection.execute("SELECT * FROM work_items WHERE id=?", (first_id,)).fetchone()
            if first is None:
                raise Retire2Error(f"first_disposition_missing:{first_id}")
            payload = json.loads(str(first["payload_json"] or "{}"))
            if (
                first["ea_id"] != ea_id or first["symbol"] != symbol
                or first["kind"] != "disposition" or first["phase"] != NEWS_PHASE
                or first["status"] != "failed" or first["verdict"] != "INFRA_FAIL"
                or payload.get("owner_decision_id") != OWNER_DECISION_ID
                or payload.get("router_task_id") != AUTHORIZED_ROUTER_TASK_ID
                or payload.get("verdict_reason") != "ARTIFACT_IDENTITY_MISSING"
                or payload.get("source_work_item_id") != source_id
            ):
                raise Retire2Error(f"first_disposition_not_exact_sh3_rewrite:{first_id}")
            hold = connection.execute(
                "SELECT * FROM work_item_holds WHERE work_item_id=?", (source_id,)
            ).fetchone()
            if (
                hold is None or hold["hold_code"] != HOLD_CODE or int(hold["active"]) != 0
                or OWNER_DECISION_ID not in str(hold["release_note"] or "")
            ):
                raise Retire2Error(f"released_hold_drift:{source_id}")
            repaired_id = repaired_disposition_id(source_id)
            if connection.execute("SELECT 1 FROM work_items WHERE id=?", (repaired_id,)).fetchone():
                raise Retire2Error(f"repaired_disposition_exists:{repaired_id}")
            targets.append({
                "source_work_item_id": source_id,
                "first_disposition_work_item_id": first_id,
                "first_disposition_payload_sha256": sha256_bytes(
                    str(first["payload_json"]).encode("utf-8")
                ),
                "repaired_disposition_work_item_id": repaired_id,
                "ea_id": ea_id,
                "symbol": symbol,
                "setfile_path": first["setfile_path"],
                "gate_contract_version": first["gate_contract_version"] or "legacy",
            })
        active_holds = _active_hold_count(connection)
    finally:
        connection.close()
    plan = {
        "schema": "qm.q09-retire2-sh3-repair-plan/v1",
        "generated_at_utc": utc_now(),
        "database": str(db.resolve()),
        "router_task_id": AUTHORIZED_ROUTER_TASK_ID,
        "owner_decision": {"id": OWNER_DECISION_ID, "record_sha256": record_sha},
        "evidence_path": str(EVIDENCE_PATH.resolve()),
        "evidence_sha256": sha256_file(EVIDENCE_PATH),
        "active_news_holds_before": active_holds,
        "mutation": "APPEND_CANONICAL_RETIRE_SUCCESSORS_ONLY",
        "historical_work_item_updates": 0,
        "historical_hold_updates": 0,
        "targets": targets,
    }
    plan["targets_sha256"] = sha256_bytes(canonical_bytes(targets))
    return plan


def apply_repair_plan(
    *, db: Path, decisions: Path, plan_path: Path, expected_plan_sha256: str,
    receipt_out: Path, backup_dir: Path, mutation_lock: Path,
) -> dict[str, Any]:
    if sha256_file(plan_path) != expected_plan_sha256.lower():
        raise Retire2Error("repair_plan_sha256_mismatch")
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    if plan.get("schema") != "qm.q09-retire2-sh3-repair-plan/v1":
        raise Retire2Error("wrong_repair_plan_schema")
    record, record_sha = decision_record(decisions)
    del record
    if record_sha != plan.get("owner_decision", {}).get("record_sha256"):
        raise Retire2Error("repair_owner_decision_drift")
    targets = plan.get("targets") or []
    if (
        len(targets) != 2
        or sha256_bytes(canonical_bytes(targets)) != plan.get("targets_sha256")
        or {(r["source_work_item_id"], r["ea_id"], r["symbol"]) for r in targets} != set(TARGETS)
    ):
        raise Retire2Error("repair_target_manifest_invalid")
    if sha256_file(EVIDENCE_PATH) != plan.get("evidence_sha256"):
        raise Retire2Error("repair_evidence_drift")
    backup_path, backup_sha = backup_database(db, backup_dir)
    applied_at = utc_now()
    inserted: list[str] = []
    with FactoryMutationLock(mutation_lock, owner=f"q09-retire2-sh3-repair:{AUTHORIZED_ROUTER_TASK_ID}"):
        connection = connect(db, read_only=False)
        try:
            connection.execute("BEGIN IMMEDIATE")
            if _active_hold_count(connection) != int(plan["active_news_holds_before"]):
                raise Retire2Error("repair_active_hold_count_drift")
            for target in targets:
                first = connection.execute(
                    "SELECT * FROM work_items WHERE id=?", (target["first_disposition_work_item_id"],)
                ).fetchone()
                if (
                    first is None or first["status"] != "failed" or first["verdict"] != "INFRA_FAIL"
                    or sha256_bytes(str(first["payload_json"]).encode("utf-8"))
                    != target["first_disposition_payload_sha256"]
                ):
                    raise Retire2Error(f"repair_first_disposition_drift:{target['first_disposition_work_item_id']}")
                if connection.execute(
                    "SELECT 1 FROM work_items WHERE id=?", (target["repaired_disposition_work_item_id"],)
                ).fetchone():
                    raise Retire2Error(f"repair_disposition_raced:{target['repaired_disposition_work_item_id']}")

            for target in targets:
                payload = {
                    "append_only_disposition": True,
                    "control_plane_disposition": True,
                    "disposition": "RETIRE",
                    "economic_failure_lineage": True,
                    "historical_evidence_preserved": True,
                    "historical_verdicts_preserved": True,
                    "owner_decision_id": OWNER_DECISION_ID,
                    "owner_decision_record_sha256": plan["owner_decision"]["record_sha256"],
                    "repair_of_work_item_id": target["first_disposition_work_item_id"],
                    "repair_reason": "FIRST_DISPOSITION_SH3_NORMALIZED_MISSING_IDENTITY",
                    "router_task_id": AUTHORIZED_ROUTER_TASK_ID,
                    "source_work_item_id": target["source_work_item_id"],
                    "verdict_reason": "OWNER_APPROVED_ECONOMIC_FAIL_PAIR_RETIREMENT",
                    "verdict_taxonomy": "strategy",
                }
                connection.execute(
                    """INSERT INTO work_items(
                         id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                         attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,
                         created_at,updated_at,verdict_taxonomy_stored,clean_status_stored,
                         gate_contract_version,verdict_taxonomy,sh3_enforced
                       ) VALUES(?,'disposition',?,?,?,?, 'done','RETIRE',0,NULL,?,NULL,
                         ?,?,?,'strategy','done',?,'strategy',0)""",
                    (
                        target["repaired_disposition_work_item_id"], NEWS_PHASE,
                        target["ea_id"], target["symbol"], target["setfile_path"],
                        str(EVIDENCE_PATH.resolve()), json.dumps(payload, sort_keys=True),
                        applied_at, applied_at, target["gate_contract_version"],
                    ),
                )
                for old_id, encoding in (
                    (target["first_disposition_work_item_id"], "operator:q09-retire2-sh3-repair/v1"),
                    (target["source_work_item_id"], "owner:q09-retire2/v2"),
                ):
                    connection.execute(
                        """INSERT INTO work_item_supersedes(
                             work_item_id,superseded_by_work_item_id,reason,source_encoding,
                             evidence_path,recorded_by,recorded_at) VALUES(?,?,?,?,?,?,?)""",
                        (
                            old_id, target["repaired_disposition_work_item_id"],
                            "append-only canonical RETIRE successor after SH-3 disposition normalization",
                            encoding, str(EVIDENCE_PATH.resolve()), "codex", applied_at,
                        ),
                    )
                inserted.append(target["repaired_disposition_work_item_id"])
            rows = connection.execute(
                "SELECT id,status,verdict,sh3_enforced FROM work_items WHERE id IN (?,?) ORDER BY id",
                inserted,
            ).fetchall()
            if len(rows) != 2 or any(
                row["status"] != "done" or row["verdict"] != "RETIRE"
                or int(row["sh3_enforced"]) != 0 for row in rows
            ):
                raise Retire2Error("repair_post_insert_verdict_mismatch")
            quick_check = connection.execute("PRAGMA quick_check").fetchone()[0]
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()
    receipt = {
        "schema": "qm.q09-retire2-sh3-repair-receipt/v1",
        "applied_at_utc": applied_at,
        "router_task_id": AUTHORIZED_ROUTER_TASK_ID,
        "owner_decision_id": OWNER_DECISION_ID,
        "plan_path": str(plan_path.resolve()),
        "plan_sha256": expected_plan_sha256.lower(),
        "backup": {"path": str(backup_path.resolve()), "sha256": backup_sha},
        "inserted_canonical_retire_dispositions": inserted,
        "historical_work_item_updates": 0,
        "historical_hold_updates": 0,
        "active_news_holds_after": int(plan["active_news_holds_before"]),
        "quick_check": quick_check,
    }
    receipt["receipt_sha256"] = write_new_json(receipt_out, receipt)
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("plan", "apply", "repair-plan", "repair-apply"))
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--decisions", type=Path, default=DEFAULT_DECISIONS)
    parser.add_argument("--plan-out", type=Path)
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--expected-plan-sha256")
    parser.add_argument("--receipt-out", type=Path)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_MUTATION_LOCK)
    args = parser.parse_args()
    try:
        if args.mode in {"plan", "repair-plan"}:
            if args.plan_out is None:
                raise Retire2Error("plan_out_required")
            plan = (
                build_plan(args.db, args.decisions)
                if args.mode == "plan"
                else build_repair_plan(args.db, args.decisions)
            )
            plan_sha = write_new_json(args.plan_out, plan)
            result = {"status": "ok", "mode": "plan", "pair_count": 2,
                      "plan_path": str(args.plan_out.resolve()), "plan_sha256": plan_sha}
        else:
            if args.plan is None or not args.expected_plan_sha256 or args.receipt_out is None:
                raise Retire2Error("plan_hash_and_receipt_required")
            apply_function = apply_plan if args.mode == "apply" else apply_repair_plan
            result = apply_function(
                    db=args.db, decisions=args.decisions, plan_path=args.plan,
                    expected_plan_sha256=args.expected_plan_sha256,
                    receipt_out=args.receipt_out, backup_dir=args.backup_dir,
                    mutation_lock=args.mutation_lock,
                )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (Retire2Error, OSError, sqlite3.Error, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"status": "aborted", "reason": f"{type(exc).__name__}: {exc}"}, indent=2))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
