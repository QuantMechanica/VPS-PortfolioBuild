#!/usr/bin/env python3
"""Close the exact OWNER-approved QM5_20172 stale-build Q02 bypass hold.

Dry-run emits a hash-bound disposition. Apply deactivates (never deletes) the exact hold,
then appends a transition-ledger row and event. The public-snapshot guard is not changed.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
from pathlib import Path
from typing import Any

from factory_mutation_lock import FactoryMutationLock


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
DECISION_ID = "OWNER-DEC-Q02-BYPASS-88ba4560"
DECISION_PATH = Path("decisions/2026-08-23_owner_decisions_evening_batch_2.md")
HOLD_WORK_ITEM_ID = "88ba4560-fd7f-456f-903f-f4982d8f9cf3"
HOLD_CODE = "STALE_BUILD_RESULT_AUTO_Q02_BYPASS"
RECOVERY_WORK_ITEM_ID = "bf7b7bfe-4dd3-4a11-8904-1a6b081717b0"
EXPECTED_EA = "QM5_20172"
EXPECTED_SYMBOL = "XTIUSD.DWX"
EXPECTED_RECOVERY_EX5 = "0e01ada7d9f9711e70a20f032f5f0a6e5bb63adb3b5f6d26f1f295202412a2d5"


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
            + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def write_new_json(path: Path, value: Any) -> str:
    path = path.resolve(strict=False)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise RuntimeError(f"refusing to overwrite artifact: {path}")
    raw = canonical_bytes(value)
    path.write_bytes(raw)
    return sha256_bytes(raw)


def connect_ro(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db.resolve().as_uri() + "?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def _row_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {key: row[key] for key in row.keys()}


def inspect(db: Path) -> dict[str, Any]:
    decision_raw = DECISION_PATH.read_bytes()
    if DECISION_ID.encode() not in decision_raw or "alle drei genehmigt".encode() not in decision_raw:
        raise RuntimeError("OWNER decision artifact does not contain the hold-close approval")
    with connect_ro(db) as conn:
        hold = conn.execute(
            "SELECT * FROM work_item_holds WHERE work_item_id=?", (HOLD_WORK_ITEM_ID,)
        ).fetchone()
        held_item = conn.execute(
            "SELECT * FROM work_items WHERE id=?", (HOLD_WORK_ITEM_ID,)
        ).fetchone()
        recovery = conn.execute(
            "SELECT * FROM work_items WHERE id=?", (RECOVERY_WORK_ITEM_ID,)
        ).fetchone()
    if hold is None or held_item is None or recovery is None:
        raise RuntimeError("hold, held work item, or recovery work item is missing")
    if hold["hold_code"] != HOLD_CODE or int(hold["active"]) != 1:
        raise RuntimeError("exact stale-build hold is not active")
    if (held_item["ea_id"], held_item["symbol"], held_item["status"], held_item["verdict"]) != (
        EXPECTED_EA, EXPECTED_SYMBOL, "failed", "BLOCKED_STALE_BUILD_RESULT"
    ):
        raise RuntimeError("held work-item identity drifted")
    if (recovery["ea_id"], recovery["symbol"], recovery["phase"],
            recovery["status"], recovery["verdict"]) != (
        EXPECTED_EA, EXPECTED_SYMBOL, "Q02", "done", "PASS"
    ):
        raise RuntimeError("fresh recovery work-item identity drifted")
    payload = json.loads(recovery["payload_json"])
    if payload.get("requalification_old_work_item_id") != HOLD_WORK_ITEM_ID:
        raise RuntimeError("recovery row is not lineage-bound to the held stale row")
    if str(payload.get("expected_ex5_sha256") or "").lower() != EXPECTED_RECOVERY_EX5:
        raise RuntimeError("recovery expected EX5 binding drifted")
    evidence = Path(str(recovery["evidence_path"] or ""))
    if not evidence.is_file():
        raise RuntimeError(f"recovery evidence is missing: {evidence}")
    summary = json.loads(evidence.read_text(encoding="utf-8-sig"))
    expert = (summary.get("execution_identity") or {}).get("expert_binary") or {}
    runs = summary.get("runs") or []
    if (summary.get("result") != "PASS" or summary.get("reason_classes") != ["OK"]
            or not runs or any(row.get("status") != "OK" for row in runs)
            or sum(int(row.get("total_trades") or 0) for row in runs) <= 0
            or expert.get("required_sha256") != EXPECTED_RECOVERY_EX5
            or expert.get("stable_during_run") is not True):
        raise RuntimeError("fresh recovery summary does not prove a stable PASS/OK result")
    return {
        "schema": "qm.q02-bypass-hold-close-disposition/v1",
        "mode": "dry_run",
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "database": str(db.resolve()),
        "owner_decision": {
            "id": DECISION_ID,
            "path": str(DECISION_PATH.resolve()),
            "sha256": sha256_bytes(decision_raw),
        },
        "hold": _row_dict(hold),
        "held_work_item": {
            "id": held_item["id"], "ea_id": held_item["ea_id"],
            "symbol": held_item["symbol"], "status": held_item["status"],
            "verdict": held_item["verdict"], "updated_at": held_item["updated_at"],
        },
        "recovery": {
            "work_item_id": recovery["id"], "status": recovery["status"],
            "verdict": recovery["verdict"], "evidence_path": str(evidence),
            "evidence_sha256": sha256_file(evidence),
            "expected_ex5_sha256": EXPECTED_RECOVERY_EX5,
            "total_trades": sum(int(row.get("total_trades") or 0) for row in runs),
        },
        "operation": "DEACTIVATE_HOLD_APPEND_LEDGER_AND_EVENT",
        "delete_count": 0,
        "guard_contract_unchanged": True,
    }


def snapshot(db: Path, output: Path) -> str:
    if output.exists():
        raise RuntimeError(f"snapshot already exists: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    src = sqlite3.connect(str(db), timeout=30)
    dst = sqlite3.connect(str(output))
    try:
        src.backup(dst)
    finally:
        dst.close()
        src.close()
    return sha256_file(output)


def apply(db: Path, disposition: dict[str, Any], disposition_sha: str,
          receipt_out: Path, snapshot_path: Path, lock_path: Path) -> dict[str, Any]:
    if disposition.get("schema") != "qm.q02-bypass-hold-close-disposition/v1":
        raise RuntimeError("unsupported disposition schema")
    if disposition.get("owner_decision", {}).get("id") != DECISION_ID:
        raise RuntimeError("wrong OWNER decision")
    live = inspect(db)
    for key in ("hold", "held_work_item", "recovery", "owner_decision"):
        if live[key] != disposition[key]:
            raise RuntimeError(f"live {key} differs from the reviewed disposition")
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()
    release_note = (
        f"{DECISION_ID}: stale-build finding closed by fresh hash-bound Q02 "
        f"{RECOVERY_WORK_ITEM_ID}; public snapshot guard unchanged"
    )
    ledger_key = f"{DECISION_ID}:{HOLD_WORK_ITEM_ID}:{disposition['hold']['created_at']}"
    with FactoryMutationLock(lock_path, owner="close_q02_bypass_hold.apply"):
        backup_sha = snapshot(db, snapshot_path)
        conn = sqlite3.connect(str(db), timeout=30)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("BEGIN IMMEDIATE")
            current = conn.execute(
                "SELECT * FROM work_item_holds WHERE work_item_id=?", (HOLD_WORK_ITEM_ID,)
            ).fetchone()
            if current is None or _row_dict(current) != disposition["hold"]:
                raise RuntimeError("hold preimage drifted before close")
            changed = conn.execute(
                """UPDATE work_item_holds
                   SET active=0,updated_at=?,released_at=?,release_note=?
                   WHERE work_item_id=? AND hold_code=? AND active=1
                     AND created_at=? AND updated_at=? AND released_at IS NULL
                     AND release_note IS NULL""",
                (now, now, release_note, HOLD_WORK_ITEM_ID, HOLD_CODE,
                 current["created_at"], current["updated_at"]),
            )
            if changed.rowcount != 1:
                raise RuntimeError("exact hold close compare-and-swap failed")
            detail = {
                "owner_decision_id": DECISION_ID,
                "disposition_sha256": disposition_sha,
                "recovery_work_item_id": RECOVERY_WORK_ITEM_ID,
                "recovery_evidence_sha256": disposition["recovery"]["evidence_sha256"],
                "guard_contract_unchanged": True,
                "snapshot_sha256": backup_sha,
            }
            conn.execute(
                """INSERT INTO work_item_transition_ledger(
                     idempotency_key,ts,work_item_id,action,from_status,to_status,
                     from_verdict,to_verdict,from_claimed_by,to_claimed_by,reason,run_id,detail_json
                   ) VALUES(?,?,?,'release_q02_bypass_hold','failed','failed',
                            'BLOCKED_STALE_BUILD_RESULT','BLOCKED_STALE_BUILD_RESULT',
                            NULL,NULL,?,?,?)""",
                (ledger_key, now, HOLD_WORK_ITEM_ID, release_note, DECISION_ID,
                 json.dumps(detail, sort_keys=True, separators=(",", ":"))),
            )
            conn.execute(
                "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)",
                (now, "work_item", HOLD_WORK_ITEM_ID, "q02_bypass_hold_closed",
                 json.dumps(detail, sort_keys=True, separators=(",", ":"))),
            )
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
        finally:
            conn.close()
    receipt = {
        "schema": "qm.q02-bypass-hold-close-receipt/v1",
        "applied_at_utc": now,
        "database": str(db.resolve()),
        "owner_decision_id": DECISION_ID,
        "disposition_sha256": disposition_sha,
        "work_item_id": HOLD_WORK_ITEM_ID,
        "hold_code": HOLD_CODE,
        "active_before": True,
        "active_after": False,
        "transition_ledger_idempotency_key": ledger_key,
        "snapshot_path": str(snapshot_path.resolve()),
        "snapshot_sha256": backup_sha,
        "deleted_rows": 0,
        "guard_contract_unchanged": True,
    }
    receipt_sha = write_new_json(receipt_out, receipt)
    return {**receipt, "receipt_path": str(receipt_out.resolve()),
            "receipt_sha256": receipt_sha}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    sub = parser.add_subparsers(dest="command", required=True)
    dry = sub.add_parser("dry-run")
    dry.add_argument("--disposition-out", type=Path, required=True)
    do = sub.add_parser("apply")
    do.add_argument("--disposition", type=Path, required=True)
    do.add_argument("--expected-disposition-sha256", required=True)
    do.add_argument("--receipt-out", type=Path, required=True)
    do.add_argument("--snapshot-path", type=Path, required=True)
    do.add_argument("--mutation-lock", type=Path, default=DEFAULT_LOCK)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "dry-run":
        result = inspect(args.db)
        digest = write_new_json(args.disposition_out, result)
        print(json.dumps({**result, "disposition_path": str(args.disposition_out.resolve()),
                          "disposition_sha256": digest}, indent=2, sort_keys=True))
        return 0
    raw = args.disposition.read_bytes()
    digest = sha256_bytes(raw)
    if digest != args.expected_disposition_sha256.lower():
        raise RuntimeError(
            f"disposition SHA-256 mismatch: expected={args.expected_disposition_sha256} "
            f"actual={digest}"
        )
    result = apply(args.db, json.loads(raw), digest, args.receipt_out,
                   args.snapshot_path, args.mutation_lock)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2))
        raise SystemExit(1)
