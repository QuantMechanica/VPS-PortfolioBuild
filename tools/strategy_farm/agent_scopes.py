"""agent_scopes.py — fail-closed agent capability enforcement + audit (DL-065).

Router `capabilities` decide *what work to route*; these scopes decide *what
tools may fire*, fail-closed, under a declared agent identity, with every
decision written to one audit trail.

Policy data: framework/registry/agent_capabilities.json (authored by Claude/OWNER;
do NOT mutate grants from code). See decisions/DL-065_agent_capability_scopes_audit.md.

Core invariants:
  * Unknown agent or unknown/ungranted scope -> DENY (default-deny).
  * `deny_explicit` ALWAYS beats `grants`.
  * Broken/missing policy file -> deny every scope except `repo.read`
    (so read-only diagnostics still work), with a loud audit event.
  * Every `require()` call writes exactly one `agent_audit` event.
"""

from __future__ import annotations

import json
import os
import sqlite3
from pathlib import Path
from typing import Any

try:
    from sqlite_busy import (
        BUSY_TIMEOUT_MS,
        configure_connection as configure_sqlite_connection,
        retry_sqlite_busy,
    )
except ModuleNotFoundError:
    from tools.strategy_farm.sqlite_busy import (
        BUSY_TIMEOUT_MS,
        configure_connection as configure_sqlite_connection,
        retry_sqlite_busy,
    )

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_POLICY_PATH = REPO_ROOT / "framework" / "registry" / "agent_capabilities.json"

# Scope allowed even when the policy file is missing/unparseable (fail-closed
# still lets pure read diagnostics through).
_SAFE_SCOPE_ON_POLICY_ERROR = "repo.read"


class ScopeDenied(PermissionError):
    """Raised when an agent identity lacks the required scope."""

    def __init__(self, agent_id: str, scope: str, tool: str) -> None:
        self.agent_id = agent_id
        self.scope = scope
        self.tool = tool
        super().__init__(f"agent {agent_id!r} is not allowed scope {scope!r} (tool={tool!r})")


class Policy:
    """Parsed capability policy. `broken` is True if the file could not be read."""

    def __init__(self, data: dict[str, Any] | None, *, broken: bool = False) -> None:
        self._agents: dict[str, dict[str, Any]] = (data or {}).get("agents", {}) if data else {}
        self.broken = broken

    def grants(self, agent_id: str) -> tuple[set[str], set[str]] | None:
        """Return (grants, deny_explicit) for agent_id, or None if unknown."""
        agent = self._agents.get(agent_id)
        if agent is None:
            return None
        return set(agent.get("grants", [])), set(agent.get("deny_explicit", []))


def load_policy(path: str | Path = DEFAULT_POLICY_PATH) -> Policy:
    """Load the capability policy. On any read/parse error return a `broken`
    policy (which denies everything except the safe read scope)."""
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        if not isinstance(data, dict) or "agents" not in data:
            return Policy(None, broken=True)
        return Policy(data)
    except (OSError, ValueError):
        return Policy(None, broken=True)


def is_allowed(agent_id: str, scope: str, policy: Policy | None = None) -> bool:
    """True iff `agent_id` holds `scope`. Fail-closed: unknown agent/scope -> False,
    `deny_explicit` beats `grants`, broken policy -> only `repo.read`."""
    pol = policy if policy is not None else load_policy()
    if pol.broken:
        return scope == _SAFE_SCOPE_ON_POLICY_ERROR
    g = pol.grants(agent_id)
    if g is None:
        return False  # unknown agent
    grants, deny = g
    if scope in deny:
        return False  # explicit deny always wins
    return scope in grants


def _file_backed_audit_connection(conn: Any) -> sqlite3.Connection | None:
    """Open an autonomous connection to ``conn``'s main database when possible.

    A scope denial normally raises through the caller's transaction.  Writing
    the audit event on that same connection would therefore roll the DENY row
    back with the rejected operation.  A separate file-backed connection gives
    the audit event its own commit without committing any caller work.

    Mock connections and private in-memory databases have no reopenable main
    database.  They retain the legacy same-connection behavior, which is useful
    for isolated unit tests and never applies to the production farm database.
    """
    try:
        rows = conn.execute("PRAGMA database_list").fetchall()
    except Exception:
        return None
    for row in rows:
        try:
            name, filename = str(row[1]), str(row[2])
        except (IndexError, KeyError, TypeError):
            continue
        if name != "main" or not filename:
            continue
        durable = sqlite3.connect(filename, timeout=BUSY_TIMEOUT_MS / 1000.0)
        durable.row_factory = sqlite3.Row
        return configure_sqlite_connection(durable)
    return None


