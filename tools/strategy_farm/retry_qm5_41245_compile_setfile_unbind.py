#!/usr/bin/env python3
"""Append one held COMPILE_EA retry for the exact QM5_41245 setfile incident.

The predecessor and evidence remain immutable. Dry-run is the default; apply
takes a SQLite backup, uses the factory mutation lock, appends one successor,
and records the canonical supersession link. This utility grants no compile,
backtest, gate, or live verdict.
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
    from compile_work_items import (
        COMPILE_ACTIVATION_HOLD_CODE,
        COMPILE_EA_PHASE,
        QM5_41245_SETFILE_UNBIND_RETRY_AUTHORITY,
        QM5_41245_SETFILE_UNBIND_RETRY_CONTRACT_VERSION,
        QM5_41245_SETFILE_UNBIND_RETRY_EA_LABEL,
        QM5_41245_SETFILE_UNBIND_RETRY_EVIDENCE_SHA256,
        QM5_41245_SETFILE_UNBIND_RETRY_PREDECESSOR_ID,
        QM5_41245_SETFILE_UNBIND_RETRY_SOURCE_SHA256,
        _inventory,
        _qm5_41245_setfile_unbind_predecessor_authorized,
    )
    from factory_mutation_lock import FactoryMutationLock
except ModuleNotFoundError:
    from tools.strategy_farm.compile_work_items import (
        COMPILE_ACTIVATION_HOLD_CODE,
        COMPILE_EA_PHASE,
        QM5_41245_SETFILE_UNBIND_RETRY_AUTHORITY,
        QM5_41245_SETFILE_UNBIND_RETRY_CONTRACT_VERSION,
        QM5_41245_SETFILE_UNBIND_RETRY_EA_LABEL,
        QM5_41245_SETFILE_UNBIND_RETRY_EVIDENCE_SHA256,
        QM5_41245_SETFILE_UNBIND_RETRY_PREDECESSOR_ID,
        QM5_41245_SETFILE_UNBIND_RETRY_SOURCE_SHA256,
        _inventory,
        _qm5_41245_setfile_unbind_predecessor_authorized,
    )
    from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock


DEFAULT_ROOT = Path(r"D:\QM\strategy_farm")
DEFAULT_REPO = Path(r"C:\QM\repo")
DEFAULT_BACKUP_DIR = DEFAULT_ROOT / "state" / "backups"
DEFAULT_MUTATION_LOCK = DEFAULT_ROOT / "state" / "FACTORY_MUTATION.lock"
EA_ID = "QM5_41245"
SETFILE_NAME = (
    "QM5_41245_wti-mcusum-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
HOLD_REASON = (
    "Exact evidence-bound QM5_41245 setfile-unbind retry remains held; "
    "release only through the governed compile-wave ceremony"
)
RETRY_REASON = "OPERATOR_PREBOUND_SETFILE_BEFORE_INITIAL_COMPILE"
BOUND_HASH = re.compile(r"^[0-9a-f]{64}$", re.I)


class RetryError(RuntimeError):
    """Fail-closed predecessor, source, setfile, or transaction error."""


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).isoformat(timespec="microseconds")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _connect(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def _payload(raw: Any) -> dict[str, Any]:
    try:
        value = json.loads(str(raw or "{}"))
    except json.JSONDecodeError as exc:
        raise RetryError("predecessor payload is invalid JSON") from exc
    if not isinstance(value, dict):
        raise RetryError("predecessor payload is not an object")
    return value


def _preimage(row: sqlite3.Row) -> str:
    fields = (
        "id", "kind", "phase", "ea_id", "symbol", "setfile_path",
        "status", "verdict", "attempt_count", "parent_task_id",
        "evidence_path", "claimed_by", "payload_json", "created_at",
        "updated_at",
    )
    raw = json.dumps(
        {field: row[field] for field in fields},
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def _successor_payload(old: dict[str, Any], now: str) -> dict[str, Any]:
    allowed = (
        "compile_contract_version", "compile_activation_state",
        "compile_activation_hold_code", "ea_label", "ea_dir", "mq5_path",
        "mq5_sha256", "symbols", "timeframe", "risk_contract",
        "utility_phase", "no_gate_verdict",
    )
    payload = {key: old.get(key) for key in allowed}
    payload.update(
        {
            "enqueued_at": now,
            "compile_retry_contract_version": (
                QM5_41245_SETFILE_UNBIND_RETRY_CONTRACT_VERSION
            ),
            "compile_retry_authority": (
                QM5_41245_SETFILE_UNBIND_RETRY_AUTHORITY
            ),
            "retry_of_work_item_id": (
                QM5_41245_SETFILE_UNBIND_RETRY_PREDECESSOR_ID
            ),
            "retry_reason": RETRY_REASON,
            "retry_evidence_sha256": (
                QM5_41245_SETFILE_UNBIND_RETRY_EVIDENCE_SHA256
            ),
            "append_only_retry": True,
            "avoid_terminals": ["T1"],
            "avoid_terminal_reason": (
                "T1 may retain the pre-retry compile module loaded by the "
                "immutable predecessor"
            ),
        }
    )
    return payload


def inspect(root: Path, repo: Path) -> dict[str, Any]:
    db = root / "state" / "farm_state.sqlite"
    with _connect(db) as conn:
        row = conn.execute(
            "SELECT * FROM work_items WHERE id=?",
            (QM5_41245_SETFILE_UNBIND_RETRY_PREDECESSOR_ID,),
        ).fetchone()
        open_rows = list(
            conn.execute(
                "SELECT id,status FROM work_items WHERE ea_id=? AND phase=? "
                "AND status IN ('pending','active') ORDER BY created_at,id",
                (EA_ID, COMPILE_EA_PHASE),
            )
        )
        successor = conn.execute(
            "SELECT superseded_by_work_item_id FROM work_item_supersedes "
            "WHERE work_item_id=?",
            (QM5_41245_SETFILE_UNBIND_RETRY_PREDECESSOR_ID,),
        ).fetchone()
    reasons: list[str] = []
    if row is None:
        reasons.append("PREDECESSOR_MISSING")
        old_payload: dict[str, Any] = {}
        old_preimage = None
    else:
        old_payload = _payload(row["payload_json"])
        old_preimage = _preimage(row)
    if open_rows:
        reasons.append("OPEN_COMPILE_EA_EXISTS")
    if successor is not None:
        reasons.append("SUCCESSOR_ALREADY_RECORDED")

    ea_dir = repo / "framework" / "EAs" / QM5_41245_SETFILE_UNBIND_RETRY_EA_LABEL
    source = ea_dir / f"{QM5_41245_SETFILE_UNBIND_RETRY_EA_LABEL}.mq5"
    setfile = ea_dir / "sets" / SETFILE_NAME
    ex5 = ea_dir / f"{QM5_41245_SETFILE_UNBIND_RETRY_EA_LABEL}.ex5"
    source_sha = sha256_file(source) if source.is_file() else None
    if source_sha != QM5_41245_SETFILE_UNBIND_RETRY_SOURCE_SHA256:
        reasons.append("SOURCE_SHA_MISMATCH")
    if ex5.exists():
        reasons.append("EX5_ALREADY_PRESENT")
    setfiles = sorted((ea_dir / "sets").glob("*.set")) if (ea_dir / "sets").is_dir() else []
    if setfiles != [setfile]:
        reasons.append("SETFILE_CARDINALITY_OR_PATH_MISMATCH")
        build_hash = None
    else:
        text = setfile.read_text(encoding="utf-8-sig", errors="strict")
        match = re.search(r"(?im)^\s*;\s*build_hash\s*:\s*(\S+)\s*$", text)
        build_hash = match.group(1) if match else None
        if build_hash != "PENDING_STRICT_Q01" or BOUND_HASH.fullmatch(build_hash or ""):
            reasons.append("SETFILE_NOT_EXPLICITLY_UNBOUND")

    successor_payload = _successor_payload(old_payload, utc_now())
    if row is not None:
        inventory = _inventory(root, repo)
        authorized = _qm5_41245_setfile_unbind_predecessor_authorized(
            successor_payload, inventory, "41245", frozenset()
        )
        if authorized != QM5_41245_SETFILE_UNBIND_RETRY_PREDECESSOR_ID:
            reasons.append("CORE_PREDECESSOR_AUTHORIZATION_REFUSED")

    classification = "eligible" if not reasons else (
        "already_retried" if reasons == ["SUCCESSOR_ALREADY_RECORDED"] else "held"
    )
    return {
        "schema": QM5_41245_SETFILE_UNBIND_RETRY_CONTRACT_VERSION,
        "mode": "dry_run",
        "classification": classification,
        "eligible": classification == "eligible",
        "reasons": reasons,
        "predecessor_work_item_id": QM5_41245_SETFILE_UNBIND_RETRY_PREDECESSOR_ID,
        "predecessor_preimage_sha256": old_preimage,
        "predecessor_evidence_sha256": QM5_41245_SETFILE_UNBIND_RETRY_EVIDENCE_SHA256,
        "ea_id": EA_ID,
        "ea_label": QM5_41245_SETFILE_UNBIND_RETRY_EA_LABEL,
        "source_path": str(source),
        "source_sha256": source_sha,
        "setfile_path": str(setfile),
        "setfile_build_hash": build_hash,
        "open_compile_work_item_ids": [str(item["id"]) for item in open_rows],
        "existing_successor_work_item_id": successor[0] if successor else None,
        "no_gate_verdict": True,
    }


def _backup(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    target = backup_dir / f"farm_state_before_qm5_41245_compile_retry_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    with sqlite3.connect(db) as source, sqlite3.connect(target) as destination:
        source.backup(destination)
    with sqlite3.connect(target) as check:
        if str(check.execute("PRAGMA quick_check").fetchone()[0]).lower() != "ok":
            raise RetryError("backup quick_check failed")
    return target, sha256_file(target)


def apply_retry(
    root: Path,
    repo: Path,
    backup_dir: Path,
    mutation_lock: Path,
) -> dict[str, Any]:
    preflight = inspect(root, repo)
    if not preflight["eligible"]:
        return {**preflight, "mode": "apply", "applied": 0, "backup": None}
    db = root / "state" / "farm_state.sqlite"
    successor_id = str(uuid.uuid4())
    lock = FactoryMutationLock(
        mutation_lock,
        owner="retry_qm5_41245_compile_setfile_unbind.apply",
    )
    with lock:
        backup_path, backup_sha = _backup(db, backup_dir)
        with _connect(db) as conn:
            conn.execute("BEGIN IMMEDIATE")
            row = conn.execute(
                "SELECT * FROM work_items WHERE id=?",
                (QM5_41245_SETFILE_UNBIND_RETRY_PREDECESSOR_ID,),
            ).fetchone()
            if row is None or _preimage(row) != preflight["predecessor_preimage_sha256"]:
                raise RetryError("predecessor preimage drifted")
            existing = conn.execute(
                "SELECT id FROM work_items WHERE ea_id=? AND phase=? "
                "AND status IN ('pending','active')",
                (EA_ID, COMPILE_EA_PHASE),
            ).fetchone()
            link = conn.execute(
                "SELECT superseded_by_work_item_id FROM work_item_supersedes "
                "WHERE work_item_id=?",
                (QM5_41245_SETFILE_UNBIND_RETRY_PREDECESSOR_ID,),
            ).fetchone()
            if existing is not None or link is not None:
                raise RetryError("successor/open-row state drifted")
            now = utc_now()
            payload = _successor_payload(_payload(row["payload_json"]), now)
            conn.execute(
                "INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,"
                "verdict,attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,"
                "created_at,updated_at) VALUES (?,'compile',?,?,?,'','pending',NULL,0,"
                "NULL,NULL,NULL,?,?,?)",
                (successor_id, COMPILE_EA_PHASE, EA_ID, "", json.dumps(payload, sort_keys=True), now, now),
            )
            conn.execute(
                "INSERT INTO work_item_holds(work_item_id,hold_code,reason,active,"
                "release_on_restart,created_at,updated_at,released_at,release_note) "
                "VALUES (?,?,?,1,1,?,?,NULL,NULL)",
                (successor_id, COMPILE_ACTIVATION_HOLD_CODE, HOLD_REASON, now, now),
            )
            detail = {
                "schema": QM5_41245_SETFILE_UNBIND_RETRY_CONTRACT_VERSION,
                "authority": QM5_41245_SETFILE_UNBIND_RETRY_AUTHORITY,
                "predecessor_work_item_id": QM5_41245_SETFILE_UNBIND_RETRY_PREDECESSOR_ID,
                "predecessor_preimage_sha256": preflight["predecessor_preimage_sha256"],
                "predecessor_evidence_sha256": QM5_41245_SETFILE_UNBIND_RETRY_EVIDENCE_SHA256,
                "mq5_sha256": QM5_41245_SETFILE_UNBIND_RETRY_SOURCE_SHA256,
                "setfile_build_hash": "PENDING_STRICT_Q01",
                "no_gate_verdict": True,
            }
            detail_json = json.dumps(detail, sort_keys=True, separators=(",", ":"))
            conn.execute(
                "INSERT INTO work_item_supersedes(work_item_id,superseded_by_work_item_id,"
                "reason,source_encoding,evidence_path,recorded_by,recorded_at) "
                "VALUES (?,?,?,?,?,'codex',?)",
                (
                    QM5_41245_SETFILE_UNBIND_RETRY_PREDECESSOR_ID,
                    successor_id,
                    RETRY_REASON,
                    "operator:qm5-41245-setfile-unbind/v1",
                    row["evidence_path"],
                    now,
                ),
            )
            conn.execute(
                "INSERT INTO work_item_transition_ledger(idempotency_key,ts,work_item_id,"
                "action,from_status,to_status,from_verdict,to_verdict,from_claimed_by,"
                "to_claimed_by,reason,run_id,detail_json) VALUES (?,?,?,"
                "'append_only_retry',NULL,'pending',NULL,NULL,NULL,NULL,?,?,?)",
                (f"qm5-41245-compile-retry:{successor_id}", now, successor_id, RETRY_REASON, "qm5_41245_setfile_unbind", detail_json),
            )
            conn.execute(
                "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                "VALUES (?,'work_item',?,'compile_ea_append_only_retry',?)",
                (now, successor_id, detail_json),
            )
            conn.commit()
    after = inspect(root, repo)
    return {
        **preflight,
        "mode": "apply",
        "applied": 1,
        "successor_work_item_id": successor_id,
        "backup": {"path": str(backup_path), "sha256": backup_sha},
        "factory_mutation_lock_release_status": lock.release_status,
        "after_classification": after["classification"],
        "no_gate_verdict": True,
    }


def _write_json(path: Path, result: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_MUTATION_LOCK)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = (
        apply_retry(args.root, args.repo, args.backup_dir, args.mutation_lock)
        if args.apply
        else inspect(args.root, args.repo)
    )
    if args.output:
        _write_json(args.output, result)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result.get("eligible") or result.get("applied") == 1 else 2


if __name__ == "__main__":
    raise SystemExit(main())
