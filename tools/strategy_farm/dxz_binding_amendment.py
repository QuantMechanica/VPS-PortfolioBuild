"""Fail-closed resolver for versioned DXZ repair-spec binding amendments.

The dated repair specs remain immutable historical records.  An amendment may
replace only explicitly enumerated file-binding rows, and only when both the
base spec and the OWNER repair decision are content-addressed.  It grants no
qualification, deployment, MT5, or runtime authority.
"""

from __future__ import annotations

import copy
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence


SHA_RE = re.compile(r"^[0-9a-f]{64}$")
AMENDMENT_SCHEMA = "qm.dxz-repair-spec-binding-amendment/v1"
OWNER_DECISION_SCHEMA = "qm.factory-restart-owner-preparation-decision/v1"
OWNER_DECISION_COMMIT = "7b36ff27f83f024bf1c43bb5537cc747f52b887a"
OWNER_DECISION_BLOB_SHA1 = "6d36cf6682e317324a35bc8388042402b0f3e540"
OWNER_DECISION_PATH = (
    "C:/QM/repo/docs/ops/evidence/2026-07-30_factory_preparation_owner_decision.json"
)
AMENDMENT_KEYS = {
    "schema_version",
    "artifact_type",
    "amendment_id",
    "packet_id",
    "scope",
    "disposition",
    "qualification_effect",
    "runtime_mutation_performed",
    "silent_rebinding",
    "recorded_at_utc",
    "supersedes",
    "owner_decision",
    "binding_changes",
    "open_strategy_decisions",
    "amendment_payload_sha256",
}
OWNER_REQUIRED_EXCLUSIONS = {
    "factory_on",
    "scheduled_task_mutation",
    "factory_off_flag_mutation",
    "hold_release_now",
    "process_or_terminal_start_stop",
    "database_mutation",
    "autotrading_toggle",
    "t_live_mutation",
    "live_or_ftmo_task_contract_apply",
    "deployment",
}


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _git_blob_sha1_file(path: Path) -> str:
    raw = path.read_bytes()
    return _git_blob_sha1_bytes(raw)


def _git_blob_sha1_bytes(raw: bytes) -> str:
    return hashlib.sha1(f"blob {len(raw)}\0".encode("ascii") + raw).hexdigest()


def _canonical_sha(payload: Any) -> str:
    encoded = json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"DUPLICATE_JSON_KEY: {key}")
        result[key] = value
    return result


def _load_object_bytes(raw: bytes, *, label: str) -> dict[str, Any]:
    try:
        payload = json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=_reject_duplicate_keys,
        )
    except (UnicodeError, json.JSONDecodeError, ValueError) as exc:
        raise ValueError(f"{label}_READ_ERROR: {exc}") from exc
    if not isinstance(payload, dict):
        raise ValueError(f"{label}_ROOT_INVALID")
    return payload


def _load_object(path: Path, *, label: str) -> dict[str, Any]:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise ValueError(f"{label}_READ_ERROR: {exc}") from exc
    return _load_object_bytes(raw, label=label)


def _parse_utc(raw: Any, *, label: str) -> datetime:
    text = str(raw or "")
    if not text.endswith("Z"):
        raise ValueError(f"{label}_INVALID")
    try:
        value = datetime.fromisoformat(text[:-1] + "+00:00")
    except ValueError as exc:
        raise ValueError(f"{label}_INVALID") from exc
    if value.tzinfo is None or value.utcoffset() != timezone.utc.utcoffset(value):
        raise ValueError(f"{label}_INVALID")
    return value


