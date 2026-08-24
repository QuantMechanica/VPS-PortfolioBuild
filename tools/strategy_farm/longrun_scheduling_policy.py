"""Fleet-wide claim-selection cap for long-running terminal occupants.

Router task de0f052e-8e04-419a-bfc6-c81ff4362abf, following
docs/ops/evidence/2026-08-24_throughput_forensics.md (branch
rb-throughput-forensics, commit e88c8e9b0), recommendation 1: on a
ten-terminal fleet, cap concurrent 29-cell expanded Q10_NEWS parents at 2 and
concurrent Q07/Q08 long regenerations at 2, so at least 6 terminals stay
available for ordinary short gates/compiles instead of being occupied for
hours by a handful of long-running rows.

This module is claim-selection ONLY: it decides which pending row a free
terminal is allowed to claim next. It never touches gate criteria, verdict
logic, or deletes/overwrites any row — a skipped candidate simply stays
`pending` and is reconsidered on the next claim attempt (by this or another
terminal) once fleet occupancy drops.
"""

from __future__ import annotations

import json
import os
import sqlite3
from typing import Any

EXPANDED_NEWS_PARENT_CLASS = "expanded_news_parent"
Q07_Q08_LONGRUN_CLASS = "q07_q08_longrun"

EXPANDED_NEWS_PARENT_FLEET_CAP = 2
Q07_Q08_LONGRUN_FLEET_CAP = 2
# Documents the intended outcome; not enforced directly (it falls out of the
# two caps above given a 10-terminal fleet: 10 - (2 + 2) = 6).
SHORT_FLOW_RESERVE_FLOOR = 6

# Rollback switch (Konfig-Flag): set to "1" to disable this policy entirely
# and fall back to the pre-existing unconstrained claim order. Same
# convention as QM_ENABLE_GEMINI_BUILDS / QM_ALLOW_NONCANONICAL.
DISABLE_ENV_VAR = "QM_DISABLE_LONGRUN_SCHEDULING_CAP"


def policy_enabled() -> bool:
    return os.environ.get(DISABLE_ENV_VAR) != "1"


def _payload_dict(payload_json: Any) -> dict[str, Any]:
    if isinstance(payload_json, dict):
        return payload_json
    try:
        parsed = json.loads(payload_json or "{}")
    except (TypeError, ValueError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def classify_longrun_candidate(
    phase: object,
    payload: Any,
    *,
    news_phase: str,
    q07_phase: str = "Q07",
    q08_phase: str = "Q08",
) -> str | None:
    """Return the long-run class for a candidate row, or None for ordinary work.

    `news_phase` must be the caller's resolved news-gate storage phase (e.g.
    `terminal_worker._Q09_NEWS_PHASE`) so this stays correct across gate
    renumbering instead of hardcoding a Qxx literal for the news role.
    """
    phase_upper = str(phase or "").strip().upper()
    if phase_upper == str(news_phase or "").strip().upper():
        payload_dict = _payload_dict(payload)
        if payload_dict.get("force_expanded_news_matrix") is True:
            return EXPANDED_NEWS_PARENT_CLASS
        return None
    if phase_upper in (q07_phase, q08_phase):
        return Q07_Q08_LONGRUN_CLASS
    return None


def fleet_cap_for_class(longrun_class: str) -> int:
    if longrun_class == EXPANDED_NEWS_PARENT_CLASS:
        return EXPANDED_NEWS_PARENT_FLEET_CAP
    if longrun_class == Q07_Q08_LONGRUN_CLASS:
        return Q07_Q08_LONGRUN_FLEET_CAP
    raise ValueError(f"unknown longrun class: {longrun_class!r}")


def active_longrun_counts(
    conn: sqlite3.Connection,
    *,
    news_phase: str,
    q07_phase: str = "Q07",
    q08_phase: str = "Q08",
) -> dict[str, int]:
    """Fleet-wide count of currently `active` claims per long-run class.

    Must be read inside the same transaction as the claim decision (the
    caller already holds `BEGIN IMMEDIATE` in `terminal_worker.claim_atomic`)
    so the count is consistent with the eventual claim commit.
    """
    counts = {EXPANDED_NEWS_PARENT_CLASS: 0, Q07_Q08_LONGRUN_CLASS: 0}
    rows = conn.execute(
        "SELECT phase, payload_json FROM work_items WHERE status='active' "
        "AND phase IN (?, ?, ?)",
        (news_phase, q07_phase, q08_phase),
    ).fetchall()
    for row in rows:
        phase = row["phase"] if isinstance(row, sqlite3.Row) else row[0]
        payload_json = row["payload_json"] if isinstance(row, sqlite3.Row) else row[1]
        longrun_class = classify_longrun_candidate(
            phase, payload_json, news_phase=news_phase, q07_phase=q07_phase, q08_phase=q08_phase
        )
        if longrun_class is not None:
            counts[longrun_class] += 1
    return counts


def should_skip_for_longrun_cap(
    phase: object,
    payload: Any,
    active_counts: dict[str, int],
    *,
    news_phase: str,
    q07_phase: str = "Q07",
    q08_phase: str = "Q08",
    enabled: bool = True,
) -> tuple[bool, dict[str, Any] | None]:
    """Decide whether a candidate row must be skipped this claim attempt.

    Returns (skip, detail). `detail` is populated only when skipping, for the
    caller's existing skip-ledger convention (skipped_history,
    skipped_launch_cooldown, ...).
    """
    if not enabled:
        return False, None
    longrun_class = classify_longrun_candidate(
        phase, payload, news_phase=news_phase, q07_phase=q07_phase, q08_phase=q08_phase
    )
    if longrun_class is None:
        return False, None
    cap = fleet_cap_for_class(longrun_class)
    active = active_counts.get(longrun_class, 0)
    if active < cap:
        return False, None
    return True, {
        "longrun_class": longrun_class,
        "active_count": active,
        "fleet_cap": cap,
    }
