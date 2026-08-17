#!/usr/bin/env python3
"""Hash-bound correction for Q07 zero-seed-outlier work-item verdicts.

``plan`` is read-only. It binds exact target and preservation row sets to their
SQLite preimages and raw aggregate hashes. ``apply`` requires the plan hash,
holds the Factory mutation lock, takes an online backup, uses compare-and-swap,
and appends transition/event audit records. It never edits raw evidence or
enqueues a rerun.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import sys
from typing import Any, Iterable


_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parents[1]
for _path in (_REPO, _HERE):
    if str(_path) not in sys.path:
        sys.path.insert(0, str(_path))

from framework.scripts import q07_multiseed as q07  # noqa: E402
from factory_mutation_lock import FactoryMutationLock  # noqa: E402


PLAN_SCHEMA = "qm.q07-zero-seed-outlier-reclassification-plan/v1"
RECEIPT_SCHEMA = "qm.q07-zero-seed-outlier-reclassification-receipt/v1"
HISTORY_SCHEMA = "qm.q07-zero-seed-outlier-reclassification/v1"
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
DEFAULT_MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
WORK_ITEM_COLUMNS = (
    "id", "kind", "phase", "ea_id", "symbol", "setfile_path", "status",
    "verdict", "attempt_count", "parent_task_id", "evidence_path",
    "claimed_by", "payload_json", "created_at", "updated_at",
)


class ReclassificationError(RuntimeError):
    """Fail-closed target, evidence, preimage, backup, or audit error."""


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def pretty_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def _connect(path: Path, *, read_only: bool) -> sqlite3.Connection:
    if not path.is_file():
        raise ReclassificationError(f"database not found: {path}")
    if read_only:
        conn = sqlite3.connect(f"file:{path.resolve().as_posix()}?mode=ro", uri=True)
    else:
        conn = sqlite3.connect(path, timeout=30.0)
    conn.row_factory = sqlite3.Row
    return conn


def _payload(raw: str) -> dict[str, Any]:
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ReclassificationError(f"invalid payload_json: {exc}") from exc
    if not isinstance(value, dict):
        raise ReclassificationError("payload_json is not an object")
    return value


def _row_snapshot(row: sqlite3.Row) -> dict[str, Any]:
    return {column: row[column] for column in WORK_ITEM_COLUMNS}


def _row_state_sha256(row: sqlite3.Row) -> str:
    return sha256_bytes(canonical_json_bytes(_row_snapshot(row)))


def _select_exact_rows(
    conn: sqlite3.Connection,
    expected_ids: set[str],
    *,
    label: str,
) -> list[sqlite3.Row]:
    if not expected_ids:
        raise ReclassificationError(f"at least one exact {label} ID is required")
    placeholders = ",".join("?" for _ in expected_ids)
    rows = conn.execute(
        f"SELECT {', '.join(WORK_ITEM_COLUMNS)} FROM work_items "
        f"WHERE id IN ({placeholders}) ORDER BY id",  # noqa: S608 -- placeholders only
        tuple(sorted(expected_ids)),
    ).fetchall()
    actual = {str(row["id"]) for row in rows}
    if actual != expected_ids:
        raise ReclassificationError(
            f"exact {label} mismatch: expected={sorted(expected_ids)} actual={sorted(actual)}"
        )
    return rows


def _load_q07_aggregate(row: sqlite3.Row) -> tuple[Path, dict[str, Any]]:
    raw_path = str(row["evidence_path"] or "").strip()
    if not raw_path:
        raise ReclassificationError(f"target {row['id']} has no evidence path")
    path = Path(raw_path)
    if not path.is_file():
        raise ReclassificationError(f"evidence missing for {row['id']}: {path}")
    try:
        aggregate = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ReclassificationError(f"unreadable evidence for {row['id']}: {exc}") from exc
    if not isinstance(aggregate, dict):
        raise ReclassificationError(f"aggregate is not an object: {path}")
    if str(aggregate.get("phase") or "").upper() != "Q07":
        raise ReclassificationError(f"non-Q07 evidence for {row['id']}: {path}")
    aggregate_ea = str(aggregate.get("ea_id") or "")
    if aggregate_ea.isdigit():
        aggregate_ea = f"QM5_{aggregate_ea}"
    if aggregate_ea != str(row["ea_id"]):
        raise ReclassificationError(
            f"aggregate EA mismatch for {row['id']}: {aggregate_ea!r}"
        )
    if str(aggregate.get("symbol") or "") != str(row["symbol"]):
        raise ReclassificationError(
            f"aggregate symbol mismatch for {row['id']}: {aggregate.get('symbol')!r}"
        )
    details = aggregate.get("per_seed_detail")
    if not isinstance(details, list) or not details:
        raise ReclassificationError(f"aggregate has no per_seed_detail: {path}")
    return path, aggregate


def _derive_zero_outlier(aggregate: dict[str, Any]) -> tuple[str, str, dict[str, Any]]:
    verdict, reason, metrics = q07.evaluate_seeds(aggregate["per_seed_detail"])
    if verdict != "INVALID" or not reason.startswith("seed_zero_trades_outlier:"):
        raise ReclassificationError(
            f"stored evidence does not derive the zero-seed-outlier class: {verdict}/{reason}"
        )
    return verdict, reason, metrics


def _preservation_snapshot(row: sqlite3.Row) -> dict[str, Any]:
    if row["phase"] != "Q07" or row["status"] != "done":
        raise ReclassificationError(
            f"preservation row {row['id']} is not completed Q07: "
            f"{row['phase']}/{row['status']}"
        )
    evidence_path, aggregate = _load_q07_aggregate(row)
    if str(aggregate.get("verdict") or "").upper() != "INVALID":
        raise ReclassificationError(
            f"preservation row {row['id']} aggregate is not INVALID"
        )
    trades = [int(item.get("trades") or 0) for item in aggregate["per_seed_detail"]]
    if 0 not in trades:
        raise ReclassificationError(
            f"preservation row {row['id']} has no zero-trade seed"
        )
    return {
        "id": row["id"],
        "ea_id": row["ea_id"],
        "symbol": row["symbol"],
        "status": row["status"],
        "verdict": row["verdict"],
        "updated_at": row["updated_at"],
        "trade_counts": trades,
        "evidence_path": str(evidence_path),
        "evidence_sha256": sha256_file(evidence_path),
        "preimage_state_sha256": _row_state_sha256(row),
    }


def build_plan(
    db: Path,
    *,
    expected_ids: Iterable[str],
    preserve_ids: Iterable[str],
    authority_task_id: str,
    evidence_doc: str,
    planned_at_utc: str | None = None,
) -> dict[str, Any]:
    expected = {str(item).strip() for item in expected_ids if str(item).strip()}
    preserved = {str(item).strip() for item in preserve_ids if str(item).strip()}
    if expected & preserved:
        raise ReclassificationError("target and preservation ID sets overlap")
    if not authority_task_id.strip() or not evidence_doc.strip():
        raise ReclassificationError("authority task ID and evidence doc are required")
    planned_at = planned_at_utc or utc_now()
    plan_rows: list[dict[str, Any]] = []
    with _connect(db, read_only=True) as conn:
        rows = _select_exact_rows(conn, expected, label="target")
        preservation_rows = _select_exact_rows(conn, preserved, label="preservation")
        for row in rows:
            if row["phase"] != "Q07" or row["status"] != "done":
                raise ReclassificationError(
                    f"target {row['id']} is not completed Q07: "
                    f"{row['phase']}/{row['status']}"
                )
            if row["verdict"] != "FAIL" or row["claimed_by"] is not None:
                raise ReclassificationError(
                    f"target {row['id']} is not an unclaimed FAIL: "
                    f"{row['verdict']}/{row['claimed_by']}"
                )
            payload = _payload(str(row["payload_json"] or "{}"))
            evidence_path, aggregate = _load_q07_aggregate(row)
            aggregate_verdict, reason, metrics = _derive_zero_outlier(aggregate)
            history = list(payload.get("q07_zero_seed_outlier_reclassifications") or [])
            history.append({
                "schema": HISTORY_SCHEMA,
                "authority_task_id": authority_task_id,
                "evidence_doc": evidence_doc,
                "from_verdict": row["verdict"],
                "to_verdict": "INFRA_FAIL",
                "aggregate_verdict": aggregate_verdict,
                "reason": reason,
                "reclassified_at_utc": planned_at,
                "rerun_performed": False,
            })
            payload["q07_zero_seed_outlier_reclassifications"] = history
            payload["verdict_reason"] = reason
            payload["verdict_taxonomy"] = "infra"
            target_payload = json.dumps(payload, sort_keys=True, separators=(",", ":"))
            plan_rows.append({
                "id": row["id"],
                "ea_id": row["ea_id"],
                "symbol": row["symbol"],
                "from_status": row["status"],
                "to_status": row["status"],
                "from_verdict": row["verdict"],
                "to_verdict": "INFRA_FAIL",
                "aggregate_verdict": aggregate_verdict,
                "reason": reason,
                "derived_metrics": metrics,
                "evidence_path": str(evidence_path),
                "evidence_sha256": sha256_file(evidence_path),
                "preimage_state_sha256": _row_state_sha256(row),
                "preimage_payload_sha256": sha256_bytes(
                    str(row["payload_json"]).encode("utf-8")
                ),
                "target_payload_json": target_payload,
                "target_payload_sha256": sha256_bytes(target_payload.encode("utf-8")),
                "target_updated_at": planned_at,
            })

        preserve_snapshots = [
            _preservation_snapshot(row) for row in preservation_rows
        ]

    return {
        "schema": PLAN_SCHEMA,
        "planned_at_utc": planned_at,
        "authority_task_id": authority_task_id,
        "operation": "Q07_ZERO_SEED_OUTLIER_RECLASSIFICATION",
        "database": str(db.resolve()),
        "evidence_doc": evidence_doc,
        "selection": {
            "expected_ids": sorted(expected),
            "expected_count": len(expected),
            "preserve_ids": sorted(preserved),
            "preserve_count": len(preserved),
            "phase": "Q07",
        },
        "predicate": {
            "candidate_trade_count": 0,
            "sibling_cohort_median_min": q07.MIN_TRADES,
            "description": (
                "a zero-trade seed is suspect only when the median across its "
                "seed cohort is at or above the Q07 trade floor"
            ),
        },
        "invariants": [
            "exact target and preservation ID sets are required and disjoint",
            "every target is a completed unclaimed Q07 FAIL",
            "every target derives aggregate INVALID/seed_zero_trades_outlier",
            "preservation rows retain their exact SQLite preimages",
            "all stored aggregates are hash-bound and never mutated",
            "no work item is enqueued, claimed, cancelled, or rerun",
        ],
        "rows": plan_rows,
        "preserved_rows": preserve_snapshots,
    }


def plan_sha256(plan: dict[str, Any]) -> str:
    return sha256_bytes(pretty_json_bytes(plan))


def _backup_database(source: Path, backup_dir: Path, *, stamp: str) -> Path:
    backup_dir.mkdir(parents=True, exist_ok=True)
    safe_stamp = re.sub(r"[^0-9]", "", stamp)[:14]
    destination = backup_dir / f"farm_state_before_q07_zero_seed_guard_{safe_stamp}Z.sqlite"
    if destination.exists():
        raise ReclassificationError(f"backup destination exists: {destination}")
    with sqlite3.connect(source) as source_conn, sqlite3.connect(destination) as backup_conn:
        source_conn.backup(backup_conn)
    with sqlite3.connect(destination) as check_conn:
        result = str(check_conn.execute("PRAGMA quick_check").fetchone()[0])
    if result.casefold() != "ok":
        raise ReclassificationError(f"backup quick_check failed: {result}")
    return destination


def _verify_evidence_hash(entry: dict[str, Any]) -> None:
    path = Path(str(entry["evidence_path"]))
    if not path.is_file() or sha256_file(path) != entry["evidence_sha256"]:
        raise ReclassificationError(f"evidence hash drift: {entry['id']}")


def apply_plan(
    plan: dict[str, Any],
    *,
    expected_plan_sha256: str,
    db: Path,
    backup_dir: Path,
    mutation_lock: Path,
) -> dict[str, Any]:
    actual_plan_sha = plan_sha256(plan)
    if actual_plan_sha != expected_plan_sha256.casefold():
        raise ReclassificationError(
            f"plan SHA mismatch: expected={expected_plan_sha256} actual={actual_plan_sha}"
        )
    if plan.get("schema") != PLAN_SCHEMA:
        raise ReclassificationError(f"unsupported plan schema: {plan.get('schema')!r}")
    if Path(str(plan.get("database"))).resolve() != db.resolve():
        raise ReclassificationError("apply database does not match plan")
    expected = set(plan["selection"]["expected_ids"])
    preserved = set(plan["selection"]["preserve_ids"])
    targets = {str(row["id"]): dict(row) for row in plan["rows"]}
    preservation = {
        str(row["id"]): dict(row) for row in plan["preserved_rows"]
    }
    if set(targets) != expected or set(preservation) != preserved:
        raise ReclassificationError("plan rows do not equal exact selected ID sets")

    with FactoryMutationLock(
        mutation_lock,
        owner="q07_zero_seed_outlier_reclassify.apply",
    ):
        backup = _backup_database(db, backup_dir, stamp=str(plan["planned_at_utc"]))
        conn = _connect(db, read_only=False)
        try:
            conn.execute("BEGIN IMMEDIATE")
            current_rows = _select_exact_rows(conn, expected, label="target")
            current_preserved = _select_exact_rows(
                conn, preserved, label="preservation"
            )
            for row in current_preserved:
                entry = preservation[str(row["id"])]
                if _row_state_sha256(row) != entry["preimage_state_sha256"]:
                    raise ReclassificationError(
                        f"preservation row preimage drift: {row['id']}"
                    )
                _verify_evidence_hash(entry)

            for row in current_rows:
                target = targets[str(row["id"])]
                if _row_state_sha256(row) != target["preimage_state_sha256"]:
                    raise ReclassificationError(f"row preimage drift: {row['id']}")
                _verify_evidence_hash(target)
                cursor = conn.execute(
                    "UPDATE work_items SET verdict=?, payload_json=?, updated_at=? "
                    "WHERE id=? AND status=? AND verdict IS ? AND payload_json=? AND updated_at=?",
                    (
                        target["to_verdict"], target["target_payload_json"],
                        target["target_updated_at"], row["id"], target["from_status"],
                        target["from_verdict"], row["payload_json"], row["updated_at"],
                    ),
                )
                if cursor.rowcount != 1:
                    raise ReclassificationError(f"compare-and-swap failed: {row['id']}")
                detail = {
                    "schema": HISTORY_SCHEMA,
                    "authority_task_id": plan["authority_task_id"],
                    "evidence_doc": plan["evidence_doc"],
                    "plan_sha256": actual_plan_sha,
                    "preimage_state_sha256": target["preimage_state_sha256"],
                    "target_payload_sha256": target["target_payload_sha256"],
                    "raw_evidence_sha256": target["evidence_sha256"],
                    "aggregate_verdict": target["aggregate_verdict"],
                    "rerun_performed": False,
                }
                conn.execute(
                    "INSERT INTO work_item_transition_ledger "
                    "(idempotency_key,ts,work_item_id,action,from_status,to_status,"
                    "from_verdict,to_verdict,from_claimed_by,to_claimed_by,reason,run_id,detail_json) "
                    "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    (
                        f"q07-zero-seed-outlier:{plan['authority_task_id']}:{row['id']}",
                        plan["planned_at_utc"], row["id"],
                        "reclassify_q07_zero_seed_outlier",
                        row["status"], row["status"], row["verdict"],
                        target["to_verdict"], row["claimed_by"], row["claimed_by"],
                        target["reason"], plan["authority_task_id"],
                        json.dumps(detail, sort_keys=True, separators=(",", ":")),
                    ),
                )
                conn.execute(
                    "INSERT INTO events (ts,entity_type,entity_id,event,detail_json) "
                    "VALUES (?,?,?,?,?)",
                    (
                        plan["planned_at_utc"], "work_item", row["id"],
                        "q07_zero_seed_outlier_reclassified",
                        json.dumps(detail, sort_keys=True, separators=(",", ":")),
                    ),
                )
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    with _connect(db, read_only=True) as conn:
        after_rows = _select_exact_rows(conn, expected, label="target")
        after_preserved = _select_exact_rows(conn, preserved, label="preservation")
        after = []
        for row in after_rows:
            target = targets[str(row["id"])]
            if row["verdict"] != target["to_verdict"]:
                raise ReclassificationError(f"post-apply verdict mismatch: {row['id']}")
            _verify_evidence_hash(target)
            after.append({
                "id": row["id"], "ea_id": row["ea_id"], "symbol": row["symbol"],
                "status": row["status"], "verdict": row["verdict"],
                "updated_at": row["updated_at"],
                "payload_sha256": sha256_bytes(str(row["payload_json"]).encode("utf-8")),
            })
        preserved_after = []
        for row in after_preserved:
            entry = preservation[str(row["id"])]
            if _row_state_sha256(row) != entry["preimage_state_sha256"]:
                raise ReclassificationError(
                    f"preservation row changed during apply: {row['id']}"
                )
            _verify_evidence_hash(entry)
            preserved_after.append({
                "id": row["id"], "ea_id": row["ea_id"], "symbol": row["symbol"],
                "status": row["status"], "verdict": row["verdict"],
                "updated_at": row["updated_at"],
                "state_sha256": _row_state_sha256(row),
                "evidence_sha256": entry["evidence_sha256"],
            })
        quick_check = str(conn.execute("PRAGMA quick_check").fetchone()[0])
    if quick_check.casefold() != "ok":
        raise ReclassificationError(f"live database quick_check failed: {quick_check}")

    return {
        "schema": RECEIPT_SCHEMA,
        "applied_at_utc": utc_now(),
        "authority_task_id": plan["authority_task_id"],
        "plan_sha256": actual_plan_sha,
        "database": str(db.resolve()),
        "backup_path": str(backup.resolve()),
        "backup_sha256": sha256_file(backup),
        "database_quick_check": quick_check,
        "selection": plan["selection"],
        "rows": after,
        "preserved_rows": preserved_after,
        "raw_evidence_mutated": False,
        "preservation_rows_mutated": 0,
        "work_items_enqueued_or_rerun": 0,
    }


def _read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ReclassificationError(f"JSON root is not an object: {path}")
    return value


def _emit(value: dict[str, Any], output: Path | None) -> None:
    raw = pretty_json_bytes(value)
    if output is None:
        sys.stdout.buffer.write(raw)
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(raw)
        print(json.dumps({"output": str(output.resolve()), "sha256": sha256_file(output)}))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    plan_parser = sub.add_parser("plan")
    plan_parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    plan_parser.add_argument("--expected-id", action="append", required=True)
    plan_parser.add_argument("--preserve-id", action="append", required=True)
    plan_parser.add_argument("--authority-task-id", required=True)
    plan_parser.add_argument("--evidence-doc", required=True)
    plan_parser.add_argument("--planned-at-utc")
    plan_parser.add_argument("--out", type=Path)
    apply_parser = sub.add_parser("apply")
    apply_parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    apply_parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    apply_parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_MUTATION_LOCK)
    apply_parser.add_argument("--plan", type=Path, required=True)
    apply_parser.add_argument("--expect-plan-sha256", required=True)
    apply_parser.add_argument("--receipt-out", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "plan":
            value = build_plan(
                args.db,
                expected_ids=args.expected_id,
                preserve_ids=args.preserve_id,
                authority_task_id=args.authority_task_id,
                evidence_doc=args.evidence_doc,
                planned_at_utc=args.planned_at_utc,
            )
            _emit(value, args.out)
            return 0
        value = apply_plan(
            _read_json(args.plan),
            expected_plan_sha256=args.expect_plan_sha256,
            db=args.db,
            backup_dir=args.backup_dir,
            mutation_lock=args.mutation_lock,
        )
        _emit(value, args.receipt_out)
        return 0
    except (ReclassificationError, OSError, sqlite3.Error) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