def _audit(agent_id: str, scope: str, *, tool: str, args_summary: str,
           decision: str, conn: Any | None = None) -> None:
    """Append one durable ``agent_audit`` event via the farmctl primitive.

    File-backed caller connections are never used as the audit transaction:
    the event is written and committed through an autonomous connection so a
    subsequent caller rollback cannot erase a DENY.  Imported lazily to avoid
    an import cycle.  Audit failures never block the authorization decision.
    """
    detail = {"tool": tool, "args_summary": args_summary, "decision": decision}
    try:
        import farmctl  # type: ignore
    except ImportError:  # pragma: no cover - alt import path when run as a module
        from tools.strategy_farm import farmctl  # type: ignore
    try:
        if conn is not None:
            durable = _file_backed_audit_connection(conn)
            if durable is None:
                farmctl.event(conn, "agent_audit", agent_id, scope, detail)
                return
            try:
                def _write_durable() -> None:
                    farmctl.event(durable, "agent_audit", agent_id, scope, detail)
                    durable.commit()

                retry_sqlite_busy(_write_durable)
            finally:
                durable.close()
            return
        own = farmctl.connect(farmctl.DEFAULT_ROOT)
        try:
            def _write_own() -> None:
                farmctl.event(own, "agent_audit", agent_id, scope, detail)
                own.commit()

            retry_sqlite_busy(_write_own)
        finally:
            own.close()
    except Exception:  # pragma: no cover - audit must never crash the guard
        pass


def current_agent_id() -> str:
    """Acting identity from QM_AGENT_ID; absent -> 'unknown' (fail-closed)."""
    return os.environ.get("QM_AGENT_ID", "unknown")


# Identities that are the trusted deterministic base, NOT spawned agents: the
# farmctl/pump controller and the OWNER. Unset/unknown callers fail closed.
_TRUSTED_BASE = {"controller", "owner"}


def guarded_db_delete(conn: Any, sql: str, params: tuple = (), *,
                      tool: str, args_summary: str = "") -> int:
    """Sanctioned db.delete path (DL-065). Fail-closed guard, then execute the
    DELETE. Spawned agents without the scope raise ScopeDenied; controller passes.
    Returns rowcount. Raw `conn.execute("DELETE ...")` should migrate to this."""
    guard("db.delete", tool=tool, args_summary=args_summary or sql[:80], conn=conn)
    cur = conn.execute(sql, params)
    return cur.rowcount


def _ensure_spawn_lease_schema(conn: Any) -> None:
    """Create/upgrade the coordination table without invalidating old callers.

    ``task_key`` remains the exclusion key.  The added owner tuple makes a
    lease belong to one concrete session instead of the broad agent lane, so a
    second ``claude`` process cannot renew or release the first one's lease.
    """
    conn.execute(
        """CREATE TABLE IF NOT EXISTS spawn_leases (
            task_key TEXT PRIMARY KEY, agent_id TEXT NOT NULL,
            acquired_at TEXT NOT NULL, expires_at TEXT NOT NULL,
            owner_token TEXT, owner_pid INTEGER, owner_host TEXT,
            renewed_at TEXT)"""
    )
    existing = {str(row[1]) for row in conn.execute("PRAGMA table_info(spawn_leases)")}
    for name, sql_type in (
        ("owner_token", "TEXT"),
        ("owner_pid", "INTEGER"),
        ("owner_host", "TEXT"),
        ("renewed_at", "TEXT"),
    ):
        if name not in existing:
            try:
                conn.execute(f"ALTER TABLE spawn_leases ADD COLUMN {name} {sql_type}")
            except sqlite3.OperationalError:
                # Another controller may have completed the same idempotent
                # migration after our PRAGMA snapshot.
                refreshed = {
                    str(row[1]) for row in conn.execute("PRAGMA table_info(spawn_leases)")
                }
                if name not in refreshed:
                    raise


