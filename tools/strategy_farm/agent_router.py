#!/usr/bin/env python3
"""Deterministic capability router for strategy-farm agent work.

This module is intentionally not an AI orchestrator. It owns the ticket state
machine and chooses an available worker from declared capabilities, budgets,
and guardrails. Agents execute assigned tickets and write artifacts; the QM
pipeline remains the approval authority for EAs.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import uuid
from contextlib import closing
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    from tools.strategy_farm import farmctl
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    import farmctl  # type: ignore


DEFAULT_ROOT = farmctl.DEFAULT_ROOT
CLAUDE_DISABLED_FLAG = Path(r"D:\QM\strategy_farm\CLAUDE_DISABLED.flag")

TASK_STATES = {
    "BACKLOG",
    "TODO",
    "IN_PROGRESS",
    "REVIEW",
    "APPROVED",
    "PIPELINE",
    "PASSED",
    "FAILED",
    "RECYCLE",
    "OPS_FIX_REQUIRED",
    "BLOCKED",
}

TASK_TYPE_CAPABILITIES: dict[str, list[str]] = {
    "research_strategy": ["research", "strategy"],
    "review_strategy": ["review", "strategy"],
    "build_ea": ["code"],
    "review_ea": ["review", "code"],
    "pipeline_run": ["pipeline"],
    "triage_failure": ["ops", "review"],
    "ops_issue": ["ops", "code"],
}

DEFAULT_AGENT_REGISTRY: dict[str, dict[str, Any]] = {
    "codex": {
        "enabled": True,
        "capabilities": ["code", "tests", "repo_edit", "review", "ops", "research", "strategy"],
        "max_parallel": 3,
        "cost_rank": 20,
    },
    "claude": {
        "enabled": True,
        "capabilities": ["research", "review", "strategy", "summary"],
        "max_parallel": 1,
        "cost_rank": 30,
    },
    "gemini": {
        "enabled": True,
        "capabilities": ["research", "strategy", "source_discovery"],
        "max_parallel": 2,
        "cost_rank": 10,
    },
}


@dataclass(frozen=True)
class RouteDecision:
    task_id: str
    task_type: str
    assigned_agent: str | None
    reason: str


def _json(data: Any) -> str:
    return json.dumps(data, sort_keys=True, separators=(",", ":"))


def connect(root: Path = DEFAULT_ROOT) -> sqlite3.Connection:
    farmctl.init_dirs(root)
    conn = farmctl.connect(root)
    init_schema(conn)
    return conn


def init_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS agent_registry (
            agent_id TEXT PRIMARY KEY,
            enabled INTEGER NOT NULL CHECK (enabled IN (0, 1)),
            capabilities_json TEXT NOT NULL,
            max_parallel INTEGER NOT NULL DEFAULT 1,
            cost_rank INTEGER NOT NULL DEFAULT 100,
            budget_class TEXT NOT NULL DEFAULT 'standard',
            updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS agent_tasks (
            id TEXT PRIMARY KEY,
            task_type TEXT NOT NULL,
            state TEXT NOT NULL CHECK (
                state IN (
                    'BACKLOG',
                    'TODO',
                    'IN_PROGRESS',
                    'REVIEW',
                    'APPROVED',
                    'PIPELINE',
                    'PASSED',
                    'FAILED',
                    'RECYCLE',
                    'OPS_FIX_REQUIRED',
                    'BLOCKED'
                )
            ),
            priority INTEGER NOT NULL DEFAULT 50,
            required_capabilities_json TEXT NOT NULL,
            assigned_agent TEXT,
            budget_class TEXT NOT NULL DEFAULT 'standard',
            parent_id TEXT,
            artifact_path TEXT,
            verdict TEXT,
            payload_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_agent_tasks_state_priority
            ON agent_tasks(state, priority, updated_at);
        CREATE INDEX IF NOT EXISTS idx_agent_tasks_assigned_agent
            ON agent_tasks(assigned_agent, state);
        """
    )


