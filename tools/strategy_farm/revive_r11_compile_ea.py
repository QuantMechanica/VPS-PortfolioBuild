#!/usr/bin/env python3
"""Append-only revival for COMPILE_EA rows falsely invalidated by repair R11.

This is an incident-specific recovery utility.  It never changes an existing
work-item verdict or status.  It selects only the exact R11/ex5_missing incident
population, revalidates every bound MQ5 SHA-256, and appends held COMPILE_EA
successors for source-fresh rows.  Dry-run is the default.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sqlite3
import uuid
from collections import Counter
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
AUTHORITY_TASK_ID = "83be33f3-a45d-453b-bb70-79d10a7841e9"
REVIVAL_CONTRACT_VERSION = "qm.r11-compile-ea-revival/v1"
COMPILE_CONTRACT_VERSION = "qm.compile-ea-work-item/v1"
COMPILE_EA_PHASE = "COMPILE_EA"
COMPILE_WORK_ITEM_KIND = "compile"
ACTIVATION_HOLD_CODE = "COMPILE_EA_WORKER_ROLLOUT_PENDING"
ACTIVATION_HOLD_REASON = (
    "R11 append-only revival retains the reviewed COMPILE_EA rollout boundary; "
    "release only through the governed compile-wave ceremony"
)
INCIDENT_HANDLER = "R11_pending_unclaimable_work_item"
INCIDENT_REASON = "ex5_missing"
KNOWN_SHA_STALE_WORK_ITEMS = {
    "QM5_12946": "ae9e93a6-4a77-4ac9-bd11-e9ec1363bc60",
    "QM5_41097": "d646713d-c8ba-41ef-98f4-9b544780e714",
}

# Acceptance contract: do not broaden this selector to phase/status alone.
INCIDENT_SELECTOR_SQL = """
    SELECT id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
           attempt_count, parent_task_id, evidence_path, claimed_by,
           payload_json, created_at, updated_at
    FROM work_items
    WHERE phase='COMPILE_EA'
      AND status='failed'
      AND verdict='INVALID'
      AND json_extract(payload_json, '$.repair_handler')='R11_pending_unclaimable_work_item'
      AND json_extract(payload_json, '$.verdict_reason')='ex5_missing'
    ORDER BY CAST(substr(ea_id, 5) AS INTEGER), ea_id, id
