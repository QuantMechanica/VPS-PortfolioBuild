#!/usr/bin/env python3
"""Append the 16 OWNER-approved dead-Q02 INVALID disposition rows.

The tool is deliberately specific to OWNER-DEC-Q02-DEAD16-20260825.  Dry-run
binds the approved 88-pair census, the decision document, the exact 16 terminal
INFRA_FAIL source rows, and deterministic destination IDs into a plan.  Apply
requires that plan's SHA-256, takes an online SQLite backup, rechecks every
binding under the shared factory mutation lock, and inserts new terminal rows
plus events.  Historical work_items are never updated or deleted.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import sqlite3
import uuid
from pathlib import Path
from typing import Any

try:
    from factory_mutation_lock import FactoryMutationLock
except ModuleNotFoundError:  # pragma: no cover - package import in tests
    from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_CENSUS = Path(
    r"C:\QM\repo\docs\ops\evidence\2026-08-24_q02_stranded_pairs_census.csv"
)
DEFAULT_DECISION = Path(
    r"C:\QM\repo\decisions\2026-08-25_owner_hma_requal_ftmo_park_q02_dead16.md"
)
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
DEFAULT_MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")

TASK_ID = "b8cfb755-3e59-4051-948b-5d73239b2202"
OWNER_DECISION_ID = "OWNER-DEC-Q02-DEAD16-20260825"
EXPECTED_CENSUS_ROWS = 88
EXPECTED_DISPOSITION_ROWS = 16
EXPECTED_ONINIT_ROWS = 14
EXPECTED_LOG_BOMB_ROWS = 2
PLAN_SCHEMA = "qm.q02-dead16-disposition-plan/v1"
RECEIPT_SCHEMA = "qm.q02-dead16-disposition-receipt/v1"
DISPOSITION_NAMESPACE = uuid.UUID("50216cbc-55f2-4374-a640-eb71c4261fc5")

CLASS_ONINIT = "LIKELY_DEAD_DETERMINISTIC_ONINIT"
CLASS_LOG_BOMB = "LIKELY_DEAD_DETERMINISTIC_SINGLE_REASON"
APPROVED_CLASSES = {CLASS_ONINIT, CLASS_LOG_BOMB}

STRANDED_COHORT_SQL = """
SELECT ea_id, symbol
FROM work_items
WHERE phase IN ('Q02','P2')
GROUP BY ea_id, symbol
HAVING SUM(CASE WHEN status IN ('done','failed') AND verdict IS NOT NULL
                 AND TRIM(verdict)<>'' AND UPPER(verdict)<>'INFRA_FAIL'
                THEN 1 ELSE 0 END)=0
   AND SUM(CASE WHEN status IN ('pending','active') THEN 1 ELSE 0 END)=0
   AND SUM(CASE WHEN UPPER(verdict)='INFRA_FAIL' THEN 1 ELSE 0 END)>=12
""".strip()


class Dead16Error(RuntimeError):
    """Fail-closed plan or apply error."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def connect_ro(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    return conn