def _bound_path(raw: Any, *, base_dir: Path, label: str) -> tuple[Path, bytes]:
    if not isinstance(raw, Mapping):
        raise ValueError(f"{label}_BINDING_INVALID")
    path_text = str(raw.get("path") or "").strip()
    expected = str(raw.get("sha256") or "").strip().lower()
    if not path_text or SHA_RE.fullmatch(expected) is None:
        raise ValueError(f"{label}_BINDING_FIELDS_INVALID")
    path = Path(path_text)
    if not path.is_absolute():
        path = base_dir / path
    path = path.resolve(strict=False)
    if not path.is_file():
        raise ValueError(f"{label}_BINDING_MISSING: {path}")
    expected_bytes = raw.get("bytes")
    if type(expected_bytes) is not int or expected_bytes <= 0:
        raise ValueError(f"{label}_BINDING_SIZE_INVALID")
    try:
        content = path.read_bytes()
    except OSError as exc:
        raise ValueError(f"{label}_BINDING_READ_ERROR: {exc}") from exc
    actual = _sha256_bytes(content)
    if actual != expected:
        raise ValueError(
            f"{label}_BINDING_HASH_MISMATCH: expected={expected} actual={actual}"
        )
    if len(content) != expected_bytes:
        raise ValueError(f"{label}_BINDING_SIZE_MISMATCH")
    return path, content


def _binding_identity(raw: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "id": raw.get("id"),
        "role": raw.get("role"),
        "path": raw.get("path"),
        "sha256": raw.get("sha256"),
        "bytes": raw.get("bytes"),
    }


