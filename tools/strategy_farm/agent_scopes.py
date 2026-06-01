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
from pathlib import Path
from typing import Any

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


def _audit(agent_id: str, scope: str, *, tool: str, args_summary: str,
           decision: str, conn: Any | None = None) -> None:
    """Append one `agent_audit` event via the farmctl primitive. Imported lazily
    to avoid an import cycle. Audit failures never block the caller's decision."""
    detail = {"tool": tool, "args_summary": args_summary, "decision": decision}
    try:
        import farmctl  # type: ignore
    except ImportError:  # pragma: no cover - alt import path when run as a module
        from tools.strategy_farm import farmctl  # type: ignore
    try:
        if conn is not None:
            farmctl.event(conn, "agent_audit", agent_id, scope, detail)
            return
        own = farmctl.connect()
        try:
            farmctl.event(own, "agent_audit", agent_id, scope, detail)
            own.commit()
        finally:
            own.close()
    except Exception:  # pragma: no cover - audit must never crash the guard
        pass


def current_agent_id() -> str:
    """Acting identity from QM_AGENT_ID; absent -> 'unknown' (fail-closed)."""
    return os.environ.get("QM_AGENT_ID", "unknown")


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
