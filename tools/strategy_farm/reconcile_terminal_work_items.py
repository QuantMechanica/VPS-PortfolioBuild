#!/usr/bin/env python3
"""MNT-009 -> MNT-010 guarded work-item and parent reconciliation.

The default command is a read-only PLAN.  APPLY is deliberately verbose: it
requires byte hashes for the manifest, SQLite main file, SQLite logical state,
and FACTORY_OFF flag, takes a fresh SQLite backup, owns the global factory
mutation lock, and performs every row/ledger transition in one transaction.

The MNT-009 receipt is a *legacy database-state disposition*, never invented
test evidence.  ``evidence_path`` is populated only when an already-existing,
concrete artifact is discovered beneath a payload-bound path and its bytes are
hash-bound in the manifest.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import sqlite3
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

try:
    import farmctl
    from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag
except ModuleNotFoundError:  # pragma: no cover - package import
    from tools.strategy_farm import farmctl
    from tools.strategy_farm.factory_mutation_lock import (
        FactoryMutationLock,
        path_for_factory_flag,
    )


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_FACTORY_OFF = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
SCHEMA_VERSION = "mnt009-010-reconciliation/v1"
NULL_TAXONOMY_VERSION = "mnt009-null-disposition/v1"

PARK_REASONS = frozenset({
    (
        "parked 2026-07-14: NDX.DWX symbol-level defect — history sync error "
        "persists even after 2020.hcc gap heal (GapFix Bars()=0 anomaly); needs "
        "custom-symbol repair before any NDX run can succeed. Re-enqueue via "
        "farmctl after fix."
    ),
    (
        "parked 2026-07-14: NDX.DWX symbol-level defect (rebuild in progress); "
        "batch re-enqueue after repair."
    ),
    (
        "parked 2026-07-15: NDX.DWX rebuild in progress; batch re-enqueue "
        "after repair."
    ),
})
BASKET_SUPERSEDE_REASON = (
    "cancelled 2026-07-15: per-pair fan-out forbidden for cross-sectional basket "
    "(decisions/2026-07-15_multicurrency_logical_basket_workitem.md); replaced by "
    "ONE logical FX8_BASKET_D1 item."
)
OWNER_RETIRE_REASON = (
    "XAU excluded by OWNER-approved USDJPY-only admission: walkforward OOS PF 1.03 "
    "gross = documented negative (docs/research/BALKE_RANGE_BREAKOUT_WALKFORWARD_"
    "2026-07-14.md); setfile removed from canonical (7f9ae6e3d); fanout derived "
    "symbol from magic slot 1."
)

DIRECT_EVIDENCE_KEYS = (
    "summary_path",
    "aggregate_path",
    "report_path",
    "report_csv",
    "runner_log",
)
ROOT_EVIDENCE_KEYS = ("report_root", "archived_report_root_on_requeue")
LOG_EVIDENCE_KEYS = ("log_path",)
EVIDENCE_FILENAME_RANK = {
    "aggregate.json": 0,
    "summary.json": 1,
    "report.csv": 2,
    "report.html": 3,
    "report.htm": 4,
    "runner.log": 5,
    "run.log": 6,
}
EVIDENCE_SUFFIX_RANK = {
    ".json": 20,
    ".csv": 21,
    ".html": 22,
    ".htm": 23,
    ".log": 24,
    ".xml": 25,
}


SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS work_item_transition_ledger (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    idempotency_key TEXT NOT NULL UNIQUE,
    ts TEXT NOT NULL,
    work_item_id TEXT NOT NULL,
    action TEXT NOT NULL,
    from_status TEXT,
    to_status TEXT,
    from_verdict TEXT,
    to_verdict TEXT,
    from_claimed_by TEXT,
    to_claimed_by TEXT,
    reason TEXT NOT NULL,
    run_id TEXT,
    detail_json TEXT NOT NULL
);
CREATE TRIGGER IF NOT EXISTS trg_work_item_transition_ledger_no_update
BEFORE UPDATE ON work_item_transition_ledger
BEGIN SELECT RAISE(ABORT, 'work_item_transition_ledger is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_work_item_transition_ledger_no_delete
BEFORE DELETE ON work_item_transition_ledger
BEGIN SELECT RAISE(ABORT, 'work_item_transition_ledger is append-only'); END;

CREATE TRIGGER IF NOT EXISTS trg_work_items_terminal_requires_verdict_update
BEFORE UPDATE OF status, verdict ON work_items
WHEN NEW.status IN ('done', 'failed') AND NEW.verdict IS NULL
BEGIN SELECT RAISE(ABORT, 'terminal work_item requires verdict'); END;
CREATE TRIGGER IF NOT EXISTS trg_work_items_terminal_requires_verdict_insert
BEFORE INSERT ON work_items
WHEN NEW.status IN ('done', 'failed') AND NEW.verdict IS NULL
BEGIN SELECT RAISE(ABORT, 'terminal work_item requires verdict'); END;

-- MNT-009 (2026-08-21): mirrors farmctl.py's init_db schema -- see there for
-- the full rationale (scoped to verdict='INFRA_FAIL' only). Kept in lockstep
-- because this tool applies its own schema independently against the same
-- farm_state.sqlite.
CREATE TRIGGER IF NOT EXISTS trg_work_items_infra_fail_requires_evidence_update
BEFORE UPDATE OF status, verdict ON work_items
WHEN NEW.status IN ('done', 'failed') AND NEW.verdict = 'INFRA_FAIL'
     AND (NEW.evidence_path IS NULL OR trim(NEW.evidence_path) = '')
BEGIN SELECT RAISE(ABORT, 'terminal INFRA_FAIL work_item requires evidence_path or EVIDENCE_UNAVAILABLE sentinel'); END;
CREATE TRIGGER IF NOT EXISTS trg_work_items_infra_fail_requires_evidence_insert
BEFORE INSERT ON work_items
WHEN NEW.status IN ('done', 'failed') AND NEW.verdict = 'INFRA_FAIL'
     AND (NEW.evidence_path IS NULL OR trim(NEW.evidence_path) = '')
BEGIN SELECT RAISE(ABORT, 'terminal INFRA_FAIL work_item requires evidence_path or EVIDENCE_UNAVAILABLE sentinel'); END;

CREATE TABLE IF NOT EXISTS parent_task_transition_ledger (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    idempotency_key TEXT NOT NULL UNIQUE,
    ts TEXT NOT NULL,
    parent_task_id TEXT NOT NULL,
    action TEXT NOT NULL,
    from_status TEXT,
    to_status TEXT,
    from_payload_sha256 TEXT NOT NULL,
    to_payload_sha256 TEXT NOT NULL,
    child_state_sha256 TEXT NOT NULL,
    verdict TEXT NOT NULL,
    reason TEXT NOT NULL,
    run_id TEXT,
    detail_json TEXT NOT NULL
);
CREATE TRIGGER IF NOT EXISTS trg_parent_task_transition_ledger_no_update
BEFORE UPDATE ON parent_task_transition_ledger
BEGIN SELECT RAISE(ABORT, 'parent_task_transition_ledger is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_parent_task_transition_ledger_no_delete
BEFORE DELETE ON parent_task_transition_ledger
BEGIN SELECT RAISE(ABORT, 'parent_task_transition_ledger is append-only'); END;
"""


