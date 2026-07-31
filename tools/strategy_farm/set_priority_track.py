#!/usr/bin/env python3
"""Dry-run-first exact-ID controller for OWNER priority-track backfills."""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any, Mapping, Sequence


_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

import farmctl  # noqa: E402
import strategy_priority  # noqa: E402
from factory_mutation_lock import FactoryMutationLock  # noqa: E402


EXPECTATIONS_SCHEMA = "qm.priority-track-expectations/v1"
PLAN_SCHEMA = "qm.priority-track-plan/v1"
JOURNAL_SCHEMA = "qm.priority-track-journal/v1"
OWNER_REFERENCE = "OWNER_DECISION_2026-07-31_QM5_20007_PRIORITY_TRACK"
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REPO = Path(r"C:\QM\repo")
DEFAULT_REGISTRY = DEFAULT_REPO / "framework" / "registry" / "owner_priority_tracks.json"
DEFAULT_LOCK = Path(r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock")
DEFAULT_JOURNAL_DIR = Path(r"D:\QM\reports\state")
MAX_EXACT_IDS = 10

ROW_STATE_FIELDS = (
    "status",
    "phase",
    "verdict",
    "claimed_by",
    "payload_json",
    "updated_at",
)
DOWNSTREAM_PHASES = {
    "Q04", "Q05", "Q06", "Q07", "Q08", "Q09", "Q09_NEWS",
    "Q09_PORTFOLIO", "Q10",
}


class PriorityTrackError(RuntimeError):
    """Fail-closed exact-ID/CAS/journal error."""


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            while chunk := handle.read(1024 * 1024):
                digest.update(chunk)
    except OSError as exc:
        raise PriorityTrackError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def normalized_text_sha256(path: Path) -> str:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise PriorityTrackError(f"cannot read {path}: {exc}") from exc
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    raw = raw.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    try:
        raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise PriorityTrackError(f"text binding is not UTF-8: {path}") from exc
    return sha256_bytes(raw)


def payload_sha256(raw: Any) -> str:
    if not isinstance(raw, str):
        raise PriorityTrackError("payload_json is not text")
    return sha256_bytes(raw.encode("utf-8"))


def _normal_sha(value: Any, label: str) -> str:
    token = str(value or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", token):
        raise PriorityTrackError(f"{label}: expected SHA-256")
    return token


def _reject_constant(token: str) -> None:
    raise PriorityTrackError(f"non-finite JSON constant: {token}")


def _no_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise PriorityTrackError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json(path: Path, label: str) -> tuple[dict[str, Any], str]:
    try:
        raw = path.read_bytes()
        value = json.loads(
            raw.decode("utf-8-sig"),
            object_pairs_hook=_no_duplicates,
            parse_constant=_reject_constant,
        )
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise PriorityTrackError(f"{label}: invalid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise PriorityTrackError(f"{label}: root must be an object")
    return value, sha256_bytes(raw)


def write_json_atomic(path: Path, value: Mapping[str, Any], *, require_absent: bool) -> str:
    path = path.resolve(strict=False)
    if require_absent and path.exists():
        raise PriorityTrackError(f"refusing to overwrite {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = (
        json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False) + "\n"
    ).encode("utf-8")
    temp = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        with temp.open("xb") as handle:
            handle.write(raw)
            handle.flush()
            os.fsync(handle.fileno())
        if require_absent and path.exists():
            raise PriorityTrackError(f"output appeared before atomic replace: {path}")
        os.replace(temp, path)
    finally:
        try:
            temp.unlink()
        except FileNotFoundError:
            pass
    return sha256_bytes(raw)


def connect_ro(path: Path) -> sqlite3.Connection:
    uri = path.resolve().as_uri() + "?mode=ro"
    conn = sqlite3.connect(uri, uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def connect_rw(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(path, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def validate_exact_ids(ids: Sequence[str]) -> tuple[str, ...]:
    if not ids or len(ids) > MAX_EXACT_IDS:
        raise PriorityTrackError(f"requires 1..{MAX_EXACT_IDS} exact work-item IDs")
    normalized = tuple(str(value).strip() for value in ids)
    if len(set(normalized)) != len(normalized):
        raise PriorityTrackError("duplicate --work-item-id")
    for value in normalized:
        try:
            parsed = uuid.UUID(value)
        except (ValueError, AttributeError) as exc:
            raise PriorityTrackError(
                "work-item IDs must be full canonical UUID values, not prefixes"
            ) from exc
        if str(parsed) != value.lower() or len(value) != 36:
            raise PriorityTrackError(
                "work-item IDs must be full canonical UUID values, not prefixes"
            )
    return normalized


def validate_expectations(document: Mapping[str, Any], ids: Sequence[str]) -> dict[str, dict[str, Any]]:
    if document.get("schema_version") != EXPECTATIONS_SCHEMA:
        raise PriorityTrackError("expectations schema mismatch")
    if document.get("owner_reference") != OWNER_REFERENCE:
        raise PriorityTrackError("expectations OWNER reference mismatch")
    if document.get("mode") != "EXACT_ID_NO_WAVE_NO_BULK":
        raise PriorityTrackError("expectations mode mismatch")
    rows = document.get("rows")
    if not isinstance(rows, list):
        raise PriorityTrackError("expectations rows must be a list")
    result: dict[str, dict[str, Any]] = {}
    for index, row in enumerate(rows):
        if not isinstance(row, Mapping):
            raise PriorityTrackError(f"expectations row {index} is not an object")
        work_item_id = str(row.get("work_item_id") or "").strip()
        if work_item_id in result:
            raise PriorityTrackError("duplicate expectation work-item ID")
        if row.get("expected_status") != "pending" or row.get("expected_phase") != "Q02":
            raise PriorityTrackError("backfill expectations must be pending/Q02")
        _normal_sha(row.get("expected_payload_sha256"), "expected payload SHA-256")
        result[work_item_id] = dict(row)
    if set(result) != set(ids):
        raise PriorityTrackError("--work-item-id set must exactly equal expectation rows")
    return result


def _git_provenance(repo: Path, registry: Path) -> dict[str, Any]:
    controller = Path(__file__).resolve()
    try:
        rel_controller = controller.relative_to(repo.resolve()).as_posix()
        rel_registry = registry.resolve().relative_to(repo.resolve()).as_posix()
    except ValueError as exc:
        raise PriorityTrackError("controller/registry is outside canonical repository") from exc
    completed = subprocess.run(
        ["git", "-C", str(repo), "status", "--porcelain", "--", rel_controller, rel_registry],
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
    )
    if completed.returncode != 0 or completed.stdout.strip():
        raise PriorityTrackError(
            f"controller/registry source scope is not committed and clean: {completed.stdout.strip()}"
        )
    head = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    ).stdout.strip().lower()
    return {
        "head_commit": head,
        "controller": {
            "path": str(controller),
            "sha256": normalized_text_sha256(controller),
            "sha256_basis": "UTF8_TEXT_LF_NORMALIZED",
        },
        "registry": {
            "path": str(registry.resolve()),
            "sha256": normalized_text_sha256(registry),
            "sha256_basis": "UTF8_TEXT_LF_NORMALIZED",
        },
        "source_scope_clean": True,
    }


def _payload_object(raw: str) -> dict[str, Any]:
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise PriorityTrackError(f"payload_json invalid: {exc}") from exc
    if not isinstance(value, dict):
        raise PriorityTrackError("payload_json root is not an object")
    return value


def _new_payload(
    raw: str,
    *,
    at: str,
    expectations_sha256: str,
    provenance: Mapping[str, Any],
    owner_entry: Mapping[str, Any],
) -> str:
    payload = _payload_object(raw)
    payload["priority_track"] = True
    payload["priority_reason"] = "owner_priority_registry_20260731"
    payload["priority_track_backfill"] = {
        "schema_version": "qm.priority-track-backfill-payload/v1",
        "set_at_utc": at,
        "owner_reference": OWNER_REFERENCE,
        "expectations_sha256": expectations_sha256,
        "prior_payload_sha256": payload_sha256(raw),
        "controller_head_commit": provenance["head_commit"],
        "controller_sha256": provenance["controller"]["sha256"],
        "registry_sha256": provenance["registry"]["sha256"],
        "target_symbols": list(owner_entry["target_symbols"]),
        "excluded_symbols": list(owner_entry["excluded_symbols"]),
        "pipeline_verdict_changed": False,
    }
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _ordered_rows(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    try:
        return conn.execute(farmctl.pending_claim_order_sql()).fetchall()
    except sqlite3.Error as exc:
        raise PriorityTrackError(f"canonical claim-order query failed: {exc}") from exc


def _quote_identifier(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def _copy_claim_order_tables(source: sqlite3.Connection, destination: sqlite3.Connection) -> None:
    """Copy the exact transaction snapshot needed by pending_claim_order_sql()."""

    for table in ("work_items", "work_item_holds", "poison_pill_quarantine"):
        schema_row = source.execute(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name=?", (table,)
        ).fetchone()
        if schema_row is None or not schema_row[0]:
            raise PriorityTrackError(f"canonical claim-order table missing: {table}")
        destination.execute(str(schema_row[0]))
        columns = [
            str(row[1])
            for row in source.execute(f"PRAGMA table_info({_quote_identifier(table)})").fetchall()
        ]
        if not columns:
            raise PriorityTrackError(f"canonical claim-order table has no columns: {table}")
        column_sql = ",".join(_quote_identifier(column) for column in columns)
        has_rowid = "WITHOUT ROWID" not in str(schema_row[0]).upper()
        select_columns = f"rowid,{column_sql}" if has_rowid else column_sql
        rows = source.execute(
            f"SELECT {select_columns} FROM {_quote_identifier(table)}"
        ).fetchall()
        if rows:
            insert_columns = f"rowid,{column_sql}" if has_rowid else column_sql
            placeholders = ",".join("?" for _value in rows[0])
            destination.executemany(
                f"INSERT INTO {_quote_identifier(table)} ({insert_columns}) "
                f"VALUES ({placeholders})",
                (tuple(row) for row in rows),
            )


def _summarize_claim_order_delta(
    before: Sequence[sqlite3.Row],
    after: Sequence[sqlite3.Row],
    target_ids: Sequence[str],
    *,
    method: str,
) -> dict[str, Any]:
    before_pos = {str(row["id"]): index + 1 for index, row in enumerate(before)}
    after_pos = {str(row["id"]): index + 1 for index, row in enumerate(after)}
    by_id = {str(row["id"]): row for row in before}
    target_set = set(target_ids)
    targets = {
        work_item_id: {
            "before_rank": before_pos.get(work_item_id),
            "after_rank": after_pos.get(work_item_id),
            "rank_improvement": (
                before_pos[work_item_id] - after_pos[work_item_id]
                if work_item_id in before_pos and work_item_id in after_pos
                else None
            ),
        }
        for work_item_id in target_ids
    }
    if any(row["before_rank"] is None or row["after_rank"] is None for row in targets.values()):
        raise PriorityTrackError("target is absent from canonical pending claim order")
    displaced = [
        work_item_id
        for work_item_id, position in before_pos.items()
        if work_item_id not in target_set and after_pos.get(work_item_id, position) > position
    ]
    displaced_rows = [by_id[work_item_id] for work_item_id in displaced]
    digest = sha256_bytes("\n".join(sorted(displaced)).encode("utf-8"))
    return {
        "targets": targets,
        "displaced_rows": len(displaced),
        "displaced_ids_sha256": digest,
        "displaced_q04_plus": sum(
            str(row["phase"]) in DOWNSTREAM_PHASES for row in displaced_rows
        ),
        "displaced_metal": sum(
            str(row["symbol"]).upper().startswith(("XAU", "XAG", "XPT", "XCU"))
            for row in displaced_rows
        ),
        "pending_rows_before": len(before),
        "pending_rows_after": len(after),
        "method": method,
    }


def claim_order_delta(
    conn: sqlite3.Connection, proposed_payloads: Mapping[str, str]
) -> dict[str, Any]:
    if not conn.in_transaction:
        raise PriorityTrackError("claim-order measurement requires an explicit SQLite transaction")
    before = _ordered_rows(conn)
    memory = sqlite3.connect(":memory:")
    memory.row_factory = sqlite3.Row
    try:
        _copy_claim_order_tables(conn, memory)
        for work_item_id, payload in proposed_payloads.items():
            cursor = memory.execute(
                "UPDATE work_items SET payload_json=? WHERE id=?", (payload, work_item_id)
            )
            if cursor.rowcount != 1:
                raise PriorityTrackError("in-memory displacement update missed exact target")
        after = _ordered_rows(memory)
    finally:
        memory.close()
    return _summarize_claim_order_delta(
        before,
        after,
        tuple(proposed_payloads),
        method="CANONICAL_SQL_ON_TRANSACTION_TABLE_SNAPSHOT_IN_MEMORY_COPY",
    )


def build_plan(
    conn: sqlite3.Connection,
    ids: Sequence[str],
    expectations: Mapping[str, Mapping[str, Any]],
    expectations_path: Path,
    expectations_sha256: str,
    repo: Path,
    registry_path: Path,
    *,
    provenance: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    if not conn.in_transaction:
        raise PriorityTrackError("build_plan requires an explicit SQLite transaction")
    registry_entries, registry_provenance = strategy_priority.load_owner_priority_registry(
        registry_path
    )
    blockers: list[str] = []
    if registry_provenance.get("load_status") != "loaded":
        blockers.append(f"owner registry unavailable: {registry_provenance.get('error')}")
    try:
        git = dict(provenance or _git_provenance(repo, registry_path))
    except (PriorityTrackError, OSError, subprocess.SubprocessError) as exc:
        git = {"status": "BLOCKED", "error": str(exc)}
        blockers.append(f"git provenance: {exc}")
    else:
        git["status"] = "PASS"

    rows: list[dict[str, Any]] = []
    proposed: dict[str, str] = {}
    for work_item_id in ids:
        expected = expectations[work_item_id]
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
        row_blockers: list[str] = []
        if row is None:
            row_blockers.append("row missing")
            rows.append({"work_item_id": work_item_id, "status": "BLOCKED", "blockers": row_blockers})
            blockers.extend(f"{work_item_id}: {item}" for item in row_blockers)
            continue
        actual_payload_sha = payload_sha256(row["payload_json"])
        for label, actual, wanted in (
            ("status", row["status"], expected["expected_status"]),
            ("phase", row["phase"], expected["expected_phase"]),
            ("payload_sha256", actual_payload_sha, expected["expected_payload_sha256"].lower()),
        ):
            if actual != wanted:
                row_blockers.append(f"{label} actual={actual!r} expected={wanted!r}")
        if row["claimed_by"] is not None:
            row_blockers.append(f"claimed_by is {row['claimed_by']!r}")
        try:
            payload = _payload_object(row["payload_json"])
        except PriorityTrackError as exc:
            row_blockers.append(str(exc))
            payload = {}
        if payload.get("priority_track") is True:
            row_blockers.append("priority_track already true")
        if payload.get("recovery_class"):
            row_blockers.append("recovery-class row may not be backfilled")
        owner_entry = registry_entries.get(str(row["ea_id"]))
        symbol = str(row["symbol"]).upper()
        if owner_entry is None:
            row_blockers.append("EA absent from OWNER priority registry")
        elif symbol in owner_entry["excluded_symbols"]:
            row_blockers.append("symbol is explicitly excluded by OWNER registry")
        elif symbol not in owner_entry["target_symbols"]:
            row_blockers.append("symbol is outside OWNER registry targets")
        if not row_blockers and git.get("status") == "PASS" and owner_entry is not None:
            proposed[work_item_id] = _new_payload(
                row["payload_json"],
                at="<APPLY_TIME>",
                expectations_sha256=expectations_sha256,
                provenance=git,
                owner_entry=owner_entry,
            )
        state = {field: row[field] for field in ROW_STATE_FIELDS}
        rows.append({
            "work_item_id": work_item_id,
            "ea_id": row["ea_id"],
            "symbol": row["symbol"],
            "status": "PASS" if not row_blockers else "BLOCKED",
            "payload_sha256": actual_payload_sha,
            "state": state,
            "blockers": row_blockers,
        })
        blockers.extend(f"{work_item_id}: {item}" for item in row_blockers)
    displacement = None
    if len(proposed) == len(ids) and not blockers:
        displacement = claim_order_delta(conn, proposed)
    return {
        "schema_version": PLAN_SCHEMA,
        "generated_at_utc": utc_now(),
        "mode": "DRY_RUN",
        "status": "READY_FOR_APPLY" if not blockers else "BLOCKED",
        "exact_ids": list(ids),
        "expectations": {
            "path": str(expectations_path.resolve()),
            "sha256": expectations_sha256,
        },
        "owner_registry": registry_provenance,
        "git_provenance": git,
        "rows": rows,
        "claim_order_displacement": displacement,
        "blockers": blockers,
        "mutation_performed": False,
        "pipeline_verdict_changed": False,
    }


def _insert_event(
    conn: sqlite3.Connection, work_item_id: str, event: str, detail: Mapping[str, Any], now: str
) -> int:
    cursor = conn.execute(
        "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)",
        (now, "work_item", work_item_id, event, json.dumps(detail, sort_keys=True)),
    )
    if cursor.rowcount != 1:
        raise PriorityTrackError("farm event insert did not affect exactly one row")
    return int(cursor.lastrowid)


def apply_plan(
    db: Path,
    ids: Sequence[str],
    expectations: Mapping[str, Mapping[str, Any]],
    expectations_path: Path,
    expectations_sha256: str,
    expected_expectations_sha256: str,
    repo: Path,
    registry_path: Path,
    expected_registry_sha256: str,
    lock_path: Path,
    journal_path: Path,
) -> dict[str, Any]:
    if expectations_sha256 != _normal_sha(
        expected_expectations_sha256, "expected expectations SHA-256"
    ):
        raise PriorityTrackError("expectations SHA-256 mismatch")
    expected_registry = _normal_sha(expected_registry_sha256, "expected registry SHA-256")
    if normalized_text_sha256(registry_path) != expected_registry:
        raise PriorityTrackError("OWNER priority registry SHA-256 mismatch")
    journal_path = journal_path.resolve(strict=False)
    if journal_path.exists():
        raise PriorityTrackError(f"journal already exists: {journal_path}")

    with FactoryMutationLock(lock_path, owner="set_priority_track.apply"):
        conn = connect_rw(db)
        journal: dict[str, Any] | None = None
        event_ids: list[int] = []
        actual_displacement: dict[str, Any] | None = None
        db_committed = False
        try:
            conn.execute("BEGIN IMMEDIATE")
            provenance = _git_provenance(repo, registry_path)
            plan = build_plan(
                conn,
                ids,
                expectations,
                expectations_path,
                expectations_sha256,
                repo,
                registry_path,
                provenance=provenance,
            )
            if plan["status"] != "READY_FOR_APPLY":
                raise PriorityTrackError("apply plan blocked: " + "; ".join(plan["blockers"]))
            now = utc_now()
            registry_entries, _registry_provenance = strategy_priority.load_owner_priority_registry(
                registry_path
            )
            entries: dict[str, Any] = {}
            proposed: dict[str, str] = {}
            for work_item_id in ids:
                row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
                assert row is not None
                post_payload = _new_payload(
                    row["payload_json"],
                    at=now,
                    expectations_sha256=expectations_sha256,
                    provenance=provenance,
                    owner_entry=registry_entries[str(row["ea_id"])],
                )
                pre = {field: row[field] for field in ROW_STATE_FIELDS}
                post = {**pre, "payload_json": post_payload, "updated_at": now}
                entries[work_item_id] = {
                    "ea_id": row["ea_id"],
                    "symbol": row["symbol"],
                    "pre_apply": pre,
                    "post_apply": post,
                    "pre_payload_sha256": payload_sha256(pre["payload_json"]),
                    "post_payload_sha256": payload_sha256(post["payload_json"]),
                }
                proposed[work_item_id] = post_payload
            before_apply_order = _ordered_rows(conn)
            displacement = claim_order_delta(conn, proposed)
            journal = {
                "schema_version": JOURNAL_SCHEMA,
                "state": "planned",
                "planned_at_utc": now,
                "exact_ids": list(ids),
                "expectations": copy.deepcopy(plan["expectations"]),
                "owner_registry": {
                    "path": str(registry_path.resolve()),
                    "sha256": expected_registry,
                },
                "git_provenance": provenance,
                "entries": entries,
                "claim_order_displacement": displacement,
                "events": [],
            }
            write_json_atomic(journal_path, journal, require_absent=True)

            changed = 0
            for work_item_id, entry in entries.items():
                pre = entry["pre_apply"]
                post = entry["post_apply"]
                cursor = conn.execute(
                    "UPDATE work_items SET payload_json=?, updated_at=? "
                    "WHERE id=? AND status IS ? AND phase IS ? AND verdict IS ? "
                    "AND claimed_by IS ? AND payload_json IS ? AND updated_at IS ?",
                    (
                        post["payload_json"],
                        post["updated_at"],
                        work_item_id,
                        pre["status"],
                        pre["phase"],
                        pre["verdict"],
                        pre["claimed_by"],
                        pre["payload_json"],
                        pre["updated_at"],
                    ),
                )
                if cursor.rowcount != 1:
                    raise PriorityTrackError(
                        f"exact CAS for {work_item_id} affected {cursor.rowcount}, expected 1"
                    )
                changed += cursor.rowcount
                event_ids.append(
                    _insert_event(
                        conn,
                        work_item_id,
                        "priority_track_backfill_applied",
                        {
                            "owner_reference": OWNER_REFERENCE,
                            "expectations_sha256": expectations_sha256,
                            "registry_sha256": expected_registry,
                            "pre_payload_sha256": entry["pre_payload_sha256"],
                            "post_payload_sha256": entry["post_payload_sha256"],
                            "pipeline_verdict_changed": False,
                        },
                        now,
                    )
                )
            if changed != len(ids):
                raise PriorityTrackError(f"exact rowcount assertion failed: {changed} != {len(ids)}")
            actual_after = _ordered_rows(conn)
            actual_displacement = _summarize_claim_order_delta(
                before_apply_order,
                actual_after,
                ids,
                method="CANONICAL_SQL_ON_LIVE_TRANSACTION_BEFORE_AFTER",
            )
            if any(
                row["rank_improvement"] is None or row["rank_improvement"] < 0
                for row in actual_displacement["targets"].values()
            ):
                raise PriorityTrackError("post-update canonical rank regressed")
            journal["claim_order_displacement_actual"] = actual_displacement
            conn.commit()
            db_committed = True
        except BaseException as exc:
            if not db_committed:
                conn.rollback()
                if journal is not None:
                    journal["state"] = "rolled_back"
                    journal["rolled_back_at_utc"] = utc_now()
                    journal["failure"] = {
                        "type": type(exc).__name__,
                        "message": str(exc),
                        "database_mutation_committed": False,
                    }
                    write_json_atomic(journal_path, journal, require_absent=False)
            raise
        finally:
            conn.close()

        assert journal is not None and actual_displacement is not None
        journal["state"] = "committed"
        journal["committed_at_utc"] = now
        journal["events"] = event_ids
        final_sha = write_json_atomic(journal_path, journal, require_absent=False)
        return {
            "status": "APPLIED",
            "changed_rows": len(ids),
            "exact_ids": list(ids),
            "journal_path": str(journal_path),
            "journal_sha256": final_sha,
            "claim_order_displacement": actual_displacement,
            "claim_order_displacement_planned": displacement,
            "event_ids": event_ids,
            "pipeline_verdict_changed": False,
        }


def revert_journal(
    db: Path,
    journal_path: Path,
    expected_journal_sha256: str,
    lock_path: Path,
) -> dict[str, Any]:
    expected_sha = _normal_sha(expected_journal_sha256, "expected journal SHA-256")
    if sha256_file(journal_path) != expected_sha:
        raise PriorityTrackError("journal SHA-256 mismatch")
    journal, _raw_sha = load_json(journal_path, "journal")
    if journal.get("schema_version") != JOURNAL_SCHEMA or journal.get("state") != "committed":
        raise PriorityTrackError("journal is not a committed priority-track apply")
    entries = journal.get("entries")
    if not isinstance(entries, Mapping) or set(entries) != set(journal.get("exact_ids") or []):
        raise PriorityTrackError("journal entry/ID contract mismatch")

    with FactoryMutationLock(lock_path, owner="set_priority_track.revert"):
        conn = connect_rw(db)
        event_ids = []
        try:
            conn.execute("BEGIN IMMEDIATE")
            for work_item_id, entry in entries.items():
                row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
                if row is None or any(
                    row[field] != entry["post_apply"].get(field) for field in ROW_STATE_FIELDS
                ):
                    raise PriorityTrackError(f"guarded revert refused: {work_item_id} drifted")
            now = utc_now()
            restored = 0
            for work_item_id, entry in entries.items():
                pre = entry["pre_apply"]
                post = entry["post_apply"]
                cursor = conn.execute(
                    "UPDATE work_items SET payload_json=?, updated_at=? "
                    "WHERE id=? AND status IS ? AND phase IS ? AND verdict IS ? "
                    "AND claimed_by IS ? AND payload_json IS ? AND updated_at IS ?",
                    (
                        pre["payload_json"],
                        pre["updated_at"],
                        work_item_id,
                        post["status"],
                        post["phase"],
                        post["verdict"],
                        post["claimed_by"],
                        post["payload_json"],
                        post["updated_at"],
                    ),
                )
                if cursor.rowcount != 1:
                    raise PriorityTrackError("guarded revert exact rowcount assertion failed")
                restored += 1
                event_ids.append(
                    _insert_event(
                        conn,
                        work_item_id,
                        "priority_track_backfill_reverted",
                        {"journal_sha256": expected_sha, "owner_reference": OWNER_REFERENCE},
                        now,
                    )
                )
            conn.commit()
        except BaseException:
            conn.rollback()
            raise
        finally:
            conn.close()
        journal["state"] = "reverted"
        journal["reverted_at_utc"] = now
        journal["revert_event_ids"] = event_ids
        final_sha = write_json_atomic(journal_path, journal, require_absent=False)
        return {
            "status": "REVERTED",
            "restored_rows": restored,
            "journal_sha256": final_sha,
            "event_ids": event_ids,
        }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--owner-registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--mutation-lock", type=Path, default=DEFAULT_LOCK)
    parser.add_argument("--work-item-id", action="append", default=[])
    parser.add_argument("--expectations", type=Path)
    parser.add_argument("--expected-expectations-sha256")
    parser.add_argument("--expected-registry-sha256")
    parser.add_argument("--plan-out", type=Path)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--journal-out", type=Path)
    parser.add_argument("--revert", type=Path)
    parser.add_argument("--expected-journal-sha256")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.revert:
            if args.apply or args.work_item_id or args.expectations or args.plan_out:
                raise PriorityTrackError("--revert is a standalone mode")
            if not args.expected_journal_sha256:
                raise PriorityTrackError("--revert requires --expected-journal-sha256")
            result = revert_journal(
                args.db, args.revert, args.expected_journal_sha256, args.mutation_lock
            )
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0

        ids = validate_exact_ids(args.work_item_id)
        if args.expectations is None:
            raise PriorityTrackError("--expectations is required")
        document, expectations_sha = load_json(args.expectations, "expectations")
        expectations = validate_expectations(document, ids)
        if args.apply:
            if args.plan_out:
                raise PriorityTrackError("--plan-out is dry-run only")
            if not all(
                (args.journal_out, args.expected_expectations_sha256, args.expected_registry_sha256)
            ):
                raise PriorityTrackError(
                    "--apply requires --journal-out, --expected-expectations-sha256, "
                    "and --expected-registry-sha256"
                )
            result = apply_plan(
                args.db,
                ids,
                expectations,
                args.expectations,
                expectations_sha,
                args.expected_expectations_sha256,
                args.repo,
                args.owner_registry,
                args.expected_registry_sha256,
                args.mutation_lock,
                args.journal_out,
            )
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0

        if args.journal_out or args.expected_journal_sha256:
            raise PriorityTrackError("journal arguments are invalid in dry-run mode")
        conn = connect_ro(args.db)
        try:
            conn.execute("BEGIN")
            plan = build_plan(
                conn,
                ids,
                expectations,
                args.expectations,
                expectations_sha,
                args.repo,
                args.owner_registry,
            )
            conn.rollback()
        finally:
            conn.close()
        if args.plan_out:
            plan_sha = write_json_atomic(args.plan_out, plan, require_absent=True)
            plan["plan_artifact"] = {
                "path": str(args.plan_out.resolve()),
                "sha256": plan_sha,
            }
        print(json.dumps(plan, indent=2, sort_keys=True))
        return 0 if plan["status"] == "READY_FOR_APPLY" else 1
    except (
        PriorityTrackError,
        OSError,
        sqlite3.Error,
        subprocess.SubprocessError,
        KeyError,
        TypeError,
        ValueError,
    ) as exc:
        print(f"priority-track controller refused: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
