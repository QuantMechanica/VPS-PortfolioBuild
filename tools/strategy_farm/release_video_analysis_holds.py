#!/usr/bin/env python3
"""Release OWNER-held `video_analysis` rows back into the AI lanes.

Context: until OWNER 2026-09-09 the router held every row requiring
`video_analysis` with routing reason `awaiting_human_lane:owner` and a
`router_human_lane_hold` marker, because the only declared holder (`owner`) is
a declared-but-disabled lane. The annex to "AI Agent Routing and Role
Contracts.md" re-opened that work for the AI seats under a CAPTIONS-FIRST
contract (`agent_router.video_analysis_dispatch_contract`).

This helper does the queue half of that decision and nothing else:

  BLOCKED (+ human-lane hold) -> TODO, hold marker cleared, release recorded.

Design rules:
* DRY-RUN by default. `--apply` is the only way to write.
* `--limit N` batches the move. 420 rows dumped into the lanes at once would
  blow through the 5h/weekly windows that `quota_governor.py` / `agy_governor.py`
  pace; release in batches and let the router meter them out.
* Fail closed on the switch: `--apply` refuses while the captions-first lane is
  OFF (`agent_router.video_analysis_ai_lanes_enabled`), because releasing into
  lanes that do not declare the capability only re-holds the rows. Override with
  `--allow-switch-off` when deliberately staging a release ahead of activation.
* APPEND-ONLY journal: nothing is deleted. The previous hold marker is preserved
  inside a `video_analysis_release_journal` list on the payload, the verdict text
  is left untouched, and one `video_analysis_hold_released` event is appended per
  row.

Usage:
    python tools/strategy_farm/release_video_analysis_holds.py            # dry-run
    python tools/strategy_farm/release_video_analysis_holds.py --limit 5 --apply
"""

from __future__ import annotations

import argparse
import json
from contextlib import closing
from pathlib import Path
from typing import Any

try:
    from tools.strategy_farm import agent_router, farmctl
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    import agent_router  # type: ignore
    import farmctl  # type: ignore


RELEASE_SCHEMA = "qm.video_analysis_hold_release.v1"
RELEASE_EVENT = "video_analysis_hold_released"
RELEASE_ROUTING_REASON = "released_to_ai_lanes:video_analysis_captions_first"
SOURCE_STATE = "BLOCKED"
TARGET_STATE = "TODO"
# Cheap SQL prefilter; the real eligibility test is
# `agent_router.task_requires_video_analysis` on the parsed row.
_PREFILTER = (
    "SELECT id, state, task_type, priority, assigned_agent, "
    "required_capabilities_json, required_skills_json, payload_json, updated_at "
    "FROM agent_tasks WHERE state=? AND ("
    "required_skills_json LIKE '%video_analysis%' "
    "OR payload_json LIKE '%video_analysis%' "
    "OR payload_json LIKE '%router_human_lane_hold%') "
    "ORDER BY priority DESC, updated_at ASC"
)


def _journal(conn: Any, task_id: str, detail: dict[str, Any]) -> bool:
    """Append one release event. Never let a journal problem roll back a move.

    The payload-side `video_analysis_release_journal` is the primary, always
    written record; this is the shared `events` stream. A DB without the events
    table (a bare fixture root) degrades visibly via the returned flag instead
    of aborting a batch halfway.
    """
    try:
        farmctl.event(conn, "agent_task", task_id, RELEASE_EVENT, detail)
        return True
    except Exception:  # pragma: no cover - defensive, mirrors _record_lease_event
        return False


def _parse(raw: str | None, fallback: Any) -> Any:
    try:
        return json.loads(raw or "")
    except (TypeError, ValueError):
        return fallback


def select_candidates(
    root: Path,
    *,
    limit: int | None = None,
    task_ids: list[str] | None = None,
    state: str = SOURCE_STATE,
) -> list[dict[str, Any]]:
    """Held rows that the captions-first contract can now serve."""
    wanted = {str(task_id) for task_id in (task_ids or [])}
    candidates: list[dict[str, Any]] = []
    with closing(agent_router.connect(root)) as conn:
        rows = conn.execute(_PREFILTER, (state,)).fetchall()
    for row in rows:
        task_id = str(row["id"])
        if wanted and task_id not in wanted:
            continue
        payload = _parse(row["payload_json"], {})
        if not isinstance(payload, dict):
            payload = {}
        required = set(_parse(row["required_capabilities_json"], []) or [])
        skills = set(_parse(row["required_skills_json"], []) or [])
        if not agent_router.task_requires_video_analysis(
            required, skills=skills, payload=payload
        ):
            continue
        hold = payload.get("router_human_lane_hold")
        candidates.append(
            {
                "task_id": task_id,
                "task_type": str(row["task_type"]),
                "priority": int(row["priority"]),
                "state": str(row["state"]),
                "held_by_lane": (hold or {}).get("lane") if isinstance(hold, dict) else None,
                "hold_marker_present": isinstance(hold, dict),
                "videos": [
                    item["video_id"] for item in agent_router.extract_video_references(payload)
                ],
                "title": payload.get("title"),
                "payload": payload,
            }
        )
        if limit is not None and len(candidates) >= limit:
            break
    return candidates


