#!/usr/bin/env python3
"""Append the two OWNER-approved DL-089 Q12 misrun dispositions.

This tool is deliberately exact-scope and append-only. It never updates or
deletes the two original PASS rows.
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

from factory_mutation_lock import FactoryMutationLock


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_RECEIPT = Path(r"D:\QM\reports\state\q12_misrun_disposition_receipt_20260826.json")
DECISION_ID = "OWNER-DEC-Q12-MISRUN-DISPO-20260826"
DECISION_PATH = Path(r"C:\QM\repo\decisions\2026-08-26_owner_q12_disposition_ftmo_position.md")
MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
DISPOSITION_NAMESPACE = uuid.UUID("f7137494-139a-4f65-a6e5-e5a97fbc7936")
RECOMMENDED_DISPOSITION = "ACKNOWLEDGE_INVALID_FOR_DECLARED_Q12"

TARGETS = (
    {
        "source_id": "dfca24fa-28df-5f5e-818f-8dcf53611822",
        "ea_id": "QM5_10706",
        "symbol": "GBPUSD.DWX",
        "updated_at": "2026-08-26T10:27:49+00:00",
        "payload_sha256": "06ba6f6169561095e89c3e1cd78c6f565f478964f33d3783562eb0a73f74e30a",
        "row_sha256": "c4a4539b783cd28b0f4f71f92ad1304e1b09db79d9fc446cd0afe8c5a3b949f7",
        "authorized_successor": "1a92b33e-e34f-532e-80b3-e0144f3b3755",
    },
    {
        "source_id": "d0e53004-659c-563c-8314-c24ad4ab2a68",
        "ea_id": "QM5_11421",
        "symbol": "EURUSD.DWX",
        "updated_at": "2026-08-26T10:30:18+00:00",
        "payload_sha256": "eca8a615bd9b2cd44dde09a43158ee7c1f7a0802a28dffcaa74ac25fb8b3875b",
        "row_sha256": "24f8da5b7ba695db0cd08e312ffe631df10dc801b7ae82486ec5d3ec87bd4373",
        "authorized_successor": "c4bc189b-372d-54c9-be45-046ac77b245b",
    },
)


def _canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n"
    ).encode("utf-8")


def _sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _row_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {key: row[key] for key in row.keys()}


def _row_sha256(row: sqlite3.Row) -> str:
    return _sha256(_canonical_bytes(_row_dict(row)))


def _disposition_id(source_id: str) -> str:
    return str(uuid.uuid5(DISPOSITION_NAMESPACE, f"{DECISION_ID}:{source_id}"))


def _validate_source(row: sqlite3.Row | None, target: dict[str, str]) -> dict[str, Any]:
    if row is None:
        raise RuntimeError(f"source row missing: {target['source_id']}")
    actual_payload_sha = _sha256(str(row["payload_json"] or "").encode("utf-8"))
    actual_row_sha = _row_sha256(row)
    expected = {
        "id": target["source_id"],
        "ea_id": target["ea_id"],
        "symbol": target["symbol"],
        "phase": "Q12",
        "status": "done",
        "verdict": "PASS",
        "updated_at": target["updated_at"],
    }
    for key, value in expected.items():
        if str(row[key]) != value:
            raise RuntimeError(f"source identity drifted: {target['source_id']}:{key}")
    if actual_payload_sha != target["payload_sha256"]:
        raise RuntimeError(f"source payload drifted: {target['source_id']}")
    if actual_row_sha != target["row_sha256"]:
        raise RuntimeError(f"source row drifted: {target['source_id']}")
    return {
        "source_id": target["source_id"],
        "row_sha256": actual_row_sha,
        "payload_sha256": actual_payload_sha,
        "disposition_id": _disposition_id(target["source_id"]),
        "authorized_successor": target["authorized_successor"],
    }


def inspect(db: Path) -> dict[str, Any]:
    decision_raw = DECISION_PATH.read_bytes()
    if DECISION_ID.encode("utf-8") not in decision_raw:
        raise RuntimeError("OWNER decision ID missing from decision artifact")
    conn = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    try:
        sources = [
            _validate_source(
                conn.execute("SELECT * FROM work_items WHERE id=?", (target["source_id"],)).fetchone(),
                target,
            )
            for target in TARGETS
        ]
        existing = int(
            conn.execute(
                "SELECT COUNT(*) FROM work_items "
                "WHERE json_extract(payload_json,'$.owner_decision_id')=?",
                (DECISION_ID,),
            ).fetchone()[0]
        )
    finally:
        conn.close()
    return {
        "schema": "qm.q12-misrun-disposition-plan/v1",
        "mode": "dry_run",
        "database": str(db.resolve()),
        "decision_id": DECISION_ID,
        "decision_path": str(DECISION_PATH),
        "decision_sha256": _sha256(decision_raw),
        "recommended_disposition": RECOMMENDED_DISPOSITION,
        "source_rows": sources,
        "existing_dispositions": existing,
        "source_rows_to_update": 0,
        "dispositions_to_append": 0 if existing == len(TARGETS) else len(TARGETS),
    }


def apply(db: Path, receipt_path: Path) -> dict[str, Any]:
    plan = inspect(db)
    if plan["existing_dispositions"] != 0:
        raise RuntimeError(
            f"refusing non-fresh apply: existing dispositions={plan['existing_dispositions']}"
        )
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()
    inserted: list[str] = []
    post_hashes: dict[str, str] = {}
    with FactoryMutationLock(MUTATION_LOCK, owner="q12_misrun_owner_disposition"):
        conn = sqlite3.connect(str(db), timeout=30)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("BEGIN IMMEDIATE")
            for target in TARGETS:
                source = conn.execute(
                    "SELECT * FROM work_items WHERE id=?", (target["source_id"],)
                ).fetchone()
                source_receipt = _validate_source(source, target)
                disposition_id = source_receipt["disposition_id"]
                if conn.execute(
                    "SELECT 1 FROM work_items WHERE id=?", (disposition_id,)
                ).fetchone():
                    raise RuntimeError(f"disposition ID already exists: {disposition_id}")
                payload = {
                    "authorized_successor": target["authorized_successor"],
                    "backtest_enqueued": False,
                    "disposition_only": True,
                    "historical_source_row_preserved": True,
                    "owner_decision_id": DECISION_ID,
                    "owner_decision_sha256": plan["decision_sha256"],
                    "recommended_disposition": RECOMMENDED_DISPOSITION,
                    "source_payload_sha256": source_receipt["payload_sha256"],
                    "source_row_sha256": source_receipt["row_sha256"],
                    "source_work_item_id": target["source_id"],
                    "verdict_reason": "OWNER_ACKNOWLEDGED_INVALID_FOR_DECLARED_Q12",
                }
                conn.execute(
                    """
                    INSERT INTO work_items(
                      id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                      attempt_count,parent_task_id,evidence_path,claimed_by,
                      payload_json,created_at,updated_at,verdict_taxonomy_stored,
                      clean_status_stored,gate_contract_version,verdict_taxonomy
                    ) VALUES(?,?,?,?,?,?,'failed','INVALID',0,NULL,?,NULL,?,?,?,
                             'invalid','failed',?,'invalid')
                    """,
                    (
                        disposition_id,
                        source["kind"],
                        source["phase"],
                        source["ea_id"],
                        source["symbol"],
                        source["setfile_path"],
                        source["evidence_path"],
                        json.dumps(payload, sort_keys=True, separators=(",", ":")),
                        now,
                        now,
                        source["gate_contract_version"] or "legacy",
                    ),
                )
                conn.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                    "VALUES(?,'work_item',?,'owner_q12_misrun_invalid_appended',?)",
                    (
                        now,
                        disposition_id,
                        json.dumps(payload, sort_keys=True, separators=(",", ":")),
                    ),
                )
                inserted.append(disposition_id)

            if len(inserted) != len(TARGETS):
                raise RuntimeError(f"wrong insert count: {len(inserted)}")
            for target in TARGETS:
                source = conn.execute(
                    "SELECT * FROM work_items WHERE id=?", (target["source_id"],)
                ).fetchone()
                post_hashes[target["source_id"]] = _row_sha256(source)
                if post_hashes[target["source_id"]] != target["row_sha256"]:
                    raise RuntimeError(f"source changed during apply: {target['source_id']}")
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
        finally:
            conn.close()

    receipt = {
        "schema": "qm.q12-misrun-disposition-receipt/v1",
        "applied_at_utc": now,
        "database": str(db.resolve()),
        "decision_id": DECISION_ID,
        "decision_sha256": plan["decision_sha256"],
        "recommended_disposition": RECOMMENDED_DISPOSITION,
        "inserted_count": len(inserted),
        "inserted_disposition_ids": inserted,
        "source_row_hashes_before": {
            row["source_id"]: row["row_sha256"] for row in plan["source_rows"]
        },
        "source_row_hashes_after": post_hashes,
        "source_rows_updated": 0,
        "source_rows_deleted": 0,
        "rollback": "append a superseding OWNER disposition; never delete history",
    }
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    if receipt_path.exists():
        raise RuntimeError(f"refusing to overwrite receipt: {receipt_path}")
    receipt_path.write_bytes(_canonical_bytes(receipt))
    receipt["receipt_path"] = str(receipt_path.resolve())
    receipt["receipt_sha256"] = _sha256(receipt_path.read_bytes())
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--receipt", type=Path, default=DEFAULT_RECEIPT)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    result = apply(args.db, args.receipt) if args.apply else inspect(args.db)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
