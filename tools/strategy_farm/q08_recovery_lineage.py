"""Fail-closed lineage bindings for append-only Q08 recovery rows.

The stranded-INFRA sweep creates a new work-item id.  Owner-authorized Q08
requalification rows can carry artifact bindings that must survive that
identity change.  This module extracts those bindings without mutating any
historical row and verifies every durable byte before enqueue and again before
dispatch.
"""

from __future__ import annotations

import hashlib
import json
import re
import sqlite3
from pathlib import Path
from typing import Any, Mapping


SCHEMA_VERSION = "qm.q08-recovery-lineage/v1"
REQUIRED_ABLATION_ROLES = frozenset(
    {"setfile_ablation_00", "setfile_ablation_01", "setfile_ablation_02"}
)
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _validated_binding(raw: Mapping[str, Any]) -> tuple[dict[str, Any] | None, str | None]:
    role = str(raw.get("role") or "").strip()
    raw_path = str(raw.get("path") or "").strip()
    expected_sha = str(raw.get("sha256") or "").strip().lower()
    if not role:
        return None, "artifact_role_missing"
    if not raw_path:
        return None, f"artifact_path_missing:{role}"
    if not _SHA256_RE.fullmatch(expected_sha):
        return None, f"artifact_sha256_invalid:{role}"
    path = Path(raw_path)
    if not path.is_absolute():
        return None, f"artifact_path_not_absolute:{role}"
    if not path.is_file():
        return None, f"artifact_missing:{role}:{path}"
    try:
        actual_sha = sha256_file(path)
        actual_bytes = path.stat().st_size
    except OSError as exc:
        return None, f"artifact_unreadable:{role}:{type(exc).__name__}"
    if actual_sha != expected_sha:
        return None, f"artifact_sha256_mismatch:{role}"
    recorded_bytes = raw.get("bytes")
    if recorded_bytes is not None:
        try:
            if int(recorded_bytes) != actual_bytes:
                return None, f"artifact_size_mismatch:{role}"
        except (TypeError, ValueError):
            return None, f"artifact_size_invalid:{role}"
    return {
        "role": role,
        "path": str(path.resolve()),
        "sha256": actual_sha,
        "bytes": actual_bytes,
        "sha256_basis": str(raw.get("sha256_basis") or "RAW_BYTES"),
    }, None


def _pinned_file(role: str, path: Path) -> tuple[dict[str, Any] | None, str | None]:
    try:
        binding = {
            "role": role,
            "path": str(path.resolve()),
            "sha256": sha256_file(path),
            "bytes": path.stat().st_size,
            "sha256_basis": "RAW_BYTES",
        }
    except OSError as exc:
        return None, f"artifact_missing:{role}:{path}:{type(exc).__name__}"
    return binding, None


def validate_q08_recovery_lineage(
    lineage: Mapping[str, Any],
) -> tuple[bool, str, dict[str, Any] | None]:
    """Re-hash every required binding; never trust copied payload metadata."""
    if str(lineage.get("schema_version") or "") != SCHEMA_VERSION:
        return False, "schema_version_mismatch", None
    for field in ("retry_source_work_item_id", "lineage_source_work_item_id"):
        if not str(lineage.get(field) or "").strip():
            return False, f"{field}_missing", None

    raw_bindings = lineage.get("artifact_bindings")
    if not isinstance(raw_bindings, list) or not raw_bindings:
        return False, "artifact_bindings_missing", None
    bindings: list[dict[str, Any]] = []
    roles: set[str] = set()
    for raw in raw_bindings:
        if not isinstance(raw, Mapping):
            return False, "artifact_binding_not_object", None
        binding, error = _validated_binding(raw)
        if error:
            return False, error, None
        assert binding is not None
        if binding["role"] in roles:
            return False, f"artifact_role_duplicate:{binding['role']}", None
        roles.add(binding["role"])
        bindings.append(binding)
    missing_roles = sorted(REQUIRED_ABLATION_ROLES - roles)
    if missing_roles:
        return False, f"required_ablation_roles_missing:{','.join(missing_roles)}", None

    raw_archived = lineage.get("archived_report_artifacts")
    if not isinstance(raw_archived, list) or not raw_archived:
        return False, "archived_report_artifacts_missing", None
    archived: list[dict[str, Any]] = []
    archived_roles: set[str] = set()
    for raw in raw_archived:
        if not isinstance(raw, Mapping):
            return False, "archived_report_binding_not_object", None
        binding, error = _validated_binding(raw)
        if error:
            return False, error, None
        assert binding is not None
        archived_roles.add(binding["role"])
        archived.append(binding)
    required_archived = {"archived_q08_aggregate", "archived_q08_5_result"}
    missing_archived = sorted(required_archived - archived_roles)
    if missing_archived:
        return False, f"archived_report_roles_missing:{','.join(missing_archived)}", None

    fresh_targets = lineage.get("fresh_artifact_targets")
    if not isinstance(fresh_targets, list) or not fresh_targets:
        return False, "fresh_artifact_targets_missing", None
    for target in fresh_targets:
        if not isinstance(target, Mapping):
            return False, "fresh_artifact_target_not_object", None
        if not str(target.get("role") or "").strip() or not str(target.get("path") or "").strip():
            return False, "fresh_artifact_target_invalid", None

    normalized = dict(lineage)
    normalized["artifact_bindings"] = bindings
    normalized["archived_report_artifacts"] = archived
    return True, "hash_pins_match", normalized


