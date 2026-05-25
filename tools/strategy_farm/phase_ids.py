"""Canonical phase IDs for the V5 pipeline (post-2026-05-23 rewrite).

Pre-rewrite the codebase used legacy P-keys in storage (P1..P10) with a Q-id
display map (Q00..Q14). After the 14-phase rewrite, **Qxx is canonical
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
    P5             →   Q05 Stress MEDIUM
    (P5b dropped — old "Calibrated Noise" folded into Stress)
    (P5c dropped — old "Crisis Slices" folded into Q08.10 Regime)
    (new)          →   Q06 Stress HARSH
    P6             →   Q07 Multi-Seed
    P7+P8 merged   →   Q08 Davey Statistical Validation (10 sub-gates)
    (new)          →   Q09 News Impact Mode
    (new)          →   Q10 Full-History Confirmation
    P9             →   Q11 Portfolio Construction
    P9b            →   Q12 Operational Readiness
    P10            →   Q13 Live Burn-In DXZ

The `phase_label()` and `phase_qid()` helpers stay backwards-compatible:
- pass a known Qxx → returns it unchanged
- pass a legacy P-key → returns the Qxx equivalent via LEGACY_P_TO_Q
- pass anything else → returns input unchanged (safer than raising)
"""

from __future__ import annotations

PHASE_ORDER = [
    "Q00",
    "Q01",
    "Q02",
    "Q03",
    "Q04",
    "Q05",
    "Q06",
    "Q07",
    "Q08",
    "Q09",
    "Q10",
    "Q11",
    "Q12",
    "Q13",
]

PHASE_NAME = {
    "Q00": "Research Intake",
    "Q01": "Build & Spec",
    "Q02": "Baseline Screening",
    "Q03": "Parameter Sweep",
    "Q04": "Walk-Forward + Commission",
    "Q05": "Stress MEDIUM",
    "Q06": "Stress HARSH",
    "Q07": "Multi-Seed",
    "Q08": "Davey Statistical Validation",
    "Q09": "News Impact Mode",
    "Q10": "Full-History Confirmation",
    "Q11": "Portfolio Construction",
    "Q12": "Operational Readiness",
    "Q13": "Live Burn-In DXZ",
}

# Legacy P-key → new Qxx mapping. Used only as a back-compat shim for any
# orphan call sites that still pass P-keys (old report files on disk,
# pre-rewrite test fixtures). New code never emits these keys.
LEGACY_P_TO_Q = {
    "G0":    "Q00",
    "P1":    "Q01",
    "P2":    "Q02",
    "P3":    "Q03",
    "P3.5":  "Q03",   # collapsed into Q03 (was redundant Cross-Sectional)
    "P4":    "Q04",
    "P5":    "Q05",
    "P5b":   "Q05",   # collapsed into Q05 (was Calibrated Noise)
    "P5c":   "Q05",   # collapsed into Q08.10 Regime; legacy maps to Q05 for display
    "P6":    "Q07",
    "P7":    "Q08",
    "P8":    "Q08",   # merged P7+P8 into Q08 Davey
    "P9":    "Q11",
    "P9b":   "Q12",
    "P10":   "Q13",
}

# Inverse for any code that needs to look up the dominant legacy key from
# a new Qxx (e.g. when reading old report directories on disk).
Q_TO_LEGACY_P = {
    "Q00": "G0",
    "Q01": "P1",
    "Q02": "P2",
    "Q03": "P3",
    "Q04": "P4",
    "Q05": "P5",
    "Q06": "P6",      # NEW: Stress HARSH; no legacy P-key in storage
    "Q07": "P7",
    "Q08": "P8",
    "Q09": "P9N",     # NEW: News mode; placeholder legacy key
    "Q10": "P10C",    # NEW: Full-history confirmation; placeholder
    "Q11": "P9",
    "Q12": "P9b",
    "Q13": "P10",
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
    if key in PHASE_NAME:
        return key
    return LEGACY_P_TO_Q.get(key, key)


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
