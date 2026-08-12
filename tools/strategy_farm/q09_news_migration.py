#!/usr/bin/env python3
"""Plan and apply the additive Q09_NEWS legacy qualification overlay.

The default behaviour is read-only.  ``apply`` prints a WhatIf result unless
``--apply``, the exact plan hash, an explicit SQLite snapshot path, and the
exclusive-database acknowledgement are all supplied.  No legacy work-item
verdict or portfolio-candidate state is ever updated.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from q09_news_contract import canonical_json_bytes, sha256_file
    from q09_news_schema import (
        CONTRACT_VERSION,
        append_qualification,
        ensure_schema,
        protected_legacy_sha256,
    )
    from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag
except ModuleNotFoundError:
    from tools.strategy_farm.q09_news_contract import canonical_json_bytes, sha256_file
    from tools.strategy_farm.q09_news_schema import (
        CONTRACT_VERSION,
        append_qualification,
        ensure_schema,
        protected_legacy_sha256,
    )
    from tools.strategy_farm.factory_mutation_lock import (
        FactoryMutationLock,
        path_for_factory_flag,
    )


PLAN_SCHEMA = "q09-news-legacy-migration-plan/v2"
EXCLUSIVE_ACK = "FARM_STOPPED_AND_DB_EXCLUSIVE"
DEFAULT_FACTORY_OFF = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")


class MigrationError(RuntimeError):
    """Raised when a migration guard fails."""


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def _connect(path: Path, *, readonly: bool = False) -> sqlite3.Connection:
    if readonly:
        uri = path.resolve().as_uri() + "?mode=ro"
        conn = sqlite3.connect(uri, uri=True)
    else:
        conn = sqlite3.connect(str(path), timeout=30.0)
    conn.row_factory = sqlite3.Row
    return conn


def sqlite_state_sha256(path: Path) -> str:
    """Hash the committed, WAL-visible logical SQLite image."""

    conn = _connect(path, readonly=True)
    try:
        try:
            image = conn.serialize()
        except AttributeError as exc:  # pragma: no cover - Python < 3.11
            raise MigrationError("sqlite3.Connection.serialize() is required") from exc
    finally:
        conn.close()
    return hashlib.sha256(image).hexdigest()


def checkpoint_wal(path: Path) -> dict[str, int]:
    """Checkpoint committed WAL frames while the global mutation lock is held."""

    conn = sqlite3.connect(str(path), timeout=30.0, isolation_level=None)
    try:
        conn.execute("PRAGMA busy_timeout=30000")
        row = conn.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()
    finally:
        conn.close()
    busy, log_frames, checkpointed = (int(value or 0) for value in row)
    if busy:
        raise MigrationError(
            f"SQLite WAL checkpoint remained busy (log={log_frames}, checkpointed={checkpointed})"
        )
    return {"busy": busy, "log_frames": log_frames, "checkpointed_frames": checkpointed}


def _plan_core(plan: Mapping[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in plan.items() if key != "plan_sha256"}


def plan_sha256(plan: Mapping[str, Any]) -> str:
    return hashlib.sha256(canonical_json_bytes(_plan_core(plan))).hexdigest()


def _qualification_id(ea_id: str, symbol: str, source_id: str, state: str) -> str:
    material = f"{ea_id}\x1f{symbol}\x1f{source_id}\x1f{state}\x1f{CONTRACT_VERSION}".encode("utf-8")
    return "q09mig_" + hashlib.sha256(material).hexdigest()[:32]


def _lineage_key(ea_id: str, symbol: str, source_id: str) -> str:
    return hashlib.sha256(f"{ea_id}\x1f{symbol}\x1f{source_id}".encode("utf-8")).hexdigest()


def _related_phase_summary(conn: sqlite3.Connection, ea_id: str, symbol: str) -> dict[str, Any]:
    rows = conn.execute(
        """
        SELECT id,phase,verdict,status,created_at
        FROM work_items
        WHERE ea_id=? AND symbol=? AND phase IN ('Q08','Q09_PORTFOLIO','Q10')
        ORDER BY created_at,id
        """,
        (ea_id, symbol),
    ).fetchall()
    return {
        "q08_ids": [row["id"] for row in rows if row["phase"] == "Q08"],
        "q09_portfolio_pass_ids": [
            row["id"] for row in rows if row["phase"] == "Q09_PORTFOLIO" and row["verdict"] == "PASS_PORTFOLIO"
        ],
        "q10_pass_ids": [row["id"] for row in rows if row["phase"] == "Q10" and row["verdict"] == "PASS"],
    }


def _overlay_state(historical_state: str) -> tuple[str | None, str]:
    normalized = historical_state.strip().upper()
    if normalized == "Q12_REVIEW_READY":
        return "LEGACY_NEWS_REQUAL_REQUIRED", "historical_ready_has_no_bound_q09_news_v2"
    if normalized == "EVIDENCE_STALE":
        return "LEGACY_STALE_BLOCKED", "historical_candidate_evidence_stale"
    if normalized in {"DUPLICATE_SUPERSEDED", "SUPERSEDED_DUPLICATE"}:
        return "EXCLUDED_DUPLICATE", "historical_candidate_duplicate_superseded"
    return None, f"historical_state_not_migrated:{normalized}"


def build_plan(conn: sqlite3.Connection, *, source_database: str = "") -> dict[str, Any]:
    """Build a deterministic, read-only overlay plan from a legacy database."""

    if conn.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='work_items'").fetchone() is None:
        raise MigrationError("work_items table missing")
    if conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='portfolio_candidates'"
    ).fetchone() is None:
        raise MigrationError("portfolio_candidates table missing")
    protected = protected_legacy_sha256(conn)
    entries: list[dict[str, Any]] = []
    skipped: list[dict[str, str]] = []
    candidates = conn.execute(
        """
        SELECT ea_id,symbol,q11_work_item_id,state,evidence_path
        FROM portfolio_candidates ORDER BY ea_id,symbol,q11_work_item_id
        """
    ).fetchall()
    for candidate in candidates:
        state, reason = _overlay_state(candidate["state"])
        if state is None:
            skipped.append(
                {
                    "ea_id": candidate["ea_id"],
                    "symbol": candidate["symbol"],
                    "legacy_source_work_item_id": candidate["q11_work_item_id"],
                    "reason": reason,
                }
            )
            continue
        related = _related_phase_summary(conn, candidate["ea_id"], candidate["symbol"])
        if state == "LEGACY_NEWS_REQUAL_REQUIRED":
            has_portfolio = bool(related["q09_portfolio_pass_ids"])
            has_q10 = bool(related["q10_pass_ids"])
            if has_portfolio and has_q10:
                reason += ":historical_q09_portfolio_and_q10_present"
            elif has_portfolio:
                reason += ":historical_q09_portfolio_only"
            elif has_q10:
                reason += ":historical_q10_only"
            else:
                reason += ":no_historical_downstream_pair"
        source_id = candidate["q11_work_item_id"]
        entries.append(
            {
                "qualification_id": _qualification_id(
                    candidate["ea_id"], candidate["symbol"], source_id, state
                ),
                "candidate_lineage_key": _lineage_key(candidate["ea_id"], candidate["symbol"], source_id),
                "ea_id": candidate["ea_id"],
                "symbol": candidate["symbol"],
                "legacy_source_work_item_id": source_id,
                "historical_state": candidate["state"],
                "overlay_state": state,
                "reason_code": reason,
                "historical_evidence_path": candidate["evidence_path"],
                "historical_hints": related,
            }
        )
    counts: dict[str, int] = {}
    for entry in entries:
        counts[entry["overlay_state"]] = counts.get(entry["overlay_state"], 0) + 1
    plan: dict[str, Any] = {
        "schema_version": PLAN_SCHEMA,
        "contract_version": CONTRACT_VERSION,
        "source_database": source_database,
        "generated_at": _utc_now(),
        "protected_legacy_sha256": protected,
        "candidate_count": len(candidates),
        "entry_count": len(entries),
        "overlay_counts": dict(sorted(counts.items())),
        "entries": entries,
        "skipped": skipped,
        "legacy_mutations": [],
    }
    plan["plan_sha256"] = plan_sha256(plan)
    return plan


def load_plan(path: Path) -> dict[str, Any]:
    try:
        plan = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise MigrationError(f"cannot read migration plan: {exc}") from exc
    if plan.get("schema_version") != PLAN_SCHEMA:
        raise MigrationError("unsupported migration plan schema")
    embedded = plan.get("plan_sha256")
    actual = plan_sha256(plan)
    if embedded != actual:
        raise MigrationError("migration plan SHA-256 mismatch")
    return plan


def write_plan(plan: Mapping[str, Any], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")
    temporary.write_bytes(canonical_json_bytes(plan))
    temporary.replace(output)


def database_logical_sha256(conn: sqlite3.Connection, *, exclude_migration_ledger: bool = False) -> str:
    """Hash SQLite schema and rows independent of file-page layout."""

    digest = hashlib.sha256()
    schema_rows = conn.execute(
        """
        SELECT type,name,tbl_name,COALESCE(sql,'') AS sql
        FROM sqlite_master
        WHERE name NOT LIKE 'sqlite_autoindex_%'
        ORDER BY type,name
        """
    ).fetchall()
    for row in schema_rows:
        digest.update(canonical_json_bytes([row[0], row[1], row[2], row[3]]))
    tables = [
        row[0]
        for row in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        ).fetchall()
        if not (exclude_migration_ledger and row[0] == "q09_news_migration_runs")
    ]
    for table in tables:
        quoted_table = '"' + table.replace('"', '""') + '"'
        columns = [row[1] for row in conn.execute(f"PRAGMA table_info({quoted_table})").fetchall()]
        digest.update(canonical_json_bytes({"table": table, "columns": columns}))
        if not columns:
            continue
        quoted = ",".join('"' + column.replace('"', '""') + '"' for column in columns)
        try:
            rows = conn.execute(f"SELECT {quoted} FROM {quoted_table} ORDER BY {quoted}")
        except sqlite3.OperationalError:
            rows = conn.execute(f"SELECT {quoted} FROM {quoted_table}")
        for row in rows:
            normalized = [
                {"blob_hex": bytes(value).hex()} if isinstance(value, (bytes, bytearray, memoryview)) else value
                for value in row
            ]
            digest.update(canonical_json_bytes(normalized))
    return digest.hexdigest()


def create_snapshot(database: Path, snapshot: Path, *, plan_hash: str, protected_hash: str) -> dict[str, Any]:
    if database.resolve() == snapshot.resolve():
        raise MigrationError("snapshot path must differ from database path")
    if snapshot.exists():
        raise MigrationError(f"snapshot already exists: {snapshot}")
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    source = _connect(database, readonly=True)
    destination = sqlite3.connect(str(snapshot))
    try:
        source.backup(destination)
    finally:
        destination.close()
        source.close()
    snapshot_conn = _connect(snapshot, readonly=True)
    try:
        logical_hash = database_logical_sha256(snapshot_conn)
        snapshot_protected = protected_legacy_sha256(snapshot_conn)
    finally:
        snapshot_conn.close()
    if snapshot_protected != protected_hash:
        snapshot.unlink(missing_ok=True)
        raise MigrationError("snapshot protected-state fingerprint mismatch")
    metadata = {
        "schema_version": "q09-news-sqlite-snapshot/v1",
        "created_at": _utc_now(),
        "source_database": str(database.resolve()),
        "snapshot_path": str(snapshot.resolve()),
        "plan_sha256": plan_hash,
        "protected_legacy_sha256": protected_hash,
        "snapshot_sha256": sha256_file(snapshot),
        "snapshot_logical_sha256": logical_hash,
    }
    metadata_path = snapshot.with_suffix(snapshot.suffix + ".json")
    metadata_path.write_bytes(canonical_json_bytes(metadata))
    return metadata


def what_if(conn: sqlite3.Connection, plan: Mapping[str, Any]) -> dict[str, Any]:
    current = protected_legacy_sha256(conn)
    return {
        "mode": "WhatIf",
        "plan_sha256": plan["plan_sha256"],
        "protected_state_matches": current == plan["protected_legacy_sha256"],
        "would_insert": len(plan["entries"]),
        "would_update_legacy_rows": 0,
        "overlay_counts": plan["overlay_counts"],
    }


def inspect_operational_bindings(database: Path, factory_off_flag: Path) -> dict[str, Any]:
    """Read the exact hashes an operator must bind on guarded Apply/Revert."""

    return {
        "database_sha256": sha256_file(database),
        "database_state_sha256": sqlite_state_sha256(database),
        "factory_off_present": factory_off_flag.is_file(),
        "factory_off_sha256": sha256_file(factory_off_flag) if factory_off_flag.is_file() else None,
        "mutation_lock_path": str(path_for_factory_flag(factory_off_flag)),
    }


def _verify_operational_bindings(
    database: Path,
    factory_off_flag: Path,
    *,
    expected_database_sha256: str,
    expected_database_state_sha256: str,
    expected_factory_off_sha256: str,
) -> dict[str, str]:
    if not factory_off_flag.is_file():
        raise MigrationError(f"FACTORY_OFF flag missing: {factory_off_flag}")
    actual_database = sha256_file(database)
    actual_state = sqlite_state_sha256(database)
    actual_flag = sha256_file(factory_off_flag)
    comparisons = (
        ("database SHA-256", expected_database_sha256, actual_database),
        ("logical database-state SHA-256", expected_database_state_sha256, actual_state),
        ("FACTORY_OFF SHA-256", expected_factory_off_sha256, actual_flag),
    )
    for role, expected, actual in comparisons:
        if not expected or expected.strip().lower() != actual.lower():
            raise MigrationError(f"{role} mismatch: expected {expected!r}, actual {actual}")
    return {
        "database_sha256": actual_database,
        "database_state_sha256": actual_state,
        "factory_off_sha256": actual_flag,
    }


def _apply_plan_locked(
    database: Path,
    plan: Mapping[str, Any],
    *,
    plan_path: Path,
    snapshot_path: Path,
    confirm_plan_sha256: str,
) -> dict[str, Any]:
    expected = plan_sha256(plan)
    if plan.get("plan_sha256") != expected or confirm_plan_sha256 != expected:
        raise MigrationError("confirmed plan SHA-256 does not match the immutable plan")
    sealed_file_plan = load_plan(plan_path)
    if sealed_file_plan.get("plan_sha256") != expected:
        raise MigrationError("plan_path does not contain the confirmed migration plan")
    plan_file_sha256 = sha256_file(plan_path)
    conn = _connect(database)
    try:
        if _table_exists_local(conn, "q09_news_migration_runs"):
            existing = conn.execute(
                "SELECT inserted_count,revert_guard_sha256 FROM q09_news_migration_runs WHERE plan_sha256=?",
                (expected,),
            ).fetchone()
            if existing is not None:
                return {
                    "mode": "Apply",
                    "status": "ALREADY_APPLIED",
                    "plan_sha256": expected,
                    "inserted_count": 0,
                    "original_inserted_count": int(existing[0]),
                    "revert_guard_sha256": existing[1],
                }
        before = protected_legacy_sha256(conn)
        if before != plan["protected_legacy_sha256"]:
            raise MigrationError("database changed since the plan was sealed")
    finally:
        conn.close()

    snapshot = create_snapshot(database, snapshot_path, plan_hash=expected, protected_hash=before)
    conn = _connect(database)
    inserted = 0
    try:
        ensure_schema(conn, commit=False)
        for entry in plan["entries"]:
            existing = conn.execute(
                "SELECT state,reason_code,evidence_manifest_sha256 FROM candidate_qualifications WHERE qualification_id=?",
                (entry["qualification_id"],),
            ).fetchone()
            if existing is not None:
                if tuple(existing) != (entry["overlay_state"], entry["reason_code"], plan_file_sha256):
                    raise MigrationError(f"qualification id collision: {entry['qualification_id']}")
                continue
            append_qualification(
                conn,
                {
                    "qualification_id": entry["qualification_id"],
                    "candidate_lineage_key": entry["candidate_lineage_key"],
                    "ea_id": entry["ea_id"],
                    "symbol": entry["symbol"],
                    "contract_version": CONTRACT_VERSION,
                    "q08_work_item_id": None,
                    "q09_news_work_item_id": None,
                    "q09_portfolio_work_item_id": None,
                    "q10_work_item_id": None,
                    "legacy_source_work_item_id": entry["legacy_source_work_item_id"],
                    "state": entry["overlay_state"],
                    "reason_code": entry["reason_code"],
                    "evidence_manifest_path": str(plan_path.resolve()),
                    "evidence_manifest_sha256": plan_file_sha256,
                    "supersedes_qualification_id": None,
                    "created_at": plan["generated_at"],
                },
            )
            inserted += 1
        after = protected_legacy_sha256(conn)
        if after != before:
            raise MigrationError("protected legacy rows changed during additive migration")
        # Ledger is excluded because the guard is stored in that ledger.
        revert_guard = database_logical_sha256(conn, exclude_migration_ledger=True)
        migration_id = "q09news_" + expected[:32]
        conn.execute(
            """
            INSERT INTO q09_news_migration_runs(
                migration_id,plan_sha256,protected_before_sha256,protected_after_sha256,
                snapshot_path,snapshot_sha256,snapshot_logical_sha256,revert_guard_sha256,
                inserted_count,applied_at
            ) VALUES(?,?,?,?,?,?,?,?,?,?)
            """,
            (
                migration_id,
                expected,
                before,
                after,
                str(snapshot_path.resolve()),
                snapshot["snapshot_sha256"],
                snapshot["snapshot_logical_sha256"],
                revert_guard,
                inserted,
                _utc_now(),
            ),
        )
        conn.commit()
        return {
            "mode": "Apply",
            "status": "APPLIED",
            "plan_sha256": expected,
            "inserted_count": inserted,
            "protected_before_sha256": before,
            "protected_after_sha256": after,
            "snapshot_path": str(snapshot_path.resolve()),
            "snapshot_sha256": snapshot["snapshot_sha256"],
            "revert_guard_sha256": revert_guard,
        }
    except BaseException:
        conn.rollback()
        raise
    finally:
        conn.close()


def apply_plan(
    database: Path,
    plan: Mapping[str, Any],
    *,
    plan_path: Path,
    snapshot_path: Path,
    confirm_plan_sha256: str,
    exclusive_ack: str,
    factory_off_flag: Path,
    expected_database_sha256: str,
    expected_database_state_sha256: str,
    expected_factory_off_sha256: str,
    mutation_lock_path: Path | None = None,
) -> dict[str, Any]:
    """Apply under the same global writer boundary as Factory OFF/ON."""

    if exclusive_ack != EXCLUSIVE_ACK:
        raise MigrationError(f"exclusive database acknowledgement must be {EXCLUSIVE_ACK!r}")
    lock_path = mutation_lock_path or path_for_factory_flag(factory_off_flag)
    try:
        lock = FactoryMutationLock(lock_path, owner="q09_news_migration.apply_plan")
        with lock:
            bindings = _verify_operational_bindings(
                database,
                factory_off_flag,
                expected_database_sha256=expected_database_sha256,
                expected_database_state_sha256=expected_database_state_sha256,
                expected_factory_off_sha256=expected_factory_off_sha256,
            )
            result = _apply_plan_locked(
                database,
                plan,
                plan_path=plan_path,
                snapshot_path=snapshot_path,
                confirm_plan_sha256=confirm_plan_sha256,
            )
            wal_checkpoint = checkpoint_wal(database)
            return {
                **result,
                "pre_database_sha256": bindings["database_sha256"],
                "pre_database_state_sha256": bindings["database_state_sha256"],
                "factory_off_sha256": bindings["factory_off_sha256"],
                "post_database_sha256": sha256_file(database),
                "post_database_state_sha256": sqlite_state_sha256(database),
                "wal_checkpoint": wal_checkpoint,
                "mutation_lock_path": str(lock_path),
            }
    except RuntimeError as exc:
        if isinstance(exc, MigrationError):
            raise
        raise MigrationError(str(exc)) from exc


def _table_exists_local(conn: sqlite3.Connection, name: str) -> bool:
    return conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    ).fetchone() is not None


def _revert_locked(
    database: Path,
    *,
    snapshot_path: Path,
    plan_hash: str,
    confirm_revert_guard_sha256: str,
) -> dict[str, Any]:
    if not snapshot_path.is_file():
        raise MigrationError("snapshot does not exist")
    conn = _connect(database)
    try:
        if not _table_exists_local(conn, "q09_news_migration_runs"):
            raise MigrationError("migration ledger is missing")
        ledger = conn.execute(
            """
            SELECT snapshot_path,snapshot_sha256,snapshot_logical_sha256,revert_guard_sha256,
                   protected_before_sha256
            FROM q09_news_migration_runs WHERE plan_sha256=?
            """,
            (plan_hash,),
        ).fetchone()
        if ledger is None:
            raise MigrationError("plan was not applied")
        if Path(ledger[0]).resolve() != snapshot_path.resolve():
            raise MigrationError("snapshot path does not match migration ledger")
        if sha256_file(snapshot_path) != ledger[1]:
            raise MigrationError("snapshot byte hash mismatch")
        current_guard = database_logical_sha256(conn, exclude_migration_ledger=True)
        if current_guard != ledger[3] or confirm_revert_guard_sha256 != ledger[3]:
            raise MigrationError("database changed after migration or revert guard was not confirmed")
        protected_before = ledger[4]
        expected_snapshot_logical = ledger[2]
    finally:
        conn.close()
    snapshot_conn = _connect(snapshot_path, readonly=True)
    try:
        if database_logical_sha256(snapshot_conn) != expected_snapshot_logical:
            raise MigrationError("snapshot logical hash mismatch")
        target = sqlite3.connect(str(database), timeout=30.0)
        try:
            snapshot_conn.backup(target)
        finally:
            target.close()
    finally:
        snapshot_conn.close()
    restored = _connect(database, readonly=True)
    try:
        if protected_legacy_sha256(restored) != protected_before:
            raise MigrationError("restored legacy fingerprint mismatch")
    finally:
        restored.close()
    return {
        "mode": "Revert",
        "status": "REVERTED_TO_SNAPSHOT",
        "plan_sha256": plan_hash,
        "snapshot_path": str(snapshot_path.resolve()),
        "protected_legacy_sha256": protected_before,
    }


def revert(
    database: Path,
    *,
    snapshot_path: Path,
    plan_hash: str,
    confirm_revert_guard_sha256: str,
    exclusive_ack: str,
    factory_off_flag: Path,
    expected_database_sha256: str,
    expected_database_state_sha256: str,
    expected_factory_off_sha256: str,
    mutation_lock_path: Path | None = None,
) -> dict[str, Any]:
    if exclusive_ack != EXCLUSIVE_ACK:
        raise MigrationError(f"exclusive database acknowledgement must be {EXCLUSIVE_ACK!r}")
    lock_path = mutation_lock_path or path_for_factory_flag(factory_off_flag)
    try:
        with FactoryMutationLock(lock_path, owner="q09_news_migration.revert"):
            bindings = _verify_operational_bindings(
                database,
                factory_off_flag,
                expected_database_sha256=expected_database_sha256,
                expected_database_state_sha256=expected_database_state_sha256,
                expected_factory_off_sha256=expected_factory_off_sha256,
            )
            result = _revert_locked(
                database,
                snapshot_path=snapshot_path,
                plan_hash=plan_hash,
                confirm_revert_guard_sha256=confirm_revert_guard_sha256,
            )
            wal_checkpoint = checkpoint_wal(database)
            return {
                **result,
                "pre_database_sha256": bindings["database_sha256"],
                "pre_database_state_sha256": bindings["database_state_sha256"],
                "factory_off_sha256": bindings["factory_off_sha256"],
                "post_database_sha256": sha256_file(database),
                "post_database_state_sha256": sqlite_state_sha256(database),
                "wal_checkpoint": wal_checkpoint,
                "mutation_lock_path": str(lock_path),
            }
    except RuntimeError as exc:
        if isinstance(exc, MigrationError):
            raise
        raise MigrationError(str(exc)) from exc


def _add_common_database(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--database", required=True, type=Path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    plan_parser = subparsers.add_parser("plan", help="build a read-only migration plan")
    _add_common_database(plan_parser)
    plan_parser.add_argument("--output", required=True, type=Path)

    apply_parser = subparsers.add_parser("apply", help="WhatIf by default; guarded apply with --apply")
    _add_common_database(apply_parser)
    apply_parser.add_argument("--plan", required=True, type=Path)
    apply_parser.add_argument("--snapshot", type=Path)
    apply_parser.add_argument("--confirm-plan-sha256")
    apply_parser.add_argument("--exclusive-db-ack")
    apply_parser.add_argument("--factory-off-flag", type=Path, default=DEFAULT_FACTORY_OFF)
    apply_parser.add_argument("--mutation-lock-path", type=Path)
    apply_parser.add_argument("--expected-db-sha256")
    apply_parser.add_argument("--expected-db-state-sha256")
    apply_parser.add_argument("--expected-factory-off-sha256")
    apply_parser.add_argument("--apply", action="store_true")

    revert_parser = subparsers.add_parser("revert", help="guarded restore of the pre-apply SQLite snapshot")
    _add_common_database(revert_parser)
    revert_parser.add_argument("--snapshot", required=True, type=Path)
    revert_parser.add_argument("--plan-sha256", required=True)
    revert_parser.add_argument("--confirm-revert-guard-sha256")
    revert_parser.add_argument("--exclusive-db-ack")
    revert_parser.add_argument("--factory-off-flag", type=Path, default=DEFAULT_FACTORY_OFF)
    revert_parser.add_argument("--mutation-lock-path", type=Path)
    revert_parser.add_argument("--expected-db-sha256")
    revert_parser.add_argument("--expected-db-state-sha256")
    revert_parser.add_argument("--expected-factory-off-sha256")
    revert_parser.add_argument("--apply", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "plan":
        conn = _connect(args.database, readonly=True)
        try:
            plan = build_plan(conn, source_database=str(args.database.resolve()))
        finally:
            conn.close()
        write_plan(plan, args.output)
        print(json.dumps(plan, indent=2, sort_keys=True))
        return 0
    if args.command == "apply":
        plan = load_plan(args.plan)
        if not args.apply:
            conn = _connect(args.database, readonly=True)
            try:
                result = what_if(conn, plan)
            finally:
                conn.close()
            result["operational_bindings"] = inspect_operational_bindings(
                args.database, args.factory_off_flag
            )
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0 if result["protected_state_matches"] else 2
        if (
            args.snapshot is None
            or not args.confirm_plan_sha256
            or not args.expected_db_sha256
            or not args.expected_db_state_sha256
            or not args.expected_factory_off_sha256
        ):
            raise MigrationError(
                "guarded Apply requires snapshot, plan, DB byte/state, and FACTORY_OFF hash bindings"
            )
        result = apply_plan(
            args.database,
            plan,
            plan_path=args.plan,
            snapshot_path=args.snapshot,
            confirm_plan_sha256=args.confirm_plan_sha256,
            exclusive_ack=args.exclusive_db_ack or "",
            factory_off_flag=args.factory_off_flag,
            expected_database_sha256=args.expected_db_sha256,
            expected_database_state_sha256=args.expected_db_state_sha256,
            expected_factory_off_sha256=args.expected_factory_off_sha256,
            mutation_lock_path=args.mutation_lock_path,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    if not args.apply:
        print(
            json.dumps(
                {
                    "mode": "WhatIf",
                    "would_revert": False,
                    "reason": "--apply not supplied",
                    "operational_bindings": inspect_operational_bindings(
                        args.database, args.factory_off_flag
                    ),
                },
                indent=2,
            )
        )
        return 0
    if (
        not args.confirm_revert_guard_sha256
        or not args.expected_db_sha256
        or not args.expected_db_state_sha256
        or not args.expected_factory_off_sha256
    ):
        raise MigrationError(
            "guarded Revert requires revert guard, DB byte/state, and FACTORY_OFF hash bindings"
        )
    result = revert(
        args.database,
        snapshot_path=args.snapshot,
        plan_hash=args.plan_sha256,
        confirm_revert_guard_sha256=args.confirm_revert_guard_sha256,
        exclusive_ack=args.exclusive_db_ack or "",
        factory_off_flag=args.factory_off_flag,
        expected_database_sha256=args.expected_db_sha256,
        expected_database_state_sha256=args.expected_db_state_sha256,
        expected_factory_off_sha256=args.expected_factory_off_sha256,
        mutation_lock_path=args.mutation_lock_path,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
