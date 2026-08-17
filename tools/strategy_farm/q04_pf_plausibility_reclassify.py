#!/usr/bin/env python3
"""Hash-bound reclassification of Q04 PASS rows with unusable PF evidence.

``plan`` is read-only.  It requires an exact expected work-item ID set and
captures every row preimage plus the stored aggregate hash.  ``apply`` requires
the plan hash, holds the Factory mutation lock, creates an online SQLite backup,
uses compare-and-swap updates, and appends transition/event audit rows.  It
never enqueues or reruns work and never mutates downstream Q10/book records.
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

from framework.scripts import q04_walkforward as q04  # noqa: E402
from factory_mutation_lock import FactoryMutationLock  # noqa: E402


PLAN_SCHEMA = "qm.q04-pf-plausibility-reclassification-plan/v1"
RECEIPT_SCHEMA = "qm.q04-pf-plausibility-reclassification-receipt/v1"
HISTORY_SCHEMA = "qm.q04-pf-plausibility-reclassification/v1"
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
) -> list[sqlite3.Row]:
    if not expected_ids:
        raise ReclassificationError("at least one exact expected ID is required")
    placeholders = ",".join("?" for _ in expected_ids)
    rows = conn.execute(
        f"SELECT {', '.join(WORK_ITEM_COLUMNS)} FROM work_items "
        f"WHERE id IN ({placeholders}) ORDER BY id",  # noqa: S608 -- placeholders only
        tuple(sorted(expected_ids)),
    ).fetchall()
    actual = {str(row["id"]) for row in rows}
    if actual != expected_ids:
        raise ReclassificationError(
            f"exact target mismatch: expected={sorted(expected_ids)} actual={sorted(actual)}"
        )
    return rows


def _load_aggregate(row: sqlite3.Row) -> tuple[Path, dict[str, Any]] | None:
    raw_path = str(row["evidence_path"] or "").strip()
    path = Path(raw_path) if raw_path else Path("__missing_q04_evidence__")
    if not path.is_file():
        return None
    try:
        aggregate = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ReclassificationError(f"unreadable evidence for {row['id']}: {exc}") from exc
    if not isinstance(aggregate, dict):
        raise ReclassificationError(f"aggregate is not an object: {path}")
    if str(aggregate.get("phase") or "").upper() != "Q04":
        raise ReclassificationError(f"non-Q04 evidence for {row['id']}: {path}")
    evidence_key = str(aggregate.get("evidence_key") or "")
    if evidence_key and evidence_key != str(row["id"]):
        raise ReclassificationError(
            f"evidence key mismatch for {row['id']}: {evidence_key}"
        )
    return path, aggregate


def _unusable_fold_issues(aggregate: dict[str, Any]) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    folds = aggregate.get("folds")
    if not isinstance(folds, list) or not folds:
        return issues
    for fold in folds:
        if not isinstance(fold, dict):
            continue
        issue = q04.pf_measurement_issue(
            fold.get("pf_net"), int(fold.get("trades") or 0)
        )
        if issue:
            issues.append({
                "fold": str(fold.get("id") or "?"),
                "pf_net": fold.get("pf_net"),
                "trades": int(fold.get("trades") or 0),
                "issue": issue,
            })
    return issues


def build_plan(
    db: Path,
    *,
    expected_ids: Iterable[str],
    authority_task_id: str,
    evidence_doc: str,
    planned_at_utc: str | None = None,
) -> dict[str, Any]:
    expected = {str(item).strip() for item in expected_ids if str(item).strip()}
    if not authority_task_id.strip() or not evidence_doc.strip():
        raise ReclassificationError("authority task ID and evidence doc are required")
    planned_at = planned_at_utc or utc_now()
    plan_rows: list[dict[str, Any]] = []
    with _connect(db, read_only=True) as conn:
        rows = _select_exact_rows(conn, expected)
        for row in rows:
            if row["phase"] != "Q04" or row["status"] != "done":
                raise ReclassificationError(
                    f"target {row['id']} is not a completed Q04 row: "
                    f"{row['phase']}/{row['status']}"
                )
            if row["verdict"] != "PASS" or row["claimed_by"] is not None:
                raise ReclassificationError(
                    f"target {row['id']} is not an unclaimed PASS: "
                    f"{row['verdict']}/{row['claimed_by']}"
                )
            payload = _payload(str(row["payload_json"] or "{}"))
            loaded = _load_aggregate(row)
            if loaded is None:
                if (
                    payload.get("promotion_source") != "pump_q04_early_probe"
                    or payload.get("q04_default_probe") is not True
                    or "pf_net=999.000" not in str(payload.get("verdict_reason") or "")
                ):
                    raise ReclassificationError(
                        f"missing evidence target is not the authenticated Q04 probe class: {row['id']}"
                    )
                evidence_path = str(row["evidence_path"] or "")
                evidence_sha = None
                issues: list[dict[str, Any]] = []
                to_verdict = "INFRA_FAIL"
                reason = f"q04_probe_evidence_missing:{evidence_path or '<unset>'}"
                taxonomy = "infra"
            else:
                evidence_file, aggregate = loaded
                issues = _unusable_fold_issues(aggregate)
                if not issues:
                    raise ReclassificationError(
                        f"target {row['id']} has no unusable PF measurement"
                    )
                evidence_path = str(evidence_file)
                evidence_sha = sha256_file(evidence_file)
                to_verdict = "FAIL"
                reason = "q04_unusable_pf_measurement:" + ",".join(
                    f"{entry['fold']}:{entry['issue']}" for entry in issues
                )
                taxonomy = "strategy"

            history = list(payload.get("q04_pf_plausibility_reclassifications") or [])
            history.append({
                "schema": HISTORY_SCHEMA,
                "authority_task_id": authority_task_id,
                "evidence_doc": evidence_doc,
                "from_verdict": row["verdict"],
                "to_verdict": to_verdict,
                "reason": reason,
                "reclassified_at_utc": planned_at,
            })
            payload["q04_pf_plausibility_reclassifications"] = history
            payload["verdict_reason"] = reason
            payload["verdict_taxonomy"] = taxonomy
            target_payload = json.dumps(payload, sort_keys=True, separators=(",", ":"))
            plan_rows.append({
                "id": row["id"],
                "ea_id": row["ea_id"],
                "symbol": row["symbol"],
                "from_status": row["status"],
                "to_status": row["status"],
                "from_verdict": row["verdict"],
                "to_verdict": to_verdict,
                "reason": reason,
                "pf_issues": issues,
                "evidence_path": evidence_path,
                "evidence_exists": loaded is not None,
                "evidence_sha256": evidence_sha,
                "preimage_state_sha256": _row_state_sha256(row),
                "preimage_payload_sha256": sha256_bytes(
                    str(row["payload_json"]).encode("utf-8")
                ),
                "target_payload_json": target_payload,
                "target_payload_sha256": sha256_bytes(target_payload.encode("utf-8")),
                "target_updated_at": planned_at,
            })

    return {
        "schema": PLAN_SCHEMA,
        "planned_at_utc": planned_at,
        "authority_task_id": authority_task_id,
        "operation": "Q04_PASS_UNUSABLE_PF_RECLASSIFICATION",
        "database": str(db.resolve()),
        "evidence_doc": evidence_doc,
        "selection": {
            "expected_ids": sorted(expected),
            "expected_count": len(expected),
            "old_verdict": "PASS",
            "phase": "Q04",
        },
        "guard": {
            "pf_ceiling": q04.Q04_LOWFREQ_PF_PLAUSIBILITY_CEILING,
            "lowfreq_max_trades_per_year": q04.Q04_LOWFREQ_MAX_TRADES_PER_YEAR,
            "no_measurement_sentinels": sorted(q04.Q04_PF_NO_MEASUREMENT_SENTINELS),
        },
        "invariants": [
            "exact target ID set is required",
            "every target is a completed unclaimed Q04 PASS",
            "stored aggregates are hash-bound where present",
            "missing evidence is accepted only for the authenticated early-probe 999 sentinel class",
            "raw evidence, Q10 rows, and live roster records are not mutated",
            "no work item is enqueued, claimed, cancelled, or rerun",
        ],
        "rows": plan_rows,
    }


def plan_sha256(plan: dict[str, Any]) -> str:
    return sha256_bytes(pretty_json_bytes(plan))


def _backup_database(source: Path, backup_dir: Path, *, stamp: str) -> Path:
    backup_dir.mkdir(parents=True, exist_ok=True)
    safe_stamp = re.sub(r"[^0-9]", "", stamp)[:14]
    destination = backup_dir / f"farm_state_before_q04_pf_guard_{safe_stamp}Z.sqlite"
    if destination.exists():
        raise ReclassificationError(f"backup destination exists: {destination}")
    with sqlite3.connect(source) as source_conn, sqlite3.connect(destination) as backup_conn:
        source_conn.backup(backup_conn)
    with sqlite3.connect(destination) as check_conn:
        result = str(check_conn.execute("PRAGMA quick_check").fetchone()[0])
    if result.casefold() != "ok":
        raise ReclassificationError(f"backup quick_check failed: {result}")
    return destination


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
    targets = {str(row["id"]): dict(row) for row in plan["rows"]}
    if set(targets) != expected:
        raise ReclassificationError("plan rows do not equal exact expected target set")

    with FactoryMutationLock(mutation_lock, owner="q04_pf_plausibility_reclassify.apply"):
        backup = _backup_database(db, backup_dir, stamp=str(plan["planned_at_utc"]))
        conn = _connect(db, read_only=False)
        try:
            conn.execute("BEGIN IMMEDIATE")
            current_rows = _select_exact_rows(conn, expected)
            for row in current_rows:
                target = targets[str(row["id"])]
                if _row_state_sha256(row) != target["preimage_state_sha256"]:
                    raise ReclassificationError(f"row preimage drift: {row['id']}")
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
                }
                conn.execute(
                    "INSERT INTO work_item_transition_ledger "
                    "(idempotency_key,ts,work_item_id,action,from_status,to_status,"
                    "from_verdict,to_verdict,from_claimed_by,to_claimed_by,reason,run_id,detail_json) "
                    "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    (
                        f"q04-pf-plausibility:{plan['authority_task_id']}:{row['id']}",
                        plan["planned_at_utc"], row["id"],
                        "reclassify_q04_unusable_pf", row["status"], row["status"],
                        row["verdict"], target["to_verdict"], row["claimed_by"],
                        row["claimed_by"], target["reason"], plan["authority_task_id"],
                        json.dumps(detail, sort_keys=True, separators=(",", ":")),
                    ),
                )
                conn.execute(
                    "INSERT INTO events (ts,entity_type,entity_id,event,detail_json) "
                    "VALUES (?,?,?,?,?)",
                    (
                        plan["planned_at_utc"], "work_item", row["id"],
                        "q04_unusable_pf_reclassified",
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
        after_rows = _select_exact_rows(conn, expected)
        after = []
        for row in after_rows:
            target = targets[str(row["id"])]
            if row["verdict"] != target["to_verdict"]:
                raise ReclassificationError(f"post-apply verdict mismatch: {row['id']}")
            after.append({
                "id": row["id"], "ea_id": row["ea_id"], "symbol": row["symbol"],
                "status": row["status"], "verdict": row["verdict"],
                "updated_at": row["updated_at"],
                "payload_sha256": sha256_bytes(str(row["payload_json"]).encode("utf-8")),
            })
    return {
        "schema": RECEIPT_SCHEMA,
        "applied_at_utc": utc_now(),
        "authority_task_id": plan["authority_task_id"],
        "plan_sha256": actual_plan_sha,
        "database": str(db.resolve()),
        "backup_path": str(backup.resolve()),
        "backup_sha256": sha256_file(backup),
        "selection": plan["selection"],
        "rows": after,
        "raw_evidence_mutated": False,
        "downstream_q10_or_live_roster_rows_mutated": 0,
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
