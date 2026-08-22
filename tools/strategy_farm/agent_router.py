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
import hashlib
import json
import re
import sqlite3
import subprocess
import uuid
from contextlib import closing
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    from tools.strategy_farm import farmctl
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    import farmctl  # type: ignore

try:
    from tools.strategy_farm import agent_scopes
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    import agent_scopes  # type: ignore

try:
    from tools.strategy_farm import quota_spawn_gate
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    import quota_spawn_gate  # type: ignore

try:
    from tools.strategy_farm import work_identity
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    import work_identity  # type: ignore

try:
    from tools.strategy_farm import raw_mq5_quarantine
except ModuleNotFoundError:  # pragma: no cover - direct script execution
    import raw_mq5_quarantine  # type: ignore


DEFAULT_ROOT = farmctl.DEFAULT_ROOT
CLAUDE_DISABLED_FLAG = Path(r"D:\QM\strategy_farm\CLAUDE_DISABLED.flag")
CARDS_REVIEW_REL = Path("artifacts") / "cards_review"
CARDS_APPROVED_REL = Path("artifacts") / "cards_approved"
ROUTER_CHECKOUT_ROOT = Path(__file__).resolve().parents[2]
CANONICAL_ROUTER_ROOT = Path(farmctl.CANONICAL_REPO_ROOT)
ROUTER_WRITER_GENERATION = "qm.router-writer/2026-08-22.v1"
ROUTER_MUTATING_COMMANDS = frozenset({"run", "route-many", "route-once", "replenish"})

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
LEASE_TTL_MINUTES = 30
LEASE_RELEASE_STATES = {"REVIEW", "APPROVED", "FAILED", "BLOCKED", "RECYCLE"}

TASK_TYPE_CAPABILITIES: dict[str, list[str]] = {
    "research_strategy": ["research", "strategy"],
    "review_strategy": ["review", "strategy"],
    "build_ea": ["code"],
    "review_ea": ["review", "code"],
    "triage_failure": ["ops", "review"],
    "ops_issue": ["ops", "code"],
    "agent_learn": ["research"],
}

# Minimum eligibility contract per lane.  Task-type requirements are kept as
# the source of truth; lane-specific capabilities cover governed specialist
# work that is expressed as a required skill on an otherwise generic task.
AGENT_TASK_TYPE_LANES: dict[str, tuple[str, ...]] = {
    "codex": ("ops_issue", "triage_failure"),
    "claude": ("ops_issue", "triage_failure"),
    "gemini": ("research_strategy",),
    "owner": (),
}
AGENT_EXTRA_REQUIRED_CAPABILITIES: dict[str, set[str]] = {
    # OWNER 2026-08-21: `video_analysis` moved off the gemini lane. The routing
    # contract had named agy as the video seat since the beginning, but that
    # build has no video tool (verified three times 2026-07-12) and the VPS IP
    # is bot-blocked on YouTube — so the lane could never deliver, and a video
    # ticket sitting there was indistinguishable from ordinary backlog. OWNER
    # holds this capability personally now.
    "owner": {"video_analysis"},
}

# Lanes with NO automated worker. A task whose requirements only a human lane
# can satisfy must never be silently skipped (that is what made the blind agy
# video lane look like backlog) and must never fall through to a seat that
# cannot do the work. It is held, marked, and surfaced — see
# `_human_lane_holder` and the `awaiting_human_lane` routing decision.
HUMAN_LANES: frozenset[str] = frozenset({"owner"})

# Task types deliberately removed from the agent lane. `pipeline_run` required
# capability `pipeline`, which no enabled agent declares — so it was
# deterministically unroutable (census 2026-07-27 rank 12: a priority-99 row
# returned no_available_agent three times and had to be re-filed). It is NOT
# re-added by giving an agent the `pipeline` capability: a pipeline VERDICT is
# produced only by the deterministic Q02–Q10 backtest factory (work_items +
# phase runners + T1–T10), never by an AI worker (Hard Rule: "Pipeline verdicts
# come only from the pipeline"). Running a pipeline phase is factory work
# (farmctl pump / phase runners), not an agent_tasks lane. Code/ops work that a
# `pipeline_run` row was standing in for must be filed as `ops_issue`.
REMOVED_TASK_TYPES: dict[str, str] = {
    "pipeline_run": (
        "pipeline_run is retired from the agent router: pipeline verdicts come "
        "only from the Q02–Q10 factory, not an agent. File code/ops work as ops_issue."
    ),
}

# Contractual exit semantics for the three limbo states that the deterministic
# router never selects (census 2026-07-27 ranks 4/5/8). The canonical contract
# (AI Agent Routing and Role Contracts.md) is
#   BACKLOG -> TODO -> IN_PROGRESS -> REVIEW -> APPROVED -> PIPELINE -> PASSED
#   \-> FAILED / RECYCLE / OPS_FIX_REQUIRED / BLOCKED
# and defines APPROVED as "formally clean enough for the next deterministic
# process to start". For a build that next process is the backtest pipeline, so
# build_ea APPROVED advances to PIPELINE. For every other task type there is NO
# further deterministic pipeline (a research card / review / ops report / triage
# has no MT5 gate), so APPROVED is already the accepted terminal and resolves to
# PASSED — pushing those into PIPELINE would only mint a new dead end where no
# pipeline verdict can ever arrive.
PIPELINE_BOUND_TASK_TYPES = {"build_ea"}
# A recycled task is re-queued for another attempt, but bounded so a permanently
# unbuildable card cannot loop forever; past the cap it parks in BLOCKED for a
# human. Closing phases whose PASS/FAIL is the per-EA verdict.
RECYCLE_MAX_ATTEMPTS = 3
CLOSING_PIPELINE_PHASES = ("Q10", "P8")
LIMBO_STATES = ("RECYCLE", "APPROVED", "PIPELINE")

DEFAULT_AGENT_REGISTRY: dict[str, dict[str, Any]] = {
    "codex": {
        "enabled": True,
        "capabilities": ["code", "tests", "repo_edit", "review", "ops", "research", "strategy"],
        "max_parallel": 5,
        "cost_rank": 20,
    },
    "claude": {
        "enabled": True,
        # OWNER 2026-07-02/03: headless Sonnet lane takes coding tasks (incl. former
        # codex work) -> full coding capability set; Codex weekly quota is the
        # scarce one. "repo" added 2026-07-03 (main lane) to match ops_issue
        # task requirements ([code,repo,ops]).
        "capabilities": ["code", "tests", "repo_edit", "repo", "ops", "research", "review", "strategy", "summary"],
        "max_parallel": 3,  # OWNER 2026-06-09: 2->3 (use weekly headroom before Wed reset)
        "cost_rank": 30,
    },
    "gemini": {
        "enabled": True,
        # Research lane. `video_analysis` was REMOVED here on OWNER instruction
        # 2026-08-21 and now lives on the `owner` lane: this build has no video
        # tool and the VPS IP is YouTube-blocked, so the capability was declared
        # but undeliverable — see AGENT_EXTRA_REQUIRED_CAPABILITIES.
        # Whether code/tests/repo_edit belong on this lane is a SEPARATE OWNER
        # decision after the 2026-08-21 agy build-wave review (49/50 negative);
        # the flapping fix (ticket cd982cfc) deliberately does NOT change those
        # — it only stops stale worktree checkouts from overwriting them.
        # Leave the rest exactly as-is until that decision lands.
        "capabilities": ["code", "tests", "repo_edit", "research", "strategy", "source_discovery"],
        "max_parallel": 2,
        "cost_rank": 10,
    },
    "owner": {
        # OWNER 2026-08-21: the human lane. Declared so that routing KNOWS who
        # holds `video_analysis`; disabled with max_parallel 0 because there is
        # no worker process to execute it. The combination is deliberate: a
        # declared-but-unexecutable lane makes a video ticket wait visibly
        # (reason `awaiting_human_lane`) instead of either falling to a seat
        # that cannot watch a video or vanishing into a silent skip.
        # The extra capabilities beyond video_analysis exist so that a normal
        # research_strategy ticket carrying the video_analysis skill resolves to
        # this lane as a whole rather than tripping the unroutable path.
        "enabled": False,
        "capabilities": ["video_analysis", "research", "strategy", "review", "summary"],
        "max_parallel": 0,
        "cost_rank": 99,
    },
}

STALE_IN_PROGRESS_HOURS = 6
LANE_HEARTBEAT_STALE_HOURS = 2  # release IN_PROGRESS tasks / skip lane if heartbeat is older than this

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


class RouterCheckoutError(RuntimeError):
    """A routing writer was invoked outside the canonical checkout."""

    def __init__(self, command: str, detail: dict[str, Any]) -> None:
        self.command = command
        self.detail = detail
        super().__init__(
            f"REFUSED router command {command!r}: checkout={detail['checkout_root']} "
            f"git_marker={detail['git_marker_type']}; canonical={detail['canonical_root']}"
        )


def _json(data: Any) -> str:
    return json.dumps(data, sort_keys=True, separators=(",", ":"))


def _directory_artifact_error(artifact_path: str | None) -> dict[str, str] | None:
    """Refuse to RECORD a directory where a task artifact must be a FILE.

    Census 2026-07-27 rank 9: a directory recorded in artifact_path expanded the
    build-guardrail scan to the whole framework/EAs tree and timed out repeatedly
    on close-review. The multi-path semicolon form (fixed the same day, four
    review_strategy tasks depend on it) is preserved: each part is checked
    independently. Only an *existing* directory is rejected — a not-yet-written
    file path is allowed, because artifacts are often recorded before they land.
    """
    if not artifact_path:
        return None
    for part in str(artifact_path).split(";"):
        part = part.strip()
        if not part:
            continue
        path = Path(part)
        if not path.is_absolute():
            path = farmctl.REPO_ROOT / path
        try:
            is_dir = path.is_dir()
        except OSError:
            continue
        if is_dir:
            return {
                "reason": "artifact_must_be_file_not_directory",
                "artifact_path": part,
                "detail": (
                    "a task artifact must be a single evidence file, not a directory; "
                    "point at the specific file (e.g. build_result.json / a report.csv), "
                    "not the EA folder"
                ),
            }
    return None


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
    # DB triggers call this connection-local function. Current canonical code
    # registers the generation; old router code does not know the function at
    # all, so writes fail at the shared database boundary even if old code's
    # local .git test is missing.
    conn.create_function(
        "qm_router_writer_generation",
        0,
        lambda: (
            ROUTER_WRITER_GENERATION
            if _registry_writer_authorized()
            else None
        ),
        deterministic=True,
    )
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
    _install_router_writer_contract(conn)


