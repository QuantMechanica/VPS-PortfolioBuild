#!/usr/bin/env python3
"""E3: a review must precede pipeline entry.

v6 E3 reads: *"Review vor Pipeline-Eintritt, generell und immer. **Jeder** Review-FAIL sperrt den
Pipeline-Eintritt, nicht nur HIGH."* The headline is the rule; the second sentence sharpens which
verdicts count.

Today ``sweep_enqueue_built_eas.py`` reads no task state at all -- ``agent_tasks``,
``review_verdict`` and ``REVIEW`` appear nowhere in it -- so review state is simply not an input to
the enqueue decision. This module supplies that input. It is an additive predicate, not a repair of
existing logic.

Two design points, both measured rather than assumed:

**It keys on task STATE, not task TYPE.** The sharpest historical case was a BLOCKED ``build_ea``
while the EA's ``review_ea`` was APPROVED; a predicate over ``review_ea`` alone would have let that
row through.

**EAs with no task history are exempt.** 3,152 of 3,696 EA directories predate the task system and
carry 1,983 live pipeline rows between them. Blocking those would not enforce a review, it would
wedge the factory -- a fail-closed gate with no operator is indistinguishable from a backlog. The
gate therefore constrains only EAs the task system actually knows about.

Measured blast radius at install time: 534 EAs blocked, of which 37 have live rows, 75 live rows
total. The narrow reading (FAIL/BLOCKED only) would block 30 rows but would NOT catch the
QM5_35xxx cohort that was leaking at the time, because no FAIL had been recorded for it yet -- the
rows were enqueued before anyone reviewed the build at all.
"""

from __future__ import annotations

import json
import re
import sqlite3
from typing import Any

SCHEMA = "qm.review-entry-gate/v1"

#: Task states that bar pipeline entry outright.
BLOCKING_STATES = frozenset({"BLOCKED", "FAILED", "RECYCLE", "OPS_FIX_REQUIRED"})
#: Task states that count as an accepted, completed review.
ACCEPTED_STATES = frozenset({"APPROVED", "PASSED"})
#: Task states that mean a review is still outstanding.
OPEN_STATES = frozenset({"REVIEW", "TODO", "IN_PROGRESS", "BACKLOG"})

GATED_TASK_TYPES = ("build_ea", "review_ea")


def _task_ea_id(payload: dict[str, Any]) -> str | None:
    """The EA a task references, normalised to the ``QM5_<num>`` work_items key.

    Mirrors ``agent_router._task_ea_id``. Payloads carry the EA as a bare integer while
    ``work_items`` keys ``QM5_<num>``; joining the two raw forms silently yields zero rows, which
    reads as "nothing to block" rather than as an error.
    """
    raw = payload.get("ea_id") or payload.get("ea_label") or payload.get("card_id")
    if not raw:
        return None
    m = re.search(r"(\d{3,6})", str(raw))
    return f"QM5_{m.group(1)}" if m else None


def _verdict_is_fail(value: Any) -> bool:
    return str(value or "").strip().upper().startswith("FAIL")


def build_index(conn: sqlite3.Connection) -> dict[str, dict[str, Any]]:
    """Return ``{ea_id: block}`` for every EA the task system knows about.

    Built once per sweep rather than queried per EA: the sweep iterates ~3,700 EA directories, and
    a per-EA query would turn one scan into thousands.

    An EA absent from the returned mapping is not gated -- either it has no task history, or its
    review is accepted.
    """
    tasks: dict[str, list[sqlite3.Row]] = {}
    marks = ",".join("?" * len(GATED_TASK_TYPES))
    for row in conn.execute(
        f"SELECT id, task_type, state, verdict, payload_json FROM agent_tasks "
        f"WHERE task_type IN ({marks})",
        GATED_TASK_TYPES,
    ):
        try:
            payload = json.loads(row["payload_json"] or "{}")
        except (ValueError, TypeError):
            payload = {}
        ea_id = _task_ea_id(payload)
        if ea_id:
            tasks.setdefault(ea_id, []).append(row)

    index: dict[str, dict[str, Any]] = {}
    for ea_id, rows in tasks.items():
        failing = [
            r for r in rows
            if str(r["state"] or "").upper() in BLOCKING_STATES or _verdict_is_fail(r["verdict"])
        ]
        if failing:
            worst = failing[0]
            index[ea_id] = {
                "gate": SCHEMA,
                "reason": "review_fail_or_blocked",
                "task_id": worst["id"],
                "task_type": worst["task_type"],
                "task_state": worst["state"],
                "verdict": str(worst["verdict"] or "")[:160],
                "failing_tasks": len(failing),
            }
            continue
        accepted = [
            r for r in rows
            if r["task_type"] == "review_ea" and str(r["state"] or "").upper() in ACCEPTED_STATES
        ]
        if accepted:
            continue
        outstanding = [r for r in rows if str(r["state"] or "").upper() in OPEN_STATES]
        index[ea_id] = {
            "gate": SCHEMA,
            "reason": "review_not_completed",
            "open_tasks": [
                {"task_id": r["id"], "task_type": r["task_type"], "state": r["state"]}
                for r in (outstanding or rows)[:4]
            ],
        }
    return index


def blocked(index: dict[str, dict[str, Any]], ea_id: str) -> dict[str, Any] | None:
    """Return the block record for ``ea_id``, or None if it may enter the pipeline."""
    return index.get(ea_id)


def summarise(index: dict[str, dict[str, Any]]) -> dict[str, int]:
    out: dict[str, int] = {}
    for block in index.values():
        out[block["reason"]] = out.get(block["reason"], 0) + 1
    out["total_blocked_eas"] = len(index)
    return out
