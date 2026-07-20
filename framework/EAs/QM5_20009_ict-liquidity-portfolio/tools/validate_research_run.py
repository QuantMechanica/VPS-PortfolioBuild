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
import tempfile
from datetime import date, datetime
from pathlib import Path
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


def _write_receipt_atomic(path: Path, payload: Mapping[str, Any]) -> None:
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = (json.dumps(payload, indent=2, sort_keys=True) + "\n").encode("utf-8")
    descriptor, temporary = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(encoded)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


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
    root = freeze._artifact_path(str(protocol["model4_data"]["destination_root"]))
    actual_rows: list[dict[str, Any]] = []
    for expected in rows:
        relative = str(expected["relative_path"])
        path = root / Path(relative)
        if not path.is_file() or path.stat().st_size != int(expected["size"]):
            raise FenceError(f"selected Model-4 file missing/size drift: {path}")
        digest = freeze.sha256_file(path)
        if digest != expected["sha256"]:
            raise FenceError(f"selected Model-4 file hash drift: {path}")
        actual_rows.append({"relative_path": relative, "size": path.stat().st_size, "sha256": digest})
    return actual_rows


def preflight(
    *,
    phase_id: str,
    symbol: str,
    timeframe: str,
    set_file: Path,
    from_date: str,
    to_date: str,
) -> dict[str, Any]:
    try:
        issues = freeze.check()
    except freeze.FreezeError as exc:
        raise FenceError(str(exc)) from exc
    if issues:
        raise FenceError(f"freeze bundle drift: {issues[0]}")
    if set_file.resolve().parent != freeze.SETS_ROOT.resolve():
        raise FenceError("set file must come from the frozen sets directory")
    metadata = parse_set_metadata(set_file)
    protocol = freeze.load_protocol()
    if metadata["symbol"] != symbol or metadata["timeframe"] != timeframe:
        raise FenceError("CLI symbol/timeframe does not match frozen set header")
    manifest_path = freeze.SETS_ROOT / "manifest.json"
    manifest_bytes = manifest_path.read_bytes()
    manifest = json.loads(manifest_bytes)
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
    return {
        "schema_version": 1,
        "request": {
            "phase": phase_id,
            "symbol": symbol,
            "timeframe": timeframe,
            "variant": metadata["variant"],
            "from": from_date,
            "to": to_date,
        },
        "freeze_inputs_sha256": manifest["freeze_inputs_sha256"],
        "manifest_sha256": manifest_sha256,
        "set_sha256": set_digest,
        "selected_data_sha256": freeze.sha256_bytes(freeze.canonical_json_bytes(actual_data)),
        "phase_unlock_records": unlock_records,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", required=True)
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--timeframe", required=True)
    parser.add_argument("--set-file", required=True, type=Path)
    parser.add_argument("--from", dest="from_date", required=True)
    parser.add_argument("--to", dest="to_date", required=True)
    receipts = parser.add_mutually_exclusive_group()
    receipts.add_argument("--receipt", type=Path)
    receipts.add_argument("--postflight-receipt", type=Path)
    args = parser.parse_args(argv)
    try:
        result = preflight(
            phase_id=args.phase,
            symbol=args.symbol,
            timeframe=args.timeframe,
            set_file=args.set_file,
            from_date=args.from_date,
            to_date=args.to_date,
        )
        if args.postflight_receipt:
            previous = json.loads(args.postflight_receipt.read_text(encoding="utf-8"))
            if previous != result:
                raise FenceError("postflight evidence differs from preflight receipt")
        elif args.receipt:
            _write_receipt_atomic(args.receipt, result)
    except (FenceError, OSError, json.JSONDecodeError) as exc:
        print(f"REJECT: {exc}")
        return 2
    print(json.dumps({"status": "PASS", **result}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
