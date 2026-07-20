"""Fail-closed phase and evidence fence for QM5_20009 research runs.

Invoke immediately before a tester launch.  If ``--receipt`` is supplied, invoke
the same command after the run with ``--postflight-receipt`` to prove that mutable
news and Model-4 data files did not change while the EA was running.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import sys
from datetime import date, datetime
from pathlib import Path, PurePosixPath
from typing import Any, Mapping

import generate_research_sets as freeze


class FenceError(RuntimeError):
    pass


SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
UTC_TIMESTAMP_RE = re.compile(
    r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}"
    r"(?:\.[0-9]{1,6})?(?:Z|[+-][0-9]{2}:[0-9]{2})$"
)
FREEZE_IDENTITY_FIELDS = {"freeze_inputs_sha256", "manifest_sha256"}
BOUND_ARTIFACT_FIELDS = {
    "path",
    "size_bytes",
    "sha256",
    "sidecar_path",
    "sidecar_file_sha256",
}
FILE_BINDING_FIELDS = {"path", "size_bytes", "sha256"}
INVENTORY_FIELDS = {
    "schema_version",
    "artifact_type",
    "status",
    "created_utc",
    "protocol_id",
    "phase_id",
    "freeze_identity",
    "matrix_contract",
    "common_toolchain_sha256",
    "common_toolchain",
    "cells",
}
EVIDENCE_FIELDS = {
    "schema_version",
    "artifact_type",
    "status",
    "created_utc",
    "phase_id",
    "matrix_status",
    "duplicate_counting_policy",
    "baseline_formula",
    "binding_gates",
    "transport_diagnostic",
    "mandatory_reported_cells",
    "selected_configuration",
    "protocol_id",
    "freeze_identity",
    "inventory_binding",
    "adjudicator_binding",
}
DEV_MARKETS = ["NDX.DWX", "GDAXI.DWX", "GBPUSD.DWX", "EURUSD.DWX"]
DEV_VARIANTS = [
    "center",
    "pivot_low",
    "pivot_high",
    "reclaim_low",
    "reclaim_high",
    "mss_low",
    "mss_high",
    "fvg_low",
    "fvg_high",
    "stop_low",
    "stop_high",
    "rr_low",
    "rr_high",
]
RUN_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{15,199}$")
SNAPSHOT_FILE_FIELDS = {
    "role",
    "repo_relative_path",
    "source_path",
    "snapshot_path",
    "size_bytes",
    "sha256",
}
SNAPSHOT_MANIFEST_FIELDS = {
    "schema_version",
    "artifact_type",
    "status",
    "run_id",
    "source_repo_root",
    "snapshot_root",
    "snapshot_repo_root",
    "freeze_identity",
    "request",
    "files",
    "closure_sha256",
}
SNAPSHOT_BINDING_FIELDS = {
    "root_path",
    "repo_root",
    "manifest_path",
    "manifest_size_bytes",
    "manifest_sha256",
    "manifest_sidecar_path",
    "manifest_sidecar_sha256",
    "selected_set_repo_relative",
    "role_bindings",
}
SNAPSHOT_ROLE_BINDING_FIELDS = {"path", "size_bytes", "sha256"}
EXTERNAL_RUNTIME_FIELDS = {"role", "path", "size_bytes", "sha256"}
PRE_RECEIPT_FIELDS = {
    "schema_version",
    "artifact_type",
    "status",
    "run_id",
    "request",
    "freeze_inputs_sha256",
    "manifest_sha256",
    "set_sha256",
    "selected_data",
    "selected_data_sha256",
    "phase_unlock_records",
    "external_runtime",
    "runtime_snapshot",
}


def _reject_duplicate_json_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            raise FenceError(f"duplicate JSON key: {key}")
        value[key] = item
    return value


def _reject_nonfinite_json(value: str) -> None:
    raise FenceError(f"non-finite JSON number is forbidden: {value}")


def _canonical_json_bytes(payload: Mapping[str, Any]) -> bytes:
    try:
        encoded = json.dumps(
            payload,
            indent=2,
            sort_keys=True,
            ensure_ascii=True,
            allow_nan=False,
        )
    except (TypeError, ValueError) as exc:
        raise FenceError(f"verdict evidence is not canonical-JSON serializable: {exc}") from exc
    return (encoded + "\n").encode("ascii")


def _canonical_payload_sha256(payload: Any) -> str:
    try:
        encoded = json.dumps(
            payload,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=True,
            allow_nan=False,
        ).encode("ascii")
    except (TypeError, ValueError) as exc:
        raise FenceError(f"verdict evidence cannot be hashed canonically: {exc}") from exc
    return hashlib.sha256(encoded).hexdigest()


def _strict_canonical_json(raw: bytes, context: str) -> dict[str, Any]:
    try:
        payload = json.loads(
            raw.decode("utf-8-sig"),
            object_pairs_hook=_reject_duplicate_json_keys,
            parse_constant=_reject_nonfinite_json,
        )
    except FenceError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise FenceError(f"{context} JSON invalid") from exc
    if not isinstance(payload, dict):
        raise FenceError(f"{context} JSON root must be an object")
    if raw != _canonical_json_bytes(payload):
        raise FenceError(f"{context} is not canonical JSON")
    return payload


def _require_exact_keys(value: Mapping[str, Any], expected: set[str], context: str) -> None:
    missing = sorted(expected - set(value))
    extra = sorted(set(value) - expected)
    if missing or extra:
        raise FenceError(f"{context} fields mismatch: missing={missing} extra={extra}")


def _require_mapping(value: Any, context: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise FenceError(f"{context} must be an object")
    return value


def _require_sha256(value: Any, context: str) -> str:
    if not isinstance(value, str) or SHA256_RE.fullmatch(value) is None:
        raise FenceError(f"{context} must be a lowercase SHA-256")
    return value


def _parse_created_utc(value: Any, context: str) -> datetime:
    if not isinstance(value, str) or UTC_TIMESTAMP_RE.fullmatch(value) is None:
        raise FenceError(f"{context} must be an ISO-8601 timestamp with timezone")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise FenceError(f"{context} is not a valid timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise FenceError(f"{context} lacks a timezone")
    return parsed


def _same_path(left: Path, right: Path) -> bool:
    return os.path.normcase(str(left)) == os.path.normcase(str(right))


def _resolved_inside(path: Path, root: Path, context: str) -> Path:
    try:
        resolved = path.resolve(strict=True)
        resolved.relative_to(root.resolve(strict=True))
    except (OSError, ValueError) as exc:
        raise FenceError(f"{context} escapes or is missing from required root {root}") from exc
    if path.is_symlink() or not resolved.is_file():
        raise FenceError(f"{context} must be a regular non-symlink file")
    return resolved


def _read_exact_detached(
    artifact: Path,
    sidecar: Path,
    *,
    artifact_raw: bytes,
    context: str,
) -> bytes:
    if sidecar.is_symlink() or not sidecar.is_file():
        raise FenceError(f"{context} detached sidecar is missing or a symlink")
    try:
        raw = sidecar.read_bytes()
    except OSError as exc:
        raise FenceError(f"cannot read {context} detached sidecar") from exc
    digest = hashlib.sha256(artifact_raw).hexdigest()
    expected = f"{digest}  {artifact.name}\n".encode("ascii")
    if raw != expected:
        raise FenceError(f"{context} detached hash mismatch/format error")
    return raw


def _verify_bound_artifact(
    raw_binding: Any,
    *,
    expected_path: Path,
    allowed_root: Path,
    context: str,
) -> tuple[dict[str, Any], bytes]:
    binding = _require_mapping(raw_binding, context)
    _require_exact_keys(binding, BOUND_ARTIFACT_FIELDS, context)
    path_value = binding["path"]
    sidecar_value = binding["sidecar_path"]
    size_value = binding["size_bytes"]
    if not isinstance(path_value, str) or not Path(path_value).is_absolute():
        raise FenceError(f"{context}.path must be absolute")
    if not isinstance(sidecar_value, str) or not Path(sidecar_value).is_absolute():
        raise FenceError(f"{context}.sidecar_path must be absolute")
    if ".." in Path(path_value).parts or ".." in Path(sidecar_value).parts:
        raise FenceError(f"{context} contains path traversal")
    if isinstance(size_value, bool) or not isinstance(size_value, int) or size_value <= 0:
        raise FenceError(f"{context}.size_bytes must be a positive integer")
    expected_sha = _require_sha256(binding["sha256"], f"{context}.sha256")
    expected_sidecar_sha = _require_sha256(
        binding["sidecar_file_sha256"], f"{context}.sidecar_file_sha256"
    )

    artifact_path = Path(path_value)
    sidecar_path = Path(sidecar_value)
    resolved_artifact = _resolved_inside(artifact_path, allowed_root, context)
    resolved_sidecar = _resolved_inside(sidecar_path, allowed_root, f"{context}.sidecar")
    expected_resolved = expected_path.resolve(strict=False)
    expected_sidecar = Path(f"{expected_path}.sha256").resolve(strict=False)
    if not _same_path(resolved_artifact, expected_resolved):
        raise FenceError(f"{context} path does not match the phase artifact contract")
    if not _same_path(resolved_sidecar, expected_sidecar):
        raise FenceError(f"{context} sidecar path does not match the phase artifact contract")

    try:
        artifact_raw = resolved_artifact.read_bytes()
    except OSError as exc:
        raise FenceError(f"cannot read {context}") from exc
    if len(artifact_raw) != size_value or hashlib.sha256(artifact_raw).hexdigest() != expected_sha:
        raise FenceError(f"{context} binding drift: size/hash mismatch")
    sidecar_raw = _read_exact_detached(
        resolved_artifact,
        resolved_sidecar,
        artifact_raw=artifact_raw,
        context=context,
    )
    if hashlib.sha256(sidecar_raw).hexdigest() != expected_sidecar_sha:
        raise FenceError(f"{context} sidecar file hash drift")
    return _strict_canonical_json(artifact_raw, context), artifact_raw


def _verify_file_binding(
    raw_binding: Any,
    *,
    expected_path: Path,
    context: str,
) -> None:
    binding = _require_mapping(raw_binding, context)
    _require_exact_keys(binding, FILE_BINDING_FIELDS, context)
    path_value = binding["path"]
    size_value = binding["size_bytes"]
    if not isinstance(path_value, str) or not Path(path_value).is_absolute():
        raise FenceError(f"{context}.path must be absolute")
    if ".." in Path(path_value).parts:
        raise FenceError(f"{context} contains path traversal")
    if isinstance(size_value, bool) or not isinstance(size_value, int) or size_value <= 0:
        raise FenceError(f"{context}.size_bytes must be a positive integer")
    expected_sha = _require_sha256(binding["sha256"], f"{context}.sha256")
    path = Path(path_value)
    if path.is_symlink():
        raise FenceError(f"{context} must not be a symlink")
    try:
        resolved = path.resolve(strict=True)
        expected_resolved = expected_path.resolve(strict=True)
        raw = resolved.read_bytes()
    except OSError as exc:
        raise FenceError(f"{context} target is missing") from exc
    if not _same_path(resolved, expected_resolved):
        raise FenceError(f"{context} path does not match the frozen adjudicator")
    if len(raw) != size_value or hashlib.sha256(raw).hexdigest() != expected_sha:
        raise FenceError(f"{context} binding drift: size/hash mismatch")


def _validate_freeze_identity(
    raw_identity: Any,
    *,
    freeze_inputs_sha256: str,
    manifest_sha256: str,
    context: str,
) -> None:
    identity = _require_mapping(raw_identity, context)
    _require_exact_keys(identity, FREEZE_IDENTITY_FIELDS, context)
    if (
        identity.get("freeze_inputs_sha256") != freeze_inputs_sha256
        or identity.get("manifest_sha256") != manifest_sha256
    ):
        raise FenceError(f"{context} differs from the active freeze/manifest")


def _validate_dev_inventory(
    inventory: Mapping[str, Any],
    *,
    schema: Mapping[str, Any],
    protocol_id: str,
    created_utc: str,
    freeze_inputs_sha256: str,
    manifest_sha256: str,
) -> None:
    _require_exact_keys(inventory, INVENTORY_FIELDS, "DEV inventory")
    if (
        inventory.get("schema_version") != 1
        or inventory.get("artifact_type") != schema["inventory_artifact_type"]
        or inventory.get("status") != schema["inventory_status"]
        or inventory.get("protocol_id") != protocol_id
        or inventory.get("phase_id") != "DEV"
        or inventory.get("created_utc") != created_utc
    ):
        raise FenceError("DEV inventory identity/status mismatch")
    _parse_created_utc(inventory["created_utc"], "DEV inventory.created_utc")
    _validate_freeze_identity(
        inventory["freeze_identity"],
        freeze_inputs_sha256=freeze_inputs_sha256,
        manifest_sha256=manifest_sha256,
        context="DEV inventory.freeze_identity",
    )
    matrix = _require_mapping(inventory["matrix_contract"], "DEV inventory.matrix_contract")
    expected_matrix = {
        "markets": DEV_MARKETS,
        "variants": DEV_VARIANTS,
        "expected_cells": 52,
        "observed_cells": 52,
        "required_semantic_duplicate_runs_per_cell": 2,
        "duplicate_runs_counted_for_merit": 1,
    }
    if dict(matrix) != expected_matrix:
        raise FenceError("DEV inventory matrix contract mismatch")
    cells = inventory["cells"]
    if not isinstance(cells, list) or len(cells) != 52:
        raise FenceError("DEV inventory must contain exactly 52 cells")
    toolchain_hash = _require_sha256(
        inventory["common_toolchain_sha256"], "DEV inventory.common_toolchain_sha256"
    )
    if toolchain_hash != _canonical_payload_sha256(inventory["common_toolchain"]):
        raise FenceError("DEV inventory common toolchain hash mismatch")


def _validate_dev_evidence(
    evidence: Mapping[str, Any],
    *,
    schema: Mapping[str, Any],
    protocol_id: str,
    created_utc: str,
    freeze_inputs_sha256: str,
    manifest_sha256: str,
    inventory_binding: Mapping[str, Any],
) -> None:
    _require_exact_keys(evidence, EVIDENCE_FIELDS, "DEV evidence")
    if (
        evidence.get("schema_version") != 1
        or evidence.get("artifact_type") != schema["evidence_artifact_type"]
        or evidence.get("status") != schema["evidence_status"]
        or evidence.get("protocol_id") != protocol_id
        or evidence.get("phase_id") != "DEV"
        or evidence.get("created_utc") != created_utc
        or evidence.get("matrix_status") != "COMPLETE_52_OF_52"
    ):
        raise FenceError("DEV evidence identity/status mismatch")
    _parse_created_utc(evidence["created_utc"], "DEV evidence.created_utc")
    _validate_freeze_identity(
        evidence["freeze_identity"],
        freeze_inputs_sha256=freeze_inputs_sha256,
        manifest_sha256=manifest_sha256,
        context="DEV evidence.freeze_identity",
    )
    if evidence.get("inventory_binding") != inventory_binding:
        raise FenceError("DEV evidence inventory binding differs from verdict")
    gates = _require_mapping(evidence["binding_gates"], "DEV evidence.binding_gates")
    expected_gates = {
        "sleeve_a_center",
        "sleeve_b_center",
        "sleeve_a_plateau",
        "sleeve_b_plateau",
    }
    if set(gates) != expected_gates or any(
        not isinstance(row, Mapping) or row.get("status") != "PASS"
        for row in gates.values()
    ):
        raise FenceError("DEV evidence binding gates are not all PASS")
    selected = _require_mapping(
        evidence["selected_configuration"], "DEV evidence.selected_configuration"
    )
    if dict(selected) != {
        "sleeve_a": "center",
        "sleeve_b": "center",
        "neighbour_rescue_permitted": False,
    }:
        raise FenceError("DEV evidence selected configuration mismatch")
    mandatory = evidence["mandatory_reported_cells"]
    if not isinstance(mandatory, list) or len(mandatory) != 52:
        raise FenceError("DEV evidence must report exactly 52 mandatory cells")
    _verify_file_binding(
        evidence["adjudicator_binding"],
        expected_path=freeze.EA_ROOT / "tools" / "adjudicate_dev.py",
        context="DEV evidence.adjudicator_binding",
    )


def _validate_nested_prior_verdict(
    *,
    protocol: Mapping[str, Any],
    unlock: Mapping[str, Any],
    prior_phase: str,
    record: Mapping[str, Any],
    verdict_root: Path,
    freeze_inputs_sha256: str,
    manifest_sha256: str,
) -> None:
    required_fields = set(unlock["required_record_fields"])
    _require_exact_keys(record, required_fields, f"prior verdict {prior_phase}")
    schemas = _require_mapping(
        unlock.get("supported_record_schemas"), "phase unlock supported_record_schemas"
    )
    schema = _require_mapping(
        schemas.get(prior_phase), f"phase unlock schema for {prior_phase}"
    )
    created_utc = record.get("created_utc")
    _parse_created_utc(created_utc, f"prior verdict {prior_phase}.created_utc")
    if (
        record.get("schema_version") != unlock["record_schema_version"]
        or record.get("artifact_type") != schema["verdict_artifact_type"]
        or record.get("protocol_id") != protocol["protocol_id"]
        or record.get("phase_id") != prior_phase
        or record.get("status") != unlock["accepted_verdict"]
        or record.get("verdict") != unlock["accepted_verdict"]
    ):
        raise FenceError(f"prior verdict identity/status mismatch: {prior_phase}")
    _validate_freeze_identity(
        record["freeze_identity"],
        freeze_inputs_sha256=freeze_inputs_sha256,
        manifest_sha256=manifest_sha256,
        context=f"prior verdict {prior_phase}.freeze_identity",
    )
    publication = _require_mapping(
        record["publication_contract"], f"prior verdict {prior_phase}.publication_contract"
    )
    required_publication = _require_mapping(
        unlock.get("required_publication_contract"),
        "phase unlock required_publication_contract",
    )
    if dict(publication) != dict(required_publication):
        raise FenceError(f"prior verdict publication contract mismatch: {prior_phase}")

    output_root = verdict_root.parent
    evidence_root = output_root / "evidence"
    inventory_path = evidence_root / str(schema["inventory_name"])
    evidence_path = evidence_root / str(schema["evidence_name"])
    inventory, _inventory_raw = _verify_bound_artifact(
        record["inventory_binding"],
        expected_path=inventory_path,
        allowed_root=output_root,
        context=f"prior verdict {prior_phase}.inventory_binding",
    )
    evidence, _evidence_raw = _verify_bound_artifact(
        record["evidence_binding"],
        expected_path=evidence_path,
        allowed_root=output_root,
        context=f"prior verdict {prior_phase}.evidence_binding",
    )
    if prior_phase != "DEV":
        raise FenceError(f"unsupported nested prior verdict phase: {prior_phase}")
    _validate_dev_inventory(
        inventory,
        schema=schema,
        protocol_id=str(protocol["protocol_id"]),
        created_utc=str(created_utc),
        freeze_inputs_sha256=freeze_inputs_sha256,
        manifest_sha256=manifest_sha256,
    )
    _validate_dev_evidence(
        evidence,
        schema=schema,
        protocol_id=str(protocol["protocol_id"]),
        created_utc=str(created_utc),
        freeze_inputs_sha256=freeze_inputs_sha256,
        manifest_sha256=manifest_sha256,
        inventory_binding=_require_mapping(
            record["inventory_binding"], f"prior verdict {prior_phase}.inventory_binding"
        ),
    )


def _same_path(first: Path, second: Path) -> bool:
    return os.path.normcase(os.path.abspath(first)) == os.path.normcase(
        os.path.abspath(second)
    )


def _canonical_repo_relative(value: Any, context: str) -> str:
    if not isinstance(value, str) or not value or "\\" in value:
        raise FenceError(f"{context} must be a non-empty canonical POSIX path")
    pure = PurePosixPath(value)
    if (
        pure.is_absolute()
        or pure.as_posix() != value
        or any(part in {"", ".", ".."} for part in pure.parts)
        or ":" in pure.parts[0]
    ):
        raise FenceError(f"{context} is absolute, noncanonical or escapes its root")
    return value


def _inside_path(root: Path, relative: str, context: str) -> Path:
    canonical = _canonical_repo_relative(relative, context)
    root_full = Path(os.path.abspath(root))
    candidate = Path(os.path.abspath(root_full.joinpath(*PurePosixPath(canonical).parts)))
    try:
        inside = os.path.commonpath((os.path.normcase(root_full), os.path.normcase(candidate)))
    except ValueError as exc:
        raise FenceError(f"{context} crosses filesystem roots") from exc
    if inside != os.path.normcase(root_full):
        raise FenceError(f"{context} escapes its root")
    return candidate


def _assert_no_reparse_components(path: Path, context: str) -> None:
    full = Path(os.path.abspath(path))
    if not full.is_absolute():
        raise FenceError(f"{context} must be absolute")
    anchor = Path(full.anchor)
    cursor = anchor
    components = full.parts[1:] if full.anchor else full.parts
    for component in components:
        cursor /= component
        try:
            info = os.lstat(cursor)
        except OSError as exc:
            raise FenceError(f"{context} is missing: {cursor}") from exc
        attributes = int(getattr(info, "st_file_attributes", 0))
        reparse_flag = int(getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400))
        if stat.S_ISLNK(info.st_mode) or attributes & reparse_flag:
            raise FenceError(f"{context} contains a symlink/reparse component: {cursor}")


def _regular_file_binding(path: Path, context: str) -> dict[str, Any]:
    full = Path(os.path.abspath(path))
    _assert_no_reparse_components(full, context)
    try:
        info = os.stat(full, follow_symlinks=False)
    except OSError as exc:
        raise FenceError(f"{context} is missing") from exc
    if not stat.S_ISREG(info.st_mode):
        raise FenceError(f"{context} is not a regular file")
    return {
        "path": str(full),
        "size_bytes": info.st_size,
        "sha256": freeze.sha256_file(full),
    }


def _exclusive_write(path: Path, payload: bytes, context: str) -> None:
    full = Path(os.path.abspath(path))
    if not full.parent.is_dir():
        raise FenceError(f"{context} parent is missing")
    _assert_no_reparse_components(full.parent, f"{context} parent")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    descriptor: int | None = None
    try:
        descriptor = os.open(full, flags, 0o600)
        with os.fdopen(descriptor, "wb") as handle:
            descriptor = None
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
    except FileExistsError as exc:
        raise FenceError(f"{context} already exists; overwrite is forbidden") from exc
    finally:
        if descriptor is not None:
            os.close(descriptor)


def _write_canonical_detached(path: Path, payload: Mapping[str, Any], context: str) -> None:
    full = Path(os.path.abspath(path))
    raw = _canonical_json_bytes(payload)
    digest = hashlib.sha256(raw).hexdigest()
    sidecar = Path(f"{full}.sha256")
    detached = f"{digest}  {full.name}\n".encode("ascii")
    _exclusive_write(sidecar, detached, f"{context} detached sidecar")
    _exclusive_write(full, raw, context)


def _write_receipt_atomic(path: Path, payload: Mapping[str, Any]) -> None:
    _write_canonical_detached(path, payload, "validator receipt")


def _read_canonical_detached(path: Path, context: str) -> tuple[dict[str, Any], bytes]:
    full = Path(os.path.abspath(path))
    binding = _regular_file_binding(full, context)
    del binding
    raw = full.read_bytes()
    payload = _strict_canonical_json(raw, context)
    _read_exact_detached(
        full,
        Path(f"{full}.sha256"),
        artifact_raw=raw,
        context=context,
    )
    return payload, raw


def _read_preflight_receipt(
    path: Path, expected_sha256: str
) -> tuple[dict[str, Any], bytes]:
    expected = _require_sha256(expected_sha256, "PRE receipt sha256")
    payload, raw = _read_canonical_detached(path, "PRE validator receipt")
    if hashlib.sha256(raw).hexdigest() != expected:
        raise FenceError("PRE validator receipt identity drift")
    return payload, raw


def _runtime_contract_files(
    protocol: Mapping[str, Any], selected_set_repo_relative: str
) -> list[dict[str, str]]:
    contract = _require_mapping(protocol.get("runtime_snapshot"), "runtime_snapshot")
    raw_files = contract.get("repository_files")
    if not isinstance(raw_files, list) or not raw_files:
        raise FenceError("runtime_snapshot.repository_files is missing")
    selected = _canonical_repo_relative(
        selected_set_repo_relative, "selected set repository path"
    )
    files: list[dict[str, str]] = []
    roles: set[str] = set()
    paths: set[str] = set()
    for index, raw in enumerate(raw_files):
        row = _require_mapping(raw, f"runtime_snapshot.repository_files[{index}]")
        _require_exact_keys(row, {"role", "path"}, f"runtime snapshot file {index}")
        role = row["role"]
        template = row["path"]
        if not isinstance(role, str) or re.fullmatch(r"[a-z][a-z0-9_]*", role) is None:
            raise FenceError(f"runtime snapshot role is invalid: {role!r}")
        if not isinstance(template, str):
            raise FenceError(f"runtime snapshot path is invalid for role {role}")
        relative = template.replace("{selected_set_repo_relative}", selected)
        if "{" in relative or "}" in relative:
            raise FenceError(f"runtime snapshot path has an unresolved token: {role}")
        relative = _canonical_repo_relative(relative, f"runtime snapshot path {role}")
        if role in roles or relative.casefold() in paths:
            raise FenceError("runtime snapshot roles/paths must be unique")
        roles.add(role)
        paths.add(relative.casefold())
        files.append({"role": role, "repo_relative_path": relative})
    if "selected_set" not in roles or "ea_binary" not in roles:
        raise FenceError("runtime snapshot omits selected set or EA binary")
    return files


def _runtime_expected_specs(
    protocol: Mapping[str, Any],
    manifest: Mapping[str, Any],
    *,
    set_file: Path,
    manifest_bytes: bytes,
) -> list[dict[str, Any]]:
    try:
        selected_relative = set_file.resolve(strict=True).relative_to(
            freeze.REPO_ROOT.resolve(strict=True)
        ).as_posix()
    except (OSError, ValueError) as exc:
        raise FenceError("selected set is outside the source repository") from exc
    contract_files = _runtime_contract_files(protocol, selected_relative)
    freeze_inputs = _require_mapping(manifest.get("freeze_inputs"), "freeze manifest inputs")
    source_hashes = _require_mapping(freeze_inputs.get("source_hashes"), "source hashes")
    evidence_rows = freeze_inputs.get("evidence_artifacts")
    if not isinstance(evidence_rows, list):
        raise FenceError("freeze manifest evidence_artifacts is malformed")
    evidence_by_path = {
        str(row.get("path", "")).replace("\\", "/"): row
        for row in evidence_rows
        if isinstance(row, Mapping)
    }
    source_hash_roles = {
        "protocol": "protocol_sha256",
        "generator": "generator_sha256",
        "validator": "validator_sha256",
    }
    manifest_sha = hashlib.sha256(manifest_bytes).hexdigest()
    manifest_sidecar = f"{manifest_sha}  manifest.json\n".encode("ascii")
    selected_rows = [
        row for row in manifest.get("sets", []) if row.get("file") == set_file.name
    ]
    if len(selected_rows) != 1:
        raise FenceError("selected set is not unique in the freeze manifest")
    specs: list[dict[str, Any]] = []
    for row in contract_files:
        role = row["role"]
        relative = row["repo_relative_path"]
        expected_size: int | None = None
        if role == "sets_manifest":
            expected_sha = manifest_sha
            expected_size = len(manifest_bytes)
        elif role == "sets_manifest_detached":
            expected_sha = hashlib.sha256(manifest_sidecar).hexdigest()
            expected_size = len(manifest_sidecar)
        elif role == "selected_set":
            expected_sha = str(selected_rows[0].get("set_sha256", ""))
        elif role in source_hash_roles:
            expected_sha = str(source_hashes.get(source_hash_roles[role], ""))
        else:
            evidence = evidence_by_path.get(relative)
            if not isinstance(evidence, Mapping):
                raise FenceError(f"runtime snapshot path is not freeze-bound: {relative}")
            expected_sha = str(evidence.get("sha256", ""))
            size_value = evidence.get("size")
            if isinstance(size_value, bool) or not isinstance(size_value, int):
                raise FenceError(f"runtime evidence size is invalid: {role}")
            expected_size = size_value
        expected_sha = _require_sha256(expected_sha, f"runtime expected hash {role}")
        specs.append(
            {
                **row,
                "expected_size_bytes": expected_size,
                "expected_sha256": expected_sha,
            }
        )
    return specs


def create_runtime_snapshot(
    *,
    source_repo_root: Path,
    snapshot_root: Path,
    run_id: str,
    artifact_type: str,
    freeze_identity: Mapping[str, Any],
    request: Mapping[str, Any],
    selected_set_repo_relative: str,
    file_specs: list[Mapping[str, Any]],
) -> dict[str, Any]:
    if RUN_ID_RE.fullmatch(run_id) is None:
        raise FenceError("runtime snapshot run_id is malformed")
    source_root = Path(os.path.abspath(source_repo_root))
    root = Path(os.path.abspath(snapshot_root))
    if not root.is_absolute() or not source_root.is_absolute():
        raise FenceError("runtime snapshot/source roots must be absolute")
    _assert_no_reparse_components(source_root, "source repository root")
    _assert_no_reparse_components(root.parent, "runtime snapshot parent")
    try:
        root.mkdir()
    except FileExistsError as exc:
        raise FenceError("runtime snapshot already exists; cross-run reuse is forbidden") from exc
    repo_root = root / "repo"
    repo_root.mkdir()

    manifest_rows: list[dict[str, Any]] = []
    roles: set[str] = set()
    for index, raw_spec in enumerate(file_specs):
        spec = _require_mapping(raw_spec, f"runtime file spec {index}")
        role = spec.get("role")
        if not isinstance(role, str) or re.fullmatch(r"[a-z][a-z0-9_]*", role) is None:
            raise FenceError(f"runtime file role is invalid: {role!r}")
        if role in roles:
            raise FenceError(f"duplicate runtime file role: {role}")
        roles.add(role)
        relative = _canonical_repo_relative(
            spec.get("repo_relative_path"), f"runtime file {role}"
        )
        expected_sha = _require_sha256(
            spec.get("expected_sha256"), f"runtime file {role} expected hash"
        )
        expected_size = spec.get("expected_size_bytes")
        if expected_size is not None and (
            isinstance(expected_size, bool)
            or not isinstance(expected_size, int)
            or expected_size <= 0
        ):
            raise FenceError(f"runtime file {role} expected size is invalid")
        source = _inside_path(source_root, relative, f"runtime source {role}")
        source_binding = _regular_file_binding(source, f"runtime source {role}")
        if source_binding["sha256"] != expected_sha or (
            expected_size is not None and source_binding["size_bytes"] != expected_size
        ):
            raise FenceError(f"runtime source drifted after PRE validation: {role}")
        destination = _inside_path(repo_root, relative, f"runtime destination {role}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        _assert_no_reparse_components(destination.parent, f"runtime destination parent {role}")
        digest = hashlib.sha256()
        size = 0
        try:
            with source.open("rb") as source_handle, destination.open("xb") as destination_handle:
                while True:
                    chunk = source_handle.read(1024 * 1024)
                    if not chunk:
                        break
                    destination_handle.write(chunk)
                    digest.update(chunk)
                    size += len(chunk)
                destination_handle.flush()
                os.fsync(destination_handle.fileno())
        except FileExistsError as exc:
            raise FenceError(f"runtime destination collision: {role}") from exc
        if digest.hexdigest() != expected_sha or size != source_binding["size_bytes"]:
            raise FenceError(f"runtime snapshot copy drifted: {role}")
        copied = _regular_file_binding(destination, f"runtime snapshot file {role}")
        if copied["sha256"] != expected_sha or copied["size_bytes"] != size:
            raise FenceError(f"runtime snapshot verification failed after copy: {role}")
        manifest_rows.append(
            {
                "role": role,
                "repo_relative_path": relative,
                "source_path": str(source),
                "snapshot_path": str(destination),
                "size_bytes": size,
                "sha256": expected_sha,
            }
        )

    manifest_rows.sort(key=lambda item: str(item["role"]))
    manifest_payload = {
        "schema_version": 1,
        "artifact_type": artifact_type,
        "status": "SEALED",
        "run_id": run_id,
        "source_repo_root": str(source_root),
        "snapshot_root": str(root),
        "snapshot_repo_root": str(repo_root),
        "freeze_identity": dict(freeze_identity),
        "request": dict(request),
        "files": manifest_rows,
        "closure_sha256": _canonical_payload_sha256(manifest_rows),
    }
    manifest_path = root / "runtime_manifest.json"
    _write_canonical_detached(manifest_path, manifest_payload, "runtime snapshot manifest")
    manifest_binding = _regular_file_binding(manifest_path, "runtime snapshot manifest")
    sidecar_path = Path(f"{manifest_path}.sha256")
    sidecar_binding = _regular_file_binding(sidecar_path, "runtime snapshot manifest sidecar")
    role_bindings = {
        str(row["role"]): {
            "path": str(row["snapshot_path"]),
            "size_bytes": int(row["size_bytes"]),
            "sha256": str(row["sha256"]),
        }
        for row in manifest_rows
    }
    return {
        "root_path": str(root),
        "repo_root": str(repo_root),
        "manifest_path": str(manifest_path),
        "manifest_size_bytes": int(manifest_binding["size_bytes"]),
        "manifest_sha256": str(manifest_binding["sha256"]),
        "manifest_sidecar_path": str(sidecar_path),
        "manifest_sidecar_sha256": str(sidecar_binding["sha256"]),
        "selected_set_repo_relative": _canonical_repo_relative(
            selected_set_repo_relative, "selected set repository path"
        ),
        "role_bindings": role_bindings,
    }


def verify_runtime_snapshot(
    binding_raw: Any,
    *,
    expected_snapshot_root: Path,
    run_id: str,
    artifact_type: str,
    freeze_identity: Mapping[str, Any],
    request: Mapping[str, Any],
    expected_files: list[Mapping[str, str]],
) -> dict[str, Any]:
    binding = _require_mapping(binding_raw, "runtime snapshot binding")
    _require_exact_keys(binding, SNAPSHOT_BINDING_FIELDS, "runtime snapshot binding")
    root = Path(str(binding["root_path"]))
    repo_root = Path(str(binding["repo_root"]))
    manifest_path = Path(str(binding["manifest_path"]))
    sidecar_path = Path(str(binding["manifest_sidecar_path"]))
    expected_root = Path(os.path.abspath(expected_snapshot_root))
    if not all(path.is_absolute() for path in (root, repo_root, manifest_path, sidecar_path)):
        raise FenceError("runtime snapshot binding paths must be absolute")
    if not _same_path(root, expected_root):
        raise FenceError("cross-run runtime snapshot root")
    if not _same_path(repo_root, root / "repo"):
        raise FenceError("runtime snapshot repository root drift")
    if not _same_path(manifest_path, root / "runtime_manifest.json"):
        raise FenceError("runtime snapshot manifest path drift")
    if not _same_path(sidecar_path, Path(f"{manifest_path}.sha256")):
        raise FenceError("runtime snapshot manifest sidecar path drift")
    _assert_no_reparse_components(root, "runtime snapshot root")
    manifest, manifest_raw = _read_canonical_detached(
        manifest_path, "runtime snapshot manifest"
    )
    _require_exact_keys(manifest, SNAPSHOT_MANIFEST_FIELDS, "runtime snapshot manifest")
    manifest_sha = hashlib.sha256(manifest_raw).hexdigest()
    sidecar_sha = freeze.sha256_file(sidecar_path)
    for field, actual, expected in (
        ("manifest_size_bytes", len(manifest_raw), binding["manifest_size_bytes"]),
        ("manifest_sha256", manifest_sha, binding["manifest_sha256"]),
        ("manifest_sidecar_sha256", sidecar_sha, binding["manifest_sidecar_sha256"]),
    ):
        if actual != expected:
            raise FenceError(f"runtime snapshot {field} binding drift")
    if (
        manifest["schema_version"] != 1
        or manifest["artifact_type"] != artifact_type
        or manifest["status"] != "SEALED"
        or manifest["run_id"] != run_id
        or manifest["freeze_identity"] != dict(freeze_identity)
        or manifest["request"] != dict(request)
    ):
        raise FenceError("runtime snapshot identity/status contract drift")
    if not _same_path(Path(str(manifest["snapshot_root"])), root) or not _same_path(
        Path(str(manifest["snapshot_repo_root"])), repo_root
    ):
        raise FenceError("runtime snapshot manifest root drift")
    source_root = Path(str(manifest["source_repo_root"]))
    if not source_root.is_absolute():
        raise FenceError("runtime snapshot source repository root is not absolute")

    rows_raw = manifest["files"]
    if not isinstance(rows_raw, list):
        raise FenceError("runtime snapshot files must be a list")
    expected_by_role = {
        str(row["role"]): _canonical_repo_relative(
            row["repo_relative_path"], f"expected runtime file {row['role']}"
        )
        for row in expected_files
    }
    if len(expected_by_role) != len(expected_files):
        raise FenceError("expected runtime file roles are duplicated")
    observed_bindings: dict[str, dict[str, Any]] = {}
    normalized_rows: list[dict[str, Any]] = []
    for index, raw in enumerate(rows_raw):
        row = _require_mapping(raw, f"runtime snapshot file {index}")
        _require_exact_keys(row, SNAPSHOT_FILE_FIELDS, f"runtime snapshot file {index}")
        role = row["role"]
        if not isinstance(role, str) or role not in expected_by_role or role in observed_bindings:
            raise FenceError(f"unexpected/duplicate runtime snapshot role: {role!r}")
        relative = _canonical_repo_relative(
            row["repo_relative_path"], f"runtime snapshot file {role}"
        )
        if relative != expected_by_role[role]:
            raise FenceError(f"runtime snapshot relative path drift: {role}")
        expected_source = _inside_path(source_root, relative, f"runtime source path {role}")
        expected_snapshot = _inside_path(repo_root, relative, f"runtime snapshot path {role}")
        if not _same_path(Path(str(row["source_path"])), expected_source):
            raise FenceError(f"runtime snapshot source path drift: {role}")
        if not _same_path(Path(str(row["snapshot_path"])), expected_snapshot):
            raise FenceError(f"runtime snapshot path drift: {role}")
        size_value = row["size_bytes"]
        if isinstance(size_value, bool) or not isinstance(size_value, int) or size_value <= 0:
            raise FenceError(f"runtime snapshot size is invalid: {role}")
        expected_sha = _require_sha256(row["sha256"], f"runtime snapshot hash {role}")
        actual = _regular_file_binding(expected_snapshot, f"runtime snapshot file {role}")
        if actual["size_bytes"] != size_value or actual["sha256"] != expected_sha:
            raise FenceError(f"runtime snapshot file mutation: {role}")
        observed_bindings[role] = {
            "path": str(expected_snapshot),
            "size_bytes": size_value,
            "sha256": expected_sha,
        }
        normalized_rows.append(dict(row))
    if set(observed_bindings) != set(expected_by_role):
        raise FenceError("runtime snapshot file closure is incomplete")
    normalized_rows.sort(key=lambda item: str(item["role"]))
    if rows_raw != normalized_rows or manifest["closure_sha256"] != _canonical_payload_sha256(
        normalized_rows
    ):
        raise FenceError("runtime snapshot file order/closure hash drift")
    role_bindings = _require_mapping(binding["role_bindings"], "runtime role bindings")
    if set(role_bindings) != set(observed_bindings):
        raise FenceError("runtime snapshot role binding closure drift")
    for role, expected_binding in observed_bindings.items():
        raw_role = _require_mapping(role_bindings[role], f"runtime role binding {role}")
        _require_exact_keys(
            raw_role, SNAPSHOT_ROLE_BINDING_FIELDS, f"runtime role binding {role}"
        )
        if dict(raw_role) != expected_binding:
            raise FenceError(f"runtime snapshot role binding drift: {role}")
    selected_relative = _canonical_repo_relative(
        binding["selected_set_repo_relative"], "selected set repository path"
    )
    if expected_by_role.get("selected_set") != selected_relative:
        raise FenceError("runtime snapshot selected set binding drift")
    return manifest


def _external_runtime_rows(
    protocol: Mapping[str, Any],
    manifest: Mapping[str, Any],
    *,
    powershell_path: Path,
) -> list[dict[str, Any]]:
    contract = _require_mapping(protocol.get("runtime_snapshot"), "runtime_snapshot")
    artifact_ids = contract.get("external_runtime_artifact_ids")
    if not isinstance(artifact_ids, list) or not artifact_ids:
        raise FenceError("external runtime artifact closure is missing")
    evidence_rows = _require_mapping(manifest.get("freeze_inputs"), "freeze inputs").get(
        "evidence_artifacts"
    )
    if not isinstance(evidence_rows, list):
        raise FenceError("freeze evidence artifact closure is malformed")
    evidence_by_id = {
        str(row.get("id")): row for row in evidence_rows if isinstance(row, Mapping)
    }
    rows: list[dict[str, Any]] = []
    for artifact_id in artifact_ids:
        if not isinstance(artifact_id, str) or artifact_id not in evidence_by_id:
            raise FenceError(f"external runtime artifact is not freeze-bound: {artifact_id}")
        expected = evidence_by_id[artifact_id]
        path = freeze._artifact_path(str(expected.get("path", "")))
        actual = _regular_file_binding(path, f"external runtime {artifact_id}")
        if actual["size_bytes"] != expected.get("size") or actual["sha256"] != expected.get(
            "sha256"
        ):
            raise FenceError(f"external runtime drift: {artifact_id}")
        rows.append({"role": artifact_id, **actual})
    for role, path in (
        ("python_executable", Path(sys.executable)),
        ("powershell7", powershell_path),
    ):
        actual = _regular_file_binding(path, f"external runtime {role}")
        rows.append({"role": role, **actual})
    rows.sort(key=lambda item: str(item["role"]))
    if len({str(row["role"]) for row in rows}) != len(rows):
        raise FenceError("external runtime roles are duplicated")
    return rows


def _verify_external_runtime(
    raw_rows: Any,
    protocol: Mapping[str, Any],
    manifest: Mapping[str, Any],
    *,
    powershell_path: Path,
) -> list[dict[str, Any]]:
    if not isinstance(raw_rows, list):
        raise FenceError("PRE-bound external runtime must be a list")
    for index, raw in enumerate(raw_rows):
        row = _require_mapping(raw, f"external runtime row {index}")
        _require_exact_keys(row, EXTERNAL_RUNTIME_FIELDS, f"external runtime row {index}")
    actual = _external_runtime_rows(
        protocol, manifest, powershell_path=powershell_path
    )
    if raw_rows != actual:
        raise FenceError("PRE-bound external runtime identity drift")
    return actual


def _market(protocol: Mapping[str, Any], symbol: str) -> Mapping[str, Any]:
    matches = [row for row in protocol["markets"] if row["symbol"] == symbol]
    if len(matches) != 1:
        raise FenceError(f"symbol is not uniquely registered: {symbol}")
    return matches[0]


def _phase(protocol: Mapping[str, Any], phase_id: str) -> Mapping[str, Any]:
    matches = [row for row in protocol["phases"] if row["id"] == phase_id]
    if len(matches) != 1:
        raise FenceError(f"unknown or duplicate phase: {phase_id}")
    return matches[0]


def phase_window(
    protocol: Mapping[str, Any], phase_id: str, symbol: str
) -> tuple[str, str]:
    phase = _phase(protocol, phase_id)
    if phase.get("window") == "PER_MARKET_DEV":
        market = _market(protocol, symbol)
        return str(market["dev_from"]), str(market["dev_to"])
    return str(phase["from"]), str(phase["to"])


def validate_request(
    protocol: Mapping[str, Any],
    *,
    phase_id: str,
    symbol: str,
    timeframe: str,
    variant: str,
    from_date: str,
    to_date: str,
) -> None:
    market = _market(protocol, symbol)
    phase = _phase(protocol, phase_id)
    if "allowed_symbols" in phase and symbol not in phase["allowed_symbols"]:
        raise FenceError(f"symbol {symbol} is not allowed in phase {phase_id}")
    if timeframe != market["timeframe"]:
        raise FenceError(f"timeframe mismatch: {timeframe} != {market['timeframe']}")
    expected_from, expected_to = phase_window(protocol, phase_id, symbol)
    if (from_date, to_date) != (expected_from, expected_to):
        raise FenceError(
            f"partition mismatch: {from_date}..{to_date} != {expected_from}..{expected_to}"
        )
    try:
        start = date.fromisoformat(from_date)
        end = date.fromisoformat(to_date)
    except ValueError as exc:
        raise FenceError("run dates must be ISO YYYY-MM-DD") from exc
    if start > end:
        raise FenceError("run start is after run end")
    if str(phase.get("data_availability", "")).startswith("BLOCKED_"):
        raise FenceError(f"PHASE_DATA_UNAVAILABLE: {phase['data_availability']}")
    if phase.get("execution_kind") == "FORWARD_ONLY_NOT_RETROSPECTIVE_BACKTEST":
        raise FenceError("FORWARD_ONLY_PHASE_NOT_VALID_FOR_TESTER_RUN")
    known_variants = {name for name, _parameter, _value in freeze.variants(market["kind"])}
    if variant not in known_variants:
        raise FenceError(f"variant not in preregistered star: {variant}")
    if start >= date(2023, 1, 1) and variant != "center":
        raise FenceError("OAAT_NEIGHBOUR_FORBIDDEN_AT_OR_AFTER_2023")
    if phase["allowed_variants"] == "CENTER_ONLY" and variant != "center":
        raise FenceError(f"phase {phase_id} is center-only")
    if phase["allowed_variants"] == "ALL_13" and phase_id != "DEV":
        raise FenceError("only DEV may allow the OAAT star")
    if phase.get("requires_resolved_cost_axes"):
        unresolved = [
            axis
            for axis in protocol["qualification_blocking_cost_axes"]
            if protocol["costs"][axis]["status"] != "RESOLVED"
        ]
        if unresolved:
            raise FenceError(f"phase blocked by unresolved cost axes: {','.join(unresolved)}")


def validate_phase_unlock(
    protocol: Mapping[str, Any],
    *,
    phase_id: str,
    freeze_inputs_sha256: str,
    manifest_sha256: str,
    verdict_root: Path | None = None,
) -> list[dict[str, str]]:
    """Verify every prior binding verdict required to unlock ``phase_id``.

    Verdicts are intentionally outside the immutable freeze because they are
    produced later.  Each one is nevertheless identity-bound to this protocol,
    freeze root and manifest, and protected by a detached SHA-256 file.  Missing,
    malformed, non-binding or cross-freeze records fail closed.
    """

    unlock = protocol.get("phase_unlock")
    if not isinstance(unlock, Mapping) or unlock.get("enforcement") != (
        "FAIL_CLOSED_DETACHED_VERDICT_RECORDS"
    ):
        raise FenceError("phase unlock enforcement is absent or disabled")
    prerequisites = unlock.get("required_prior_verdicts")
    if not isinstance(prerequisites, Mapping) or phase_id not in prerequisites:
        raise FenceError(f"phase unlock mapping missing for {phase_id}")
    prior_phases = prerequisites[phase_id]
    if not isinstance(prior_phases, list):
        raise FenceError(f"phase unlock prerequisites are invalid for {phase_id}")
    root = (verdict_root or freeze._artifact_path(str(unlock["verdict_root"]))).resolve(
        strict=False
    )
    template = str(unlock["record_name_template"])
    suffix = str(unlock["detached_sha256_suffix"])
    verified: list[dict[str, str]] = []
    for prior_phase in prior_phases:
        if not isinstance(prior_phase, str) or re.fullmatch(r"[A-Z0-9_]+", prior_phase) is None:
            raise FenceError(f"invalid prior phase identifier: {prior_phase!r}")
        if prior_phase in set(unlock.get("nonbinding_phases", [])):
            raise FenceError(f"non-binding phase cannot unlock research: {prior_phase}")
        relative_name = template.format(phase_id=prior_phase)
        if Path(relative_name).name != relative_name:
            raise FenceError(f"prior verdict template escapes verdict root: {prior_phase}")
        record_path = root / relative_name
        detached_path = root / f"{relative_name}{suffix}"
        try:
            resolved_record = _resolved_inside(record_path, root, f"prior verdict {prior_phase}")
            resolved_detached = _resolved_inside(
                detached_path, root, f"prior verdict {prior_phase}.sidecar"
            )
        except FenceError as exc:
            raise FenceError(f"required prior verdict is missing: {prior_phase}")
        try:
            raw = resolved_record.read_bytes()
        except OSError as exc:
            raise FenceError(f"cannot read prior verdict: {prior_phase}") from exc
        actual_record_sha = hashlib.sha256(raw).hexdigest()
        _read_exact_detached(
            resolved_record,
            resolved_detached,
            artifact_raw=raw,
            context=f"prior verdict {prior_phase}",
        )
        record = _strict_canonical_json(raw, f"prior verdict {prior_phase}")
        _validate_nested_prior_verdict(
            protocol=protocol,
            unlock=unlock,
            prior_phase=prior_phase,
            record=record,
            verdict_root=root,
            freeze_inputs_sha256=freeze_inputs_sha256,
            manifest_sha256=manifest_sha256,
        )
        verified.append({"phase_id": prior_phase, "record_sha256": actual_record_sha})
    return verified


def parse_set_metadata(path: Path) -> dict[str, str]:
    metadata: dict[str, str] = {}
    input_names: set[str] = set()
    for raw in path.read_text(encoding="ascii").splitlines():
        if raw.startswith("; ") and ": " in raw:
            key, value = raw[2:].split(": ", 1)
            metadata[key] = value
        elif raw and not raw.startswith(";") and "=" in raw:
            key = raw.split("=", 1)[0]
            if key in input_names:
                raise FenceError(f"duplicate input assignment in set: {key}")
            input_names.add(key)
    if input_names != set(freeze.visible_input_names()):
        raise FenceError("set does not contain the exact visible input closure")
    required = {"symbol", "timeframe", "variant", "freeze_inputs_sha256", "protocol_id"}
    if not required.issubset(metadata):
        raise FenceError(f"set header missing: {sorted(required - set(metadata))}")
    return metadata


def _selected_data_rows(
    protocol: Mapping[str, Any],
    manifest: Mapping[str, Any],
    symbol: str,
    from_date: str,
    to_date: str,
) -> list[Mapping[str, Any]]:
    start = date.fromisoformat(from_date)
    end = date.fromisoformat(to_date)
    required = {str(protocol["model4_data"]["symbol_definition_relative_path"])}
    for month in freeze._month_range(from_date, end.strftime("%Y%m")):
        required.add(f"Custom/ticks/{symbol}/{month}.tkc")
    for year in range(start.year, end.year + 1):
        required.add(f"Custom/history/{symbol}/{year}.hcc")
    rows = {
        str(row["relative_path"]): row
        for row in manifest["freeze_inputs"]["model4_data_files"]
    }
    missing = sorted(required - set(rows))
    if missing:
        raise FenceError(f"freeze manifest lacks selected data files: {','.join(missing[:8])}")
    return [rows[name] for name in sorted(required)]


def rehash_selected_data(
    protocol: Mapping[str, Any], rows: list[Mapping[str, Any]]
) -> list[dict[str, Any]]:
    root = Path(
        os.path.abspath(
            freeze._artifact_path(str(protocol["model4_data"]["destination_root"]))
        )
    )
    _assert_no_reparse_components(root, "selected Model-4 data root")
    actual_rows: list[dict[str, Any]] = []
    for expected in rows:
        if set(expected) != {"relative_path", "size", "sha256"}:
            raise FenceError("selected Model-4 row schema drift")
        relative = _canonical_repo_relative(
            expected["relative_path"], "selected Model-4 relative path"
        )
        size = expected["size"]
        if isinstance(size, bool) or not isinstance(size, int) or size <= 0:
            raise FenceError("selected Model-4 size is invalid")
        expected_sha = _require_sha256(
            expected["sha256"], "selected Model-4 sha256"
        )
        path = _inside_path(root, relative, "selected Model-4 path")
        actual = _regular_file_binding(path, "selected Model-4 file")
        if actual["size_bytes"] != size:
            raise FenceError(f"selected Model-4 file missing/size drift: {path}")
        if actual["sha256"] != expected_sha:
            raise FenceError(f"selected Model-4 file hash drift: {path}")
        actual_rows.append(
            {"relative_path": relative, "size": size, "sha256": expected_sha}
        )
    return actual_rows


def preflight(
    *,
    phase_id: str,
    symbol: str,
    timeframe: str,
    set_file: Path,
    from_date: str,
    to_date: str,
    run_id: str | None = None,
    snapshot_root: Path | None = None,
    powershell_path: Path | None = None,
) -> dict[str, Any]:
    try:
        issues = freeze.check()
    except freeze.FreezeError as exc:
        raise FenceError(str(exc)) from exc
    if issues:
        raise FenceError(f"freeze bundle drift: {issues[0]}")
    set_file = set_file.resolve(strict=True)
    _assert_no_reparse_components(set_file, "selected frozen set")
    if set_file.parent != freeze.SETS_ROOT.resolve(strict=True):
        raise FenceError("set file must come from the frozen sets directory")
    metadata = parse_set_metadata(set_file)
    protocol = freeze.load_protocol()
    if metadata["symbol"] != symbol or metadata["timeframe"] != timeframe:
        raise FenceError("CLI symbol/timeframe does not match frozen set header")
    manifest_path = freeze.SETS_ROOT / "manifest.json"
    manifest_bytes = manifest_path.read_bytes()
    manifest = _strict_canonical_json(manifest_bytes, "freeze sets manifest")
    manifest_sha256 = hashlib.sha256(manifest_bytes).hexdigest()
    validate_request(
        protocol,
        phase_id=phase_id,
        symbol=symbol,
        timeframe=timeframe,
        variant=metadata["variant"],
        from_date=from_date,
        to_date=to_date,
    )
    if metadata["freeze_inputs_sha256"] != manifest["freeze_inputs_sha256"]:
        raise FenceError("set freeze root differs from manifest")
    unlock_records = validate_phase_unlock(
        protocol,
        phase_id=phase_id,
        freeze_inputs_sha256=str(manifest["freeze_inputs_sha256"]),
        manifest_sha256=manifest_sha256,
    )
    set_digest = freeze.sha256_file(set_file)
    matching = [row for row in manifest["sets"] if row["file"] == set_file.name]
    if len(matching) != 1 or matching[0]["set_sha256"] != set_digest:
        raise FenceError("selected set is not uniquely hash-bound in manifest")
    selected = _selected_data_rows(protocol, manifest, symbol, from_date, to_date)
    actual_data = rehash_selected_data(protocol, selected)
    request = {
        "phase": phase_id,
        "symbol": symbol,
        "timeframe": timeframe,
        "variant": metadata["variant"],
        "from": from_date,
        "to": to_date,
    }
    result: dict[str, Any] = {
        "schema_version": 1,
        "request": request,
        "freeze_inputs_sha256": manifest["freeze_inputs_sha256"],
        "manifest_sha256": manifest_sha256,
        "set_sha256": set_digest,
        "selected_data": actual_data,
        "selected_data_sha256": freeze.sha256_bytes(freeze.canonical_json_bytes(actual_data)),
        "phase_unlock_records": unlock_records,
    }
    snapshot_arguments = (run_id, snapshot_root, powershell_path)
    if any(item is not None for item in snapshot_arguments):
        if any(item is None for item in snapshot_arguments):
            raise FenceError("run_id, snapshot_root and powershell_path are an atomic PRE contract")
        assert run_id is not None and snapshot_root is not None and powershell_path is not None
        freeze_identity = {
            "freeze_inputs_sha256": str(manifest["freeze_inputs_sha256"]),
            "manifest_sha256": manifest_sha256,
        }
        external_runtime = _external_runtime_rows(
            protocol, manifest, powershell_path=powershell_path
        )
        selected_relative = set_file.relative_to(
            freeze.REPO_ROOT.resolve(strict=True)
        ).as_posix()
        specs = _runtime_expected_specs(
            protocol, manifest, set_file=set_file, manifest_bytes=manifest_bytes
        )
        snapshot_contract = _require_mapping(
            protocol.get("runtime_snapshot"), "runtime_snapshot"
        )
        snapshot_binding = create_runtime_snapshot(
            source_repo_root=freeze.REPO_ROOT,
            snapshot_root=snapshot_root,
            run_id=run_id,
            artifact_type=str(snapshot_contract["artifact_type"]),
            freeze_identity=freeze_identity,
            request=request,
            selected_set_repo_relative=selected_relative,
            file_specs=specs,
        )
        result.update(
            {
                "artifact_type": "QM5_20009_RESEARCH_VALIDATOR_PRE_RECEIPT",
                "status": "PASS",
                "run_id": run_id,
                "external_runtime": external_runtime,
                "runtime_snapshot": snapshot_binding,
            }
        )
    return result


def postflight(
    *,
    phase_id: str,
    symbol: str,
    timeframe: str,
    set_file: Path,
    from_date: str,
    to_date: str,
    run_id: str,
    preflight_receipt: Path,
    preflight_receipt_sha256: str,
    powershell_path: Path,
) -> dict[str, Any]:
    expected_pre_sha = _require_sha256(preflight_receipt_sha256, "PRE receipt sha256")
    pre_path = Path(os.path.abspath(preflight_receipt))
    if pre_path.parent.name != run_id:
        raise FenceError("PRE receipt directory is not bound to run_id")
    pre, pre_raw = _read_preflight_receipt(pre_path, expected_pre_sha)
    del pre_raw
    _require_exact_keys(pre, PRE_RECEIPT_FIELDS, "PRE validator receipt")
    if (
        pre["schema_version"] != 1
        or pre["artifact_type"] != "QM5_20009_RESEARCH_VALIDATOR_PRE_RECEIPT"
        or pre["status"] != "PASS"
        or pre["run_id"] != run_id
    ):
        raise FenceError("PRE validator receipt status/run identity drift")
    request = {
        "phase": phase_id,
        "symbol": symbol,
        "timeframe": timeframe,
        "variant": pre["request"].get("variant")
        if isinstance(pre.get("request"), Mapping)
        else None,
        "from": from_date,
        "to": to_date,
    }
    if pre["request"] != request:
        raise FenceError("POST request differs from PRE-bound request")
    binding = _require_mapping(pre["runtime_snapshot"], "runtime snapshot binding")
    expected_snapshot_root = pre_path.parent / "runtime_snapshot"
    snapshot_repo = Path(str(binding.get("repo_root", "")))
    if not _same_path(snapshot_repo, freeze.REPO_ROOT):
        raise FenceError("POST validator was not invoked from the PRE-bound snapshot")
    selected_relative = _canonical_repo_relative(
        binding.get("selected_set_repo_relative"), "selected set repository path"
    )
    protocol = freeze.load_protocol()
    snapshot_contract = _require_mapping(
        protocol.get("runtime_snapshot"), "runtime_snapshot"
    )
    expected_files = _runtime_contract_files(protocol, selected_relative)
    freeze_identity = {
        "freeze_inputs_sha256": pre["freeze_inputs_sha256"],
        "manifest_sha256": pre["manifest_sha256"],
    }
    snapshot_manifest = verify_runtime_snapshot(
        binding,
        expected_snapshot_root=expected_snapshot_root,
        run_id=run_id,
        artifact_type=str(snapshot_contract["artifact_type"]),
        freeze_identity=freeze_identity,
        request=request,
        expected_files=expected_files,
    )
    del snapshot_manifest
    role_bindings = _require_mapping(binding["role_bindings"], "runtime role bindings")
    validator_role = _require_mapping(role_bindings["validator"], "validator role")
    if not _same_path(Path(str(validator_role["path"])), Path(__file__)):
        raise FenceError("executing validator is not the PRE-bound snapshot validator")
    selected_role = _require_mapping(role_bindings["selected_set"], "selected set role")
    if not _same_path(set_file, Path(str(selected_role["path"]))):
        raise FenceError("POST set path is not the PRE-bound snapshot set")
    if selected_role["sha256"] != pre["set_sha256"]:
        raise FenceError("PRE-bound set identity differs from snapshot set")

    manifest_role = _require_mapping(role_bindings["sets_manifest"], "sets manifest role")
    detached_role = _require_mapping(
        role_bindings["sets_manifest_detached"], "sets manifest detached role"
    )
    frozen_manifest_path = Path(str(manifest_role["path"]))
    frozen_manifest_raw = frozen_manifest_path.read_bytes()
    if hashlib.sha256(frozen_manifest_raw).hexdigest() != pre["manifest_sha256"]:
        raise FenceError("snapshot sets manifest differs from PRE identity")
    _read_exact_detached(
        frozen_manifest_path,
        Path(str(detached_role["path"])),
        artifact_raw=frozen_manifest_raw,
        context="snapshot sets manifest",
    )
    frozen_manifest = _strict_canonical_json(
        frozen_manifest_raw, "snapshot sets manifest"
    )
    if frozen_manifest.get("freeze_inputs_sha256") != pre["freeze_inputs_sha256"]:
        raise FenceError("snapshot freeze root differs from PRE identity")
    validate_request(
        protocol,
        phase_id=phase_id,
        symbol=symbol,
        timeframe=timeframe,
        variant=str(request["variant"]),
        from_date=from_date,
        to_date=to_date,
    )
    expected_selected = _selected_data_rows(
        protocol, frozen_manifest, symbol, from_date, to_date
    )
    if pre["selected_data"] != expected_selected:
        raise FenceError("PRE selected-data rows differ from snapshot manifest")
    actual_selected = rehash_selected_data(protocol, expected_selected)
    selected_sha = freeze.sha256_bytes(freeze.canonical_json_bytes(actual_selected))
    if selected_sha != pre["selected_data_sha256"]:
        raise FenceError("selected Model-4 data identity drift after PRE")
    _verify_external_runtime(
        pre["external_runtime"],
        protocol,
        frozen_manifest,
        powershell_path=powershell_path,
    )
    binary_role = _require_mapping(role_bindings["ea_binary"], "EA binary role")
    evidence_rows = _require_mapping(
        frozen_manifest.get("freeze_inputs"), "freeze inputs"
    ).get("evidence_artifacts")
    binary_expected = [
        row
        for row in evidence_rows
        if isinstance(row, Mapping) and row.get("id") == "ea_binary_repo"
    ]
    if len(binary_expected) != 1 or binary_role["sha256"] != binary_expected[0].get(
        "sha256"
    ):
        raise FenceError("snapshot EA binary differs from frozen binary identity")
    return {
        "schema_version": 1,
        "artifact_type": "QM5_20009_RESEARCH_VALIDATOR_POST_RECEIPT",
        "status": "PASS",
        "run_id": run_id,
        "request": request,
        "preflight_receipt_sha256": expected_pre_sha,
        "freeze_inputs_sha256": pre["freeze_inputs_sha256"],
        "manifest_sha256": pre["manifest_sha256"],
        "set_sha256": pre["set_sha256"],
        "selected_data_sha256": selected_sha,
        "phase_unlock_records": pre["phase_unlock_records"],
        "runtime_snapshot_manifest_sha256": binding["manifest_sha256"],
        "external_runtime_sha256": _canonical_payload_sha256(
            pre["external_runtime"]
        ),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", required=True)
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--timeframe", required=True)
    parser.add_argument("--set-file", required=True, type=Path)
    parser.add_argument("--from", dest="from_date", required=True)
    parser.add_argument("--to", dest="to_date", required=True)
    parser.add_argument("--run-id")
    parser.add_argument("--powershell-path", type=Path)
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--postflight-receipt", type=Path)
    parser.add_argument("--preflight-receipt-sha256")
    args = parser.parse_args(argv)
    try:
        if args.postflight_receipt:
            if not args.run_id or not args.powershell_path or not args.preflight_receipt_sha256:
                raise FenceError(
                    "POST requires run-id, PowerShell path and in-memory PRE receipt hash"
                )
            result = postflight(
                phase_id=args.phase,
                symbol=args.symbol,
                timeframe=args.timeframe,
                set_file=args.set_file,
                from_date=args.from_date,
                to_date=args.to_date,
                run_id=args.run_id,
                preflight_receipt=args.postflight_receipt,
                preflight_receipt_sha256=args.preflight_receipt_sha256,
                powershell_path=args.powershell_path,
            )
        else:
            snapshot_root: Path | None = None
            if args.receipt:
                if not args.run_id or not args.powershell_path:
                    raise FenceError("PRE receipt requires run-id and PowerShell path")
                receipt_path = Path(os.path.abspath(args.receipt))
                if receipt_path.parent.name != args.run_id:
                    raise FenceError("PRE receipt directory is not bound to run_id")
                snapshot_root = receipt_path.parent / "runtime_snapshot"
            elif args.run_id or args.powershell_path or args.preflight_receipt_sha256:
                raise FenceError("snapshot PRE arguments require an output receipt")
            result = preflight(
                phase_id=args.phase,
                symbol=args.symbol,
                timeframe=args.timeframe,
                set_file=args.set_file,
                from_date=args.from_date,
                to_date=args.to_date,
                run_id=args.run_id,
                snapshot_root=snapshot_root,
                powershell_path=args.powershell_path,
            )
        if args.receipt:
            _write_receipt_atomic(args.receipt, result)
    except (
        FenceError,
        OSError,
        json.JSONDecodeError,
        KeyError,
        TypeError,
        ValueError,
    ) as exc:
        print(f"REJECT: {exc}")
        return 2
    print(json.dumps({"status": "PASS", **result}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
