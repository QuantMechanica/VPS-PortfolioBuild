#!/usr/bin/env python3
"""Park (79) + retire (223) the July-cohort Q02/Q04 zombie queue rows.

Executes the CEO-approved classification pass
(``docs/ops/evidence/2026-09-02_2093b38e_july_cohort_zombie_queue_disposition.md``,
router task ``2093b38e-8eb4-4bcd-931b-25c50ada861f``) under router task
``c9a1bdab-b40b-443b-9b12-2063958c7311``.

Cohort predicate (unchanged from the classification pass):
``status='pending' AND phase IN ('Q02','Q04') AND created_at < '2026-09'``.

For each cohort row, ``latest_terminal`` is the ``done``/``failed`` row with the
greatest ``created_at`` for the same ``(ea_id, symbol, phase)``. Rows are
bucketed by that row's verdict:

* **park** -- prior verdict in {PASS, PASS_SOFT, PASS_LOWFREQ, RETIRE,
  CANCELLED_DUPLICATE_REQUEUE}: the pending row is a redundant rerun of an
  already-settled cell (DL-090: PASS-family evidence never ages out).
* **retire** -- prior verdict in {FAIL, INVALID, ZERO_TRADES, DRAFT_DEFECT}:
  the pending row would only re-confirm an already-settled economic failure.

Rows whose prior verdict is ``INFRA_FAIL`` (treasure candidates) or that have
no prior terminal run at all (``NO_PRIOR_RUN``, needs viability assessment)
are out of scope and are never selected, matching the disposition's explicit
"do NOT touch" instruction.

Mechanism: one ``work_item_supersedes`` edge per row (never an UPDATE/DELETE
on ``work_items``). ``superseded_by_work_item_id`` is set to the prior
terminal row's id in *both* buckets -- that row is, in both cases, the
already-existing authoritative terminal record that makes running the pending
row redundant; the bucket (park vs retire) and the specific prior verdict are
carried in ``reason``. The existing trigger
``trg_work_items_superseded_no_activate`` makes any row with a
``work_item_supersedes`` entry permanently unclaimable without ever touching
its ``status``/``verdict``/``payload_json``.

Dry-run (``build_plan``) is read-only and is the authority for the exact row
list: if the re-derived park/retire counts are not exactly 79/223, it raises
and nothing is written -- STOP, per the task's hard rule, instead of guessing.

Apply takes exactly one online SQLite backup for the whole run, then commits
the park batch and the retire batch as two separate ``BEGIN IMMEDIATE``
transactions (both under one ``FactoryMutationLock`` hold). Each row is
revalidated immediately before its INSERT; a row that drifted since the plan
was built (claimed, resolved, already superseded) is *skipped*, not force-
applied and not allowed to abort rows that did not drift -- the hard rule is
"never touch active rows," not "abort a 300-row batch because a factory
worker won one race."
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
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock

try:
    from work_item_supersedes import ensure_schema as ensure_work_item_supersedes_schema
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    from tools.strategy_farm.work_item_supersedes import (
        ensure_schema as ensure_work_item_supersedes_schema,
    )


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_BACKUP_DIR = Path(r"D:\QM\strategy_farm\state\backups")
DEFAULT_MUTATION_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
DEFAULT_BUSY_TIMEOUT_MS = 120000

CLASSIFICATION_EVIDENCE_PATH = Path(
    r"C:\QM\repo\docs\ops\evidence\2026-09-02_2093b38e_july_cohort_zombie_queue_disposition.md"
)
CLASSIFICATION_ROUTER_TASK_ID = "2093b38e-8eb4-4bcd-931b-25c50ada861f"
ROUTER_TASK_ID = "c9a1bdab-b40b-443b-9b12-2063958c7311"

PLAN_SCHEMA = "qm.july-cohort-park-retire-plan/v1"
RECEIPT_SCHEMA = "qm.july-cohort-park-retire-receipt/v1"

PARK_SOURCE_ENCODING = f"router:july-cohort-park:{ROUTER_TASK_ID}"
RETIRE_SOURCE_ENCODING = f"router:july-cohort-retire:{ROUTER_TASK_ID}"

PARK_VERDICTS = {"PASS", "PASS_SOFT", "PASS_LOWFREQ", "RETIRE", "CANCELLED_DUPLICATE_REQUEUE"}
RETIRE_VERDICTS = {"FAIL", "INVALID", "ZERO_TRADES", "DRAFT_DEFECT"}

EXPECTED_PARK_COUNT = 79
EXPECTED_RETIRE_COUNT = 223

COHORT_SQL = """
    SELECT id, ea_id, symbol, phase, status, verdict, claimed_by, created_at
    FROM work_items
    WHERE status='pending' AND phase IN ('Q02','Q04') AND created_at < '2026-09'
