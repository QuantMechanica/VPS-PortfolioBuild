"""Canonical phase IDs for the V5 pipeline (post-2026-05-23 rewrite).

Pre-rewrite the codebase used legacy P-keys in storage (P1..P10) with a Q-id
display map. After the gate rewrite, **Qxx is canonical
end-to-end** — display AND storage. The work_items wipe on 2026-05-23 cleared
the migration debt; new work_items use Qxx directly.

Mapping reference (legacy → new):

    legacy P-key   →   new Qxx
    G0             →   Q00 Research Intake
    P1             →   Q01 Build & Spec
    P2             →   Q02 Baseline Screening
    P3             →   Q03 Parameter Sweep
    (P3.5 dropped — old "Q04 Cross-Sectional Robustness" was redundant)
    P4             →   Q04 Walk-Forward + Commission
    P5             →   Q05 Gross Full-History Robustness (was "Stress MEDIUM")
    (P5b dropped — old "Calibrated Noise" folded into Stress)
    (P5c dropped — old "Crisis Slices" folded into Q08.10 Regime)
    (new)          →   Q06 Stress HARSH
    P6             →   Q07 Multi-Seed
    P7+P8 merged   →   Q08 Davey Statistical Validation (11 sub-gates)
    (new)          →   Q09 News Impact Mode
    (new)          →   Q10 Full-History Confirmation
    P9             →   Q11 Portfolio Construction
    P9b            →   Q12 Operational Readiness
    P10            →   Q13 Live Burn-In DXZ
    (opt fork)      →   Q14 Optimization Admission
    (opt fork)      →   Q15 Challenger Build & Freeze
    (opt fork)      →   Q16 Head-to-Head Requalification

The ordinary chain remains Q00→Q13. The read-inert optimization branch is
Q10→Q14→Q15→Q16→Q11; Q14 is not the successor of Q13.

The `phase_label()` and `phase_qid()` helpers stay backwards-compatible:
- pass a known Qxx → returns it unchanged
- pass a legacy P-key → returns the Qxx equivalent via LEGACY_P_TO_Q
- pass anything else → returns input unchanged (safer than raising)
"""

from __future__ import annotations

from dataclasses import dataclass
from types import MappingProxyType
from typing import Mapping

try:  # direct ``python tools/strategy_farm/<script>.py`` imports
    from gate_manifest import GateManifest, GateManifestError, equivalent_gate, load_gate_manifest
except ModuleNotFoundError:  # package imports in tests and module consumers
    from tools.strategy_farm.gate_manifest import (
        GateManifest,
        GateManifestError,
        equivalent_gate,
        load_gate_manifest,
    )


def build_phase_tables(
    manifest: GateManifest,
) -> tuple[list[str], dict[str, str], dict[str, str | None]]:
    """Build independent phase order/name/next tables from one loaded contract.

    The function is pure: it performs no manifest load and mutates neither the
    supplied immutable manifest nor the module defaults.  This lets migration
    and display code inspect the READ_INERT v4 draft explicitly while all
    existing imports continue to use the active v3 tables below.
    """

    return (
        list(manifest.phase_ids),
        dict(manifest.display_names),
        dict(manifest.next_by_phase),
    )


# Load and validate the versioned contract once at import time.  Runtime helpers
# below use these in-memory tables; hot paths never re-parse the JSON manifest.
_GATE_MANIFEST = load_gate_manifest()


def _short_contract_version(schema_version: str) -> str:
    """Return the storage stamp (``vN``) from a manifest schema version."""

    suffix = str(schema_version).rsplit("/", 1)[-1].lower()
    if not suffix.startswith("v") or not suffix[1:].isdigit():
        raise ValueError(f"invalid gate manifest schema version: {schema_version!r}")
    return suffix


ACTIVE_GATE_CONTRACT_VERSION = _short_contract_version(_GATE_MANIFEST.schema_version)

PHASE_ORDER, PHASE_NAME, PHASE_NEXT = build_phase_tables(_GATE_MANIFEST)
# Includes display-only evidence stages when the active manifest defines them.
# Such stages (v3 Q10A) are not in PHASE_ORDER and remain invalid for writes.
if _GATE_MANIFEST.extension_topology is None:
    ORDINARY_PHASE_ORDER = list(_GATE_MANIFEST.phase_ids)
    OPTIMIZATION_PHASE_ORDER: list[str] = []
else:
    ORDINARY_PHASE_ORDER = list(_GATE_MANIFEST.extension_topology["ordinary_chain"])
    OPTIMIZATION_PHASE_ORDER = list(
        _GATE_MANIFEST.extension_topology["optimization_fork"]["path"]
    )