class ReconciliationError(RuntimeError):
    pass


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")


def canonical_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def sha256_bytes(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def connect_ro(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(Path(path).resolve().as_uri() + "?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def sqlite_logical_sha256(path: Path) -> str:
    with connect_ro(path) as conn:
        try:
            image = conn.serialize()
        except AttributeError as exc:  # pragma: no cover - Python < 3.11
            raise ReconciliationError("sqlite3.Connection.serialize() is required") from exc
    return hashlib.sha256(image).hexdigest()


def checkpoint_wal(path: Path) -> dict[str, int]:
    with sqlite3.connect(path, timeout=30, isolation_level=None) as conn:
        conn.execute("PRAGMA busy_timeout=30000")
        row = conn.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()
    busy, log_frames, checkpointed = (int(value or 0) for value in row)
    if busy:
        raise ReconciliationError(
            f"WAL checkpoint busy: log={log_frames}, checkpointed={checkpointed}"
        )
    return {
        "busy": busy,
        "log_frames": log_frames,
        "checkpointed_frames": checkpointed,
    }


def write_json_atomic(path: Path, payload: Any) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp.{os.getpid()}")
    try:
        with temporary.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True, ensure_ascii=False)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def classify_null_disposition(row: sqlite3.Row | dict[str, Any]) -> dict[str, Any]:
    """Return one exact legacy disposition; unknown reasons are blocked."""
    status = str(row["status"] or "")
    verdict = row["verdict"]
    if status not in farmctl.PHYSICALLY_TERMINAL_WORK_ITEM_STATUSES or verdict is not None:
        return {"eligible": False, "reason": "not_terminal_null"}
    payload_raw = str(row["payload_json"] or "{}")
    try:
        payload = json.loads(payload_raw)
    except json.JSONDecodeError:
        return {"eligible": False, "reason": "payload_json_invalid"}
    invalidated_reason = payload.get("invalidated_reason")
    if not isinstance(invalidated_reason, str) or not invalidated_reason:
        return {"eligible": False, "reason": "invalidated_reason_missing"}
    if invalidated_reason in PARK_REASONS:
        category, target_status, target_verdict = (
            "NDX_HISTORY_REPAIR_PARK",
            "failed",
            "INFRA_FAIL",
        )
    elif invalidated_reason == BASKET_SUPERSEDE_REASON:
        category, target_status, target_verdict = (
            "CROSS_SECTIONAL_PAIR_SUPERSEDED",
            "done",
            "SUPERSEDED_BY_LOGICAL_BASKET",
        )
    elif invalidated_reason == OWNER_RETIRE_REASON:
        category, target_status, target_verdict = (
            "OWNER_USDJPY_ONLY_ADMISSION",
            "done",
            "RETIRE",
        )
    else:
        return {
            "eligible": False,
            "reason": "unknown_invalidated_reason",
            "invalidated_reason_sha256": sha256_bytes(invalidated_reason),
        }
    return {
        "eligible": True,
        "category": category,
        "target_status": target_status,
        "target_verdict": target_verdict,
        "evidence_kind": "legacy_db_state_disposition_not_test_result",
        "invalidated_reason": invalidated_reason,
        "invalidated_reason_sha256": sha256_bytes(invalidated_reason),
        "payload_sha256": sha256_bytes(payload_raw),
    }


def _candidate_files(root: Path) -> Iterable[tuple[int, Path]]:
    if root.is_file():
        yield (0, root)
        return
    if not root.is_dir():
        return
    try:
        paths = root.rglob("*")
        for path in paths:
            try:
                if not path.is_file():
                    continue
            except OSError:
                continue
            name = path.name.lower()
            if name in EVIDENCE_FILENAME_RANK:
                yield (EVIDENCE_FILENAME_RANK[name], path)
            elif path.suffix.lower() in EVIDENCE_SUFFIX_RANK:
                yield (EVIDENCE_SUFFIX_RANK[path.suffix.lower()], path)
    except OSError:
        return


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve(strict=False).relative_to(root.resolve(strict=False))
        return True
    except (OSError, ValueError):
        return False


def _report_lineage_root(
    path: Path, *, work_item_id: str, runtime_root: Path
) -> Path | None:
    bases = (
        Path(runtime_root) / "reports" / "work_items",
        Path(r"D:\QM\reports\work_items"),
    )
    resolved = path.resolve(strict=False)
    for base in bases:
        try:
            relative = resolved.relative_to(base.resolve(strict=False))
        except (OSError, ValueError):
            continue
        if not relative.parts:
            continue
        lineage_component = relative.parts[0]
        if (
            lineage_component == work_item_id
            or lineage_component.startswith(work_item_id + ".requeued_")
        ):
            return base / lineage_component
    return None


def _is_expected_work_item_log(
    path: Path, *, work_item_id: str, runtime_root: Path
) -> bool:
    expected = Path(runtime_root) / "logs" / f"work_item_{work_item_id}.log"
    try:
        return path.resolve(strict=False) == expected.resolve(strict=False)
    except OSError:
        return False


def resolve_existing_evidence(
    payload: dict[str, Any], *, work_item_id: str, runtime_root: Path
) -> dict[str, Any] | None:
    """Resolve a concrete artifact inside the row's expected runtime lineage.

    Arbitrary paths in historical payload JSON are never trusted.  Report
    artifacts must stay below the work-item-id directory (or its explicit
    ``<id>.requeued_*`` archive) in a canonical runtime report root; logs must
    be the exact ``work_item_<id>.log`` under this runtime's log directory.
    """
    candidates: list[tuple[int, str, Path, str]] = []
    for index, key in enumerate(DIRECT_EVIDENCE_KEYS):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            path = Path(value)
            lineage = _report_lineage_root(
                path, work_item_id=work_item_id, runtime_root=runtime_root
            )
            if path.is_file() and (
                (lineage is not None and _is_within(path, lineage))
                or _is_expected_work_item_log(
                    path, work_item_id=work_item_id, runtime_root=runtime_root
                )
            ):
                candidates.append((
                    index,
                    key,
                    path,
                    "report" if lineage is not None else "work_item_log",
                ))
    for index, key in enumerate(ROOT_EVIDENCE_KEYS, start=100):
        value = payload.get(key)
        if not isinstance(value, str) or not value.strip():
            continue
        payload_root = Path(value)
        lineage = _report_lineage_root(
            payload_root, work_item_id=work_item_id, runtime_root=runtime_root
        )
        if lineage is None or not _is_within(payload_root, lineage):
            continue
        for rank, path in _candidate_files(payload_root):
            if _is_within(path, lineage):
                candidates.append((index + rank, key, path, "report"))
    for index, key in enumerate(LOG_EVIDENCE_KEYS, start=500):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            path = Path(value)
            if path.is_file() and _is_expected_work_item_log(
                path, work_item_id=work_item_id, runtime_root=runtime_root
            ):
                candidates.append((index, key, path, "work_item_log"))
    if not candidates:
        return None
    candidates.sort(key=lambda item: (item[0], str(item[2]).casefold()))
    _, source_key, chosen, lineage_kind = candidates[0]
    try:
        chosen = chosen.resolve(strict=True)
        stat = chosen.stat()
        digest = sha256_file(chosen)
    except OSError:
        return None
    return {
        "path": str(chosen),
        "sha256": digest,
        "size_bytes": int(stat.st_size),
        "source_payload_key": source_key,
        "lineage_kind": lineage_kind,
        "work_item_id": work_item_id,
        "evidence_kind": "preexisting_runtime_artifact_not_reconstructed",
    }


def _row_expected(row: sqlite3.Row) -> dict[str, Any]:
    payload_raw = str(row["payload_json"] or "{}")
    return {
        "status": row["status"],
        "verdict": row["verdict"],
        "claimed_by": row["claimed_by"],
        "evidence_path": row["evidence_path"],
        "updated_at": row["updated_at"],
        "payload_sha256": sha256_bytes(payload_raw),
    }


def _simulated_parent_operation(
    conn: sqlite3.Connection,
    parent: sqlite3.Row,
    children: list[sqlite3.Row],
    null_targets: dict[str, dict[str, str]],
) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    simulated: list[dict[str, Any]] = []
    for child in children:
        row = dict(child)
        target = null_targets.get(str(child["id"]))
        if target:
            row["status"] = target["target_status"]
            row["verdict"] = target["target_verdict"]
        simulated.append(row)
    refusal = farmctl._terminal_child_refusal(simulated)
    if any(refusal.values()):
        return None, {
            "parent_task_id": parent["id"],
            "reason": "child_contract_refused",
            **refusal,
        }
    phase = farmctl._parent_phase_from_task_kind(parent["kind"])
    pass_symbols = [row["symbol"] for row in simulated if row["verdict"] == "PASS"]
    if phase == "P2":
        surviving, _ = farmctl._filter_p2_profitable_symbols(conn, parent["id"], pass_symbols)
    else:
        surviving = pass_symbols
    verdict = farmctl._aggregate_work_item_verdict(phase, simulated, surviving)
    child_hash = farmctl.terminal_child_state_sha256(simulated)
    parent_payload_raw = str(parent["payload_json"] or "{}")
    next_phase = farmctl.PARENT_PROGRESSION_MAP.get(phase) if verdict == "PASS" else None
    return {
        "operation_id": f"mnt010-parent-close:{parent['id']}",
        "parent_task_id": parent["id"],
        "expected": {
            "status": parent["status"],
            "updated_at": parent["updated_at"],
            "payload_sha256": sha256_bytes(parent_payload_raw),
            "child_state_sha256_after_mnt009": child_hash,
        },
        "target": {
            "status": "done",
            "verdict": verdict,
            "progression": (
                {"status": "DEFERRED_FACTORY_OFF", "next_phase": next_phase}
                if next_phase
                else {"status": "NOT_APPLICABLE"}
            ),
        },
        "phase": phase,
        "child_ids": sorted(str(row["id"]) for row in simulated),
        "evidence_kind": "canonical_child_state_aggregation",
    }, None


def _plan_id_payload(plan: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": plan["schema_version"],
        "database": plan["database"],
        "factory_off": plan["factory_off"],
        "taxonomies": plan["taxonomies"],
        "null_verdict_operations": plan["null_verdict_operations"],
        "evidence_binding_operations": plan["evidence_binding_operations"],
        "parent_close_operations": plan["parent_close_operations"],
        "blocked": plan["blocked"],
        "census": plan["census"],
        "maintenance_status": plan["maintenance_status"],
        "apply_scope_status": plan["apply_scope_status"],
        "apply_ready": plan["apply_ready"],
        "apply_ready_definition": plan["apply_ready_definition"],
    }


def _reject_duplicate_object_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    payload: dict[str, Any] = {}
    for key, value in pairs:
        if key in payload:
            raise ReconciliationError(f"duplicate JSON object key: {key}")
        payload[key] = value
    return payload


def plan_reconciliation(
    db_path: Path = DEFAULT_DB,
    factory_off_path: Path = DEFAULT_FACTORY_OFF,
    *,
    scan_evidence: bool = True,
) -> dict[str, Any]:
    """Read the entire relevant corpus and return one deterministic plan."""
    db_path = Path(db_path)
    factory_off_path = Path(factory_off_path)
    if not db_path.is_file():
        raise ReconciliationError(f"database missing: {db_path}")
    if not factory_off_path.is_file():
        raise ReconciliationError(f"FACTORY_OFF flag missing: {factory_off_path}")
    db_binding = {
        "path": str(db_path),
        "file_sha256": sha256_file(db_path),
        "logical_sha256": sqlite_logical_sha256(db_path),
    }
    flag_binding = {
        "path": str(factory_off_path),
        "sha256": sha256_file(factory_off_path),
    }
    null_operations: list[dict[str, Any]] = []
    evidence_operations: list[dict[str, Any]] = []
    parent_operations: list[dict[str, Any]] = []
    blocked_null: list[dict[str, Any]] = []
    blocked_parents: list[dict[str, Any]] = []
    disposition_counts: Counter[str] = Counter()
    evidence_source_counts: Counter[str] = Counter()
    missing_evidence_count = 0
    projected_new_infra_without_evidence = 0
    null_evidence_binding_count = 0

    with connect_ro(db_path) as conn:
        null_rows = conn.execute(
            """
            SELECT * FROM work_items
            WHERE status IN ('done','failed') AND verdict IS NULL
            ORDER BY id
            """
        ).fetchall()
        null_targets: dict[str, dict[str, str]] = {}
        for row in null_rows:
            disposition = classify_null_disposition(row)
            if not disposition.get("eligible"):
                blocked_null.append({
                    "work_item_id": row["id"],
                    "reason": disposition.get("reason"),
                    "detail": disposition,
                })
                continue
            disposition_counts[disposition["category"]] += 1
            null_targets[str(row["id"])] = {
                "target_status": disposition["target_status"],
                "target_verdict": disposition["target_verdict"],
            }
            target: dict[str, Any] = {
                "status": disposition["target_status"],
                "verdict": disposition["target_verdict"],
            }
            artifact: dict[str, Any] | None = None
            if (
                disposition["target_verdict"] in {"INFRA_FAIL", "INVALID"}
                and not (row["evidence_path"] or "").strip()
            ):
                projected_new_infra_without_evidence += 1
                if scan_evidence:
                    try:
                        null_payload = json.loads(row["payload_json"] or "{}")
                    except json.JSONDecodeError:
                        null_payload = {}
                    if isinstance(null_payload, dict):
                        artifact = resolve_existing_evidence(
                            null_payload,
                            work_item_id=str(row["id"]),
                            runtime_root=db_path.parent.parent,
                        )
                    if artifact is not None:
                        target["evidence_path"] = artifact["path"]
                        null_evidence_binding_count += 1
                        evidence_source_counts[artifact["source_payload_key"]] += 1
            operation = {
                "operation_id": f"mnt009-null:{row['id']}",
                "work_item_id": row["id"],
                "phase": row["phase"],
                "ea_id": row["ea_id"],
                "symbol": row["symbol"],
                "expected": _row_expected(row),
                "target": target,
                "legacy_disposition": {
                    key: disposition[key]
                    for key in (
                        "category",
                        "evidence_kind",
                        "invalidated_reason",
                        "invalidated_reason_sha256",
                    )
                },
            }
            if artifact is not None:
                operation["artifact"] = artifact
                operation["claim_limit"] = (
                    "Artifact existence is proven; the legacy disposition does "
                    "not reinterpret its contents or invent a test result."
                )
            null_operations.append(operation)

        evidence_rows = conn.execute(
            """
            SELECT * FROM work_items
            WHERE status IN ('done','failed')
              AND verdict IN ('INFRA_FAIL','INVALID')
              AND (evidence_path IS NULL OR trim(evidence_path)='')
            ORDER BY id
            """
        ).fetchall()
        missing_evidence_count = len(evidence_rows)
        if scan_evidence:
            for row in evidence_rows:
                try:
                    payload = json.loads(row["payload_json"] or "{}")
                except json.JSONDecodeError:
                    continue
                if not isinstance(payload, dict):
                    continue
                candidate = resolve_existing_evidence(
                    payload,
                    work_item_id=str(row["id"]),
                    runtime_root=db_path.parent.parent,
                )
                if candidate is None:
                    continue
                evidence_source_counts[candidate["source_payload_key"]] += 1
                evidence_operations.append({
                    "operation_id": f"mnt009-evidence:{row['id']}",
                    "work_item_id": row["id"],
                    "phase": row["phase"],
                    "ea_id": row["ea_id"],
                    "symbol": row["symbol"],
                    "expected": _row_expected(row),
                    "target": {"evidence_path": candidate["path"]},
                    "artifact": candidate,
                    "claim_limit": (
                        "Artifact existence is proven; this migration does not "
                        "reinterpret its contents or invent a test result."
                    ),
                })

        parent_rows = conn.execute(
            """
            SELECT t.*
            FROM tasks t
            WHERE t.status IN ('pending','active')
              AND EXISTS (SELECT 1 FROM work_items w WHERE w.parent_task_id=t.id)
              AND NOT EXISTS (
                  SELECT 1 FROM work_items w
                  WHERE w.parent_task_id=t.id
                    AND w.status NOT IN ('done','failed')
              )
            ORDER BY t.id
            """
        ).fetchall()
        for parent in parent_rows:
            children = conn.execute(
                "SELECT * FROM work_items WHERE parent_task_id=? ORDER BY id",
                (parent["id"],),
            ).fetchall()
            operation, refusal = _simulated_parent_operation(
                conn, parent, list(children), null_targets
            )
            if operation:
                parent_operations.append(operation)
            elif refusal:
                blocked_parents.append(refusal)

    projected_missing_evidence = (
        missing_evidence_count + projected_new_infra_without_evidence
    )
    total_evidence_bindings = len(evidence_operations) + null_evidence_binding_count
    evidence_unbound = projected_missing_evidence - total_evidence_bindings
    plan: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "generated_at": utc_now(),
        "mode": "PLAN_READ_ONLY",
        "database": db_binding,
        "factory_off": flag_binding,
        "taxonomies": {
            "null_disposition": NULL_TAXONOMY_VERSION,
            "parent_child_verdict": farmctl.PARENT_CHILD_VERDICT_TAXONOMY_VERSION,
            "canonical_parent_child_verdicts": sorted(
                farmctl.CANONICAL_PARENT_CHILD_VERDICTS
            ),
        },
        "null_verdict_operations": null_operations,
        "evidence_binding_operations": evidence_operations,
        "parent_close_operations": parent_operations,
        "blocked": {
            "null_verdict_rows": blocked_null,
            "parent_tasks": blocked_parents,
        },
        "census": {
            "terminal_null_verdict_rows": len(null_rows),
            "null_disposition_counts": dict(sorted(disposition_counts.items())),
            "infra_invalid_without_evidence_path_before_mnt009": missing_evidence_count,
            "infra_invalid_without_evidence_path": missing_evidence_count,
            "new_infra_without_evidence_from_null_disposition": projected_new_infra_without_evidence,
            "projected_infra_invalid_without_evidence_after_null_disposition": projected_missing_evidence,
            "existing_evidence_bindings_planned": total_evidence_bindings,
            "evidence_bindings_inside_null_dispositions": null_evidence_binding_count,
            "existing_evidence_source_counts": dict(sorted(evidence_source_counts.items())),
            "evidence_still_unbound": evidence_unbound,
            "evidence_binding_status": "PARTIAL" if evidence_unbound else "COMPLETE",
            "unbound_evidence_statement": (
                "No artifact is invented. Rows without an existing, lineage-valid "
                "payload-bound file remain explicitly unbound."
            ),
            "physical_parent_zombies": len(parent_rows),
            "parent_closures_planned_after_mnt009": len(parent_operations),
            "parent_predicted_verdicts": dict(sorted(Counter(
                operation["target"]["verdict"] for operation in parent_operations
            ).items())),
        },
        "apply_ready": not blocked_null and not blocked_parents,
        "apply_ready_definition": (
            "All planned transitions are taxonomically classified and hash-bindable; "
            "this does not mean all missing historical evidence can be recovered."
        ),
        "apply_scope_status": (
            "SAFE_PARTIAL_RECONCILIATION" if evidence_unbound
            else "SAFE_COMPLETE_RECONCILIATION"
        ),
        "maintenance_status": {
            "MNT-009": {
                "status": (
                    "PARTIAL"
                    if evidence_unbound
                    else (
                        "READY_FOR_GUARDED_APPLY"
                        if null_operations or evidence_operations
                        else "NO_ACTION_REQUIRED"
                    )
                ),
                "null_verdict_scope": (
                    "READY_FOR_GUARDED_APPLY"
                    if null_operations
                    else "NO_ACTION_REQUIRED"
                ),
                "evidence_binding_scope": (
                    "PARTIAL"
                    if evidence_unbound
                    else (
                        "READY_FOR_GUARDED_APPLY"
                        if evidence_operations
                        else "NO_ACTION_REQUIRED"
                    )
                ),
                "remaining_unbound_rows": evidence_unbound,
            },
            "MNT-010": {
                "status": (
                    "READY_FOR_GUARDED_APPLY"
                    if parent_operations
                    else "NO_ACTION_REQUIRED"
                ),
                "parent_closures": len(parent_operations),
            },
        },
    }
    plan["plan_id"] = canonical_sha256(_plan_id_payload(plan))
    return plan


def _assert_equal(label: str, actual: Any, expected: Any) -> None:
    if actual != expected:
        raise ReconciliationError(f"{label} drift: {actual!r} != {expected!r}")


def _load_manifest(path: Path) -> dict[str, Any]:
    payload = json.loads(
        Path(path).read_text(encoding="utf-8-sig"),
        object_pairs_hook=_reject_duplicate_object_keys,
    )
    if not isinstance(payload, dict) or payload.get("schema_version") != SCHEMA_VERSION:
        raise ReconciliationError("unsupported reconciliation manifest")
    expected_plan_id = canonical_sha256(_plan_id_payload(payload))
    _assert_equal("plan_id", payload.get("plan_id"), expected_plan_id)
    if not payload.get("apply_ready"):
        raise ReconciliationError("manifest is not apply_ready")
    for key in (
        "null_verdict_operations",
        "evidence_binding_operations",
        "parent_close_operations",
    ):
        operations = payload.get(key)
        if not isinstance(operations, list):
            raise ReconciliationError(f"manifest.{key} must be an array")
        ids = [str(operation.get("operation_id") or "") for operation in operations]
        if not all(ids) or len(ids) != len(set(ids)):
            raise ReconciliationError(f"manifest.{key} has missing/duplicate operation ids")
    return payload


def _snapshot_database(db_path: Path, snapshot_path: Path) -> str:
    if snapshot_path.exists():
        raise ReconciliationError(f"snapshot path already exists: {snapshot_path}")
    snapshot_path.parent.mkdir(parents=True, exist_ok=True)
    source = sqlite3.connect(db_path, timeout=30)
    destination = sqlite3.connect(snapshot_path)
    try:
        source.backup(destination)
        destination.commit()
    finally:
        destination.close()
        source.close()
    return sha256_file(snapshot_path)


def _fetch_work_item(conn: sqlite3.Connection, operation: dict[str, Any]) -> sqlite3.Row:
    row = conn.execute(
        "SELECT * FROM work_items WHERE id=?", (operation["work_item_id"],)
    ).fetchone()
    if row is None:
        raise ReconciliationError(f"work item missing: {operation['work_item_id']}")
    expected = operation["expected"]
    for key in ("status", "verdict", "claimed_by", "evidence_path", "updated_at"):
        _assert_equal(f"{row['id']}.{key}", row[key], expected.get(key))
    _assert_equal(
        f"{row['id']}.payload_sha256",
        sha256_bytes(str(row["payload_json"] or "{}")),
        expected["payload_sha256"],
    )
    return row


def apply_manifest(
    *,
    manifest_path: Path,
    expected_manifest_sha256: str,
    expected_db_file_sha256: str,
    expected_db_logical_sha256: str,
    expected_factory_off_sha256: str,
    snapshot_path: Path,
    receipt_path: Path,
) -> dict[str, Any]:
    """Apply an exact PLAN under one global lock and one DB transaction."""
    manifest_path = Path(manifest_path)
    snapshot_path = Path(snapshot_path)
    receipt_path = Path(receipt_path)
    manifest_sha = sha256_file(manifest_path)
    _assert_equal("manifest SHA-256", manifest_sha, expected_manifest_sha256.lower())
    manifest = _load_manifest(manifest_path)
    db_path = Path(manifest["database"]["path"])
    flag_path = Path(manifest["factory_off"]["path"])
    for label, cli_value, bound_value in (
        ("DB file SHA-256 argument", expected_db_file_sha256, manifest["database"]["file_sha256"]),
        ("DB logical SHA-256 argument", expected_db_logical_sha256, manifest["database"]["logical_sha256"]),
        ("FACTORY_OFF SHA-256 argument", expected_factory_off_sha256, manifest["factory_off"]["sha256"]),
    ):
        _assert_equal(label, cli_value.lower(), str(bound_value).lower())
    if receipt_path.exists():
        raise ReconciliationError(f"receipt path already exists: {receipt_path}")

    lock_path = path_for_factory_flag(flag_path)
    applied_at = utc_now()
    ledger_counts: Counter[str] = Counter()
    with FactoryMutationLock(lock_path, owner=f"mnt009_010_apply:{manifest['plan_id']}"):
        if not flag_path.is_file():
            raise ReconciliationError("FACTORY_OFF disappeared before apply")
        pre_file_sha = sha256_file(db_path)
        pre_logical_sha = sqlite_logical_sha256(db_path)
        pre_flag_sha = sha256_file(flag_path)
        _assert_equal("DB file SHA-256", pre_file_sha, expected_db_file_sha256.lower())
        _assert_equal("DB logical SHA-256", pre_logical_sha, expected_db_logical_sha256.lower())
        _assert_equal("FACTORY_OFF SHA-256", pre_flag_sha, expected_factory_off_sha256.lower())
        snapshot_sha = _snapshot_database(db_path, snapshot_path)
        # Backup is read-only; nevertheless re-check the exact pre-image before
        # opening the write transaction so a non-cooperating writer cannot hide
        # in the snapshot interval.
        _assert_equal("DB file SHA-256 after snapshot", sha256_file(db_path), pre_file_sha)
        _assert_equal(
            "DB logical SHA-256 after snapshot",
            sqlite_logical_sha256(db_path),
            pre_logical_sha,
        )

        conn = sqlite3.connect(db_path, timeout=30)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA busy_timeout=30000")
        try:
            conn.executescript("BEGIN IMMEDIATE;\n" + SCHEMA_SQL)
            for operation in manifest["evidence_binding_operations"]:
                row = _fetch_work_item(conn, operation)
                artifact = operation["artifact"]
                artifact_path = Path(artifact["path"])
                if not artifact_path.is_file():
                    raise ReconciliationError(f"bound artifact disappeared: {artifact_path}")
                _assert_equal(
                    f"artifact {artifact_path} SHA-256",
                    sha256_file(artifact_path),
                    artifact["sha256"],
                )
                cursor = conn.execute(
                    """
                    UPDATE work_items SET evidence_path=?, updated_at=?
                    WHERE id=? AND status=? AND verdict=? AND payload_json=?
                      AND updated_at=? AND evidence_path IS ?
                    """,
                    (
                        artifact["path"],
                        applied_at,
                        row["id"],
                        row["status"],
                        row["verdict"],
                        row["payload_json"],
                        row["updated_at"],
                        row["evidence_path"],
                    ),
                )
                if cursor.rowcount != 1:
                    raise ReconciliationError(f"evidence CAS lost: {row['id']}")
                detail = {
                    "manifest_sha256": manifest_sha,
                    "plan_id": manifest["plan_id"],
                    "artifact": artifact,
                    "claim_limit": operation["claim_limit"],
                    "original_payload_sha256": operation["expected"]["payload_sha256"],
                }
                conn.execute(
                    """
                    INSERT INTO work_item_transition_ledger(
                        idempotency_key, ts, work_item_id, action, from_status,
                        to_status, from_verdict, to_verdict, from_claimed_by,
                        to_claimed_by, reason, run_id, detail_json
                    ) VALUES (?, ?, ?, 'bind_existing_evidence', ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        operation["operation_id"], applied_at, row["id"],
                        row["status"], row["status"], row["verdict"], row["verdict"],
                        row["claimed_by"], row["claimed_by"],
                        "bound pre-existing artifact; no result reconstructed",
                        manifest["plan_id"], json.dumps(detail, sort_keys=True),
                    ),
                )
                conn.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                    "VALUES (?,'work_item',?,'mnt009_evidence_bound',?)",
                    (applied_at, row["id"], json.dumps(detail, sort_keys=True)),
                )
                ledger_counts["evidence_bindings"] += 1

            for operation in manifest["null_verdict_operations"]:
                row = _fetch_work_item(conn, operation)
                if row["verdict"] is not None:
                    raise ReconciliationError(f"NULL disposition target changed: {row['id']}")
                artifact = operation.get("artifact")
                if artifact is not None:
                    artifact_path = Path(artifact["path"])
                    if not artifact_path.is_file():
                        raise ReconciliationError(
                            f"bound NULL-disposition artifact disappeared: {artifact_path}"
                        )
                    _assert_equal(
                        f"artifact {artifact_path} SHA-256",
                        sha256_file(artifact_path),
                        artifact["sha256"],
                    )
                payload = json.loads(row["payload_json"] or "{}")
                payload["mnt009_legacy_disposition"] = {
                    **operation["legacy_disposition"],
                    "taxonomy_version": NULL_TAXONOMY_VERSION,
                    "applied_at": applied_at,
                    "plan_id": manifest["plan_id"],
                    "manifest_sha256": manifest_sha,
                    "original_payload_sha256": operation["expected"]["payload_sha256"],
                }
                updated_payload = json.dumps(payload, sort_keys=True)
                target = operation["target"]
                target_evidence_path = target.get("evidence_path", row["evidence_path"])
                cursor = conn.execute(
                    """
                    UPDATE work_items
                    SET status=?, verdict=?, evidence_path=?, payload_json=?, updated_at=?
                    WHERE id=? AND status=? AND verdict IS NULL AND payload_json=?
                      AND updated_at=? AND claimed_by IS ? AND evidence_path IS ?
                    """,
                    (
                        target["status"], target["verdict"], target_evidence_path,
                        updated_payload, applied_at,
                        row["id"], row["status"], row["payload_json"], row["updated_at"],
                        row["claimed_by"], row["evidence_path"],
                    ),
                )
                if cursor.rowcount != 1:
                    raise ReconciliationError(f"NULL disposition CAS lost: {row['id']}")
                detail = {
                    "manifest_sha256": manifest_sha,
                    "plan_id": manifest["plan_id"],
                    "legacy_disposition": operation["legacy_disposition"],
                    "original_payload_sha256": operation["expected"]["payload_sha256"],
                    "post_payload_sha256": sha256_bytes(updated_payload),
                    "evidence_path_before": row["evidence_path"],
                    "evidence_path_after": target_evidence_path,
                    "artifact": artifact,
                    "claim_limit": operation.get("claim_limit"),
                }
                conn.execute(
                    """
                    INSERT INTO work_item_transition_ledger(
                        idempotency_key, ts, work_item_id, action, from_status,
                        to_status, from_verdict, to_verdict, from_claimed_by,
                        to_claimed_by, reason, run_id, detail_json
                    ) VALUES (?, ?, ?, 'legacy_null_disposition', ?, ?, NULL, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        operation["operation_id"], applied_at, row["id"],
                        row["status"], target["status"], target["verdict"],
                        row["claimed_by"], row["claimed_by"],
                        "legacy DB-state disposition; not reconstructed test evidence",
                        manifest["plan_id"], json.dumps(detail, sort_keys=True),
                    ),
                )
                conn.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                    "VALUES (?,'work_item',?,'mnt009_null_disposition',?)",
                    (applied_at, row["id"], json.dumps(detail, sort_keys=True)),
                )
                ledger_counts["null_dispositions"] += 1
                if artifact is not None:
                    ledger_counts["evidence_bindings"] += 1

            for operation in manifest["parent_close_operations"]:
                parent = conn.execute(
                    "SELECT * FROM tasks WHERE id=?", (operation["parent_task_id"],)
                ).fetchone()
                if parent is None:
                    raise ReconciliationError(f"parent missing: {operation['parent_task_id']}")
                expected = operation["expected"]
                _assert_equal(f"{parent['id']}.status", parent["status"], expected["status"])
                _assert_equal(f"{parent['id']}.updated_at", parent["updated_at"], expected["updated_at"])
                result = farmctl.aggregate_finished_parent_cas(
                    db_path.parent.parent,
                    parent["id"],
                    source="mnt009_010_off_reconciliation",
                    conn=conn,
                    completed_at=applied_at,
                    run_id=manifest["plan_id"],
                    expected_parent_payload_sha256=expected["payload_sha256"],
                    expected_child_state_sha256=expected["child_state_sha256_after_mnt009"],
                    auto_enqueue=False,
                    factory_off=True,
                    ledger_detail={
                        "manifest_sha256": manifest_sha,
                        "plan_id": manifest["plan_id"],
                        "factory_off_sha256": pre_flag_sha,
                    },
                )
                if not result or not result.get("closed"):
                    raise ReconciliationError(
                        f"parent close refused: {parent['id']}: {result}"
                    )
                _assert_equal(
                    f"{parent['id']}.predicted_verdict",
                    result["verdict"],
                    operation["target"]["verdict"],
                )
                if result.get("auto_next") is not None:
                    raise ReconciliationError("OFF reconciliation attempted auto progression")
                ledger_counts["parent_closures"] += 1
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
        finally:
            conn.close()

        wal = checkpoint_wal(db_path)
        post_file_sha = sha256_file(db_path)
        post_logical_sha = sqlite_logical_sha256(db_path)
        if sha256_file(flag_path) != pre_flag_sha:
            raise ReconciliationError("FACTORY_OFF flag drifted during apply")
        receipt = {
            "schema_version": SCHEMA_VERSION,
            "mode": "APPLY_RECEIPT",
            "applied_at": applied_at,
            "plan_id": manifest["plan_id"],
            "manifest": {"path": str(manifest_path), "sha256": manifest_sha},
            "database": {
                "path": str(db_path),
                "pre_file_sha256": pre_file_sha,
                "pre_logical_sha256": pre_logical_sha,
                "post_file_sha256": post_file_sha,
                "post_logical_sha256": post_logical_sha,
                "wal_checkpoint": wal,
            },
            "factory_off": {"path": str(flag_path), "sha256": pre_flag_sha},
            "snapshot": {"path": str(snapshot_path), "sha256": snapshot_sha},
            "operation_counts": dict(sorted(ledger_counts.items())),
            "maintenance_status": {
                "MNT-009": {
                    "status": (
                        "PARTIAL"
                        if int(manifest["census"]["evidence_still_unbound"]) > 0
                        else "COMPLETED_RUNTIME"
                    ),
                    "null_verdict_scope": "COMPLETED_RUNTIME",
                    "existing_evidence_bindings": ledger_counts["evidence_bindings"],
                    "remaining_unbound_rows": int(
                        manifest["census"]["evidence_still_unbound"]
                    ),
                },
                "MNT-010": {
                    "status": "COMPLETED_RUNTIME",
                    "parent_closures": ledger_counts["parent_closures"],
                    "pass_progressions_deferred_factory_off": sum(
                        operation["target"]["verdict"] == "PASS"
                        for operation in manifest["parent_close_operations"]
                    ),
                },
            },
            "plan_census": manifest["census"],
            "evidence_statement": (
                "NULL migrations are legacy DB-state dispositions, not recreated "
                "test evidence. Evidence bindings reference only pre-existing, "
                "manifest-hashed artifacts."
            ),
            "auto_enqueue_during_factory_off": False,
        }
        write_json_atomic(receipt_path, receipt)
    return receipt