def release_holds(
    root: Path = agent_router.DEFAULT_ROOT,
    *,
    apply: bool = False,
    limit: int | None = None,
    task_ids: list[str] | None = None,
    allow_switch_off: bool = False,
    state: str = SOURCE_STATE,
) -> dict[str, Any]:
    switch = agent_router.video_analysis_switch_state(root)
    candidates = select_candidates(root, limit=limit, task_ids=task_ids, state=state)
    plan = [
        {key: value for key, value in candidate.items() if key != "payload"}
        for candidate in candidates
    ]
    result: dict[str, Any] = {
        "schema": RELEASE_SCHEMA,
        "root": str(root),
        "apply": bool(apply),
        "limit": limit,
        "from_state": state,
        "to_state": TARGET_STATE,
        "routing_reason": RELEASE_ROUTING_REASON,
        "switch": switch,
        "candidate_count": len(plan),
        "candidates": plan,
        "released": 0,
        "released_task_ids": [],
    }
    if not apply:
        result["reason"] = "dry_run"
        return result
    if not switch["enabled"] and not allow_switch_off:
        result["refused"] = True
        result["reason"] = "video_analysis_ai_lanes_disabled"
        result["remedy"] = (
            f"arm the lane first ({switch['env_var']}=1 for a single command, or create "
            f"{switch['flag_path']} for the scheduled router), or pass --allow-switch-off "
            "to stage the release deliberately ahead of activation"
        )
        return result
    if not candidates:
        result["reason"] = "no_candidates"
        return result

    now = farmctl.utc_now()
    released: list[str] = []
    journal_degraded: list[str] = []
    with closing(agent_router.connect(root)) as conn:
        conn.execute("BEGIN IMMEDIATE")
        for candidate in candidates:
            payload = dict(candidate["payload"])
            previous_hold = payload.pop("router_human_lane_hold", None)
            record = {
                "schema": RELEASE_SCHEMA,
                "released_at": now,
                "from_state": state,
                "to_state": TARGET_STATE,
                "routing_reason": RELEASE_ROUTING_REASON,
                "authority": agent_router.VIDEO_ANALYSIS_AUTHORITY,
                "ai_lanes": list(agent_router.VIDEO_ANALYSIS_AI_LANES),
                "previous_hold": previous_hold,
                "switch_enabled": bool(switch["enabled"]),
                "staged_ahead_of_switch": bool(not switch["enabled"] and allow_switch_off),
            }
            journal = payload.get("video_analysis_release_journal")
            if not isinstance(journal, list):
                journal = []
            journal.append(record)
            payload["video_analysis_release_journal"] = journal
            payload["video_analysis_release"] = record
            payload["router_routing_reason"] = RELEASE_ROUTING_REASON
            # Hand the execution contract over with the release so the row is
            # never visible as an ordinary research ticket, even before the
            # router re-attaches it at dispatch time.
            payload["video_analysis_contract"] = agent_router.video_analysis_dispatch_contract(
                payload,
                task_id=candidate["task_id"],
                agent=None,
                root=root,
            )
            cur = conn.execute(
                "UPDATE agent_tasks SET state=?, assigned_agent=NULL, payload_json=?, "
                "updated_at=? WHERE id=? AND state=?",
                (
                    TARGET_STATE,
                    json.dumps(payload, sort_keys=True),
                    now,
                    candidate["task_id"],
                    state,
                ),
            )
            if cur.rowcount != 1:
                continue
            if not _journal(
                conn,
                candidate["task_id"],
                {key: value for key, value in record.items() if key != "previous_hold"},
            ):
                journal_degraded.append(candidate["task_id"])
            released.append(candidate["task_id"])
        conn.commit()
    if journal_degraded:
        result["events_journal_degraded"] = journal_degraded
    result["released"] = len(released)
    result["released_task_ids"] = released
    result["reason"] = "applied"
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=agent_router.DEFAULT_ROOT)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Perform the release (default: dry-run plan only)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Max rows to release in one batch (pace against the quota governors)",
    )
    parser.add_argument(
        "--task-id",
        action="append",
        dest="task_ids",
        help="Restrict to these exact task UUIDs (repeatable)",
    )
    parser.add_argument(
        "--state",
        default=SOURCE_STATE,
        choices=sorted(agent_router.TASK_STATES),
        help=f"Source state to release from (default: {SOURCE_STATE})",
    )
    parser.add_argument(
        "--allow-switch-off",
        action="store_true",
        help="Release even though the captions-first lane is still OFF (staging)",
    )
    args = parser.parse_args(argv)

    if args.apply:
        try:
            agent_router._require_canonical_router_command("release-video-analysis-holds")
        except agent_router.RouterCheckoutError as exc:
            print(
                json.dumps(
                    {
                        "refused": True,
                        "reason": "noncanonical_router_checkout",
                        "command": exc.command,
                        **exc.detail,
                    },
                    indent=2,
                    sort_keys=True,
                )
            )
            return 2

    result = release_holds(
        args.root,
        apply=args.apply,
        limit=args.limit,
        task_ids=args.task_ids,
        allow_switch_off=args.allow_switch_off,
        state=args.state,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 1 if result.get("refused") else 0


if __name__ == "__main__":
    raise SystemExit(main())
