"""Canonical, retry-stable identities for router tasks and farm work items.

The two queues use different parent columns. ``agent_tasks.parent_id`` links
agent work (for example a producer and its review), while
``work_items.parent_task_id`` normally links to the legacy bundled farm task.
Append-only work-item retries name their predecessor in
``payload_json.append_only_rerun_of_work_item``. This module keeps those
relationships explicit and never guesses that unlike parent namespaces are the
same object.
"""

from __future__ import annotations

import json
import sqlite3
from typing import Any, Mapping

try:
    from tools.strategy_farm.phase_ids import phase_qid
except ModuleNotFoundError:  # pragma: no cover - direct script import
    from phase_ids import phase_qid  # type: ignore


SCHEMA_VERSION = "qm.work_identity.v1"
_WORK_ITEM_LINK_KEYS = (
    "source_work_item_id",
    "q02_work_item_id",
    "q11_work_item_id",
    "work_item_id",
    "append_only_rerun_of_work_item",
)


def _value(row: Mapping[str, Any] | sqlite3.Row, key: str, default: Any = None) -> Any:
    try:
        value = row[key]
    except (KeyError, IndexError):
        return default
    return default if value is None else value


def _payload(row: Mapping[str, Any] | sqlite3.Row) -> dict[str, Any]:
    raw = _value(row, "payload_json", "{}")
    if isinstance(raw, dict):
        return raw
    try:
        parsed = json.loads(raw or "{}")
    except (TypeError, json.JSONDecodeError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _table_exists(conn: sqlite3.Connection, name: str) -> bool:
    return conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    ).fetchone() is not None


def _root_agent_task_id(conn: sqlite3.Connection, task_id: str) -> tuple[str, list[str]]:
    if not task_id or not _table_exists(conn, "agent_tasks"):
        return task_id, [task_id] if task_id else []
    chain: list[str] = []
    current = task_id
    while current and current not in chain:
        chain.append(current)
        row = conn.execute(
            "SELECT parent_id FROM agent_tasks WHERE id=?", (current,)
        ).fetchone()
        if row is None:
            break
        parent = str(_value(row, "parent_id", "") or "").strip()
        if not parent:
            break
        current = parent
    return chain[-1], chain


def _root_work_item_id(conn: sqlite3.Connection, work_item_id: str) -> tuple[str, list[str]]:
    if not work_item_id or not _table_exists(conn, "work_items"):
        return work_item_id, [work_item_id] if work_item_id else []
    chain: list[str] = []
    current = work_item_id
    while current and current not in chain:
        chain.append(current)
        row = conn.execute(
            "SELECT parent_task_id, payload_json FROM work_items WHERE id=?", (current,)
        ).fetchone()
        if row is None:
            break
        payload = _payload(row)
        predecessor = str(payload.get("append_only_rerun_of_work_item") or "").strip()
        if not predecessor:
            # Older retry writers used parent_task_id for the predecessor. Only
            # follow it when it resolves in the work_items namespace; ordinary
            # bundled farm-task parents deliberately remain separate.
            candidate = str(_value(row, "parent_task_id", "") or "").strip()
            if candidate and conn.execute(
                "SELECT 1 FROM work_items WHERE id=?", (candidate,)
            ).fetchone():
                predecessor = candidate
        if not predecessor:
            break
        current = predecessor
    return chain[-1], chain


def _linked_work_item_id(payload: Mapping[str, Any]) -> str | None:
    for key in _WORK_ITEM_LINK_KEYS:
        value = str(payload.get(key) or "").strip()
        if value:
            return value
    return None


def agent_task_identity(
    conn: sqlite3.Connection, row: Mapping[str, Any] | sqlite3.Row
) -> dict[str, Any]:
    """Identity for one agent task, stable across RECYCLE attempts and reviews."""
    task_id = str(_value(row, "id", "") or "")
    payload = _payload(row)
    root_task_id, agent_chain = _root_agent_task_id(conn, task_id)
    linked = _linked_work_item_id(payload)
    linked_root = None
    linked_chain: list[str] = []
    if linked:
        linked_root, linked_chain = _root_work_item_id(conn, linked)
    stable_key = (
        f"work_item:{linked_root}" if linked_root else f"agent_task:{root_task_id}"
    )
    return {
        "schema_version": SCHEMA_VERSION,
        "stable_key": stable_key,
        "entity_kind": "agent_task",
        "entity_id": task_id,
        "root_agent_task_id": root_task_id,
        "parent_agent_task_id": _value(row, "parent_id"),
        "agent_task_chain": agent_chain,
        "linked_work_item_id": linked,
        "root_work_item_id": linked_root,
        "work_item_retry_chain": linked_chain,
        "retry_ordinal": int(payload.get("recycle_count") or 0),
        "ea_id": payload.get("ea_id") or payload.get("card_id"),
    }


def work_item_identity(
    conn: sqlite3.Connection, row: Mapping[str, Any] | sqlite3.Row
) -> dict[str, Any]:
    """Identity for one farm work item, stable across append-only reruns."""
    work_item_id = str(_value(row, "id", "") or "")
    root_id, chain = _root_work_item_id(conn, work_item_id)
    phase = str(_value(row, "phase", "") or "")
    return {
        "schema_version": SCHEMA_VERSION,
        "stable_key": f"work_item:{root_id}",
        "entity_kind": "work_item",
        "entity_id": work_item_id,
        "root_work_item_id": root_id,
        "work_item_retry_chain": chain,
        "parent_farm_task_id": _value(row, "parent_task_id"),
        "ea_id": _value(row, "ea_id"),
        "symbol": _value(row, "symbol"),
        "phase_qid": phase_qid(phase) if phase else None,
        "retry_ordinal": int(_value(row, "attempt_count", 0) or 0),
    }
