#!/usr/bin/env python3
"""Build a deterministic, read-only inventory for Q08 v2 -> v3 migration.

This module deliberately has no database apply path.  It opens SQLite only by
URI with ``mode=ro``, asserts ``PRAGMA query_only=ON``, and emits a
content-addressed snapshot.  The snapshot classifies every Q08 work item,
records lineage and aliases, and exposes collisions for later dry-run
adjudication.  It never changes the historical Q08 verdict.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sqlite3
import sys
from collections import Counter, defaultdict
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator, Mapping, Sequence

REPO_ROOT = Path(__file__).resolve().parents[2]
try:
    from framework.scripts.q08_v3_shadow.policy import (
        DEFAULT_POLICY_PATH as DEFAULT_Q08_POLICY_PATH,
        PolicyValidationError,
        load_policy as load_q08_policy,
    )
except ModuleNotFoundError:  # direct script execution from tools/strategy_farm
    if str(REPO_ROOT) not in sys.path:
        sys.path.insert(0, str(REPO_ROOT))
    from framework.scripts.q08_v3_shadow.policy import (
        DEFAULT_POLICY_PATH as DEFAULT_Q08_POLICY_PATH,
        PolicyValidationError,
        load_policy as load_q08_policy,
    )


SCHEMA_VERSION = "qm.q08-v3-migration-inventory/v1"
TARGETS_SCHEMA_VERSION = "qm.q08-v3-current-targets/v1"
TOOL_VERSION = "q08_v3_migration_inventory/1.0.0"

DISPOSITIONS = (
    "CURRENT",
    "LEGACY_UNVERIFIED",
    "ELIGIBLE_REEVALUATION",
    "INVALID",
    "SUPERSEDED",
)
PRIORITIES = (
    "P0_CURRENT_TARGET",
    "P1_V2_PASS",
    "P2_V2_FAIL_SOFT",
    "P3_LEGACY",
    "HOLD_INVALID",
    "HOLD_SUPERSEDED",
)
LEGACY_VERDICTS = {
    "PASS",
    "FAIL_SOFT",
    "FAIL_HARD",
    "FAIL",
    "INVALID",
    "INFRA_FAIL",
    "SUPERSEDED_DUPLICATE",
}
TARGETS = {"DXZ", "FTMO"}
SELECTOR_TYPES = {"WORK_ITEM_ID", "LINEAGE_KEY"}
TERMINAL_STATUSES = {"done", "failed"}
LINEAGE_BASES = {"EXPLICIT_PAYLOAD", "DERIVED_IDENTITY", "CONFLICT"}
ALIAS_ORIGINS = {
    "WORK_ITEM_ID",
    "DERIVED_IDENTITY",
    "PAYLOAD_ALIAS",
    "PAYLOAD_REFERENCE",
}
ARTIFACT_ROLES = ("SETFILE", "EVIDENCE")
ARTIFACT_STATES = {
    "NOT_DECLARED",
    "NOT_CHECKED",
    "INVALID_PATH",
    "ARTIFACT_ROOT_MISSING",
    "SYMLINK",
    "MISSING",
    "UNREADABLE",
    "OUTSIDE_ROOT",
    "NON_REGULAR",
    "VERIFIED",
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")

REQUIRED_WORK_ITEM_COLUMNS = (
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


class InventoryError(RuntimeError):
    """The source database or requested inventory violates the v1 contract."""


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise InventoryError(f"duplicate JSON key rejected: {key}")
        result[key] = value
    return result


def _reject_constant(value: str) -> Any:
    raise InventoryError(f"non-finite JSON value rejected: {value}")


def strict_json_loads(raw: str, *, context: str) -> Any:
    try:
        return json.loads(
            raw,
            object_pairs_hook=_reject_duplicate_keys,
            parse_constant=_reject_constant,
        )
    except InventoryError:
        raise
    except (TypeError, json.JSONDecodeError) as exc:
        raise InventoryError(f"invalid JSON in {context}: {exc}") from exc


def load_json_file(path: Path, *, context: str) -> Any:
    try:
        raw = Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise InventoryError(f"cannot read {context}: {exc}") from exc
    return strict_json_loads(raw, context=context)


def _assert_no_floats(value: Any, context: str = "payload") -> None:
    if isinstance(value, float):
        raise InventoryError(f"floating-point value forbidden at {context}")
    if isinstance(value, Mapping):
        for key, child in value.items():
            if not isinstance(key, str):
                raise InventoryError(f"non-string object key at {context}")
            _assert_no_floats(child, f"{context}.{key}")
    elif isinstance(value, (list, tuple)):
        for index, child in enumerate(value):
            _assert_no_floats(child, f"{context}[{index}]")


def canonical_json_bytes(value: Any) -> bytes:
    """Return the unique UTF-8 representation used for every v1 identity."""

    _assert_no_floats(value)
    try:
        text = json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
    except (TypeError, ValueError) as exc:
        raise InventoryError(f"payload is not canonical-JSON compatible: {exc}") from exc
    return text.encode("utf-8")


def canonical_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_q08_policy_binding() -> dict[str, str]:
    """Return the one repository-owned Q08-v3 policy identity.

    Migration callers cannot substitute a syntactically valid policy hash or an
    alternate policy file.  Both raw bytes and semantic canonical JSON are
    bound so formatting drift and policy drift remain independently visible.
    """

    try:
        policy_path = Path(DEFAULT_Q08_POLICY_PATH).resolve(strict=True)
        policy_path.relative_to(REPO_ROOT.resolve(strict=True))
        policy = load_q08_policy(policy_path)
        file_sha256 = sha256_file(policy_path)
    except (OSError, ValueError, PolicyValidationError) as exc:
        raise InventoryError(f"canonical Q08-v3 policy is unavailable or invalid: {exc}") from exc
    return {
        "path": policy_path.relative_to(REPO_ROOT.resolve()).as_posix(),
        "file_sha256": file_sha256,
        "canonical_sha256": policy.policy_sha256,
        "policy_version": policy.policy_version,
    }


def _exact_object(value: Any, keys: set[str], context: str) -> dict[str, Any]:
    if type(value) is not dict:
        raise InventoryError(f"{context} must be an object")
    actual = set(value)
    if actual != keys:
        raise InventoryError(
            f"{context} key set mismatch "
            f"(missing={sorted(keys - actual)}, extra={sorted(actual - keys)})"
        )
    return value


def _nonempty_string(value: Any, context: str) -> str:
    if not isinstance(value, str) or not value or value.strip() != value:
        raise InventoryError(f"{context} must be a non-empty, trimmed string")
    return value


@contextmanager
def open_read_only_database(path: Path) -> Iterator[sqlite3.Connection]:
    """Open an existing SQLite file with both independent read-only rails."""

    candidate = Path(path)
    try:
        resolved = candidate.resolve(strict=True)
    except FileNotFoundError as exc:
        raise InventoryError(f"database does not exist: {candidate}") from exc
    if not resolved.is_file():
        raise InventoryError(f"database is not a regular file: {resolved}")
    connection = sqlite3.connect(
        resolved.as_uri() + "?mode=ro", uri=True, timeout=30
    )
    connection.row_factory = sqlite3.Row
    try:
        connection.execute("PRAGMA query_only=ON")
        enabled = connection.execute("PRAGMA query_only").fetchone()
        if enabled is None or int(enabled[0]) != 1:
            raise InventoryError("SQLite query_only could not be enabled")
        yield connection
    finally:
        connection.close()


def _work_item_schema(connection: sqlite3.Connection) -> list[dict[str, Any]]:
    rows = connection.execute("PRAGMA table_info('work_items')").fetchall()
    if not rows:
        raise InventoryError("required table work_items does not exist")
    available = {str(row[1]) for row in rows}
    missing = sorted(set(REQUIRED_WORK_ITEM_COLUMNS) - available)
    if missing:
        raise InventoryError(f"work_items is missing required columns: {missing}")
    selected = [row for row in rows if str(row[1]) in REQUIRED_WORK_ITEM_COLUMNS]
    selected.sort(key=lambda row: REQUIRED_WORK_ITEM_COLUMNS.index(str(row[1])))
    return [
        {
            "name": str(row[1]),
            "type": str(row[2] or ""),
            "not_null": bool(row[3]),
            "default_sql": None if row[4] is None else str(row[4]),
            "primary_key_position": int(row[5]),
        }
        for row in selected
    ]


def _sqlite_hash_value(value: Any) -> Any:
    if value is None or type(value) in {str, int, bool}:
        return value
    if isinstance(value, bytes):
        return {"sqlite_type": "blob", "hex": value.hex()}
    if isinstance(value, float):
        return {"sqlite_type": "real", "decimal": format(value, ".17g")}
    return {"sqlite_type": type(value).__name__, "repr": repr(value)}


def _raw_row_snapshot(row: sqlite3.Row) -> dict[str, Any]:
    return {
        name: _sqlite_hash_value(row[name])
        for name in REQUIRED_WORK_ITEM_COLUMNS
    }


def _trimmed(value: Any) -> str | None:
    return value if isinstance(value, str) and value and value.strip() == value else None


def _derived_lineage(ea_id: str, symbol: str, setfile_path: str) -> str:
    normalized_path = setfile_path.replace("\\", "/").casefold()
    identity = {
        "ea_id": ea_id.casefold(),
        "symbol": symbol.casefold(),
        "setfile_path": normalized_path,
    }
    return "derived:" + canonical_sha256(identity)


def _parse_payload(raw: Any) -> tuple[dict[str, Any] | None, str, list[str]]:
    if not isinstance(raw, str):
        serialized = repr(raw).encode("utf-8", errors="backslashreplace")
        return None, hashlib.sha256(serialized).hexdigest(), ["PAYLOAD_NOT_TEXT"]
    payload_sha = hashlib.sha256(raw.encode("utf-8")).hexdigest()
    try:
        value = strict_json_loads(raw, context="work_items.payload_json")
    except InventoryError:
        return None, payload_sha, ["PAYLOAD_JSON_INVALID"]
    if type(value) is not dict:
        return None, payload_sha, ["PAYLOAD_NOT_OBJECT"]
    return value, payload_sha, []


def _lineage(
    *, payload: Mapping[str, Any] | None, ea_id: str, symbol: str, setfile_path: str
) -> tuple[dict[str, Any], list[str]]:
    derived = _derived_lineage(ea_id, symbol, setfile_path)
    reasons: list[str] = []
    explicit: list[str] = []
    if payload is not None:
        for field in ("candidate_lineage_key", "lineage_key"):
            if field not in payload:
                continue
            value = _trimmed(payload[field])
            if value is None:
                reasons.append("PAYLOAD_LINEAGE_INVALID")
            else:
                explicit.append(value)
    explicit = sorted(set(explicit))
    conflict = len(explicit) > 1
    if conflict:
        reasons.append("LINEAGE_KEY_CONFLICT")
        key = "conflict:" + canonical_sha256(explicit)
        basis = "CONFLICT"
    elif explicit:
        key = explicit[0]
        basis = "EXPLICIT_PAYLOAD"
    else:
        key = derived
        basis = "DERIVED_IDENTITY"
    return {
        "key": key,
        "basis": basis,
        "derived_key": derived,
        "explicit_keys": explicit,
        "conflict": conflict,
    }, reasons


def _aliases(
    *, work_item_id: str, derived_lineage: str, payload: Mapping[str, Any] | None
) -> tuple[list[dict[str, Any]], list[str]]:
    aliases: dict[str, set[str]] = defaultdict(set)
    reasons: list[str] = []
    aliases[work_item_id].add("WORK_ITEM_ID")
    aliases["candidate:" + derived_lineage].add("DERIVED_IDENTITY")
    if payload is not None:
        for field in ("aliases", "legacy_aliases"):
            if field not in payload:
                continue
            raw_values = payload[field]
            if not isinstance(raw_values, list):
                reasons.append("PAYLOAD_ALIAS_LIST_INVALID")
                continue
            for raw_alias in raw_values:
                alias = _trimmed(raw_alias)
                if alias is None:
                    reasons.append("PAYLOAD_ALIAS_INVALID")
                    continue
                aliases[alias].add("PAYLOAD_ALIAS")
        for field in (
            "legacy_work_item_id",
            "source_work_item_id",
            "q08_work_item_id",
            "promoted_from_work_item",
            "promoted_from_p2_work_item",
            "supersedes_work_item_id",
            "superseded_by_work_item_id",
        ):
            if field not in payload:
                continue
            alias = _trimmed(payload[field])
            if alias is None:
                reasons.append("PAYLOAD_REFERENCE_INVALID")
                continue
            aliases[alias].add("PAYLOAD_REFERENCE")
    result = [
        {"alias": alias, "origins": sorted(origins)}
        for alias, origins in sorted(aliases.items())
    ]
    return result, reasons


def _artifact_binding(
    role: str,
    declared_path: Any,
    artifact_root: Path | None,
) -> dict[str, Any]:
    if declared_path is None or declared_path == "":
        return {
            "role": role,
            "declared_path": None,
            "state": "NOT_DECLARED",
            "sha256": None,
        }
    if not isinstance(declared_path, str):
        return {
            "role": role,
            "declared_path": repr(declared_path),
            "state": "INVALID_PATH",
            "sha256": None,
        }
    if artifact_root is None:
        return {
            "role": role,
            "declared_path": declared_path,
            "state": "NOT_CHECKED",
            "sha256": None,
        }
    try:
        root = Path(artifact_root).resolve(strict=True)
    except FileNotFoundError:
        return {
            "role": role,
            "declared_path": declared_path,
            "state": "ARTIFACT_ROOT_MISSING",
            "sha256": None,
        }
    candidate = Path(declared_path)
    if not candidate.is_absolute():
        candidate = root / candidate
    if candidate.is_symlink():
        state = "SYMLINK"
        digest = None
    else:
        try:
            resolved = candidate.resolve(strict=True)
        except FileNotFoundError:
            state = "MISSING"
            digest = None
        except OSError:
            state = "UNREADABLE"
            digest = None
        else:
            if not resolved.is_relative_to(root):
                state = "OUTSIDE_ROOT"
                digest = None
            elif not resolved.is_file():
                state = "NON_REGULAR"
                digest = None
            else:
                try:
                    digest = sha256_file(resolved)
                except OSError:
                    state = "UNREADABLE"
                    digest = None
                else:
                    state = "VERIFIED"
    return {
        "role": role,
        "declared_path": declared_path,
        "state": state,
        "sha256": digest,
    }


def _normalize_target_manifest(value: Any) -> dict[str, Any]:
    root = _exact_object(value, {"schema_version", "targets"}, "current-target manifest")
    if root["schema_version"] != TARGETS_SCHEMA_VERSION:
        raise InventoryError("unsupported current-target manifest schema_version")
    if type(root["targets"]) is not list:
        raise InventoryError("current-target manifest targets must be an array")
    normalized: list[dict[str, str]] = []
    seen: set[tuple[str, str, str]] = set()
    for index, raw in enumerate(root["targets"]):
        row = _exact_object(
            raw, {"target", "selector_type", "selector"}, f"targets[{index}]"
        )
        target = _nonempty_string(row["target"], f"targets[{index}].target").upper()
        selector_type = _nonempty_string(
            row["selector_type"], f"targets[{index}].selector_type"
        ).upper()
        selector = _nonempty_string(row["selector"], f"targets[{index}].selector")
        if target not in TARGETS:
            raise InventoryError(f"unsupported target: {target}")
        if selector_type not in SELECTOR_TYPES:
            raise InventoryError(f"unsupported target selector_type: {selector_type}")
        key = (target, selector_type, selector)
        if key in seen:
            raise InventoryError(f"duplicate current-target selector: {key}")
        seen.add(key)
        normalized.append(
            {"target": target, "selector_type": selector_type, "selector": selector}
        )
    normalized.sort(key=lambda row: (row["target"], row["selector_type"], row["selector"]))
    return {"schema_version": TARGETS_SCHEMA_VERSION, "targets": normalized}


def load_target_manifest(path: Path | None) -> dict[str, Any]:
    if path is None:
        return _normalize_target_manifest(
            {"schema_version": TARGETS_SCHEMA_VERSION, "targets": []}
        )
    return _normalize_target_manifest(
        load_json_file(Path(path), context="current-target manifest")
    )


def _targets_for_record(
    work_item_id: str,
    lineage_key: str,
    selectors: Sequence[Mapping[str, str]],
) -> tuple[list[str], set[int]]:
    targets: set[str] = set()
    matches: set[int] = set()
    for index, selector in enumerate(selectors):
        value = work_item_id if selector["selector_type"] == "WORK_ITEM_ID" else lineage_key
        if value == selector["selector"]:
            targets.add(selector["target"])
            matches.add(index)
    return sorted(targets), matches


def _classify(
    *, status: Any, verdict: Any, targets: Sequence[str], structural_reasons: Sequence[str]
) -> tuple[str, str, list[str]]:
    reasons = set(structural_reasons)
    if status not in TERMINAL_STATUSES:
        reasons.add("STATUS_NOT_TERMINAL")
    if verdict not in LEGACY_VERDICTS:
        reasons.add("UNKNOWN_LEGACY_VERDICT")
    invalidating = {
        "IDENTITY_INVALID",
        "PAYLOAD_NOT_TEXT",
        "PAYLOAD_JSON_INVALID",
        "PAYLOAD_NOT_OBJECT",
        "PAYLOAD_LINEAGE_INVALID",
        "LINEAGE_KEY_CONFLICT",
        "PAYLOAD_ALIAS_LIST_INVALID",
        "PAYLOAD_ALIAS_INVALID",
        "PAYLOAD_REFERENCE_INVALID",
        "STATUS_NOT_TERMINAL",
        "UNKNOWN_LEGACY_VERDICT",
    }
    if reasons & invalidating:
        disposition = "INVALID"
        priority = "HOLD_INVALID"
    elif verdict == "INVALID":
        disposition = "INVALID"
        priority = "HOLD_INVALID"
        reasons.add("LEGACY_EVIDENCE_INVALID")
    elif verdict == "SUPERSEDED_DUPLICATE":
        disposition = "SUPERSEDED"
        priority = "HOLD_SUPERSEDED"
    elif targets:
        disposition = "CURRENT"
        priority = "P0_CURRENT_TARGET"
        reasons.add("CURRENT_TARGET")
    elif verdict == "PASS":
        disposition = "ELIGIBLE_REEVALUATION"
        priority = "P1_V2_PASS"
    elif verdict == "FAIL_SOFT":
        disposition = "ELIGIBLE_REEVALUATION"
        priority = "P2_V2_FAIL_SOFT"
    else:
        disposition = "LEGACY_UNVERIFIED"
        priority = "P3_LEGACY"
        if verdict == "FAIL":
            reasons.add("LEGACY_UNNORMALIZED_FAIL")
    return disposition, priority, sorted(reasons)


def _build_record(
    row: sqlite3.Row,
    *,
    target_selectors: Sequence[Mapping[str, str]],
    artifact_root: Path | None,
) -> tuple[dict[str, Any], set[int]]:
    raw_sha = canonical_sha256(_raw_row_snapshot(row))
    reasons: list[str] = []
    identity_values: dict[str, str] = {}
    for field in ("id", "kind", "ea_id", "symbol", "setfile_path"):
        value = row[field]
        if not isinstance(value, str) or value.strip() != value or (
            field != "setfile_path" and not value
        ):
            reasons.append("IDENTITY_INVALID")
            identity_values[field] = "" if value is None else str(value)
        else:
            identity_values[field] = value
    if not identity_values["id"]:
        # Preserve cardinality even for a corrupt empty/non-text primary key.
        # The raw row hash retains the exact source identity; this deterministic
        # surrogate merely keeps the emitted JSON inside its strict schema.
        identity_values["id"] = "invalid-work-item:" + raw_sha

    payload, payload_sha, payload_reasons = _parse_payload(row["payload_json"])
    reasons.extend(payload_reasons)
    lineage, lineage_reasons = _lineage(
        payload=payload,
        ea_id=identity_values["ea_id"],
        symbol=identity_values["symbol"],
        setfile_path=identity_values["setfile_path"],
    )
    reasons.extend(lineage_reasons)
    aliases, alias_reasons = _aliases(
        work_item_id=identity_values["id"],
        derived_lineage=lineage["derived_key"],
        payload=payload,
    )
    reasons.extend(alias_reasons)
    targets, matched_selectors = _targets_for_record(
        identity_values["id"], lineage["key"], target_selectors
    )
    disposition, priority, reasons = _classify(
        status=row["status"],
        verdict=row["verdict"],
        targets=targets,
        structural_reasons=reasons,
    )
    legacy = {
        "kind": None if row["kind"] is None else str(row["kind"]),
        "phase": None if row["phase"] is None else str(row["phase"]),
        "status": None if row["status"] is None else str(row["status"]),
        "verdict": None if row["verdict"] is None else str(row["verdict"]),
        "attempt_count": row["attempt_count"] if type(row["attempt_count"]) is int else None,
        "parent_task_id": None if row["parent_task_id"] is None else str(row["parent_task_id"]),
        "claimed_by": None if row["claimed_by"] is None else str(row["claimed_by"]),
        "created_at": None if row["created_at"] is None else str(row["created_at"]),
        "updated_at": None if row["updated_at"] is None else str(row["updated_at"]),
        "payload_sha256": payload_sha,
        "raw_row_sha256": raw_sha,
    }
    record: dict[str, Any] = {
        "work_item_id": identity_values["id"],
        "ea_id": identity_values["ea_id"],
        "symbol": identity_values["symbol"],
        "setfile_path": identity_values["setfile_path"],
        "evidence_path": None if row["evidence_path"] is None else str(row["evidence_path"]),
        "legacy": legacy,
        "lineage": lineage,
        "aliases": aliases,
        "targets": targets,
        "artifacts": [
            _artifact_binding("SETFILE", row["setfile_path"], artifact_root),
            _artifact_binding("EVIDENCE", row["evidence_path"], artifact_root),
        ],
        "disposition": disposition,
        "priority": priority,
        "reason_codes": reasons,
    }
    record["record_sha256"] = canonical_sha256(record)
    return record, matched_selectors


def _collision(
    collision_type: str,
    key: str,
    records: Sequence[Mapping[str, Any]],
    *,
    blocking: bool,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "collision_type": collision_type,
        "key": key,
        "work_item_ids": sorted(str(row["work_item_id"]) for row in records),
        "lineage_keys": sorted({str(row["lineage"]["key"]) for row in records}),
        "blocking": blocking,
    }
    payload["collision_id"] = canonical_sha256(payload)
    return payload


def _collisions(records: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    by_lineage: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
    by_alias: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
    for record in records:
        by_lineage[str(record["lineage"]["key"])].append(record)
        for alias in record["aliases"]:
            by_alias[str(alias["alias"])].append(record)
    for key, rows in by_lineage.items():
        unique = {str(row["work_item_id"]): row for row in rows}
        if len(unique) <= 1:
            continue
        ordered = [unique[item_id] for item_id in sorted(unique)]
        active = [row for row in ordered if row["disposition"] != "SUPERSEDED"]
        result.append(
            _collision(
                "MULTIPLE_WORK_ITEMS_FOR_LINEAGE",
                key,
                ordered,
                blocking=len(active) > 1,
            )
        )
    for key, rows in by_alias.items():
        unique = {str(row["work_item_id"]): row for row in rows}
        lineages = {str(row["lineage"]["key"]) for row in unique.values()}
        if len(unique) <= 1 or len(lineages) <= 1:
            continue
        ordered = [unique[item_id] for item_id in sorted(unique)]
        result.append(
            _collision("ALIAS_TO_MULTIPLE_LINEAGES", key, ordered, blocking=True)
        )
    result.sort(key=lambda row: (row["collision_type"], row["key"], row["collision_id"]))
    return result


def _count_all(values: Sequence[str], domain: Sequence[str]) -> dict[str, int]:
    counts = Counter(values)
    return {name: int(counts.get(name, 0)) for name in domain}


def build_inventory(
    db_path: Path,
    *,
    current_targets: Mapping[str, Any] | None = None,
    artifact_root: Path | None = None,
    source_label: str | None = None,
) -> dict[str, Any]:
    """Return the complete content-addressed Q08 inventory without mutations."""

    label = source_label or Path(db_path).name
    _nonempty_string(label, "source_label")
    target_manifest = _normalize_target_manifest(
        current_targets
        if current_targets is not None
        else {"schema_version": TARGETS_SCHEMA_VERSION, "targets": []}
    )
    selectors = target_manifest["targets"]
    with open_read_only_database(Path(db_path)) as connection:
        schema = _work_item_schema(connection)
        quoted_columns = ",".join(f'"{name}"' for name in REQUIRED_WORK_ITEM_COLUMNS)
        rows = connection.execute(
            f"SELECT {quoted_columns} FROM work_items "
            "WHERE phase=? ORDER BY id COLLATE BINARY",
            ("Q08",),
        ).fetchall()

    records: list[dict[str, Any]] = []
    matched: set[int] = set()
    for row in rows:
        record, selector_matches = _build_record(
            row, target_selectors=selectors, artifact_root=artifact_root
        )
        records.append(record)
        matched.update(selector_matches)
    records.sort(key=lambda row: row["work_item_id"])
    if len({row["work_item_id"] for row in records}) != len(records):
        raise InventoryError("Q08 rowset contains duplicate work_item_id values")

    unmatched = [dict(selectors[index]) for index in range(len(selectors)) if index not in matched]
    collisions = _collisions(records)
    blocked_ids = sorted(
        {
            work_item_id
            for collision in collisions
            if collision["blocking"]
            for work_item_id in collision["work_item_ids"]
        }
    )
    summary = {
        "row_count": len(records),
        "disposition_counts": _count_all(
            [str(row["disposition"]) for row in records], DISPOSITIONS
        ),
        "priority_counts": _count_all(
            [str(row["priority"]) for row in records], PRIORITIES
        ),
        "legacy_verdict_counts": dict(
            sorted(Counter(str(row["legacy"]["verdict"]) for row in records).items())
        ),
        "collision_count": len(collisions),
        "blocking_collision_count": sum(bool(row["blocking"]) for row in collisions),
        "blocking_work_item_ids": blocked_ids,
        "unmatched_target_selectors": unmatched,
    }
    rowset_sha = canonical_sha256([row["legacy"]["raw_row_sha256"] for row in records])
    inventory: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "owner_authorization": "NONE",
        "runtime_action": "NONE",
        "database_access": {
            "sqlite_uri_mode": "ro",
            "pragma_query_only": True,
            "writes_supported": False,
        },
        "source": {
            "label": label,
            "phase": "Q08",
            "required_columns": list(REQUIRED_WORK_ITEM_COLUMNS),
            "schema_sha256": canonical_sha256(schema),
            "rowset_sha256": rowset_sha,
            "target_manifest_sha256": canonical_sha256(target_manifest),
            "artifact_verification": "ENABLED" if artifact_root is not None else "NOT_REQUESTED",
            "q08_policy_binding": canonical_q08_policy_binding(),
        },
        "records": records,
        "collisions": collisions,
        "summary": summary,
    }
    inventory["inventory_sha256"] = canonical_sha256(inventory)
    validate_inventory(inventory)
    return inventory


def _require_sha(value: Any, context: str) -> str:
    if not isinstance(value, str) or SHA256_RE.fullmatch(value) is None:
        raise InventoryError(f"{context} must be a lowercase SHA-256 digest")
    return value


def validate_inventory(value: Any) -> dict[str, Any]:
    """Validate strict keysets, cardinality, ordering, and all self-hashes."""

    root_keys = {
        "schema_version",
        "tool_version",
        "owner_authorization",
        "runtime_action",
        "database_access",
        "source",
        "records",
        "collisions",
        "summary",
        "inventory_sha256",
    }
    root = _exact_object(value, root_keys, "inventory")
    if root["schema_version"] != SCHEMA_VERSION:
        raise InventoryError("unsupported inventory schema_version")
    if root["tool_version"] != TOOL_VERSION:
        raise InventoryError("unsupported inventory tool_version")
    if root["owner_authorization"] != "NONE" or root["runtime_action"] != "NONE":
        raise InventoryError("inventory must not authorize OWNER or runtime action")
    access = _exact_object(
        root["database_access"],
        {"sqlite_uri_mode", "pragma_query_only", "writes_supported"},
        "inventory.database_access",
    )
    if access != {"sqlite_uri_mode": "ro", "pragma_query_only": True, "writes_supported": False}:
        raise InventoryError("inventory database_access is not fail-closed read-only")
    source = _exact_object(
        root["source"],
        {
            "label",
            "phase",
            "required_columns",
            "schema_sha256",
            "rowset_sha256",
            "target_manifest_sha256",
            "artifact_verification",
            "q08_policy_binding",
        },
        "inventory.source",
    )
    _nonempty_string(source["label"], "inventory.source.label")
    if source["phase"] != "Q08":
        raise InventoryError("inventory.source.phase must be Q08")
    if source["required_columns"] != list(REQUIRED_WORK_ITEM_COLUMNS):
        raise InventoryError("inventory.source.required_columns mismatch")
    for key in ("schema_sha256", "rowset_sha256", "target_manifest_sha256"):
        _require_sha(source[key], f"inventory.source.{key}")
    if source["artifact_verification"] not in {"ENABLED", "NOT_REQUESTED"}:
        raise InventoryError("inventory.source.artifact_verification unsupported")
    policy_binding = _exact_object(
        source["q08_policy_binding"],
        {"path", "file_sha256", "canonical_sha256", "policy_version"},
        "inventory.source.q08_policy_binding",
    )
    for key in ("path", "policy_version"):
        _nonempty_string(
            policy_binding[key], f"inventory.source.q08_policy_binding.{key}"
        )
    for key in ("file_sha256", "canonical_sha256"):
        _require_sha(
            policy_binding[key], f"inventory.source.q08_policy_binding.{key}"
        )
    if policy_binding != canonical_q08_policy_binding():
        raise InventoryError(
            "inventory source does not bind the current canonical Q08-v3 policy"
        )
    if type(root["records"]) is not list or type(root["collisions"]) is not list:
        raise InventoryError("inventory records and collisions must be arrays")
    record_keys = {
        "work_item_id",
        "ea_id",
        "symbol",
        "setfile_path",
        "evidence_path",
        "legacy",
        "lineage",
        "aliases",
        "targets",
        "artifacts",
        "disposition",
        "priority",
        "reason_codes",
        "record_sha256",
    }
    ids: list[str] = []
    for index, record_raw in enumerate(root["records"]):
        record = _exact_object(record_raw, record_keys, f"inventory.records[{index}]")
        item_id = _nonempty_string(record["work_item_id"], f"records[{index}].work_item_id")
        ids.append(item_id)
        if record["disposition"] not in DISPOSITIONS or record["priority"] not in PRIORITIES:
            raise InventoryError(f"records[{index}] has unsupported classification")
        for key in ("ea_id", "symbol", "setfile_path"):
            if not isinstance(record[key], str):
                raise InventoryError(f"records[{index}].{key} must be a string")
        if record["evidence_path"] is not None and not isinstance(record["evidence_path"], str):
            raise InventoryError(f"records[{index}].evidence_path must be string or null")
        legacy = _exact_object(
            record["legacy"],
            {
                "kind",
                "phase",
                "status",
                "verdict",
                "attempt_count",
                "parent_task_id",
                "claimed_by",
                "created_at",
                "updated_at",
                "payload_sha256",
                "raw_row_sha256",
            },
            f"records[{index}].legacy",
        )
        for key in ("payload_sha256", "raw_row_sha256"):
            _require_sha(legacy[key], f"records[{index}].legacy.{key}")
        if legacy["phase"] != "Q08":
            raise InventoryError(f"records[{index}].legacy.phase must be Q08")
        if legacy["attempt_count"] is not None and type(legacy["attempt_count"]) is not int:
            raise InventoryError(f"records[{index}].legacy.attempt_count must be integer or null")
        for key in (
            "kind",
            "status",
            "verdict",
            "parent_task_id",
            "claimed_by",
            "created_at",
            "updated_at",
        ):
            if legacy[key] is not None and not isinstance(legacy[key], str):
                raise InventoryError(f"records[{index}].legacy.{key} must be string or null")
        lineage = _exact_object(
            record["lineage"],
            {"key", "basis", "derived_key", "explicit_keys", "conflict"},
            f"records[{index}].lineage",
        )
        _nonempty_string(lineage["key"], f"records[{index}].lineage.key")
        _nonempty_string(lineage["derived_key"], f"records[{index}].lineage.derived_key")
        if lineage["basis"] not in LINEAGE_BASES or type(lineage["conflict"]) is not bool:
            raise InventoryError(f"records[{index}].lineage classification invalid")
        if type(lineage["explicit_keys"]) is not list:
            raise InventoryError(f"records[{index}].lineage.explicit_keys must be an array")
        if (
            any(not isinstance(item, str) or not item for item in lineage["explicit_keys"])
            or lineage["explicit_keys"] != sorted(lineage["explicit_keys"])
            or len(lineage["explicit_keys"]) != len(set(lineage["explicit_keys"]))
        ):
            raise InventoryError(f"records[{index}].lineage.explicit_keys must be uniquely sorted")
        if lineage["conflict"] != (lineage["basis"] == "CONFLICT"):
            raise InventoryError(f"records[{index}].lineage conflict/basis mismatch")
        if type(record["aliases"]) is not list or type(record["artifacts"]) is not list:
            raise InventoryError(f"records[{index}] aliases/artifacts must be arrays")
        alias_order: list[str] = []
        for alias_index, raw_alias in enumerate(record["aliases"]):
            alias = _exact_object(
                raw_alias,
                {"alias", "origins"},
                f"records[{index}].aliases[{alias_index}]",
            )
            alias_order.append(
                _nonempty_string(alias["alias"], f"records[{index}].aliases[{alias_index}].alias")
            )
            origins = alias["origins"]
            if (
                type(origins) is not list
                or not origins
                or origins != sorted(origins)
                or len(origins) != len(set(origins))
                or any(origin not in ALIAS_ORIGINS for origin in origins)
            ):
                raise InventoryError(f"records[{index}].aliases[{alias_index}].origins invalid")
        if alias_order != sorted(alias_order) or len(alias_order) != len(set(alias_order)):
            raise InventoryError(f"records[{index}].aliases must be uniquely sorted")
        targets = record["targets"]
        if (
            type(targets) is not list
            or targets != sorted(targets)
            or len(targets) != len(set(targets))
            or any(target not in TARGETS for target in targets)
        ):
            raise InventoryError(f"records[{index}].targets must be a sorted target set")
        if len(record["artifacts"]) != 2:
            raise InventoryError(f"records[{index}].artifacts must contain two bindings")
        for artifact_index, raw_artifact in enumerate(record["artifacts"]):
            artifact = _exact_object(
                raw_artifact,
                {"role", "declared_path", "state", "sha256"},
                f"records[{index}].artifacts[{artifact_index}]",
            )
            if artifact["role"] != ARTIFACT_ROLES[artifact_index]:
                raise InventoryError(f"records[{index}].artifacts role/order mismatch")
            if artifact["state"] not in ARTIFACT_STATES:
                raise InventoryError(f"records[{index}].artifacts[{artifact_index}] state invalid")
            if artifact["declared_path"] is not None and not isinstance(
                artifact["declared_path"], str
            ):
                raise InventoryError(f"records[{index}].artifacts[{artifact_index}] path invalid")
            if artifact["state"] == "VERIFIED":
                _require_sha(
                    artifact["sha256"], f"records[{index}].artifacts[{artifact_index}].sha256"
                )
            elif artifact["sha256"] is not None:
                raise InventoryError(f"records[{index}].artifacts[{artifact_index}] unexpected hash")
        reason_codes = record["reason_codes"]
        if (
            type(reason_codes) is not list
            or reason_codes != sorted(reason_codes)
            or len(reason_codes) != len(set(reason_codes))
            or any(not isinstance(reason, str) or not reason for reason in reason_codes)
        ):
            raise InventoryError(f"records[{index}].reason_codes must be uniquely sorted")
        declared = _require_sha(record["record_sha256"], f"records[{index}].record_sha256")
        unsigned = {key: child for key, child in record.items() if key != "record_sha256"}
        if declared != canonical_sha256(unsigned):
            raise InventoryError(f"records[{index}].record_sha256 mismatch")
    if ids != sorted(ids) or len(ids) != len(set(ids)):
        raise InventoryError("inventory records must be uniquely sorted by work_item_id")
    collision_keys = {
        "collision_type",
        "key",
        "work_item_ids",
        "lineage_keys",
        "blocking",
        "collision_id",
    }
    collision_order: list[tuple[str, str, str]] = []
    for index, raw in enumerate(root["collisions"]):
        collision = _exact_object(raw, collision_keys, f"inventory.collisions[{index}]")
        if collision["collision_type"] not in {
            "MULTIPLE_WORK_ITEMS_FOR_LINEAGE",
            "ALIAS_TO_MULTIPLE_LINEAGES",
        }:
            raise InventoryError(f"collisions[{index}].collision_type unsupported")
        if type(collision["blocking"]) is not bool:
            raise InventoryError(f"collisions[{index}].blocking must be boolean")
        for key in ("work_item_ids", "lineage_keys"):
            values = collision[key]
            if (
                type(values) is not list
                or not values
                or values != sorted(values)
                or len(values) != len(set(values))
                or any(not isinstance(item, str) or not item for item in values)
            ):
                raise InventoryError(f"collisions[{index}].{key} must be uniquely sorted")
        if any(item_id not in set(ids) for item_id in collision["work_item_ids"]):
            raise InventoryError(f"collisions[{index}] references unknown work item")
        declared = _require_sha(collision["collision_id"], f"collisions[{index}].collision_id")
        unsigned = {key: child for key, child in collision.items() if key != "collision_id"}
        if declared != canonical_sha256(unsigned):
            raise InventoryError(f"collisions[{index}].collision_id mismatch")
        collision_order.append(
            (collision["collision_type"], collision["key"], collision["collision_id"])
        )
    if collision_order != sorted(collision_order):
        raise InventoryError("inventory collisions are not deterministically sorted")
    summary = _exact_object(
        root["summary"],
        {
            "row_count",
            "disposition_counts",
            "priority_counts",
            "legacy_verdict_counts",
            "collision_count",
            "blocking_collision_count",
            "blocking_work_item_ids",
            "unmatched_target_selectors",
        },
        "inventory.summary",
    )
    if summary["row_count"] != len(root["records"]):
        raise InventoryError("inventory summary row_count mismatch")
    actual_dispositions = _count_all([row["disposition"] for row in root["records"]], DISPOSITIONS)
    actual_priorities = _count_all([row["priority"] for row in root["records"]], PRIORITIES)
    if summary["disposition_counts"] != actual_dispositions:
        raise InventoryError("inventory disposition_counts mismatch")
    if summary["priority_counts"] != actual_priorities:
        raise InventoryError("inventory priority_counts mismatch")
    actual_verdicts = dict(
        sorted(Counter(str(row["legacy"]["verdict"]) for row in root["records"]).items())
    )
    if summary["legacy_verdict_counts"] != actual_verdicts:
        raise InventoryError("inventory legacy_verdict_counts mismatch")
    if summary["collision_count"] != len(root["collisions"]):
        raise InventoryError("inventory collision_count mismatch")
    if summary["blocking_collision_count"] != sum(
        bool(row["blocking"]) for row in root["collisions"]
    ):
        raise InventoryError("inventory blocking_collision_count mismatch")
    actual_blocked = sorted(
        {
            item_id
            for collision in root["collisions"]
            if collision["blocking"]
            for item_id in collision["work_item_ids"]
        }
    )
    if summary["blocking_work_item_ids"] != actual_blocked:
        raise InventoryError("inventory blocking_work_item_ids mismatch")
    if source["rowset_sha256"] != canonical_sha256(
        [row["legacy"]["raw_row_sha256"] for row in root["records"]]
    ):
        raise InventoryError("inventory source.rowset_sha256 mismatch")
    declared_inventory = _require_sha(root["inventory_sha256"], "inventory.inventory_sha256")
    unsigned_inventory = {key: child for key, child in root.items() if key != "inventory_sha256"}
    if declared_inventory != canonical_sha256(unsigned_inventory):
        raise InventoryError("inventory_sha256 mismatch")
    return root


def render_json_bytes(value: Mapping[str, Any]) -> bytes:
    """Stable human-readable bytes; generation has no timestamp or host path."""

    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False)
        + "\n"
    ).encode("utf-8")


def write_create_new(value: Mapping[str, Any], output: Path) -> Path:
    """Create an artifact without overwriting an earlier inventory."""

    path = Path(output)
    path.parent.mkdir(parents=True, exist_ok=True)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_BINARY", 0)
    descriptor = os.open(str(path), flags, 0o444)
    try:
        with os.fdopen(descriptor, "wb", closefd=True) as handle:
            descriptor = -1
            handle.write(render_json_bytes(value))
            handle.flush()
            os.fsync(handle.fileno())
    finally:
        if descriptor >= 0:
            os.close(descriptor)
    return path


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, required=True, help="Existing SQLite database")
    parser.add_argument("--current-targets", type=Path)
    parser.add_argument("--artifact-root", type=Path)
    parser.add_argument("--source-label")
    parser.add_argument("--output", type=Path, help="Create-new JSON path (default: stdout)")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        inventory = build_inventory(
            args.db,
            current_targets=load_target_manifest(args.current_targets),
            artifact_root=args.artifact_root,
            source_label=args.source_label,
        )
        if args.output is not None:
            write_create_new(inventory, args.output)
        else:
            sys.stdout.buffer.write(render_json_bytes(inventory))
        return 0
    except (InventoryError, OSError, sqlite3.Error) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
