"""Strict loader for the versioned Q00..Q13 gate contract.

Legacy aliases are accepted only by :func:`read_phase_id`.  Any code preparing a
new database write or evidence artifact must call :func:`write_phase_id`, which
rejects aliases and unknown values.
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from typing import Any, Mapping


SCHEMA_VERSION = "qm.gate-manifest/v1"
DEFAULT_MANIFEST = Path(__file__).resolve().parent / "config" / "gate_manifest.v1.json"
REQUIRED_VERDICT_DIMENSIONS = (
    "execution_status",
    "evidence_strength",
    "economic_merit",
    "target_eligibility",
    "promotion_decision",
)


class GateManifestError(ValueError):
    """The gate manifest or a requested phase ID violates the contract."""


@dataclass(frozen=True)
class Gate:
    id: str
    ordinal: int
    name: str
    authority: str
    runner: str
    evidence_role: str
    next: str | None


@dataclass(frozen=True)
class GateManifest:
    schema_version: str
    pipeline_version: str
    sha256: str
    gates: tuple[Gate, ...]
    legacy_aliases: Mapping[str, str]
    verdict_dimensions: tuple[str, ...]

    @property
    def phase_ids(self) -> tuple[str, ...]:
        return tuple(gate.id for gate in self.gates)

    @property
    def names(self) -> dict[str, str]:
        return {gate.id: gate.name for gate in self.gates}


def _duplicate_key_guard(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise GateManifestError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_float(raw_value: str) -> Any:
    raise GateManifestError(f"floating-point JSON value rejected: {raw_value}")


def _reject_constant(raw_value: str) -> Any:
    raise GateManifestError(f"non-finite JSON value rejected: {raw_value}")


def _load_json(path: Path) -> tuple[dict[str, Any], bytes]:
    raw = path.read_bytes()
    try:
        value = json.loads(
            raw.decode("utf-8-sig"),
            object_pairs_hook=_duplicate_key_guard,
            parse_float=_reject_float,
            parse_constant=_reject_constant,
        )
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise GateManifestError(f"invalid gate manifest JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise GateManifestError("gate manifest root must be an object")
    return value, raw


def load_gate_manifest(path: Path = DEFAULT_MANIFEST) -> GateManifest:
    value, raw = _load_json(Path(path))
    expected_top = {
        "schema_version", "pipeline_version", "canonical_id_pattern", "write_policy",
        "legacy_policy", "verdict_dimensions", "gates", "legacy_aliases",
    }
    if set(value) != expected_top:
        raise GateManifestError("gate manifest top-level key set mismatch")
    if value["schema_version"] != SCHEMA_VERSION:
        raise GateManifestError(f"unsupported schema_version: {value['schema_version']!r}")
    if value["write_policy"] != "CANONICAL_ONLY":
        raise GateManifestError("write_policy must be CANONICAL_ONLY")
    if value["legacy_policy"] != "READ_AND_MIGRATION_ONLY":
        raise GateManifestError("legacy_policy must be READ_AND_MIGRATION_ONLY")
    try:
        pattern = re.compile(str(value["canonical_id_pattern"]))
    except re.error as exc:
        raise GateManifestError("canonical_id_pattern is invalid") from exc

    pipeline_version = str(value["pipeline_version"])
    if not pipeline_version or pipeline_version.strip() != pipeline_version:
        raise GateManifestError("pipeline_version must be a non-empty trimmed string")

    dimensions = tuple(value["verdict_dimensions"])
    if dimensions != REQUIRED_VERDICT_DIMENSIONS:
        raise GateManifestError("verdict_dimensions must use the canonical ordered contract")

    rows = value["gates"]
    if not isinstance(rows, list) or len(rows) != 14:
        raise GateManifestError("exactly 14 gates are required")
    gates: list[Gate] = []
    ids: set[str] = set()
    for expected_ordinal, row in enumerate(rows):
        if not isinstance(row, dict) or set(row) != {
            "id", "ordinal", "name", "authority", "runner", "evidence_role", "next"
        }:
            raise GateManifestError(f"gate[{expected_ordinal}] key set mismatch")
        gate = Gate(**row)
        if gate.ordinal != expected_ordinal:
            raise GateManifestError(f"gate ordinal mismatch at index {expected_ordinal}")
        if pattern.fullmatch(gate.id) is None or gate.id != f"Q{expected_ordinal:02d}":
            raise GateManifestError(f"invalid canonical gate id: {gate.id!r}")
        if gate.id in ids:
            raise GateManifestError(f"duplicate gate id: {gate.id}")
        expected_next = None if expected_ordinal == 13 else f"Q{expected_ordinal + 1:02d}"
        if gate.next != expected_next:
            raise GateManifestError(f"non-contiguous next pointer for {gate.id}")
        if not all((gate.name, gate.authority, gate.runner, gate.evidence_role)):
            raise GateManifestError(f"blank gate metadata for {gate.id}")
        ids.add(gate.id)
        gates.append(gate)

    aliases = value["legacy_aliases"]
    if not isinstance(aliases, dict) or not aliases:
        raise GateManifestError("legacy_aliases must be a non-empty object")
    normalized_aliases: dict[str, str] = {}
    for alias, target in aliases.items():
        key = str(alias).strip().upper()
        if not key or key in ids or target not in ids:
            raise GateManifestError(f"invalid legacy alias mapping: {alias!r} -> {target!r}")
        if key in normalized_aliases:
            raise GateManifestError(f"duplicate normalized legacy alias: {key}")
        normalized_aliases[key] = target

    return GateManifest(
        schema_version=SCHEMA_VERSION,
        pipeline_version=pipeline_version,
        sha256=hashlib.sha256(raw).hexdigest(),
        gates=tuple(gates),
        legacy_aliases=MappingProxyType(normalized_aliases),
        verdict_dimensions=dimensions,
    )


def write_phase_id(value: str, manifest: GateManifest | None = None) -> str:
    """Validate a canonical phase ID for a new write; aliases never pass."""

    contract = manifest or load_gate_manifest()
    candidate = value if isinstance(value, str) else ""
    if candidate not in contract.phase_ids:
        raise GateManifestError(f"non-canonical phase ID rejected for write: {value!r}")
    return candidate


def read_phase_id(value: str, manifest: GateManifest | None = None) -> str:
    """Normalize canonical IDs or explicit legacy aliases for reads/migration."""

    contract = manifest or load_gate_manifest()
    candidate = str(value).strip().upper()
    if candidate in contract.phase_ids:
        return candidate
    try:
        return contract.legacy_aliases[candidate]
    except KeyError as exc:
        raise GateManifestError(f"unknown phase ID rejected: {value!r}") from exc