def connect_rw(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(str(db), timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def write_new_json(path: Path, value: dict[str, Any]) -> str:
    if path.exists():
        raise Dead16Error(f"output_exists:{path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    data = canonical_bytes(value)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_bytes(data)
    temporary.replace(path)
    return sha256_bytes(data)


def backup_database(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    destination = backup_dir / (
        f"farm_state_before_q02_dead16_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    )
    source_conn = sqlite3.connect(str(db), timeout=30)
    backup_conn = sqlite3.connect(str(destination))
    try:
        source_conn.backup(backup_conn)
    finally:
        backup_conn.close()
        source_conn.close()
    return destination, sha256_file(destination)


def read_bound_census(path: Path) -> tuple[list[dict[str, str]], str]:
    raw = path.read_bytes()
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != EXPECTED_CENSUS_ROWS:
        raise Dead16Error(
            f"approved_census_row_count_changed:{len(rows)}!={EXPECTED_CENSUS_ROWS}"
        )
    approved = [row for row in rows if row.get("classification") in APPROVED_CLASSES]
    if len(approved) != EXPECTED_DISPOSITION_ROWS:
        raise Dead16Error(
            "approved_dead_pair_count_changed:"
            f"{len(approved)}!={EXPECTED_DISPOSITION_ROWS}"
        )
    oninit = sum(row["classification"] == CLASS_ONINIT for row in approved)
    log_bomb = sum(row["classification"] == CLASS_LOG_BOMB for row in approved)
    if (oninit, log_bomb) != (EXPECTED_ONINIT_ROWS, EXPECTED_LOG_BOMB_ROWS):
        raise Dead16Error(
            f"approved_class_counts_changed:oninit={oninit},log_bomb={log_bomb}"
        )
    pairs = [(row["ea_id"], row["symbol"]) for row in approved]
    if len(set(pairs)) != EXPECTED_DISPOSITION_ROWS:
        raise Dead16Error("approved_census_contains_duplicate_pair")
    for row in approved:
        if int(row.get("infra_fail_rows") or 0) < 12:
            raise Dead16Error(
                f"approved_pair_below_retry_floor:{row['ea_id']}:{row['symbol']}"
            )
        reasons = str(row.get("distinct_reasons") or "").upper()
        if row["classification"] == CLASS_ONINIT and "ONINIT_FAILED" not in reasons:
            raise Dead16Error(f"oninit_reason_missing:{row['ea_id']}:{row['symbol']}")
        if row["classification"] == CLASS_LOG_BOMB and "LOG_BOMB" not in reasons:
            raise Dead16Error(f"log_bomb_reason_missing:{row['ea_id']}:{row['symbol']}")
    approved.sort(key=lambda row: (row["ea_id"], row["symbol"]))
    return approved, sha256_bytes(raw)


def read_bound_decision(path: Path) -> tuple[str, str]:
    raw = path.read_bytes()
    text = raw.decode("utf-8-sig")
    required = (
        OWNER_DECISION_ID,
        "disposition_only=true",
        "16 deterministisch tote Q02-Paare",
    )
    missing = [token for token in required if token not in text]
    if missing:
        raise Dead16Error(f"owner_decision_contract_missing:{','.join(missing)}")
    return text, sha256_bytes(raw)


def disposition_id(ea_id: str, symbol: str) -> str:
    return str(
        uuid.uuid5(
            DISPOSITION_NAMESPACE,
            f"{OWNER_DECISION_ID}|{ea_id}|{symbol}",
        )
    )


def build_plan(db: Path, census: Path, decision: Path) -> dict[str, Any]:
    approved, census_sha = read_bound_census(census)
    _decision_text, decision_sha = read_bound_decision(decision)
    conn = connect_ro(db)
    try:
        stranded = {
            (str(row["ea_id"]), str(row["symbol"]))
            for row in conn.execute(STRANDED_COHORT_SQL)
        }
        existing_decision_rows = int(
            conn.execute(
                "SELECT COUNT(*) FROM work_items "
                "WHERE json_extract(payload_json,?)=?",
                ("$.owner_decision_id", OWNER_DECISION_ID),
            ).fetchone()[0]
            or 0
        )
        if existing_decision_rows:
            raise Dead16Error(
                f"owner_decision_rows_already_exist:{existing_decision_rows}"
            )

        targets: list[dict[str, Any]] = []
        for census_row in approved:
            pair = (census_row["ea_id"], census_row["symbol"])
            if pair not in stranded:
                raise Dead16Error(f"approved_pair_not_currently_stranded:{pair[0]}:{pair[1]}")
            source = conn.execute(
                "SELECT * FROM work_items WHERE id=?",
                (census_row["terminal_work_item_id"],),
            ).fetchone()
            if source is None:
                raise Dead16Error(
                    f"census_source_missing:{census_row['terminal_work_item_id']}"
                )
            if (
                source["ea_id"] != pair[0]
                or source["symbol"] != pair[1]
                or str(source["phase"]).upper() not in {"Q02", "P2"}
                or source["status"] not in {"done", "failed"}
                or str(source["verdict"]).upper() != "INFRA_FAIL"
            ):
                raise Dead16Error(f"census_source_identity_drift:{source['id']}")
            payload_text = str(source["payload_json"] or "")
            target = {
                "ea_id": pair[0],
                "symbol": pair[1],
                "census_classification": census_row["classification"],
                "census_distinct_reasons": census_row["distinct_reasons"],
                "census_infra_fail_rows": int(census_row["infra_fail_rows"]),
                "census_current_repo_ex5_sha256": census_row[
                    "current_repo_ex5_sha256"
                ],
                "source_work_item_id": str(source["id"]),
                "source_status": str(source["status"]),
                "source_verdict": str(source["verdict"]),
                "source_payload_sha256": sha256_bytes(payload_text.encode("utf-8")),
                "source_evidence_path": source["evidence_path"],
                "kind": str(source["kind"]),
                "phase": str(source["phase"]),
                "setfile_path": str(source["setfile_path"]),
                "gate_contract_version": source["gate_contract_version"] or "legacy",
                "disposition_work_item_id": disposition_id(pair[0], pair[1]),
            }
            if conn.execute(
                "SELECT 1 FROM work_items WHERE id=?",
                (target["disposition_work_item_id"],),
            ).fetchone():
                raise Dead16Error(
                    "deterministic_disposition_id_already_exists:"
                    f"{target['disposition_work_item_id']}"
                )
            targets.append(target)
    finally:
        conn.close()

    plan = {
        "schema": PLAN_SCHEMA,
        "generated_at_utc": utc_now(),
        "database": str(db.resolve()),
        "task_id": TASK_ID,
        "owner_decision": {
            "id": OWNER_DECISION_ID,
            "path": str(decision.resolve()),
            "sha256": decision_sha,
        },
        "approved_census": {
            "path": str(census.resolve()),
            "sha256": census_sha,
            "total_rows": EXPECTED_CENSUS_ROWS,
            "dead_rows": EXPECTED_DISPOSITION_ROWS,
            "oninit_rows": EXPECTED_ONINIT_ROWS,
            "log_bomb_rows": EXPECTED_LOG_BOMB_ROWS,
        },
        "selection": {
            "cohort_sql": STRANDED_COHORT_SQL,
            "pair_count": len(targets),
        },
        "mutation": "APPEND_INVALID_DISPOSITION_ROWS_ONLY",
        "historical_verdict_rows_updated": 0,
        "targets": targets,
    }
    plan["targets_sha256"] = sha256_bytes(canonical_bytes(targets))
    return plan


def validate_plan_files(plan: dict[str, Any], census: Path, decision: Path) -> None:
    if plan.get("schema") != PLAN_SCHEMA:
        raise Dead16Error("unsupported_plan_schema")
    if plan.get("task_id") != TASK_ID:
        raise Dead16Error("wrong_router_task_id")
    if plan.get("owner_decision", {}).get("id") != OWNER_DECISION_ID:
        raise Dead16Error("wrong_owner_decision_id")
    targets = plan.get("targets") or []
    if len(targets) != EXPECTED_DISPOSITION_ROWS:
        raise Dead16Error("plan_is_not_exact_16_pair_scope")
    if sha256_bytes(canonical_bytes(targets)) != plan.get("targets_sha256"):
        raise Dead16Error("plan_target_hash_mismatch")
    _approved, census_sha = read_bound_census(census)
    _text, decision_sha = read_bound_decision(decision)
    if census_sha != plan.get("approved_census", {}).get("sha256"):
        raise Dead16Error("approved_census_hash_changed")
    if decision_sha != plan.get("owner_decision", {}).get("sha256"):
        raise Dead16Error("owner_decision_hash_changed")


def apply_plan(
    *,
    db: Path,
    census: Path,
    decision: Path,
    plan_path: Path,
    expected_plan_sha256: str,
    receipt_out: Path,
    backup_dir: Path,
    mutation_lock: Path,
) -> dict[str, Any]:
    if receipt_out.exists():
        raise Dead16Error(f"receipt_exists:{receipt_out}")
    actual_plan_sha = sha256_file(plan_path)
    if actual_plan_sha != expected_plan_sha256.lower():
        raise Dead16Error(
            f"plan_sha256_mismatch:{actual_plan_sha}!={expected_plan_sha256.lower()}"
        )
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    validate_plan_files(plan, census, decision)
    backup_path, backup_sha = backup_database(db, backup_dir)
    applied_at = utc_now()
    inserted: list[str] = []

    with FactoryMutationLock(
        mutation_lock,
        owner=f"apply_q02_dead16_dispositions:{TASK_ID}",
    ):
        conn = connect_rw(db)
        try:
            conn.execute("BEGIN IMMEDIATE")
            stranded_before = {
                (str(row["ea_id"]), str(row["symbol"]))
                for row in conn.execute(STRANDED_COHORT_SQL)
            }
            existing = int(
                conn.execute(
                    "SELECT COUNT(*) FROM work_items "
                    "WHERE json_extract(payload_json,?)=?",
                    ("$.owner_decision_id", OWNER_DECISION_ID),
                ).fetchone()[0]
                or 0
            )
            if existing:
                raise Dead16Error(f"owner_decision_rows_raced:{existing}")

            for target in plan["targets"]:
                pair = (target["ea_id"], target["symbol"])
                if pair not in stranded_before:
                    raise Dead16Error(
                        f"approved_pair_left_stranded_cohort:{pair[0]}:{pair[1]}"
                    )
                source = conn.execute(
                    "SELECT * FROM work_items WHERE id=?",
                    (target["source_work_item_id"],),
                ).fetchone()
                if source is None:
                    raise Dead16Error(f"source_row_vanished:{target['source_work_item_id']}")
                source_payload = str(source["payload_json"] or "")
                if sha256_bytes(source_payload.encode("utf-8")) != target[
                    "source_payload_sha256"
                ]:
                    raise Dead16Error(f"source_payload_drifted:{source['id']}")
                if (
                    source["ea_id"] != pair[0]
                    or source["symbol"] != pair[1]
                    or source["status"] != target["source_status"]
                    or source["verdict"] != target["source_verdict"]
                    or str(source["verdict"]).upper() != "INFRA_FAIL"
                ):
                    raise Dead16Error(f"source_terminal_identity_drifted:{source['id']}")
                if conn.execute(
                    "SELECT 1 FROM work_items WHERE id=?",
                    (target["disposition_work_item_id"],),
                ).fetchone():
                    raise Dead16Error(
                        "disposition_id_raced:"
                        f"{target['disposition_work_item_id']}"
                    )

            for target in plan["targets"]:
                failure_subclass = (
                    "ONINIT_FAILED_12_OF_12_IDENTICAL"
                    if target["census_classification"] == CLASS_ONINIT
                    else "LOG_BOMB_12_OF_12_IDENTICAL"
                )
                payload = {
                    "backtest_enqueued": False,
                    "census_classification": target["census_classification"],
                    "census_distinct_reasons": target["census_distinct_reasons"],
                    "census_infra_fail_rows": target["census_infra_fail_rows"],
                    "disposition_only": True,
                    "failure_class": "DETERMINISTIC_DEAD_Q02_PAIR",
                    "failure_subclass": failure_subclass,
                    "historical_infra_rows_preserved": True,
                    "owner_decision_id": OWNER_DECISION_ID,
                    "owner_decision_sha256": plan["owner_decision"]["sha256"],
                    "plan_sha256": expected_plan_sha256.lower(),
                    "router_task_id": TASK_ID,
                    "source_census_path": plan["approved_census"]["path"],
                    "source_census_sha256": plan["approved_census"]["sha256"],
                    "source_payload_sha256": target["source_payload_sha256"],
                    "source_work_item_id": target["source_work_item_id"],
                    "verdict_reason": "OWNER_APPROVED_Q02_DEAD16_INVALID",
                }
                evidence = target.get("source_evidence_path") or (
                    f"EVIDENCE_UNAVAILABLE:{OWNER_DECISION_ID}:"
                    f"{target['source_work_item_id']}"
                )
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
                        target["disposition_work_item_id"],
                        target["kind"],
                        target["phase"],
                        target["ea_id"],
                        target["symbol"],
                        target["setfile_path"],
                        evidence,
                        json.dumps(payload, sort_keys=True, separators=(",", ":")),
                        applied_at,
                        applied_at,
                        target["gate_contract_version"],
                    ),
                )
                conn.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                    "VALUES(?,'work_item',?,'owner_q02_dead16_invalid_appended',?)",
                    (
                        applied_at,
                        target["disposition_work_item_id"],
                        json.dumps(payload, sort_keys=True, separators=(",", ":")),
                    ),
                )
                inserted.append(target["disposition_work_item_id"])

            readback = int(
                conn.execute(
                    "SELECT COUNT(*) FROM work_items "
                    "WHERE json_extract(payload_json,?)=? "
                    "AND json_extract(payload_json,?)=1 "
                    "AND status='failed' AND verdict='INVALID'",
                    (
                        "$.owner_decision_id",
                        OWNER_DECISION_ID,
                        "$.disposition_only",
                    ),
                ).fetchone()[0]
                or 0
            )
            if readback != EXPECTED_DISPOSITION_ROWS:
                raise Dead16Error(f"precommit_readback_count:{readback}")
            event_count = int(
                conn.execute(
                    "SELECT COUNT(*) FROM events WHERE event=? "
                    "AND entity_id IN ("
                    + ",".join(["?"] * len(inserted))
                    + ")",
                    ["owner_q02_dead16_invalid_appended", *inserted],
                ).fetchone()[0]
                or 0
            )
            if event_count != EXPECTED_DISPOSITION_ROWS:
                raise Dead16Error(f"precommit_event_count:{event_count}")
            stranded_after = {
                (str(row["ea_id"]), str(row["symbol"]))
                for row in conn.execute(STRANDED_COHORT_SQL)
            }
            if len(stranded_before) - len(stranded_after) != EXPECTED_DISPOSITION_ROWS:
                raise Dead16Error(
                    "precommit_health_delta:"
                    f"{len(stranded_before)}->{len(stranded_after)}"
                )
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
        finally:
            conn.close()

    check = connect_ro(db)
    try:
        quick_check = str(check.execute("PRAGMA quick_check").fetchone()[0])
        source_rows_preserved = 0
        for target in plan["targets"]:
            source = check.execute(
                "SELECT status,verdict,payload_json FROM work_items WHERE id=?",
                (target["source_work_item_id"],),
            ).fetchone()
            if (
                source
                and source["status"] == target["source_status"]
                and source["verdict"] == target["source_verdict"]
                and sha256_bytes(str(source["payload_json"] or "").encode("utf-8"))
                == target["source_payload_sha256"]
            ):
                source_rows_preserved += 1
    finally:
        check.close()

    receipt = {
        "schema": RECEIPT_SCHEMA,
        "applied_at_utc": applied_at,
        "database": str(db.resolve()),
        "task_id": TASK_ID,
        "owner_decision_id": OWNER_DECISION_ID,
        "plan_path": str(plan_path.resolve()),
        "plan_sha256": expected_plan_sha256.lower(),
        "inserted_count": len(inserted),
        "inserted_work_item_ids": inserted,
        "historical_verdict_rows_updated": 0,
        "source_rows_preserved": source_rows_preserved,
        "health_count_before": len(stranded_before),
        "health_count_after": len(stranded_after),
        "health_count_delta": len(stranded_after) - len(stranded_before),
        "quick_check": quick_check,
        "backup": {"path": str(backup_path), "sha256": backup_sha},
        "rollback": (
            "append an OWNER-authorized superseding disposition; never update "
            "or delete source/disposition history"
        ),
    }
    receipt_sha = write_new_json(receipt_out, receipt)
    return {
        **receipt,
        "receipt_path": str(receipt_out.resolve()),
        "receipt_sha256": receipt_sha,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--census", type=Path, default=DEFAULT_CENSUS)
    parser.add_argument("--decision", type=Path, default=DEFAULT_DECISION)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_MUTATION_LOCK)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--apply", action="store_true")
    parser.add_argument("--plan-out", type=Path)
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--expected-plan-sha256")
    parser.add_argument("--receipt-out", type=Path)
    args = parser.parse_args(argv)

    try:
        if args.apply:
            if not args.plan or not args.expected_plan_sha256 or not args.receipt_out:
                raise Dead16Error(
                    "--apply requires --plan, --expected-plan-sha256, and --receipt-out"
                )
            result = apply_plan(
                db=args.db,
                census=args.census,
                decision=args.decision,
                plan_path=args.plan,
                expected_plan_sha256=args.expected_plan_sha256,
                receipt_out=args.receipt_out,
                backup_dir=args.backup_dir,
                mutation_lock=args.mutation_lock,
            )
            output = {**result, "status": "ok", "mode": "apply"}
        else:
            if not args.plan_out:
                raise Dead16Error("dry-run requires --plan-out")
            plan = build_plan(args.db, args.census, args.decision)
            plan_sha = write_new_json(args.plan_out, plan)
            output = {
                "status": "ok",
                "mode": "dry_run",
                "schema": plan["schema"],
                "pair_count": len(plan["targets"]),
                "oninit_count": sum(
                    target["census_classification"] == CLASS_ONINIT
                    for target in plan["targets"]
                ),
                "log_bomb_count": sum(
                    target["census_classification"] == CLASS_LOG_BOMB
                    for target in plan["targets"]
                ),
                "historical_verdict_rows_updated": 0,
                "plan_path": str(args.plan_out.resolve()),
                "plan_sha256": plan_sha,
                "targets_sha256": plan["targets_sha256"],
            }
        print(json.dumps(output, indent=2, sort_keys=True))
        return 0
    except (Dead16Error, OSError, sqlite3.Error, ValueError, json.JSONDecodeError) as exc:
        print(
            json.dumps(
                {
                    "status": "aborted",
                    "reason": f"{type(exc).__name__}: {exc}",
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
