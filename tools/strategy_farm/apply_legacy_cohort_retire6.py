#!/usr/bin/env python3
"""Apply the six OWNER-approved legacy-cohort pair retirements append-only."""

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
AUDIT_PATH = Path(
    r"C:\QM\repo\docs\ops\evidence\2026-08-30_359988fb_legacy_q12_anchor_audit.md"
)
EVIDENCE_PATH = Path(
    r"C:\QM\repo\docs\ops\evidence\2026-08-30_7d561f89_legacy_cohort_retire6.md"
)

AUTHORIZED_ROUTER_TASK_ID = "7d561f89-f031-4806-9f0f-d0eac630b7e4"
OWNER_DECISION_ID = "OWNER-DEC-LEGACY-COHORT-DISPO-20260830"
OWNER_RECEIPT_PREFIX = "68a58c95"
PLAN_SCHEMA = "qm.legacy-cohort-retire6-plan/v1"
RECEIPT_SCHEMA = "qm.legacy-cohort-retire6-receipt/v1"
NAMESPACE = uuid.UUID("60eb51cb-b4f0-57ca-99f8-5dd0258bbaea")
TARGETS = (
    ("78849592-dffe-4344-8edc-fdf9d1c8fc64", "QM5_1567", "XAGUSD.DWX"),
    ("f7f379d3-841d-455a-a64f-ea69ea3fc5ef", "QM5_10476", "USDCAD.DWX"),
    ("cac0d840-73e9-4601-95dd-d37533b32f29", "QM5_10919", "XTIUSD.DWX"),
    ("a472a5f9-c614-4c7d-9ff0-8542085e9a02", "QM5_11421", "AUDUSD.DWX"),
    ("084a05e0-99cf-435e-bce3-d464d97081e0", "QM5_12567", "XNGUSD.DWX"),
    (
        "d9f360d4-6fa3-47ab-bddb-6a33a616f540",
        "QM5_13117",
        "QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1",
    ),
)


