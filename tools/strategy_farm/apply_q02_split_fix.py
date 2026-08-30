#!/usr/bin/env python3
"""Apply OWNER-DEC-Q02-SPLIT-FIX-20260830 as one sealed transaction.

The controller is intentionally task-specific.  ``plan`` derives the exact
34-row action manifest from the sealed classification CSV.  ``apply`` requires
the plan SHA-256, takes an online SQLite backup, rechecks every source row, and
then appends 20 Q02 reruns plus 14 RETIRE dispositions.  Only the first five
reruns are claimable; later batches receive item holds.  Historical work-item
rows, verdicts, and evidence are never updated.
"""

from __future__ import annotations

import argparse
import csv
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
    import farmctl
except ModuleNotFoundError:  # pragma: no cover - package import in tests
    from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock
    from tools.strategy_farm import farmctl


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_CLASSIFICATION = Path(
    r"C:\QM\repo\docs\ops\evidence\2026-08-29_q02_stranded_pairs_classification.csv"
)
DEFAULT_DECISIONS = Path(
    r"C:\QM\repo\tools\strategy_farm\config\owner_decision_execution.v1.json"
)
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
DEFAULT_MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")

TASK_ID = "ffc5a16d-3045-4eab-a351-bacd554545a0"
OWNER_DECISION_ID = "OWNER-DEC-Q02-SPLIT-FIX-20260830"
PLAN_SCHEMA = "qm.q02-split-fix-plan/v1"
RECEIPT_SCHEMA = "qm.q02-split-fix-receipt/v1"
MANIFEST_SCHEMA = "qm.q02-split-fix-manifest/v1"
HOLD_CODE = "Q02_SPLIT_FIX_STAGED_BATCH"
EXPECTED_ROWS = 34
EXPECTED_RESTARTS = 20
EXPECTED_RETIRES = 14
MAX_IN_FLIGHT = 5
RESTART_CAUSES = {
    "ACTIVE_TIMEOUT", "TIMEOUT_METATESTER_HUNG", "NO_HISTORY_TRANSIENT",
}
RETIRE_CAUSES = {
    "SETFILE_MISSING", "ONINIT_FAILED",
    "SUMMARY_MISSING_NO_ROW_BOUND_AGGREGATE", "LOG_BOMB",
}
NAMESPACE = uuid.UUID("7f4a0f48-214d-58ea-858e-4b413dcbec4c")


