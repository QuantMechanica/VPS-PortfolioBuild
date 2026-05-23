"""One-shot task-state watch notifier.

This is a generic successor to one-off "ping me when X is ready" scripts. A
watch group fires only after every configured agent_task reaches its target
state or a later terminal/review state, then writes a sentinel before sending
mail so pump retries cannot spam OWNER.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import sqlite3
from pathlib import Path
from typing import Any, Callable


SENTINEL_REL = Path("state") / "task_watch_notifier.json"

STATE_ORDER = {
    "BACKLOG": 10,
    "TODO": 20,
    "IN_PROGRESS": 30,
    "REVIEW": 40,
    "APPROVED": 50,
    "PIPELINE": 60,
    "PASSED": 70,
    "FAILED": 70,
    "RECYCLE": 70,
    "OPS_FIX_REQUIRED": 70,
    "BLOCKED": 70,
    "SELF_LEARNING": 5,
}

DEFAULT_WATCH_GROUPS: list[dict[str, Any]] = [
    {
        "id": "ws2_ws4_review_2026_05_22",
        "subject": "QM task watch: WS-2 and WS-4 reached REVIEW",
        "description": "OWNER one-shot watch for WS-2 verdict taxonomy and WS-4 basket wiring review readiness.",
        "tasks": [
            {"id": "6d365393-9a2a-4784-aa60-ba519365e5b3", "target_state": "REVIEW", "label": "WS-2 verdict taxonomy"},
            {"id": "d6e2f4d9-8351-4503-9f83-b33770095841", "target_state": "REVIEW", "label": "WS-4 basket wiring"},
        ],
    },
    {
        "id": "edge_lab_d1_build_review_2026_05_22",
        "subject": "QM task watch: Edge Lab D1 build reached REVIEW",
        "description": "OWNER one-shot watch for the Edge Lab Direction 1 EA build follow-up review readiness.",
        "tasks": [
            {
                "id": "fccb8155-cdb2-4ca9-822c-15d209cced05",
                "target_state": "REVIEW",
                "label": "Edge Lab D1 EA build follow-up",
            },
        ],
    }
]


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def _db_path(root: Path) -> Path:
    return root / "state" / "farm_state.sqlite"


def _write_json_atomic(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    tmp.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)


def _read_sentinel(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"groups": {}}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {"groups": {}, "unreadable_previous_sentinel": str(path)}
    if not isinstance(payload, dict):
        return {"groups": {}, "invalid_previous_sentinel": str(path)}
    payload.setdefault("groups", {})
    return payload


def _default_send_mail(subject: str, body: str) -> dict[str, Any]:
    try:
        from gmail_alarm import _send_mail
    except ModuleNotFoundError:
        from tools.strategy_farm.gmail_alarm import _send_mail
    return _send_mail(subject, body)


def _state_reached(current: str | None, target: str) -> bool:
    if not current:
        return False
    return STATE_ORDER.get(current, -1) >= STATE_ORDER.get(target, 10_000)


def _load_task_rows(root: Path, task_ids: list[str]) -> dict[str, dict[str, Any]]:
    if not task_ids or not _db_path(root).exists():
        return {}
    placeholders = ",".join("?" for _ in task_ids)
    con = sqlite3.connect(_db_path(root), timeout=30)
    con.row_factory = sqlite3.Row
    try:
        rows = con.execute(
            f"""
            SELECT id, task_type, state, assigned_agent, artifact_path, verdict, updated_at
            FROM agent_tasks
            WHERE id IN ({placeholders})
            """,
            task_ids,
        ).fetchall()
    finally:
        con.close()
    return {str(row["id"]): dict(row) for row in rows}


def _group_status(root: Path, group: dict[str, Any]) -> dict[str, Any]:
    watches = list(group.get("tasks") or [])
    rows = _load_task_rows(root, [str(w["id"]) for w in watches])
    task_statuses: list[dict[str, Any]] = []
    ready = True
    for watch in watches:
        task_id = str(watch["id"])
        target = str(watch.get("target_state") or "REVIEW")
        row = rows.get(task_id)
        reached = _state_reached(row.get("state") if row else None, target)
        ready = ready and reached
        task_statuses.append(
            {
                "id": task_id,
                "label": watch.get("label") or task_id,
                "target_state": target,
                "current_state": row.get("state") if row else None,
                "reached": reached,
                "task": row,
            }
        )
    return {"ready": ready and bool(watches), "tasks": task_statuses}


def check_and_notify(
    root: Path,
    *,
    watch_groups: list[dict[str, Any]] | None = None,
    send_mail: Callable[[str, str], dict[str, Any]] | None = None,
) -> dict[str, Any]:
    sentinel = root / SENTINEL_REL
    state = _read_sentinel(sentinel)
    groups_done: dict[str, Any] = dict(state.get("groups") or {})
    results: list[dict[str, Any]] = []
    triggered: list[dict[str, Any]] = []

    for group in watch_groups or DEFAULT_WATCH_GROUPS:
        group_id = str(group["id"])
        if group_id in groups_done:
            results.append({"id": group_id, "triggered": False, "reason": "already_disarmed"})
            continue
        status = _group_status(root, group)
        if not status["ready"]:
            results.append({"id": group_id, "triggered": False, "reason": "targets_not_reached", "status": status})
            continue

        subject = str(group.get("subject") or f"QM task watch ready: {group_id}")
        lines = [str(group.get("description") or subject), "", "Watched tasks:"]
        for task in status["tasks"]:
            row = task.get("task") or {}
            lines.append(
                f"- {task['label']}: {task['id']} state={task['current_state']} "
                f"verdict={row.get('verdict') or ''} artifact={row.get('artifact_path') or ''}"
            )
        body = "\n".join(lines) + "\n"

        groups_done[group_id] = {
            "disarmed_at": _utc_now(),
            "subject": subject,
            "status": status,
            "mail_result": {"sent": False, "reason": "not attempted"},
        }
        state["groups"] = groups_done
        _write_json_atomic(sentinel, state)

        sender = send_mail or _default_send_mail
        mail_result = sender(subject, body)
        groups_done[group_id]["mail_attempted_at"] = _utc_now()
        groups_done[group_id]["mail_result"] = mail_result
        state["groups"] = groups_done
        _write_json_atomic(sentinel, state)
        item = {"id": group_id, "triggered": True, "sentinel": str(sentinel), "mail_result": mail_result}
        results.append(item)
        triggered.append(item)

    return {"triggered": bool(triggered), "groups": results, "sentinel": str(sentinel)}