def acquire_spawn_lease(conn: Any, task_key: str, agent_id: str, now_iso: str,
                        expires_iso: str, *, owner_token: str | None = None,
                        owner_pid: int | None = None,
                        owner_host: str | None = None,
                        fail_open_on_error: bool = True) -> bool:
    """R-065-3 claim/lease: prevent two spawn paths doing the same work (the
    Task-E duplication). Returns True if the lease was acquired, False if a live
    (non-expired) lease for task_key already exists. Caller passes timestamps so
    the function stays deterministic/testable.

    Task-router callers retain the historical fail-open behavior on storage
    errors. Headless-session callers pass ``fail_open_on_error=False`` because
    uncertainty there must refuse a duplicate controller. Every error emits a
    best-effort audit event.
    """
    try:
        _ensure_spawn_lease_schema(conn)
        cursor = conn.execute(
            """INSERT INTO spawn_leases(
                   task_key, agent_id, acquired_at, expires_at,
                   owner_token, owner_pid, owner_host, renewed_at
               ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT(task_key) DO UPDATE SET
                   agent_id=excluded.agent_id,
                   acquired_at=excluded.acquired_at,
                   expires_at=excluded.expires_at,
                   owner_token=excluded.owner_token,
                   owner_pid=excluded.owner_pid,
                   owner_host=excluded.owner_host,
                   renewed_at=excluded.renewed_at
               WHERE spawn_leases.expires_at <= excluded.acquired_at""",
            (
                task_key,
                agent_id,
                now_iso,
                expires_iso,
                owner_token,
                owner_pid,
                owner_host,
                now_iso,
            ),
        )
        return bool(cursor.rowcount)
    except Exception as exc:  # pragma: no cover - exercised by caller-safety tests
        error_mode = "FAIL_OPEN" if fail_open_on_error else "FAIL_CLOSED"
        _audit(agent_id, "spawn.lease", tool="acquire_spawn_lease",
               args_summary=f"{task_key} [LEASE_ERROR_{error_mode}:{exc!r}]",
               decision="ALLOW" if fail_open_on_error else "DENY", conn=conn)
        return bool(fail_open_on_error)


def renew_spawn_lease(conn: Any, task_key: str, *, owner_token: str,
                      owner_pid: int, owner_host: str, now_iso: str,
                      expires_iso: str) -> bool:
    """Renew only the exact live session owner; foreign/stale owners refuse."""
    try:
        _ensure_spawn_lease_schema(conn)
        cursor = conn.execute(
            """UPDATE spawn_leases
               SET expires_at=?, renewed_at=?
               WHERE task_key=? AND owner_token=? AND owner_pid=? AND owner_host=?
                 AND expires_at > ?""",
            (expires_iso, now_iso, task_key, owner_token, owner_pid, owner_host, now_iso),
        )
        return bool(cursor.rowcount)
    except Exception as exc:  # coordination failure must stop an owner refresh
        _audit(
            "controller",
            "spawn.lease",
            tool="renew_spawn_lease",
            args_summary=f"{task_key} [LEASE_ERROR_FAIL_CLOSED:{exc!r}]",
            decision="DENY",
            conn=conn,
        )
        return False


def release_spawn_lease(conn: Any, task_key: str, *, owner_token: str | None = None,
                        owner_pid: int | None = None,
                        owner_host: str | None = None) -> None:
    try:
        if owner_token is None:
            # Backward-compatible task-router release.  Concrete orchestration
            # sessions always provide the full owner tuple below.
            conn.execute("DELETE FROM spawn_leases WHERE task_key=?", (task_key,))
            return
        conn.execute(
            """DELETE FROM spawn_leases
               WHERE task_key=? AND owner_token=? AND owner_pid=? AND owner_host=?""",
            (task_key, owner_token, owner_pid, owner_host),
        )
    except Exception:
        pass


def guard(scope: str, *, tool: str, args_summary: str = "", conn: Any | None = None) -> None:
    """Controller-safe choke-point guard (DL-065 Task H).

    - Spawned agent identity (codex/gemini/claude/…): fail-closed `require()` — raises
      ScopeDenied if the agent lacks the scope.
    - Trusted base (controller/pump/owner): audit ALLOW and return, never block.
    """
    actor = current_agent_id()
    if actor in _TRUSTED_BASE:
        label = actor if actor in {"controller", "owner"} else "controller"
        _audit(label, scope, tool=tool,
               args_summary=(args_summary + " [base]").strip(), decision="ALLOW", conn=conn)
        return
    require(actor, scope, tool=tool, args_summary=args_summary, conn=conn)


def require(agent_id: str | None, scope: str, *, tool: str, args_summary: str = "",
            conn: Any | None = None, policy: Policy | None = None) -> None:
    """Fail-closed guard. Audits the decision, then raises ScopeDenied on deny.

    agent_id None -> resolve from QM_AGENT_ID (default 'unknown')."""
    actor = agent_id or current_agent_id()
    pol = policy if policy is not None else load_policy()
    allowed = is_allowed(actor, scope, pol)
    decision = "ALLOW" if allowed else "DENY"
    summary = args_summary
    if pol.broken:
        summary = (summary + " [POLICY_BROKEN_FAIL_CLOSED]").strip()
    _audit(actor, scope, tool=tool, args_summary=summary, decision=decision, conn=conn)
    if not allowed:
        raise ScopeDenied(actor, scope, tool)