"""


class RevivalError(RuntimeError):
    """Fail-closed selection, source-binding, backup, or transaction error."""


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).isoformat(timespec="microseconds")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _connect(db: Path, *, read_only: bool) -> sqlite3.Connection:
    if read_only:
        uri = db.resolve().as_uri() + "?mode=ro"
        conn = sqlite3.connect(uri, uri=True, timeout=30)
    else:
        conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def _payload(raw: str) -> dict[str, Any]:
    try:
        value = json.loads(raw or "{}")
    except json.JSONDecodeError as exc:
        raise RevivalError("incident payload is not valid JSON") from exc
    if not isinstance(value, dict):
        raise RevivalError("incident payload is not a JSON object")
    return value


def _row_preimage_sha256(row: sqlite3.Row) -> str:
    preimage = {
        key: row[key]
        for key in (
            "id", "kind", "phase", "ea_id", "symbol", "setfile_path",
            "status", "verdict", "attempt_count", "parent_task_id",
            "evidence_path", "claimed_by", "payload_json", "created_at", "updated_at",
        )
    }
    return sha256_bytes(
        json.dumps(preimage, sort_keys=True, separators=(",", ":")).encode("utf-8")
    )


def _select_incident_rows(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return list(conn.execute(INCIDENT_SELECTOR_SQL))


def _canonical_source(repo: Path, row: sqlite3.Row, payload: dict[str, Any]) -> Path:
    label = str(payload.get("ea_label") or "")
    if not re.fullmatch(r"QM5_[0-9]+_[A-Za-z0-9][A-Za-z0-9_-]*", label):
        raise RevivalError("EA_LABEL_INVALID")
    if not label.startswith(str(row["ea_id"]) + "_"):
        raise RevivalError("EA_ID_LABEL_MISMATCH")
    source = (repo / "framework" / "EAs" / label / f"{label}.mq5").resolve()
    ea_root = (repo / "framework" / "EAs").resolve()
    if ea_root not in source.parents:
        raise RevivalError("MQ5_PATH_OUTSIDE_CANONICAL_EA_ROOT")
    bound_path = Path(str(payload.get("mq5_path") or "")).resolve()
    if bound_path != source:
        raise RevivalError("MQ5_BOUND_PATH_MISMATCH")
    return source


def _successors(conn: sqlite3.Connection, old_id: str) -> list[sqlite3.Row]:
    return list(conn.execute(
        """
        SELECT id, ea_id, status, verdict, claimed_by, payload_json, created_at, updated_at
        FROM work_items
        WHERE phase='COMPILE_EA'
          AND json_extract(payload_json, '$.revival_contract_version')=?
          AND json_extract(payload_json, '$.revived_from_work_item_id')=?
        ORDER BY created_at, id
        """,
        (REVIVAL_CONTRACT_VERSION, old_id),
    ))


def _classify_row(
    conn: sqlite3.Connection,
    repo: Path,
    row: sqlite3.Row,
) -> dict[str, Any]:
    payload = _payload(str(row["payload_json"]))
    base = {
        "old_work_item_id": row["id"],
        "ea_id": row["ea_id"],
        "ea_label": payload.get("ea_label"),
        "old_status": row["status"],
        "old_verdict": row["verdict"],
        "old_preimage_sha256": _row_preimage_sha256(row),
        "bound_mq5_sha256": str(payload.get("mq5_sha256") or "").lower() or None,
    }
    successors = _successors(conn, str(row["id"]))
    if successors:
        return {
            **base,
            "classification": "already_revived",
            "successors": [
                {
                    "work_item_id": successor["id"],
                    "status": successor["status"],
                    "verdict": successor["verdict"],
                }
                for successor in successors
            ],
        }

    open_rows = list(conn.execute(
        """
        SELECT id, status, verdict
        FROM work_items
        WHERE ea_id=? AND phase='COMPILE_EA'
          AND status IN ('pending','active') AND id<>?
        ORDER BY created_at, id
        """,
        (row["ea_id"], row["id"]),
    ))
    if open_rows:
        return {
            **base,
            "classification": "held",
            "hold_reasons": ["OPEN_COMPILE_EA_EXISTS"],
            "open_work_item_ids": [open_row["id"] for open_row in open_rows],
        }

    reasons: list[str] = []
    try:
        source = _canonical_source(repo, row, payload)
    except RevivalError as exc:
        source = None
        reasons.append(str(exc))
    actual_sha = sha256_file(source) if source is not None and source.is_file() else None
    expected_sha = str(payload.get("mq5_sha256") or "").lower()
    if not re.fullmatch(r"[0-9a-f]{64}", expected_sha):
        reasons.append("BOUND_MQ5_SHA256_INVALID")
    if source is not None and not source.is_file():
        reasons.append("MQ5_SOURCE_MISSING")
    elif actual_sha != expected_sha:
        reasons.append("MQ5_SHA_STALE")

    risk = payload.get("risk_contract")
    if not isinstance(risk, dict):
        reasons.append("RISK_CONTRACT_MISSING")
    else:
        try:
            fixed = float(risk.get("RISK_FIXED"))
            percent = float(risk.get("RISK_PERCENT"))
        except (TypeError, ValueError):
            reasons.append("RISK_CONTRACT_INVALID")
        else:
            if fixed <= 0 or percent != 0:
                reasons.append("RISK_CONTRACT_NOT_FIXED_ONLY")
    if payload.get("utility_phase") is not True:
        reasons.append("UTILITY_PHASE_MARKER_MISSING")
    if payload.get("no_gate_verdict") is not True:
        reasons.append("NO_GATE_VERDICT_MARKER_MISSING")
    if payload.get("compile_contract_version") != COMPILE_CONTRACT_VERSION:
        reasons.append("COMPILE_CONTRACT_VERSION_MISMATCH")

    return {
        **base,
        "classification": "held" if reasons else "eligible",
        "hold_reasons": sorted(set(reasons)),
        "mq5_path": str(source) if source is not None else payload.get("mq5_path"),
        "actual_mq5_sha256": actual_sha,
        "symbols": payload.get("symbols"),
        "timeframe": payload.get("timeframe"),
        "risk_contract": payload.get("risk_contract"),
    }


def _known_stale_audit(
    conn: sqlite3.Connection,
    repo: Path,
    selected_ids: set[str],
) -> list[dict[str, Any]]:
    audit: list[dict[str, Any]] = []
    for ea_id, work_item_id in KNOWN_SHA_STALE_WORK_ITEMS.items():
        row = conn.execute(
            "SELECT id,ea_id,phase,status,verdict,payload_json FROM work_items WHERE id=?",
            (work_item_id,),
        ).fetchone()
        if row is None:
            audit.append({
                "ea_id": ea_id,
                "work_item_id": work_item_id,
                "state": "MISSING_FROM_DB",
                "in_incident_selector": False,
            })
            continue
        payload = _payload(str(row["payload_json"]))
        try:
            source = _canonical_source(repo, row, payload)
        except RevivalError:
            source = Path(str(payload.get("mq5_path") or ""))
        actual_sha = sha256_file(source) if source.is_file() else None
        hold = conn.execute(
            "SELECT hold_code,active FROM work_item_holds WHERE work_item_id=?",
            (work_item_id,),
        ).fetchone()
        audit.append({
            "ea_id": ea_id,
            "work_item_id": work_item_id,
            "status": row["status"],
            "verdict": row["verdict"],
            "in_incident_selector": work_item_id in selected_ids,
            "bound_mq5_sha256": payload.get("mq5_sha256"),
            "actual_mq5_sha256": actual_sha,
            "source_fresh": actual_sha == payload.get("mq5_sha256"),
            "hold": dict(hold) if hold is not None else None,
            "revived": bool(_successors(conn, work_item_id)),
        })
    return audit


def _state_counts(
    conn: sqlite3.Connection,
    incident_rows: list[sqlite3.Row],
) -> dict[str, Any]:
    selected_ids = [str(row["id"]) for row in incident_rows]
    selected_ea_ids = [str(row["ea_id"]) for row in incident_rows]
    successor_rows = list(conn.execute(
        """
        SELECT id,status,verdict,payload_json
        FROM work_items
        WHERE phase='COMPILE_EA'
          AND json_extract(payload_json, '$.revival_contract_version')=?
          AND json_extract(payload_json, '$.revival_authority_task_id')=?
        """,
        (REVIVAL_CONTRACT_VERSION, AUTHORITY_TASK_ID),
    ))
    successor_status = Counter(str(row["status"]) for row in successor_rows)
    return {
        "incident_selector_count": len(incident_rows),
        "incident_status_verdict_distribution": dict(sorted(Counter(
            f"{row['status']}/{row['verdict']}" for row in incident_rows
        ).items())),
        "distinct_incident_ea_count": len(set(selected_ea_ids)),
        "successor_count": len(successor_rows),
        "successor_status_distribution": dict(sorted(successor_status.items())),
        "pending_successor_count": successor_status.get("pending", 0),
        "incident_id_sha256": sha256_bytes("\n".join(sorted(selected_ids)).encode("utf-8")),
    }


def inspect(db: Path, repo: Path) -> dict[str, Any]:
    with _connect(db, read_only=True) as conn:
        rows = _select_incident_rows(conn)
        classified = [_classify_row(conn, repo, row) for row in rows]
        eligible = [item for item in classified if item["classification"] == "eligible"]
        held = [item for item in classified if item["classification"] == "held"]
        already = [item for item in classified if item["classification"] == "already_revived"]
        selected_ids = {str(row["id"]) for row in rows}
        return {
            "schema": REVIVAL_CONTRACT_VERSION,
            "authority_task_id": AUTHORITY_TASK_ID,
            "mode": "dry_run",
            "inspected_at_utc": utc_now(),
            "database": str(db.resolve()),
            "canonical_repo": str(repo.resolve()),
            "selector": {
                "phase": COMPILE_EA_PHASE,
                "status": "failed",
                "verdict": "INVALID",
                "payload.repair_handler": INCIDENT_HANDLER,
                "payload.verdict_reason": INCIDENT_REASON,
            },
            "before_counts": _state_counts(conn, rows),
            "eligible_count": len(eligible),
            "held_count": len(held),
            "already_revived_count": len(already),
            "eligible": eligible,
            "held": held,
            "already_revived": already,
            "known_sha_stale_audit": _known_stale_audit(conn, repo, selected_ids),
            "invariants": [
                "existing work-item status and verdict are never updated",
                "only the exact five-clause incident selector supplies candidates",
                "each source MQ5 hash is revalidated against its enqueue binding",
                "new rows are pending, activation-held, fixed-risk utility work",
                "new COMPILE_EA rows carry no gate verdict",
                "one historical successor per invalidated work-item ID makes retries idempotent",
            ],
        }


def _backup_database(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    destination = backup_dir / (
        f"farm_state_before_r11_compile_revival_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    )
    with sqlite3.connect(db) as source, sqlite3.connect(destination) as target:
        source.backup(target)
    with sqlite3.connect(destination) as check:
        quick_check = str(check.execute("PRAGMA quick_check").fetchone()[0])
    if quick_check.casefold() != "ok":
        raise RevivalError(f"backup quick_check failed: {quick_check}")
    return destination, sha256_file(destination)


def _successor_payload(old_payload: dict[str, Any], candidate: dict[str, Any], now: str) -> dict[str, Any]:
    allowed = (
        "compile_contract_version", "compile_activation_state",
        "compile_activation_hold_code", "ea_label", "ea_dir", "mq5_path",
        "mq5_sha256", "symbols", "timeframe", "risk_contract",
        "utility_phase", "no_gate_verdict",
    )
    payload = {key: old_payload.get(key) for key in allowed}
    payload.update({
        "enqueued_at": now,
        "revival_contract_version": REVIVAL_CONTRACT_VERSION,
        "revival_authority_task_id": AUTHORITY_TASK_ID,
        "revived_from_work_item_id": candidate["old_work_item_id"],
        "revived_at_utc": now,
        "revival_reason": "R11_FALSE_INVALID_EX5_MISSING",
        "revival_source_mq5_sha256": candidate["actual_mq5_sha256"],
        "append_only_revival": True,
    })
    return payload


def apply_revival(
    db: Path,
    repo: Path,
    backup_dir: Path,
    mutation_lock: Path,
) -> dict[str, Any]:
    preflight = inspect(db, repo)
    if not preflight["eligible"]:
        return {
            **preflight,
            "mode": "apply",
            "applied_count": 0,
            "applied": [],
            "backup": None,
            "after_counts": preflight["before_counts"],
            "idempotent_noop": preflight["already_revived_count"] > 0,
            "verification_ok": True,
        }

    lock = FactoryMutationLock(
        mutation_lock,
        owner="revive_r11_compile_ea.apply",
    )
    backup_path: Path | None = None
    backup_sha: str | None = None
    applied: list[dict[str, Any]] = []
    old_preimages = {
        item["old_work_item_id"]: item["old_preimage_sha256"]
        for item in preflight["eligible"]
    }
    expected_sources = {
        item["old_work_item_id"]: item["actual_mq5_sha256"]
        for item in preflight["eligible"]
    }

    with lock:
        backup_path, backup_sha = _backup_database(db, backup_dir)
        conn = _connect(db, read_only=False)
        try:
            conn.execute("BEGIN IMMEDIATE")
            current_rows = _select_incident_rows(conn)
            classified = [_classify_row(conn, repo, row) for row in current_rows]
            current_eligible = {
                item["old_work_item_id"]: item
                for item in classified
                if item["classification"] == "eligible"
            }
            if set(current_eligible) != set(old_preimages):
                raise RevivalError("eligible incident ID set drifted between dry-run and apply")
            for old_id, candidate in current_eligible.items():
                if candidate["old_preimage_sha256"] != old_preimages[old_id]:
                    raise RevivalError(f"incident row preimage drift: {old_id}")
                if candidate["actual_mq5_sha256"] != expected_sources[old_id]:
                    raise RevivalError(f"source MQ5 SHA drift: {old_id}")
                old_row = next(row for row in current_rows if row["id"] == old_id)
                old_payload = _payload(str(old_row["payload_json"]))
                new_id = str(uuid.uuid4())
                now = utc_now()
                new_payload = _successor_payload(old_payload, candidate, now)
                conn.execute(
                    """
                    INSERT INTO work_items(
                        id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                        attempt_count,parent_task_id,evidence_path,claimed_by,
                        payload_json,created_at,updated_at
                    ) VALUES (?,?,'COMPILE_EA',?,'','','pending',NULL,0,NULL,NULL,NULL,?,?,?)
                    """,
                    (
                        new_id,
                        COMPILE_WORK_ITEM_KIND,
                        old_row["ea_id"],
                        json.dumps(new_payload, sort_keys=True),
                        now,
                        now,
                    ),
                )
                conn.execute(
                    """
                    INSERT INTO work_item_holds(
                        work_item_id,hold_code,reason,active,release_on_restart,
                        created_at,updated_at,released_at,release_note
                    ) VALUES (?,?,?,1,1,?,?,NULL,NULL)
                    """,
                    (new_id, ACTIVATION_HOLD_CODE, ACTIVATION_HOLD_REASON, now, now),
                )
                detail = {
                    "schema": REVIVAL_CONTRACT_VERSION,
                    "authority_task_id": AUTHORITY_TASK_ID,
                    "old_work_item_id": old_id,
                    "old_status": old_row["status"],
                    "old_verdict": old_row["verdict"],
                    "old_preimage_sha256": candidate["old_preimage_sha256"],
                    "mq5_path": candidate["mq5_path"],
                    "mq5_sha256": candidate["actual_mq5_sha256"],
                    "activation_hold_code": ACTIVATION_HOLD_CODE,
                    "no_gate_verdict": True,
                }
                detail_json = json.dumps(detail, sort_keys=True, separators=(",", ":"))
                conn.execute(
                    """
                    INSERT INTO work_item_transition_ledger(
                        idempotency_key,ts,work_item_id,action,from_status,to_status,
                        from_verdict,to_verdict,from_claimed_by,to_claimed_by,
                        reason,run_id,detail_json
                    ) VALUES (?,?,?,'append_only_revival',NULL,'pending',NULL,NULL,
                              NULL,NULL,'R11_FALSE_INVALID_EX5_MISSING',?,?)
                    """,
                    (f"r11-compile-revival:{old_id}", now, new_id, AUTHORITY_TASK_ID, detail_json),
                )
                conn.execute(
                    """
                    INSERT INTO events(ts,entity_type,entity_id,event,detail_json)
                    VALUES (?,'work_item',?,'compile_ea_append_only_revival',?)
                    """,
                    (now, new_id, detail_json),
                )
                conn.execute(
                    """
                    INSERT INTO events(ts,entity_type,entity_id,event,detail_json)
                    VALUES (?,'work_item',?,'compile_ea_successor_appended',?)
                    """,
                    (now, old_id, json.dumps({**detail, "new_work_item_id": new_id}, sort_keys=True)),
                )
                applied.append({
                    "old_work_item_id": old_id,
                    "new_work_item_id": new_id,
                    "ea_id": old_row["ea_id"],
                    "ea_label": candidate["ea_label"],
                    "mq5_sha256": candidate["actual_mq5_sha256"],
                    "status": "pending",
                    "verdict": None,
                    "activation_hold_code": ACTIVATION_HOLD_CODE,
                })
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    after = inspect(db, repo)
    verification_errors: list[str] = []
    if after["before_counts"]["incident_selector_count"] != preflight["before_counts"]["incident_selector_count"]:
        verification_errors.append("incident selector count changed")
    after_preimages = {
        item["old_work_item_id"]: item["old_preimage_sha256"]
        for item in after["already_revived"] + after["held"] + after["eligible"]
    }
    for old_id, expected in old_preimages.items():
        if after_preimages.get(old_id) != expected:
            verification_errors.append(f"historical incident row changed: {old_id}")
    applied_ids = {item["new_work_item_id"] for item in applied}
    observed_ids = {
        successor["work_item_id"]
        for item in after["already_revived"]
        for successor in item["successors"]
    }
    if not applied_ids.issubset(observed_ids):
        verification_errors.append("one or more appended successors are not observable")
    if after["eligible_count"] != 0:
        verification_errors.append("source-fresh incident rows remain without successors")
    if any(item.get("revived") for item in after["known_sha_stale_audit"]):
        verification_errors.append("a known SHA-stale row was revived")

    return {
        **preflight,
        "mode": "apply",
        "committed_at_utc": utc_now(),
        "applied_count": len(applied),
        "actual_back_into_queue": len(applied),
        "applied": applied,
        "backup": {"path": str(backup_path), "sha256": backup_sha},
        "after_counts": after["before_counts"],
        "after_held": after["held"],
        "after_already_revived_count": after["already_revived_count"],
        "known_sha_stale_audit_after": after["known_sha_stale_audit"],
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
    parser.add_argument("--apply", action="store_true", help="append successors; default is dry-run")
    parser.add_argument("--output", type=Path, help="atomically write the JSON receipt")
    args = parser.parse_args()
    result = (
        apply_revival(args.db, args.repo, args.backup_dir, args.mutation_lock)
        if args.apply
        else inspect(args.db, args.repo)
    )
    if args.output:
        _write_json_atomic(args.output, result)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result.get("verification_ok", True) else 2


if __name__ == "__main__":
    raise SystemExit(main())
