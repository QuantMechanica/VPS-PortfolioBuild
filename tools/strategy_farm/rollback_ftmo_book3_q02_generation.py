#!/usr/bin/env python3
"""Plan/apply rollback of one failed six-row FTMO Book-3 Q02 generation.

This controller is intentionally narrow.  It removes only the six work items
and six non-releasing holds created by one hash-bound prepare receipt after an
isolated runner failed before a final fidelity result.  MT5 reports, runner
receipts, harvested streams, snapshots, and logs are never removed or moved.

Dry-run is the default.  Apply requires the exact plan/file/DB/OFF/source
identities, creates an intent and SQLite snapshot without replacement, holds
the global Factory mutation lock, revalidates every full row preimage under
``BEGIN IMMEDIATE``, and verifies that the resulting logical database content
equals the original prepare pre-snapshot.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import os
import sqlite3
import sys
from pathlib import Path
from typing import Any, Iterable

try:
    import prepare_ftmo_book3_q02 as base
except ModuleNotFoundError:
    from tools.strategy_farm import prepare_ftmo_book3_q02 as base


SCHEMA_PLAN = "qm.ftmo-book3-q02-generation-rollback-plan/v1"
SCHEMA_RECEIPT = "qm.ftmo-book3-q02-generation-rollback-receipt/v1"
EXPECTED_RUNGS = ("R0", "J0", "R1", "J1", "R2", "J2")
WORK_ITEM_COLUMNS = (
    "id",
    "kind",
    "phase",
    "ea_id",
    "symbol",
    "setfile_path",
    "status",
    "verdict",
    "attempt_count",
    "parent_task_id",
    "evidence_path",
    "claimed_by",
    "payload_json",
    "created_at",
    "updated_at",
)
HOLD_COLUMNS = (
    "work_item_id",
    "hold_code",
    "reason",
    "active",
    "release_on_restart",
    "created_at",
    "updated_at",
    "released_at",
    "release_note",
)


class ContractError(RuntimeError):
    pass


def _canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def _canonical_sha(value: Any) -> str:
    return hashlib.sha256(_canonical_bytes(value)).hexdigest()


def _json_value(value: Any) -> Any:
    if isinstance(value, bytes):
        return {"$bytes_hex": value.hex()}
    if isinstance(value, float) and not math.isfinite(value):
        raise ContractError("database contains a non-finite float")
    return value


def _quote_identifier(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def _table_names(conn: sqlite3.Connection) -> list[str]:
    return [
        str(row[0])
        for row in conn.execute(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
        )
    ]


def _table_columns(conn: sqlite3.Connection, table: str) -> list[str]:
    return [
        str(row[1])
        for row in conn.execute(f"PRAGMA table_info({_quote_identifier(table)})")
    ]


def _logical_manifest_conn(
    conn: sqlite3.Connection, *, exclude_work_item_ids: set[str] | None = None
) -> dict[str, Any]:
    excluded = exclude_work_item_ids or set()
    tables: dict[str, Any] = {}
    for table in _table_names(conn):
        columns = _table_columns(conn, table)
        selected = ",".join(_quote_identifier(column) for column in columns)
        rows: list[list[Any]] = []
        for raw in conn.execute(f"SELECT {selected} FROM {_quote_identifier(table)}"):
            row = [_json_value(value) for value in raw]
            if table == "work_items" and row[columns.index("id")] in excluded:
                continue
            if table == "work_item_holds" and row[columns.index("work_item_id")] in excluded:
                continue
            rows.append(row)
        rows.sort(key=_canonical_bytes)
        schema_row = conn.execute(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name=?", (table,)
        ).fetchone()
        tables[table] = {
            "columns": columns,
            "row_count": len(rows),
            "rows_sha256": _canonical_sha(rows),
            "schema_sha256": _canonical_sha(str(schema_row[0] if schema_row else "")),
        }
    objects = [
        {
            "type": str(row[0]),
            "name": str(row[1]),
            "table": str(row[2]),
            "sql": str(row[3] or ""),
        }
        for row in conn.execute(
            "SELECT type,name,tbl_name,sql FROM sqlite_master "
            "WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name,tbl_name"
        )
    ]
    pragmas = {
        name: conn.execute(f"PRAGMA {name}").fetchone()[0]
        for name in ("application_id", "encoding", "page_size", "user_version")
    }
    return {"objects": objects, "pragmas": pragmas, "tables": tables}


def _logical_manifest(
    db: Path,
    *,
    exclude_work_item_ids: set[str] | None = None,
    immutable: bool = False,
) -> dict[str, Any]:
    if immutable:
        wal = Path(str(db) + "-wal")
        if wal.exists() and wal.stat().st_size:
            raise ContractError(f"historical SQLite snapshot has a non-empty WAL: {wal}")
        uri = db.resolve().as_uri() + "?mode=ro&immutable=1"
        conn = sqlite3.connect(uri, uri=True, timeout=30)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA query_only=ON")
    else:
        conn = base.connect_ro(db)
    with conn:
        return _logical_manifest_conn(conn, exclude_work_item_ids=exclude_work_item_ids)


def _strict_json(path: Path, label: str) -> tuple[dict[str, Any], str]:
    _resolved, data, digest, _identity = base._read_unaliased_regular_file_once(
        path, label
    )
    return base._strict_json_object(data, label), digest


def _file_artifact(path: Path, role: str) -> dict[str, Any]:
    if not path.is_file():
        return {"role": role, "path": str(path), "valid": False, "reason": "missing"}
    return {
        "role": role,
        "path": str(path),
        "bytes": path.stat().st_size,
        "sha256": base.sha256_file(path),
        "valid": True,
    }


def _tree_artifact(path: Path, role: str) -> dict[str, Any]:
    if not path.is_dir():
        return {"role": role, "path": str(path), "valid": False, "reason": "missing"}
    rows = [
        {
            "path": child.relative_to(path).as_posix(),
            "bytes": child.stat().st_size,
            "sha256": base.sha256_file(child),
        }
        for child in sorted(
            (candidate for candidate in path.rglob("*") if candidate.is_file()),
            key=lambda candidate: candidate.relative_to(path).as_posix().casefold(),
        )
    ]
    return {
        "role": role,
        "path": str(path),
        "file_count": len(rows),
        "sha256": _canonical_sha(rows),
        "valid": bool(rows),
    }


def _artifact_map(artifacts: Iterable[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for artifact in artifacts:
        role = str(artifact.get("role") or "")
        if not role or role in result:
            raise ContractError(f"artifact role must occur exactly once: {role!r}")
        result[role] = artifact
    return result


def _verify_artifacts(plan: dict[str, Any]) -> None:
    for expected in plan.get("artifacts") or []:
        path = Path(str(expected["path"]))
        actual = (
            _tree_artifact(path, str(expected["role"]))
            if "file_count" in expected
            else _file_artifact(path, str(expected["role"]))
        )
        if actual != expected:
            raise ContractError(
                f"artifact drift for {expected['role']}: expected={expected} actual={actual}"
            )


def _row_dict(
    conn: sqlite3.Connection, table: str, key_column: str, key: str
) -> dict[str, Any] | None:
    columns = _table_columns(conn, table)
    selected = ",".join(_quote_identifier(column) for column in columns)
    raw = conn.execute(
        f"SELECT {selected} FROM {_quote_identifier(table)} "
        f"WHERE {_quote_identifier(key_column)}=?",
        (key,),
    ).fetchone()
    return None if raw is None else dict(zip(columns, raw))


def _validate_preimage_columns(
    row: dict[str, Any], expected: tuple[str, ...], label: str
) -> None:
    if set(row) != set(expected) or len(row) != len(expected):
        raise ContractError(
            f"{label} columns mismatch: expected={list(expected)} actual={list(row)}"
        )


def _delete_full_preimage(
    conn: sqlite3.Connection,
    *,
    table: str,
    columns: tuple[str, ...],
    row: dict[str, Any],
) -> None:
    _validate_preimage_columns(row, columns, table)
    where = " AND ".join(f"{_quote_identifier(column)} IS ?" for column in columns)
    cursor = conn.execute(
        f"DELETE FROM {_quote_identifier(table)} WHERE {where}",
        tuple(row[column] for column in columns),
    )
    if cursor.rowcount != 1:
        raise ContractError(f"{table} full-preimage delete CAS failed")


def _source_identity(repo: Path, source_commit: str, paths: list[Path]) -> dict[str, Any]:
    resolved = base._git(repo, "rev-parse", f"{source_commit}^{{commit}}").lower()
    head = base._git(repo, "rev-parse", "HEAD").lower()
    if resolved != source_commit.lower() or head != resolved:
        raise ContractError(
            f"source commit/HEAD mismatch: requested={source_commit} resolved={resolved} head={head}"
        )
    relative = [str(path.resolve().relative_to(repo.resolve())).replace("\\", "/") for path in paths]
    status = base._git(repo, "status", "--porcelain=v1", "--", *relative)
    if status:
        raise ContractError(f"rollback runtime sources are dirty: {status.splitlines()}")
    return {
        "source_commit": resolved,
        "head_commit": head,
        "scoped_status": [],
    }


def _validate_output_paths(
    *,
    plan: dict[str, Any],
    manifest_path: Path,
    snapshot_path: Path,
    receipt_path: Path,
) -> None:
    intent_path = base._intent_path(receipt_path)
    runtime_root = (base.DEFAULT_ARTIFACT_ROOT / "runtime").resolve()
    outputs = (snapshot_path, receipt_path, intent_path)
    if snapshot_path.suffix.lower() not in {".sqlite", ".db"}:
        raise ContractError("rollback snapshot must use a SQLite file suffix")
    if receipt_path.suffix.lower() != ".json":
        raise ContractError("rollback receipt must use .json")
    for output in outputs:
        if output.resolve().parent != runtime_root:
            raise ContractError(
                f"rollback output must be a direct child of {runtime_root}: {output}"
            )
    protected_files = {
        base._path_identity(Path(str(plan["db"]["path"]))),
        base._path_identity(Path(str(plan["factory_off"]["path"]))),
        base._path_identity(manifest_path),
    }
    protected_files.update(
        base._path_identity(Path(str(artifact["path"])))
        for artifact in plan.get("artifacts") or []
        if "file_count" not in artifact
    )
    protected_trees = [
        Path(str(artifact["path"])).resolve()
        for artifact in plan.get("artifacts") or []
        if "file_count" in artifact
    ]
    for output in outputs:
        if base._path_identity(output) in protected_files:
            raise ContractError(f"rollback output overlaps a protected file: {output}")
        resolved = output.resolve()
        for tree in protected_trees:
            try:
                resolved.relative_to(tree)
            except ValueError:
                continue
            raise ContractError(
                f"rollback output is inside a bound artifact tree: {output}"
            )


def _plan_core(plan: dict[str, Any]) -> dict[str, Any]:
    core = copy.deepcopy(plan)
    core.pop("generated_at_utc", None)
    core.pop("plan_id", None)
    return core


def _assign_plan_id(plan: dict[str, Any]) -> None:
    plan["plan_id"] = _canonical_sha(_plan_core(plan))


def _validate_plan_id(plan: dict[str, Any]) -> None:
    actual = _canonical_sha(_plan_core(plan))
    if plan.get("plan_id") != actual:
        raise ContractError(
            f"plan_id mismatch: expected={plan.get('plan_id')} actual={actual}"
        )


def _validate_prepare_evidence(
    prepare_manifest: dict[str, Any],
    prepare_manifest_path: Path,
    prepare_manifest_sha: str,
    prepare_receipt: dict[str, Any],
) -> list[str]:
    errors: list[str] = []
    if prepare_manifest.get("schema") != base.SCHEMA_PREPARE:
        errors.append("prepare manifest schema mismatch")
    if prepare_receipt.get("schema") != base.SCHEMA_RECEIPT:
        errors.append("prepare receipt schema mismatch")
    try:
        # Historical evidence must remain structurally verifiable after the
        # repair is committed.  The old prepare plan already binds its own
        # source commit and hashes; requiring those old sources to equal the
        # *current* HEAD would make a safe rollback impossible by construction.
        base._validate_prepare_operations(
            prepare_manifest, validate_live_source=False
        )
        base._validate_plan_id(prepare_manifest)
    except Exception as exc:
        errors.append(f"prepare manifest invalid: {exc}")
    if prepare_receipt.get("action") != "prepare" or prepare_receipt.get("mode") != "apply":
        errors.append("prepare receipt action/mode mismatch")
    if prepare_receipt.get("plan_id") != prepare_manifest.get("plan_id"):
        errors.append("prepare receipt plan_id mismatch")
    if os.path.normcase(os.path.abspath(str(prepare_receipt.get("manifest_path") or ""))) != os.path.normcase(os.path.abspath(str(prepare_manifest_path))):
        errors.append("prepare receipt manifest path mismatch")
    if str(prepare_receipt.get("manifest_sha256") or "").lower() != prepare_manifest_sha:
        errors.append("prepare receipt manifest SHA-256 mismatch")
    expected_ids = [str(operation.get("work_item_id") or "") for operation in prepare_manifest.get("operations") or []]
    receipt_ids = [str(row.get("id") or "") for row in prepare_receipt.get("created_work_items") or []]
    hold_ids = [str(row.get("work_item_id") or "") for row in prepare_receipt.get("created_holds") or []]
    if receipt_ids != expected_ids or hold_ids != expected_ids:
        errors.append("prepare receipt exact-six topology mismatch")
    return errors


def _validate_failed_runner_evidence(
    failed_runner: dict[str, Any],
    prepare_manifest: dict[str, Any],
    prepare_receipt: dict[str, Any],
) -> list[str]:
    errors: list[str] = []
    operations = prepare_manifest.get("operations") or []
    if not operations:
        return ["prepare manifest has no R0 operation"]
    r0 = operations[0]
    try:
        r0_payload = json.loads(str(r0["payload_json"]))
    except Exception:
        return ["prepare R0 payload is invalid"]
    preflight = failed_runner.get("preflight") or {}
    pre_work = preflight.get("work_item") or {}
    source_binding = preflight.get("source_binding") or {}
    runtime_sources = source_binding.get("runtime_sources") or {}
    execution_inputs = preflight.get("execution_inputs") or {}
    checks = {
        "runner schema_version": (failed_runner.get("schema_version"), 1),
        "runner mode": (failed_runner.get("mode"), "apply"),
        "runner state": (failed_runner.get("state"), "completed"),
        "runner success": (failed_runner.get("success"), False),
        "runner terminal": (failed_runner.get("terminal"), base.TERMINAL),
        "runner R0 id": (failed_runner.get("work_item_id"), r0.get("work_item_id")),
        "runner OFF hash": (
            failed_runner.get("factory_off_sha256"),
            prepare_receipt.get("factory_off_sha256"),
        ),
        "runner preflight R0 id": (
            preflight.get("work_item_id"),
            r0.get("work_item_id"),
        ),
        "runner preflight rung": (pre_work.get("measurement_rung"), "R0"),
        "runner preflight sequence": (pre_work.get("measurement_sequence"), 0),
        "runner preflight payload hash": (
            pre_work.get("payload_sha256"),
            hashlib.sha256(str(r0.get("payload_json") or "").encode("utf-8")).hexdigest(),
        ),
        "runner authoritative commit": (
            source_binding.get("authoritative_source_commit"),
            (prepare_manifest.get("git") or {}).get("authoritative_source_commit"),
        ),
        "runner controller commit": (
            source_binding.get("controller_head_commit"),
            (prepare_manifest.get("git") or {}).get("controller_head_commit"),
        ),
        "runner runtime-source bundle": (
            runtime_sources.get("canonical_sha256"),
            r0_payload.get("runtime_source_artifacts_sha256"),
        ),
        "runner execution-input bundle": (
            execution_inputs.get("canonical_sha256"),
            r0_payload.get("execution_input_artifacts_sha256"),
        ),
        "runner worker exit": (failed_runner.get("worker_exit_code"), 1),
    }
    for label, (actual, expected) in checks.items():
        if actual != expected:
            errors.append(f"{label} mismatch: expected={expected} actual={actual}")
    success_checks = failed_runner.get("success_checks") or {}
    expected_success_checks = {
        "execution_inputs_unchanged": True,
        "fidelity_receipt_unchanged": True,
        "payload_contract_revalidated": False,
        "post_run_stream_valid": True,
        "process_tree_quiescent": True,
        "runtime_sources_unchanged": True,
        "work_item_done": False,
        "work_item_evidence_valid": False,
        "work_item_pass": False,
        "work_item_unclaimed": True,
        "worker_exit_code_zero": False,
    }
    if success_checks != expected_success_checks:
        errors.append("failed runner success-check taxonomy mismatch")
    payload_revalidation = failed_runner.get("payload_contract_revalidation") or {}
    if (
        payload_revalidation.get("valid") is not False
        or payload_revalidation.get("changed_immutable_keys") != ["from_date"]
        or payload_revalidation.get("pre_payload_sha256")
        != pre_work.get("payload_sha256")
    ):
        errors.append("failed runner payload-drift signature mismatch")
    post_work = failed_runner.get("post_work_item") or {}
    if {
        key: post_work.get(key)
        for key in ("id", "status", "verdict", "claimed_by", "evidence_path")
    } != {
        "id": r0.get("work_item_id"),
        "status": "pending",
        "verdict": None,
        "claimed_by": None,
        "evidence_path": None,
    }:
        errors.append("failed runner post-work-item signature mismatch")
    stream = failed_runner.get("post_run_stream") or {}
    harvested = stream.get("harvested") or {}
    if (
        stream.get("valid") is not True
        or int(harvested.get("lines") or 0) <= 0
        or not str(harvested.get("sha256") or "")
    ):
        errors.append("failed runner harvested-stream signature mismatch")
    if (
        failed_runner.get("autotrading_touched") is not False
        or failed_runner.get("live_scope_touched") is not False
    ):
        errors.append("failed runner touched protected live scope")
    return errors


def build_plan(
    *,
    prepare_manifest_path: Path,
    prepare_receipt_path: Path,
    prepare_snapshot_path: Path,
    failed_runner_receipt_path: Path,
    source_commit: str,
    root: Path = base.DEFAULT_ROOT,
    repo: Path = base.DEFAULT_REPO,
) -> dict[str, Any]:
    errors: list[str] = []
    db = root / "state/farm_state.sqlite"
    flag = root / "state/FACTORY_OFF.flag"
    controller = Path(__file__).resolve()
    lock_source = repo / "tools/strategy_farm/factory_mutation_lock.py"
    process_source = repo / "tools/strategy_farm/isolated_work_item_runner.py"
    source_paths = [
        controller,
        Path(base.__file__).resolve(),
        lock_source,
        process_source,
    ]
    if base._path_identity(root) != base._path_identity(base.DEFAULT_ROOT):
        errors.append(f"canonical root mismatch: expected={base.DEFAULT_ROOT} actual={root}")
    if base._path_identity(repo) != base._path_identity(base.DEFAULT_REPO):
        errors.append(f"canonical repo mismatch: expected={base.DEFAULT_REPO} actual={repo}")
    try:
        source = _source_identity(repo, source_commit, source_paths)
    except Exception as exc:
        source = {"source_commit": source_commit.lower()}
        errors.append(f"source identity failed: {exc}")
    try:
        prepare_manifest, prepare_manifest_sha = _strict_json(
            prepare_manifest_path, "prepare manifest"
        )
        prepare_receipt, _prepare_receipt_sha = _strict_json(
            prepare_receipt_path, "prepare receipt"
        )
        failed_runner, _runner_receipt_sha = _strict_json(
            failed_runner_receipt_path, "failed runner receipt"
        )
    except Exception as exc:
        prepare_manifest, prepare_receipt, failed_runner = {}, {}, {}
        prepare_manifest_sha = ""
        errors.append(f"evidence load failed: {exc}")

    errors.extend(
        _validate_prepare_evidence(
            prepare_manifest,
            prepare_manifest_path,
            prepare_manifest_sha,
            prepare_receipt,
        )
        if prepare_manifest
        else []
    )
    operations: list[dict[str, Any]] = []
    expected_ids = [
        str(operation.get("work_item_id") or "")
        for operation in prepare_manifest.get("operations") or []
    ]
    if len(expected_ids) != 6 or len(set(expected_ids)) != 6:
        errors.append("rollback requires exactly six unique prepared work item IDs")
    if failed_runner:
        errors.extend(
            _validate_failed_runner_evidence(
                failed_runner, prepare_manifest, prepare_receipt
            )
        )

    artifacts: list[dict[str, Any]] = [
        _file_artifact(controller, "rollback_controller"),
        _file_artifact(Path(base.__file__).resolve(), "prepare_controller"),
        _file_artifact(lock_source, "factory_mutation_lock"),
        _file_artifact(process_source, "isolated_runner"),
        _file_artifact(prepare_manifest_path, "prepare_manifest"),
        _file_artifact(prepare_receipt_path, "prepare_receipt"),
        _file_artifact(prepare_snapshot_path, "prepare_pre_snapshot"),
        _file_artifact(failed_runner_receipt_path, "failed_runner_receipt"),
    ]
    if failed_runner:
        runner_snapshot = Path(str(failed_runner.get("snapshot_path") or ""))
        worker_log = Path(str(failed_runner.get("worker_log_path") or ""))
        harvest = Path(str((failed_runner.get("post_run_stream") or {}).get("target") or ""))
        artifacts.extend(
            [
                _file_artifact(runner_snapshot, "failed_runner_pre_snapshot"),
                _file_artifact(worker_log, "failed_runner_worker_log"),
                _file_artifact(harvest, "failed_runner_harvest"),
            ]
        )
        # The canonical report tree is anchored by the prepared operation, not
        # by transient worker fields.
        if expected_ids:
            artifacts.append(
                _tree_artifact(
                    base.DEFAULT_REPORT_ROOT / expected_ids[0], "failed_runner_report_tree"
                )
            )
        if runner_snapshot.is_file() and str(failed_runner.get("snapshot_sha256") or "").lower() != base.sha256_file(runner_snapshot):
            errors.append("failed runner snapshot SHA-256 mismatch")
        if worker_log.is_file() and str(failed_runner.get("worker_log_sha256") or "").lower() != base.sha256_file(worker_log):
            errors.append("failed runner worker-log SHA-256 mismatch")
        harvested = (failed_runner.get("post_run_stream") or {}).get("harvested") or {}
        if harvest.is_file() and str(harvested.get("sha256") or "").lower() != base.sha256_file(harvest):
            errors.append("failed runner harvest SHA-256 mismatch")
    prepare_snapshot_binding = prepare_receipt.get("snapshot") or {}
    if base._path_identity(Path(str(prepare_snapshot_binding.get("path") or ""))) != base._path_identity(prepare_snapshot_path):
        errors.append("prepare receipt snapshot path mismatch")
    if prepare_snapshot_path.is_file() and str(prepare_snapshot_binding.get("sha256") or "").lower() != base.sha256_file(prepare_snapshot_path):
        errors.append("prepare receipt snapshot SHA-256 mismatch")
    if any(artifact.get("valid") is not True for artifact in artifacts):
        errors.append("one or more rollback evidence artifacts are missing/invalid")

    factory_off = {
        "path": str(flag),
        "exists": flag.is_file(),
        "sha256": base.sha256_file(flag) if flag.is_file() else None,
    }
    if not factory_off["exists"]:
        errors.append("FACTORY_OFF is missing")
    lock_path = base.path_for_factory_flag(flag)
    if lock_path.exists():
        errors.append(f"Factory mutation lock already exists: {lock_path}")
    processes = base._factory_processes()
    if processes:
        errors.append(f"factory process census is not empty: {len(processes)}")

    db_state = ""
    baseline_manifest: dict[str, Any] = {}
    current_without_generation: dict[str, Any] = {}
    if not db.is_file():
        errors.append(f"database missing: {db}")
    elif not prepare_snapshot_path.is_file():
        errors.append(f"prepare pre-snapshot missing: {prepare_snapshot_path}")
    elif expected_ids:
        try:
            db_state = base.sqlite_state_sha256(db)
            if str(failed_runner.get("post_db_state_sha256") or "").lower() != db_state:
                errors.append("current DB state does not match failed runner post-state")
            baseline_manifest = _logical_manifest(
                prepare_snapshot_path, immutable=True
            )
            current_without_generation = _logical_manifest(
                db, exclude_work_item_ids=set(expected_ids)
            )
            if current_without_generation != baseline_manifest:
                errors.append(
                    "database differs from prepare pre-snapshot outside the exact six-row generation"
                )
            with base.connect_ro(db) as conn:
                receipt_work_by_id = {
                    str(row.get("id") or ""): row
                    for row in prepare_receipt.get("created_work_items") or []
                }
                receipt_hold_by_id = {
                    str(row.get("work_item_id") or ""): row
                    for row in prepare_receipt.get("created_holds") or []
                }
                for index, (expected_rung, work_id) in enumerate(
                    zip(EXPECTED_RUNGS, expected_ids)
                ):
                    prepared_operation = (
                        prepare_manifest.get("operations") or []
                    )[index]
                    work = _row_dict(conn, "work_items", "id", work_id)
                    hold = _row_dict(
                        conn, "work_item_holds", "work_item_id", work_id
                    )
                    if work is None or hold is None:
                        errors.append(f"generation row/hold missing: {work_id}")
                        continue
                    _validate_preimage_columns(work, WORK_ITEM_COLUMNS, "work_items")
                    _validate_preimage_columns(hold, HOLD_COLUMNS, "work_item_holds")
                    try:
                        payload = json.loads(str(work["payload_json"]))
                    except Exception:
                        payload = {}
                    if payload.get("measurement_contract") != base.FIDELITY_MEASUREMENT_CONTRACT:
                        errors.append(f"measurement contract mismatch: {work_id}")
                    if payload.get("measurement_rung") != expected_rung or payload.get("measurement_sequence") != index:
                        errors.append(f"measurement rung/sequence mismatch: {work_id}")
                    if hold.get("hold_code") != base.HOLD_CODE or hold.get("active") != 1 or hold.get("release_on_restart") != 0:
                        errors.append(f"hold contract mismatch: {work_id}")
                    immutable_expected = {
                        "id": work_id,
                        "kind": prepared_operation.get("kind"),
                        "phase": prepared_operation.get("phase"),
                        "ea_id": prepared_operation.get("ea_id"),
                        "symbol": prepared_operation.get("symbol"),
                        "setfile_path": prepared_operation.get("setfile_path"),
                        "parent_task_id": None,
                        "created_at": (
                            receipt_work_by_id.get(work_id) or {}
                        ).get("created_at"),
                    }
                    for key, expected in immutable_expected.items():
                        if work.get(key) != expected:
                            errors.append(
                                f"work item immutable provenance mismatch for {work_id}:{key}"
                            )
                    if work.get("attempt_count") != 0:
                        errors.append(f"work item attempt_count drift: {work_id}")
                    if index == 0:
                        runner_post = failed_runner.get("post_work_item") or {}
                        for key in (
                            "id",
                            "status",
                            "verdict",
                            "claimed_by",
                            "evidence_path",
                            "updated_at",
                        ):
                            if work.get(key) != runner_post.get(key):
                                errors.append(
                                    f"R0 row does not match failed runner postimage for {key}"
                                )
                        payload_sha = hashlib.sha256(
                            str(work["payload_json"]).encode("utf-8")
                        ).hexdigest()
                        if payload_sha != str(
                            failed_runner.get("post_payload_sha256") or ""
                        ).lower():
                            errors.append("R0 payload does not match failed runner postimage")
                        if (
                            payload.get("p2_prescreen_done") is not True
                            or payload.get("p2_run_stage") != "full_pending"
                            or not payload.get("p2_prescreen_evidence_path")
                        ):
                            errors.append("R0 is not the expected prescreen-PASS requeue state")
                    else:
                        created = receipt_work_by_id.get(work_id) or {}
                        for key in (
                            "id",
                            "status",
                            "verdict",
                            "claimed_by",
                            "created_at",
                            "updated_at",
                        ):
                            if work.get(key) != created.get(key):
                                errors.append(
                                    f"untouched work item differs from prepare receipt for {work_id}:{key}"
                                )
                        if work.get("evidence_path") is not None or work.get("attempt_count") != 0:
                            errors.append(f"untouched work item has runtime state: {work_id}")
                        manifest_payload = str(
                            prepared_operation.get("payload_json") or ""
                        )
                        if work.get("payload_json") != manifest_payload:
                            errors.append(f"untouched work item payload drift: {work_id}")
                    if hold != receipt_hold_by_id.get(work_id):
                        errors.append(f"hold differs from prepare receipt: {work_id}")
                    operations.append(
                        {
                            "sequence": index,
                            "measurement_rung": expected_rung,
                            "work_item_id": work_id,
                            "work_item_preimage": work,
                            "hold_preimage": hold,
                        }
                    )
        except Exception as exc:
            errors.append(f"database preimage analysis failed: {exc}")

    plan: dict[str, Any] = {
        "schema": SCHEMA_PLAN,
        "mode": "dry-run",
        "generated_at_utc": base.utc_now(),
        "root": str(root),
        "repo": str(repo),
        "db": {"path": str(db), "logical_state_sha256": db_state},
        "factory_off": factory_off,
        "source": source,
        "prepare_plan_id": prepare_manifest.get("plan_id"),
        "prepare_snapshot_baseline_manifest_sha256": _canonical_sha(baseline_manifest),
        "current_without_generation_manifest_sha256": _canonical_sha(
            current_without_generation
        ),
        "factory_processes": processes,
        "artifacts": artifacts,
        "operation_count": len(operations),
        "operations": operations,
        "safety": {
            "deletes_only_exact_six_work_items_and_six_holds": True,
            "preserves_all_runtime_artifacts": True,
            "factory_remains_off": True,
            "runs_mt5": False,
        },
        "errors": errors,
        "valid": not errors and len(operations) == 6,
    }
    _assign_plan_id(plan)
    return plan


def _load_plan(path: Path, expected_sha256: str) -> tuple[dict[str, Any], str]:
    plan, actual = _strict_json(path, "rollback manifest")
    if actual.lower() != expected_sha256.lower():
        raise ContractError(
            f"manifest SHA-256 mismatch: expected={expected_sha256} actual={actual}"
        )
    if plan.get("schema") != SCHEMA_PLAN or plan.get("valid") is not True:
        raise ContractError("rollback manifest schema/validity mismatch")
    _validate_plan_id(plan)
    if plan.get("operation_count") != 6 or len(plan.get("operations") or []) != 6:
        raise ContractError("rollback manifest is not an exact six-row generation")
    if [operation.get("measurement_rung") for operation in plan["operations"]] != list(EXPECTED_RUNGS):
        raise ContractError("rollback manifest rung order mismatch")
    return plan, actual


def apply_plan(
    *,
    manifest_path: Path,
    expected_manifest_sha256: str,
    confirm_plan_id: str,
    expected_factory_off_sha256: str,
    expected_db_state_sha256: str,
    expected_source_commit: str,
    snapshot_path: Path,
    receipt_path: Path,
) -> dict[str, Any]:
    plan, manifest_sha = _load_plan(manifest_path, expected_manifest_sha256)
    base._assert_equal("confirmed plan id", confirm_plan_id, plan["plan_id"])
    base._assert_equal(
        "FACTORY_OFF argument",
        expected_factory_off_sha256,
        plan["factory_off"]["sha256"],
    )
    base._assert_equal(
        "DB state argument", expected_db_state_sha256, plan["db"]["logical_state_sha256"]
    )
    base._assert_equal(
        "source commit argument", expected_source_commit, plan["source"]["source_commit"]
    )
    artifact_map = _artifact_map(plan.get("artifacts") or [])
    required_roles = {
        "rollback_controller",
        "prepare_controller",
        "factory_mutation_lock",
        "isolated_runner",
        "prepare_manifest",
        "prepare_receipt",
        "prepare_pre_snapshot",
        "failed_runner_receipt",
        "failed_runner_pre_snapshot",
        "failed_runner_worker_log",
        "failed_runner_harvest",
        "failed_runner_report_tree",
    }
    if set(artifact_map) != required_roles:
        raise ContractError(
            "rollback manifest artifact role set is not exact: "
            f"expected={sorted(required_roles)} actual={sorted(artifact_map)}"
        )
    rebuilt = build_plan(
        prepare_manifest_path=Path(artifact_map["prepare_manifest"]["path"]),
        prepare_receipt_path=Path(artifact_map["prepare_receipt"]["path"]),
        prepare_snapshot_path=Path(artifact_map["prepare_pre_snapshot"]["path"]),
        failed_runner_receipt_path=Path(
            artifact_map["failed_runner_receipt"]["path"]
        ),
        source_commit=expected_source_commit,
        root=Path(str(plan["root"])),
        repo=Path(str(plan["repo"])),
    )
    if rebuilt.get("valid") is not True:
        raise ContractError(
            f"apply-time rollback plan regeneration failed: {rebuilt.get('errors')}"
        )
    if _plan_core(rebuilt) != _plan_core(plan):
        raise ContractError("apply manifest differs from an exact live regeneration")
    _validate_output_paths(
        plan=plan,
        manifest_path=manifest_path,
        snapshot_path=snapshot_path,
        receipt_path=receipt_path,
    )
    db = Path(str(plan["db"]["path"]))
    flag = Path(str(plan["factory_off"]["path"]))
    repo = Path(str(plan["repo"]))
    controller = Path(__file__).resolve()
    source_paths = [
        controller,
        Path(base.__file__).resolve(),
        repo / "tools/strategy_farm/factory_mutation_lock.py",
        repo / "tools/strategy_farm/isolated_work_item_runner.py",
    ]
    _source_identity(repo, expected_source_commit, source_paths)
    _verify_artifacts(plan)
    intent_path, intent_sha = base._reserve_mutation_outputs(
        action="rollback_failed_generation",
        plan_id=plan["plan_id"],
        manifest_path=manifest_path,
        manifest_sha256=manifest_sha,
        snapshot_path=snapshot_path,
        receipt_path=receipt_path,
        db_path=db,
        flag_path=flag,
    )
    lock_path = base.path_for_factory_flag(flag)
    with base.FactoryMutationLock(
        lock_path, owner=f"ftmo_book3_q02_rollback:{plan['plan_id']}"
    ):
        base._assert_equal(
            "FACTORY_OFF SHA-256", expected_factory_off_sha256, base.sha256_file(flag)
        )
        base._assert_equal(
            "DB logical state", expected_db_state_sha256, base.sqlite_state_sha256(db)
        )
        _source_identity(repo, expected_source_commit, source_paths)
        _verify_artifacts(plan)
        if base._factory_processes():
            raise ContractError("factory process census is not empty")
        snapshot_sha = base.sqlite_snapshot(db, snapshot_path)
        base._assert_equal(
            "DB state after snapshot", expected_db_state_sha256, base.sqlite_state_sha256(db)
        )
        applied_at = base.utc_now()
        conn = sqlite3.connect(db, timeout=30)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("PRAGMA busy_timeout=30000")
            conn.execute("BEGIN IMMEDIATE")
            base._assert_equal(
                "transaction DB preimage",
                expected_db_state_sha256,
                hashlib.sha256(conn.serialize()).hexdigest(),
            )
            ids = {str(operation["work_item_id"]) for operation in plan["operations"]}
            current_without = _logical_manifest_conn(
                conn, exclude_work_item_ids=ids
            )
            base._assert_equal(
                "transaction unaffected logical manifest",
                plan["prepare_snapshot_baseline_manifest_sha256"],
                _canonical_sha(current_without),
            )
            for operation in plan["operations"]:
                work_id = str(operation["work_item_id"])
                current_work = _row_dict(conn, "work_items", "id", work_id)
                current_hold = _row_dict(
                    conn, "work_item_holds", "work_item_id", work_id
                )
                if current_work != operation["work_item_preimage"]:
                    raise ContractError(f"work item full-preimage drift: {work_id}")
                if current_hold != operation["hold_preimage"]:
                    raise ContractError(f"hold full-preimage drift: {work_id}")
                _delete_full_preimage(
                    conn,
                    table="work_item_holds",
                    columns=HOLD_COLUMNS,
                    row=operation["hold_preimage"],
                )
                _delete_full_preimage(
                    conn,
                    table="work_items",
                    columns=WORK_ITEM_COLUMNS,
                    row=operation["work_item_preimage"],
                )
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
        finally:
            conn.close()
        base._assert_equal(
            "FACTORY_OFF post SHA-256",
            expected_factory_off_sha256,
            base.sha256_file(flag),
        )
        _verify_artifacts(plan)
        post_manifest = _logical_manifest(db)
        base._assert_equal(
            "post logical database content",
            plan["prepare_snapshot_baseline_manifest_sha256"],
            _canonical_sha(post_manifest),
        )
        post_state = base.sqlite_state_sha256(db)
        receipt = {
            "schema": SCHEMA_RECEIPT,
            "action": "rollback_failed_generation",
            "mode": "apply",
            "receipt_id": f"ftmo-book3-q02-generation-rollback-{plan['plan_id']}",
            "applied_at_utc": applied_at,
            "plan_id": plan["plan_id"],
            "manifest_path": str(manifest_path),
            "manifest_sha256": manifest_sha,
            "mutation_intent": {"path": str(intent_path), "sha256": intent_sha},
            "factory_off_sha256": expected_factory_off_sha256.lower(),
            "pre_db_state_sha256": expected_db_state_sha256.lower(),
            "post_db_state_sha256": post_state,
            "post_logical_manifest_sha256": _canonical_sha(post_manifest),
            "snapshot": {"path": str(snapshot_path), "sha256": snapshot_sha},
            "deleted_work_items": [
                operation["work_item_preimage"] for operation in plan["operations"]
            ],
            "deleted_holds": [
                operation["hold_preimage"] for operation in plan["operations"]
            ],
            "preserved_artifacts": plan["artifacts"],
            "factory_remains_off": flag.is_file(),
            "runs_mt5": False,
        }
        base._write_new_json(receipt_path, receipt)
        return receipt


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=base.DEFAULT_ROOT)
    parser.add_argument("--repo", type=Path, default=base.DEFAULT_REPO)
    parser.add_argument("--prepare-manifest", type=Path)
    parser.add_argument("--prepare-receipt", type=Path)
    parser.add_argument("--prepare-snapshot", type=Path)
    parser.add_argument("--failed-runner-receipt", type=Path)
    parser.add_argument("--source-commit")
    parser.add_argument("--plan-out", type=Path)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--expected-manifest-sha256")
    parser.add_argument("--confirm-plan-id")
    parser.add_argument("--expected-factory-off-sha256")
    parser.add_argument("--expected-db-state-sha256")
    parser.add_argument("--expected-source-commit")
    parser.add_argument("--snapshot", type=Path)
    parser.add_argument("--receipt", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if not args.apply:
        required = {
            "--prepare-manifest": args.prepare_manifest,
            "--prepare-receipt": args.prepare_receipt,
            "--prepare-snapshot": args.prepare_snapshot,
            "--failed-runner-receipt": args.failed_runner_receipt,
            "--source-commit": args.source_commit,
        }
        missing = [name for name, value in required.items() if value in (None, "")]
        if missing:
            raise ContractError(
                f"dry-run missing required arguments: {', '.join(missing)}"
            )
        plan = build_plan(
            prepare_manifest_path=args.prepare_manifest,
            prepare_receipt_path=args.prepare_receipt,
            prepare_snapshot_path=args.prepare_snapshot,
            failed_runner_receipt_path=args.failed_runner_receipt,
            source_commit=args.source_commit,
            root=args.root,
            repo=args.repo,
        )
        if args.plan_out:
            base._write_new_json(args.plan_out, plan)
        print(json.dumps(plan, indent=2, ensure_ascii=False, sort_keys=True))
        return 0 if plan["valid"] else 2
    required = {
        "--manifest": args.manifest,
        "--expected-manifest-sha256": args.expected_manifest_sha256,
        "--confirm-plan-id": args.confirm_plan_id,
        "--expected-factory-off-sha256": args.expected_factory_off_sha256,
        "--expected-db-state-sha256": args.expected_db_state_sha256,
        "--expected-source-commit": args.expected_source_commit,
        "--snapshot": args.snapshot,
        "--receipt": args.receipt,
    }
    missing = [name for name, value in required.items() if value in (None, "")]
    if missing:
        raise ContractError(f"apply missing required arguments: {', '.join(missing)}")
    receipt = apply_plan(
        manifest_path=args.manifest,
        expected_manifest_sha256=args.expected_manifest_sha256,
        confirm_plan_id=args.confirm_plan_id,
        expected_factory_off_sha256=args.expected_factory_off_sha256,
        expected_db_state_sha256=args.expected_db_state_sha256,
        expected_source_commit=args.expected_source_commit,
        snapshot_path=args.snapshot,
        receipt_path=args.receipt,
    )
    print(json.dumps(receipt, indent=2, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ContractError, base.ContractError) as exc:
        print(
            json.dumps({"error": str(exc), "fail_closed": True}, sort_keys=True),
            file=sys.stderr,
        )
        raise SystemExit(2)