"""

LATEST_TERMINAL_SQL = """
    SELECT id, verdict, status, created_at
    FROM work_items
    WHERE ea_id=? AND symbol=? AND phase=? AND status IN ('done','failed')
    ORDER BY created_at DESC
    LIMIT 1
"""


class ParkRetireBatchError(RuntimeError):
    """Fail-closed park/retire batch error -- the caller must STOP, not guess."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


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
        raise ParkRetireBatchError(f"output_exists:{path}")
    data = canonical_bytes(value)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_bytes(data)
    temporary.replace(path)
    return sha256_bytes(data)


def connect(db: Path, *, read_only: bool, busy_timeout_ms: int = DEFAULT_BUSY_TIMEOUT_MS) -> sqlite3.Connection:
    if read_only:
        conn = sqlite3.connect(f"file:{Path(db).as_posix()}?mode=ro", uri=True, timeout=30)
    else:
        conn = sqlite3.connect(str(db), timeout=30)
        conn.execute(f"PRAGMA busy_timeout={max(0, int(busy_timeout_ms))}")
    conn.row_factory = sqlite3.Row
    return conn


def _row_identity(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "ea_id": row["ea_id"],
        "symbol": row["symbol"],
        "phase": row["phase"],
        "status": row["status"],
        "verdict": row["verdict"],
        "claimed_by": row["claimed_by"],
        "created_at": row["created_at"],
    }


def _reason(*, bucket: str, prior_verdict: str, ea_id: str, symbol: str, phase: str,
            prior_id: str, prior_created_at: str) -> str:
    if bucket == "park":
        disposition = (
            "PARK: pending row is a redundant rerun of an already-settled cell "
            "(DL-090: PASS-family evidence ages never)"
        )
    else:
        disposition = (
            "RETIRE: pending row would only re-confirm an already-settled "
            "economic failure (genuine no-signal/fail/invalid results are never requalified)"
        )
    return (
        f"july_cohort_{bucket}: prior_verdict={prior_verdict} for "
        f"{ea_id}/{symbol}/{phase}, prior terminal row {prior_id} "
        f"(created {prior_created_at}). {disposition}. "
        f"Classification: {CLASSIFICATION_ROUTER_TASK_ID}; execution: {ROUTER_TASK_ID}."
    )


