"""Strict loader for the versioned QuantMechanica gate contract.

Legacy aliases are accepted only by :func:`read_phase_id`.  Any code preparing a
new database write or evidence artifact must call :func:`write_phase_id`, which
rejects aliases and unknown values.

The v2 default adds the read-inert Q10 -> Q14 -> Q15 -> Q16 -> Q11
optimization fork.  The active v3 contract describes the OWNER-approved Q10A
baseline evidence binding and revised Q09/Q14-Q16/Q11 presentation.  The v4
loader branch accepts the READ_INERT linear three-macro-phase proposal without
making it operational.  The ordinary Q00 -> Q13 v3 chain remains explicit and
v1/v2 manifests remain valid fixtures.
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
SCHEMA_VERSION_V4 = "qm.gate-manifest/v4"
SCHEMA_VERSION = SCHEMA_VERSION_V3
SUPPORTED_SCHEMA_VERSIONS = frozenset(
    {SCHEMA_VERSION_V1, SCHEMA_VERSION_V2, SCHEMA_VERSION_V3, SCHEMA_VERSION_V4}
)
CONFIG_DIR = Path(__file__).resolve().parent / "config"
V1_MANIFEST = CONFIG_DIR / "gate_manifest.v1.json"
V2_MANIFEST = CONFIG_DIR / "gate_manifest.v2.json"
V3_MANIFEST = CONFIG_DIR / "gate_manifest.v3.json"
V4_DRAFT_MANIFEST = CONFIG_DIR / "gate_manifest.v4.draft.json"
# Reserved final path.  It intentionally does not exist until OWNER ratification;
# load_gate_manifest accepts either this future path or V4_DRAFT_MANIFEST when
# the corresponding file is explicitly supplied.
V4_MANIFEST = CONFIG_DIR / "gate_manifest.v4.json"
# Gate Manifest v3 activated 2026-08-23 by CLAUDE under OWNER chat
# authorization, after Claude-Review d5c13a08 (APPROVED) whose prerequisite
# OPS-Q10-REALIGN-E1-E2 review 9b40ff25 was APPROVED.  The activation guard is
# fail-closed (see _validate_v3_activation_guard): a READ_INERT manifest can
# never become the default, and an ACTIVE manifest must carry both review refs.
DEFAULT_MANIFEST = V3_MANIFEST
# The two review references that must be recorded before a v3 manifest may be
# ACTIVE: OPS-Q10-REALIGN-E1-E2 closure (9b40ff25) and the v3 Claude review
# (d5c13a08).
ACTIVATION_REVIEW_REFS = ("9b40ff25", "d5c13a08")
# The two references that must be recorded before a v4 manifest may be ACTIVE:
# the v4 loader review-fix commit (a4990f77a) and the OWNER decision record for
# the linear three-phase renumbering.  Mirrors the v3 pattern: an ACTIVE v4
# manifest must carry BOTH, so a green review is always provable from the file.
V4_ACTIVATION_REVIEW_REFS = (
    "a4990f77a",
    "decisions/2026-08-23_owner_gate_manifest_v4_linear.md",
)
ACTIVATION_STATES = frozenset({"READ_INERT", "ACTIVE"})
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
REQUIRED_LEGACY_ALIASES_V4 = {
    **REQUIRED_LEGACY_ALIASES,
    "P9": "Q15",
    "P9B": "Q16",
    "P10": "Q17",
}
V1_PHASE_IDS = tuple(f"Q{ordinal:02d}" for ordinal in range(14))
V2_PHASE_IDS = tuple(f"Q{ordinal:02d}" for ordinal in range(17))
V4_PHASE_IDS = tuple(f"Q{ordinal:02d}" for ordinal in range(18))
V2_OPTIMIZATION_NEXT = {"Q14": "Q15", "Q15": "Q16", "Q16": "Q11"}
V4_MACRO_PHASE_GATES = {
    "1_STRATEGIEBEWEIS": V4_PHASE_IDS[:9],
    "2_OPTIMIERUNG": V4_PHASE_IDS[9:15],
    "3_BUCHBEWERTUNG": V4_PHASE_IDS[15:],
}
V4_CONTRACT_EQUIVALENCE = {
    "Q00": "Q00", "Q01": "Q01", "Q02": "Q02", "Q03": "Q03",
    "Q04": "Q04", "Q05": "Q05", "Q06": "Q06", "Q07": "Q07",
    "Q08": "Q08", "Q10A": "Q09", "Q09": "Q10",
    "Q09_NEWS": "Q10_NEWS", "Q09_PORTFOLIO": "Q10_PORTFOLIO",
    "Q10": "Q11", "Q14": "Q12", "Q15": "Q13", "Q16": "Q14",
    "Q11": "Q15", "Q11_DXZ": "Q15_DXZ", "Q11_FTMO": "Q15_FTMO",
    "Q12": "Q16", "Q13": "Q17",
}
V4_DEPENDENCY_ROLE_EQUIVALENCE = {
    "Q08_INPUT": "Q08_INPUT",
    "Q09_NEWS": "Q10_NEWS",
    "Q09_PORTFOLIO": "Q10_PORTFOLIO",
    "PARENT_LINEAGE": "PARENT_LINEAGE",
    "CHALLENGER_Q10": "CHALLENGER_Q11",
    "Q14_ADMISSION": "Q12_ADMISSION",
}
V4_SOURCE_BY_GATE = {
    target: source
    for source, target in V4_CONTRACT_EQUIVALENCE.items()
    if target in V4_PHASE_IDS
}

# Stable runtime vocabulary.  Numeric gate ids are presentation/storage details
# owned by each manifest; dispatch code asks for the evidence responsibility.
EVIDENCE_ROLE_PREFIXES = MappingProxyType({
    "BASELINE_FULL_RUN": "PRE_NEWS_FULL_HISTORY_BASELINE",
    "NEWS": "NEWS_MODE_SELECTION_AND_FTMO_RECOMMENDATION",
    "INCUMBENT": "LOCKED_CONFIGURATION_REPRODUCIBILITY",
    "PATTERN": "DL089_PREREGISTERED_PATTERN_FILTER_SELECTION",
    "PARAM_OPT": "DEV_ONLY_PARAMETER_SWEEP_AND_FREEZE",
    "HEAD_TO_HEAD": "SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT",
    "PORTFOLIO": "TARGET_SPECIFIC_PORTFOLIO_ADMISSION",
    "OPS": "DEPLOYMENT_READINESS",
    "LIVE": "PROSPECTIVE_BURN_IN",
})


def _v3_role_to_v4(role: str) -> str:
    """Renumber a trailing embedded v3 gate reference in an ``evidence_role``.

    A v3 ``evidence_role`` may end in a ``_Q<NN>`` token that names another v3
    gate (only ``SEALED_..._INCUMBENT_Q10`` does today).  Under v4 that
    referenced gate is renumbered per :data:`V4_CONTRACT_EQUIVALENCE`
    (v3 ``Q10`` incumbent -> v4 ``Q11``), so the faithful v4 role carries the
    v4 number.  Every other role has no such token and is returned byte-for-byte
    unchanged, keeping the caller's comparison strict.  This is the ONLY drift
    the criteria-preservation check tolerates: a mechanical renumber driven
    entirely by the authoritative equivalence table, never a semantic change.
    """

    prefix, sep, token = role.rpartition("_")
    if sep and token in V4_CONTRACT_EQUIVALENCE and V4_CONTRACT_EQUIVALENCE[token] in V4_PHASE_IDS:
        return f"{prefix}{sep}{V4_CONTRACT_EQUIVALENCE[token]}"
    return role


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
    macro_phase: str | None = None


@dataclass(frozen=True)
class GateManifest:
    schema_version: str
    pipeline_version: str
    sha256: str
    gates: tuple[Gate, ...]
    legacy_aliases: Mapping[str, str]
    verdict_dimensions: tuple[str, ...]
    extension_topology: Mapping[str, Any] | None = None
    contract_equivalence: Mapping[str, Any] | None = None

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

    @property
    def terminal_requalification_gate(self) -> str:
        """Return the active contract's terminal per-EA requalification gate.

        The evidence role is stable across gate renumberings (Q16 in v3 and
        Q14 in the proposed v4 contract), so consumers never infer this
        authority from a numeric gate literal or a non-monotone ``next`` edge.
        """
        matches = [
            gate.id
            for gate in self.gates
            if gate.evidence_role.startswith(
                "SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT"
            )
        ]
        if len(matches) != 1:
            raise GateManifestError(
                "gate manifest must define exactly one terminal requalification gate"
            )
        return matches[0]

    def gate_for_role(self, role: str) -> str:
        """Resolve one stable runtime evidence role to this contract's gate id.

        V3's baseline-full-run is the sole display-only exception: ``Q10A`` is
        returned because that contract binds Q08 full-history evidence instead
        of writing a top-level work item.  V4 returns its real ``Q09`` gate.
        """

        logical_role = str(role or "").strip().upper()
        try:
            prefix = EVIDENCE_ROLE_PREFIXES[logical_role]
        except KeyError as exc:
            raise GateManifestError(f"unknown evidence role: {role!r}") from exc
        matches = [gate.id for gate in self.gates if gate.evidence_role.startswith(prefix)]
        if logical_role == "BASELINE_FULL_RUN" and not matches:
            stage = self.baseline_stage
            if stage and str(stage.get("name")) == "Baseline Full Run":
                return str(stage["id"])
        if len(matches) != 1:
            raise GateManifestError(
                f"gate manifest must define exactly one {logical_role} gate; found {matches}"
            )
        return matches[0]

    def storage_phase_for_role(self, role: str, lane: str | None = None) -> str:
        """Resolve a role to its writable phase, including the split news lane."""

        gate_id = self.gate_for_role(role)
        if str(role).strip().upper() != "NEWS":
            if lane is not None:
                raise GateManifestError(f"storage lane is only valid for NEWS, got {role!r}")
            return gate_id
        lane_id = str(lane or "NEWS").strip().upper()
        if lane_id not in {"NEWS", "PORTFOLIO"}:
            raise GateManifestError(f"unknown NEWS storage lane: {lane!r}")
        return f"{gate_id}_{lane_id}"

    def dependency_role(self, v3_role: str) -> str:
        """Return the dependency token owned by this manifest version."""

        token = str(v3_role or "").strip().upper()
        if self.schema_version != SCHEMA_VERSION_V4:
            return token
        if self.contract_equivalence is None:
            raise GateManifestError("v4 manifest has no dependency-role equivalence")
        try:
            return str(self.contract_equivalence["dependency_role_v3_to_v4"][token])
        except KeyError as exc:
            raise GateManifestError(f"dependency role has no v4 equivalence: {token!r}") from exc

    @property
    def head_to_head_dependency_roles(self) -> tuple[str, ...]:
        """Ordered dependency tokens for the sealed comparison work item."""

        if self.schema_version == SCHEMA_VERSION_V4:
            return ("BASELINE_Q09", "INCUMBENT_Q11", "CHALLENGER_Q11")
        return ("PARENT_LINEAGE", "CHALLENGER_Q10")

    @property
    def baseline_stage(self) -> Mapping[str, Any] | None:
        """The v3 Q10A baseline evidence-binding stage (None before v3)."""
        if not self.extension_topology:
            return None
        return self.extension_topology.get("baseline_stage")

    @property
    def baseline_reuse_policy(self) -> str | None:
        """How Q10A reuses a Q08 baseline, else None.

        ``REUSE_ONLY_HASH_BOUND_FULL_HISTORY_Q08_BASELINE`` in v3.
        """
        stage = self.baseline_stage
        return None if stage is None else str(stage.get("reuse_policy"))

    @property
    def baseline_missing_binding_action(self) -> str | None:
        """Fail-closed action when no reusable Q08 baseline exists.

        ``REQUIRE_Q10A_BASELINE_RUN`` in v3, else None.
        """
        stage = self.baseline_stage
        return None if stage is None else str(stage.get("missing_binding_action"))

    @property
    def q16_dependencies(self) -> tuple[Mapping[str, Any], ...]:
        """Ordered Q16 evidence dependencies (baseline full run + incumbent Q10).

        Empty for manifests without the v3 optimization contract.
        """
        if not self.extension_topology:
            return ()
        return tuple(self.extension_topology.get("q16_dependencies", ()))

    @property
    def portfolio_routes(self) -> tuple[Mapping[str, Any], ...]:
        """The Q11 entry routes (Q10 non-optimized, Q16 optimized)."""
        if not self.extension_topology:
            return ()
        return tuple(self.extension_topology.get("portfolio_routes", ()))

    def portfolio_route(self, *, optimized: bool) -> str | None:
        """Return no automatic portfolio predecessor.

        The v3 JSON retains its historical topology as contract evidence, but
        OWNER decision A2 makes optimization mandatory and the book guard is
        now the only Phase-3 entry authority under both v3 and v4.
        """
        del optimized
        return None

    @property
    def activation_state(self) -> str | None:
        """The v3/v4 activation-guard state (READ_INERT/ACTIVE), else None."""
        if not self.extension_topology:
            return None
        guard = self.extension_topology.get("activation_guard")
        return None if guard is None else str(guard.get("state"))

    def macro_phase(self, gate_id: str) -> str | None:
        """Return a gate's v4 macro phase; older contracts return ``None``."""

        for gate in self.gates:
            if gate.id == gate_id:
                return gate.macro_phase
        raise GateManifestError(f"unknown gate ID for macro phase: {gate_id!r}")

    def equivalent_gate(
        self, gate_id: str, from_version: str, to_version: str
    ) -> str:
        """Translate an explicitly versioned gate ID using the v4 contract map.

        Translation never guesses from an unstamped value.  The v4 manifest is
        the only contract that owns the v3<->v4 equivalence table.
        """

        versions = {
            "v3": "v3", SCHEMA_VERSION_V3: "v3",
            "v4": "v4", SCHEMA_VERSION_V4: "v4",
        }
        try:
            source = versions[str(from_version).lower()]
            target = versions[str(to_version).lower()]
        except KeyError as exc:
            raise GateManifestError(
                f"unsupported gate contract translation: {from_version!r} -> {to_version!r}"
            ) from exc
        if self.contract_equivalence is None:
            raise GateManifestError("manifest has no contract_equivalence table")
        forward = dict(self.contract_equivalence["v3_to_v4"])
        mapping = forward if source == "v3" else {value: key for key, value in forward.items()}
        if source == target:
            domain = forward if source == "v3" else mapping
            if gate_id in domain:
                return gate_id
        else:
            try:
                return str(mapping[gate_id])
            except KeyError:
                pass
        raise GateManifestError(
            f"gate {gate_id!r} has no {source}->{target} contract equivalence"
        )


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


