"""Read-only, append-only disposition plan for DL-089 re-declarations.

This command intentionally has no apply mode.  The plan is handed to the
orchestrator for an explicit plan-hash confirmation before any disposition
writer is allowed to touch the live farm database.
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

REPO = Path("C:/QM/repo")
DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
ARTIFACT_ROOT = Path("D:/QM/strategy_farm/artifacts/opt_census")
PLAN_PATH = REPO / "docs/ops/evidence/2026-09-17_dl089_zombie_declaration_disposition_plan.json"


def _canonical(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode(
        "utf-8"
    )


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _identity(row: sqlite3.Row) -> dict[str, Any]:
    return {
        key: row[key]
        for key in (
            "id",
            "kind",
            "phase",
            "ea_id",
            "symbol",
            "status",
            "verdict",
            "created_at",
            "updated_at",
            "setfile_path",
        )
    }


def _program_id(ea_id: str, symbol: str) -> str:
    return f"DL089_{ea_id}_{symbol.replace('.', '_')}_2019_2025"


def _receipt(program_id: str) -> tuple[Path, dict[str, Any] | None]:
    path = ARTIFACT_ROOT / program_id / "q12_selection_receipt.json"
    if not path.is_file():
        return path, None
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return path, None
    if value.get("schema") != "qm.dl089-q12-selection-receipt/v1":
        return path, None
    return path, value


def build_plan() -> dict[str, Any]:
    import sys

    sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
    import dl089_matrix_service as service

    conn = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        q12_rows = conn.execute(
            """
            SELECT * FROM work_items
            WHERE lower(status)='pending' AND upper(phase)='Q12'
              AND created_at < '2026-09-10T00:00:00+00:00'
            ORDER BY created_at,id
            """
        ).fetchall()
        q14_rows = conn.execute(
            """
            SELECT * FROM work_items
            WHERE lower(status)='pending' AND upper(phase)='Q14'
            ORDER BY created_at,id
            """
        ).fetchall()
    finally:
        conn.close()

    q12_duplicates: list[dict[str, Any]] = []
    q12_excluded: list[dict[str, Any]] = []
    for row in q12_rows:
        try:
            payload = json.loads(row["payload_json"] or "{}")
            declaration = payload["pattern_filter_sweep"]
        except (KeyError, TypeError, json.JSONDecodeError):
            q12_excluded.append({"source_identity": _identity(row), "reason": "INVALID_DECLARATION"})
            continue
        prior = service._adjudicated_program_receipt(
            q12_row=row, declaration=declaration, artifact_root=ARTIFACT_ROOT
        )
        program_id = str(declaration.get("program_id") or "")
        if prior is None:
            receipt_path, receipt = _receipt(program_id)
            reason = (
                "NO_COMPLETED_RECEIPT"
                if receipt is None
                else "CENSUS_UNIVERSE_CHANGED_OR_LEDGER_MISMATCH"
            )
            q12_excluded.append(
                {
                    "source_identity": _identity(row),
                    "program_id": program_id,
                    "receipt_path": str(receipt_path.resolve()),
                    "reason": reason,
                }
            )
            continue
        q12_duplicates.append(
            {
                "source_identity": _identity(row),
                "program_id": program_id,
                "disposition_work_item_id": str(
                    uuid.uuid5(
                        uuid.NAMESPACE_URL,
                        f"qm:dl089-zombie-disposition:{row['id']}",
                    )
                ),
                "verdict": "SUPERSEDED_DUPLICATE_DECLARATION",
                "duplicate_receipt": prior,
            }
        )

    q14_duplicates: list[dict[str, Any]] = []
    q14_excluded: list[dict[str, Any]] = []
    for row in q14_rows:
        program_id = _program_id(str(row["ea_id"]), str(row["symbol"]))
        receipt_path, receipt = _receipt(program_id)
        if receipt is None:
            q14_excluded.append(
                {
                    "source_identity": _identity(row),
                    "program_id": program_id,
                    "receipt_path": str(receipt_path.resolve()),
                    "reason": "NO_COMPLETED_RECEIPT",
                }
            )
            continue
        q14_duplicates.append(
            {
                "source_identity": _identity(row),
                "program_id": program_id,
                "disposition_work_item_id": str(
                    uuid.uuid5(
                        uuid.NAMESPACE_URL,
                        f"qm:dl089-zombie-disposition:{row['id']}",
                    )
                ),
                "verdict": "SUPERSEDED_DUPLICATE_DECLARATION",
                "duplicate_receipt": {
                    "receipt_path": str(receipt_path.resolve()),
                    "receipt_sha256": _sha(receipt_path.read_bytes()),
                    "receipt_q12_work_item_id": receipt["q12_work_item_id"],
                    "verdict": receipt.get("verdict"),
                },
            }
        )

    body = {
        "schema": "qm.dl089-zombie-declaration-disposition-plan/v1",
        "db_path": str(DB),
        "scope": {
            "q12_created_before": "2026-09-10T00:00:00+00:00",
            "q12_pending_before": len(q12_rows),
            "q14_pending_before": len(q14_rows),
            "q12_expected_by_ticket": 73,
            "q14_expected_by_ticket": 2,
        },
        "disposition": "SUPERSEDED_DUPLICATE_DECLARATION",
        "append_only": True,
        "apply_requires_plan_sha256_confirmation": True,
        "q12_duplicates": q12_duplicates,
        "q14_duplicates": q14_duplicates,
        "excluded_from_disposition": [*q12_excluded, *q14_excluded],
        "counts": {
            "q12_duplicate_rows": len(q12_duplicates),
            "q14_duplicate_rows": len(q14_duplicates),
            "excluded_rows": len(q12_excluded) + len(q14_excluded),
        },
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
    }
    plan = {"content": body, "content_sha256": _sha(_canonical(body))}
    PLAN_PATH.parent.mkdir(parents=True, exist_ok=True)
    PLAN_PATH.write_text(json.dumps(plan, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    result = {
        "plan_path": str(PLAN_PATH),
        "plan_sha256": _sha(PLAN_PATH.read_bytes()),
        "content_sha256": plan["content_sha256"],
        "counts": body["counts"],
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return plan


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.parse_args()
    build_plan()
