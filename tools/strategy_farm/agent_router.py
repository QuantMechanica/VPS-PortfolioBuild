#!/usr/bin/env python3
"""Deterministic capability router for strategy-farm agent work.

This module is intentionally not an AI orchestrator. It owns the ticket state
machine and chooses an available worker from declared capabilities, budgets,
and guardrails. Agents execute assigned tickets and write artifacts; the QM
pipeline remains the approval authority for EAs.
"""

from __future__ import annotations

import argparse
import datetime as dt
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
CARDS_REVIEW_REL = Path("artifacts") / "cards_review"
CARDS_APPROVED_REL = Path("artifacts") / "cards_approved"

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
    "SELF_LEARNING",
}

REVIEW_CLOSE_STATES = {"APPROVED", "BLOCKED", "FAILED", "RECYCLE"}

TASK_TYPE_CAPABILITIES: dict[str, list[str]] = {
    "research_strategy": ["research", "strategy"],
    "review_strategy": ["review", "strategy"],
    "build_ea": ["code"],
    "review_ea": ["review", "code"],
    "pipeline_run": ["pipeline"],
    "triage_failure": ["ops", "review"],
    "ops_issue": ["ops", "code"],
    "agent_learn": ["research"],
}

DEFAULT_AGENT_REGISTRY: dict[str, dict[str, Any]] = {
    "codex": {
        "enabled": True,
        "capabilities": ["code", "tests", "repo_edit", "review", "ops", "research", "strategy"],
        "max_parallel": 5,
        "cost_rank": 20,
    },
    "claude": {
        "enabled": True,
        "capabilities": ["code", "research", "review", "strategy", "summary"],
        "max_parallel": 3,
        "cost_rank": 30,
    },
    "gemini": {
        "enabled": True,
        "capabilities": ["research", "strategy", "source_discovery"],
        "max_parallel": 2,
        "cost_rank": 10,
    },
}

STALE_IN_PROGRESS_HOURS = 6

STRATEGY_CARD_SCHEMA: dict[str, list[str]] = {
    "frontmatter_required": [
        "ea_id",
        "slug",
        "g0_status",
        "r1_track_record",
        "r2_mechanical",
        "r3_data_available",
        "r4_ml_forbidden",
        "expected_trades_per_year_per_symbol",
    ],
    "body_required": [
        "thesis",
        "market_universe",
        "timeframe",
        "entry",
        "exit",
        "risk",
        "filters",
        "falsification",
        "q08_q11_risks",
        "implementation_notes",
    ],
}

