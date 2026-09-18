#!/usr/bin/env python3
"""Governed append-only apply of the DL-089 zombie-declaration disposition plan.

Follow-up of router task b093f809 (APPROVED 2026-09-18, verdict: "root cause
quoted ... dry-run plan for 57 Q12 + 2 Q14. APPLY still owed - follow-up
ticket required"). The plan was produced read-only by
``session_tools/plan_dl089_zombie_declarations_0917.py`` and committed at
``docs/ops/evidence/2026-09-17_dl089_zombie_declaration_disposition_plan.json``
(plan sha256 58fb570c9f4bb7667d3b099d224406066616fae1eb9b3bbb8416202c577e92da).

Each of the 59 plan entries is a pending Q12/Q14 work item that re-declares a
program whose Q12 selection receipt already exists with an exact
``annual_cells_sha256`` match (an adjudicated duplicate). This tool never
edits or deletes the 59 source rows. It appends, per entry, one terminal
``disposition`` work item (status=failed, verdict=SUPERSEDED_DUPLICATE_DECLARATION,
sh3_enforced=0 -- a governance record, not an economic result) and one
``work_item_supersedes`` edge from the source row to it, which is what the
canonical claim selector (``farmctl.pending_claim_order_sql``) already checks
to keep a superseded row out of the pending/claimable board and cockpit
counts.

Dry-run (``validate``) re-checks every one of the 59 source identities against
the live database and reports the before/after pending counts without writing
anything. Apply re-validates the same 59 identities inside one
``FactoryMutationLock`` + ``BEGIN IMMEDIATE`` transaction, after one online
SQLite backup, and aborts (rollback) on any drift.
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
    try:
        from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock
    except ModuleNotFoundError:
        from factory_mutation_lock import FactoryMutationLock  # script-style import (sys.path = tools/strategy_farm)


REPO = Path(r"C:\QM\repo")
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
DEFAULT_MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")

PLAN_PATH = REPO / "docs/ops/evidence/2026-09-17_dl089_zombie_declaration_disposition_plan.json"
EXPECTED_PLAN_SHA256 = "58fb570c9f4bb7667d3b099d224406066616fae1eb9b3bbb8416202c577e92da"
EXPECTED_CONTENT_SHA256 = "ec051a6a42b41d77c8bef18ebccdd7657bdac8a9c9c0cebb313f40feb9c60a39"
PLAN_SCHEMA = "qm.dl089-zombie-declaration-disposition-plan/v1"
REVIEW_TASK_ID = "b093f809-b5bb-404a-8a3d-58a210c78ff8"
APPLY_TASK_ID = "2e354912-767c-4405-be5d-7b5f70b2e110"
SOURCE_ENCODING = f"router:dl089-zombie-disposition-apply:{APPLY_TASK_ID}"
DISPOSITION_VERDICT = "SUPERSEDED_DUPLICATE_DECLARATION"
EVIDENCE_PATH = REPO / "docs/ops/evidence/2026-09-18_2e354912_dl089_zombie_disposition_apply.md"
RECEIPT_SCHEMA = "qm.dl089-zombie-declaration-disposition-receipt/v1"


class ApplyError(RuntimeError):
    pass


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


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
        raise ApplyError(f"output_exists:{path}")
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


def _identity(row: sqlite3.Row) -> dict[str, Any]:
    return {
        key: row[key]
        for key in (
            "id", "kind", "phase", "ea_id", "symbol", "status",
            "verdict", "created_at", "updated_at", "setfile_path",
        )
    }


def load_plan(plan_path: Path) -> dict[str, Any]:
    file_sha = sha256_file(plan_path)
    if file_sha != EXPECTED_PLAN_SHA256:
        raise ApplyError(f"plan_sha256_mismatch:{file_sha}")
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    content = plan.get("content")
    if content is None:
        raise ApplyError("plan_missing_content")
    if content.get("schema") != PLAN_SCHEMA:
        raise ApplyError(f"wrong_plan_schema:{content.get('schema')}")
    computed_content_sha = sha256_bytes(canonical_bytes(content))
    if computed_content_sha != EXPECTED_CONTENT_SHA256 or computed_content_sha != plan.get("content_sha256"):
        raise ApplyError("content_sha256_mismatch")
    entries = list(content.get("q12_duplicates") or []) + list(content.get("q14_duplicates") or [])
    counts = content.get("counts") or {}
    expected_n = int(counts.get("q12_duplicate_rows", 0)) + int(counts.get("q14_duplicate_rows", 0))
    if len(entries) != expected_n or expected_n != 59:
        raise ApplyError(f"entry_count_mismatch:{len(entries)}!={expected_n}")
    seen_ids = {e["disposition_work_item_id"] for e in entries}
    if len(seen_ids) != len(entries):
        raise ApplyError("duplicate_disposition_ids_in_plan")
    return {"plan": plan, "content": content, "entries": entries}


def _pending_counts(connection: sqlite3.Connection) -> dict[str, int]:
    def count(sql: str, params: tuple = ()) -> int:
        return int(connection.execute(sql, params).fetchone()[0])

    superseded_clause = (
        "AND NOT EXISTS (SELECT 1 FROM work_item_supersedes s WHERE s.work_item_id=w.id)"
    )
    return {
        "pending_q12_ticket_scope": count(
            f"""SELECT COUNT(*) FROM work_items w
                WHERE upper(w.phase)='Q12' AND lower(w.status)='pending'
                  AND w.created_at < '2026-09-10T00:00:00+00:00' {superseded_clause}"""
        ),
        "pending_q12_all": count(
            f"""SELECT COUNT(*) FROM work_items w
                WHERE upper(w.phase)='Q12' AND lower(w.status)='pending' {superseded_clause}"""
        ),
        "pending_q14_all": count(
            f"""SELECT COUNT(*) FROM work_items w
                WHERE upper(w.phase)='Q14' AND lower(w.status)='pending' {superseded_clause}"""
        ),
    }


def _validate_entry(
    connection: sqlite3.Connection, entry: dict[str, Any], plan_generated_at_utc: str,
) -> sqlite3.Row | None:
    """Return the live row to disposition, or None if a pre-existing, unrelated
    supersession edge already resolves this source (skip -- never double-supersede)."""
    source_id = entry["source_identity"]["id"]
    row = connection.execute("SELECT * FROM work_items WHERE id=?", (source_id,)).fetchone()
    if row is None:
        raise ApplyError(f"source_missing:{source_id}")
    if _identity(row) != entry["source_identity"]:
        raise ApplyError(f"source_identity_drift:{source_id}")
    if connection.execute(
        "SELECT 1 FROM work_items WHERE id=?", (entry["disposition_work_item_id"],)
    ).fetchone():
        raise ApplyError(f"disposition_already_exists:{entry['disposition_work_item_id']}")
    existing_supersede = connection.execute(
        "SELECT source_encoding,recorded_at FROM work_item_supersedes WHERE work_item_id=?",
        (source_id,),
    ).fetchone()
    if existing_supersede is not None:
        # A supersession recorded strictly before this plan was generated is a
        # pre-existing, independently-resolved disposition (e.g. the 09-02
        # program-cell binding reconciliation); the row is already correctly
        # excluded from the pending/claimable pool, so skip it rather than
        # writing a second, redundant supersession edge on top.
        if existing_supersede["recorded_at"] >= plan_generated_at_utc:
            raise ApplyError(f"source_superseded_after_plan_generation:{source_id}")
        return None
    return row


def validate(db: Path, plan_path: Path) -> dict[str, Any]:
    loaded = load_plan(plan_path)
    generated_at = loaded["content"]["generated_at_utc"]
    connection = connect(db, read_only=True)
    try:
        before = _pending_counts(connection)
        skipped: list[str] = []
        to_apply_by_phase = {"Q12": 0, "Q14": 0}
        for entry in loaded["entries"]:
            row = _validate_entry(connection, entry, generated_at)
            if row is None:
                skipped.append(entry["source_identity"]["id"])
            else:
                to_apply_by_phase[entry["source_identity"]["phase"]] += 1
    finally:
        connection.close()
    return {
        "status": "ok",
        "mode": "validate",
        "plan_sha256": EXPECTED_PLAN_SHA256,
        "entry_count": len(loaded["entries"]),
        "pre_existing_resolved_skip_count": len(skipped),
        "pre_existing_resolved_skip_ids": skipped,
        "to_apply_count": sum(to_apply_by_phase.values()),
        "to_apply_by_phase": to_apply_by_phase,
        "pending_counts_before": before,
        "expected_pending_counts_after": {
            "pending_q12_ticket_scope": before["pending_q12_ticket_scope"] - to_apply_by_phase["Q12"],
            "pending_q12_all": before["pending_q12_all"] - to_apply_by_phase["Q12"],
            "pending_q14_all": before["pending_q14_all"] - to_apply_by_phase["Q14"],
        },
    }


def backup_database(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    destination = backup_dir / f"farm_state_before_dl089_zombie_disposition_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    source = sqlite3.connect(str(db), timeout=30)
    target = sqlite3.connect(str(destination))
    try:
        source.backup(target)
    finally:
        target.close()
        source.close()
    return destination, sha256_file(destination)


def apply(
    *, db: Path, plan_path: Path, receipt_out: Path, backup_dir: Path, mutation_lock: Path,
) -> dict[str, Any]:
    loaded = load_plan(plan_path)
    entries = loaded["entries"]
    generated_at = loaded["content"]["generated_at_utc"]
    applied_at = utc_now()
    inserted: list[str] = []
    superseded: list[str] = []
    skipped_pre_existing: list[str] = []

    with FactoryMutationLock(mutation_lock, owner=f"dl089-zombie-disposition-apply:{APPLY_TASK_ID}"):
        backup_path, backup_sha = backup_database(db, backup_dir)
        connection = connect(db, read_only=False)
        try:
            connection.execute("BEGIN IMMEDIATE")
            before = _pending_counts(connection)
            rows_by_source: dict[str, sqlite3.Row] = {}
            for entry in entries:
                source_id = entry["source_identity"]["id"]
                row = _validate_entry(connection, entry, generated_at)
                if row is None:
                    skipped_pre_existing.append(source_id)
                else:
                    rows_by_source[source_id] = row

            for entry in entries:
                source_id = entry["source_identity"]["id"]
                row = rows_by_source.get(source_id)
                if row is None:
                    continue
                disposition_id = entry["disposition_work_item_id"]
                payload = {
                    "append_only_disposition": True,
                    "control_plane_disposition": True,
                    "disposition": DISPOSITION_VERDICT,
                    "historical_evidence_preserved": True,
                    "historical_verdicts_preserved": True,
                    "program_id": entry["program_id"],
                    "duplicate_receipt": entry["duplicate_receipt"],
                    "plan_path": str(plan_path.resolve()),
                    "plan_sha256": EXPECTED_PLAN_SHA256,
                    "review_task_id": REVIEW_TASK_ID,
                    "router_task_id": APPLY_TASK_ID,
                    "source_work_item_id": source_id,
                    "verdict_reason": "DL089_RE_DECLARATION_OF_ADJUDICATED_PROGRAM",
                    "verdict_taxonomy": "governance",
                }
                connection.execute(
                    """INSERT INTO work_items(
                         id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                         attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,
                         created_at,updated_at,verdict_taxonomy_stored,clean_status_stored,
                         gate_contract_version,verdict_taxonomy,sh3_enforced
                       ) VALUES(?,'disposition',?,?,?,?, 'failed',?,0,
                         NULL,?,NULL,?,?,?,'governance','failed',?,'governance',0)""",
                    (
                        disposition_id, row["phase"], row["ea_id"], row["symbol"],
                        row["setfile_path"], DISPOSITION_VERDICT, str(EVIDENCE_PATH),
                        json.dumps(payload, sort_keys=True), applied_at, applied_at,
                        row["gate_contract_version"] or "legacy",
                    ),
                )
                connection.execute(
                    """INSERT INTO work_item_supersedes(
                         work_item_id,superseded_by_work_item_id,reason,source_encoding,
                         evidence_path,recorded_by,recorded_at) VALUES(?,?,?,?,?,?,?)""",
                    (
                        source_id, disposition_id,
                        f"DL-089 re-declaration of adjudicated program {entry['program_id']} "
                        f"(prior receipt verdict={entry['duplicate_receipt'].get('verdict')}); "
                        f"plan {EXPECTED_PLAN_SHA256}",
                        SOURCE_ENCODING, str(EVIDENCE_PATH), "claude", applied_at,
                    ),
                )
                connection.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)",
                    (
                        applied_at, "work_item", source_id, "dl089_zombie_declaration_superseded",
                        json.dumps({
                            "disposition_work_item_id": disposition_id,
                            "program_id": entry["program_id"],
                            "plan_sha256": EXPECTED_PLAN_SHA256,
                            "review_task_id": REVIEW_TASK_ID,
                            "router_task_id": APPLY_TASK_ID,
                        }, sort_keys=True),
                    ),
                )
                inserted.append(disposition_id)
                superseded.append(source_id)

            if len(inserted) + len(skipped_pre_existing) != len(entries):
                raise ApplyError(
                    f"entry_accounting_mismatch:{len(inserted)}+{len(skipped_pre_existing)}!={len(entries)}"
                )
            readback = connection.execute(
                "SELECT COUNT(*) FROM work_item_supersedes WHERE source_encoding=?",
                (SOURCE_ENCODING,),
            ).fetchone()[0]
            if int(readback) != len(inserted):
                raise ApplyError(f"pre_commit_readback:{readback}!={len(inserted)}")
            bad = connection.execute(
                f"""SELECT COUNT(*) FROM work_items
                    WHERE id IN ({",".join("?" * len(inserted))})
                      AND (status<>'failed' OR verdict<>? OR sh3_enforced<>0)""",
                (*inserted, DISPOSITION_VERDICT),
            ).fetchone()[0]
            if int(bad) != 0:
                raise ApplyError(f"pre_commit_disposition_shape_mismatch:{bad}")
            after = _pending_counts(connection)
            quick_check = connection.execute("PRAGMA quick_check").fetchone()[0]
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    receipt = {
        "schema": RECEIPT_SCHEMA,
        "applied_at_utc": applied_at,
        "review_task_id": REVIEW_TASK_ID,
        "router_task_id": APPLY_TASK_ID,
        "plan_path": str(plan_path.resolve()),
        "plan_sha256": EXPECTED_PLAN_SHA256,
        "backup": {"path": str(backup_path.resolve()), "sha256": backup_sha},
        "source_encoding": SOURCE_ENCODING,
        "disposition_verdict": DISPOSITION_VERDICT,
        "inserted_disposition_work_item_ids": inserted,
        "superseded_source_work_item_ids": superseded,
        "disposition_count": len(inserted),
        "pre_existing_resolved_skip_count": len(skipped_pre_existing),
        "pre_existing_resolved_skip_ids": skipped_pre_existing,
        "plan_entry_count": len(entries),
        "pending_counts_before": before,
        "pending_counts_after": after,
        "quick_check": quick_check,
    }
    receipt["receipt_sha256"] = write_new_json(receipt_out, receipt)
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("validate", "apply"))
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--plan", type=Path, default=PLAN_PATH)
    parser.add_argument("--receipt-out", type=Path)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_MUTATION_LOCK)
    args = parser.parse_args()
    try:
        if args.mode == "validate":
            result = validate(args.db, args.plan)
        else:
            if args.receipt_out is None:
                raise ApplyError("receipt_out_required")
            result = apply(
                db=args.db, plan_path=args.plan, receipt_out=args.receipt_out,
                backup_dir=args.backup_dir, mutation_lock=args.mutation_lock,
            )
        print(json.dumps(result, indent=2, sort_keys=True, default=str))
        return 0
    except (ApplyError, sqlite3.Error, OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"status": "aborted", "reason": f"{type(exc).__name__}: {exc}"}, indent=2))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