def build_q08_recovery_lineage(
    conn: sqlite3.Connection,
    reports_root: Path,
    *,
    ea_id: str,
    symbol: str,
    setfile_path: str,
) -> tuple[dict[str, Any] | None, str | None]:
    """Return a verified carry-forward contract, or ``None`` for ordinary rows.

    A malformed owner-authorized lineage is an error, not an invitation to
    silently downgrade the retry to an unbound generic row.
    """
    rows = conn.execute(
        """
        SELECT id, evidence_path, payload_json, updated_at
        FROM work_items
        WHERE ea_id=? AND symbol=? AND phase='Q08'
          AND ifnull(setfile_path, '')=ifnull(?, '')
        ORDER BY updated_at DESC, created_at DESC, id DESC
        """,
        (ea_id, symbol, setfile_path),
    ).fetchall()
    if not rows:
        return None, None
    retry_source_id = str(rows[0]["id"])

    lineage_row: sqlite3.Row | None = None
    lineage_payload: dict[str, Any] | None = None
    for row in rows:
        try:
            payload = json.loads(row["payload_json"] or "{}")
        except (TypeError, json.JSONDecodeError):
            continue
        requal = payload.get("q08_single_target_requalification")
        if isinstance(requal, dict) and requal.get("artifact_bindings"):
            lineage_row = row
            lineage_payload = payload
            break
    if lineage_row is None or lineage_payload is None:
        return None, None

    requal = lineage_payload["q08_single_target_requalification"]
    raw_bindings = requal.get("artifact_bindings")
    if not isinstance(raw_bindings, list):
        return None, "artifact_bindings_not_list"
    bindings: list[dict[str, Any]] = []
    for raw in raw_bindings:
        if not isinstance(raw, Mapping):
            return None, "artifact_binding_not_object"
        if str(raw.get("role") or "").strip() not in REQUIRED_ABLATION_ROLES:
            continue
        binding, error = _validated_binding(raw)
        if error:
            return None, error
        assert binding is not None
        bindings.append(binding)
    roles = {binding["role"] for binding in bindings}
    missing_roles = sorted(REQUIRED_ABLATION_ROLES - roles)
    if missing_roles:
        return None, f"required_ablation_roles_missing:{','.join(missing_roles)}"

    archive_raw = str(
        requal.get("archived_report_root")
        or lineage_payload.get("archived_report_root_on_requeue")
        or ""
    ).strip()
    if not archive_raw:
        return None, "archived_report_root_missing"
    archive_root = Path(archive_raw)
    if not archive_root.is_absolute():
        return None, "archived_report_root_not_absolute"
    leaf = archive_root / ea_id / "Q08" / symbol.replace(".", "_")
    archived: list[dict[str, Any]] = []
    for role, path in (
        ("archived_q08_aggregate", leaf / "aggregate.json"),
        ("archived_q08_5_result", leaf / "8_5_neighborhood.json"),
    ):
        binding, error = _pinned_file(role, path)
        if error:
            return None, error
        assert binding is not None
        archived.append(binding)

    lineage = {
        "schema_version": SCHEMA_VERSION,
        "retry_source_work_item_id": retry_source_id,
        "lineage_source_work_item_id": str(lineage_row["id"]),
        "archived_report_root": str(archive_root.resolve()),
        "artifact_bindings": bindings,
        "archived_report_artifacts": archived,
        "fresh_artifact_targets": [
            {
                "role": "q08_5_perturbations",
                "path": str(
                    (
                        reports_root
                        / "pipeline"
                        / ea_id
                        / "Q08"
                        / "neighborhood"
                        / symbol.replace(".", "_")
                        / "perturbations.json"
                    ).resolve()
                ),
                "preexisting_required": False,
            }
        ],
        "historical_rows_mutated": False,
    }
    ok, reason, normalized = validate_q08_recovery_lineage(lineage)
    if not ok:
        return None, reason
    return normalized, None
