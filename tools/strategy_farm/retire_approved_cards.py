#!/usr/bin/env python3
"""Safely retire the fixed 2026-07-20 P2 item-11 card cohort.

The operation is intentionally narrow: it moves ten Markdown Strategy Cards from
``cards_approved`` to ``cards_rejected`` and retires only their exact unclaimed,
pending work-item rows.  It never discovers, copies, compiles, or launches an
EA/EX5/MT5 artifact.

Execution is dry-run by default.  A live move additionally requires an assigned
Codex ``ops_issue`` authorization row and refuses while any other matching farm
task or work item remains open.  Every run writes a self-contained JSON manifest.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence


SCHEMA_VERSION = 1
AUTH_OPERATION = "retire_approved_cards_p2_item_11"
DEFAULT_APPROVED_ROOT = Path(r"D:\QM\strategy_farm\artifacts\cards_approved")
DEFAULT_REJECTED_ROOT = Path(r"D:\QM\strategy_farm\artifacts\cards_rejected")
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REASON_EVIDENCE = Path(
    r"D:\QM\reports\state\build_backlog_priority_v1.csv"
)


@dataclass(frozen=True)
class RetirementSpec:
    ea_id: str
    reason_code: str
    reason: str
    expected_trades_per_year: float | None = None


# Governance source: docs/ops/CODEX_HANDOFF_2026-07-19_audit_fix_bundle.md,
# P2 addendum item 11.  Order is fixed so manifests and reviews remain stable.
RETIREMENT_COHORT: tuple[RetirementSpec, ...] = (
    RetirementSpec(
        "QM5_12941",
        "R1_FAIL",
        "Approved card carries r1_track_record=FAIL.",
    ),
    RetirementSpec(
        "QM5_12942",
        "R1_FAIL",
        "Approved card carries r1_track_record=FAIL.",
    ),
    RetirementSpec(
        "QM5_1650",
        "R1_FAIL",
        "Approved card carries r1_track_record=FAIL.",
    ),
    RetirementSpec(
        "QM5_3005",
        "R1_FAIL",
        "Approved card carries r1_track_record=FAIL.",
    ),
    RetirementSpec(
        "QM5_1648",
        "TD_COUNTDOWN_OFF_EURUSD",
        "2026-07-19 book decision eliminated the TD-countdown family off EURUSD.",
    ),
    RetirementSpec(
        "QM5_12937",
        "TD_COUNTDOWN_OFF_EURUSD",
        "2026-07-19 book decision eliminated the TD-countdown family off EURUSD.",
    ),
    RetirementSpec(
        "QM5_1622",
        "TD_COUNTDOWN_OFF_EURUSD",
        "2026-07-19 book decision eliminated the TD-countdown family off EURUSD.",
    ),
    RetirementSpec(
        "QM5_12921",
        "BELOW_FIVE_TRADES_PER_YEAR",
        "Declared frequency is below the five-trades-per-year floor.",
        2.0,
    ),
    RetirementSpec(
        "QM5_12702",
        "BELOW_FIVE_TRADES_PER_YEAR",
        "Declared frequency is below the five-trades-per-year floor.",
        4.0,
    ),
    RetirementSpec(
        "QM5_12740",
        "BELOW_FIVE_TRADES_PER_YEAR",
        "Declared frequency is below the five-trades-per-year floor.",
        4.0,
    ),
)

COHORT_IDS = tuple(spec.ea_id for spec in RETIREMENT_COHORT)
OPEN_AGENT_TASK_STATES = {
    "BACKLOG",
    "TODO",
    "IN_PROGRESS",
    "REVIEW",
    "PIPELINE",
    "OPS_FIX_REQUIRED",
    "BLOCKED",
    "SELF_LEARNING",
}
OPEN_WORK_ITEM_STATUSES = {"pending", "active"}


class RetirementError(RuntimeError):
    """Raised when a safety or evidence contract is not satisfied."""


class DatabaseDriftError(RetirementError):
    """Raised when cohort state changes between preflight and the write lock."""


@dataclass(frozen=True)
class RunConfig:
    approved_root: Path
    rejected_root: Path
    db_path: Path
    reason_evidence_path: Path
    manifest_path: Path
    execute: bool = False
    ops_task_id: str | None = None
    now_utc: str | None = None


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def _canonical_path(path: Path) -> str:
    return path.resolve().as_posix()


def _same_path(left: Path, right: Path) -> bool:
    return os.path.normcase(str(left.resolve())) == os.path.normcase(str(right.resolve()))


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _sha256_json(value: Any) -> str:
    payload = json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _strip_yaml_scalar(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    return value


def load_frontmatter(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8-sig")
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise RetirementError(f"card has no YAML frontmatter: {path}")
    try:
        end = next(index for index in range(1, len(lines)) if lines[index].strip() == "---")
    except StopIteration as exc:
        raise RetirementError(f"card has unterminated YAML frontmatter: {path}") from exc

    fields: dict[str, str] = {}
    scalar = re.compile(r"^([A-Za-z0-9_]+):\s*(.*?)\s*$")
    for line in lines[1:end]:
        match = scalar.match(line)
        if match:
            fields[match.group(1)] = _strip_yaml_scalar(match.group(2))
    return fields


def _card_pattern(ea_id: str) -> re.Pattern[str]:
    return re.compile(rf"^{re.escape(ea_id)}(?:_|$).*\.md$", re.IGNORECASE)


def _find_card_matches(root: Path, ea_id: str) -> list[Path]:
    pattern = _card_pattern(ea_id)
    return sorted(
        (
            entry
            for entry in root.iterdir()
            if entry.is_file() and pattern.fullmatch(entry.name)
        ),
        key=lambda path: path.name.casefold(),
    )


def _load_reason_evidence(path: Path) -> tuple[list[dict[str, str]], str]:
    if not path.is_file():
        raise RetirementError(f"reason evidence CSV is missing: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        required = {
            "ea_id",
            "expected_trades_per_year",
            "freq_note",
            "dead_family_confidence",
            "dead_family_reason",
        }
        missing = required.difference(reader.fieldnames or ())
        if missing:
            raise RetirementError(
                f"reason evidence CSV lacks columns: {', '.join(sorted(missing))}"
            )
        rows = [dict(row) for row in reader]
    return rows, sha256_file(path)


def _one_evidence_row(rows: Sequence[Mapping[str, str]], ea_id: str) -> Mapping[str, str]:
    matches = [row for row in rows if (row.get("ea_id") or "").strip() == ea_id]
    if len(matches) != 1:
        raise RetirementError(
            f"{ea_id}: expected exactly one reason-evidence row, found {len(matches)}"
        )
    return matches[0]


def _validate_reason(
    spec: RetirementSpec,
    frontmatter: Mapping[str, str],
    evidence_rows: Sequence[Mapping[str, str]],
) -> dict[str, Any]:
    if spec.reason_code == "R1_FAIL":
        observed = (frontmatter.get("r1_track_record") or "").upper()
        if observed != "FAIL":
            raise RetirementError(
                f"{spec.ea_id}: expected r1_track_record=FAIL, observed {observed or '<missing>'}"
            )
        if not (frontmatter.get("r1_reasoning") or "").strip():
            raise RetirementError(f"{spec.ea_id}: R1 FAIL has no r1_reasoning")
        return {
            "validated_from": "card_frontmatter",
            "r1_track_record": observed,
            "r1_reasoning": frontmatter["r1_reasoning"],
        }

    row = _one_evidence_row(evidence_rows, spec.ea_id)
    if spec.reason_code == "TD_COUNTDOWN_OFF_EURUSD":
        confidence = (row.get("dead_family_confidence") or "").strip().upper()
        reason = (row.get("dead_family_reason") or "").strip()
        if confidence != "HIGH":
            raise RetirementError(
                f"{spec.ea_id}: TD evidence confidence is {confidence or '<missing>'}, expected HIGH"
            )
        required_markers = (
            "TD-Reverse-Sequential/Countdown",
            "off-EURUSD",
            "eliminated 2026-07-19 book decision",
        )
        if any(marker.casefold() not in reason.casefold() for marker in required_markers):
            raise RetirementError(f"{spec.ea_id}: TD evidence does not match the book decision")
        return {
            "validated_from": "build_backlog_priority_v1.csv",
            "dead_family_confidence": confidence,
            "dead_family_reason": reason,
        }

    if spec.reason_code == "BELOW_FIVE_TRADES_PER_YEAR":
        card_raw = frontmatter.get("expected_trades_per_year_per_symbol") or ""
        csv_raw = (row.get("expected_trades_per_year") or "").strip()
        try:
            card_frequency = float(card_raw)
            csv_frequency = float(csv_raw)
        except ValueError as exc:
            raise RetirementError(
                f"{spec.ea_id}: missing/non-numeric frequency evidence"
            ) from exc
        expected = float(spec.expected_trades_per_year or 0.0)
        if card_frequency != expected or csv_frequency != expected or expected >= 5.0:
            raise RetirementError(
                f"{spec.ea_id}: frequency mismatch card={card_frequency}, "
                f"csv={csv_frequency}, contract={expected}"
            )
        note = (row.get("freq_note") or "").strip()
        if "BELOW_FLOOR(<5/yr" not in note:
            raise RetirementError(f"{spec.ea_id}: below-floor evidence marker is absent")
        return {
            "validated_from": "card_frontmatter+build_backlog_priority_v1.csv",
            "card_expected_trades_per_year_per_symbol": card_frequency,
            "evidence_expected_trades_per_year": csv_frequency,
            "freq_note": note,
        }

    raise RetirementError(f"unsupported retirement reason: {spec.reason_code}")


def validate_card_plan(
    approved_root: Path,
    rejected_root: Path,
    evidence_rows: Sequence[Mapping[str, str]],
) -> list[dict[str, Any]]:
    if not approved_root.is_dir():
        raise RetirementError(f"approved-card root is missing: {approved_root}")
    if not rejected_root.is_dir():
        raise RetirementError(f"rejected-card root is missing: {rejected_root}")
    if approved_root.is_symlink() or rejected_root.is_symlink():
        raise RetirementError("card roots must not be symlinks")
    if _same_path(approved_root, rejected_root):
        raise RetirementError("approved and rejected roots resolve to the same directory")
    if os.stat(approved_root).st_dev != os.stat(rejected_root).st_dev:
        raise RetirementError("card roots are on different filesystems; atomic moves are required")

    cards: list[dict[str, Any]] = []
    for spec in RETIREMENT_COHORT:
        source_matches = _find_card_matches(approved_root, spec.ea_id)
        if len(source_matches) != 1:
            raise RetirementError(
                f"{spec.ea_id}: expected exactly one approved card, found {len(source_matches)}"
            )
        source = source_matches[0]
        if source.is_symlink():
            raise RetirementError(f"{spec.ea_id}: source card must not be a symlink")
        destination = rejected_root / source.name
        if not _is_within(source, approved_root) or not _is_within(destination, rejected_root):
            raise RetirementError(f"{spec.ea_id}: resolved card path escapes its root")
        if destination.exists() or destination.is_symlink():
            raise RetirementError(f"{spec.ea_id}: destination already exists: {destination}")
        # The historical rejected archive contains some older, differently
        # named cards that reused an EA ID.  They are evidence, not a reason to
        # overwrite or rename this card.  Record them in the manifest while
        # requiring the exact destination filename to be free.
        rejected_matches = _find_card_matches(rejected_root, spec.ea_id)

        frontmatter = load_frontmatter(source)
        if frontmatter.get("ea_id") != spec.ea_id:
            raise RetirementError(
                f"{spec.ea_id}: card frontmatter identity is "
                f"{frontmatter.get('ea_id') or '<missing>'}"
            )
        # QM5_3005 is a legacy approved-root card with no g0_status marker.  All
        # other cards in this fixed cohort must retain their APPROVED marker.
        approval_marker = (frontmatter.get("g0_status") or "").upper()
        if approval_marker != "APPROVED" and not (
            spec.ea_id == "QM5_3005" and not approval_marker
        ):
            raise RetirementError(
                f"{spec.ea_id}: expected g0_status=APPROVED, observed "
                f"{approval_marker or '<missing>'}"
            )

        source_sha = sha256_file(source)
        cards.append(
            {
                **asdict(spec),
                "approval_validation": (
                    "approved_root_legacy_missing_g0_status"
                    if spec.ea_id == "QM5_3005" and not approval_marker
                    else "g0_status_APPROVED"
                ),
                "reason_evidence": _validate_reason(spec, frontmatter, evidence_rows),
                "source_path": _canonical_path(source),
                "destination_path": _canonical_path(destination),
                "preexisting_rejected_same_id_paths": [
                    _canonical_path(path) for path in rejected_matches
                ],
                "source_sha256": source_sha,
                "expected_destination_sha256": source_sha,
                "destination_sha256": None,
                "move_state": "PLANNED",
            }
        )
    return cards


def _db_uri(path: Path) -> str:
    # pathlib.as_uri() is accepted by SQLite on Windows and POSIX and preserves
    # read-only mode without accidentally creating a missing database.
    return f"{path.resolve().as_uri()}?mode=ro"


def _row_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {key: row[key] for key in row.keys()}


def _ea_match_pattern(ea_id: str) -> re.Pattern[str]:
    return re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(ea_id)}(?:_|(?![A-Za-z0-9]))",
        re.IGNORECASE,
    )


def _matching_ids(text: str) -> list[str]:
    return [ea_id for ea_id in COHORT_IDS if _ea_match_pattern(ea_id).search(text)]


def _database_snapshot_from_connection(
    connection: sqlite3.Connection, db_path: Path, *, read_only: bool
) -> dict[str, Any]:
    tables = {
        row[0]
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        )
    }
    missing_tables = {"agent_tasks", "work_items"}.difference(tables)
    if missing_tables:
        raise RetirementError(
            f"farm database lacks tables: {', '.join(sorted(missing_tables))}"
        )
    required_work_columns = {
        "id",
        "phase",
        "ea_id",
        "status",
        "verdict",
        "claimed_by",
        "evidence_path",
        "payload_json",
        "created_at",
        "updated_at",
    }
    work_columns = {
        row[1] for row in connection.execute("PRAGMA table_info(work_items)")
    }
    missing_work_columns = required_work_columns.difference(work_columns)
    if missing_work_columns:
        raise RetirementError(
            "farm work_items lacks columns: "
            + ", ".join(sorted(missing_work_columns))
        )

    task_rows: list[dict[str, Any]] = []
    for row in connection.execute("SELECT * FROM agent_tasks ORDER BY created_at, id"):
        item = _row_dict(row)
        searchable = "\n".join(
            str(item.get(key) or "")
            for key in ("payload_json", "artifact_path", "verdict")
        )
        matches = _matching_ids(searchable)
        if matches:
            item["matched_ea_ids"] = matches
            task_rows.append(item)

    predicates = " OR ".join("ea_id LIKE ?" for _ in COHORT_IDS)
    params = [f"{ea_id}%" for ea_id in COHORT_IDS]
    work_rows: list[dict[str, Any]] = []
    query = f"SELECT * FROM work_items WHERE {predicates} ORDER BY created_at, id"
    for row in connection.execute(query, params):
        item = _row_dict(row)
        matches = _matching_ids(str(item.get("ea_id") or ""))
        if matches:
            item["matched_ea_ids"] = matches
            work_rows.append(item)

    data_version = int(connection.execute("PRAGMA data_version").fetchone()[0])
    snapshot_rows = {"agent_tasks": task_rows, "work_items": work_rows}
    return {
        "database_path": _canonical_path(db_path),
        "sqlite_data_version": data_version,
        "read_only": read_only,
        "agent_tasks": task_rows,
        "work_items": work_rows,
        "snapshot_sha256": _sha256_json(snapshot_rows),
    }


def load_database_snapshot(db_path: Path) -> dict[str, Any]:
    if not db_path.is_file():
        raise RetirementError(f"farm database is missing: {db_path}")

    try:
        connection = sqlite3.connect(_db_uri(db_path), uri=True, timeout=30.0)
    except sqlite3.Error as exc:
        raise RetirementError(f"cannot open farm database read-only: {exc}") from exc
    connection.row_factory = sqlite3.Row
    try:
        connection.execute("PRAGMA query_only=ON")
        connection.execute("BEGIN")
        snapshot = _database_snapshot_from_connection(
            connection, db_path, read_only=True
        )
        connection.execute("COMMIT")
        return snapshot
    except (sqlite3.Error, RetirementError) as exc:
        try:
            connection.execute("ROLLBACK")
        except sqlite3.Error:
            pass
        if isinstance(exc, RetirementError):
            raise
        raise RetirementError(f"farm database snapshot failed: {exc}") from exc
    finally:
        connection.close()


def _parse_payload(row: Mapping[str, Any], label: str) -> dict[str, Any]:
    try:
        payload = json.loads(str(row.get("payload_json") or "{}"))
    except json.JSONDecodeError as exc:
        raise RetirementError(f"{label} payload_json is malformed") from exc
    if not isinstance(payload, dict):
        raise RetirementError(f"{label} payload_json must be an object")
    return payload


def _validate_ops_authorization_row(
    item: Mapping[str, Any],
    approved_root: Path,
    rejected_root: Path,
) -> dict[str, Any]:
    expected_fields = {
        "task_type": "ops_issue",
        "state": "IN_PROGRESS",
        "assigned_agent": "codex",
    }
    for key, expected in expected_fields.items():
        if item.get(key) != expected:
            raise RetirementError(
                f"ops authorization {key}={item.get(key)!r}, expected {expected!r}"
            )
    payload = _parse_payload(item, "ops authorization")
    if payload.get("operation") != AUTH_OPERATION:
        raise RetirementError(f"ops authorization operation must be {AUTH_OPERATION}")
    if payload.get("allow_card_move") is not True:
        raise RetirementError("ops authorization must set allow_card_move=true")
    if payload.get("allow_pending_work_retirement") is not True:
        raise RetirementError(
            "ops authorization must set allow_pending_work_retirement=true"
        )
    if payload.get("card_ids") != list(COHORT_IDS):
        raise RetirementError("ops authorization card_ids do not match the fixed cohort/order")

    requested_approved = payload.get("approved_root")
    requested_rejected = payload.get("rejected_root")
    if not isinstance(requested_approved, str) or not _same_path(
        Path(requested_approved), approved_root
    ):
        raise RetirementError("ops authorization approved_root does not match")
    if not isinstance(requested_rejected, str) or not _same_path(
        Path(requested_rejected), rejected_root
    ):
        raise RetirementError("ops authorization rejected_root does not match")
    return dict(item)


def validate_ops_authorization(
    db_path: Path,
    task_id: str | None,
    approved_root: Path,
    rejected_root: Path,
) -> dict[str, Any]:
    if not task_id:
        raise RetirementError("--execute requires --ops-task-id")
    connection = sqlite3.connect(_db_uri(db_path), uri=True, timeout=30.0)
    connection.row_factory = sqlite3.Row
    try:
        connection.execute("PRAGMA query_only=ON")
        row = connection.execute(
            "SELECT * FROM agent_tasks WHERE id=?", (task_id,)
        ).fetchone()
    finally:
        connection.close()
    if row is None:
        raise RetirementError(f"ops authorization task does not exist: {task_id}")
    return _validate_ops_authorization_row(
        _row_dict(row), approved_root, rejected_root
    )


def classify_open_work(
    snapshot: Mapping[str, Any], authorized_task_id: str | None
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    blockers: list[dict[str, Any]] = []
    pending_retirements: list[dict[str, Any]] = []
    for row in snapshot.get("agent_tasks", []):
        if row.get("id") == authorized_task_id:
            continue
        state = str(row.get("state") or "").upper()
        if state in OPEN_AGENT_TASK_STATES:
            blockers.append(
                {
                    "kind": "agent_task",
                    "id": row.get("id"),
                    "state": state,
                    "matched_ea_ids": row.get("matched_ea_ids", []),
                }
            )
    for row in snapshot.get("work_items", []):
        status = str(row.get("status") or "").lower()
        claimed_by = str(row.get("claimed_by") or "").strip()
        if status == "pending" and not claimed_by:
            pending_retirements.append(dict(row))
        elif status in OPEN_WORK_ITEM_STATUSES:
            blockers.append(
                {
                    "kind": "work_item",
                    "id": row.get("id"),
                    "status": status,
                    "phase": row.get("phase"),
                    "claimed_by": row.get("claimed_by"),
                    "matched_ea_ids": row.get("matched_ea_ids", []),
                }
            )
    return blockers, pending_retirements


def _planned_work_item_after(
    before: Mapping[str, Any],
    *,
    manifest_path: Path,
    ops_task_id: str | None,
    retired_at_utc: str,
) -> dict[str, Any]:
    payload = _parse_payload(before, f"work item {before.get('id')}")
    if "retirement_audit" in payload:
        raise RetirementError(
            f"work item {before.get('id')} already has retirement_audit payload"
        )
    payload["retirement_audit"] = {
        "operation": AUTH_OPERATION,
        "reason": "P2_ITEM_11_RETIRE_WITHOUT_BUILD",
        "manifest_path": _canonical_path(manifest_path),
        "ops_task_id": ops_task_id,
        "retired_at_utc": retired_at_utc,
        "previous_status": before.get("status"),
        "previous_verdict": before.get("verdict"),
        "matched_ea_ids": list(before.get("matched_ea_ids", [])),
    }
    after = dict(before)
    after.update(
        {
            "status": "done",
            "verdict": "RETIRED_WITHOUT_BUILD",
            "claimed_by": None,
            "evidence_path": _canonical_path(manifest_path),
            "payload_json": json.dumps(
                payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")
            ),
            "updated_at": retired_at_utc,
        }
    )
    return after


def _database_mutation_plan(
    pending_rows: Sequence[Mapping[str, Any]],
    config: RunConfig,
    retired_at_utc: str,
) -> dict[str, Any]:
    before = [dict(row) for row in pending_rows]
    planned_after = [
        _planned_work_item_after(
            row,
            manifest_path=config.manifest_path,
            ops_task_id=config.ops_task_id,
            retired_at_utc=retired_at_utc,
        )
        for row in before
    ]
    return {
        "state": "PREPARED" if config.execute else "DRY_RUN_PLANNED",
        "transaction": "BEGIN IMMEDIATE" if config.execute else None,
        "planned_work_item_ids": [row.get("id") for row in before],
        "before_rows": before,
        "planned_after_rows": planned_after,
        "after_rows": None,
    }


def _stage_pending_work_item_retirements(
    connection: sqlite3.Connection,
    mutation: Mapping[str, Any],
) -> list[dict[str, Any]]:
    planned_after = mutation.get("planned_after_rows", [])
    for after in planned_after:
        result = connection.execute(
            """
            UPDATE work_items
               SET status=?, verdict=?, claimed_by=NULL, evidence_path=?,
                   payload_json=?, updated_at=?
             WHERE id=? AND status='pending'
               AND (claimed_by IS NULL OR TRIM(claimed_by)='')
            """,
            (
                after["status"],
                after["verdict"],
                after["evidence_path"],
                after["payload_json"],
                after["updated_at"],
                after["id"],
            ),
        )
        if result.rowcount != 1:
            raise DatabaseDriftError(
                f"pending work item changed before retirement update: {after['id']}"
            )

    ids = [row["id"] for row in planned_after]
    if not ids:
        return []
    placeholders = ",".join("?" for _ in ids)
    rows: list[dict[str, Any]] = []
    for row in connection.execute(
        f"SELECT * FROM work_items WHERE id IN ({placeholders}) ORDER BY created_at, id",
        ids,
    ):
        item = _row_dict(row)
        item["matched_ea_ids"] = _matching_ids(str(item.get("ea_id") or ""))
        rows.append(item)
    if [row["id"] for row in rows] != [row["id"] for row in planned_after]:
        raise DatabaseDriftError("retired work-item result set/order drifted")
    for actual, expected in zip(rows, planned_after):
        for key in (
            "status",
            "verdict",
            "claimed_by",
            "evidence_path",
            "payload_json",
            "updated_at",
        ):
            if actual.get(key) != expected.get(key):
                raise DatabaseDriftError(
                    f"work item {actual['id']} staged {key} mismatch"
                )
    return rows


def _write_initial_manifest(path: Path, manifest: Mapping[str, Any]) -> None:
    if not path.parent.is_dir():
        raise RetirementError(f"manifest parent directory is missing: {path.parent}")
    try:
        with path.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(manifest, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
    except FileExistsError as exc:
        raise RetirementError(f"manifest already exists: {path}") from exc


def _replace_manifest(path: Path, manifest: Mapping[str, Any]) -> None:
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        with temporary.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(manifest, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def _atomic_move(source: Path, destination: Path) -> None:
    # Never use os.replace here: an independently created destination is
    # evidence and must not be overwritten.  Windows rename is no-clobber.  The
    # hard-link fallback gives the same no-clobber property on POSIX fixtures.
    if os.name == "nt":
        os.rename(source, destination)
        return
    os.link(source, destination)
    try:
        source.unlink()
    except Exception:
        destination.unlink(missing_ok=True)
        raise


def _base_manifest(
    config: RunConfig,
    cards: list[dict[str, Any]],
    reason_evidence_sha: str,
    database_snapshot: dict[str, Any],
    authorization: dict[str, Any] | None,
    blockers: list[dict[str, Any]],
    database_mutation: dict[str, Any],
) -> dict[str, Any]:
    created_at = config.now_utc or _utc_now()
    return {
        "schema_version": SCHEMA_VERSION,
        "operation": AUTH_OPERATION,
        "mode": "execute" if config.execute else "dry_run",
        "status": "PREPARED" if config.execute else "DRY_RUN",
        "created_at_utc": created_at,
        "updated_at_utc": created_at,
        "governance_source": (
            "docs/ops/CODEX_HANDOFF_2026-07-19_audit_fix_bundle.md#p2-addendum-item-11"
        ),
        "scope_guards": {
            "card_count": len(cards),
            "fixed_card_ids": list(COHORT_IDS),
            "markdown_cards_only": True,
            "database_write_scope": (
                "none_dry_run"
                if not config.execute
                else "exact_unclaimed_pending_cohort_work_items"
            ),
            "ea_ex5_mt5_touched": False,
        },
        "roots": {
            "approved": _canonical_path(config.approved_root),
            "rejected": _canonical_path(config.rejected_root),
        },
        "reason_evidence": {
            "path": _canonical_path(config.reason_evidence_path),
            "sha256": reason_evidence_sha,
        },
        "database_snapshot": database_snapshot,
        "database_mutation": database_mutation,
        "ops_authorization": authorization,
        "open_work_blockers": blockers,
        "cards": cards,
    }


def run(config: RunConfig) -> dict[str, Any]:
    if config.manifest_path.exists() or config.manifest_path.is_symlink():
        raise RetirementError(f"manifest already exists: {config.manifest_path}")
    if config.manifest_path.suffix.lower() != ".json":
        raise RetirementError("manifest path must end in .json")

    evidence_rows, evidence_sha = _load_reason_evidence(config.reason_evidence_path)
    cards = validate_card_plan(
        config.approved_root, config.rejected_root, evidence_rows
    )
    snapshot = load_database_snapshot(config.db_path)
    authorization = (
        validate_ops_authorization(
            config.db_path,
            config.ops_task_id,
            config.approved_root,
            config.rejected_root,
        )
        if config.execute
        else None
    )
    blockers, pending_retirements = classify_open_work(
        snapshot, config.ops_task_id if config.execute else None
    )
    created_at = config.now_utc or _utc_now()
    database_mutation = _database_mutation_plan(
        pending_retirements, config, created_at
    )
    manifest = _base_manifest(
        config,
        cards,
        evidence_sha,
        snapshot,
        authorization,
        blockers,
        database_mutation,
    )

    if blockers:
        manifest["status"] = (
            "BLOCKED_ACTIVE_WORK" if config.execute else "DRY_RUN_BLOCKED_ACTIVE_WORK"
        )
        _write_initial_manifest(config.manifest_path, manifest)
        return manifest

    if not config.execute:
        _write_initial_manifest(config.manifest_path, manifest)
        return manifest

    _write_initial_manifest(config.manifest_path, manifest)
    connection: sqlite3.Connection | None = None
    moved_indexes: list[int] = []
    try:
        connection = sqlite3.connect(str(config.db_path.resolve()), timeout=30.0)
        connection.row_factory = sqlite3.Row
        connection.execute("BEGIN IMMEDIATE")
        locked_snapshot = _database_snapshot_from_connection(
            connection, config.db_path, read_only=False
        )
        if sha256_file(config.reason_evidence_path) != evidence_sha:
            raise DatabaseDriftError("reason evidence changed before write lock")
        if locked_snapshot["snapshot_sha256"] != snapshot["snapshot_sha256"]:
            raise DatabaseDriftError(
                "cohort task/work-item snapshot changed before BEGIN IMMEDIATE"
            )
        locked_authorization_row = connection.execute(
            "SELECT * FROM agent_tasks WHERE id=?", (config.ops_task_id,)
        ).fetchone()
        if locked_authorization_row is None:
            raise DatabaseDriftError("ops authorization disappeared before write lock")
        locked_authorization = _validate_ops_authorization_row(
            _row_dict(locked_authorization_row),
            config.approved_root,
            config.rejected_root,
        )
        if _sha256_json(locked_authorization) != _sha256_json(authorization):
            raise DatabaseDriftError("ops authorization changed before write lock")
        locked_blockers, locked_pending = classify_open_work(
            locked_snapshot, config.ops_task_id
        )
        if locked_blockers:
            raise DatabaseDriftError("new active/claimed cohort work appeared")
        if [row.get("id") for row in locked_pending] != database_mutation[
            "planned_work_item_ids"
        ]:
            raise DatabaseDriftError("pending cohort retirement set changed")

        database_mutation["after_rows"] = _stage_pending_work_item_retirements(
            connection, database_mutation
        )
        database_mutation["state"] = "STAGED_UNCOMMITTED"
        manifest["updated_at_utc"] = config.now_utc or _utc_now()
        _replace_manifest(config.manifest_path, manifest)

        for index, card in enumerate(manifest["cards"]):
            source = Path(card["source_path"])
            destination = Path(card["destination_path"])
            if sha256_file(source) != card["source_sha256"]:
                raise RetirementError(f"{card['ea_id']}: source changed after preflight")
            _atomic_move(source, destination)
            moved_indexes.append(index)
            destination_sha = sha256_file(destination)
            if destination_sha != card["source_sha256"]:
                raise RetirementError(f"{card['ea_id']}: destination hash mismatch")
            card["destination_sha256"] = destination_sha
            card["move_state"] = "MOVED"
            manifest["updated_at_utc"] = _utc_now()
            _replace_manifest(config.manifest_path, manifest)

        for card in manifest["cards"]:
            if Path(card["source_path"]).exists():
                raise RetirementError(
                    f"postcondition failed; source remains: {card['source_path']}"
                )
            destination = Path(card["destination_path"])
            if (
                not destination.is_file()
                or sha256_file(destination) != card["source_sha256"]
            ):
                raise RetirementError(
                    "postcondition failed; destination invalid: "
                    f"{card['destination_path']}"
                )
        connection.commit()
    except Exception as exc:
        if connection is not None and connection.in_transaction:
            connection.rollback()
        rollback_errors: list[str] = []
        for index in reversed(moved_indexes):
            card = manifest["cards"][index]
            source = Path(card["source_path"])
            destination = Path(card["destination_path"])
            try:
                if source.exists():
                    raise RetirementError(f"rollback source already exists: {source}")
                _atomic_move(destination, source)
                if sha256_file(source) != card["source_sha256"]:
                    raise RetirementError(f"rollback hash mismatch: {source}")
                card["destination_sha256"] = None
                card["move_state"] = "ROLLED_BACK"
            except Exception as rollback_exc:  # pragma: no cover - emergency path
                card["move_state"] = "ROLLBACK_FAILED"
                rollback_errors.append(f"{card['ea_id']}: {rollback_exc}")
        if isinstance(exc, DatabaseDriftError) and not moved_indexes:
            manifest["status"] = "BLOCKED_DB_DRIFT"
        else:
            manifest["status"] = (
                "PARTIAL_REQUIRES_RECOVERY" if rollback_errors else "ROLLED_BACK"
            )
        database_mutation["state"] = (
            "ROLLBACK_INCOMPLETE" if rollback_errors else "ROLLED_BACK"
        )
        database_mutation["after_rows"] = database_mutation["before_rows"]
        manifest["failure"] = {
            "error": str(exc),
            "rollback_errors": rollback_errors,
        }
        manifest["updated_at_utc"] = _utc_now()
        _replace_manifest(config.manifest_path, manifest)
        raise RetirementError(
            f"retirement failed; manifest status={manifest['status']}: {exc}"
        ) from exc
    finally:
        if connection is not None:
            connection.close()

    database_mutation["state"] = "COMMITTED"
    manifest["status"] = "COMPLETE"
    manifest["updated_at_utc"] = _utc_now()
    _replace_manifest(config.manifest_path, manifest)
    return manifest


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Dry-run or execute the fixed P2 item-11 approved-card retirement."
    )
    parser.add_argument("--approved-root", type=Path, default=DEFAULT_APPROVED_ROOT)
    parser.add_argument("--rejected-root", type=Path, default=DEFAULT_REJECTED_ROOT)
    parser.add_argument("--db", dest="db_path", type=Path, default=DEFAULT_DB)
    parser.add_argument(
        "--reason-evidence", type=Path, default=DEFAULT_REASON_EVIDENCE
    )
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Move the cards. Default is read-only dry-run apart from the manifest.",
    )
    parser.add_argument(
        "--ops-task-id",
        help="Required with --execute; assigned IN_PROGRESS Codex ops authorization.",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    config = RunConfig(
        approved_root=args.approved_root,
        rejected_root=args.rejected_root,
        db_path=args.db_path,
        reason_evidence_path=args.reason_evidence,
        manifest_path=args.manifest,
        execute=args.execute,
        ops_task_id=args.ops_task_id,
    )
    try:
        manifest = run(config)
    except RetirementError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    print(
        json.dumps(
            {
                "status": manifest["status"],
                "manifest": _canonical_path(config.manifest_path),
                "card_count": len(manifest["cards"]),
                "open_work_blockers": len(manifest["open_work_blockers"]),
            },
            sort_keys=True,
        )
    )
    return 3 if manifest["open_work_blockers"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