class SplitFixError(RuntimeError):
    """Fail-closed input, precondition, or postcondition error."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"),
                       ensure_ascii=False) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def deterministic_id(action: str, source_id: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"{OWNER_DECISION_ID}|{action}|{source_id}"))


def connect(db: Path, *, read_only: bool) -> sqlite3.Connection:
    if read_only:
        conn = sqlite3.connect(db.resolve().as_uri() + "?mode=ro", uri=True, timeout=30)
        conn.execute("PRAGMA query_only=ON")
    else:
        conn = sqlite3.connect(str(db), timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def write_new_json(path: Path, value: dict[str, Any]) -> str:
    if path.exists():
        raise SplitFixError(f"output_exists:{path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = canonical_bytes(value)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_bytes(raw)
    temporary.replace(path)
    return sha256_bytes(raw)


def backup_database(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    destination = backup_dir / f"farm_state_before_q02_split_fix_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    source = sqlite3.connect(str(db), timeout=30)
    target = sqlite3.connect(str(destination))
    try:
        source.backup(target)
    finally:
        target.close()
        source.close()
    return destination, sha256_file(destination)


def decision_binding(path: Path) -> str:
    doc = json.loads(path.read_text(encoding="utf-8-sig"))
    matches = [row for row in doc.get("decisions", []) if row.get("id") == OWNER_DECISION_ID]
    if len(matches) != 1:
        raise SplitFixError(f"owner_decision_count:{len(matches)}")
    yes = matches[0].get("choices", {}).get("YES", {})
    text = json.dumps(yes, sort_keys=True)
    required = ("20 append-only Q02 restarts", "14 append-only retire dispositions",
                "max 5 in flight", "classification CSV as provenance")
    if any(token not in text for token in required):
        raise SplitFixError("owner_decision_contract_drift")
    return sha256_file(path)


def derive_manifest(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != EXPECTED_ROWS:
        raise SplitFixError(f"classification_count:{len(rows)}!={EXPECTED_ROWS}")
    required = {"ea_id", "symbol", "primary_cause", "latest_work_item_id"}
    if not rows or not required.issubset(rows[0]):
        raise SplitFixError("classification_columns_missing")
    pairs: set[tuple[str, str]] = set()
    sources: set[str] = set()
    manifest_rows: list[dict[str, Any]] = []
    restart_index = 0
    for source in rows:
        ea_id = str(source["ea_id"]).strip()
        symbol = str(source["symbol"]).strip()
        cause = str(source["primary_cause"]).strip().upper()
        source_id = str(source["latest_work_item_id"]).strip()
        if not re.fullmatch(r"QM5_\d+", ea_id) or not symbol or not source_id:
            raise SplitFixError(f"ambiguous_classification_row:{ea_id}:{symbol}")
        if (ea_id, symbol) in pairs or source_id in sources:
            raise SplitFixError(f"duplicate_classification_identity:{ea_id}:{symbol}:{source_id}")
        pairs.add((ea_id, symbol)); sources.add(source_id)
        if cause in RESTART_CAUSES:
            action = "RESTART"
            restart_index += 1
            batch = ((restart_index - 1) // MAX_IN_FLIGHT) + 1
        elif cause in RETIRE_CAUSES:
            action = "RETIRE"
            batch = None
        else:
            raise SplitFixError(f"unmapped_primary_cause:{cause}")
        manifest_rows.append({
            "action": action,
            "batch": batch,
            "cause": cause,
            "ea_id": ea_id,
            "source_work_item_id": source_id,
            "successor_work_item_id": deterministic_id(action, source_id),
            "symbol": symbol,
        })
    restarts = sum(row["action"] == "RESTART" for row in manifest_rows)
    retires = sum(row["action"] == "RETIRE" for row in manifest_rows)
    if (restarts, retires) != (EXPECTED_RESTARTS, EXPECTED_RETIRES):
        raise SplitFixError(f"action_count_mismatch:{restarts}/{retires}")
    manifest = {
        "schema": MANIFEST_SCHEMA,
        "classification_path": str(path.resolve()),
        "classification_sha256": sha256_file(path),
        "mapping": {
            "RESTART": sorted(RESTART_CAUSES),
            "RETIRE": sorted(RETIRE_CAUSES),
        },
        "row_count": len(manifest_rows),
        "restart_count": restarts,
        "retire_count": retires,
        "max_in_flight": MAX_IN_FLIGHT,
        "rows": manifest_rows,
    }
    manifest["rows_sha256"] = sha256_bytes(canonical_bytes(manifest_rows))
    return manifest


def _artifact_bindings(row: sqlite3.Row, payload: dict[str, Any]) -> dict[str, Any]:
    setfile = Path(str(row["setfile_path"]))
    risk_ok, risk = farmctl._q02_fixed_risk_contract(str(setfile))
    if not risk_ok:
        raise SplitFixError(f"fixed_risk_contract:{row['id']}:{risk}")
    ea_dir = setfile.parent.parent
    mq5 = ea_dir / f"{ea_dir.name}.mq5"
    ex5 = ea_dir / f"{ea_dir.name}.ex5"
    if not mq5.is_file() or not ex5.is_file():
        raise SplitFixError(f"current_artifact_missing:{row['id']}:{mq5}:{ex5}")
    period = str(payload.get("expected_period") or payload.get("host_timeframe") or "").strip()
    if not period:
        match = re.search(r"_(M1|M5|M15|M30|H1|H4|D1|W1)_", setfile.name, re.I)
        period = match.group(1).upper() if match else ""
    if not period:
        raise SplitFixError(f"timeframe_unresolved:{row['id']}")
    return {
        "expected_ex5_path": str(ex5.resolve()),
        "expected_ex5_sha256": sha256_file(ex5),
        "expected_mq5_sha256": sha256_file(mq5),
        "expected_setfile_sha256": sha256_file(setfile),
        "expected_expert": f"QM\\{ea_dir.name}",
        "expected_period": period,
        "expected_symbol": str(row["symbol"]),
        "risk_fixed": risk["risk_fixed"],
        "risk_percent": risk["risk_percent"],
    }


def _source_snapshot(conn: sqlite3.Connection, item: dict[str, Any]) -> dict[str, Any]:
    row = conn.execute("SELECT * FROM work_items WHERE id=?", (item["source_work_item_id"],)).fetchone()
    if row is None:
        raise SplitFixError(f"source_missing:{item['source_work_item_id']}")
    if (row["ea_id"], row["symbol"], str(row["phase"]).upper()) != (
        item["ea_id"], item["symbol"], "Q02"
    ) or row["kind"] != "backtest" or row["status"] not in {"done", "failed"} \
            or str(row["verdict"]).upper() != "INFRA_FAIL" or row["claimed_by"]:
        raise SplitFixError(f"source_identity_drift:{row['id']}")
    open_row = conn.execute(
        "SELECT id FROM work_items WHERE ea_id=? AND symbol=? AND phase IN ('Q02','P2') "
        "AND status IN ('pending','active') LIMIT 1", (row["ea_id"], row["symbol"]),
    ).fetchone()
    if open_row:
        raise SplitFixError(f"pair_already_open:{row['id']}:{open_row['id']}")
    if conn.execute("SELECT 1 FROM work_item_supersedes WHERE work_item_id=?", (row["id"],)).fetchone():
        raise SplitFixError(f"source_already_superseded:{row['id']}")
    if conn.execute("SELECT 1 FROM work_items WHERE id=?", (item["successor_work_item_id"],)).fetchone():
        raise SplitFixError(f"successor_exists:{item['successor_work_item_id']}")
    raw_payload = str(row["payload_json"] or "{}")
    try:
        payload = json.loads(raw_payload)
    except json.JSONDecodeError as exc:
        raise SplitFixError(f"source_payload_invalid:{row['id']}") from exc
    if not isinstance(payload, dict):
        raise SplitFixError(f"source_payload_not_object:{row['id']}")
    snapshot = {
        "source_payload_sha256": sha256_bytes(raw_payload.encode("utf-8")),
        "source_status": row["status"],
        "source_updated_at": row["updated_at"],
        "source_verdict": row["verdict"],
        "kind": row["kind"],
        "phase": row["phase"],
        "setfile_path": row["setfile_path"],
        "gate_contract_version": row["gate_contract_version"] or "legacy",
    }
    if item["action"] == "RESTART":
        snapshot["artifact_bindings"] = _artifact_bindings(row, payload)
        snapshot["stable_payload"] = {
            key: payload[key] for key in farmctl._Q02_APPEND_ONLY_STABLE_PAYLOAD_KEYS
            if key in payload and key != "priority_track"
        }
    return snapshot


def build_plan(db: Path, classification: Path, decisions: Path) -> dict[str, Any]:
    manifest = derive_manifest(classification)
    decision_sha = decision_binding(decisions)
    conn = connect(db, read_only=True)
    try:
        targets = [{**row, **_source_snapshot(conn, row)} for row in manifest["rows"]]
    finally:
        conn.close()
    plan = {
        "schema": PLAN_SCHEMA,
        "generated_at_utc": utc_now(),
        "database": str(db.resolve()),
        "router_task_id": TASK_ID,
        "owner_decision": {"id": OWNER_DECISION_ID, "path": str(decisions.resolve()),
                           "sha256": decision_sha},
        "manifest": manifest,
        "mutation": "APPEND_20_Q02_RERUNS_AND_14_RETIRE_DISPOSITIONS",
        "historical_work_item_updates": 0,
        "targets": targets,
    }
    plan["targets_sha256"] = sha256_bytes(canonical_bytes(targets))
    return plan


def validate_plan(plan: dict[str, Any], classification: Path, decisions: Path) -> None:
    if plan.get("schema") != PLAN_SCHEMA or plan.get("router_task_id") != TASK_ID:
        raise SplitFixError("plan_authority_mismatch")
    if plan.get("owner_decision", {}).get("id") != OWNER_DECISION_ID:
        raise SplitFixError("plan_owner_decision_mismatch")
    manifest = derive_manifest(classification)
    if manifest != plan.get("manifest"):
        raise SplitFixError("sealed_manifest_drift")
    if decision_binding(decisions) != plan.get("owner_decision", {}).get("sha256"):
        raise SplitFixError("owner_decision_file_drift")
    targets = plan.get("targets") or []
    if len(targets) != EXPECTED_ROWS or sha256_bytes(canonical_bytes(targets)) != plan.get("targets_sha256"):
        raise SplitFixError("plan_targets_invalid")


def _insert_supersedes(conn: sqlite3.Connection, source_id: str, successor_id: str,
                       evidence_path: Path, now: str, action: str) -> None:
    conn.execute(
        "INSERT INTO work_item_supersedes(work_item_id,superseded_by_work_item_id,reason,"
        "source_encoding,evidence_path,recorded_by,recorded_at) VALUES(?,?,?,?,?,?,?)",
        (source_id, successor_id, f"{OWNER_DECISION_ID} append-only {action}",
         "owner:q02-split-fix/v1", str(evidence_path.resolve()), "codex", now),
    )


def apply_plan(*, db: Path, classification: Path, decisions: Path, plan_path: Path,
               expected_plan_sha256: str, receipt_out: Path, evidence_path: Path,
               backup_dir: Path, mutation_lock: Path) -> dict[str, Any]:
    if sha256_file(plan_path) != expected_plan_sha256.lower():
        raise SplitFixError("plan_sha256_mismatch")
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    validate_plan(plan, classification, decisions)
    if not evidence_path.is_file():
        raise SplitFixError(f"evidence_path_missing:{evidence_path}")
    backup_path, backup_sha = backup_database(db, backup_dir)
    now = utc_now(); restarts: list[dict[str, Any]] = []; retires: list[str] = []
    with FactoryMutationLock(mutation_lock, owner=f"q02-split-fix:{TASK_ID}"):
        conn = connect(db, read_only=False)
        try:
            conn.execute("BEGIN IMMEDIATE")
            live = [{**item, **_source_snapshot(conn, item)} for item in plan["manifest"]["rows"]]
            if sha256_bytes(canonical_bytes(live)) != plan["targets_sha256"]:
                raise SplitFixError("live_source_or_artifact_drift")
            for item in plan["targets"]:
                common = {
                    "append_only_disposition": item["action"] == "RETIRE",
                    "classification_cause": item["cause"],
                    "classification_path": plan["manifest"]["classification_path"],
                    "classification_sha256": plan["manifest"]["classification_sha256"],
                    "historical_evidence_preserved": True,
                    "historical_verdicts_preserved": True,
                    "manifest_rows_sha256": plan["manifest"]["rows_sha256"],
                    "owner_decision_id": OWNER_DECISION_ID,
                    "owner_decision_sha256": plan["owner_decision"]["sha256"],
                    "plan_sha256": expected_plan_sha256.lower(),
                    "router_task_id": TASK_ID,
                    "source_payload_sha256": item["source_payload_sha256"],
                    "source_work_item_id": item["source_work_item_id"],
                }
                if item["action"] == "RESTART":
                    payload = dict(item["stable_payload"])
                    payload.update(common)
                    payload.update(item["artifact_bindings"])
                    payload.update({
                        "append_only_disposition": False,
                        "append_only_rerun": True,
                        "append_only_rerun_of_work_item": item["source_work_item_id"],
                        "bounded_missing_predecessor_evidence_exception": True,
                        "enqueued_at_utc": now,
                        "enqueued_by": "apply_q02_split_fix",
                        "historical_work_item_preserved": True,
                        "rerun_reason": "OWNER_DEC_Q02_SPLIT_FIX_TRANSIENT_RESTART",
                        "rerun_source_evidence_binding": "owner_decision_classification_csv",
                        "rerun_source_evidence_path": plan["manifest"]["classification_path"],
                        "rerun_source_evidence_sha256": plan["manifest"]["classification_sha256"],
                        "restart_batch": item["batch"],
                        "restart_batch_max_in_flight": MAX_IN_FLIGHT,
                    })
                    bindings = item["artifact_bindings"]
                    conn.execute(
                        """INSERT INTO work_items(
                          id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
                          parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,
                          gate_contract_version,ex5_sha256,setfile_sha256,mq5_sha256,
                          verdict_taxonomy,sh3_enforced)
                        VALUES(?,'backtest','Q02',?,?,?,'pending',NULL,0,NULL,NULL,NULL,?,?,?,'v4',?,?,?,NULL,0)""",
                        (item["successor_work_item_id"], item["ea_id"], item["symbol"],
                         item["setfile_path"], json.dumps(payload, sort_keys=True), now, now,
                         bindings["expected_ex5_sha256"], bindings["expected_setfile_sha256"],
                         bindings["expected_mq5_sha256"]),
                    )
                    held = int(item["batch"]) > 1
                    if held:
                        conn.execute(
                            "INSERT INTO work_item_holds(work_item_id,hold_code,reason,active,"
                            "release_on_restart,created_at,updated_at) VALUES(?,?,?,1,0,?,?)",
                            (item["successor_work_item_id"], HOLD_CODE,
                             f"{OWNER_DECISION_ID} staged batch {item['batch']}; release only after prior batch terminal",
                             now, now),
                        )
                    restarts.append({"work_item_id": item["successor_work_item_id"],
                                     "batch": item["batch"], "held": held,
                                     "ea_id": item["ea_id"], "symbol": item["symbol"]})
                else:
                    payload = {**common, "control_plane_disposition": True,
                               "disposition": "RETIRE",
                               "verdict_reason": "OWNER_APPROVED_STRUCTURAL_Q02_RETIREMENT",
                               "verdict_taxonomy": "strategy"}
                    conn.execute(
                        """INSERT INTO work_items(
                          id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
                          parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,
                          gate_contract_version,verdict_taxonomy,sh3_enforced)
                        VALUES(?,'disposition','Q02',?,?,?,'done','RETIRE',0,NULL,?,NULL,?,?,?,?,'strategy',0)""",
                        (item["successor_work_item_id"], item["ea_id"], item["symbol"],
                         item["setfile_path"], str(evidence_path.resolve()),
                         json.dumps(payload, sort_keys=True), now, now, item["gate_contract_version"]),
                    )
                    retires.append(item["successor_work_item_id"])
                _insert_supersedes(conn, item["source_work_item_id"],
                                   item["successor_work_item_id"], evidence_path, now, item["action"])
                conn.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)",
                    (now, "work_item", item["successor_work_item_id"],
                     "owner_q02_split_fix_appended", json.dumps(common, sort_keys=True)),
                )
            claimable = conn.execute(
                """SELECT COUNT(*) FROM work_items w
                   WHERE json_extract(w.payload_json,'$.owner_decision_id')=?
                     AND json_extract(w.payload_json,'$.append_only_rerun')=1
                     AND w.status IN ('pending','active')
                     AND NOT EXISTS(SELECT 1 FROM work_item_holds h
                                    WHERE h.work_item_id=w.id AND h.active=1)""",
                (OWNER_DECISION_ID,),
            ).fetchone()[0]
            held = conn.execute(
                "SELECT COUNT(*) FROM work_item_holds WHERE hold_code=? AND active=1",
                (HOLD_CODE,),
            ).fetchone()[0]
            retire_readback = conn.execute(
                """SELECT COUNT(*) FROM work_items WHERE
                   json_extract(payload_json,'$.owner_decision_id')=? AND kind='disposition'
                   AND status='done' AND verdict='RETIRE' AND sh3_enforced=0""",
                (OWNER_DECISION_ID,),
            ).fetchone()[0]
            if (len(restarts), len(retires), claimable, held, retire_readback) != (20, 14, 5, 15, 14):
                raise SplitFixError(
                    f"postcondition_counts:{len(restarts)}/{len(retires)}/{claimable}/{held}/{retire_readback}"
                )
            quick = conn.execute("PRAGMA quick_check").fetchone()[0]
            if quick != "ok":
                raise SplitFixError(f"quick_check:{quick}")
            conn.commit()
        except Exception:
            conn.rollback(); raise
        finally:
            conn.close()
    batches = [{"batch": batch,
                "work_items": [row for row in restarts if row["batch"] == batch],
                "claimable": batch == 1} for batch in range(1, 5)]
    receipt = {
        "schema": RECEIPT_SCHEMA, "applied_at_utc": now,
        "router_task_id": TASK_ID, "owner_decision_id": OWNER_DECISION_ID,
        "plan_path": str(plan_path.resolve()), "plan_sha256": expected_plan_sha256.lower(),
        "manifest_sha256": sha256_bytes(canonical_bytes(plan["manifest"])),
        "manifest_rows_sha256": plan["manifest"]["rows_sha256"],
        "backup": {"path": str(backup_path.resolve()), "sha256": backup_sha},
        "restart_count": 20, "retire_count": 14, "claimable_restart_count": 5,
        "held_restart_count": 15, "max_in_flight": 5, "batches": batches,
        "retire_work_item_ids": retires, "historical_work_item_updates": 0,
        "quick_check": "ok",
    }
    receipt["receipt_sha256"] = write_new_json(receipt_out, receipt)
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("plan", "apply"))
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--classification", type=Path, default=DEFAULT_CLASSIFICATION)
    parser.add_argument("--decisions", type=Path, default=DEFAULT_DECISIONS)
    parser.add_argument("--plan-out", type=Path)
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--expected-plan-sha256")
    parser.add_argument("--receipt-out", type=Path)
    parser.add_argument("--evidence-path", type=Path)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_MUTATION_LOCK)
    args = parser.parse_args()
    try:
        if args.mode == "plan":
            if args.plan_out is None:
                raise SplitFixError("plan_out_required")
            plan = build_plan(args.db, args.classification, args.decisions)
            result = {"status": "ok", "mode": "plan", "plan_path": str(args.plan_out.resolve()),
                      "plan_sha256": write_new_json(args.plan_out, plan),
                      "rows": 34, "restarts": 20, "retires": 14}
        else:
            if args.plan is None or not args.expected_plan_sha256 or args.receipt_out is None \
                    or args.evidence_path is None:
                raise SplitFixError("apply_requires_plan_hash_receipt_and_evidence")
            result = apply_plan(
                db=args.db, classification=args.classification, decisions=args.decisions,
                plan_path=args.plan, expected_plan_sha256=args.expected_plan_sha256,
                receipt_out=args.receipt_out, evidence_path=args.evidence_path,
                backup_dir=args.backup_dir, mutation_lock=args.mutation_lock,
            )
        print(json.dumps(result, indent=2, sort_keys=True)); return 0
    except (SplitFixError, OSError, sqlite3.Error, json.JSONDecodeError, ValueError) as exc:
        print(json.dumps({"status": "aborted", "reason": f"{type(exc).__name__}: {exc}"}, indent=2))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