# Legacy P-key → new Qxx mapping. Used only as a back-compat shim for any
# orphan call sites that still pass P-keys (old report files on disk,
# pre-rewrite test fixtures). New code never emits these keys.
LEGACY_P_TO_Q = dict(_GATE_MANIFEST.legacy_aliases)

# A canonical gate can have zero, one, or several legacy aliases.  Keep the
# complete inverse for UNION reads; choosing only one alias silently loses old
# P3.5/P5b/P5c/P8 rows after the collapsed rewrite.
Q_TO_LEGACY_ALIASES = {
    qid: tuple(
        alias for alias, target in LEGACY_P_TO_Q.items() if target == qid
    )
    for qid in PHASE_ORDER
}

# Compatibility for callers that truly require one legacy directory name.
# JSON insertion order is the documented primary-alias rule. Gates introduced
# by the rewrite (Q06/Q09/Q10) intentionally have no invented legacy key.
Q_TO_LEGACY_P = {
    qid: aliases[0]
    for qid, aliases in Q_TO_LEGACY_ALIASES.items()
    if aliases
}


@dataclass(frozen=True)
class PhaseAdvancement:
    """One storage token's position in the active gate topology.

    ``canonical_phase`` and ``rank`` always refer to the manifest gate.  The
    predecessor/successor fields retain storage compatibility where the runtime
    cannot write the top-level token directly (Q09) or is reading historical
    legacy-P rows.
    """

    phase: str
    canonical_phase: str
    previous: str | None
    next: str | None
    rank: int
    ordinary: bool
    legacy_alias: bool = False
    storage_lane: bool = False


_PHASE_RANK = {phase: index for index, phase in enumerate(PHASE_ORDER)}

# Q09 is a contract gate but not a writable work_items token.  NEWS is the
# mandatory lane and PORTFOLIO is a sibling informational lane.  The latter has
# the same predecessor and rank, but deliberately no successor: Q10 requires a
# CONFIG_LOCKED NEWS result and must never be licensed by portfolio evidence.
_CANONICAL_TO_PRIMARY_STORAGE = {"Q09": "Q09_NEWS"}
_STORAGE_LANE_CANONICAL = {
    "Q09_NEWS": "Q09",
    "Q09_PORTFOLIO": "Q09",
}

# Historical rows used mixed-case B/C suffixes.  Manifest aliases are compared
# case-insensitively, while returned tokens retain the bytes used in storage and
# in the legacy UNION reads.
_LEGACY_STORAGE_TOKEN = {
    alias: {"P5B": "P5b", "P5C": "P5c", "P9B": "P9b"}.get(alias, alias)
    for alias in LEGACY_P_TO_Q
}

# Alias collapse is not invertible: P3/P3.5 and P5/P5b/P5c map to the same
# canonical gates.  This is the one explicit historical storage topology.  It
# preserves the old dispatcher/cascade semantics without inventing aliases for
# gates (Q06/Q09/Q10) that never had one.
_LEGACY_STORAGE_ORDER = tuple(
    _LEGACY_STORAGE_TOKEN[alias]
    for alias in LEGACY_P_TO_Q
)
_LEGACY_PRIMARY_PATH = tuple(
    phase for phase in _LEGACY_STORAGE_ORDER if phase != "P5c"
)


