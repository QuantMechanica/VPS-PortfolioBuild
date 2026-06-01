# Agent Capability Scopes + Audit — Engineering Spec

**Date:** 2026-06-01 · **Authority:** DL-065 · **Execution:** Codex (scoped)
**Policy data:** `framework/registry/agent_capabilities.json` (authored by Claude — do not edit the grants)

## Goal
A fail-closed enforcement + audit layer so every tool action runs under an agent
identity that holds the required scope, with one queryable audit trail. Local-first,
no external IdP. Implements DL-065 R-065-1..5.

## Deliverables

### 1. Enforcement module — `tools/strategy_farm/agent_scopes.py`
- `load_policy(path=DEFAULT) -> Policy` — read `agent_capabilities.json`.
- `is_allowed(agent_id: str, scope: str) -> bool` — True iff the agent's `grants`
  include `scope` AND `scope` not in `deny_explicit`. Unknown agent or unknown
  scope → **False** (fail-closed). `deny_explicit` always wins over `grants`.
- `require(agent_id: str, scope: str, *, tool: str, args_summary: str, conn=None) -> None`
  — calls `is_allowed`; on allow, audit `ALLOW`; on deny, audit `DENY` then raise
  `ScopeDenied(agent_id, scope, tool)`. Always audits (R-065-4).
- `class ScopeDenied(PermissionError)`.
- Pure stdlib. No import cycle with farmctl (import `event` lazily or pass `conn`).

### 2. Audit trail (extends existing `events`)
- `require()` appends `event(conn, "agent_audit", agent_id, scope, {"tool": tool,
  "args_summary": args_summary, "decision": "ALLOW"|"DENY"})` via the existing
  `farmctl.event(...)` primitive. No new table.
- `farmctl.py` gains an `audit` subcommand: `farmctl audit [--agent X] [--scope Y]
  [--decision DENY] [--since ISO] [--limit N]` → reads `events WHERE
  entity_type='agent_audit'`. This is the "Okta for agents" query surface.

### 3. Enforce at the real choke points (fail-closed, minimal but real)
Wire `require(...)` into the highest-blast-radius paths first — do NOT try to wrap
every function in v1; wrap the irreversible ones:
- **`git.push.main`** — any helper that pushes to `main` (e.g. the
  `push_worktree_branch` / direct `HEAD:main` paths) calls
  `require(actor, "git.push.main", ...)`. Codex identity is denied → forces
  branch+review-merge.
- **`db.delete`** — guard deletions of `agent_tasks` / `work_items` rows behind
  `require(actor, "db.delete", ...)`.
- **`mt5.backtest.dispatch`**, **`ea.compile`/`fleet.recompile`**,
  **`pipeline.close_gate`** — guard the dispatch/compile/gate-close entrypoints.
- **`live.deploy_manifest`** and **`live.autotrade`** — guard the T_Live deploy
  path; `live.autotrade` has no caller (Tier-0, no tool) — add an assertion that
  refuses if ever invoked programmatically (defence in depth for R-065-5).
The `actor` identity comes from an env var `QM_AGENT_ID` (set per spawn; default
`unknown` → fail-closed) or an explicit arg.

### 4. Ban `danger-full-access` as default (R-065-2)
- In `farmctl.py` and `run_agent_orchestration_task.py`, change the Codex spawn
  from `-s danger-full-access` to **`-s workspace-write`** by default.
- Allow `danger-full-access` ONLY if `agent_capabilities.json`
  `full_access_grant.active_grants` has a non-expired entry matching the task;
  else workspace-write. Log which sandbox was chosen via the audit trail.

### 5. Claim/lease for spawns (R-065-3)
- A tiny lease: before executing a task, `claim_lease(task_key, agent_id)` writes a
  row (reuse `agent_tasks` claimed_by/claim ts, or a `leases` table) and returns
  False if a live lease exists. Both orchestration and direct-spawn paths call it.
  Prevents the Task-E double-build. Stale lease (> N min) is reclaimable.

## Acceptance
- `tests/test_agent_scopes.py`: fail-closed on unknown agent/scope;
  `deny_explicit` beats `grants`; codex denied `git.push.main`; gemini denied
  `mt5.backtest.dispatch`; `live.autotrade` denied for all three; every call
  audits exactly one `agent_audit` event with the right decision.
- `farmctl audit --decision DENY` lists denials.
- Grep proof that no spawn site uses `-s danger-full-access` unconditionally.

## Constraints
- Do NOT edit the grants in `agent_capabilities.json` (Claude/OWNER policy).
- Fail-closed everywhere; never fail-open on a parse error (missing/broken policy
  file → deny all non-read scopes, log a loud audit event).
- Pure stdlib + existing deps. win32 `CREATE_NO_WINDOW` on any subprocess.
- Do NOT touch the Q04 path or the commission layer.

## Sequencing
- **Task G** (module + audit + tests): foundation, build first.
- **Task H** (wire choke points §3 + ban danger-full-access §4 + lease §5):
  depends on G; build after G is verified.