def _validate_v3_activation_guard(guard: Any, *, is_default: bool) -> None:
    """Fail-closed gate on the v3 activation record.

    Two invariants, enforced in both directions:

    * a ``READ_INERT`` manifest can never become the default — its
      ``default_manifest_switch`` must be ``false`` and it may not be loaded via
      :data:`DEFAULT_MANIFEST`;
    * an ``ACTIVE`` manifest must set ``default_manifest_switch=true``, record
      the approver that also appears in ``requires_approver``, carry an
      ``activated_at`` stamp, and list **both** :data:`ACTIVATION_REVIEW_REFS`.
    """
    if not isinstance(guard, dict):
        raise GateManifestError("v3 activation_guard must be an object")
    base_keys = {
        "state",
        "requires_completed_review",
        "requires_approver",
        "default_manifest_switch",
    }
    state = guard.get("state")
    if state not in ACTIVATION_STATES:
        raise GateManifestError(f"v3 activation_guard state invalid: {state!r}")
    if guard.get("requires_completed_review") != "OPS-Q10-REALIGN-E1-E2":
        raise GateManifestError(
            "v3 activation_guard requires_completed_review mismatch"
        )
    approver_required = guard.get("requires_approver")
    if approver_required != "CLAUDE":
        raise GateManifestError("v3 activation_guard requires_approver mismatch")
    switch = guard.get("default_manifest_switch")
    if not isinstance(switch, bool):
        raise GateManifestError(
            "v3 activation_guard default_manifest_switch must be boolean"
        )
    if state == "READ_INERT":
        if set(guard) != base_keys:
            raise GateManifestError("v3 READ_INERT activation_guard key set mismatch")
        if switch is not False:
            raise GateManifestError("v3 READ_INERT manifest cannot switch the default")
        if is_default:
            raise GateManifestError(
                "v3 READ_INERT manifest cannot be loaded as the default manifest"
            )
        return
    # state == "ACTIVE"
    if set(guard) != base_keys | {"activated_by", "activated_at", "review_refs"}:
        raise GateManifestError("v3 ACTIVE activation_guard key set mismatch")
    if switch is not True:
        raise GateManifestError("v3 ACTIVE manifest must switch the default")
    if str(guard.get("activated_by") or "").strip() != approver_required:
        raise GateManifestError(
            "v3 ACTIVE manifest must record activated_by equal to requires_approver"
        )
    if not str(guard.get("activated_at") or "").strip():
        raise GateManifestError("v3 ACTIVE manifest must record activated_at")
    refs = guard.get("review_refs")
    if not isinstance(refs, list) or not set(ACTIVATION_REVIEW_REFS).issubset(
        {str(item) for item in refs}
    ):
        raise GateManifestError(
            "v3 ACTIVE manifest must record both activation review refs"
        )