def _build_advancement_table() -> Mapping[str, PhaseAdvancement]:
    table: dict[str, PhaseAdvancement] = {}
    ordinary_set = set(ORDINARY_PHASE_ORDER)
    ordinary_previous = {
        phase: (ORDINARY_PHASE_ORDER[index - 1] if index else None)
        for index, phase in enumerate(ORDINARY_PHASE_ORDER)
    }
    optimization_previous = {
        phase: (
            OPTIMIZATION_PHASE_ORDER[index - 1]
            if index
            else str(_GATE_MANIFEST.extension_topology["optimization_fork"]["from"])
        )
        for index, phase in enumerate(OPTIMIZATION_PHASE_ORDER)
    }

    # Canonical gates come directly from PHASE_NEXT.  Ordinary predecessors use
    # the declared ordinary chain so Q11 remains Q10's predecessor even though
    # the optimization fork also rejoins Q11 from Q16.
    for phase in PHASE_ORDER:
        previous = ordinary_previous.get(phase, optimization_previous.get(phase))
        if phase not in ordinary_set and phase not in optimization_previous:
            candidates = [source for source, target in PHASE_NEXT.items() if target == phase]
            previous = candidates[0] if len(candidates) == 1 else None
        previous = _CANONICAL_TO_PRIMARY_STORAGE.get(previous, previous)
        successor = PHASE_NEXT.get(phase)
        successor = _CANONICAL_TO_PRIMARY_STORAGE.get(successor, successor)
        table[phase] = PhaseAdvancement(
            phase=phase,
            canonical_phase=phase,
            previous=previous,
            next=successor,
            rank=_PHASE_RANK[phase],
            ordinary=phase in ordinary_set,
        )

    q09_canonical = _STORAGE_LANE_CANONICAL["Q09_NEWS"]
    q09_rank = _PHASE_RANK[q09_canonical]
    q09_next = PHASE_NEXT[q09_canonical]
    table["Q09_NEWS"] = PhaseAdvancement(
        phase="Q09_NEWS",
        canonical_phase=q09_canonical,
        previous=ordinary_previous[q09_canonical],
        next=q09_next,
        rank=q09_rank,
        ordinary=True,
        storage_lane=True,
    )
    table["Q09_PORTFOLIO"] = PhaseAdvancement(
        phase="Q09_PORTFOLIO",
        canonical_phase=_STORAGE_LANE_CANONICAL["Q09_PORTFOLIO"],
        previous=ordinary_previous[q09_canonical],
        next=None,
        rank=q09_rank,
        ordinary=True,
        storage_lane=True,
    )

    legacy_previous = {
        phase: (_LEGACY_PRIMARY_PATH[index - 1] if index else None)
        for index, phase in enumerate(_LEGACY_PRIMARY_PATH)
    }
    legacy_next = {
        phase: (
            _LEGACY_PRIMARY_PATH[index + 1]
            if index + 1 < len(_LEGACY_PRIMARY_PATH)
            else None
        )
        for index, phase in enumerate(_LEGACY_PRIMARY_PATH)
    }
    # P5c was a sibling evidence lane sourced from P5. It never licensed P6;
    # the required predecessor for P6 was P5b.
    legacy_previous["P5c"] = "P5"
    legacy_next["P5c"] = None
    for alias, canonical in LEGACY_P_TO_Q.items():
        phase = _LEGACY_STORAGE_TOKEN[alias]
        table[phase] = PhaseAdvancement(
            phase=phase,
            canonical_phase=canonical,
            previous=legacy_previous[phase],
            next=legacy_next[phase],
            rank=_PHASE_RANK[canonical],
            ordinary=canonical in ordinary_set,
            legacy_alias=True,
        )
    return MappingProxyType(table)


_ADVANCEMENT_TABLE = _build_advancement_table()
_ADVANCEMENT_KEY_BY_UPPER = {phase.upper(): phase for phase in _ADVANCEMENT_TABLE}

# Mandatory writable ordinary chain.  The informational Q09_PORTFOLIO sibling
# is intentionally excluded; consumers that accept it add it by selecting the
# storage_lane row from advancement_table().
ORDINARY_STORAGE_PHASE_ORDER = tuple(
    _CANONICAL_TO_PRIMARY_STORAGE.get(phase, phase)
    for phase in ORDINARY_PHASE_ORDER
)
ORDINARY_RUNTIME_PHASES = tuple(
    storage_phase
    for canonical_phase in ORDINARY_PHASE_ORDER
    for storage_phase in (
        tuple(
            row.phase
            for row in _ADVANCEMENT_TABLE.values()
            if row.storage_lane and row.canonical_phase == canonical_phase
        )
        or (canonical_phase,)
    )
)


def advancement_table() -> Mapping[str, PhaseAdvancement]:
    """Return the immutable manifest-derived runtime advancement table."""
    return _ADVANCEMENT_TABLE


def _advancement(phase: str | None) -> PhaseAdvancement | None:
    if phase is None:
        return None
    key = str(phase).strip().upper()
    storage_key = _ADVANCEMENT_KEY_BY_UPPER.get(key)
    return None if storage_key is None else _ADVANCEMENT_TABLE[storage_key]


def next_phase(phase: str | None) -> str | None:
    """Return the runtime storage successor for a canonical/lane/legacy token."""
    row = _advancement(phase)
    return None if row is None else row.next


def prev_phase(phase: str | None) -> str | None:
    """Return the runtime storage predecessor for a canonical/lane/legacy token."""
    row = _advancement(phase)
    return None if row is None else row.previous


def phase_rank(phase: str | None) -> int:
    """Return the manifest ordinal for a canonical/lane/legacy token, else -1."""
    row = _advancement(phase)
    return -1 if row is None else row.rank


