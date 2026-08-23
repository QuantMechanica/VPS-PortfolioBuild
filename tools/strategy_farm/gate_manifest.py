"""Strict loader for the versioned QuantMechanica gate contract.

Legacy aliases are accepted only by :func:`read_phase_id`.  Any code preparing a
new database write or evidence artifact must call :func:`write_phase_id`, which
rejects aliases and unknown values.

The v2 default adds the read-inert Q10 -> Q14 -> Q15 -> Q16 -> Q11
optimization fork.  The v3 candidate describes the OWNER-approved Q10A
baseline evidence binding and revised Q09/Q14-Q16/Q11 presentation, but remains
opt-in until its prerequisite review closes.  The ordinary Q00 -> Q13 chain
remains explicit and v1/v2 manifests remain valid fixtures.
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from typing import Any, Mapping


SCHEMA_VERSION_V1 = "qm.gate-manifest/v1"
SCHEMA_VERSION_V2 = "qm.gate-manifest/v2"
SCHEMA_VERSION_V3 = "qm.gate-manifest/v3"
SCHEMA_VERSION = SCHEMA_VERSION_V2
SUPPORTED_SCHEMA_VERSIONS = frozenset(
    {SCHEMA_VERSION_V1, SCHEMA_VERSION_V2, SCHEMA_VERSION_V3}
)
CONFIG_DIR = Path(__file__).resolve().parent / "config"
V1_MANIFEST = CONFIG_DIR / "gate_manifest.v1.json"
# Deliberately keep v2 active.  Switching DEFAULT_MANIFEST is an activation act
# that requires Claude review after OPS-Q10-REALIGN-E1-E2 is closed.
DEFAULT_MANIFEST = CONFIG_DIR / "gate_manifest.v2.json"
V3_MANIFEST = CONFIG_DIR / "gate_manifest.v3.json"
REQUIRED_VERDICT_DIMENSIONS = (
    "execution_status",
    "evidence_strength",
    "economic_merit",
    "target_eligibility",
    "promotion_decision",
)
REQUIRED_LEGACY_ALIASES = {
    "G0": "Q00",
    "P1": "Q01",
    "P2": "Q02",
    "P3": "Q03",
    "P3.5": "Q03",
    "P4": "Q04",
    "P5": "Q05",
    "P5B": "Q05",
    "P5C": "Q05",
    "P6": "Q07",
    "P7": "Q08",
    "P8": "Q08",
    "P9": "Q11",
    "P9B": "Q12",
    "P10": "Q13",
}
V1_PHASE_IDS = tuple(f"Q{ordinal:02d}" for ordinal in range(14))
V2_PHASE_IDS = tuple(f"Q{ordinal:02d}" for ordinal in range(17))
V2_OPTIMIZATION_NEXT = {"Q14": "Q15", "Q15": "Q16", "Q16": "Q11"}


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
    extension_topology: Mapping[str, Any] | None = None

    @property
    def phase_ids(self) -> tuple[str, ...]:
        return tuple(gate.id for gate in self.gates)

    @property
    def names(self) -> dict[str, str]:
        return {gate.id: gate.name for gate in self.gates}

    @property
    def display_names(self) -> dict[str, str]:
        """Gate names plus non-writable evidence-stage display tokens.

        Q10A in v3 is intentionally not a database phase and therefore never
        appears in :attr:`phase_ids`; it is a label for a hash-bound Q08 evidence
        reuse.  Keeping it in this display-only map prevents accidental writes.
        """

        names = self.names
        if self.schema_version == SCHEMA_VERSION_V3 and self.extension_topology:
            stage = self.extension_topology["baseline_stage"]
            names[str(stage["id"])] = str(stage["name"])
        return names

    @property
    def next_by_phase(self) -> dict[str, str | None]:
        return {gate.id: gate.next for gate in self.gates}


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


def _freeze(value: Any) -> Any:
    if isinstance(value, dict):
        return MappingProxyType({str(key): _freeze(item) for key, item in value.items()})
    if isinstance(value, list):
        return tuple(_freeze(item) for item in value)
    return value


def _validate_v2_topology(raw: Any) -> Mapping[str, Any]:
    if not isinstance(raw, dict) or set(raw) != {
        "ordinary_chain", "optimization_fork", "storage_lanes"
    }:
        raise GateManifestError("v2 extension_topology key set mismatch")
    ordinary_chain = raw["ordinary_chain"]
    if not isinstance(ordinary_chain, list) or tuple(ordinary_chain) != V1_PHASE_IDS:
        raise GateManifestError("v2 ordinary_chain must preserve Q00 through Q13")
    fork = raw["optimization_fork"]
    if not isinstance(fork, dict) or set(fork) != {
        "from", "entry", "path", "rejoins", "activation"
    }:
        raise GateManifestError("v2 optimization_fork key set mismatch")
    if fork != {
        "from": "Q10",
        "entry": "Q14",
        "path": ["Q14", "Q15", "Q16"],
        "rejoins": "Q11",
        "activation": "EXPLICIT_Q14_ADMISSION_RUN",
    }:
        raise GateManifestError("v2 optimization fork must be Q10->Q14->Q15->Q16->Q11")
    lanes = raw["storage_lanes"]
    if not isinstance(lanes, list) or len(lanes) != 2:
        raise GateManifestError("v2 requires exactly two Q11 storage lanes")
    expected_lane_ids = ("Q11_DXZ", "Q11_FTMO")
    for index, (lane, lane_id) in enumerate(zip(lanes, expected_lane_ids)):
        if not isinstance(lane, dict) or set(lane) != {
            "id", "parent", "authority", "runner", "evidence_role", "top_level"
        }:
            raise GateManifestError(f"v2 storage_lanes[{index}] key set mismatch")
        if (
            lane.get("id") != lane_id
            or lane.get("parent") != "Q11"
            or lane.get("authority") != "OWNER"
            or lane.get("runner") != "MANUAL_OR_ANALYTIC"
            or lane.get("top_level") is not False
            or not str(lane.get("evidence_role") or "").strip()
        ):
            raise GateManifestError(f"invalid v2 Q11 storage lane: {lane_id}")
    return _freeze(raw)


def _validate_v3_topology(raw: Any) -> Mapping[str, Any]:
    expected_keys = {
        "ordinary_chain",
        "baseline_stage",
        "target_sequence",
        "optimization_fork",
        "q16_dependencies",
        "portfolio_routes",
        "storage_lanes",
        "activation_guard",
    }
    if not isinstance(raw, dict) or set(raw) != expected_keys:
        raise GateManifestError("v3 extension_topology key set mismatch")
    if raw["ordinary_chain"] != list(V1_PHASE_IDS):
        raise GateManifestError("v3 ordinary_chain must preserve Q00 through Q13")
    if raw["baseline_stage"] != {
        "id": "Q10A",
        "name": "Baseline Full Run",
        "top_level": False,
        "kind": "EVIDENCE_BINDING",
        "source_phase": "Q08",
        "source_evidence_role": "TARGET_NEUTRAL_EVIDENCE_DOSSIER",
        "reuse_policy": "REUSE_ONLY_HASH_BOUND_FULL_HISTORY_Q08_BASELINE",
        "missing_binding_action": "REQUIRE_Q10A_BASELINE_RUN",
        "next": "Q09",
    }:
        raise GateManifestError("v3 Q10A must be a read-only Q08 evidence binding")
    if raw["target_sequence"] != [
        "Q10A", "Q09", "Q10", "Q14", "Q15", "Q16", "Q11"
    ]:
        raise GateManifestError("v3 target sequence mismatch")
    if raw["optimization_fork"] != {
        "from": "Q10",
        "entry": "Q14",
        "path": ["Q14", "Q15", "Q16"],
        "rejoins": "Q11",
        "activation": "EXPLICIT_Q14_ADMISSION_RUN",
        "pattern_filter_cap_per_direction": 3,
        "selection_contract": "DL-089",
    }:
        raise GateManifestError("v3 optimization fork contract mismatch")
    if raw["q16_dependencies"] != [
        {"role": "BASELINE_FULL_RUN", "phase": "Q10A", "source_phase": "Q08"},
        {"role": "INCUMBENT_Q10", "phase": "Q10", "source_phase": "Q10"},
    ]:
        raise GateManifestError("v3 Q16 dependency contract mismatch")
    if raw["portfolio_routes"] != [
        {"from": "Q10", "condition": "NOT_OPTIMIZED", "to": "Q11"},
        {"from": "Q16", "condition": "OPTIMIZED", "to": "Q11"},
    ]:
        raise GateManifestError("v3 Q11 routing contract mismatch")
    lanes = raw["storage_lanes"]
    if not isinstance(lanes, list) or len(lanes) != 2:
        raise GateManifestError("v3 requires exactly two Q11 storage lanes")
    expected_lane_ids = ("Q11_DXZ", "Q11_FTMO")
    for index, (lane, lane_id) in enumerate(zip(lanes, expected_lane_ids)):
        if not isinstance(lane, dict) or set(lane) != {
            "id", "parent", "authority", "runner", "evidence_role", "top_level"
        }:
            raise GateManifestError(f"v3 storage_lanes[{index}] key set mismatch")
        if (
            lane.get("id") != lane_id
            or lane.get("parent") != "Q11"
            or lane.get("authority") != "OWNER"
            or lane.get("runner") != "MANUAL_OR_ANALYTIC"
            or lane.get("top_level") is not False
            or not str(lane.get("evidence_role") or "").strip()
        ):
            raise GateManifestError(f"invalid v3 Q11 storage lane: {lane_id}")
    if raw["activation_guard"] != {
        "state": "READ_INERT",
        "requires_completed_review": "OPS-Q10-REALIGN-E1-E2",
        "requires_approver": "CLAUDE",
        "default_manifest_switch": False,
    }:
        raise GateManifestError("v3 activation guard mismatch")
    return _freeze(raw)


def load_gate_manifest(path: Path = DEFAULT_MANIFEST) -> GateManifest:
    value, raw = _load_json(Path(path))
    schema_version = str(value.get("schema_version") or "")
    if schema_version not in SUPPORTED_SCHEMA_VERSIONS:
        raise GateManifestError(f"unsupported schema_version: {schema_version!r}")
    expected_top = {
        "schema_version", "pipeline_version", "canonical_id_pattern", "write_policy",
        "legacy_policy", "verdict_dimensions", "gates", "legacy_aliases",
    }
    if schema_version in {SCHEMA_VERSION_V2, SCHEMA_VERSION_V3}:
        expected_top.add("extension_topology")
    if set(value) != expected_top:
        raise GateManifestError("gate manifest top-level key set mismatch")
    if value["write_policy"] != "CANONICAL_ONLY":
        raise GateManifestError("write_policy must be CANONICAL_ONLY")
    if value["legacy_policy"] != "READ_AND_MIGRATION_ONLY":
        raise GateManifestError("legacy_policy must be READ_AND_MIGRATION_ONLY")
    try:
        pattern = re.compile(str(value["canonical_id_pattern"]))
    except re.error as exc:
        raise GateManifestError("canonical_id_pattern is invalid") from exc
    expected_pattern = (
        r"^Q(?:0[0-9]|1[0-3])$"
        if schema_version == SCHEMA_VERSION_V1
        else r"^Q(?:0[0-9]|1[0-6])$"
    )
    if str(value["canonical_id_pattern"]) != expected_pattern:
        raise GateManifestError(f"{schema_version} canonical_id_pattern mismatch")

    pipeline_version = str(value["pipeline_version"])
    if not pipeline_version or pipeline_version.strip() != pipeline_version:
        raise GateManifestError("pipeline_version must be a non-empty trimmed string")

    dimensions = tuple(value["verdict_dimensions"])
    if dimensions != REQUIRED_VERDICT_DIMENSIONS:
        raise GateManifestError("verdict_dimensions must use the canonical ordered contract")

    rows = value["gates"]
    expected_ids = V1_PHASE_IDS if schema_version == SCHEMA_VERSION_V1 else V2_PHASE_IDS
    if not isinstance(rows, list) or len(rows) != len(expected_ids):
        raise GateManifestError(f"exactly {len(expected_ids)} gates are required")
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
        if expected_ordinal < 13:
            expected_next = f"Q{expected_ordinal + 1:02d}"
        elif expected_ordinal == 13:
            expected_next = None
        else:
            expected_next = V2_OPTIMIZATION_NEXT[gate.id]
        if gate.next != expected_next:
            raise GateManifestError(f"non-contiguous or invalid next pointer for {gate.id}")
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
    if normalized_aliases != REQUIRED_LEGACY_ALIASES:
        raise GateManifestError("legacy_aliases differ from the frozen v1 contract")

    if schema_version == SCHEMA_VERSION_V2:
        extension_topology = _validate_v2_topology(value["extension_topology"])
    elif schema_version == SCHEMA_VERSION_V3:
        extension_topology = _validate_v3_topology(value["extension_topology"])
    else:
        extension_topology = None

    return GateManifest(
        schema_version=schema_version,
        pipeline_version=pipeline_version,
        sha256=hashlib.sha256(raw).hexdigest(),
        gates=tuple(gates),
        legacy_aliases=MappingProxyType(normalized_aliases),
        verdict_dimensions=dimensions,
        extension_topology=extension_topology,
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