def _validate_v3_topology(raw: Any, *, is_default: bool) -> Mapping[str, Any]:
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
    _validate_v3_activation_guard(raw["activation_guard"], is_default=is_default)
    return _freeze(raw)


def _validate_v4_activation_guard(guard: Any, *, is_default: bool) -> None:
    """Fail closed until a v4 ratification record is complete."""

    if not isinstance(guard, dict):
        raise GateManifestError("v4 activation_guard must be an object")
    base_keys = {
        "state",
        "requires_completed_review",
        "requires_approver",
        "default_manifest_switch",
    }
    state = guard.get("state")
    if state not in ACTIVATION_STATES:
        raise GateManifestError(f"v4 activation_guard state invalid: {state!r}")
    if guard.get("requires_completed_review") != "OWNER-RATIFY-GATE-MANIFEST-V4":
        raise GateManifestError("v4 activation_guard completed review mismatch")
    approver_required = str(guard.get("requires_approver") or "").strip()
    if not approver_required:
        raise GateManifestError("v4 activation_guard requires an approver")
    switch = guard.get("default_manifest_switch")
    if not isinstance(switch, bool):
        raise GateManifestError("v4 default_manifest_switch must be boolean")
    if state == "READ_INERT":
        if set(guard) != base_keys:
            raise GateManifestError("v4 READ_INERT activation_guard key set mismatch")
        if switch is not False:
            raise GateManifestError("v4 READ_INERT manifest cannot switch the default")
        if is_default:
            raise GateManifestError(
                "v4 READ_INERT manifest cannot be loaded as the default manifest"
            )
        return

    active_keys = base_keys | {"activated_by", "activated_at", "review_refs"}
    if set(guard) != active_keys:
        raise GateManifestError("v4 ACTIVE activation_guard key set mismatch")
    if switch is not True:
        raise GateManifestError("v4 ACTIVE manifest must switch the default")
    if str(guard.get("activated_by") or "").strip() != approver_required:
        raise GateManifestError(
            "v4 ACTIVE manifest must record activated_by equal to requires_approver"
        )
    if not str(guard.get("activated_at") or "").strip():
        raise GateManifestError("v4 ACTIVE manifest must record activated_at")
    refs = guard.get("review_refs")
    if (
        not isinstance(refs, list)
        or not refs
        or len({str(item).strip() for item in refs}) != len(refs)
        or any(not str(item).strip() for item in refs)
    ):
        raise GateManifestError("v4 ACTIVE manifest must record unique review_refs")
    if not set(V4_ACTIVATION_REVIEW_REFS).issubset(
        {str(item).strip() for item in refs}
    ):
        raise GateManifestError(
            "v4 ACTIVE manifest must record both v4 activation review refs"
        )