def sync_default_registry(root: Path = DEFAULT_ROOT, claude_disabled_flag: Path = CLAUDE_DISABLED_FLAG) -> dict[str, Any]:
    now = farmctl.utc_now()
    changed: list[str] = []
    with closing(connect(root)) as conn:
        for agent_id, cfg in DEFAULT_AGENT_REGISTRY.items():
            effective = dict(cfg)
            if agent_id == "claude" and claude_disabled_flag.exists():
                effective["enabled"] = False
                effective["max_parallel"] = 0
            conn.execute(
                """
                INSERT INTO agent_registry(
                    agent_id, enabled, capabilities_json, max_parallel,
                    cost_rank, budget_class, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(agent_id) DO UPDATE SET
                    enabled=excluded.enabled,
                    capabilities_json=excluded.capabilities_json,
                    max_parallel=excluded.max_parallel,
                    cost_rank=excluded.cost_rank,
                    budget_class=excluded.budget_class,
                    updated_at=excluded.updated_at
                """,
                (
                    agent_id,
                    1 if effective.get("enabled") else 0,
                    _json(effective.get("capabilities", [])),
                    int(effective.get("max_parallel", 1)),
                    int(effective.get("cost_rank", 100)),
                    str(effective.get("budget_class", "standard")),
                    now,
                ),
            )
            changed.append(agent_id)
        conn.commit()
    return {"synced": changed, "claude_disabled": claude_disabled_flag.exists()}