def _normalise_contract_version(
    contract_version: str | None, *, strict: bool = False
) -> str | None:
    """Normalise a stored contract-version token.

    ``strict=True`` is for explicit write/validation paths and rejects an
    unrecognised token.  The default (``strict=False``) is for the display
    helpers, which promise graceful degradation and must never hard-fail on a
    typo or a future version they do not yet know: an unrecognised token is
    returned lower-cased and passed through so it can still be surfaced as raw
    provenance, and the phase itself degrades to a pass-through.
    """
    if contract_version is None:
        return None
    value = str(contract_version).strip().lower()
    if not value or value == "legacy":
        return None
    value = value.rsplit("/", 1)[-1]
    if value in {"v1", "v2", "v3", "v4"}:
        return value
    if strict:
        raise ValueError(f"unsupported gate contract version: {contract_version!r}")
    return value


def _resolve_versioned_phase(
    phase: str | None, contract_version: str | None
) -> tuple[str, str, str | None]:
    """Resolve one stored phase into active numbering plus source provenance."""

    if phase is None:
        return "", "", _normalise_contract_version(contract_version)
    source_key = str(phase).strip()
    source_id = source_key.upper()
    source_version = _normalise_contract_version(contract_version)
    if source_version is None:
        if source_id in PHASE_NAME:
            return source_id, source_id, None
        return LEGACY_P_TO_Q.get(source_id, source_key), source_id, None

    active_version = ACTIVE_GATE_CONTRACT_VERSION
    if source_version == active_version:
        return source_id, source_id, source_version

    # v1/v2 and v3 retain the same numbered storage IDs.  The v4 manifest owns
    # the only renumbering equivalence table, so pre-v3 records translate via
    # the v3 side of that explicit table rather than by ordinal guessing.
    equivalence_source = "v3" if source_version in {"v1", "v2"} else source_version
    equivalence_target = "v3" if active_version in {"v1", "v2"} else active_version
    if equivalence_source == equivalence_target:
        return source_id, source_id, source_version
    try:
        active_id = equivalent_gate(source_id, equivalence_source, equivalence_target)
    except GateManifestError:
        # Display helpers historically pass unknown utility phases through.  A
        # version stamp must not turn COMPILE_EA/HARNESS rows into exceptions.
        active_id = source_id
    return active_id, source_id, source_version


def phase_qid(phase: str | None, contract_version: str | None = None) -> str:
    """Return the canonical Qxx for a given key (Qxx or legacy P-key).

    Unknown keys pass through unchanged — phase_qid is a *display* helper,
    not a validator. Callers that need validation should check membership
    in PHASE_ORDER explicitly.
    """
    active_id, _source_id, _source_version = _resolve_versioned_phase(
        phase, contract_version
    )
    return active_id


def phase_label(
    phase: str | None,
    contract_version: str | None = None,
    *,
    include_name: bool = False,
) -> str:
    """Return the operator-facing label for a phase key.

    Always Qxx. Legacy P-keys are mapped via LEGACY_P_TO_Q. Unknown keys
    pass through unchanged (graceful degradation — preferable to a hard
    fail on a typo in a free-text reason string).
    """
    qid, source_id, source_version = _resolve_versioned_phase(phase, contract_version)
    label = qid
    if include_name:
        name = PHASE_NAME.get(qid)
        if name:
            label = f"{qid} {name}"
    if source_version is not None and (
        source_version != ACTIVE_GATE_CONTRACT_VERSION or source_id != qid
    ):
        label += f" ({source_version}:{source_id})"
    return label


def display_phase(
    phase: str | None,
    contract_version: str | None,
    *,
    include_name: bool = False,
) -> str:
    """Render active numbering and retain an explicit historical provenance."""

    return phase_label(
        phase,
        contract_version,
        include_name=include_name,
    )


def next_phase_id(phase: str | None) -> str | None:
    """Return the manifest-declared successor, preserving the Q10 fork shape."""
    qid = phase_qid(phase)
    return PHASE_NEXT.get(qid)


def normalize_phase_id(
    value: str | None, contract_version: str | None = None
) -> str:
    """Normalize any input (Qxx, legacy P-key, lowercase, whitespace) to the
    canonical Qxx storage key. Used by readers ingesting external data.
    """
    if contract_version is None:
        if value is None:
            return ""
        upper = str(value).strip().upper()
        if upper in PHASE_NAME:
            return upper
        return LEGACY_P_TO_Q.get(upper, upper)
    active_id, _source_id, _source_version = _resolve_versioned_phase(value, contract_version)
    return active_id
