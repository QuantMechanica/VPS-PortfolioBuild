"""Canonical Q-series display IDs for legacy pipeline phase keys.

Runtime storage intentionally keeps legacy keys (P3.5, P5b, ...). New
operator-facing surfaces should display only Qxx. Legacy P-keys remain DB and
report compatibility identifiers only.
"""

from __future__ import annotations

PHASE_ORDER = [
    "G0",
    "P1",
    "P2",
    "P3",
    "P3.5",
    "P4",
    "P5",
    "P5b",
    "P5c",
    "P6",
    "P7",
    "P8",
    "P9",
    "P9b",
    "P10",
]

PHASE_QID = {
    "G0": "Q00",
    "P1": "Q01",
    "P2": "Q02",
    "P3": "Q03",
    "P3.5": "Q04",
    "P4": "Q05",
    "P5": "Q06",
    "P5b": "Q07",
    "P5c": "Q08",
    "P6": "Q09",
    "P7": "Q10",
    "P8": "Q11",
    "P9": "Q12",
    "P9b": "Q13",
    "P10": "Q14",
}

QID_TO_PHASE = {v: k for k, v in PHASE_QID.items()}

PHASE_NAME = {
    "G0": "Research Intake",
    "P1": "Build Validation",
    "P2": "Baseline Screening",
    "P3": "Parameter Sweep",
    "P3.5": "Cross-Sectional Robustness",
    "P4": "Walk-Forward",
    "P5": "Stress Test",
    "P5b": "Calibrated Noise",
    "P5c": "Crisis Slices",
    "P6": "Multi-Seed",
    "P7": "Statistical Validation",
    "P8": "News Impact",
    "P9": "Portfolio Construction",
    "P9b": "Operational Readiness",
    "P10": "Live Burn-In",
}


def phase_qid(phase: str | None) -> str:
    return PHASE_QID.get(str(phase or ""), str(phase or ""))


def phase_label(phase: str | None, *, include_name: bool = False) -> str:
    key = str(phase or "")
    qid = PHASE_QID.get(key)
    if not qid:
        return key
    base = qid
    if include_name:
        name = PHASE_NAME.get(key)
        return f"{base} {name}" if name else base
    return base


def normalize_phase_id(value: str | None) -> str:
    key = str(value or "").strip()
    upper = key.upper()
    return QID_TO_PHASE.get(upper, key)
