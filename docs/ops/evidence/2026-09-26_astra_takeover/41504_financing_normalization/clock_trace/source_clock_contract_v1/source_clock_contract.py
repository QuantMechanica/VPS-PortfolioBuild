"""Source-clock / destination-rollover contract V1 (DRAFT reference implementation).

Standalone module. Not imported by any production pipeline code. See
SOURCE_CLOCK_CONTRACT_V1.md in this directory for the full rationale and the
primary-source evidence this seed table is derived from.

This module NEVER guesses a clock mapping. `require_authenticated` raises
`ClockContractRefusal` for every source/window that is not explicitly seeded
as AUTHENTICATED_UTC with a dated offset table. As of this draft, no source
in the repository qualifies -- that is the correct, honest state.
"""

from __future__ import annotations

import datetime as dt
import enum
from dataclasses import dataclass, field


class ClockState(enum.Enum):
    UNKNOWN = "UNKNOWN"
    NATIVE_LABEL_PARITY_ONLY = "NATIVE_LABEL_PARITY_ONLY"
    CANDIDATE_OFFSET_UNAUTHENTICATED = "CANDIDATE_OFFSET_UNAUTHENTICATED"
    REFUTED = "REFUTED"
    AUTHENTICATED_UTC = "AUTHENTICATED_UTC"


class RolloverRole(enum.Enum):
    SWAP_PLATFORM_MIDNIGHT = "SWAP_PLATFORM_MIDNIGHT"
    DAILY_LOSS_RESET = "DAILY_LOSS_RESET"


class ClockContractRefusal(Exception):
    """Raised when a consumer requests a clock/rollover operation on a
    source/window that is not AUTHENTICATED_UTC with a dated offset table."""


@dataclass(frozen=True)
class OffsetTransition:
    """A single dated transition of a platform's UTC offset, in hours."""

    effective_from_utc: dt.datetime
    offset_hours: float


@dataclass(frozen=True)
class ClockRecord:
    source_id: str
    window_start: dt.date
    window_end: dt.date
    state: ClockState
    evidence_paths: tuple[tuple[str, str], ...] = field(default_factory=tuple)
    offset_table: tuple[OffsetTransition, ...] | None = None


def _within(window: tuple[dt.date, dt.date], record: ClockRecord) -> bool:
    start, end = window
    return not (end < record.window_start or start > record.window_end)


# --- Seed table -------------------------------------------------------
# Every row below is a restatement of a fact already established and cited
# in SOURCE_CLOCK_CONTRACT_V1.md. Do not add a row without an evidence_paths
# entry pointing at a committed artifact.

SEED_RECORDS: tuple[ClockRecord, ...] = (
    ClockRecord(
        source_id="10403:XAUUSD.DWX",
        window_start=dt.date(2017, 8, 1),
        window_end=dt.date(2025, 11, 21),
        state=ClockState.NATIVE_LABEL_PARITY_ONLY,
        evidence_paths=(
            (
                "docs/ops/evidence/2026-09-26_astra_takeover/41504_financing_normalization/"
                "clock_trace/NATIVE_CLOCK_RESULT_10403.json",
                "d995c673d40ce935adead12942105c7dae876554adaf8a42a85044a4bfc97ed3",
            ),
        ),
    ),
    ClockRecord(
        source_id="FTMO_MT5_PLATFORM:Europe/Bucharest_generic_EU_DST",
        window_start=dt.date(2023, 3, 12),
        window_end=dt.date(2023, 3, 26),
        state=ClockState.REFUTED,
        evidence_paths=(
            (
                "docs/ops/evidence/2026-09-26_astra_takeover/41504_financing_normalization/"
                "clock_trace/VENUE_CLOCK_OBSERVATIONS.json",
                "3eb98d6133222cff2838c21619962d99687fcdeff7910f415fc78fb78771f61e",
            ),
        ),
    ),
    ClockRecord(
        source_id="FTMO_MT5_PLATFORM:Europe/Bucharest_generic_EU_DST",
        window_start=dt.date(2024, 10, 27),
        window_end=dt.date(2024, 11, 3),
        state=ClockState.REFUTED,
        evidence_paths=(
            (
                "docs/ops/evidence/2026-09-26_astra_takeover/41504_financing_normalization/"
                "clock_trace/VENUE_CLOCK_OBSERVATIONS.json",
                "3eb98d6133222cff2838c21619962d99687fcdeff7910f415fc78fb78771f61e",
            ),
        ),
    ),
    ClockRecord(
        source_id="10403:XAUUSD.DWX:NY_close_US_DST_candidate",
        window_start=dt.date(2017, 8, 1),
        window_end=dt.date(2025, 11, 21),
        state=ClockState.CANDIDATE_OFFSET_UNAUTHENTICATED,
        evidence_paths=(
            (
                "docs/ops/evidence/2026-09-26_astra_takeover/41504_financing_normalization/"
                "clock_trace/CONDITIONAL_DST_EXPOSURE_10403.json",
                "5c7ed89509104f0366fb52e0ce927864f05e1a61e9a170879e4ec8be7be28312",
            ),
        ),
    ),
)


def classify(source_id: str, window: tuple[dt.date, dt.date]) -> ClockState:
    """Return the most restrictive known state overlapping this window.

    If no seed record overlaps, returns UNKNOWN. If multiple overlapping
    records disagree, returns the most restrictive (REFUTED > UNKNOWN >
    NATIVE_LABEL_PARITY_ONLY > CANDIDATE_OFFSET_UNAUTHENTICATED >
    AUTHENTICATED_UTC) -- i.e. never silently pick the more permissive one.
    """
    restrictiveness = {
        ClockState.REFUTED: 0,
        ClockState.UNKNOWN: 1,
        ClockState.NATIVE_LABEL_PARITY_ONLY: 2,
        ClockState.CANDIDATE_OFFSET_UNAUTHENTICATED: 3,
        ClockState.AUTHENTICATED_UTC: 4,
    }
    matches = [r for r in SEED_RECORDS if r.source_id == source_id and _within(window, r)]
    if not matches:
        return ClockState.UNKNOWN
    return min((r.state for r in matches), key=lambda s: restrictiveness[s])


def require_authenticated(
    source_id: str,
    window: tuple[dt.date, dt.date],
    rollover_role: RolloverRole,
) -> tuple[OffsetTransition, ...]:
    """Fail-closed gate. Raises ClockContractRefusal unless the source/window
    is AUTHENTICATED_UTC with a populated dated offset table. `rollover_role`
    is required and is never defaulted -- callers must state whether they are
    computing swap/platform-midnight or daily-loss-reset boundaries, because
    this contract does not assume those two clocks coincide.
    """
    if not isinstance(rollover_role, RolloverRole):
        raise ClockContractRefusal(f"rollover_role must be explicit, got {rollover_role!r}")

    matches = [
        r
        for r in SEED_RECORDS
        if r.source_id == source_id
        and _within(window, r)
        and r.state == ClockState.AUTHENTICATED_UTC
        and r.offset_table
    ]
    if not matches:
        state = classify(source_id, window)
        raise ClockContractRefusal(
            f"refusing {source_id} window {window} for {rollover_role.value}: "
            f"state={state.value}, not AUTHENTICATED_UTC with a dated offset table"
        )
    return matches[0].offset_table
