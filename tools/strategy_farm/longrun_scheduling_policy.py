"""Fleet-wide claim-selection cap for long-running terminal occupants.

Router task de0f052e-8e04-419a-bfc6-c81ff4362abf, following
docs/ops/evidence/2026-08-24_throughput_forensics.md (branch
rb-throughput-forensics, commit e88c8e9b0), recommendation 1: on a
ten-terminal fleet, cap all concurrent Q10_NEWS parents at 4, retain the
stricter expanded-parent subcap of 2, and cap concurrent Q07/Q08 long
regenerations at 2.  At least 4 terminals then remain available for ordinary
short gates/compiles instead of being occupied for hours by news rows.

Router task 427f8014-c199-4ed1-9b9a-9e56ad50b0f2 extends the original
expansion-only news cap to this combined standard-plus-expansion cap after the
2026-08-25 fleet snapshot showed seven standard news rows active at once.

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
TOTAL_NEWS_PARENT_CLASS = "total_news_parent"
Q07_Q08_LONGRUN_CLASS = "q07_q08_longrun"

EXPANDED_NEWS_PARENT_FLEET_CAP = 2
# 2026-09-04 04:00Z (CEO, Auffangregel on the News-Gate A Vorlage of 2026-09-03):
# the expansion subcap may rise to three parents, but only while the host has
# real headroom at claim time.  The gate is the caller-supplied free-RAM
# snapshot (``free_ram_gb``); with no snapshot the cap stays at 2.  Rollback:
# ``QM_DISABLE_LONGRUN_SCHEDULING_CAP=1`` disables the whole policy, or set
# EXPANDED_NEWS_PARENT_FLEET_CAP_RAM_GATED back to 2.
EXPANDED_NEWS_PARENT_FLEET_CAP_RAM_GATED = 3
EXPANDED_NEWS_PARENT_RAM_GATE_GB = 10.0
TOTAL_NEWS_PARENT_FLEET_CAP = 4
Q07_Q08_LONGRUN_FLEET_CAP = 2
# 2026-09-03 (CEO, OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903 §3
# "Recompiles zuerst"): an exact append-only lineage rerun that the
# orchestrator marked priority_track (Amendment B row) is the critical path
# to a Q10 lock.  With both Q07/Q08 slots held by multi-hour recovery
# regenerations (QM5_20085 H4, budgets 216/418 min) such a rerun waited for
# hours at claim position 2.  A lineage rerun may take ONE extra slot above
# the cap (2 -> 3); ordinary Q07/Q08 rows keep the cap of 2 and the short-flow
# reserve stays >= 3 on a ten-terminal fleet.  Bounded, selection-only.
LINEAGE_RERUN_Q07_Q08_EXTRA_SLOTS = 1
# Documents the intended outcome; not enforced directly.  The combined news
# cap and Q07/Q08 cap imply it on a ten-terminal fleet: 10 - (4 + 2) = 4.
SHORT_FLOW_RESERVE_FLOOR = 4

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


def _is_news_lane(phase: object, news_phase: str) -> bool:
    """True for the resolved news phase AND any legacy-named news lane.

    2026-09-04 (CEO): rows minted under the v3 storage name ``Q09_NEWS`` are
    still pending/active in the live DB; an exact match against the resolved
    v4 name let them bypass the news caps and the drain window.  Any
    ``*_NEWS`` lane counts as the news class.
    """
    phase_upper = str(phase or "").strip().upper()
    if phase_upper == str(news_phase or "").strip().upper():
        return True
    return phase_upper.endswith("_NEWS")


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
    if _is_news_lane(phase_upper, news_phase):
        payload_dict = _payload_dict(payload)
        if payload_dict.get("force_expanded_news_matrix") is True:
            return EXPANDED_NEWS_PARENT_CLASS
        return TOTAL_NEWS_PARENT_CLASS
    if phase_upper in (q07_phase, q08_phase):
        return Q07_Q08_LONGRUN_CLASS
    return None


def _is_priority_lineage_rerun(payload: Any) -> bool:
    """Amendment B row: exact append-only lineage rerun marked priority_track.

    Same two predicates as ``farmctl._lineage_rerun_rank_sql`` (JSON true or
    integer 1 for ``append_only_rerun``; JSON literal true for
    ``priority_track``); a quarantined lineage (poison-pill override) does not
    qualify, mirroring the claim-order key.
    """
    payload_dict = _payload_dict(payload)
    rerun = payload_dict.get("append_only_rerun")
    if rerun is not True and rerun != 1:
        return False
    if payload_dict.get("priority_track") is not True:
        return False
    if payload_dict.get("poison_pill_priority_override") == 1:
        return False
    return True


def fleet_cap_for_class(longrun_class: str) -> int:
    if longrun_class == EXPANDED_NEWS_PARENT_CLASS:
        return EXPANDED_NEWS_PARENT_FLEET_CAP
    if longrun_class == TOTAL_NEWS_PARENT_CLASS:
        return TOTAL_NEWS_PARENT_FLEET_CAP
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
    counts = {
        EXPANDED_NEWS_PARENT_CLASS: 0,
        TOTAL_NEWS_PARENT_CLASS: 0,
        Q07_Q08_LONGRUN_CLASS: 0,
    }
    rows = conn.execute(
        "SELECT phase, payload_json FROM work_items WHERE status='active' "
        "AND (phase IN (?, ?, ?) OR upper(phase) LIKE '%\\_NEWS' ESCAPE '\\')",
        (news_phase, q07_phase, q08_phase),
    ).fetchall()
    for row in rows:
        phase = row["phase"] if isinstance(row, sqlite3.Row) else row[0]
        payload_json = row["payload_json"] if isinstance(row, sqlite3.Row) else row[1]
        phase_upper = str(phase or "").strip().upper()
        if _is_news_lane(phase_upper, news_phase):
            counts[TOTAL_NEWS_PARENT_CLASS] += 1
            if _payload_dict(payload_json).get("force_expanded_news_matrix") is True:
                counts[EXPANDED_NEWS_PARENT_CLASS] += 1
            continue
        if phase_upper in (q07_phase, q08_phase):
            counts[Q07_Q08_LONGRUN_CLASS] += 1
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
    free_ram_gb: float | None = None,
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
    classes_to_check = [longrun_class]
    if longrun_class == EXPANDED_NEWS_PARENT_CLASS:
        # An expansion consumes both the two-row expansion subcap and the
        # four-row combined news cap.  Check the stricter subcap first so the
        # skip ledger preserves the most specific governing reason.
        classes_to_check.append(TOTAL_NEWS_PARENT_CLASS)
    lineage_rerun = _is_priority_lineage_rerun(payload)
    for governed_class in classes_to_check:
        cap = fleet_cap_for_class(governed_class)
        if governed_class == Q07_Q08_LONGRUN_CLASS and lineage_rerun:
            cap += LINEAGE_RERUN_Q07_Q08_EXTRA_SLOTS
        ram_gated = False
        if (
            governed_class == EXPANDED_NEWS_PARENT_CLASS
            and free_ram_gb is not None
            and float(free_ram_gb) >= EXPANDED_NEWS_PARENT_RAM_GATE_GB
        ):
            cap = max(cap, EXPANDED_NEWS_PARENT_FLEET_CAP_RAM_GATED)
            ram_gated = True
        active = active_counts.get(governed_class, 0)
        if active >= cap:
            detail = {
                "longrun_class": governed_class,
                "active_count": active,
                "fleet_cap": cap,
            }
            if ram_gated:
                detail["ram_gated_cap"] = True
                detail["free_ram_gb"] = round(float(free_ram_gb), 1)
            return True, detail
    return False, None