def build_plan(db: Path) -> dict[str, Any]:
    if not CLASSIFICATION_EVIDENCE_PATH.is_file():
        raise ParkRetireBatchError(f"classification_evidence_missing:{CLASSIFICATION_EVIDENCE_PATH}")
    conn = connect(db, read_only=True)
    try:
        cohort = conn.execute(COHORT_SQL).fetchall()
        by_verdict_counts: dict[str, int] = {}
        park_targets: list[dict[str, Any]] = []
        retire_targets: list[dict[str, Any]] = []
        for row in cohort:
            terminal = conn.execute(
                LATEST_TERMINAL_SQL, (row["ea_id"], row["symbol"], row["phase"])
            ).fetchone()
            prior_verdict = terminal["verdict"] if terminal is not None else "NO_PRIOR_RUN"
            by_verdict_counts[prior_verdict] = by_verdict_counts.get(prior_verdict, 0) + 1
            if prior_verdict not in PARK_VERDICTS and prior_verdict not in RETIRE_VERDICTS:
                continue
            bucket = "park" if prior_verdict in PARK_VERDICTS else "retire"
            identity = _row_identity(row)
            target = {
                "id": row["id"],
                "ea_id": row["ea_id"],
                "symbol": row["symbol"],
                "phase": row["phase"],
                "prior_verdict": prior_verdict,
                "prior_work_item_id": terminal["id"],
                "prior_created_at": terminal["created_at"],
                "reason": _reason(
                    bucket=bucket, prior_verdict=prior_verdict, ea_id=row["ea_id"],
                    symbol=row["symbol"], phase=row["phase"], prior_id=terminal["id"],
                    prior_created_at=terminal["created_at"],
                ),
                "row_identity_sha256": sha256_bytes(canonical_bytes(identity)),
            }
            (park_targets if bucket == "park" else retire_targets).append(target)
    finally:
        conn.close()

    if len(park_targets) != EXPECTED_PARK_COUNT or len(retire_targets) != EXPECTED_RETIRE_COUNT:
        raise ParkRetireBatchError(
            "count_mismatch:park="
            f"{len(park_targets)}(expected {EXPECTED_PARK_COUNT}):retire="
            f"{len(retire_targets)}(expected {EXPECTED_RETIRE_COUNT})"
        )

    park_targets.sort(key=lambda t: t["id"])
    retire_targets.sort(key=lambda t: t["id"])

    plan = {
        "schema": PLAN_SCHEMA,
        "generated_at_utc": utc_now(),
        "database": str(Path(db).resolve()),
        "router_task_id": ROUTER_TASK_ID,
        "classification_router_task_id": CLASSIFICATION_ROUTER_TASK_ID,
        "classification_evidence_path": str(CLASSIFICATION_EVIDENCE_PATH.resolve()),
        "classification_evidence_sha256": sha256_file(CLASSIFICATION_EVIDENCE_PATH),
        "cohort_sql": COHORT_SQL.strip(),
        "cohort_total": len(cohort),
        "by_prior_verdict_count": by_verdict_counts,
        "park_source_encoding": PARK_SOURCE_ENCODING,
        "retire_source_encoding": RETIRE_SOURCE_ENCODING,
        "park_targets": park_targets,
        "retire_targets": retire_targets,
        "park_count": len(park_targets),
        "retire_count": len(retire_targets),
    }
    plan["park_targets_sha256"] = sha256_bytes(canonical_bytes(park_targets))
    plan["retire_targets_sha256"] = sha256_bytes(canonical_bytes(retire_targets))
    return plan


def validate_plan(plan: dict[str, Any]) -> None:
    if plan.get("schema") != PLAN_SCHEMA or plan.get("router_task_id") != ROUTER_TASK_ID:
        raise ParkRetireBatchError("wrong_plan_authority")
    if (
        plan.get("park_source_encoding") != PARK_SOURCE_ENCODING
        or plan.get("retire_source_encoding") != RETIRE_SOURCE_ENCODING
    ):
        raise ParkRetireBatchError("wrong_plan_disposition")
    park_targets = plan.get("park_targets") or []
    retire_targets = plan.get("retire_targets") or []
    if len(park_targets) != EXPECTED_PARK_COUNT or len(retire_targets) != EXPECTED_RETIRE_COUNT:
        raise ParkRetireBatchError(
            f"plan_count_mismatch:park={len(park_targets)}:retire={len(retire_targets)}"
        )
    if sha256_bytes(canonical_bytes(park_targets)) != plan.get("park_targets_sha256"):
        raise ParkRetireBatchError("park_targets_hash_mismatch")
    if sha256_bytes(canonical_bytes(retire_targets)) != plan.get("retire_targets_sha256"):
        raise ParkRetireBatchError("retire_targets_hash_mismatch")
    if sha256_file(CLASSIFICATION_EVIDENCE_PATH) != plan.get("classification_evidence_sha256"):
        raise ParkRetireBatchError("classification_evidence_drift")