def load_binding_amendment(
    amendment_path: Path,
    *,
    amendment_artifact_type: str,
    amendment_id: str,
    base_artifact_type: str,
    packet_id: str,
    binding_container: Sequence[str],
    required_change_ids: set[str],
    expected_base_binding: Mapping[str, Any],
    expected_after_bindings: Mapping[str, Mapping[str, Any]],
    expected_open_strategy_decisions: set[str],
    expected_scope: Mapping[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Resolve and validate one content-addressed binding-only amendment."""

    amendment_path = amendment_path.resolve()
    try:
        amendment_raw = amendment_path.read_bytes()
    except OSError as exc:
        raise ValueError(f"AMENDMENT_READ_ERROR: {exc}") from exc
    amendment = _load_object_bytes(amendment_raw, label="AMENDMENT")
    if set(amendment) != AMENDMENT_KEYS:
        raise ValueError("AMENDMENT_FIELDS_INVALID")
    if amendment.get("schema_version") != AMENDMENT_SCHEMA:
        raise ValueError("AMENDMENT_SCHEMA_INVALID")
    if amendment.get("artifact_type") != amendment_artifact_type:
        raise ValueError("AMENDMENT_TYPE_INVALID")
    if amendment.get("amendment_id") != amendment_id:
        raise ValueError("AMENDMENT_ID_INVALID")
    if amendment.get("packet_id") != packet_id:
        raise ValueError("AMENDMENT_PACKET_INVALID")
    if amendment.get("scope") != dict(expected_scope):
        raise ValueError("AMENDMENT_SCOPE_INVALID")
    if amendment.get("disposition") != "BINDING_RECONCILIATION_ONLY":
        raise ValueError("AMENDMENT_DISPOSITION_INVALID")
    if amendment.get("qualification_effect") != "NONE_REMAINS_BLOCKED":
        raise ValueError("AMENDMENT_QUALIFICATION_SCOPE_INVALID")
    if amendment.get("runtime_mutation_performed") is not False:
        raise ValueError("AMENDMENT_RUNTIME_SCOPE_INVALID")
    if amendment.get("silent_rebinding") is not False:
        raise ValueError("AMENDMENT_SILENT_REBIND_INVALID")
    amendment_recorded_at = _parse_utc(
        amendment.get("recorded_at_utc"), label="AMENDMENT_RECORDED_AT"
    )
    open_decisions = amendment.get("open_strategy_decisions")
    if (
        not isinstance(open_decisions, list)
        or any(not isinstance(item, str) for item in open_decisions)
        or set(open_decisions) != expected_open_strategy_decisions
        or len(open_decisions) != len(expected_open_strategy_decisions)
    ):
        raise ValueError("AMENDMENT_OPEN_DECISIONS_INVALID")

    declared_payload_sha = str(amendment.get("amendment_payload_sha256") or "").lower()
    unsigned = dict(amendment)
    unsigned.pop("amendment_payload_sha256", None)
    if (
        SHA_RE.fullmatch(declared_payload_sha) is None
        or _canonical_sha(unsigned) != declared_payload_sha
    ):
        raise ValueError("AMENDMENT_PAYLOAD_HASH_INVALID")

    if amendment.get("supersedes") != dict(expected_base_binding):
        raise ValueError("AMENDMENT_BASE_SPEC_BINDING_POLICY_MISMATCH")
    base_path, base_raw = _bound_path(
        amendment.get("supersedes"),
        base_dir=amendment_path.parent,
        label="AMENDMENT_BASE_SPEC",
    )
    if _git_blob_sha1_bytes(base_raw) != expected_base_binding.get("git_blob_sha1"):
        raise ValueError("AMENDMENT_BASE_SPEC_GIT_BINDING_INVALID")
    base_spec = _load_object_bytes(base_raw, label="AMENDMENT_BASE_SPEC")
    if (
        base_spec.get("artifact_type") != base_artifact_type
        or base_spec.get("packet_id") != packet_id
    ):
        raise ValueError("AMENDMENT_BASE_SPEC_IDENTITY_INVALID")

    owner_path, owner_raw = _bound_path(
        amendment.get("owner_decision"),
        base_dir=amendment_path.parent,
        label="AMENDMENT_OWNER_DECISION",
    )
    owner = _load_object_bytes(owner_raw, label="AMENDMENT_OWNER_DECISION")
    owner_binding = amendment.get("owner_decision") or {}
    if (
        not isinstance(owner_binding, Mapping)
        or set(owner_binding)
        != {"path", "sha256", "bytes", "decision_id", "git_commit", "git_blob_sha1"}
        or owner_binding.get("git_commit") != OWNER_DECISION_COMMIT
        or owner_binding.get("git_blob_sha1") != OWNER_DECISION_BLOB_SHA1
        or owner_binding.get("path") != OWNER_DECISION_PATH
        or owner_path != Path(OWNER_DECISION_PATH).resolve()
        or _git_blob_sha1_bytes(owner_raw) != OWNER_DECISION_BLOB_SHA1
    ):
        raise ValueError("AMENDMENT_OWNER_DECISION_GIT_BINDING_INVALID")
    external = owner.get("external_residuals") or {}
    exclusions = owner.get("explicit_exclusions") or {}
    if (
        owner.get("schema_version") != OWNER_DECISION_SCHEMA
        or owner.get("status") != "APPROVED_WITH_EXPLICIT_BOUNDARIES"
        or owner.get("authority") != "OWNER"
        or owner.get("authorized_by") != "OWNER"
        or owner.get("decision_channel") != "interactive_owner_chat"
        or owner.get("decision_id") != owner_binding.get("decision_id")
        or external.get("disposition") != "REPAIR_NO_WAIVER"
        or external.get("required_exit")
        != "ALL_FIVE_DECLARED_EXTERNAL_RESIDUAL_TESTS_PASS"
        or external.get("silent_rebinding_allowed") is not False
        or external.get("skip_xfail_or_assertion_weakening_allowed") is not False
        or external.get("governance_exit_contract_revision_authorized") is not False
        or "VERSIONED_BINDING_AMENDMENTS_WITH_DRIFT_LEDGER"
        not in (external.get("repair_scope") or [])
        or not isinstance(exclusions, Mapping)
        or not OWNER_REQUIRED_EXCLUSIONS.issubset(exclusions)
        or any(exclusions[key] is not False for key in OWNER_REQUIRED_EXCLUSIONS)
    ):
        raise ValueError("AMENDMENT_OWNER_DECISION_SCOPE_INVALID")
    owner_authorized_at = _parse_utc(
        owner.get("authorized_at_utc"), label="AMENDMENT_OWNER_AUTHORIZED_AT"
    )
    owner_expires_at = _parse_utc(
        owner.get("authorization_expires_at_utc"),
        label="AMENDMENT_OWNER_EXPIRES_AT",
    )
    if not owner_authorized_at <= amendment_recorded_at <= owner_expires_at:
        raise ValueError("AMENDMENT_OWNER_DECISION_TIME_SCOPE_INVALID")

    container: Any = base_spec
    for key in binding_container:
        if not isinstance(container, Mapping):
            raise ValueError("AMENDMENT_BINDING_CONTAINER_INVALID")
        container = container.get(key)
    if not isinstance(container, list):
        raise ValueError("AMENDMENT_BINDING_CONTAINER_INVALID")
    bindings = {
        str(row.get("id")): row
        for row in container
        if isinstance(row, Mapping) and row.get("id")
    }

    changes = amendment.get("binding_changes")
    if not isinstance(changes, list):
        raise ValueError("AMENDMENT_CHANGES_INVALID")
    change_ids = {
        str(row.get("id"))
        for row in changes
        if isinstance(row, Mapping) and row.get("id")
    }
    if change_ids != required_change_ids or len(changes) != len(required_change_ids):
        raise ValueError("AMENDMENT_CHANGE_SET_INVALID")
    if set(expected_after_bindings) != required_change_ids:
        raise ValueError("AMENDMENT_EXPECTED_AFTER_POLICY_INVALID")

    replacements: dict[str, dict[str, Any]] = {}
    for change in changes:
        if not isinstance(change, Mapping):
            raise ValueError("AMENDMENT_CHANGE_INVALID")
        if set(change) != {"id", "reason", "before", "after"}:
            raise ValueError("AMENDMENT_CHANGE_FIELDS_INVALID")
        binding_id = str(change.get("id") or "")
        before = change.get("before")
        after = change.get("after")
        if not isinstance(before, Mapping) or not isinstance(after, Mapping):
            raise ValueError(f"AMENDMENT_CHANGE_BINDING_INVALID: {binding_id}")
        if set(before) != {"id", "role", "path", "sha256", "bytes"}:
            raise ValueError(f"AMENDMENT_BEFORE_FIELDS_INVALID: {binding_id}")
        current = bindings.get(binding_id)
        if current is None or _binding_identity(current) != dict(before):
            raise ValueError(f"AMENDMENT_BEFORE_BINDING_MISMATCH: {binding_id}")
        after_identity = dict(after)
        if set(after_identity) != {"id", "role", "path", "sha256", "bytes"}:
            raise ValueError(f"AMENDMENT_AFTER_FIELDS_INVALID: {binding_id}")
        if (
            after_identity.get("id") != binding_id
            or SHA_RE.fullmatch(str(after_identity.get("sha256") or "").lower()) is None
            or type(after_identity.get("bytes")) is not int
            or int(after_identity["bytes"]) <= 0
            or not str(after_identity.get("path") or "").strip()
            or not str(after_identity.get("role") or "").strip()
        ):
            raise ValueError(f"AMENDMENT_AFTER_BINDING_INVALID: {binding_id}")
        if after_identity != dict(expected_after_bindings[binding_id]):
            raise ValueError(f"AMENDMENT_AFTER_BINDING_POLICY_MISMATCH: {binding_id}")
        if _binding_identity(current) == after_identity:
            raise ValueError(f"AMENDMENT_CHANGE_IS_NOOP: {binding_id}")
        if not str(change.get("reason") or "").strip():
            raise ValueError(f"AMENDMENT_CHANGE_REASON_MISSING: {binding_id}")
        replacements[binding_id] = after_identity

    resolved = copy.deepcopy(base_spec)
    resolved_container: Any = resolved
    for key in binding_container:
        resolved_container = resolved_container[key]
    for index, binding in enumerate(resolved_container):
        binding_id = str(binding.get("id") or "") if isinstance(binding, Mapping) else ""
        if binding_id in replacements:
            resolved_container[index] = replacements[binding_id]
    resolved["binding_amendment"] = {
        "amendment_id": amendment.get("amendment_id"),
        "amendment_path": str(amendment_path),
        "amendment_sha256": _sha256_bytes(amendment_raw),
        "base_spec_path": str(base_path),
        "base_spec_sha256": _sha256_bytes(base_raw),
        "owner_decision_path": str(owner_path),
        "owner_decision_sha256": _sha256_bytes(owner_raw),
        "qualification_effect": "NONE_REMAINS_BLOCKED",
    }
    return resolved, amendment