def _registry_writer_authorized() -> bool:
    """Only the primary checkout may overwrite the shared agent registry.

    A normal checkout has a real ``.git/`` directory.  Git linked worktrees
    have a ``.git`` *file*, so scheduled orchestration worktrees remain readers
    even when they execute an older/default-divergent source revision.
    """
    return (ROUTER_CHECKOUT_ROOT / ".git").is_dir()


def _git_marker_type(root: Path) -> str:
    marker = root / ".git"
    if marker.is_dir():
        return "directory"
    if marker.is_file():
        return "file"
    if marker.exists():
        return "other"
    return "missing"


def _router_checkout_detail() -> dict[str, Any]:
    return {
        "checkout_root": str(ROUTER_CHECKOUT_ROOT),
        "canonical_root": str(CANONICAL_ROUTER_ROOT),
        "git_marker": str(ROUTER_CHECKOUT_ROOT / ".git"),
        "git_marker_type": _git_marker_type(ROUTER_CHECKOUT_ROOT),
        "canonical_git_directory_required": True,
        "writer_generation": ROUTER_WRITER_GENERATION,
    }


def _require_canonical_router_command(command: str) -> None:
    if _registry_writer_authorized():
        return
    raise RouterCheckoutError(command, _router_checkout_detail())


def _checkout_head() -> str | None:
    result = subprocess.run(
        ["git", "-C", str(ROUTER_CHECKOUT_ROOT), "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def _install_router_writer_contract(conn: sqlite3.Connection) -> None:
    """Install a DB-side writer gate that old checkouts cannot satisfy."""
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS router_writer_contract (
            singleton INTEGER PRIMARY KEY CHECK(singleton=1),
            generation TEXT NOT NULL,
            canonical_checkout_root TEXT NOT NULL,
            installed_at TEXT NOT NULL,
            installed_by_head TEXT
        )
        """
    )
    if _registry_writer_authorized():
        now = farmctl.utc_now()
        conn.execute(
            """
            INSERT INTO router_writer_contract(
                singleton,generation,canonical_checkout_root,installed_at,installed_by_head
            ) VALUES (1,?,?,?,?)
            ON CONFLICT(singleton) DO UPDATE SET
                generation=excluded.generation,
                canonical_checkout_root=excluded.canonical_checkout_root,
                installed_at=excluded.installed_at,
                installed_by_head=excluded.installed_by_head
            WHERE router_writer_contract.generation<>excluded.generation
               OR router_writer_contract.canonical_checkout_root<>excluded.canonical_checkout_root
            """,
            (
                ROUTER_WRITER_GENERATION,
                str(CANONICAL_ROUTER_ROOT.resolve()),
                now,
                _checkout_head(),
            ),
        )
    # These triggers are durable shared-DB policy. An old router connection has
    # no qm_router_writer_generation() function, and therefore cannot write the
    # registry, enqueue replenishment tasks, or change task ownership.
    conn.executescript(
        """
        CREATE TRIGGER IF NOT EXISTS trg_router_writer_contract_insert
        BEFORE INSERT ON router_writer_contract
        WHEN qm_router_writer_generation() IS NULL
          OR NEW.generation<>qm_router_writer_generation()
        BEGIN
            SELECT RAISE(ABORT, 'router writer generation mismatch');
        END;

        CREATE TRIGGER IF NOT EXISTS trg_router_writer_contract_update
        BEFORE UPDATE ON router_writer_contract
        WHEN qm_router_writer_generation() IS NULL
          OR NEW.generation<>qm_router_writer_generation()
        BEGIN
            SELECT RAISE(ABORT, 'router writer generation mismatch');
        END;

        CREATE TRIGGER IF NOT EXISTS trg_agent_registry_canonical_insert
        BEFORE INSERT ON agent_registry
        WHEN qm_router_writer_generation() IS NULL
          OR qm_router_writer_generation()<>COALESCE((
            SELECT generation FROM router_writer_contract WHERE singleton=1
          ), '')
        BEGIN
            SELECT RAISE(ABORT, 'agent_registry requires canonical router generation');
        END;

        CREATE TRIGGER IF NOT EXISTS trg_agent_registry_canonical_update
        BEFORE UPDATE ON agent_registry
        WHEN qm_router_writer_generation() IS NULL
          OR qm_router_writer_generation()<>COALESCE((
            SELECT generation FROM router_writer_contract WHERE singleton=1
          ), '')
        BEGIN
            SELECT RAISE(ABORT, 'agent_registry requires canonical router generation');
        END;

        CREATE TRIGGER IF NOT EXISTS trg_agent_registry_canonical_delete
        BEFORE DELETE ON agent_registry
        WHEN qm_router_writer_generation() IS NULL
          OR qm_router_writer_generation()<>COALESCE((
            SELECT generation FROM router_writer_contract WHERE singleton=1
          ), '')
        BEGIN
            SELECT RAISE(ABORT, 'agent_registry requires canonical router generation');
        END;

        CREATE TRIGGER IF NOT EXISTS trg_agent_tasks_canonical_insert
        BEFORE INSERT ON agent_tasks
        WHEN qm_router_writer_generation() IS NULL
          OR qm_router_writer_generation()<>COALESCE((
            SELECT generation FROM router_writer_contract WHERE singleton=1
          ), '')
        BEGIN
            SELECT RAISE(ABORT, 'agent task enqueue requires canonical router generation');
        END;

        CREATE TRIGGER IF NOT EXISTS trg_agent_tasks_canonical_assignment
        BEFORE UPDATE OF assigned_agent ON agent_tasks
        WHEN NEW.assigned_agent IS NOT OLD.assigned_agent
         AND (
            qm_router_writer_generation() IS NULL
            OR qm_router_writer_generation()<>COALESCE((
                SELECT generation FROM router_writer_contract WHERE singleton=1
            ), '')
         )
        BEGIN
            SELECT RAISE(ABORT, 'agent task assignment requires canonical router generation');
        END;
        """
    )


def _router_writer_contract_from_conn(conn: sqlite3.Connection) -> dict[str, Any]:
    row = conn.execute(
        "SELECT * FROM router_writer_contract WHERE singleton=1"
    ).fetchone()
    stored = dict(row) if row is not None else None
    authorized = bool(
        _registry_writer_authorized()
        and stored is not None
        and stored["generation"] == ROUTER_WRITER_GENERATION
        and Path(stored["canonical_checkout_root"]).resolve()
        == CANONICAL_ROUTER_ROOT.resolve()
    )
    return {
        "authorized": authorized,
        "current_generation": ROUTER_WRITER_GENERATION,
        "checkout": _router_checkout_detail(),
        "stored": stored,
    }


def _minimum_lane_capabilities(agent_id: str) -> set[str]:
    required = set(AGENT_EXTRA_REQUIRED_CAPABILITIES.get(agent_id, set()))
    for task_type in AGENT_TASK_TYPE_LANES.get(agent_id, ()):
        required.update(TASK_TYPE_CAPABILITIES[task_type])
    return required


def _registry_contract_from_conn(conn: sqlite3.Connection) -> dict[str, Any]:
    rows = {
        str(row["agent_id"]): set(json.loads(row["capabilities_json"] or "[]"))
        for row in conn.execute("SELECT agent_id, capabilities_json FROM agent_registry").fetchall()
    }
    gaps = []
    for agent_id in sorted(AGENT_TASK_TYPE_LANES):
        required = _minimum_lane_capabilities(agent_id)
        actual = rows.get(agent_id, set())
        missing = sorted(required - actual)
        if missing:
            gaps.append({"agent_id": agent_id, "missing": missing, "required": sorted(required)})
    return {"ok": not gaps, "gaps": gaps}


def registry_contract(root: Path = DEFAULT_ROOT) -> dict[str, Any]:
    """Read-only report of live lane capabilities against the routing contract."""
    with closing(connect(root)) as conn:
        return _registry_contract_from_conn(conn)


def sync_default_registry(root: Path = DEFAULT_ROOT, claude_disabled_flag: Path = CLAUDE_DISABLED_FLAG) -> dict[str, Any]:
    claude_disabled_flag = _effective_claude_disabled_flag(root, claude_disabled_flag)
    if not _registry_writer_authorized():
        with closing(connect(root)) as conn:
            contract = _registry_contract_from_conn(conn)
            writer_contract = _router_writer_contract_from_conn(conn)
        return {
            "synced": [],
            "claude_disabled": claude_disabled_flag.exists(),
            "read_only": True,
            "reason": "linked_worktree_registry_reader",
            "checkout_root": str(ROUTER_CHECKOUT_ROOT),
            "contract": contract,
            "writer_contract": writer_contract,
        }
    now = farmctl.utc_now()
    changed: list[str] = []
    with closing(connect(root)) as conn:
        writer_contract = _router_writer_contract_from_conn(conn)
        if not writer_contract["authorized"]:
            raise RuntimeError(
                "canonical registry writer generation contract is not authorized: "
                + _json(writer_contract)
            )
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
        contract = _registry_contract_from_conn(conn)
        writer_contract = _router_writer_contract_from_conn(conn)
    return {
        "synced": changed,
        "claude_disabled": claude_disabled_flag.exists(),
        "read_only": False,
        "checkout_root": str(ROUTER_CHECKOUT_ROOT),
        "contract": contract,
        "writer_contract": writer_contract,
    }


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
    if task_type in REMOVED_TASK_TYPES:
        raise ValueError(REMOVED_TASK_TYPES[task_type])
    if task_type not in TASK_TYPE_CAPABILITIES:
        raise ValueError(f"unknown task_type: {task_type}")
    if state not in TASK_STATES:
        raise ValueError(f"unknown state: {state}")
    dir_err = _directory_artifact_error(artifact_path)
    if dir_err is not None:
        raise ValueError(f"{dir_err['reason']}: {dir_err['artifact_path']}")
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


def ensure_magic_precondition_task(
    root: Path,
    card_path: Path,
    precheck: dict[str, Any],
) -> dict[str, Any]:
    """Create one actionable, deduplicated task for a build magic blocker."""
    ea_id = str(precheck.get("ea_id") or "").strip()
    classification = str(precheck.get("classification") or "").strip()
    action = str(precheck.get("action") or "").strip()
    if not ea_id or not classification or bool(precheck.get("ready")):
        return {"enqueued": False, "reason": "magic_precondition_task_not_required"}

    with closing(connect(root)) as conn:
        for row in conn.execute(
            "SELECT id, state, payload_json FROM agent_tasks "
            "WHERE task_type='ops_issue' "
            "AND state IN ('BACKLOG','TODO','IN_PROGRESS','REVIEW')"
        ).fetchall():
            try:
                payload = json.loads(row["payload_json"] or "{}")
            except json.JSONDecodeError:
                continue
            if (
                payload.get("operation") == "governed_magic_precondition"
                and str(payload.get("ea_id") or "") == ea_id
            ):
                return {
                    "enqueued": False,
                    "idempotent": True,
                    "task_id": row["id"],
                    "state": row["state"],
                    "reason": "existing_open_magic_precondition_task",
                }

    safe_label = ea_id.lower()
    evidence_date = farmctl.utc_now()[:10]
    evidence_path = (
        ROUTER_CHECKOUT_ROOT
        / "docs" / "ops" / "evidence"
        / f"{evidence_date}_{safe_label}_governed_magic_precondition.json"
    )
    command = None
    if action == "GOVERNED_ALLOCATE":
        command = (
            "python tools/strategy_farm/governed_magic_allocator.py "
            f"--card \"{card_path}\" --max-eas 1 "
            f"--output \"{evidence_path}\""
        )
    payload = {
        "title": f"{ea_id} governed magic precondition: {classification}",
        "operation": "governed_magic_precondition",
        "ea_id": ea_id,
        "slug": precheck.get("slug"),
        "card_path": str(card_path),
        "classification": classification,
        "required_action": action,
        "target_symbols": list(precheck.get("target_symbols") or []),
        "diagnosis": {
            "active_magic_rows": precheck.get("active_magic_rows"),
            "retired_magic_rows": precheck.get("retired_magic_rows"),
            "total_magic_rows": precheck.get("total_magic_rows"),
            "ea_directory_exists": precheck.get("ea_directory_exists"),
        },
        "command": command,
        "expected_artifact": str(evidence_path),
        "acceptance": [
            "Use the governed allocator sequence: EA directory/card, CSV rows, resolver regeneration, verification.",
            "Never invent a magic outside ea_id*10000+slot and never revive a retired row.",
            "Leave the original build blocked until a fresh precheck proves active rows and resolver presence.",
        ],
        "required_capabilities": ["code", "ops"],
        "source": "farmctl build precheck",
    }
    return enqueue_task(
        root,
        "ops_issue",
        state="TODO",
        priority=75,
        required_capabilities=["code", "ops"],
        payload=payload,
    )


def _running_count(conn: sqlite3.Connection, agent_id: str) -> int:
    row = conn.execute(
        "SELECT COUNT(*) AS n FROM agent_tasks WHERE assigned_agent=? AND state='IN_PROGRESS'",
        (agent_id,),
    ).fetchone()
    return int(row["n"] if row else 0)


def _task_lease_key(task_id: str) -> str:
    return f"agent_task:{task_id}"


def _record_lease_event(conn: sqlite3.Connection, task_id: str, event_name: str, detail: dict[str, Any]) -> None:
    try:
        farmctl.event(conn, "agent_task", task_id, event_name, detail)
    except Exception:
        pass


def _acquire_task_lease(
    conn: sqlite3.Connection,
    task_id: str,
    agent_id: str,
    now_dt: dt.datetime,
) -> bool:
    now_iso = now_dt.isoformat(timespec="seconds")
    expires_iso = (now_dt + dt.timedelta(minutes=LEASE_TTL_MINUTES)).isoformat(timespec="seconds")
    task_key = _task_lease_key(task_id)
    try:
        acquired = agent_scopes.acquire_spawn_lease(conn, task_key, agent_id, now_iso, expires_iso)
    except Exception as exc:
        _record_lease_event(
            conn,
            task_id,
            "spawn_lease_error",
            {"agent_id": agent_id, "task_key": task_key, "error": repr(exc), "decision": "fail_open"},
        )
        return True
    if not acquired:
        _record_lease_event(
            conn,
            task_id,
            "spawn_lease_deferred",
            {"agent_id": agent_id, "task_key": task_key, "expires_after": now_iso},
        )
    return acquired


def _release_task_lease(conn: sqlite3.Connection, task_id: str) -> None:
    try:
        agent_scopes.release_spawn_lease(conn, _task_lease_key(task_id))
    except Exception as exc:
        _record_lease_event(
            conn,
            task_id,
            "spawn_lease_release_error",
            {"task_key": _task_lease_key(task_id), "error": repr(exc)},
        )


def release_stale_in_progress(root: Path = DEFAULT_ROOT, *, max_age_hours: int = STALE_IN_PROGRESS_HOURS) -> dict[str, Any]:
    """Release abandoned agent_tasks so one dead worker cannot consume capacity forever.

    Two release triggers:
    1. Task age > max_age_hours (unconditional, existing behaviour).
    2. Task age > LANE_HEARTBEAT_STALE_HOURS AND the assigned agent's lane heartbeat is
       missing or stale — the lane died without recovering, release sooner.
    """
    now = farmctl.utc_now()
    now_dt = dt.datetime.now(dt.UTC).replace(microsecond=0)
    age_cutoff = now_dt - dt.timedelta(hours=max_age_hours)
    hb_cutoff  = now_dt - dt.timedelta(hours=LANE_HEARTBEAT_STALE_HOURS)
    released: list[dict[str, Any]] = []
    with closing(connect(root)) as conn:
        conn.execute("BEGIN IMMEDIATE")
        rows = conn.execute(
            """
            SELECT * FROM agent_tasks
            WHERE state='IN_PROGRESS'
            ORDER BY updated_at ASC
            """,
        ).fetchall()
        for row in rows:
            updated_at_str: str = row["updated_at"] or ""
            try:
                updated_dt = dt.datetime.fromisoformat(updated_at_str)
                if updated_dt.tzinfo is None:
                    updated_dt = updated_dt.replace(tzinfo=dt.timezone.utc)
            except (ValueError, TypeError):
                updated_dt = dt.datetime.min.replace(tzinfo=dt.timezone.utc)

            age_expired = updated_dt < age_cutoff
            hb_stale = (
                updated_dt < hb_cutoff
                and _lane_heartbeat_stale(root, row["assigned_agent"] or "")
            )
            if not (age_expired or hb_stale):
                continue

            release_reason = "age_expired" if age_expired else "lane_heartbeat_stale"
            payload = json.loads(row["payload_json"] or "{}")
            history = list(payload.get("stale_releases") or [])
            history.append(
                {
                    "released_at": now,
                    "release_reason": release_reason,
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
            _release_task_lease(conn, row["id"])
            released.append(
                {
                    "task_id": row["id"],
                    "task_type": row["task_type"],
                    "assigned_agent": row["assigned_agent"],
                    "previous_updated_at": row["updated_at"],
                    "release_reason": release_reason,
                }
            )
        conn.commit()
    return {"released": released, "max_age_hours": max_age_hours}


def _lane_heartbeat_stale(root: Path, agent_id: str) -> bool:
    """Return True only if a heartbeat FILE EXISTS for this agent but is older than
    LANE_HEARTBEAT_STALE_HOURS.  Missing file = no data = treat lane as available
    (covers new deployments and factory-OFF states where the scheduler never fires)."""
    if not agent_id:
        return False
    hb_path = root / "state" / f"lane_{agent_id}_heartbeat.json"
    if not hb_path.exists():
        return False  # no prior evidence; don't block routing
    try:
        age_hours = (dt.datetime.now(dt.UTC).timestamp() - hb_path.stat().st_mtime) / 3600
        return age_hours > LANE_HEARTBEAT_STALE_HOURS
    except OSError:
        return False


def _declared_registry_capabilities(conn: sqlite3.Connection) -> set[str]:
    """Union of capabilities over ALL registry agents (incl. disabled ones), so
    a skill owned only by a temporarily-disabled lane keeps gating routing."""
    caps: set[str] = set()
    for row in conn.execute("SELECT capabilities_json FROM agent_registry").fetchall():
        try:
            caps |= set(json.loads(row["capabilities_json"] or "[]"))
        except (TypeError, ValueError):
            continue
    return caps


def _governed_routing_capabilities() -> set[str]:
    """Capabilities that remain routing requirements even if the live row drifts."""
    return {
        str(capability)
        for cfg in DEFAULT_AGENT_REGISTRY.values()
        for capability in cfg.get("capabilities", [])
    }


def _capability_profile_gap(conn: sqlite3.Connection, required: set[str]) -> dict[str, Any] | None:
    """Describe a structural gap when no declared lane can satisfy one task."""
    profiles: dict[str, list[str]] = {}
    for row in conn.execute(
        "SELECT agent_id, capabilities_json FROM agent_registry ORDER BY agent_id"
    ).fetchall():
        capabilities = set(json.loads(row["capabilities_json"] or "[]"))
        if required.issubset(capabilities):
            return None
        profiles[str(row["agent_id"])] = sorted(required - capabilities)
    return {
        "code": "ROUTER_CAPABILITY_UNROUTABLE",
        "required": sorted(required),
        "missing_by_agent": profiles,
    }


def _record_capability_warning(
    conn: sqlite3.Connection,
    task: sqlite3.Row,
    warning: dict[str, Any],
) -> None:
    """Persist one visible warning without changing queue age or priority."""
    try:
        payload = json.loads(task["payload_json"] or "{}")
    except (TypeError, json.JSONDecodeError):
        payload = {}
    if payload.get("router_capability_warning") == warning:
        return
    payload["router_capability_warning"] = warning
    conn.execute(
        "UPDATE agent_tasks SET payload_json=? WHERE id=? AND state IN ('BACKLOG', 'TODO')",
        (_json(payload), task["id"]),
    )
    _record_lease_event(conn, task["id"], "routing_capability_unroutable", warning)


def _human_lane_holder(conn: sqlite3.Connection, required: set[str]) -> str | None:
    """Name the human lane that alone can satisfy `required`, if any.

    A human lane is declared in the registry but has no worker process
    (``enabled=0`` / ``max_parallel=0``). The caller uses this to HOLD the task
    visibly rather than skipping it silently — the failure mode that made the
    blind agy video lane look like ordinary backlog for five weeks.

    The hold only applies when the task really needs the capability the human
    lane owns (``AGENT_EXTRA_REQUIRED_CAPABILITIES``). Without that guard every
    ordinary review/research ticket would be held for OWNER whenever the AI
    lanes are merely at capacity, because their requirements happen to be a
    subset of the human lane's declared set.
    """
    if not required:
        return None
    for row in conn.execute(
        "SELECT agent_id, capabilities_json FROM agent_registry ORDER BY agent_id"
    ).fetchall():
        agent_id = str(row["agent_id"])
        if agent_id not in HUMAN_LANES:
            continue
        owned = set(AGENT_EXTRA_REQUIRED_CAPABILITIES.get(agent_id, set()))
        if not (required & owned):
            continue
        capabilities = set(json.loads(row["capabilities_json"] or "[]"))
        if required.issubset(capabilities):
            return agent_id
    return None


def _record_human_lane_hold(
    conn: sqlite3.Connection,
    task: sqlite3.Row,
    hold: dict[str, Any],
) -> None:
    """Persist one visible hold without changing queue age or priority."""
    try:
        payload = json.loads(task["payload_json"] or "{}")
    except (TypeError, json.JSONDecodeError):
        payload = {}
    if payload.get("router_human_lane_hold") == hold:
        return
    payload["router_human_lane_hold"] = hold
    conn.execute(
        "UPDATE agent_tasks SET payload_json=? WHERE id=? AND state IN ('BACKLOG', 'TODO')",
        (_json(payload), task["id"]),
    )
    _record_lease_event(conn, task["id"], "routing_awaiting_human_lane", hold)


def _eligible_agents(conn: sqlite3.Connection, required: set[str], root: Path = DEFAULT_ROOT) -> list[sqlite3.Row]:
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
        if _lane_heartbeat_stale(root, row["agent_id"]):
            continue
        eligible.append(row)
    return eligible


def _quota_gate_decision(
    root: Path,
    task: sqlite3.Row,
    agent_id: str,
    *,
    enabled: bool | None,
    config_path: Path | None,
    state_path: Path | None,
    summary_path: Path | None,
) -> dict[str, Any]:
    enforce = (Path(root) == Path(DEFAULT_ROOT)) if enabled is None else bool(enabled)
    if agent_id not in quota_spawn_gate.GATED_AGENTS or not enforce:
        return {
            "allowed": True,
            "agent": agent_id,
            "reason": "quota_gate_not_applicable",
            "enforced": False,
        }
    try:
        task_payload = json.loads(task["payload_json"] or "{}")
    except (TypeError, json.JSONDecodeError):
        task_payload = {}
    decision = quota_spawn_gate.evaluate_spawn(
        agent_id,
        str(task["task_type"]),
        int(task["priority"]),
        config_path=config_path,
        state_path=state_path,
        summary_path=summary_path,
        payload=task_payload,
    )
    decision["enforced"] = True
    return decision


def route_once(
    root: Path = DEFAULT_ROOT,
    *,
    claude_disabled_flag: Path = CLAUDE_DISABLED_FLAG,
    quota_gate_enabled: bool | None = None,
    quota_config_path: Path | None = None,
    quota_state_path: Path | None = None,
    quota_summary_path: Path | None = None,
) -> RouteDecision:
    _require_canonical_router_command("route-once")
    sync_default_registry(root, claude_disabled_flag=claude_disabled_flag)
    release_stale_in_progress(root)
    now_dt = dt.datetime.now(dt.UTC).replace(microsecond=0)
    now = now_dt.isoformat()
    with closing(connect(root)) as conn:
        conn.execute("BEGIN IMMEDIATE")
        tasks = conn.execute(
            """
            SELECT * FROM agent_tasks
            WHERE state IN ('BACKLOG', 'TODO')
            ORDER BY priority DESC, updated_at ASC, created_at ASC
            """
        ).fetchall()
        if not tasks:
            conn.commit()
            return RouteDecision("", "", None, "no_routable_task")
        declared_caps = _declared_registry_capabilities(conn)
        governed_caps = _governed_routing_capabilities()
        skipped: list[str] = []
        capability_gaps: list[tuple[sqlite3.Row, dict[str, Any]]] = []
        human_lane_holds: list[tuple[sqlite3.Row, dict[str, Any]]] = []
        selected: tuple[sqlite3.Row, sqlite3.Row, set[str], dict[str, Any]] | None = None
        quota_blocked: list[dict[str, Any]] = []
        for task in tasks:
            required = set(json.loads(task["required_capabilities_json"] or "[]"))
            # required_skills gate routing too — for capabilities governed by
            # defaults even if the live registry has drifted (e.g. Gemini's
            # video_analysis). Routing was
            # skills-blind and put two OWNER video tickets on codex while
            # gemini was full (2026-07-07). Skills nobody declares
            # ("code-review", "gemini-output-review" on auto-created review
            # tasks) are descriptive metadata and must not make a task
            # unroutable. Declared-but-disabled lane => ticket waits rather
            # than falling to an incapable agent.
            skills = set(json.loads(task["required_skills_json"] or "[]"))
            required |= skills & (declared_caps | governed_caps)
            capability_gap = _capability_profile_gap(conn, required)
            if capability_gap is not None:
                _record_capability_warning(conn, task, capability_gap)
                capability_gaps.append((task, capability_gap))
                skipped.append(task["id"])
                continue
            agents = _eligible_agents(conn, required, root)
            if not agents:
                holder = _human_lane_holder(conn, required)
                if holder is not None:
                    hold = {
                        "code": "ROUTER_AWAITING_HUMAN_LANE",
                        "lane": holder,
                        "required": sorted(required),
                    }
                    _record_human_lane_hold(conn, task, hold)
                    human_lane_holds.append((task, hold))
                skipped.append(task["id"])
                continue
            chosen_agent: sqlite3.Row | None = None
            chosen_gate: dict[str, Any] | None = None
            for agent in agents:
                gate = _quota_gate_decision(
                    root,
                    task,
                    str(agent["agent_id"]),
                    enabled=quota_gate_enabled,
                    config_path=quota_config_path,
                    state_path=quota_state_path,
                    summary_path=quota_summary_path,
                )
                if gate.get("allowed"):
                    chosen_agent = agent
                    chosen_gate = gate
                    break
                quota_blocked.append({"task_id": task["id"], **gate})
                _record_lease_event(
                    conn,
                    task["id"],
                    "quota_gate_blocked",
                    {key: value for key, value in gate.items() if key != "metrics"},
                )
            if chosen_agent is None or chosen_gate is None:
                skipped.append(task["id"])
                continue
            if not _acquire_task_lease(conn, task["id"], chosen_agent["agent_id"], now_dt):
                skipped.append(task["id"])
                continue
            selected = (task, chosen_agent, required, chosen_gate)
            break
        if selected is None:
            conn.commit()
            if capability_gaps:
                gap_task, gap = capability_gaps[0]
                missing = ",".join(gap["required"])
                return RouteDecision(
                    gap_task["id"],
                    gap_task["task_type"],
                    None,
                    f"capability_unavailable:{missing}",
                )
            if human_lane_holds:
                # Reported ahead of the generic no_available_agent so an
                # unstaffed human lane never reads as "the AI seats are busy".
                hold_task, hold = human_lane_holds[0]
                return RouteDecision(
                    hold_task["id"],
                    hold_task["task_type"],
                    None,
                    f"awaiting_human_lane:{hold['lane']}",
                )
            first = tasks[0]
            reason = "quota_gate_blocked" if quota_blocked else "no_available_agent"
            return RouteDecision(first["id"], first["task_type"], None, reason)
        task, agent, required, gate = selected
        payload = json.loads(task["payload_json"] or "{}")
        payload.pop("router_capability_warning", None)
        payload.pop("router_human_lane_hold", None)
        payload["routed_at"] = now
        payload["required_capabilities"] = sorted(required)
        if gate.get("enforced"):
            payload["quota_gate"] = gate
            if gate.get("tier_escalation"):
                payload["quota_tier_escalation"] = gate["tier_escalation"]
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
    quota_gate_enabled: bool | None = None,
    quota_config_path: Path | None = None,
    quota_state_path: Path | None = None,
    quota_summary_path: Path | None = None,
) -> list[dict[str, Any]]:
    """Route up to `max_routes` waiting tickets.

    This is intentionally only a router. It moves tickets from BACKLOG/TODO to
    IN_PROGRESS for an eligible agent and respects each agent's max_parallel
    limit. Agent execution remains artifact-driven and separate.
    """
    _require_canonical_router_command("route-many")
    decisions: list[dict[str, Any]] = []
    for _ in range(max(0, max_routes)):
        decision = route_once(
            root,
            claude_disabled_flag=claude_disabled_flag,
            quota_gate_enabled=quota_gate_enabled,
            quota_config_path=quota_config_path,
            quota_state_path=quota_state_path,
            quota_summary_path=quota_summary_path,
        )
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
    _require_canonical_router_command("replenish")
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


def directed_research_targets(root: Path = DEFAULT_ROOT) -> dict[str, Any]:
    """DL-064 R-064-1: ranked empty (logic x market) cells of the robust sleeve pool.

    The "shopping list" for anticorrelated edges. Lazy-imports the portfolio matrix so the
    router still works if the portfolio package is unavailable.
    """
    try:
        import research_matrix
    except ModuleNotFoundError:
        try:
            from tools.strategy_farm import research_matrix
        except Exception as exc:  # pragma: no cover - defensive
            return {"available": False, "ranked_targets": [], "reason": f"matrix_unavailable:{exc}"}
    except Exception as exc:  # pragma: no cover - defensive
        return {"available": False, "ranked_targets": [], "reason": f"matrix_unavailable:{exc}"}
    try:
        sc = research_matrix.sleeve_coverage(
            db_path=farmctl.db_path(root),
            cards_dir=root / CARDS_APPROVED_REL,
        )
    except Exception as exc:  # pragma: no cover - defensive
        return {"available": False, "ranked_targets": [], "reason": f"matrix_error:{exc}"}
    return {
        "available": True,
        "ranked_targets": sc["ranked_targets"],
        "filled": sc["filled"],
        "n_sleeves": sc["n_sleeves"],
    }


def replenish_directed(
    root: Path = DEFAULT_ROOT,
    *,
    max_open_directed: int = 6,
    max_seed_per_run: int = 3,
    claude_disabled_flag: Path = CLAUDE_DISABLED_FLAG,
) -> dict[str, Any]:
    """DL-064 R-064-1: seed matrix-DIRECTED research for the most under-filled,
    anticorrelated portfolio cells (Forex / SeasonalVol are empty today).

    Replaces the frozen generic reservoir replenishment with targeted demand. Idempotent
    and self-limiting: at most one open task per empty cell, capped at max_open_directed
    total and max_seed_per_run per cycle, so running it every router tick is safe.
    """
    targets = directed_research_targets(root)
    if not targets.get("available"):
        return {"created": [], "skipped": [], "reason": targets.get("reason")}
    ranked = targets.get("ranked_targets") or []
    if not ranked:
        return {"created": [], "skipped": [], "reason": "no_empty_cells", "n_sleeves": targets.get("n_sleeves")}

    open_cells: set[tuple[str, str]] = set()
    with closing(connect(root)) as conn:
        for row in conn.execute(
            """
            SELECT payload_json FROM agent_tasks
            WHERE state IN ('BACKLOG', 'TODO', 'IN_PROGRESS', 'REVIEW')
              AND payload_json LIKE '%portfolio_matrix_directed_research%'
            """
        ).fetchall():
            try:
                p = json.loads(row["payload_json"] or "{}")
            except json.JSONDecodeError:
                continue
            open_cells.add((str(p.get("target_logic")), str(p.get("target_market"))))

    created: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    for t in ranked:
        if len(created) >= max_seed_per_run:
            break
        if (len(open_cells) + len(created)) >= max_open_directed:
            break
        cell = (t["logic"], t["market"])
        if cell in open_cells:
            skipped.append({"cell": cell, "reason": "already_open"})
            continue
        brief = (
            f"Find or mechanize a {t['logic']} strategy for {t['market']} markets "
            f"(DWX-testable) that is ANTICORRELATED to the current book "
            f"({targets.get('filled')}). Low parameter freedom, V5-framework-encodable, "
            f"no ML/grid/martingale, one position per magic. This fills an empty "
            f"portfolio diversification cell (DL-064 R-064-1)."
        )
        created.append(
            enqueue_task(
                root,
                "research_strategy",
                state="TODO",
                priority=70,
                required_capabilities=RESEARCH_PERSPECTIVES["gemini"]["required_capabilities"],
                payload={
                    "reason": "portfolio_matrix_directed_research",
                    "target_logic": t["logic"],
                    "target_market": t["market"],
                    "perspective": "portfolio_diversification_R064_1",
                    "brief": brief,
                },
            )
        )
    return {
        "created": created,
        "skipped": skipped,
        "open_before": len(open_cells),
        "ranked_targets": ranked,
        "n_sleeves": targets.get("n_sleeves"),
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
                # Operator convention is high=urgent; keep restart smoke ahead
                # of ordinary priority-50 work.
                priority=95,
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
    _require_canonical_router_command("run")
    registry = sync_default_registry(root, claude_disabled_flag=claude_disabled_flag)
    replenished = replenish(
        root,
        min_ready_strategy_cards=min_ready_strategy_cards,
        claude_disabled_flag=claude_disabled_flag,
    )
    # DL-064 R-064-1: matrix-directed research toward empty anticorrelated cells
    # (replaces the frozen generic replenishment). Idempotent + self-limiting.
    directed = replenish_directed(root, claude_disabled_flag=claude_disabled_flag)
    routed = route_many(root, max_routes=max_routes, claude_disabled_flag=claude_disabled_flag)
    return {
        "registry": registry,
        "replenish": replenished,
        "replenish_directed": directed,
        "routes": routed,
        "status": status(root),
    }


def status(root: Path = DEFAULT_ROOT, *, claude_disabled_flag: Path = CLAUDE_DISABLED_FLAG) -> dict[str, Any]:
    registry_sync = sync_default_registry(root, claude_disabled_flag=claude_disabled_flag)
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
        contract = _registry_contract_from_conn(conn)
    return {
        "agents": agents,
        "tasks": tasks,
        "registry_sync": registry_sync,
        "registry_contract": contract,
        "quota_headroom": quota_spawn_gate.read_headroom_summary(),
    }


def list_tasks(root: Path = DEFAULT_ROOT, agent_id: str | None = None, state: str | None = None) -> list[dict[str, Any]]:
    if state is not None and state not in TASK_STATES:
        raise ValueError(f"unknown state: {state}")
    with closing(connect(root)) as conn:
        query = "SELECT * FROM agent_tasks"
        params = []
        if agent_id:
            query += " WHERE assigned_agent = ?"
            params.append(agent_id)
        if state:
            query += " AND state = ?" if params else " WHERE state = ?"
            params.append(state)
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


def _normalize_card_ea_id(value: Any) -> str:
    text = str(value or "").strip()
    match = re.match(r"^(?:QM5_)?(\d+)$", text, re.IGNORECASE)
    if match:
        return match.group(1)
    return text.upper()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _git_result(cwd: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(cwd), *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )


def _git_root_for(path: Path) -> Path | None:
    result = _git_result(path.parent, "rev-parse", "--show-toplevel")
    if result.returncode != 0 or not result.stdout.strip():
        return None
    return Path(result.stdout.strip()).resolve()


def _tracked_clean_at_head(git_root: Path, path: Path) -> tuple[bool, str]:
    try:
        relative = path.resolve().relative_to(git_root).as_posix()
    except ValueError:
        return False, "outside_git_root"
    tracked = _git_result(git_root, "ls-files", "--error-unmatch", "--", relative)
    if tracked.returncode != 0:
        return False, "untracked"
    clean = _git_result(git_root, "diff", "--quiet", "HEAD", "--", relative)
    if clean.returncode != 0:
        return False, "not_committed_at_head"
    return True, relative


def _refuse_review(code: str, reason: str, **detail: Any) -> dict[str, Any]:
    return {"allowed": False, "gate_code": code, "reason": reason, **detail}


def _build_review_dispatch_gate(artifact_path: str | None) -> dict[str, Any]:
    """Fail closed before a Gemini build can mint a Codex review task.

    D1 rejects an explicit strict-build failure. D6 then requires the producer
    packet to bind committed MQ5/EX5/setfile bytes at the current Git HEAD.
    This is intentionally a review-dispatch gate: compile/build_check may
    regenerate EX5 bytes, after which the builder must commit the exact result
    before asking a reviewer to inspect it.
    """
    artifact = Path(str(artifact_path or ""))
    if not artifact.is_file() or artifact.suffix.lower() != ".json":
        return _refuse_review(
            "D6_BUILD_IDENTITY_MISSING",
            "build_identity_json_missing_review_dispatch_refused",
            artifact_path=str(artifact),
        )
    try:
        payload = json.loads(artifact.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        return _refuse_review(
            "D6_BUILD_IDENTITY_INVALID",
            "build_identity_json_invalid_review_dispatch_refused",
            artifact_path=str(artifact),
            detail=str(exc),
        )
    if not isinstance(payload, dict):
        return _refuse_review(
            "D6_BUILD_IDENTITY_INVALID",
            "build_identity_json_not_object_review_dispatch_refused",
            artifact_path=str(artifact),
        )

    build_check = payload.get("build_check")
    nested_fail = isinstance(build_check, dict) and (
        str(build_check.get("result") or build_check.get("status") or "").upper() == "FAIL"
        or (
            build_check.get("exit_code") is not None
            and str(build_check.get("exit_code")) not in {"0", "0.0"}
        )
    )
    if payload.get("build_check_passed") is False or nested_fail:
        return _refuse_review(
            "D1_STRICT_BUILD_FAIL",
            "strict_build_check_failed_review_dispatch_refused",
            artifact_path=str(artifact.resolve()),
        )
    if payload.get("build_check_passed") is not True:
        return _refuse_review(
            "D6_BUILD_IDENTITY_MISSING",
            "strict_build_pass_evidence_missing_review_dispatch_refused",
            artifact_path=str(artifact.resolve()),
        )

    raw_source_gate = raw_mq5_quarantine.check_source_path(
        str(payload.get("mq5_path") or ""),
        purpose="promotion",
        repo_root=CANONICAL_ROUTER_ROOT,
        # Git identity checks below bind committed canonical bytes. Keep this
        # layer narrowly focused on direct G:/quarantined-source provenance so
        # hermetic router tests can use an injectable Git root.
        enforce_canonical=False,
    )
    if not raw_source_gate.get("allowed"):
        return _refuse_review(
            str(raw_source_gate.get("code") or "RAW_MQ5_QUARANTINE_REFUSED"),
            "raw_mq5_quarantine_refused_review_dispatch",
            artifact_path=str(artifact.resolve()),
            raw_mq5_quarantine=raw_source_gate,
        )

    bound_specs = (
        ("mq5_path", "mq5_sha256"),
        ("ex5_path", "ex5_sha256"),
    )
    bound_paths: list[Path] = []
    for path_key, hash_key in bound_specs:
        raw_path = str(payload.get(path_key) or "").strip()
        expected_hash = str(payload.get(hash_key) or "").strip().lower()
        if not raw_path or not re.fullmatch(r"[0-9a-f]{64}", expected_hash):
            return _refuse_review(
                "D6_BUILD_IDENTITY_MISSING",
                "build_identity_path_or_hash_missing_review_dispatch_refused",
                missing_path_key=path_key if not raw_path else None,
                missing_hash_key=hash_key if not re.fullmatch(r"[0-9a-f]{64}", expected_hash) else None,
            )
        bound_path = Path(raw_path)
        if not bound_path.is_file():
            return _refuse_review(
                "D6_BUILD_IDENTITY_MISSING",
                "build_identity_bound_file_missing_review_dispatch_refused",
                bound_path=str(bound_path),
            )
        actual_hash = _sha256_file(bound_path)
        if actual_hash != expected_hash:
            return _refuse_review(
                "D6_BUILD_IDENTITY_HASH_MISMATCH",
                "build_identity_hash_mismatch_review_dispatch_refused",
                bound_path=str(bound_path.resolve()),
                expected_sha256=expected_hash,
                actual_sha256=actual_hash,
            )
        bound_paths.append(bound_path.resolve())

    git_root = _git_root_for(bound_paths[0])
    if git_root is None:
        return _refuse_review(
            "D6_BUILD_IDENTITY_UNTRACKED",
            "build_identity_git_root_missing_review_dispatch_refused",
            bound_path=str(bound_paths[0]),
        )
    for bound_path in bound_paths:
        ok, track_detail = _tracked_clean_at_head(git_root, bound_path)
        if not ok:
            return _refuse_review(
                "D6_BUILD_IDENTITY_UNTRACKED",
                "build_identity_not_committed_review_dispatch_refused",
                bound_path=str(bound_path),
                track_detail=track_detail,
            )

    setfiles = payload.get("setfiles_generated")
    if not isinstance(setfiles, list) or not setfiles:
        return _refuse_review(
            "D6_BUILD_IDENTITY_MISSING",
            "build_identity_setfiles_missing_review_dispatch_refused",
        )
    for raw_setfile in setfiles:
        setfile = Path(str(raw_setfile or "")).resolve()
        if not setfile.is_file():
            return _refuse_review(
                "D6_BUILD_IDENTITY_MISSING",
                "build_identity_setfile_missing_review_dispatch_refused",
                setfile=str(setfile),
            )
        try:
            set_text = setfile.read_text(encoding="utf-8-sig")
        except (OSError, UnicodeError) as exc:
            return _refuse_review(
                "D6_BUILD_IDENTITY_INVALID",
                "build_identity_setfile_unreadable_review_dispatch_refused",
                setfile=str(setfile),
                detail=str(exc),
            )
        if not re.search(r"(?im)^\s*;\s*build_hash\s*:\s*[0-9a-f]{64}\s*$", set_text):
            return _refuse_review(
                "D6_BUILD_HASH_MISSING",
                "build_hash_missing_review_dispatch_refused",
                setfile=str(setfile),
            )
        ok, track_detail = _tracked_clean_at_head(git_root, setfile)
        if not ok:
            return _refuse_review(
                "D6_BUILD_IDENTITY_UNTRACKED",
                "build_identity_setfile_not_committed_review_dispatch_refused",
                setfile=str(setfile),
                track_detail=track_detail,
            )

    head = _git_result(git_root, "rev-parse", "HEAD")
    return {
        "allowed": True,
        "gate_code": "BUILD_REVIEW_DISPATCH_PASS",
        "identity_commit": head.stdout.strip() if head.returncode == 0 else None,
        "artifact_path": str(artifact.resolve()),
    }


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
        dir_err = _directory_artifact_error(artifact_path)
        if dir_err is not None:
            return {"updated": False, "task_id": task_id, **dir_err}
        if row["task_type"] == "build_ea" and row["assigned_agent"] == "gemini" and state == "REVIEW":
            review_gate = _build_review_dispatch_gate(artifact_path or row["artifact_path"])
            if not review_gate["allowed"]:
                _record_lease_event(
                    conn,
                    task_id,
                    "review_dispatch_refused",
                    {
                        "requested_state": state,
                        "artifact_path": artifact_path or row["artifact_path"],
                        **review_gate,
                    },
                )
                conn.commit()
                return {"updated": False, "task_id": task_id, **review_gate}
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
                    ea_id_key = _normalize_card_ea_id(fm.get("ea_id"))
                    duplicate_ea_id_cards: list[str] = []
                    if ea_id_key:
                        for pool in (approved_dir, review_dir):
                            if not pool.exists():
                                continue
                            for candidate in pool.glob("*.md"):
                                if candidate.resolve() == resolved_artifact:
                                    continue
                                try:
                                    candidate_fm = farmctl.parse_card_frontmatter(candidate)
                                except Exception:
                                    continue
                                if _normalize_card_ea_id(candidate_fm.get("ea_id")) == ea_id_key:
                                    duplicate_ea_id_cards.append(str(candidate))
                    if duplicate_ea_id_cards:
                        return {
                            "updated": False,
                            "task_id": task_id,
                            "reason": "duplicate_strategy_card_ea_id",
                            "ea_id": fm.get("ea_id"),
                            "duplicates": duplicate_ea_id_cards[:8],
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
        if state in LEASE_RELEASE_STATES:
            _release_task_lease(conn, task_id)
        codex_review_task_id = None
        if row["task_type"] == "build_ea" and row["assigned_agent"] == "gemini" and state == "REVIEW":
            existing_review = conn.execute(
                """
                SELECT id FROM agent_tasks
                WHERE task_type='review_ea'
                  AND parent_id=?
                  AND state IN ('BACKLOG', 'TODO', 'IN_PROGRESS', 'REVIEW')
                ORDER BY created_at DESC
                LIMIT 1
                """,
                (task_id,),
            ).fetchone()
            if existing_review:
                codex_review_task_id = existing_review["id"]
            else:
                payload = json.loads(row["payload_json"] or "{}")
                review_payload = {
                    "reason": "codex_review_required_for_gemini_code",
                    "source_task_id": task_id,
                    "source_agent": "gemini",
                    "source_execution_backend": "agy",
                    "source_task_type": row["task_type"],
                    "source_artifact_path": artifact_path or row["artifact_path"],
                    "source_verdict": verdict,
                    "ea_id": payload.get("ea_id"),
                    "card_id": payload.get("card_id"),
                    "required_capabilities": ["code", "review"],
                }
                codex_review_task_id = str(uuid.uuid4())
                conn.execute(
                    """
                    INSERT INTO agent_tasks(
                        id, task_type, state, priority, required_capabilities_json,
                        required_skills_json, assigned_agent, budget_class, parent_id,
                        artifact_path, verdict, payload_json, created_at, updated_at
                    )
                    VALUES (?, 'review_ea', 'TODO', ?, ?, ?, NULL, ?, ?, ?, NULL, ?, ?, ?)
                    """,
                    (
                        codex_review_task_id,
                        int(row["priority"]) + 1,
                        _json(["code", "review"]),
                        _json(["code-review", "gemini-output-review"]),
                        row["budget_class"],
                        task_id,
                        artifact_path or row["artifact_path"],
                        _json(review_payload),
                        now,
                        now,
                    ),
                )
        conn.commit()
    return {
        "updated": True,
        "task_id": task_id,
        "state": state,
        "artifact_path": artifact_path,
        "verdict": verdict,
        "codex_review_task_id": codex_review_task_id,
    }


def _task_artifact_paths(root: Path, row: sqlite3.Row, artifact_path: str | None) -> list[Path]:
    """Every artifact a task cites, as absolute paths.

    Agents that produce several pieces of evidence record them as one
    semicolon-separated string. Treating that string as a single filename made
    every such task permanently unapprovable with reason 'artifact_missing' -
    four review_strategy tasks sat in REVIEW for two days that way, each with all
    of its artifacts present on disk.
    """
    candidate = artifact_path or row["artifact_path"]
    if not candidate:
        try:
            payload = json.loads(row["payload_json"] or "{}")
        except json.JSONDecodeError:
            payload = {}
        candidate = payload.get("closeout_artifact") or payload.get("expected_artifact")
    if not candidate:
        return []
    out = []
    for part in str(candidate).split(";"):
        part = part.strip()
        if not part:
            continue
        path = Path(part)
        if not path.is_absolute():
            path = farmctl.REPO_ROOT / path
        out.append(path)
    return out


def _task_artifact_path(root: Path, row: sqlite3.Row, artifact_path: str | None) -> Path | None:
    """The task's primary artifact - the first one it cites."""
    paths = _task_artifact_paths(root, row, artifact_path)
    return paths[0] if paths else None


try:
    from validate_build_guardrails import validate_path as _validate_build_guardrails
except ImportError:  # imported as a package (tools.strategy_farm.agent_router)
    from tools.strategy_farm.validate_build_guardrails import validate_path as _validate_build_guardrails


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
    if close_state == "APPROVED" and _is_safe_defer_verdict(verdict):
        return {
            "closed": False,
            "task_id": task_id,
            "reason": "safe_defer_must_be_blocked",
            "detail": "SAFE_DEFER records unfinished work and cannot use the APPROVED/PASSED path",
        }
    now = farmctl.utc_now()
    with closing(connect(root)) as conn:
        row = conn.execute("SELECT * FROM agent_tasks WHERE id=?", (task_id,)).fetchone()
        if not row:
            return {"closed": False, "task_id": task_id, "reason": "task_not_found"}
        if row["state"] != "REVIEW":
            return {"closed": False, "task_id": task_id, "reason": f"not_in_review:{row['state']}"}
        dir_err = _directory_artifact_error(artifact_path)
        if dir_err is not None:
            return {"closed": False, "task_id": task_id, **dir_err}
        all_evidence = _task_artifact_paths(root, row, artifact_path)
        evidence = all_evidence[0] if all_evidence else None
        if close_state == "APPROVED":
            if evidence is None:
                return {"closed": False, "task_id": task_id, "reason": "approval_requires_artifact"}
            missing = [p for p in all_evidence if not p.exists()]
            if missing:
                return {
                    "closed": False,
                    "task_id": task_id,
                    "reason": "artifact_missing",
                    "artifact_path": ";".join(str(p) for p in missing),
                }
            # Never hand a directory to the build guardrails: evidence.parent on a
            # directory artifact is the EAs root, which made validate_path walk the
            # whole framework/EAs tree and time out (census rank 9). Refuse here so
            # a pre-existing directory row cannot trip the scan on close.
            dir_evidence = [str(p) for p in all_evidence if p.is_dir()]
            if dir_evidence:
                return {
                    "closed": False,
                    "task_id": task_id,
                    "reason": "artifact_must_be_file_not_directory",
                    "artifact_path": ";".join(dir_evidence),
                    "detail": "point the artifact at a single evidence file, not the EA folder",
                }
            # Hard-Rule backstop: never approve a build that violates the deterministic
            # build guardrails - news-staleness bypass (qm_news_stale_max_hours > 336) or
            # RISK_PERCENT in a backtest set (must be RISK_FIXED). OWNER 2026-06-03.
            if row["task_type"] == "build_ea":
                gr = _validate_build_guardrails(Path(evidence).parent)
                if gr.get("verdict") != "PASS":
                    kinds = ",".join(sorted({f["kind"] for f in gr.get("findings", [])}))
                    return {
                        "closed": False,
                        "task_id": task_id,
                        "reason": "build_guardrails_failed",
                        "findings": kinds,
                        "detail": (f"refusing APPROVED: build guardrails failed ({kinds}). "
                                   f"Refresh the news calendar / use RISK_FIXED; do not weaken the checks."),
                    }

        payload = json.loads(row["payload_json"] or "{}")
        payload["review_closed_at"] = now
        payload["review_close_state"] = close_state
        payload["review_close_verdict"] = verdict
        if close_state == "RECYCLE":
            try:
                prior_recycle_count = max(0, int(payload.get("recycle_count") or 0))
            except (TypeError, ValueError):
                prior_recycle_count = 0
            payload["recycle_count"] = prior_recycle_count + 1
            payload["recycle_count_recorded_at_review"] = now
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
        _release_task_lease(conn, task_id)
        conn.commit()
    return {
        "closed": True,
        "task_id": task_id,
        "state": close_state,
        "verdict": verdict,
        "artifact_path": str(evidence) if evidence else artifact_path,
    }


def _task_ea_id(payload: dict[str, Any]) -> str | None:
    """The EA a task references, normalized to the 'QM5_<num>' work_items key."""
    raw = payload.get("ea_id") or payload.get("card_id")
    if not raw:
        return None
    m = re.search(r"(\d{3,6})", str(raw))
    return f"QM5_{m.group(1)}" if m else None


def _is_safe_defer_verdict(value: Any) -> bool:
    """Return true only for the explicit SAFE_DEFER verdict family."""
    text = str(value or "").strip().upper()
    return re.match(r"^SAFE(?:[\s_-]+)DEFER\b", text) is not None


def _ea_pipeline_verdict(conn: sqlite3.Connection, ea_id: str | None) -> str | None:
    """The pipeline's closing verdict for an EA, READ from work_items — never
    manufactured (Hard Rule: pipeline verdicts come only from the pipeline).

    PASS wins over FAIL when both exist (a later full-history PASS supersedes an
    earlier fail). Returns None while the EA is still in flight — no closing-phase
    (Q10/P8) terminal row — so an in-flight PIPELINE task is LEFT in place rather
    than forced to a verdict it has not earned.
    """
    if not ea_id:
        return None
    placeholders = ",".join("?" for _ in CLOSING_PIPELINE_PHASES)
    for want in ("PASS", "FAIL"):
        try:
            row = conn.execute(
                f"""
                SELECT 1 FROM work_items
                WHERE ea_id=? AND phase IN ({placeholders})
                  AND status='done' AND verdict=? LIMIT 1
                """,
                (ea_id, *CLOSING_PIPELINE_PHASES, want),
            ).fetchone()
        except sqlite3.OperationalError:
            return None  # work_items table absent (never in production) -> in flight
        if row:
            return want
    return None


def _ea_has_work_items(conn: sqlite3.Connection, ea_id: str) -> bool:
    """Whether the EA has ANY work_items row at all (not merely a closing verdict).

    Distinguishes "legitimately in flight" (has rows, none closing yet) from
    "structurally orphaned" (no rows were ever created for this EA, so no
    pipeline activity can ever produce a closing verdict) -- the latter is a
    permanent limbo unless dispositioned, not a transient in-flight state.
    """
    try:
        row = conn.execute("SELECT 1 FROM work_items WHERE ea_id=? LIMIT 1", (ea_id,)).fetchone()
    except sqlite3.OperationalError:
        return True  # table absent (never in production) -> don't manufacture a false BLOCKED
    return row is not None


def _compute_task_exit(
    conn: sqlite3.Connection, row: sqlite3.Row
) -> tuple[str | None, str, dict[str, Any]]:
    """Deterministic, type-aware exit for a limbo-state task.

    Returns (target_state, reason, payload_updates); target_state None means
    "leave in place" (a legitimately in-flight PIPELINE row, or a non-limbo row).
    See PIPELINE_BOUND_TASK_TYPES / RECYCLE_MAX_ATTEMPTS for the contract mapping.
    """
    state = row["state"]
    task_type = row["task_type"]
    try:
        payload = json.loads(row["payload_json"] or "{}")
    except (TypeError, json.JSONDecodeError):
        payload = {}

    # Retired task type (pipeline_run): give the orphan row a terminal home
    # instead of leaving it structurally unroutable (census rank 12).
    if task_type in REMOVED_TASK_TYPES:
        return "BLOCKED", "pipeline_run_retired_not_agent_lane", {}

    if state == "APPROVED":
        review_verdict = row["verdict"] or payload.get("review_close_verdict")
        if _is_safe_defer_verdict(review_verdict):
            return (
                "BLOCKED",
                "approved_safe_defer_not_completed",
                {"safe_defer_reclassified": True},
            )
        if task_type in PIPELINE_BOUND_TASK_TYPES:
            return "PIPELINE", "approved_build_handed_to_pipeline", {}
        # research / review / ops / triage: APPROVED already IS the accepted
        # verdict; there is no further MT5 pipeline, so PASSED is the terminal.
        return "PASSED", "approved_accepted_terminal", {}

    if state == "PIPELINE":
        ea_id = _task_ea_id(payload)
        if ea_id is None:
            # No ea_id/card_id the pipeline could ever bind a verdict to --
            # this row can never resolve via _ea_pipeline_verdict. Named
            # terminal instead of eternal "in flight".
            return "BLOCKED", "pipeline_no_ea_binding", {}
        verdict = _ea_pipeline_verdict(conn, ea_id)
        if verdict == "PASS":
            return "PASSED", "pipeline_closing_verdict_pass", {}
        if verdict == "FAIL":
            return "FAILED", "pipeline_closing_verdict_fail", {}
        if not _ea_has_work_items(conn, ea_id):
            # Has a resolvable ea_id but the pipeline never created a single
            # work_items row for it -- nothing is running that could ever
            # produce a closing verdict. Structurally orphaned, not in flight.
            return "BLOCKED", "pipeline_no_work_items", {}
        return None, "pipeline_in_flight_no_closing_verdict", {}

    if state == "RECYCLE":
        recycle_count = int(payload.get("recycle_count") or 0)
        counted_at_review = (
            payload.get("recycle_count_recorded_at_review")
            and payload.get("recycle_count_recorded_at_review") == payload.get("review_closed_at")
        )
        if recycle_count > RECYCLE_MAX_ATTEMPTS or (
            recycle_count >= RECYCLE_MAX_ATTEMPTS and not counted_at_review
        ):
            # Bounded: a permanently unbuildable card cannot loop forever.
            return "BLOCKED", "recycle_attempts_exhausted", {}
        if counted_at_review:
            return "TODO", "recycle_requeue", {}
        return "TODO", "recycle_requeue", {"recycle_count": recycle_count + 1}

    return None, "not_a_limbo_state", {}


def reconcile_task_exits(
    root: Path = DEFAULT_ROOT,
    *,
    apply: bool = False,
    limit: int | None = None,
    states: tuple[str, ...] | list[str] | None = None,
    task_ids: tuple[str, ...] | list[str] | None = None,
) -> dict[str, Any]:
    """Give the three no-exit limbo states their contractual exit (census ranks
    4/5/8). DRY-RUN by default: it reports what WOULD move and moves nothing.

    It is deliberately NOT wired into the autonomous run_once tick. RECYCLE->TODO
    re-queues 411 build_ea rows into the build lane — a mass requeue and an OWNER
    capacity decision — and even the terminal APPROVED->PASSED reclassification
    of ~200 rows must be a visible, opted-in action, not a silent side effect of
    a routing tick. Detection (health invariant) runs continuously; remediation
    is an explicit operator call. Bound it with `limit`, `states`, and optionally
    an exact `task_ids` selection when applying so a single run cannot flood a
    lane or requeue a row the caller classified as already gated.
    """
    target_states = tuple(states) if states else LIMBO_STATES
    selected_task_ids = tuple(dict.fromkeys(task_ids or ()))
    for s in target_states:
        if s not in LIMBO_STATES:
            raise ValueError(f"reconcile state must be one of {LIMBO_STATES}: {s}")
    now = farmctl.utc_now()
    moved: list[dict[str, Any]] = []
    would_move: dict[str, int] = {}
    left_in_place: dict[str, int] = {}
    placeholders = ",".join("?" for _ in target_states)
    with closing(connect(root)) as conn:
        if apply:
            conn.execute("BEGIN IMMEDIATE")
        task_filter = ""
        params: tuple[Any, ...] = tuple(target_states)
        if selected_task_ids:
            task_filter = " AND id IN (" + ",".join("?" for _ in selected_task_ids) + ")"
            params += selected_task_ids
        rows = conn.execute(
            f"SELECT * FROM agent_tasks WHERE state IN ({placeholders}){task_filter} "
            "ORDER BY state, updated_at ASC",
            params,
        ).fetchall()
        n_applied = 0
        for row in rows:
            target, reason, payload_updates = _compute_task_exit(conn, row)
            if target is None:
                left_in_place[reason] = left_in_place.get(reason, 0) + 1
                continue
            key = f"{row['state']}->{target}:{reason}"
            would_move[key] = would_move.get(key, 0) + 1
            if not apply or (limit is not None and n_applied >= limit):
                continue
            try:
                payload = json.loads(row["payload_json"] or "{}")
            except (TypeError, json.JSONDecodeError):
                payload = {}
            payload.update(payload_updates)
            identity = work_identity.agent_task_identity(conn, row)
            history = list(payload.get("exit_reconciliations") or [])
            history.append(
                {
                    "reconciled_at": now,
                    "from_state": row["state"],
                    "to_state": target,
                    "reason": reason,
                    "work_identity_key": identity["stable_key"],
                }
            )
            payload.setdefault("work_identity", identity)
            payload["exit_reconciliations"] = history[-5:]
            conn.execute(
                "UPDATE agent_tasks SET state=?, payload_json=?, updated_at=? WHERE id=? AND state=?",
                (target, _json(payload), now, row["id"], row["state"]),
            )
            _release_task_lease(conn, row["id"])
            n_applied += 1
            moved.append(
                {
                    "task_id": row["id"],
                    "task_type": row["task_type"],
                    "from_state": row["state"],
                    "to_state": target,
                    "reason": reason,
                    "work_identity_key": identity["stable_key"],
                }
            )
        if apply:
            conn.commit()
    return {
        "apply": apply,
        "limit": limit,
        "states": list(target_states),
        "task_ids": list(selected_task_ids),
        "would_move": would_move,
        "left_in_place": left_in_place,
        "moved_count": len(moved),
        "moved": moved[:50],
    }


def _portfolio_admission_key(ea_id: str, symbol: str) -> tuple[int, str] | None:
    """work_items ea_id 'QM5_10692' + symbol 'NDX.DWX' -> (10692, 'NDX.DWX').
    Note: match QM5_(\\d+), NOT \\d+ (the latter grabs the 5 in 'QM5')."""
    m = re.search(r"QM5_(\d+)", str(ea_id))
    sym = str(symbol).strip()
    if not m or not sym:
        return None
    return int(m.group(1)), sym


def sync_q11_candidates(root: Path = DEFAULT_ROOT, *, apply_admission: bool = True) -> dict[str, Any]:
    """Promote Q10 PASS work_items into the Q11 portfolio-candidate book.

    DL-064 R-064-2: this is the real portfolio gate, not "≥1 symbol passed =
    candidate". A Q10 passer is admitted ONLY if portfolio_admission judges it
    diversifying vs the current book (low correlation AND it improves portfolio
    Sharpe or max-DD); the first sleeve is admitted unconditionally. Non-
    diversifying passers are recorded as DIVERSIFICATION_REJECTED (visible, not
    silently dropped); evaluation errors (e.g. missing q08 stream) land as
    ADMISSION_DEFERRED and are retried next sync. Pass apply_admission=False
    (CLI --no-admission) to fall back to the legacy mirror-all behaviour.
    """
    now = farmctl.utc_now()
    created = 0
    existing = 0
    admitted = 0
    rejected = 0
    deferred = 0
    admission = None
    if apply_admission:
        try:
            from portfolio import portfolio_admission as admission  # type: ignore
        except ImportError:  # pragma: no cover
            from tools.strategy_farm.portfolio import portfolio_admission as admission  # type: ignore

    with closing(connect(root)) as conn:
        # Seed the book with already-admitted candidates so new passers evaluate
        # against (and grow) the real book.
        book: list[tuple[int, str]] = []
        if apply_admission:
            for r in conn.execute(
                "SELECT DISTINCT ea_id, symbol FROM portfolio_candidates WHERE state='Q12_REVIEW_READY'"
            ).fetchall():
                key = _portfolio_admission_key(r["ea_id"], r["symbol"])
                if key:
                    book.append(key)

        rows = conn.execute(
            """
            SELECT id, ea_id, COALESCE(symbol, '') AS symbol, evidence_path, payload_json
            FROM work_items
            WHERE phase IN ('Q10', 'P8') AND status='done' AND verdict='PASS'
            ORDER BY updated_at DESC
            """
        ).fetchall()
        for row in rows:
            cur = conn.execute(
                "SELECT 1 FROM portfolio_candidates WHERE ea_id=? AND symbol=? AND q11_work_item_id=?",
                (row["ea_id"], row["symbol"], row["id"]),
            ).fetchone()
            if cur:
                existing += 1
                conn.execute(
                    "UPDATE portfolio_candidates SET evidence_path=COALESCE(?, evidence_path), "
                    "updated_at=? WHERE ea_id=? AND symbol=? AND q11_work_item_id=?",
                    (row["evidence_path"], now, row["ea_id"], row["symbol"], row["id"]),
                )
                continue

            state = "Q12_REVIEW_READY"
            reason = "legacy_mirror_all"
            if apply_admission:
                key = _portfolio_admission_key(row["ea_id"], row["symbol"])
                if key is None:
                    state, reason = "ADMISSION_DEFERRED", "unparseable_ea_id"
                    deferred += 1
                else:
                    try:
                        try:
                            payload = json.loads(row["payload_json"] or "{}")
                        except json.JSONDecodeError:
                            payload = {}
                        verdict = admission.evaluate_candidate(key, book, lineage_payload=payload)
                        reason = str(verdict.get("reason", ""))
                        if verdict.get("admit"):
                            state = "Q12_REVIEW_READY"
                            book.append(key)
                            admitted += 1
                        else:
                            state = "DIVERSIFICATION_REJECTED"
                            rejected += 1
                    except Exception as exc:  # never crash the sync on one bad candidate
                        state, reason = "ADMISSION_DEFERRED", f"admission_error:{exc!r}"[:160]
                        deferred += 1
                farmctl.event(conn, "portfolio_admission", str(row["ea_id"]),
                              state, {"symbol": row["symbol"], "reason": reason})

            conn.execute(
                """
                INSERT INTO portfolio_candidates(
                    ea_id, symbol, q11_work_item_id, state, evidence_path,
                    first_seen_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (row["ea_id"], row["symbol"], row["id"], state, row["evidence_path"], now, now),
            )
            created += 1
        conn.commit()
    return {
        "q11_pass_rows": len(rows),
        "created": created,
        "existing": existing,
        "admitted": admitted,
        "rejected": rejected,
        "deferred": deferred,
        "apply_admission": apply_admission,
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
    list_tasks_p.add_argument("--state", choices=sorted(TASK_STATES), help="Filter by task state")
    sub.add_parser("replenish")
    route_many_p = sub.add_parser("route-many")
    route_many_p.add_argument("--max-routes", type=int, default=5)
    run = sub.add_parser("run")
    run.add_argument("--min-ready-strategy-cards", type=int, default=5)
    run.add_argument("--max-routes", type=int, default=5)
    enqueue = sub.add_parser("enqueue")
    enqueue.add_argument("task_type", choices=sorted(TASK_TYPE_CAPABILITIES))
    enqueue.add_argument(
        "--priority",
        type=int,
        default=50,
        help="Task urgency; higher values route earlier (default: 50)",
    )
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
    reconcile = sub.add_parser(
        "reconcile-exits",
        help="Report/apply contractual exits for the RECYCLE/APPROVED/PIPELINE limbo states (dry-run by default)",
    )
    reconcile.add_argument("--apply", action="store_true", help="Perform the transitions (default: dry-run report only)")
    reconcile.add_argument("--limit", type=int, default=None, help="Max rows to move in one run (bounds a lane flood)")
    reconcile.add_argument(
        "--state",
        action="append",
        choices=sorted(LIMBO_STATES),
        help="Restrict to these limbo states (repeatable); default all three",
    )
    reconcile.add_argument(
        "--task-id",
        action="append",
        help="Restrict to these exact task UUIDs (repeatable)",
    )
    sync_q11 = sub.add_parser("sync-q11-candidates")
    sync_q11.add_argument("--no-admission", action="store_true",
                          help="legacy mirror-all (skip the DL-064 R-064-2 diversification gate)")
    update = sub.add_parser("update-task")
    update.add_argument("task_id")
    update.add_argument("--state", required=True, choices=sorted(TASK_STATES))
    update.add_argument("--artifact-path")
    update.add_argument("--verdict")
    args = parser.parse_args(argv)

    if args.command in ROUTER_MUTATING_COMMANDS:
        try:
            _require_canonical_router_command(args.command)
        except RouterCheckoutError as exc:
            print(json.dumps({
                "refused": True,
                "reason": "noncanonical_router_checkout",
                "command": exc.command,
                **exc.detail,
            }, indent=2, sort_keys=True))
            return 2

    if args.command == "init":
        result = sync_default_registry(args.root)
    elif args.command == "status":
        result = status(args.root)
    elif args.command == "list-tasks":
        result = list_tasks(args.root, agent_id=args.agent, state=args.state)
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
    elif args.command == "reconcile-exits":
        result = reconcile_task_exits(
            args.root,
            apply=args.apply,
            limit=args.limit,
            states=args.state,
            task_ids=args.task_id,
        )
    elif args.command == "sync-q11-candidates":
        result = sync_q11_candidates(args.root, apply_admission=not args.no_admission)
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
    # 2026-08-16: a REFUSED mutation used to exit 0. close_review_task and
    # update_task report refusal in-band ({"closed": false, "reason": ...} /
    # {"updated": false, "reason": "task_not_found"}), so a caller that checked
    # only the exit code was told a state change had happened when it had not.
    # This bit a bulk closure of 53 build_ea reviews (every one refused with
    # artifact_missing, all reported as success) and a mistyped task id on the
    # same day. Refusal is now an exit code, not just a field.
    if isinstance(result, dict):
        for key in ("closed", "updated", "enqueued"):
            if key in result and result.get(key) is False:
                return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
