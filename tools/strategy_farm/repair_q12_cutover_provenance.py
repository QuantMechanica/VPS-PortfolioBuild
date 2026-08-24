#!/usr/bin/env python3
"""Repair the three v3/Q14 rows relabelled in-place during the v4 cutover.

The historical payload bytes are evidence and are never rewritten.  Each bad
column relabel is restored to v3/Q14 and terminalised as an infrastructure
migration failure; a fresh, deterministic v4/Q12 successor is appended with an
explicit migration-provenance binding.  The operation is a tiny guarded SQLite
transaction and does not stop, start, claim, or execute factory work.

Dry-run is the default.  Apply requires the SHA-256 of the exact dry-run plan::

    python tools/strategy_farm/repair_q12_cutover_provenance.py
    python tools/strategy_farm/repair_q12_cutover_provenance.py \
        --apply --expected-plan-sha256 <sha>
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import sys
import uuid
from pathlib import Path
from typing import Any, Mapping

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import farmctl, gate_manifest  # noqa: E402


SCHEMA = "qm.gate-cutover-provenance-repair/v1"
OWNER_DECISION = "OWNER-DEC-Q12-PROVENANCE-REPAIR-20260824"
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_RECEIPT = Path(
    r"D:\QM\reports\state\q12_cutover_provenance_repair_20260824.json"
)
EVIDENCE_PATH = (
    r"C:\QM\repo\docs\ops\evidence\2026-08-24_q12_cutover_provenance_repair.md"
)
OLD_MANIFEST_SHA256 = (
    "988f9dea709bb71de5d7b6bce3c02ea02417cd63f447767853281c8f5f8fc6ce"
)
REPAIR_NAMESPACE = uuid.UUID("47545562-dd1f-44fd-ac17-9bc75acb058c")

TARGETS: dict[str, dict[str, str]] = {
    "48183f09-ad48-5c42-b1b6-9e7787b5ac32": {
        "ea_id": "QM5_10706",
        "symbol": "GBPUSD.DWX",
        "parent_work_item_id": "f06b8243-d3ca-490a-8b47-7c598f4d6d58",
        "payload_sha256": "d0e5dc434008a684ec646a97b8273cfd62a6e4016abde3933ec7b6bd80e18974",
    },
    "8eda68d9-aae3-509c-a0cc-6e738e1bde99": {
        "ea_id": "QM5_11421",
        "symbol": "EURUSD.DWX",
        "parent_work_item_id": "38eddd19-0d07-4686-b1e2-afc4124e9bc8",
        "payload_sha256": "0d28f213ab716a1a57e9e71be7a22b5e38f52cae1bca9bfe31bfccb30e03b48a",
    },
    "9975987c-d408-5724-8863-f4e49a214d4b": {
        "ea_id": "QM5_11422",
        "symbol": "USDCAD.DWX",
        "parent_work_item_id": "6f9400fa-9ca2-4835-9fcf-e1087289f9b1",
        "payload_sha256": "aeee5e4488e2679b7d0158bbae2bc7cc3aa47488906a84544e0875203fa7b996",
    },
}

REPAIR_LEDGER_DDL = """
CREATE TABLE IF NOT EXISTS gate_contract_provenance_repairs (
    repair_id TEXT PRIMARY KEY,
    old_work_item_id TEXT NOT NULL UNIQUE,
    new_work_item_id TEXT NOT NULL UNIQUE,
    old_payload_sha256 TEXT NOT NULL,
    new_payload_sha256 TEXT NOT NULL,
    old_phase TEXT NOT NULL,
    old_version TEXT NOT NULL,
    new_phase TEXT NOT NULL,
    new_version TEXT NOT NULL,
    owner_decision TEXT NOT NULL,
    evidence_path TEXT NOT NULL,
    repaired_at TEXT NOT NULL
);
CREATE TRIGGER IF NOT EXISTS trg_gate_contract_provenance_repairs_no_update
BEFORE UPDATE ON gate_contract_provenance_repairs
BEGIN SELECT RAISE(ABORT, 'gate_contract_provenance_repairs is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_gate_contract_provenance_repairs_no_delete
BEFORE DELETE ON gate_contract_provenance_repairs
BEGIN SELECT RAISE(ABORT, 'gate_contract_provenance_repairs is append-only'); END;
"""


def _ensure_repair_ledger(conn: sqlite3.Connection) -> None:
    """Install the ledger without ``executescript``'s implicit COMMIT."""

    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS gate_contract_provenance_repairs (
            repair_id TEXT PRIMARY KEY,
            old_work_item_id TEXT NOT NULL UNIQUE,
            new_work_item_id TEXT NOT NULL UNIQUE,
            old_payload_sha256 TEXT NOT NULL,
            new_payload_sha256 TEXT NOT NULL,
            old_phase TEXT NOT NULL,
            old_version TEXT NOT NULL,
            new_phase TEXT NOT NULL,
            new_version TEXT NOT NULL,
            owner_decision TEXT NOT NULL,
            evidence_path TEXT NOT NULL,
            repaired_at TEXT NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE TRIGGER IF NOT EXISTS trg_gate_contract_provenance_repairs_no_update
        BEFORE UPDATE ON gate_contract_provenance_repairs
        BEGIN SELECT RAISE(ABORT, 'gate_contract_provenance_repairs is append-only'); END
        """
    )
    conn.execute(
        """
        CREATE TRIGGER IF NOT EXISTS trg_gate_contract_provenance_repairs_no_delete
        BEFORE DELETE ON gate_contract_provenance_repairs
        BEGIN SELECT RAISE(ABORT, 'gate_contract_provenance_repairs is append-only'); END
        """
    )


class RepairError(RuntimeError):
    """The live state no longer matches the reviewed repair contract."""


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _sha_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def _public(value: Any) -> Any:
    """Strip transaction-only values before hashing or emitting a plan."""

    if isinstance(value, dict):
        return {key: _public(item) for key, item in value.items() if not key.startswith("_")}
    if isinstance(value, list):
        return [_public(item) for item in value]
    return value


def plan_sha256(plan: Mapping[str, Any]) -> str:
    return hashlib.sha256(_canonical_bytes(_public(dict(plan)))).hexdigest()


def _table_exists(conn: sqlite3.Connection, name: str) -> bool:
    return conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    ).fetchone() is not None


def _normalise_version(value: Any) -> str:
    version = str(value or "").strip().lower()
    return version.rsplit("/", 1)[-1] if version.startswith("qm.gate-manifest/") else version


def _new_payload(
    old_payload: Mapping[str, Any],
    *,
    old_id: str,
    old_payload_sha256: str,
    active_manifest_sha256: str,
    cutover_at: str,
) -> tuple[str, str, str]:
    payload = dict(old_payload)
    payload.pop("routing_identity_sha256", None)
    payload["phase"] = "Q12"
    payload["gate_contract_version"] = "v4"
    payload["gate_manifest_sha256"] = active_manifest_sha256
    payload["migration_provenance"] = {
        "schema": SCHEMA,
        "owner_decision": OWNER_DECISION,
        "source_work_item_id": old_id,
        "source_payload_sha256": old_payload_sha256,
        "source_phase": "Q14",
        "source_gate_contract_version": "v3",
        "observed_cutover_phase": "Q12",
        "observed_cutover_gate_contract_version": "v4",
        "cutover_log_at": cutover_at,
        "source_payload_retained": True,
        "repair_action": "RESTORE_SOURCE_AND_APPEND_NATIVE_SUCCESSOR",
    }
    payload["routing_identity_sha256"] = hashlib.sha256(
        _canonical_bytes(payload)
    ).hexdigest()
    raw = json.dumps(payload, sort_keys=True)
    new_id = str(
        uuid.uuid5(
            REPAIR_NAMESPACE,
            f"{SCHEMA}:{active_manifest_sha256}:{old_id}:Q12:v4",
        )
    )
    return new_id, raw, _sha_text(raw)


def _payload_mismatch_count(conn: sqlite3.Connection) -> int:
    return int(
        conn.execute(
            """
            SELECT count(*) FROM work_items
            WHERE json_valid(payload_json)=1 AND (
              (json_type(payload_json,'$.phase')='text'
               AND trim(CAST(json_extract(payload_json,'$.phase') AS TEXT))<>''
               AND upper(trim(CAST(json_extract(payload_json,'$.phase') AS TEXT)))
                   <> upper(trim(phase)))
              OR
              (json_type(payload_json,'$.gate_contract_version')='text'
               AND trim(CAST(json_extract(payload_json,'$.gate_contract_version') AS TEXT))<>''
               AND gate_contract_version IS NOT NULL
               AND trim(gate_contract_version)<>''
               AND lower(trim(CAST(json_extract(payload_json,'$.gate_contract_version') AS TEXT)))
                   <> lower(trim(gate_contract_version))
               AND lower(trim(CAST(json_extract(payload_json,'$.gate_contract_version') AS TEXT)))
                   <> 'qm.gate-manifest/' || lower(trim(gate_contract_version)))
            )
            """
        ).fetchone()[0]
    )


def build_plan(conn: sqlite3.Connection) -> dict[str, Any]:
    conn.row_factory = sqlite3.Row
    manifest = gate_manifest.load_gate_manifest()
    if manifest.schema_version != gate_manifest.SCHEMA_VERSION_V4:
        raise RepairError(f"active gate manifest is not v4: {manifest.schema_version}")
    actions: list[dict[str, Any]] = []
    ledger_exists = _table_exists(conn, "gate_contract_provenance_repairs")

    for old_id, expected in TARGETS.items():
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (old_id,)).fetchone()
        if row is None:
            raise RepairError(f"target work item missing: {old_id}")
        row_dict = dict(row)
        raw = str(row["payload_json"] or "")
        payload_sha = _sha_text(raw)
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise RepairError(f"target payload is invalid JSON: {old_id}") from exc
        if not isinstance(payload, dict):
            raise RepairError(f"target payload is not an object: {old_id}")
        if payload_sha != expected["payload_sha256"]:
            raise RepairError(
                f"target payload changed for {old_id}: {payload_sha}"
            )
        for field in ("ea_id", "symbol"):
            if str(row[field]) != expected[field]:
                raise RepairError(
                    f"target {field} changed for {old_id}: {row[field]}"
                )
        if str(payload.get("parent_work_item_id")) != expected["parent_work_item_id"]:
            raise RepairError(f"parent binding changed for {old_id}")
        if (
            str(payload.get("phase")) != "Q14"
            or _normalise_version(payload.get("gate_contract_version")) != "v3"
            or str(payload.get("gate_manifest_sha256")) != OLD_MANIFEST_SHA256
        ):
            raise RepairError(f"source payload provenance changed for {old_id}")

        parent = conn.execute(
            "SELECT id,ea_id,symbol,phase,status,verdict FROM work_items WHERE id=?",
            (expected["parent_work_item_id"],),
        ).fetchone()
        if parent is None:
            raise RepairError(f"parent work item missing for {old_id}")
        if (
            str(parent["ea_id"]) != expected["ea_id"]
            or str(parent["symbol"]) != expected["symbol"]
            or str(parent["phase"]).upper() != "Q10"
            or str(parent["status"]).lower() != "done"
            or str(parent["verdict"]).upper() != "PASS"
        ):
            raise RepairError(f"parent work item no longer matches for {old_id}")

        cutovers = conn.execute(
            "SELECT old_phase,new_phase,old_version,new_version,at "
            "FROM gate_contract_cutover_log WHERE work_item_id=? ORDER BY rowid",
            (old_id,),
        ).fetchall()
        if len(cutovers) != 1 or tuple(cutovers[0][:4]) != (
            "Q14", "Q12", "v3", "v4"
        ):
            raise RepairError(f"cutover ledger mismatch for {old_id}")
        cutover_at = str(cutovers[0]["at"])
        new_id, new_raw, new_sha = _new_payload(
            payload,
            old_id=old_id,
            old_payload_sha256=payload_sha,
            active_manifest_sha256=manifest.sha256,
            cutover_at=cutover_at,
        )
        new_row = conn.execute(
            "SELECT phase,status,verdict,gate_contract_version,payload_json "
            "FROM work_items WHERE id=?",
            (new_id,),
        ).fetchone()
        ledger = (
            conn.execute(
                "SELECT old_payload_sha256,new_payload_sha256 FROM "
                "gate_contract_provenance_repairs WHERE old_work_item_id=?",
                (old_id,),
            ).fetchone()
            if ledger_exists
            else None
        )
        pre_state = (
            str(row["phase"]).upper() == "Q12"
            and _normalise_version(row["gate_contract_version"]) == "v4"
            and str(row["status"]).lower() == "pending"
            and row["verdict"] is None
            and row["claimed_by"] is None
            and int(row["attempt_count"] or 0) == 0
            and new_row is None
            and ledger is None
        )
        post_state = (
            str(row["phase"]).upper() == "Q14"
            and _normalise_version(row["gate_contract_version"]) == "v3"
            and str(row["status"]).lower() == "failed"
            and str(row["verdict"]).upper() == "INFRA_FAIL"
            and str(row["evidence_path"]) == EVIDENCE_PATH
            and new_row is not None
            and tuple(new_row[:4]) == ("Q12", "pending", None, "v4")
            and _sha_text(str(new_row["payload_json"])) == new_sha
            and ledger is not None
            and tuple(ledger) == (payload_sha, new_sha)
        )
        if not pre_state and not post_state:
            raise RepairError(f"target is neither exact pre-state nor post-state: {old_id}")
        dependencies = 0
        if _table_exists(conn, "work_item_dependencies"):
            dependencies = int(
                conn.execute(
                    "SELECT count(*) FROM work_item_dependencies "
                    "WHERE child_work_item_id=? OR parent_work_item_id=?",
                    (old_id, old_id),
                ).fetchone()[0]
            )
        active_holds = 0
        if _table_exists(conn, "work_item_holds"):
            active_holds = int(
                conn.execute(
                    "SELECT count(*) FROM work_item_holds "
                    "WHERE work_item_id=? AND active=1",
                    (old_id,),
                ).fetchone()[0]
            )
        if dependencies or active_holds:
            raise RepairError(
                f"target acquired dependencies/holds: {old_id} "
                f"dependencies={dependencies} active_holds={active_holds}"
            )
        actions.append(
            {
                "old_work_item_id": old_id,
                "new_work_item_id": new_id,
                "ea_id": expected["ea_id"],
                "symbol": expected["symbol"],
                "parent_work_item_id": expected["parent_work_item_id"],
                "state": "ALREADY_REPAIRED" if post_state else "READY",
                "old_column_provenance": {"phase": "Q12", "version": "v4"},
                "restored_source_provenance": {"phase": "Q14", "version": "v3"},
                "successor_provenance": {"phase": "Q12", "version": "v4"},
                "old_payload_sha256": payload_sha,
                "new_payload_sha256": new_sha,
                "cutover_at": cutover_at,
                "dependencies": dependencies,
                "active_holds": active_holds,
                "_old_row": row_dict,
                "_old_payload_json": raw,
                "_new_payload_json": new_raw,
            }
        )
    states = {action["state"] for action in actions}
    if len(states) != 1:
        raise RepairError(f"partial repair state is not allowed: {sorted(states)}")
    return {
        "schema": SCHEMA,
        "owner_decision": OWNER_DECISION,
        "active_manifest_sha256": manifest.sha256,
        "evidence_path": EVIDENCE_PATH,
        "state": next(iter(states)),
        "target_count": len(actions),
        "pre_repair_payload_mismatch_count": _payload_mismatch_count(conn),
        "actions": actions,
    }


def apply_plan(conn: sqlite3.Connection, plan: Mapping[str, Any]) -> dict[str, Any]:
    if plan["state"] == "ALREADY_REPAIRED":
        return {"applied": False, "idempotent": True, "repaired_at": None}
    repaired_at = _utc_now()
    _ensure_repair_ledger(conn)
    farmctl.ensure_work_item_gate_contract_schema(conn)
    conn.execute(
        f"DROP TRIGGER IF EXISTS {farmctl._WORK_ITEM_GATE_CONTRACT_IMMUTABLE_TRIGGER}"
    )
    conn.execute(f"DROP TRIGGER IF EXISTS {farmctl._WORK_ITEM_PHASE_IMMUTABLE_TRIGGER}")
    for action in plan["actions"]:
        old = action["_old_row"]
        changed = conn.execute(
            """
            UPDATE work_items
            SET phase='Q14',gate_contract_version='v3',status='failed',
                verdict='INFRA_FAIL',verdict_taxonomy='infra',evidence_path=?,
                claimed_by=NULL,updated_at=?
            WHERE id=? AND phase='Q12' AND gate_contract_version='v4'
              AND status='pending' AND verdict IS NULL AND claimed_by IS NULL
              AND attempt_count=0 AND payload_json=? AND updated_at=?
            """,
            (
                EVIDENCE_PATH,
                repaired_at,
                action["old_work_item_id"],
                action["_old_payload_json"],
                old["updated_at"],
            ),
        ).rowcount
        if changed != 1:
            raise RepairError(
                f"guarded source restore changed {changed} rows for "
                f"{action['old_work_item_id']}"
            )
        conn.execute(
            """
            INSERT INTO work_items(
                id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
                parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,
                gate_contract_version,ex5_sha256,setfile_sha256,mq5_sha256,
                include_closure_sha256,build_id,data_window_start,data_window_end,
                news_calendar_sha256,verdict_taxonomy,sh3_enforced
            ) VALUES(?,?,?,?,?,?,'pending',NULL,0,NULL,NULL,NULL,?,?,?,'v4',
                     ?,?,?,?,?,?,?,?,?,1)
            """,
            (
                action["new_work_item_id"],
                "analytic",
                "Q12",
                old["ea_id"],
                old["symbol"],
                old["setfile_path"],
                action["_new_payload_json"],
                repaired_at,
                repaired_at,
                old.get("ex5_sha256"),
                old.get("setfile_sha256"),
                old.get("mq5_sha256"),
                old.get("include_closure_sha256"),
                old.get("build_id"),
                old.get("data_window_start"),
                old.get("data_window_end"),
                old.get("news_calendar_sha256"),
                "open",
            ),
        )
        repair_id = str(
            uuid.uuid5(
                REPAIR_NAMESPACE,
                f"ledger:{action['old_work_item_id']}:{action['new_work_item_id']}",
            )
        )
        conn.execute(
            """
            INSERT INTO gate_contract_provenance_repairs(
                repair_id,old_work_item_id,new_work_item_id,old_payload_sha256,
                new_payload_sha256,old_phase,old_version,new_phase,new_version,
                owner_decision,evidence_path,repaired_at
            ) VALUES(?,?,?,?,?,'Q14','v3','Q12','v4',?,?,?)
            """,
            (
                repair_id,
                action["old_work_item_id"],
                action["new_work_item_id"],
                action["old_payload_sha256"],
                action["new_payload_sha256"],
                OWNER_DECISION,
                EVIDENCE_PATH,
                repaired_at,
            ),
        )
    farmctl.ensure_work_item_gate_contract_schema(conn)
    mismatch_count = _payload_mismatch_count(conn)
    if mismatch_count != 0:
        raise RepairError(
            f"payload provenance mismatch census is {mismatch_count}, expected 0"
        )
    return {
        "applied": True,
        "idempotent": False,
        "repaired_at": repaired_at,
        "post_repair_payload_mismatch_count": mismatch_count,
    }


def _connect(path: Path, *, writable: bool) -> sqlite3.Connection:
    if writable:
        conn = sqlite3.connect(str(path), timeout=30.0)
    else:
        uri = f"file:{path.resolve().as_posix()}?mode=ro"
        conn = sqlite3.connect(uri, uri=True, timeout=30.0)
        conn.execute("PRAGMA query_only=ON")
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def _write_receipt(path: Path, payload: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(
        json.dumps(_public(dict(payload)), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    temp.replace(path)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--expected-plan-sha256")
    parser.add_argument("--receipt-out", type=Path, default=DEFAULT_RECEIPT)
    args = parser.parse_args(argv)
    if args.apply and not args.expected_plan_sha256:
        parser.error("--apply requires --expected-plan-sha256 from the dry-run")

    conn = _connect(args.db, writable=args.apply)
    try:
        if args.apply:
            conn.execute("BEGIN IMMEDIATE")
        plan = build_plan(conn)
        plan_hash = plan_sha256(plan)
        if args.apply and plan_hash != args.expected_plan_sha256:
            raise RepairError(
                f"plan hash changed: expected {args.expected_plan_sha256}, observed {plan_hash}"
            )
        result = (
            apply_plan(conn, plan)
            if args.apply
            else {"applied": False, "idempotent": plan["state"] == "ALREADY_REPAIRED"}
        )
        if args.apply:
            conn.commit()
    except Exception:
        if conn.in_transaction:
            conn.rollback()
        raise
    finally:
        conn.close()

    receipt = {
        "schema": SCHEMA,
        "dry_run": not args.apply,
        "db": str(args.db),
        "plan_sha256": plan_hash,
        "plan": plan,
        "result": result,
    }
    if args.apply:
        _write_receipt(args.receipt_out, receipt)
        receipt["receipt_path"] = str(args.receipt_out)
    sys.stdout.write(json.dumps(_public(receipt), indent=2, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
