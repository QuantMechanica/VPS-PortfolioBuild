#!/usr/bin/env python3
"""Append one held retry for the rollout canary's false candidate refusal.

The first post-R11 COMPILE_EA canary was claimed by the resident fleet and
failed before setfile generation because its immutable R11 predecessor counted
as unrelated work.  This incident utility never rewrites that failed row.  It
selects the one evidence-bound canary, revalidates its source and lineage, and
appends one activation-held successor.  Dry-run is the default.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sqlite3
import uuid
from pathlib import Path
from typing import Any

try:
    from factory_mutation_lock import FactoryMutationLock
except ModuleNotFoundError:
    from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REPO = Path(r"C:\QM\repo")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
DEFAULT_MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
AUTHORITY_TASK_ID = "1fb9943f-1b87-4515-b2b4-f5ca3ffb56f8"
INCIDENT_WORK_ITEM_ID = "949b6983-0584-4318-962c-86dfb781fc65"
RETRY_CONTRACT_VERSION = "qm.compile-ea-candidate-recheck-retry/v1"
COMPILE_CONTRACT_VERSION = "qm.compile-ea-work-item/v1"
R11_REVIVAL_CONTRACT_VERSION = "qm.r11-compile-ea-revival/v1"
R11_REVIVAL_AUTHORITY_TASK_ID = "83be33f3-a45d-453b-bb70-79d10a7841e9"
ACTIVATION_HOLD_CODE = "COMPILE_EA_WORKER_ROLLOUT_PENDING"
ACTIVATION_HOLD_REASON = (
    "Candidate-recheck rollout repair retains the bounded COMPILE_EA rollout; "
    "release only through the governed compile-wave ceremony"
)
FAILURE_CLASS = "CANDIDATE_RECHECK_REFUSED"
RETRY_REASON = "ROLLOUT_CANDIDATE_RECHECK_FALSE_POSITIVE"


class RetryError(RuntimeError):
    """Fail-closed selection, evidence, source, backup, or transaction error."""


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


def _connect(db: Path, *, read_only: bool) -> sqlite3.Connection:
    if read_only:
        conn = sqlite3.connect(db.resolve().as_uri() + "?mode=ro", uri=True, timeout=30)
    else:
        conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def _payload(raw: Any) -> dict[str, Any]:
    try:
        value = json.loads(str(raw or "{}"))
    except json.JSONDecodeError as exc:
        raise RetryError("work-item payload is not valid JSON") from exc
    if not isinstance(value, dict):
        raise RetryError("work-item payload is not a JSON object")
    return value


def _row_preimage_sha256(row: sqlite3.Row) -> str:
    fields = (
        "id", "kind", "phase", "ea_id", "symbol", "setfile_path",
        "status", "verdict", "attempt_count", "parent_task_id",
        "evidence_path", "claimed_by", "payload_json", "created_at", "updated_at",
    )
    preimage = {field: row[field] for field in fields}
    return sha256_bytes(
        json.dumps(preimage, sort_keys=True, separators=(",", ":")).encode("utf-8")
    )


def _incident_row(conn: sqlite3.Connection) -> sqlite3.Row:
    row = conn.execute(
        "SELECT * FROM work_items WHERE id=?",
        (INCIDENT_WORK_ITEM_ID,),
    ).fetchone()
    if row is None:
        raise RetryError("incident canary work item is missing")
    return row


def _canonical_source(repo: Path, row: sqlite3.Row, payload: dict[str, Any]) -> Path:
    label = str(payload.get("ea_label") or "")
    if not re.fullmatch(r"QM5_[0-9]+_[A-Za-z0-9][A-Za-z0-9_-]*", label):
        raise RetryError("EA_LABEL_INVALID")
    if not label.startswith(str(row["ea_id"]) + "_"):
        raise RetryError("EA_ID_LABEL_MISMATCH")
    source = (repo / "framework" / "EAs" / label / f"{label}.mq5").resolve()
    ea_root = (repo / "framework" / "EAs").resolve()
    if ea_root not in source.parents:
        raise RetryError("MQ5_PATH_OUTSIDE_CANONICAL_EA_ROOT")
    if Path(str(payload.get("mq5_path") or "")).resolve() != source:
        raise RetryError("MQ5_BOUND_PATH_MISMATCH")
    return source


def _read_evidence(row: sqlite3.Row) -> dict[str, Any]:
    path = Path(str(row["evidence_path"] or ""))
    if not path.is_file():
        raise RetryError("COMPILE_EVIDENCE_MISSING")
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RetryError("COMPILE_EVIDENCE_INVALID") from exc
    if not isinstance(value, dict):
        raise RetryError("COMPILE_EVIDENCE_NOT_OBJECT")
    return value


def _classify(conn: sqlite3.Connection, repo: Path, row: sqlite3.Row) -> dict[str, Any]:
    payload = _payload(row["payload_json"])
    reasons: list[str] = []
    if not (
        row["id"] == INCIDENT_WORK_ITEM_ID
        and row["phase"] == "COMPILE_EA"
        and row["status"] == "failed"
        and row["verdict"] == "COMPILE_FAIL"
    ):
        reasons.append("INCIDENT_ROW_STATE_MISMATCH")
    compile_result = payload.get("compile_result")
    failure_classes = (
        compile_result.get("failure_classes", [])
        if isinstance(compile_result, dict)
        else []
    )
    if not (
        payload.get("compile_contract_version") == COMPILE_CONTRACT_VERSION
        and payload.get("revival_contract_version") == R11_REVIVAL_CONTRACT_VERSION
        and payload.get("revival_authority_task_id") == R11_REVIVAL_AUTHORITY_TASK_ID
        and payload.get("append_only_revival") is True
        and payload.get("verdict_reason") == FAILURE_CLASS
        and failure_classes == [FAILURE_CLASS]
        and payload.get("utility_phase") is True
        and payload.get("no_gate_verdict") is True
    ):
        reasons.append("INCIDENT_PAYLOAD_CONTRACT_MISMATCH")

    evidence: dict[str, Any] = {}
    try:
        evidence = _read_evidence(row)
    except RetryError as exc:
        reasons.append(str(exc))
    candidate = evidence.get("candidate_recheck", {})
    if evidence and not (
        evidence.get("work_item_id") == INCIDENT_WORK_ITEM_ID
        and evidence.get("success") is False
        and evidence.get("failure_classes") == [FAILURE_CLASS]
        and isinstance(candidate, dict)
        and candidate.get("reasons") == ["WORK_ITEMS_EXIST"]
    ):
        reasons.append("INCIDENT_EVIDENCE_CONTRACT_MISMATCH")

    source: Path | None = None
    try:
        source = _canonical_source(repo, row, payload)
    except RetryError as exc:
        reasons.append(str(exc))
    expected_sha = str(payload.get("mq5_sha256") or "").lower()
    actual_sha = sha256_file(source) if source is not None and source.is_file() else None
    if not re.fullmatch(r"[0-9a-f]{64}", expected_sha):
        reasons.append("BOUND_MQ5_SHA256_INVALID")
    if source is not None and not source.is_file():
        reasons.append("MQ5_SOURCE_MISSING")
    elif actual_sha != expected_sha:
        reasons.append("MQ5_SHA_STALE")
    risk = payload.get("risk_contract")
    try:
        fixed = float(risk.get("RISK_FIXED")) if isinstance(risk, dict) else 0.0
        percent = float(risk.get("RISK_PERCENT")) if isinstance(risk, dict) else -1.0
    except (TypeError, ValueError):
        fixed, percent = 0.0, -1.0
    if fixed <= 0 or percent != 0:
        reasons.append("RISK_CONTRACT_NOT_FIXED_ONLY")

    successors = list(conn.execute(
        "SELECT id,status,verdict FROM work_items WHERE phase='COMPILE_EA' "
        "AND json_extract(payload_json, '$.compile_retry_contract_version')=? "
        "AND json_extract(payload_json, '$.retry_of_work_item_id')=? "
        "ORDER BY created_at,id",
        (RETRY_CONTRACT_VERSION, INCIDENT_WORK_ITEM_ID),
    ))
    if successors:
        return {
            "classification": "already_retried",
            "work_item_id": row["id"],
            "ea_id": row["ea_id"],
            "old_preimage_sha256": _row_preimage_sha256(row),
            "successors": [dict(successor) for successor in successors],
            "hold_reasons": [],
        }
    open_rows = list(conn.execute(
        "SELECT id,status FROM work_items WHERE ea_id=? AND phase='COMPILE_EA' "
        "AND status IN ('pending','active') AND id<>? ORDER BY created_at,id",
        (row["ea_id"], row["id"]),
    ))
    if open_rows:
        reasons.append("OPEN_COMPILE_EA_EXISTS")
    link = conn.execute(
        "SELECT * FROM work_item_supersedes WHERE work_item_id=?",
        (row["id"],),
    ).fetchone()
    if link is not None:
        reasons.append("INCIDENT_ALREADY_HAS_SUPERSEDES_LINK")
    return {
        "classification": "held" if reasons else "eligible",
        "work_item_id": row["id"],
        "ea_id": row["ea_id"],
        "ea_label": payload.get("ea_label"),
        "old_preimage_sha256": _row_preimage_sha256(row),
        "evidence_path": row["evidence_path"],
        "mq5_path": str(source) if source is not None else payload.get("mq5_path"),
        "expected_mq5_sha256": expected_sha,
        "actual_mq5_sha256": actual_sha,
        "hold_reasons": sorted(set(reasons)),
        "open_work_item_ids": [open_row["id"] for open_row in open_rows],
    }


def inspect(db: Path, repo: Path) -> dict[str, Any]:
    with _connect(db, read_only=True) as conn:
        row = _incident_row(conn)
        item = _classify(conn, repo, row)
    return {
        "schema": RETRY_CONTRACT_VERSION,
        "authority_task_id": AUTHORITY_TASK_ID,
        "incident_work_item_id": INCIDENT_WORK_ITEM_ID,
        "mode": "dry_run",
        "inspected_at_utc": utc_now(),
        "database": str(db.resolve()),
        "canonical_repo": str(repo.resolve()),
        "eligible_count": int(item["classification"] == "eligible"),
        "already_retried_count": int(item["classification"] == "already_retried"),
        "held_count": int(item["classification"] == "held"),
        "item": item,
        "invariants": [
            "the failed canary row and evidence are immutable",
            "only the exact task-bound candidate-recheck false positive is selectable",
            "the canonical MQ5 SHA-256 is revalidated before append",
            "the successor is activation-held and fixed-risk only",
            "the successor carries no gate verdict",
        ],
    }


def _backup_database(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    destination = backup_dir / (
        f"farm_state_before_compile_recheck_retry_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    )
    with sqlite3.connect(db) as source, sqlite3.connect(destination) as target:
        source.backup(target)
    with sqlite3.connect(destination) as check:
        quick_check = str(check.execute("PRAGMA quick_check").fetchone()[0])
    if quick_check.casefold() != "ok":
        raise RetryError(f"backup quick_check failed: {quick_check}")
    return destination, sha256_file(destination)


def _successor_payload(old_payload: dict[str, Any], now: str) -> dict[str, Any]:
    allowed = (
        "compile_contract_version", "compile_activation_state",
        "compile_activation_hold_code", "ea_label", "ea_dir", "mq5_path",
        "mq5_sha256", "symbols", "timeframe", "risk_contract",
        "utility_phase", "no_gate_verdict", "revival_contract_version",
        "revival_authority_task_id", "revived_from_work_item_id",
        "revival_reason", "revival_source_mq5_sha256", "append_only_revival",
    )
    payload = {key: old_payload.get(key) for key in allowed}
    payload.update({
        "enqueued_at": now,
        "compile_retry_contract_version": RETRY_CONTRACT_VERSION,
        "compile_retry_authority_task_id": AUTHORITY_TASK_ID,
        "retry_of_work_item_id": INCIDENT_WORK_ITEM_ID,
        "retried_at_utc": now,
        "retry_reason": RETRY_REASON,
        "append_only_retry": True,
        # T8 claimed the failed canary and therefore has the pre-fix module in
        # memory until its resident worker is naturally recycled.  The existing
        # normal selector honors avoid_terminals; no targeted dispatcher is
        # introduced and no active terminal or worker is interrupted.
        "avoid_terminals": ["T8"],
        "avoid_terminal_reason": "PRE_FIX_COMPILE_MODULE_LOADED_BY_FAILED_CANARY",
    })
    return payload


def apply_retry(
    db: Path,
    repo: Path,
    backup_dir: Path,
    mutation_lock: Path,
) -> dict[str, Any]:
    preflight = inspect(db, repo)
    if preflight["eligible_count"] == 0:
        return {
            **preflight,
            "mode": "apply",
            "applied_count": 0,
            "applied": [],
            "backup": None,
            "idempotent_noop": preflight["already_retried_count"] == 1,
            "verification_ok": preflight["held_count"] == 0,
        }

    expected_preimage = preflight["item"]["old_preimage_sha256"]
    expected_source_sha = preflight["item"]["actual_mq5_sha256"]
    lock = FactoryMutationLock(mutation_lock, owner="retry_compile_recheck_canary.apply")
    backup_path: Path | None = None
    backup_sha: str | None = None
    new_id = str(uuid.uuid4())
    with lock:
        backup_path, backup_sha = _backup_database(db, backup_dir)
        conn = _connect(db, read_only=False)
        try:
            conn.execute("BEGIN IMMEDIATE")
            row = _incident_row(conn)
            current = _classify(conn, repo, row)
            if current["classification"] != "eligible":
                raise RetryError("incident eligibility drifted between dry-run and apply")
            if current["old_preimage_sha256"] != expected_preimage:
                raise RetryError("incident row preimage drifted")
            if current["actual_mq5_sha256"] != expected_source_sha:
                raise RetryError("source MQ5 SHA drifted")
            old_payload = _payload(row["payload_json"])
            now = utc_now()
            new_payload = _successor_payload(old_payload, now)
            conn.execute(
                "INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,"
                "verdict,attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,"
                "created_at,updated_at) VALUES (?,'compile','COMPILE_EA',?,'','',"
                "'pending',NULL,0,NULL,NULL,NULL,?,?,?)",
                (new_id, row["ea_id"], json.dumps(new_payload, sort_keys=True), now, now),
            )
            conn.execute(
                "INSERT INTO work_item_holds(work_item_id,hold_code,reason,active,"
                "release_on_restart,created_at,updated_at,released_at,release_note) "
                "VALUES (?,?,?,1,1,?,?,NULL,NULL)",
                (new_id, ACTIVATION_HOLD_CODE, ACTIVATION_HOLD_REASON, now, now),
            )
            detail = {
                "schema": RETRY_CONTRACT_VERSION,
                "authority_task_id": AUTHORITY_TASK_ID,
                "old_work_item_id": INCIDENT_WORK_ITEM_ID,
                "old_preimage_sha256": expected_preimage,
                "old_evidence_path": row["evidence_path"],
                "mq5_sha256": expected_source_sha,
                "activation_hold_code": ACTIVATION_HOLD_CODE,
                "no_gate_verdict": True,
            }
            detail_json = json.dumps(detail, sort_keys=True, separators=(",", ":"))
            conn.execute(
                "INSERT INTO work_item_transition_ledger(idempotency_key,ts,work_item_id,"
                "action,from_status,to_status,from_verdict,to_verdict,from_claimed_by,"
                "to_claimed_by,reason,run_id,detail_json) VALUES (?,?,?,"
                "'append_only_retry',NULL,'pending',NULL,NULL,NULL,NULL,?,?,?)",
                (
                    f"compile-recheck-retry:{INCIDENT_WORK_ITEM_ID}", now, new_id,
                    RETRY_REASON, AUTHORITY_TASK_ID, detail_json,
                ),
            )
            conn.execute(
                "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                "VALUES (?,'work_item',?,'compile_ea_append_only_retry',?)",
                (now, new_id, detail_json),
            )
            conn.execute(
                "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                "VALUES (?,'work_item',?,'compile_ea_successor_appended',?)",
                (now, INCIDENT_WORK_ITEM_ID, json.dumps({**detail, "new_work_item_id": new_id}, sort_keys=True)),
            )
            conn.execute(
                "INSERT INTO work_item_supersedes(work_item_id,superseded_by_work_item_id,"
                "reason,source_encoding,evidence_path,recorded_by,recorded_at) "
                "VALUES (?,?,?,?,?,?,?)",
                (
                    INCIDENT_WORK_ITEM_ID, new_id, RETRY_REASON,
                    "operator:compile_recheck_retry", row["evidence_path"],
                    "codex", now,
                ),
            )
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    after = inspect(db, repo)
    verification_errors: list[str] = []
    if after["item"].get("old_preimage_sha256") != expected_preimage:
        verification_errors.append("failed canary row changed")
    successor_ids = {
        item["id"] for item in after["item"].get("successors", [])
    }
    if new_id not in successor_ids:
        verification_errors.append("appended successor is not observable")
    with _connect(db, read_only=True) as conn:
        successor = conn.execute(
            "SELECT status,verdict,payload_json FROM work_items WHERE id=?", (new_id,)
        ).fetchone()
        hold = conn.execute(
            "SELECT hold_code,active FROM work_item_holds WHERE work_item_id=?", (new_id,)
        ).fetchone()
        link = conn.execute(
            "SELECT superseded_by_work_item_id FROM work_item_supersedes WHERE work_item_id=?",
            (INCIDENT_WORK_ITEM_ID,),
        ).fetchone()
    if successor is None or (successor["status"], successor["verdict"]) != ("pending", None):
        verification_errors.append("successor is not pending without verdict")
    if hold is None or tuple(hold) != (ACTIVATION_HOLD_CODE, 1):
        verification_errors.append("successor activation hold is missing")
    if link is None or link[0] != new_id:
        verification_errors.append("canonical supersedes link is missing")
    return {
        **preflight,
        "mode": "apply",
        "committed_at_utc": utc_now(),
        "applied_count": 1,
        "applied": [{
            "old_work_item_id": INCIDENT_WORK_ITEM_ID,
            "new_work_item_id": new_id,
            "ea_id": preflight["item"]["ea_id"],
            "mq5_sha256": expected_source_sha,
            "status": "pending",
            "verdict": None,
            "activation_hold_code": ACTIVATION_HOLD_CODE,
        }],
        "backup": {"path": str(backup_path), "sha256": backup_sha},
        "after": after,
        "factory_mutation_lock": {
            "path": str(mutation_lock),
            "release_status": lock.release_status,
        },
        "verification_ok": not verification_errors,
        "verification_errors": verification_errors,
    }


def _write_json_atomic(path: Path, document: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_MUTATION_LOCK)
    parser.add_argument("--apply", action="store_true", help="append the successor; default is dry-run")
    parser.add_argument("--output", type=Path, help="atomically write the JSON receipt")
    args = parser.parse_args()
    result = (
        apply_retry(args.db, args.repo, args.backup_dir, args.mutation_lock)
        if args.apply
        else inspect(args.db, args.repo)
    )
    if args.output:
        _write_json_atomic(args.output, result)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result.get("verification_ok", result.get("held_count", 0) == 0) else 2


if __name__ == "__main__":
    raise SystemExit(main())