def _validate_v4_contract_equivalence(raw: Any) -> Mapping[str, Any]:
    if not isinstance(raw, dict) or set(raw) != {
        "note", "v3_to_v4", "dependency_role_v3_to_v4"
    }:
        raise GateManifestError("v4 contract_equivalence key set mismatch")
    if raw["v3_to_v4"] != V4_CONTRACT_EQUIVALENCE:
        raise GateManifestError("v4 gate contract equivalence mismatch")
    if len(set(raw["v3_to_v4"].values())) != len(raw["v3_to_v4"]):
        raise GateManifestError("v4 gate contract equivalence must be reversible")
    if raw["dependency_role_v3_to_v4"] != V4_DEPENDENCY_ROLE_EQUIVALENCE:
        raise GateManifestError("v4 dependency-role equivalence mismatch")
    if not str(raw["note"] or "").strip():
        raise GateManifestError("v4 contract_equivalence note must be non-empty")
    return _freeze(raw)


def _validate_v4_topology(
    value: Mapping[str, Any], gates: tuple[Gate, ...], *, is_default: bool
) -> Mapping[str, Any]:
    """Validate the READ_INERT linear three-phase v4 proposal topology."""

    macro_phases = value["macro_phases"]
    if not isinstance(macro_phases, list) or len(macro_phases) != 3:
        raise GateManifestError("v4 requires exactly three macro phases")
    expected_names = {
        "1_STRATEGIEBEWEIS": "Strategie beweist sich",
        "2_OPTIMIERUNG": "Strategie wird optimiert / requalifiziert",
        "3_BUCHBEWERTUNG": "Strategie wird zum Buch bewertet",
    }
    for row, (phase_id, phase_gates) in zip(
        macro_phases, V4_MACRO_PHASE_GATES.items()
    ):
        if not isinstance(row, dict) or set(row) != {"id", "name", "gates"}:
            raise GateManifestError("v4 macro phase key set mismatch")
        if row != {
            "id": phase_id,
            "name": expected_names[phase_id],
            "gates": list(phase_gates),
        }:
            raise GateManifestError(f"v4 macro phase mismatch: {phase_id}")

    if value["ordinary_chain"] != list(V4_PHASE_IDS):
        raise GateManifestError("v4 ordinary_chain must be Q00 through Q17")
    if not str(value["linearity_invariant"] or "").startswith("STRICTLY_MONOTONE"):
        raise GateManifestError("v4 linearity_invariant mismatch")

    per_ea_terminals: list[str] = []
    ordinals = {gate.id: gate.ordinal for gate in gates}
    for gate in gates:
        expected_macro = next(
            phase_id
            for phase_id, phase_gates in V4_MACRO_PHASE_GATES.items()
            if gate.id in phase_gates
        )
        if gate.macro_phase != expected_macro:
            raise GateManifestError(f"v4 macro_phase mismatch for {gate.id}")
        if gate.next is not None and ordinals[gate.next] <= gate.ordinal:
            raise GateManifestError(f"v4 next pointer points backward for {gate.id}")
        if gate.ordinal <= 14 and gate.next is None:
            per_ea_terminals.append(gate.id)
    if per_ea_terminals != ["Q14"]:
        raise GateManifestError("v4 requires exactly one per-EA terminal gate Q14")
    if gates[14].next is not None or gates[17].next is not None:
        raise GateManifestError("v4 Q14 and Q17 must be terminal")
    if any(gate.next == "Q15" for gate in gates):
        raise GateManifestError("v4 Phase 3 entry cannot use a per-EA next edge")

    v3_gates = {gate.id: gate for gate in load_gate_manifest(V3_MANIFEST).gates}
    for row, gate in zip(value["gates"], gates):
        if row.get("v3_source") != V4_SOURCE_BY_GATE[gate.id]:
            raise GateManifestError(f"v4 v3_source mismatch for {gate.id}")
        if not str(row.get("reuse_rule") or "").strip():
            raise GateManifestError(f"v4 reuse_rule missing for {gate.id}")
        source = v3_gates.get(str(row["v3_source"]))
        # Every v4 gate whose v3_source is a real top-level v3 gate must
        # preserve that gate's stated criteria byte-for-byte (authority, runner,
        # name and evidence_role); the only tolerated change is the mechanical
        # gate-number renumber inside an evidence_role (see _v3_role_to_v4).
        # The lone documented exception is the Q09<-Q10A promotion, where the v3
        # source is a non-top-level evidence stage and thus resolves to None.
        if source is not None and (
            gate.authority != source.authority
            or gate.runner != source.runner
            or gate.name != source.name
            or gate.evidence_role != _v3_role_to_v4(source.evidence_role)
        ):
            raise GateManifestError(
                f"v4 gate criteria drift from v3 source {source.id} for {gate.id}"
            )
    q12 = value["gates"][12]
    if (
        q12.get("selection_contract") != "DL-089"
        or q12.get("pattern_filter_cap_per_direction") != 3
    ):
        raise GateManifestError("v4 Q12 must preserve the v3 DL-089 selection criteria")
    q14 = value["gates"][14]
    if (
        q14.get("terminal_optimization_gate") is not True
        or q14.get("valid_outcomes") != ["CHALLENGER_PROMOTED", "KEEP_INCUMBENT"]
    ):
        raise GateManifestError("v4 Q14 terminal outcome contract mismatch")
    if value["gates"][15].get("entry_policy") != "BOOK_TRIGGER_ONLY":
        raise GateManifestError("v4 Q15 entry must be BOOK_TRIGGER_ONLY")

    book_trigger = value["book_trigger"]
    if not isinstance(book_trigger, dict) or set(book_trigger) != {
        "policy", "entry_gate", "requires_all", "on_unmet", "supersedes"
    }:
        raise GateManifestError("v4 book_trigger key set mismatch")
    if book_trigger["policy"] != "FAIL_CLOSED" or book_trigger["entry_gate"] != "Q15":
        raise GateManifestError("v4 Phase 3 entry must use the fail-closed Q15 book trigger")
    conditions = book_trigger["requires_all"]
    if (
        not isinstance(conditions, list)
        or not all(isinstance(item, dict) for item in conditions)
        or [item.get("condition") for item in conditions] != [
            "qualified_candidates_ge_25", "owner_order_artifact_present"
        ]
    ):
        raise GateManifestError("v4 book trigger requirements mismatch")

    storage = value["storage_strategy"]
    if not isinstance(storage, dict) or set(storage) != {
        "policy", "work_items_phase", "discriminator_column",
        "dependency_role_check", "reuse_equivalence",
    }:
        raise GateManifestError("v4 storage_strategy key set mismatch")
    if storage["policy"] != "STAMP_DONT_RENAME":
        raise GateManifestError("v4 storage policy must be STAMP_DONT_RENAME")
    if any(not str(storage[key] or "").strip() for key in set(storage) - {"policy"}):
        raise GateManifestError("v4 storage strategy fields must be non-empty")

    planner = value["backfill_planner_contract"]
    planner_keys = {
        "ordering_global", "ordering_per_pair", "append_only", "dedup",
        "terminal_economic_fail", "repairable", "enqueue_binding", "progress_metric",
    }
    if not isinstance(planner, dict) or set(planner) != planner_keys:
        raise GateManifestError("v4 backfill_planner_contract key set mismatch")
    if planner["append_only"] is not True:
        raise GateManifestError("v4 backfill contract must remain append-only")

    topology = value["extension_topology"]
    if not isinstance(topology, dict) or set(topology) != {
        "removed_from_v3", "storage_lanes", "activation_guard"
    }:
        raise GateManifestError("v4 extension_topology key set mismatch")
    removed = topology["removed_from_v3"]
    if not isinstance(removed, list) or len(removed) != 4:
        raise GateManifestError("v4 removed_from_v3 contract mismatch")
    lanes = topology["storage_lanes"]
    if not isinstance(lanes, list) or len(lanes) != 2:
        raise GateManifestError("v4 requires exactly two Q15 storage lanes")
    for index, lane_id in enumerate(("Q15_DXZ", "Q15_FTMO")):
        lane = lanes[index]
        if not isinstance(lane, dict) or set(lane) != {
            "id", "parent", "authority", "runner", "evidence_role", "top_level"
        }:
            raise GateManifestError(f"v4 storage_lanes[{index}] key set mismatch")
        if (
            lane.get("id") != lane_id
            or lane.get("parent") != "Q15"
            or lane.get("authority") != "OWNER"
            or lane.get("runner") != "MANUAL_OR_ANALYTIC"
            or lane.get("top_level") is not False
            or not str(lane.get("evidence_role") or "").strip()
        ):
            raise GateManifestError(f"invalid v4 Q15 storage lane: {lane_id}")
    _validate_v4_activation_guard(topology["activation_guard"], is_default=is_default)
    return _freeze(topology)