def enqueue_task(
    root: Path,
    task_type: str,
    *,
    state: str = "TODO",
    priority: int = 50,
    required_capabilities: list[str] | None = None,
    budget_class: str = "standard",
    parent_id: str | None = None,
    artifact_path: str | None = None,
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if task_type not in TASK_TYPE_CAPABILITIES:
        raise ValueError(f"unknown task_type: {task_type}")
    if state not in TASK_STATES:
        raise ValueError(f"unknown state: {state}")
    capabilities = required_capabilities or TASK_TYPE_CAPABILITIES[task_type]
    task_id = str(uuid.uuid4())
    now = farmctl.utc_now()
    with closing(connect(root)) as conn:
        conn.execute(
            """
            INSERT INTO agent_tasks(
                id, task_type, state, priority, required_capabilities_json,
                assigned_agent, budget_class, parent_id, artifact_path, verdict,
                payload_json, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, NULL, ?, ?, ?)
            """,
            (
                task_id,
                task_type,
                state,
                priority,
                _json(capabilities),
                budget_class,
                parent_id,
                artifact_path,
                _json(payload or {}),
                now,
                now,
            ),
        )
        conn.commit()
    return {"enqueued": True, "task_id": task_id, "task_type": task_type, "state": state}


def _running_count(conn: sqlite3.Connection, agent_id: str) -> int:
    row = conn.execute(
        "SELECT COUNT(*) AS n FROM agent_tasks WHERE assigned_agent=? AND state='IN_PROGRESS'",
        (agent_id,),
    ).fetchone()
    return int(row["n"] if row else 0)


def _eligible_agents(conn: sqlite3.Connection, required: set[str]) -> list[sqlite3.Row]:
    rows = conn.execute(
        """
        SELECT * FROM agent_registry
        WHERE enabled=1 AND max_parallel > 0
        ORDER BY cost_rank ASC, agent_id ASC
        """
    ).fetchall()
    eligible = []
    for row in rows:
        capabilities = set(json.loads(row["capabilities_json"] or "[]"))
        if not required.issubset(capabilities):
            continue
        if _running_count(conn, row["agent_id"]) >= int(row["max_parallel"]):
            continue
        eligible.append(row)
    return eligible


def route_once(root: Path = DEFAULT_ROOT) -> RouteDecision:
    sync_default_registry(root)
    now = farmctl.utc_now()
    with closing(connect(root)) as conn:
        conn.execute("BEGIN IMMEDIATE")
        task = conn.execute(
            """
            SELECT * FROM agent_tasks
            WHERE state IN ('BACKLOG', 'TODO')
            ORDER BY priority ASC, updated_at ASC, created_at ASC
            LIMIT 1
            """
        ).fetchone()
        if not task:
            conn.commit()
            return RouteDecision("", "", None, "no_routable_task")
        required = set(json.loads(task["required_capabilities_json"] or "[]"))
        agents = _eligible_agents(conn, required)
        if not agents:
            conn.commit()
            return RouteDecision(task["id"], task["task_type"], None, "no_available_agent")
        agent = agents[0]
        payload = json.loads(task["payload_json"] or "{}")
        payload["routed_at"] = now
        payload["required_capabilities"] = sorted(required)
        conn.execute(
            """
            UPDATE agent_tasks
            SET state='IN_PROGRESS', assigned_agent=?, payload_json=?, updated_at=?
            WHERE id=? AND state IN ('BACKLOG', 'TODO')
            """,
            (agent["agent_id"], _json(payload), now, task["id"]),
        )
        conn.commit()
        return RouteDecision(task["id"], task["task_type"], agent["agent_id"], "assigned")


def replenish(root: Path = DEFAULT_ROOT, *, min_ready_strategy_cards: int = 5) -> dict[str, Any]:
    """Seed backlog when the strategy-card reservoir is low.

    This is deliberately conservative. It only creates research tickets and
    leaves build/review/pipeline transitions to artifact-producing workers and
    the existing farm pump.
    """
    cards_dir = root / "artifacts" / "cards_approved"
    ready_count = len(list(cards_dir.glob("*.md"))) if cards_dir.exists() else 0
    created: list[dict[str, Any]] = []
    if ready_count < min_ready_strategy_cards:
        needed = min_ready_strategy_cards - ready_count
        with closing(connect(root)) as conn:
            existing = conn.execute(
                """
                SELECT COUNT(*) AS n FROM agent_tasks
                WHERE task_type='research_strategy'
                  AND state IN ('BACKLOG', 'TODO', 'IN_PROGRESS', 'REVIEW')
                """
            ).fetchone()
            open_count = int(existing["n"] if existing else 0)
        for _ in range(max(0, needed - open_count)):
            created.append(
                enqueue_task(
                    root,
                    "research_strategy",
                    state="TODO",
                    priority=30,
                    budget_class="low",
                    payload={"reason": "strategy_card_reservoir_low", "ready_count": ready_count},
                )
            )
    return {"ready_strategy_cards": ready_count, "created": created}


def status(root: Path = DEFAULT_ROOT) -> dict[str, Any]:
    sync_default_registry(root)
    with closing(connect(root)) as conn:
        agents = [
            {
                "agent_id": row["agent_id"],
                "enabled": bool(row["enabled"]),
                "max_parallel": int(row["max_parallel"]),
                "running": _running_count(conn, row["agent_id"]),
                "capabilities": json.loads(row["capabilities_json"] or "[]"),
            }
            for row in conn.execute("SELECT * FROM agent_registry ORDER BY agent_id").fetchall()
        ]
        tasks = [
            dict(row)
            for row in conn.execute(
                """
                SELECT task_type, state, assigned_agent, COUNT(*) AS count
                FROM agent_tasks
                GROUP BY task_type, state, assigned_agent
                ORDER BY task_type, state, assigned_agent
                """
            ).fetchall()
        ]
    return {"agents": agents, "tasks": tasks}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("init")
    sub.add_parser("status")
    sub.add_parser("replenish")
    enqueue = sub.add_parser("enqueue")
    enqueue.add_argument("task_type", choices=sorted(TASK_TYPE_CAPABILITIES))
    enqueue.add_argument("--priority", type=int, default=50)
    enqueue.add_argument("--state", default="TODO", choices=sorted(TASK_STATES))
    enqueue.add_argument("--payload-json", default="{}")
    sub.add_parser("route-once")
    args = parser.parse_args(argv)

    if args.command == "init":
        result = sync_default_registry(args.root)
    elif args.command == "status":
        result = status(args.root)
    elif args.command == "replenish":
        result = replenish(args.root)
    elif args.command == "enqueue":
        result = enqueue_task(
            args.root,
            args.task_type,
            state=args.state,
            priority=args.priority,
            payload=json.loads(args.payload_json),
        )
    elif args.command == "route-once":
        result = route_once(args.root).__dict__
    else:  # pragma: no cover
        raise AssertionError(args.command)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