def backup_database(db: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir = Path(backup_dir)
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    destination = backup_dir / f"farm_state_before_july_cohort_park_retire_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    source = sqlite3.connect(str(db), timeout=30)
    target = sqlite3.connect(str(destination))
    try:
        source.backup(target)
    finally:
        target.close()
        source.close()
    return destination, sha256_file(destination)


def _revalidate_target(conn: sqlite3.Connection, target: dict[str, Any]) -> tuple[bool, str | None]:
    """Return (eligible, skip_reason). Never raises for an individual row --
    a drifted row is skipped, not force-applied and not allowed to abort the
    rows that did not drift."""

    row = conn.execute(
        "SELECT id, ea_id, symbol, phase, status, verdict, claimed_by, created_at "
        "FROM work_items WHERE id=?",
        (target["id"],),
    ).fetchone()
    if row is None:
        return False, "row_missing"
    if row["status"] != "pending":
        return False, f"status_drifted:{row['status']}"
    if row["verdict"] is not None:
        return False, f"verdict_drifted:{row['verdict']}"
    if str(row["claimed_by"] or "").strip():
        return False, f"claimed_drifted:{row['claimed_by']}"
    identity = _row_identity(row)
    if sha256_bytes(canonical_bytes(identity)) != target["row_identity_sha256"]:
        return False, "identity_drifted"
    already = conn.execute(
        "SELECT 1 FROM work_item_supersedes WHERE work_item_id=?", (target["id"],)
    ).fetchone()
    if already is not None:
        return False, "already_superseded"
    return True, None


def _apply_batch(
    conn: sqlite3.Connection, *, targets: list[dict[str, Any]], source_encoding: str,
    applied_at: str, backup_path: Path, backup_sha: str,
) -> dict[str, Any]:
    inserted: list[str] = []
    skipped: list[dict[str, str]] = []
    conn.execute("BEGIN IMMEDIATE")
    try:
        for target in targets:
            eligible, skip_reason = _revalidate_target(conn, target)
            if not eligible:
                skipped.append({"id": target["id"], "reason": skip_reason or "unknown"})
                continue
            conn.execute(
                """INSERT INTO work_item_supersedes(
                     work_item_id,superseded_by_work_item_id,reason,source_encoding,
                     evidence_path,recorded_by,recorded_at) VALUES(?,?,?,?,?,?,?)""",
                (
                    target["id"], target["prior_work_item_id"], target["reason"], source_encoding,
                    str(CLASSIFICATION_EVIDENCE_PATH.resolve()), "claude", applied_at,
                ),
            )
            conn.execute(
                "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)",
                (
                    applied_at, "work_item", target["id"], "work_item_superseded",
                    json.dumps({
                        "reason": target["reason"],
                        "source_encoding": source_encoding,
                        "router_task_id": ROUTER_TASK_ID,
                        "superseded_by_work_item_id": target["prior_work_item_id"],
                        "backup_path": str(backup_path),
                        "backup_sha256": backup_sha,
                    }, sort_keys=True),
                ),
            )
            inserted.append(target["id"])
        readback = conn.execute(
            "SELECT COUNT(*) FROM work_item_supersedes WHERE source_encoding=?", (source_encoding,)
        ).fetchone()[0]
        if int(readback) != len(inserted):
            raise ParkRetireBatchError(f"pre_commit_readback:{readback}!={len(inserted)}:{source_encoding}")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    return {"inserted": inserted, "skipped": skipped, "table_rows": readback}


def apply_plan(
    *, db: Path, plan_path: Path, expected_plan_sha256: str, receipt_out: Path,
    backup_dir: Path, mutation_lock: Path, busy_timeout_ms: int = DEFAULT_BUSY_TIMEOUT_MS,
) -> dict[str, Any]:
    expected = expected_plan_sha256.lower()
    if sha256_file(plan_path) != expected:
        raise ParkRetireBatchError("plan_sha256_mismatch")
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    validate_plan(plan)
    applied_at = utc_now()

    with FactoryMutationLock(mutation_lock, owner=f"july-cohort-park-retire:{ROUTER_TASK_ID}"):
        backup_path, backup_sha = backup_database(db, backup_dir)
        conn = connect(db, read_only=False, busy_timeout_ms=busy_timeout_ms)
        try:
            ensure_work_item_supersedes_schema(conn)
            park_result = _apply_batch(
                conn, targets=plan["park_targets"], source_encoding=PARK_SOURCE_ENCODING,
                applied_at=applied_at, backup_path=backup_path, backup_sha=backup_sha,
            )
            retire_result = _apply_batch(
                conn, targets=plan["retire_targets"], source_encoding=RETIRE_SOURCE_ENCODING,
                applied_at=applied_at, backup_path=backup_path, backup_sha=backup_sha,
            )
            quick_check = conn.execute("PRAGMA quick_check").fetchone()[0]
        finally:
            conn.close()

    receipt = {
        "schema": RECEIPT_SCHEMA,
        "applied_at_utc": applied_at,
        "router_task_id": ROUTER_TASK_ID,
        "plan_path": str(plan_path.resolve()),
        "plan_sha256": expected,
        "backup": {"path": str(backup_path.resolve()), "sha256": backup_sha},
        "park": {
            "source_encoding": PARK_SOURCE_ENCODING,
            "planned": len(plan["park_targets"]),
            "inserted": len(park_result["inserted"]),
            "skipped": park_result["skipped"],
            "superseded_work_item_ids": park_result["inserted"],
        },
        "retire": {
            "source_encoding": RETIRE_SOURCE_ENCODING,
            "planned": len(plan["retire_targets"]),
            "inserted": len(retire_result["inserted"]),
            "skipped": retire_result["skipped"],
            "superseded_work_item_ids": retire_result["inserted"],
        },
        "total_inserted": len(park_result["inserted"]) + len(retire_result["inserted"]),
        "total_skipped": len(park_result["skipped"]) + len(retire_result["skipped"]),
        "quick_check": quick_check,
    }
    receipt["receipt_sha256"] = write_new_json(receipt_out, receipt)
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_MUTATION_LOCK)
    parser.add_argument("--busy-timeout-ms", type=int, default=DEFAULT_BUSY_TIMEOUT_MS)
    parser.add_argument("--plan-out", type=Path)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--expected-plan-sha256")
    parser.add_argument("--receipt-out", type=Path)
    args = parser.parse_args()
    try:
        if args.apply:
            if not args.plan or not args.expected_plan_sha256 or not args.receipt_out:
                raise ParkRetireBatchError("apply_requires_plan_hash_and_receipt")
            result = apply_plan(
                db=args.db, plan_path=args.plan, expected_plan_sha256=args.expected_plan_sha256,
                receipt_out=args.receipt_out, backup_dir=args.backup_dir,
                mutation_lock=args.mutation_lock, busy_timeout_ms=args.busy_timeout_ms,
            )
        else:
            result = build_plan(args.db)
            if args.plan_out:
                result["plan_file_sha256"] = write_new_json(args.plan_out, result)
        result["status"] = "ok"
        print(json.dumps(result, indent=1, default=str))
        return 0
    except (ParkRetireBatchError, sqlite3.Error, OSError, RuntimeError, ValueError) as exc:
        print(json.dumps({
            "schema": RECEIPT_SCHEMA if args.apply else PLAN_SCHEMA,
            "status": "aborted",
            "reason": f"{type(exc).__name__}: {exc}",
        }, indent=1))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
