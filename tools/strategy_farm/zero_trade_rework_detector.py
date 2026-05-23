#!/usr/bin/env python3
"""Detect DL-062 zero-trade rework candidates from work_items.

The scanner is pure SQL/Python aggregation. It never mutates work_items; the
optional enqueue helper writes only agent_tasks and is idempotent over 24h.
"""

from __future__ import annotations

import datetime as dt
import json
import sqlite3
from pathlib import Path
from typing import Any

try:
    from tools.strategy_farm import agent_router, farmctl
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    import agent_router  # type: ignore
    import farmctl  # type: ignore


PHASE_ORDER = ["P2", "P3", "P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8"]
MIN_COMPLETED_RUNS = 10
MIN_ZERO_TRADE_FAIL_PCT = 0.80
DEDUP_HOURS = 24


def _loads(raw: str | None) -> dict[str, Any]:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def _trade_count_from_payload(payload: dict[str, Any]) -> int | None:
    keys = ("trade_count", "total_trades", "trades")
    stack: list[Any] = [payload]
    while stack:
        cur = stack.pop()
        if isinstance(cur, dict):
            for key in keys:
                val = cur.get(key)
                if isinstance(val, bool):
                    continue
                if isinstance(val, (int, float)):
                    return int(val)
                if isinstance(val, str) and val.strip().isdigit():
                    return int(val.strip())
            stack.extend(cur.values())
        elif isinstance(cur, list):
            stack.extend(cur)
    return None


def _is_zero_trade_fail(row: sqlite3.Row) -> bool:
    if str(row["verdict"] or "").upper() != "FAIL":
        return False
    payload = _loads(row["payload_json"])
    trade_count = _trade_count_from_payload(payload)
    if trade_count == 0:
        return True
    payload_text = row["payload_json"] or ""
    if "MIN_TRADES_NOT_MET" in payload_text:
        return True
    evidence_path = str(row["evidence_path"] or "")
    if not evidence_path:
        return False
    try:
        p = Path(evidence_path)
        if not p.exists() or p.stat().st_size <= 0:
            return False
        text = p.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return False
    if "MIN_TRADES_NOT_MET" in text:
        return True
    evidence_payload = _loads(text)
    return _trade_count_from_payload(evidence_payload) == 0


def _slug_for_ea(ea_id: str, rows: list[sqlite3.Row]) -> str:
    for row in rows:
        payload = _loads(row["payload_json"])
        slug = payload.get("slug") or payload.get("ea_slug")
        if slug:
            return str(slug)
    return ea_id


def scan_for_rework_candidates(db_path: str | Path) -> list[dict[str, Any]]:
    """Return DL-062 candidate EAs without mutating the database."""
    path = Path(db_path)
    if not path.exists():
        return []
    with sqlite3.connect(path) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            """
            SELECT ea_id, phase, status, verdict, payload_json, evidence_path
            FROM work_items
            WHERE ea_id IS NOT NULL
              AND phase IN ('P2','P3','P3.5','P4','P5','P5b','P5c','P6','P7','P8')
              AND status IN ('done','failed')
            """
        ).fetchall()

    grouped: dict[str, list[sqlite3.Row]] = {}
    for row in rows:
        grouped.setdefault(str(row["ea_id"]), []).append(row)

    candidates: list[dict[str, Any]] = []
    for ea_id, ea_rows in sorted(grouped.items()):
        completed = len(ea_rows)
        if completed < MIN_COMPLETED_RUNS:
            continue
        pass_count = sum(1 for r in ea_rows if str(r["verdict"] or "").upper() == "PASS")
        if pass_count:
            continue
        fail_rows = [r for r in ea_rows if str(r["verdict"] or "").upper() == "FAIL"]
        if not fail_rows:
            continue
        zero_trade_fails = sum(1 for r in fail_rows if _is_zero_trade_fail(r))
        zero_trade_pct = zero_trade_fails / len(fail_rows)
        if zero_trade_pct < MIN_ZERO_TRADE_FAIL_PCT:
            continue
        candidates.append(
            {
                "ea_id": ea_id,
                "slug": _slug_for_ea(ea_id, ea_rows),
                "completed_count": completed,
                "fail_count": len(fail_rows),
                "zero_trade_fail_count": zero_trade_fails,
                "zero_trade_pct": zero_trade_pct,
                "recommended_change_vector_hint": (
                    "inspect card/source for entry-condition relaxation or signal-logic substitution"
                ),
            }
        )
    return candidates


def _recent_agent_task_exists(conn: sqlite3.Connection, ea_id: str, now: dt.datetime) -> bool:
    cutoff = (now - dt.timedelta(hours=DEDUP_HOURS)).replace(microsecond=0).isoformat()
    rows = conn.execute(
        """
        SELECT payload_json, created_at
        FROM agent_tasks
        WHERE task_type='research_strategy'
          AND created_at >= ?
        """,
        (cutoff,),
    ).fetchall()
    needle = f'"rework_target":"{ea_id}"'
    needle_spaced = f'"rework_target": "{ea_id}"'
    for row in rows:
        payload_json = row["payload_json"] or ""
        if needle in payload_json or needle_spaced in payload_json:
            return True
    return False


def enqueue_rework_tasks(root: Path = farmctl.DEFAULT_ROOT) -> dict[str, Any]:
    """Scan and enqueue research_strategy agent_tasks for fresh candidates."""
    db_path = root / "state" / "farm_state.sqlite"
    candidates = scan_for_rework_candidates(db_path)
    enqueued: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    now = dt.datetime.now(dt.UTC).replace(microsecond=0)
    with agent_router.connect(root) as conn:
        for candidate in candidates:
            ea_id = str(candidate["ea_id"])
            if _recent_agent_task_exists(conn, ea_id, now):
                skipped.append({"ea_id": ea_id, "reason": "recent_agent_task_exists"})
                continue
            parent_card = root / "artifacts" / "cards_approved"
            matches = sorted(parent_card.glob(f"{ea_id}_*.md")) if parent_card.exists() else []
            payload = {
                "reason": "DL-062_zero_trade_rework_trigger",
                "rework_target": ea_id,
                "parent_card_path": str(matches[0]) if matches else "",
                "candidate": candidate,
            }
            task = agent_router.enqueue_task(
                root,
                "research_strategy",
                state="TODO",
                priority=70,
                required_capabilities=["research", "strategy"],
                required_skills=["research", "sql", "strategy"],
                payload=payload,
            )
            enqueued.append({**task, "ea_id": ea_id})
    return {"candidates": candidates, "enqueued": enqueued, "skipped": skipped}


__all__ = ["scan_for_rework_candidates", "enqueue_rework_tasks"]