def _summary(plan: dict[str, Any]) -> dict[str, Any]:
    return {
        "mode": plan["mode"],
        "plan_id": plan["plan_id"],
        "apply_ready": plan["apply_ready"],
        "database": plan["database"],
        "factory_off": plan["factory_off"],
        "census": plan["census"],
        "maintenance_status": plan["maintenance_status"],
        "apply_scope_status": plan["apply_scope_status"],
        "blocked_counts": {
            key: len(value) for key, value in plan["blocked"].items()
        },
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", nargs="?", choices=("plan", "apply"), default="plan")
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--factory-off", type=Path, default=DEFAULT_FACTORY_OFF)
    parser.add_argument("--output", type=Path, help="PLAN manifest output path")
    parser.add_argument("--no-evidence-scan", action="store_true")
    parser.add_argument("--print-manifest", action="store_true")
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--expected-manifest-sha256")
    parser.add_argument("--expected-db-file-sha256")
    parser.add_argument("--expected-db-logical-sha256")
    parser.add_argument("--expected-factory-off-sha256")
    parser.add_argument("--snapshot", type=Path)
    parser.add_argument("--receipt", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "plan":
            plan = plan_reconciliation(
                args.db,
                args.factory_off,
                scan_evidence=not args.no_evidence_scan,
            )
            if args.output:
                write_json_atomic(args.output, plan)
            print(json.dumps(plan if args.print_manifest else _summary(plan), indent=2, sort_keys=True))
            return 0 if plan["apply_ready"] else 2
        required = {
            "--manifest": args.manifest,
            "--expected-manifest-sha256": args.expected_manifest_sha256,
            "--expected-db-file-sha256": args.expected_db_file_sha256,
            "--expected-db-logical-sha256": args.expected_db_logical_sha256,
            "--expected-factory-off-sha256": args.expected_factory_off_sha256,
            "--snapshot": args.snapshot,
            "--receipt": args.receipt,
        }
        missing = [name for name, value in required.items() if not value]
        if missing:
            raise ReconciliationError(f"apply requires: {', '.join(missing)}")
        receipt = apply_manifest(
            manifest_path=args.manifest,
            expected_manifest_sha256=args.expected_manifest_sha256,
            expected_db_file_sha256=args.expected_db_file_sha256,
            expected_db_logical_sha256=args.expected_db_logical_sha256,
            expected_factory_off_sha256=args.expected_factory_off_sha256,
            snapshot_path=args.snapshot,
            receipt_path=args.receipt,
        )
        print(json.dumps(receipt, indent=2, sort_keys=True))
        return 0
    except (OSError, sqlite3.Error, ValueError, ReconciliationError, RuntimeError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
