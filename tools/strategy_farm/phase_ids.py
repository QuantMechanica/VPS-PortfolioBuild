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

try:  # direct ``python tools/strategy_farm/<script>.py`` imports
    from gate_manifest import load_gate_manifest
except ModuleNotFoundError:  # package imports in tests and module consumers
    from tools.strategy_farm.gate_manifest import load_gate_manifest


# Load and validate the versioned contract once at import time.  Runtime helpers
# below use these in-memory tables; hot paths never re-parse the JSON manifest.
_GATE_MANIFEST = load_gate_manifest()

PHASE_ORDER = list(_GATE_MANIFEST.phase_ids)
PHASE_NAME = _GATE_MANIFEST.names
PHASE_NEXT = _GATE_MANIFEST.next_by_phase
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


def phase_qid(phase: str | None) -> str:
    """Return the canonical Qxx for a given key (Qxx or legacy P-key).

    Unknown keys pass through unchanged — phase_qid is a *display* helper,
    not a validator. Callers that need validation should check membership
    in PHASE_ORDER explicitly.
    """
    if phase is None:
        return ""
    key = str(phase)
    upper = key.upper()
    if upper in PHASE_NAME:
        return upper
    return LEGACY_P_TO_Q.get(upper, key)


def phase_label(phase: str | None, *, include_name: bool = False) -> str:
    """Return the operator-facing label for a phase key.

    Always Qxx. Legacy P-keys are mapped via LEGACY_P_TO_Q. Unknown keys
    pass through unchanged (graceful degradation — preferable to a hard
    fail on a typo in a free-text reason string).
    """
    qid = phase_qid(phase)
    if include_name:
        name = PHASE_NAME.get(qid)
        if name:
            return f"{qid} {name}"
    return qid


def next_phase_id(phase: str | None) -> str | None:
    """Return the manifest-declared successor, preserving the Q10 fork shape."""
    qid = phase_qid(phase)
    return PHASE_NEXT.get(qid)


def normalize_phase_id(value: str | None) -> str:
    """Normalize any input (Qxx, legacy P-key, lowercase, whitespace) to the
    canonical Qxx storage key. Used by readers ingesting external data.
    """
    if value is None:
        return ""
    key = str(value).strip()
    upper = key.upper()
    if upper in PHASE_NAME:
        return upper
    return LEGACY_P_TO_Q.get(upper, upper)