def load_gate_manifest(path: Path = DEFAULT_MANIFEST) -> GateManifest:
    resolved_path = Path(path)
    value, raw = _load_json(resolved_path)
    try:
        is_default = resolved_path.resolve() == DEFAULT_MANIFEST.resolve()
    except OSError:
        is_default = False
    schema_version = str(value.get("schema_version") or "")
    if schema_version not in SUPPORTED_SCHEMA_VERSIONS:
        raise GateManifestError(f"unsupported schema_version: {schema_version!r}")
    expected_top = {
        "schema_version", "pipeline_version", "canonical_id_pattern", "write_policy",
        "legacy_policy", "verdict_dimensions", "gates", "legacy_aliases",
    }
    if schema_version in {SCHEMA_VERSION_V2, SCHEMA_VERSION_V3}:
        expected_top.add("extension_topology")
    elif schema_version == SCHEMA_VERSION_V4:
        expected_top |= {
            "status", "draft_note", "gate_contract_version", "macro_phases",
            "ordinary_chain", "linearity_invariant", "contract_equivalence",
            "storage_strategy", "book_trigger", "backfill_planner_contract",
            "extension_topology",
        }
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
    expected_pattern = {
        SCHEMA_VERSION_V1: r"^Q(?:0[0-9]|1[0-3])$",
        SCHEMA_VERSION_V2: r"^Q(?:0[0-9]|1[0-6])$",
        SCHEMA_VERSION_V3: r"^Q(?:0[0-9]|1[0-6])$",
        SCHEMA_VERSION_V4: r"^Q(?:0[0-9]|1[0-7])$",
    }[schema_version]
    if str(value["canonical_id_pattern"]) != expected_pattern:
        raise GateManifestError(f"{schema_version} canonical_id_pattern mismatch")

    pipeline_version = str(value["pipeline_version"])
    if not pipeline_version or pipeline_version.strip() != pipeline_version:
        raise GateManifestError("pipeline_version must be a non-empty trimmed string")

    dimensions = tuple(value["verdict_dimensions"])
    if dimensions != REQUIRED_VERDICT_DIMENSIONS:
        raise GateManifestError("verdict_dimensions must use the canonical ordered contract")

    rows = value["gates"]
    expected_ids = {
        SCHEMA_VERSION_V1: V1_PHASE_IDS,
        SCHEMA_VERSION_V2: V2_PHASE_IDS,
        SCHEMA_VERSION_V3: V2_PHASE_IDS,
        SCHEMA_VERSION_V4: V4_PHASE_IDS,
    }[schema_version]
    if not isinstance(rows, list) or len(rows) != len(expected_ids):
        raise GateManifestError(f"exactly {len(expected_ids)} gates are required")
    gates: list[Gate] = []
    ids: set[str] = set()
    for expected_ordinal, row in enumerate(rows):
        base_gate_keys = {
            "id", "ordinal", "name", "authority", "runner", "evidence_role", "next"
        }
        v4_required_gate_keys = base_gate_keys | {
            "macro_phase", "v3_source", "reuse_rule"
        }
        v4_optional_gate_keys = {
            "note", "storage_lanes", "selection_contract",
            "pattern_filter_cap_per_direction", "terminal_optimization_gate",
            "valid_outcomes", "entry_policy",
        }
        row_keys = set(row) if isinstance(row, dict) else set()
        valid_row = (
            row_keys == base_gate_keys
            if schema_version != SCHEMA_VERSION_V4
            else v4_required_gate_keys <= row_keys <= (
                v4_required_gate_keys | v4_optional_gate_keys
            )
        )
        if not isinstance(row, dict) or not valid_row:
            raise GateManifestError(f"gate[{expected_ordinal}] key set mismatch")
        gate = Gate(
            id=row["id"],
            ordinal=row["ordinal"],
            name=row["name"],
            authority=row["authority"],
            runner=row["runner"],
            evidence_role=row["evidence_role"],
            next=row["next"],
            macro_phase=row.get("macro_phase"),
        )
        if gate.ordinal != expected_ordinal:
            raise GateManifestError(f"gate ordinal mismatch at index {expected_ordinal}")
        if pattern.fullmatch(gate.id) is None or gate.id != f"Q{expected_ordinal:02d}":
            raise GateManifestError(f"invalid canonical gate id: {gate.id!r}")
        if gate.id in ids:
            raise GateManifestError(f"duplicate gate id: {gate.id}")
        if schema_version == SCHEMA_VERSION_V4:
            expected_next = (
                None
                if expected_ordinal in {14, 17}
                else f"Q{expected_ordinal + 1:02d}"
            )
        elif expected_ordinal < 13:
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
    expected_aliases = (
        REQUIRED_LEGACY_ALIASES_V4
        if schema_version == SCHEMA_VERSION_V4
        else REQUIRED_LEGACY_ALIASES
    )
    if normalized_aliases != expected_aliases:
        raise GateManifestError(
            f"legacy_aliases differ from the frozen {('v4' if schema_version == SCHEMA_VERSION_V4 else 'v1')} contract"
        )

    if schema_version == SCHEMA_VERSION_V2:
        extension_topology = _validate_v2_topology(value["extension_topology"])
    elif schema_version == SCHEMA_VERSION_V3:
        extension_topology = _validate_v3_topology(
            value["extension_topology"], is_default=is_default
        )
    elif schema_version == SCHEMA_VERSION_V4:
        if value["gate_contract_version"] != "v4":
            raise GateManifestError("v4 gate_contract_version mismatch")
        extension_topology = _validate_v4_topology(
            value, tuple(gates), is_default=is_default
        )
        guard_state = extension_topology["activation_guard"]["state"]
        expected_status = (
            "DRAFT_PROPOSAL_NOT_ACTIVATED" if guard_state == "READ_INERT" else "ACTIVE"
        )
        if value["status"] != expected_status:
            raise GateManifestError("v4 status does not match activation state")
        if not str(value["draft_note"] or "").strip():
            raise GateManifestError("v4 draft_note must be non-empty")
        contract_equivalence = _validate_v4_contract_equivalence(
            value["contract_equivalence"]
        )
    else:
        extension_topology = None
    if schema_version != SCHEMA_VERSION_V4:
        contract_equivalence = None

    return GateManifest(
        schema_version=schema_version,
        pipeline_version=pipeline_version,
        sha256=hashlib.sha256(raw).hexdigest(),
        gates=tuple(gates),
        legacy_aliases=MappingProxyType(normalized_aliases),
        verdict_dimensions=dimensions,
        extension_topology=extension_topology,
        contract_equivalence=contract_equivalence,
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


def equivalent_gate(
    gate_id: str,
    from_version: str,
    to_version: str,
    manifest: GateManifest | None = None,
) -> str:
    """Module-level versioned equivalence helper for storage/display adapters."""

    contract = manifest or load_gate_manifest(V4_DRAFT_MANIFEST)
    return contract.equivalent_gate(gate_id, from_version, to_version)