class Retire6Error(RuntimeError):
    """Fail-closed authority, scope, precondition, or postcondition error."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n"
    ).encode("utf-8")


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
        raise Retire6Error(f"output_exists:{path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = canonical_bytes(value)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_bytes(raw)
    temporary.replace(path)
    return sha256_bytes(raw)


def connect(db: Path, *, read_only: bool) -> sqlite3.Connection:
    if read_only:
        conn = sqlite3.connect(db.resolve().as_uri() + "?mode=ro", uri=True, timeout=30)
        conn.execute("PRAGMA query_only=ON")
    else:
        conn = sqlite3.connect(str(db), timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def disposition_id(source_id: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"{OWNER_DECISION_ID}|RETIRE|{source_id}"))


def decision_record(path: Path) -> tuple[dict[str, Any], str]:
    payload = json.loads(path.read_text(encoding="utf-8-sig"))
    matches = [row for row in payload.get("items", []) if row.get("id") == OWNER_DECISION_ID]
    if len(matches) != 1:
        raise Retire6Error(f"owner_decision_count:{len(matches)}")
    record = matches[0]
    if record.get("status") != "DECIDED" or record.get("last_decision") != "YES":
        raise Retire6Error("owner_decision_not_yes")
    receipt_id = str(record.get("last_receipt_id") or "")
    if not receipt_id.startswith(OWNER_RECEIPT_PREFIX):
        raise Retire6Error(f"owner_receipt_mismatch:{receipt_id}")
    return record, sha256_bytes(canonical_bytes(record))


def row_snapshot(row: sqlite3.Row) -> dict[str, Any]:
    return {key: row[key] for key in row.keys()}


def row_sha256(row: sqlite3.Row) -> str:
    return sha256_bytes(canonical_bytes(row_snapshot(row)))


def target_snapshot(
    conn: sqlite3.Connection, source_id: str, ea_id: str, symbol: str
) -> dict[str, Any]:
    source = conn.execute("SELECT * FROM work_items WHERE id=?", (source_id,)).fetchone()
    if source is None:
        raise Retire6Error(f"source_missing:{source_id}")
    if (
        source["ea_id"] != ea_id
        or source["symbol"] != symbol
        or str(source["phase"]).upper() != "Q08"
        or source["kind"] != "backtest"
        or source["status"] != "done"
        or source["verdict"] != "FAIL_HARD"
        or str(source["verdict_taxonomy"] or source["verdict_taxonomy_stored"] or "").lower()
        != "strategy"
        or str(source["claimed_by"] or "").strip()
    ):
        raise Retire6Error(f"source_prestate_mismatch:{source_id}")
    new_id = disposition_id(source_id)
    if conn.execute("SELECT 1 FROM work_items WHERE id=?", (new_id,)).fetchone():
        raise Retire6Error(f"successor_exists:{new_id}")
    if conn.execute(
        "SELECT 1 FROM work_item_supersedes WHERE work_item_id=?", (source_id,)
    ).fetchone():
        raise Retire6Error(f"source_already_superseded:{source_id}")
    if conn.execute(
        """SELECT 1 FROM work_items
           WHERE ea_id=? AND symbol=? AND kind='disposition'
             AND status='done' AND verdict='RETIRE' LIMIT 1""",
        (ea_id, symbol),
    ).fetchone():
        raise Retire6Error(f"pair_already_retired:{ea_id}:{symbol}")
    candidates = conn.execute(
        "SELECT * FROM portfolio_candidates WHERE ea_id=? AND symbol=? ORDER BY q11_work_item_id",
        (ea_id, symbol),
    ).fetchall()
    if len(candidates) != 1 or candidates[0]["state"] != "Q12_REVIEW_READY":
        raise Retire6Error(
            f"portfolio_candidate_prestate:{ea_id}:{symbol}:{len(candidates)}:"
            f"{[row['state'] for row in candidates]}"
        )
    return {
        "source_work_item_id": source_id,
        "source_row_sha256": row_sha256(source),
        "ea_id": ea_id,
        "symbol": symbol,
        "setfile_path": source["setfile_path"],
        "gate_contract_version": source["gate_contract_version"] or "legacy",
        "source_evidence_path": source["evidence_path"],
        "disposition_work_item_id": new_id,
        "portfolio_candidate": {
            "q11_work_item_id": candidates[0]["q11_work_item_id"],
            "state": candidates[0]["state"],
            "row_sha256": row_sha256(candidates[0]),
        },
    }


def build_plan(db: Path, decisions: Path) -> dict[str, Any]:
    _record, record_sha = decision_record(decisions)
    if not AUDIT_PATH.is_file() or not EVIDENCE_PATH.is_file():
        raise Retire6Error("audit_or_evidence_missing")
    conn = connect(db, read_only=True)
    try:
        targets = [target_snapshot(conn, *target) for target in TARGETS]
    finally:
        conn.close()
    plan = {
        "schema": PLAN_SCHEMA,
        "generated_at_utc": utc_now(),
        "database": str(db.resolve()),
        "router_task_id": AUTHORIZED_ROUTER_TASK_ID,
        "owner_decision": {"id": OWNER_DECISION_ID, "record_sha256": record_sha},
        "audit_path": str(AUDIT_PATH.resolve()),
        "audit_sha256": sha256_file(AUDIT_PATH),
        "evidence_path": str(EVIDENCE_PATH.resolve()),
        "evidence_sha256": sha256_file(EVIDENCE_PATH),
        "mutation": "APPEND_EXACTLY_6_RETIRE_SUCCESSORS_AND_RETIRE_6_PORTFOLIO_ROWS",
        "historical_work_item_updates": 0,
        "targets": targets,
    }
    plan["targets_sha256"] = sha256_bytes(canonical_bytes(targets))
    return plan


def validate_plan(plan: dict[str, Any], decisions: Path) -> None:
    if plan.get("schema") != PLAN_SCHEMA or plan.get("router_task_id") != AUTHORIZED_ROUTER_TASK_ID:
        raise Retire6Error("plan_authority_mismatch")
    if plan.get("owner_decision", {}).get("id") != OWNER_DECISION_ID:
        raise Retire6Error("plan_decision_mismatch")
    _record, record_sha = decision_record(decisions)
    if record_sha != plan.get("owner_decision", {}).get("record_sha256"):
        raise Retire6Error("owner_decision_record_drift")
    if sha256_file(AUDIT_PATH) != plan.get("audit_sha256"):
        raise Retire6Error("audit_drift")
    if sha256_file(EVIDENCE_PATH) != plan.get("evidence_sha256"):
        raise Retire6Error("evidence_drift")
    targets = plan.get("targets") or []
    if len(targets) != 6 or sha256_bytes(canonical_bytes(targets)) != plan.get("targets_sha256"):
        raise Retire6Error("target_manifest_invalid")
    actual = {(row["source_work_item_id"], row["ea_id"], row["symbol"]) for row in targets}
    if actual != set(TARGETS):
        raise Retire6Error("target_scope_changed")


def backup_database(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    destination = backup_dir / f"farm_state_before_legacy_retire6_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
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
        raise Retire6Error("plan_sha256_mismatch")
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    validate_plan(plan, decisions)
    backup_path, backup_sha = backup_database(db, backup_dir)
    now = utc_now()
    inserted: list[str] = []
    portfolio_updates: list[dict[str, str]] = []
    source_hashes_after: dict[str, str] = {}
    with FactoryMutationLock(mutation_lock, owner=f"legacy-retire6:{AUTHORIZED_ROUTER_TASK_ID}"):
        conn = connect(db, read_only=False)
        try:
            conn.execute("BEGIN IMMEDIATE")
            live = [target_snapshot(conn, *target) for target in TARGETS]
            if sha256_bytes(canonical_bytes(live)) != plan["targets_sha256"]:
                raise Retire6Error("live_target_drift")
            for target in plan["targets"]:
                payload = {
                    "append_only_disposition": True,
                    "audit_path": plan["audit_path"],
                    "audit_sha256": plan["audit_sha256"],
                    "control_plane_disposition": True,
                    "disposition": "RETIRE",
                    "historical_evidence_preserved": True,
                    "historical_verdicts_preserved": True,
                    "owner_decision_id": OWNER_DECISION_ID,
                    "owner_decision_record_sha256": plan["owner_decision"]["record_sha256"],
                    "plan_sha256": expected_plan_sha256.lower(),
                    "router_task_id": AUTHORIZED_ROUTER_TASK_ID,
                    "source_evidence_path": target["source_evidence_path"],
                    "source_row_sha256": target["source_row_sha256"],
                    "source_work_item_id": target["source_work_item_id"],
                    "verdict_reason": "OWNER_APPROVED_MEASURED_Q08_FAIL_HARD_PAIR_RETIREMENT",
                    "verdict_taxonomy": "strategy",
                }
                conn.execute(
                    """INSERT INTO work_items(
                         id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
                         parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,
                         verdict_taxonomy_stored,clean_status_stored,gate_contract_version,
                         verdict_taxonomy,sh3_enforced)
                       VALUES(?,'disposition','Q08',?,?,?,'done','RETIRE',0,NULL,?,NULL,?,?,?,
                              'strategy','done',?,'strategy',0)""",
                    (
                        target["disposition_work_item_id"], target["ea_id"], target["symbol"],
                        target["setfile_path"], str(EVIDENCE_PATH.resolve()),
                        json.dumps(payload, sort_keys=True), now, now,
                        target["gate_contract_version"],
                    ),
                )
                conn.execute(
                    """INSERT INTO work_item_supersedes(
                         work_item_id,superseded_by_work_item_id,reason,source_encoding,
                         evidence_path,recorded_by,recorded_at) VALUES(?,?,?,?,?,?,?)""",
                    (
                        target["source_work_item_id"], target["disposition_work_item_id"],
                        f"OWNER-approved measured Q08 FAIL_HARD pair retirement; {OWNER_DECISION_ID}",
                        "owner:legacy-cohort-retire6/v1", str(EVIDENCE_PATH.resolve()), "codex", now,
                    ),
                )
                pc = target["portfolio_candidate"]
                cursor = conn.execute(
                    """UPDATE portfolio_candidates SET state='RETIRED',updated_at=?
                       WHERE ea_id=? AND symbol=? AND q11_work_item_id=? AND state='Q12_REVIEW_READY'""",
                    (now, target["ea_id"], target["symbol"], pc["q11_work_item_id"]),
                )
                if cursor.rowcount != 1:
                    raise Retire6Error(f"portfolio_candidate_cas_failed:{target['ea_id']}:{target['symbol']}")
                detail = {
                    "decision": OWNER_DECISION_ID,
                    "disposition_work_item_id": target["disposition_work_item_id"],
                    "portfolio_state": "RETIRED",
                    "source_work_item_id": target["source_work_item_id"],
                }
                conn.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)",
                    (now, "work_item", target["disposition_work_item_id"],
                     "owner_legacy_pair_retired", json.dumps(detail, sort_keys=True)),
                )
                inserted.append(target["disposition_work_item_id"])
                portfolio_updates.append({
                    "ea_id": target["ea_id"], "symbol": target["symbol"],
                    "q11_work_item_id": pc["q11_work_item_id"], "state": "RETIRED",
                })

            rows = conn.execute(
                "SELECT id,status,verdict,verdict_taxonomy,sh3_enforced FROM work_items "
                f"WHERE id IN ({','.join(['?'] * len(inserted))}) ORDER BY id", inserted,
            ).fetchall()
            if len(rows) != 6 or any(
                row["status"] != "done" or row["verdict"] != "RETIRE"
                or row["verdict_taxonomy"] != "strategy" or int(row["sh3_enforced"]) != 0
                for row in rows
            ):
                raise Retire6Error("retire_successor_postcondition_failed")
            edge_count = conn.execute(
                "SELECT COUNT(*) FROM work_item_supersedes "
                f"WHERE superseded_by_work_item_id IN ({','.join(['?'] * len(inserted))})", inserted,
            ).fetchone()[0]
            if edge_count != 6:
                raise Retire6Error(f"supersedes_edge_count:{edge_count}")
            for target in plan["targets"]:
                source = conn.execute(
                    "SELECT * FROM work_items WHERE id=?", (target["source_work_item_id"],)
                ).fetchone()
                current_hash = row_sha256(source)
                source_hashes_after[target["source_work_item_id"]] = current_hash
                if current_hash != target["source_row_sha256"]:
                    raise Retire6Error(f"historical_source_mutated:{target['source_work_item_id']}")
            retired_pc = conn.execute(
                "SELECT COUNT(*) FROM portfolio_candidates WHERE state='RETIRED' AND ("
                + " OR ".join(["(ea_id=? AND symbol=?)"] * len(TARGETS)) + ")",
                [value for _source_id, ea_id, symbol in TARGETS for value in (ea_id, symbol)],
            ).fetchone()[0]
            if retired_pc != 6:
                raise Retire6Error(f"retired_portfolio_count:{retired_pc}")
            quick_check = conn.execute("PRAGMA quick_check").fetchone()[0]
            if quick_check != "ok":
                raise Retire6Error(f"quick_check:{quick_check}")
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
    receipt = {
        "schema": RECEIPT_SCHEMA,
        "applied_at_utc": now,
        "router_task_id": AUTHORIZED_ROUTER_TASK_ID,
        "owner_decision_id": OWNER_DECISION_ID,
        "plan_path": str(plan_path.resolve()),
        "plan_sha256": expected_plan_sha256.lower(),
        "backup": {"path": str(backup_path.resolve()), "sha256": backup_sha},
        "inserted_retire_dispositions": inserted,
        "portfolio_candidate_updates": portfolio_updates,
        "source_row_sha256_after": source_hashes_after,
        "historical_work_item_updates": 0,
        "retire_count": 6,
        "portfolio_retired_count": 6,
        "quick_check": quick_check,
    }
    receipt["receipt_sha256"] = write_new_json(receipt_out, receipt)
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("plan", "apply"))
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
        if args.mode == "plan":
            if args.plan_out is None:
                raise Retire6Error("plan_out_required")
            plan = build_plan(args.db, args.decisions)
            result = {
                "status": "ok", "mode": "plan", "pair_count": 6,
                "plan_path": str(args.plan_out.resolve()),
                "plan_sha256": write_new_json(args.plan_out, plan),
            }
        else:
            if args.plan is None or not args.expected_plan_sha256 or args.receipt_out is None:
                raise Retire6Error("apply_requires_plan_hash_and_receipt")
            result = apply_plan(
                db=args.db, decisions=args.decisions, plan_path=args.plan,
                expected_plan_sha256=args.expected_plan_sha256,
                receipt_out=args.receipt_out, backup_dir=args.backup_dir,
                mutation_lock=args.mutation_lock,
            )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (Retire6Error, OSError, sqlite3.Error, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"status": "aborted", "reason": f"{type(exc).__name__}: {exc}"}, indent=2))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