RESEARCH_PERSPECTIVES: dict[str, dict[str, Any]] = {
    "gemini": {
        "required_capabilities": ["research", "strategy", "source_discovery"],
        "perspective": "broad_source_discovery",
        "brief": "Find external sources and mechanize fresh, testable strategy ideas across DWX-testable markets.",
    },
    "codex": {
        "required_capabilities": ["code", "research", "strategy"],
        "perspective": "implementation_aware_strategy_design",
        "brief": "Find strategies that can be encoded cleanly in the V5 EA framework with low parameter freedom.",
    },
    "claude": {
        "required_capabilities": ["research", "strategy", "summary"],
        "perspective": "deep_strategy_critique_and_synthesis",
        "brief": "Find or synthesize high-conviction strategy directions and critique why they may fail before MT5 time is spent.",
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


def _effective_claude_disabled_flag(root: Path, claude_disabled_flag: Path) -> Path:
    if claude_disabled_flag != CLAUDE_DISABLED_FLAG:
        return claude_disabled_flag
    root_flag = root / "CLAUDE_DISABLED.flag"
    if root != DEFAULT_ROOT and root_flag.exists():
        return root_flag
    return claude_disabled_flag


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
                    'BLOCKED',
                    'SELF_LEARNING'
                )
            ),
            priority INTEGER NOT NULL DEFAULT 50,
            required_capabilities_json TEXT NOT NULL,
            required_skills_json TEXT NOT NULL DEFAULT '[]',
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

        CREATE TABLE IF NOT EXISTS portfolio_candidates (
            ea_id TEXT NOT NULL,
            symbol TEXT NOT NULL DEFAULT '',
            q11_work_item_id TEXT NOT NULL,
            state TEXT NOT NULL DEFAULT 'Q12_REVIEW_READY',
            evidence_path TEXT,
            first_seen_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (ea_id, symbol, q11_work_item_id)
        );
        CREATE INDEX IF NOT EXISTS idx_portfolio_candidates_state
            ON portfolio_candidates(state, updated_at);
        """
    )
    columns = {
        str(row["name"] if isinstance(row, sqlite3.Row) else row[1])
        for row in conn.execute("PRAGMA table_info(agent_tasks)").fetchall()
    }
    if "required_skills_json" not in columns:
        conn.execute("ALTER TABLE agent_tasks ADD COLUMN required_skills_json TEXT NOT NULL DEFAULT '[]'")


def sync_default_registry(root: Path = DEFAULT_ROOT, claude_disabled_flag: Path = CLAUDE_DISABLED_FLAG) -> dict[str, Any]:
    claude_disabled_flag = _effective_claude_disabled_flag(root, claude_disabled_flag)
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
    required_skills: list[str] | None = None,
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
    skills = required_skills or []
    task_id = str(uuid.uuid4())
    now = farmctl.utc_now()
    with closing(connect(root)) as conn:
        conn.execute(
            """
            INSERT INTO agent_tasks(
                id, task_type, state, priority, required_capabilities_json,
                required_skills_json, assigned_agent, budget_class, parent_id, 
                artifact_path, verdict, payload_json, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, NULL, ?, ?, ?)
            """,
            (
                task_id,
                task_type,
                state,
                priority,
                _json(capabilities),
                _json(skills),
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


def release_stale_in_progress(root: Path = DEFAULT_ROOT, *, max_age_hours: int = STALE_IN_PROGRESS_HOURS) -> dict[str, Any]:
    """Release abandoned agent_tasks so one dead worker cannot consume capacity forever."""
    now = farmctl.utc_now()
    cutoff = dt.datetime.now(dt.UTC).replace(microsecond=0) - dt.timedelta(hours=max_age_hours)
    released: list[dict[str, Any]] = []
    with closing(connect(root)) as conn:
        conn.execute("BEGIN IMMEDIATE")
        rows = conn.execute(
            """
            SELECT * FROM agent_tasks
            WHERE state='IN_PROGRESS'
              AND updated_at < ?
            ORDER BY updated_at ASC
            """,
            (cutoff.isoformat(timespec="seconds"),),
        ).fetchall()
        for row in rows:
            payload = json.loads(row["payload_json"] or "{}")
            history = list(payload.get("stale_releases") or [])
            history.append(
                {
                    "released_at": now,
                    "previous_assigned_agent": row["assigned_agent"],
                    "previous_updated_at": row["updated_at"],
                    "max_age_hours": max_age_hours,
                }
            )
            payload["stale_releases"] = history[-5:]
            conn.execute(
                """
                UPDATE agent_tasks
                SET state='TODO', assigned_agent=NULL, payload_json=?, updated_at=?
                WHERE id=? AND state='IN_PROGRESS'
                """,
                (_json(payload), now, row["id"]),
            )
            released.append(
                {
                    "task_id": row["id"],
                    "task_type": row["task_type"],
                    "assigned_agent": row["assigned_agent"],
                    "previous_updated_at": row["updated_at"],
                }
            )
        conn.commit()
    return {"released": released, "max_age_hours": max_age_hours}


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


def route_once(root: Path = DEFAULT_ROOT, *, claude_disabled_flag: Path = CLAUDE_DISABLED_FLAG) -> RouteDecision:
    sync_default_registry(root, claude_disabled_flag=claude_disabled_flag)
    release_stale_in_progress(root)
    now = farmctl.utc_now()
    with closing(connect(root)) as conn:
        conn.execute("BEGIN IMMEDIATE")
        tasks = conn.execute(
            """
            SELECT * FROM agent_tasks
            WHERE state IN ('BACKLOG', 'TODO')
            ORDER BY priority ASC, updated_at ASC, created_at ASC
            LIMIT 25
            """
        ).fetchall()
        if not tasks:
            conn.commit()
            return RouteDecision("", "", None, "no_routable_task")
        skipped: list[str] = []
        selected: tuple[sqlite3.Row, sqlite3.Row, set[str]] | None = None
        for task in tasks:
            required = set(json.loads(task["required_capabilities_json"] or "[]"))
            agents = _eligible_agents(conn, required)
            if not agents:
                skipped.append(task["id"])
                continue
            selected = (task, agents[0], required)
            break
        if selected is None:
            conn.commit()
            first = tasks[0]
            return RouteDecision(first["id"], first["task_type"], None, "no_available_agent")
        task, agent, required = selected
        payload = json.loads(task["payload_json"] or "{}")
        payload["routed_at"] = now
        payload["required_capabilities"] = sorted(required)
        if skipped:
            payload["router_skipped_blocked_task_count"] = len(skipped)
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


def route_many(
    root: Path = DEFAULT_ROOT,
    *,
    max_routes: int = 5,
    claude_disabled_flag: Path = CLAUDE_DISABLED_FLAG,
) -> list[dict[str, Any]]:
    """Route up to `max_routes` waiting tickets.

    This is intentionally only a router. It moves tickets from BACKLOG/TODO to
    IN_PROGRESS for an eligible agent and respects each agent's max_parallel
    limit. Agent execution remains artifact-driven and separate.
    """
    decisions: list[dict[str, Any]] = []
    for _ in range(max(0, max_routes)):
        decision = route_once(root, claude_disabled_flag=claude_disabled_flag)
        decisions.append(decision.__dict__)
        if decision.reason != "assigned":
            break
    return decisions


def replenish(
    root: Path = DEFAULT_ROOT,
    *,
    min_ready_strategy_cards: int = 5,
    claude_disabled_flag: Path = CLAUDE_DISABLED_FLAG,
) -> dict[str, Any]:
    """Report strategy reservoir state without seeding generic research.

    Generic reservoir replenishment is frozen by WS-1 of the 2026-05-22
    remediation plan. Edge Lab and other explicitly routed research tasks remain
    valid, but the old ready-card threshold should not manufacture open-ended
    research_strategy tasks against the parked generic backlog.
    """
    sync_default_registry(root, claude_disabled_flag=claude_disabled_flag)
    inventory = farmctl.research_backlog_inventory(root)
    ready_count = int(inventory.get("total", 0))
    return {
        "ready_strategy_cards": ready_count,
        "strategy_inventory": inventory,
        "created": [],
        "frozen": True,
        "reason": "generic_research_replenishment_frozen_edge_lab_primary_2026-05-22",
        "min_ready_strategy_cards": min_ready_strategy_cards,
    }


def enqueue_friday_smoke_tasks(
    root: Path = DEFAULT_ROOT,
    *,
    claude_disabled_flag: Path = CLAUDE_DISABLED_FLAG,
) -> dict[str, Any]:
    """Seed one tiny verification task per worker for Friday startup."""
    sync_default_registry(root, claude_disabled_flag=claude_disabled_flag)
    created: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    profiles = {
        "codex": ("ops_issue", ["code", "ops"], "Router smoke: write a tiny artifact and mark this task REVIEW."),
        "gemini": ("research_strategy", ["research", "strategy", "source_discovery"], "Research smoke: draft one paragraph on a non-duplicate strategy direction."),
        "claude": ("review_strategy", ["review", "strategy", "summary"], "Review smoke: critique one candidate or dashboard note, then mark REVIEW."),
    }
    with closing(connect(root)) as conn:
        enabled_agents = {
            row["agent_id"]
            for row in conn.execute("SELECT agent_id FROM agent_registry WHERE enabled=1 AND max_parallel > 0").fetchall()
        }
        open_smoke_targets = set()
        for row in conn.execute(
            """
            SELECT payload_json FROM agent_tasks
            WHERE state IN ('BACKLOG', 'TODO', 'IN_PROGRESS', 'REVIEW')
              AND payload_json LIKE '%"friday_orchestration_smoke"%'
            """
        ).fetchall():
            try:
                payload = json.loads(row["payload_json"] or "{}")
            except json.JSONDecodeError:
                continue
            target = str(payload.get("target_agent_profile") or "")
            if target:
                open_smoke_targets.add(target)
    for agent_id, (task_type, capabilities, brief) in profiles.items():
        if agent_id not in enabled_agents:
            skipped.append({"agent": agent_id, "reason": "agent_disabled"})
            continue
        if agent_id in open_smoke_targets:
            skipped.append({"agent": agent_id, "reason": "already_open"})
            continue
        created.append(
            enqueue_task(
                root,
                task_type,
                state="TODO",
                priority=5,
                required_capabilities=capabilities,
                payload={
                    "reason": "friday_orchestration_smoke",
                    "target_agent_profile": agent_id,
                    "brief": brief,
                    "expected_artifact": f"docs/ops/friday_smoke_{agent_id}_2026-05-22.md",
                },
            )
        )
    return {"created": created, "skipped": skipped}


def run_once(
    root: Path = DEFAULT_ROOT,
    *,
    min_ready_strategy_cards: int = 5,
    max_routes: int = 5,
    claude_disabled_flag: Path = CLAUDE_DISABLED_FLAG,
) -> dict[str, Any]:
    """Autonomous router tick for Scheduled Task use."""
    registry = sync_default_registry(root, claude_disabled_flag=claude_disabled_flag)
    replenished = replenish(
        root,
        min_ready_strategy_cards=min_ready_strategy_cards,
        claude_disabled_flag=claude_disabled_flag,
    )
    routed = route_many(root, max_routes=max_routes, claude_disabled_flag=claude_disabled_flag)
    return {
        "registry": registry,
        "replenish": replenished,
        "routes": routed,
        "status": status(root),
    }


def status(root: Path = DEFAULT_ROOT, *, claude_disabled_flag: Path = CLAUDE_DISABLED_FLAG) -> dict[str, Any]:
    sync_default_registry(root, claude_disabled_flag=claude_disabled_flag)
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


def list_tasks(root: Path = DEFAULT_ROOT, agent_id: str | None = None) -> list[dict[str, Any]]:
    with closing(connect(root)) as conn:
        query = "SELECT * FROM agent_tasks"
        params = []
        if agent_id:
            query += " WHERE assigned_agent = ?"
            params.append(agent_id)
        query += " ORDER BY priority DESC, updated_at DESC"
        
        rows = conn.execute(query, params).fetchall()
        return [
            {
                "id": row["id"],
                "task_type": row["task_type"],
                "state": row["state"],
                "priority": row["priority"],
                "assigned_agent": row["assigned_agent"],
                "skills": json.loads(row["required_skills_json"] or "[]"),
                "payload": json.loads(row["payload_json"] or "{}"),
                "updated_at": row["updated_at"],
            }
            for row in rows
        ]


def update_task(
    root: Path,
    task_id: str,
    *,
    state: str,
    artifact_path: str | None = None,
    verdict: str | None = None,
) -> dict[str, Any]:
    if state not in TASK_STATES:
        raise ValueError(f"unknown state: {state}")
    now = farmctl.utc_now()
    with closing(connect(root)) as conn:
        row = conn.execute("SELECT * FROM agent_tasks WHERE id=?", (task_id,)).fetchone()
        if not row:
            return {"updated": False, "task_id": task_id, "reason": "task_not_found"}
        if row["task_type"] == "research_strategy" and state == "REVIEW" and artifact_path:
            try:
                resolved_artifact = Path(artifact_path).resolve()
                approved_dir = (root / CARDS_APPROVED_REL).resolve()
                review_dir = (root / CARDS_REVIEW_REL).resolve()
                if resolved_artifact == approved_dir or approved_dir in resolved_artifact.parents:
                    return {
                        "updated": False,
                        "task_id": task_id,
                        "reason": "research_artifact_must_use_cards_review",
                        "required_dir": str(review_dir),
                    }
                if resolved_artifact.suffix.lower() == ".md" and (resolved_artifact == review_dir or review_dir in resolved_artifact.parents):
                    if not resolved_artifact.exists():
                        return {"updated": False, "task_id": task_id, "reason": "artifact_path_missing"}
                    fm = farmctl.parse_card_frontmatter(resolved_artifact)
                    schema_issues = farmctl.strategy_card_schema_issues(resolved_artifact, fm)
                    if schema_issues:
                        return {
                            "updated": False,
                            "task_id": task_id,
                            "reason": "strategy_card_schema_failed",
                            "errors": schema_issues[:12],
                        }
                    fp = farmctl.strategy_card_fingerprint(resolved_artifact, fm)
                    duplicate_cards: list[str] = []
                    for pool in (approved_dir, review_dir):
                        if not pool.exists():
                            continue
                        for candidate in pool.glob("*.md"):
                            if candidate.resolve() == resolved_artifact:
                                continue
                            try:
                                if farmctl.strategy_card_fingerprint(candidate) == fp:
                                    duplicate_cards.append(str(candidate))
                            except Exception:
                                continue
                    if duplicate_cards:
                        return {
                            "updated": False,
                            "task_id": task_id,
                            "reason": "duplicate_strategy_card_fingerprint",
                            "fingerprint": fp,
                            "duplicates": duplicate_cards[:8],
                        }
            except OSError as exc:
                return {"updated": False, "task_id": task_id, "reason": f"artifact_path_invalid:{exc}"}
        conn.execute(
            """
            UPDATE agent_tasks
            SET state=?, artifact_path=COALESCE(?, artifact_path),
                verdict=COALESCE(?, verdict), updated_at=?
            WHERE id=?
            """,
            (state, artifact_path, verdict, now, task_id),
        )
        conn.commit()
    return {
        "updated": True,
        "task_id": task_id,
        "state": state,
        "artifact_path": artifact_path,
        "verdict": verdict,
    }


def _task_artifact_path(root: Path, row: sqlite3.Row, artifact_path: str | None) -> Path | None:
    candidate = artifact_path or row["artifact_path"]
    if not candidate:
        try:
            payload = json.loads(row["payload_json"] or "{}")
        except json.JSONDecodeError:
            payload = {}
        candidate = payload.get("closeout_artifact") or payload.get("expected_artifact")
    if not candidate:
        return None
    path = Path(str(candidate))
    if not path.is_absolute():
        path = farmctl.REPO_ROOT / path
    return path


def close_review_task(
    root: Path,
    task_id: str,
    *,
    close_state: str,
    verdict: str,
    artifact_path: str | None = None,
    note: str | None = None,
) -> dict[str, Any]:
    """Close a REVIEW task after deterministic artifact checks."""
    if close_state not in REVIEW_CLOSE_STATES:
        raise ValueError(f"close_state must be one of {sorted(REVIEW_CLOSE_STATES)}")
    if not verdict.strip():
        raise ValueError("verdict is required")
    now = farmctl.utc_now()
    with closing(connect(root)) as conn:
        row = conn.execute("SELECT * FROM agent_tasks WHERE id=?", (task_id,)).fetchone()
        if not row:
            return {"closed": False, "task_id": task_id, "reason": "task_not_found"}
        if row["state"] != "REVIEW":
            return {"closed": False, "task_id": task_id, "reason": f"not_in_review:{row['state']}"}
        evidence = _task_artifact_path(root, row, artifact_path)
        if close_state == "APPROVED":
            if evidence is None:
                return {"closed": False, "task_id": task_id, "reason": "approval_requires_artifact"}
            if not evidence.exists():
                return {
                    "closed": False,
                    "task_id": task_id,
                    "reason": "artifact_missing",
                    "artifact_path": str(evidence),
                }

        payload = json.loads(row["payload_json"] or "{}")
        payload["review_closed_at"] = now
        payload["review_close_state"] = close_state
        payload["review_close_verdict"] = verdict
        if note:
            payload["review_close_note"] = note
        conn.execute(
            """
            UPDATE agent_tasks
            SET state=?, artifact_path=COALESCE(?, artifact_path),
                verdict=?, payload_json=?, updated_at=?
            WHERE id=?
            """,
            (
                close_state,
                str(evidence) if artifact_path is None and evidence is not None else artifact_path,
                verdict,
                _json(payload),
                now,
                task_id,
            ),
        )
        conn.commit()
    return {
        "closed": True,
        "task_id": task_id,
        "state": close_state,
        "verdict": verdict,
        "artifact_path": str(evidence) if evidence else artifact_path,
    }


def sync_q11_candidates(root: Path = DEFAULT_ROOT) -> dict[str, Any]:
    """Mirror Q11/P8 PASS work_items into a Q12 portfolio-candidate queue."""
    now = farmctl.utc_now()
    created = 0
    existing = 0
    with closing(connect(root)) as conn:
        rows = conn.execute(
            """
            SELECT id, ea_id, COALESCE(symbol, '') AS symbol, evidence_path
            FROM work_items
            WHERE phase='P8' AND status='done' AND verdict='PASS'
            ORDER BY updated_at DESC
            """
        ).fetchall()
        for row in rows:
            cur = conn.execute(
                """
                SELECT 1 FROM portfolio_candidates
                WHERE ea_id=? AND symbol=? AND q11_work_item_id=?
                """,
                (row["ea_id"], row["symbol"], row["id"]),
            ).fetchone()
            if cur:
                existing += 1
                conn.execute(
                    """
                    UPDATE portfolio_candidates
                    SET evidence_path=COALESCE(?, evidence_path), updated_at=?
                    WHERE ea_id=? AND symbol=? AND q11_work_item_id=?
                    """,
                    (row["evidence_path"], now, row["ea_id"], row["symbol"], row["id"]),
                )
                continue
            conn.execute(
                """
                INSERT INTO portfolio_candidates(
                    ea_id, symbol, q11_work_item_id, state, evidence_path,
                    first_seen_at, updated_at
                )
                VALUES (?, ?, ?, 'Q12_REVIEW_READY', ?, ?, ?)
                """,
                (row["ea_id"], row["symbol"], row["id"], row["evidence_path"], now, now),
            )
            created += 1
        conn.commit()
    return {
        "q11_pass_rows": len(rows),
        "created": created,
        "existing": existing,
        "target": "portfolio_candidates",
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("init")
    sub.add_parser("status")
    list_tasks_p = sub.add_parser("list-tasks")
    list_tasks_p.add_argument("--agent", help="Filter by assigned agent ID")
    sub.add_parser("replenish")
    route_many_p = sub.add_parser("route-many")
    route_many_p.add_argument("--max-routes", type=int, default=5)
    run = sub.add_parser("run")
    run.add_argument("--min-ready-strategy-cards", type=int, default=5)
    run.add_argument("--max-routes", type=int, default=5)
    enqueue = sub.add_parser("enqueue")
    enqueue.add_argument("task_type", choices=sorted(TASK_TYPE_CAPABILITIES))
    enqueue.add_argument("--priority", type=int, default=50)
    enqueue.add_argument("--state", default="TODO", choices=sorted(TASK_STATES))
    enqueue.add_argument("--payload-json", default="{}")
    enqueue.add_argument("--skills", help="Comma-separated list of required skills")
    sub.add_parser("enqueue-friday-smoke")
    sub.add_parser("route-once")
    close = sub.add_parser("close-review")
    close.add_argument("task_id")
    close.add_argument("--state", required=True, choices=sorted(REVIEW_CLOSE_STATES))
    close.add_argument("--verdict", required=True)
    close.add_argument("--artifact-path")
    close.add_argument("--note")
    sub.add_parser("sync-q11-candidates")
    update = sub.add_parser("update-task")
    update.add_argument("task_id")
    update.add_argument("--state", required=True, choices=sorted(TASK_STATES))
    update.add_argument("--artifact-path")
    update.add_argument("--verdict")
    args = parser.parse_args(argv)

    if args.command == "init":
        result = sync_default_registry(args.root)
    elif args.command == "status":
        result = status(args.root)
    elif args.command == "list-tasks":
        result = list_tasks(args.root, agent_id=args.agent)
    elif args.command == "replenish":
        result = replenish(args.root)
    elif args.command == "route-many":
        result = route_many(args.root, max_routes=args.max_routes)
    elif args.command == "run":
        result = run_once(
            args.root,
            min_ready_strategy_cards=args.min_ready_strategy_cards,
            max_routes=args.max_routes,
        )
    elif args.command == "enqueue":
        skills = [s.strip() for s in args.skills.split(",")] if args.skills else None
        result = enqueue_task(
            args.root,
            args.task_type,
            state=args.state,
            priority=args.priority,
            required_skills=skills,
            payload=json.loads(args.payload_json),
        )
    elif args.command == "enqueue-friday-smoke":
        result = enqueue_friday_smoke_tasks(args.root)
    elif args.command == "route-once":
        result = route_once(args.root).__dict__
    elif args.command == "close-review":
        result = close_review_task(
            args.root,
            args.task_id,
            close_state=args.state,
            verdict=args.verdict,
            artifact_path=args.artifact_path,
            note=args.note,
        )
    elif args.command == "sync-q11-candidates":
        result = sync_q11_candidates(args.root)
    elif args.command == "update-task":
        result = update_task(
            args.root,
            args.task_id,
            state=args.state,
            artifact_path=args.artifact_path,
            verdict=args.verdict,
        )
    else:  # pragma: no cover
        raise AssertionError(args.command)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
