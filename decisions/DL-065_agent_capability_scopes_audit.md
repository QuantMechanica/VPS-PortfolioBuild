# DL-065 — Agent Capability Scopes + Audit Layer (fail-closed, local-first)

**Date:** 2026-06-01
**Status:** Decided (OWNER + Claude) — ratified 2026-06-01
**Supersedes:** none
**Related:** DL-064 (portfolio layer — same session), DL-028 (worktree isolation),
CLAUDE.md Hard Rules (T_Live AutoTrading = OWNER+Claude). Motivated by the
"Identity/Auth/Scopes for AI agents" (Nielsen/Descope) + Claude Dynamic Workflows
+ Remote Control videos, 2026-06-01.

## Context

The strategy-farm router has **capabilities** (`code`, `review`, `ops`,
`pipeline`, …) but those are **routing hints** — "what work to assign an agent" —
**not enforcement**. There is no layer that says "this agent identity may not fire
*this tool*." This session produced four concrete proofs that the gap is live, not
theoretical:

1. I spawned three direct Codex agents with **`-s danger-full-access`** — full
   filesystem/repo access, zero scoping. Exactly the anti-pattern the Descope
   talk warns about (one prompt-injection → arbitrary action).
2. **Task E was built twice** (orchestration codex AND my direct codex) — an
   identity/coordination/audit gap: no single authority tracked "who is doing
   what."
3. I **deleted 4 `agent_tasks` rows directly** and **pushed to `main` several
   times** — high-blast-radius actions that passed through no scope gate and are
   only loosely audited.
4. We ingest **external strategy sources** (YouTube, Dropbox, research briefs)
   into build prompts — a real prompt-injection surface that, combined with
   danger-full-access, is dangerous.

Our threat model is **not** the enterprise-SaaS PII leak Nielsen frames. Our crown
jewels are **live capital (T_Live), the evidence trail (DB/Git), and broker
actions.** Scopes must therefore be ranked by **blast radius / irreversibility**,
not merely read vs write.

## Decision

**Build a local-first, fail-closed Agent Capability Scope + Audit layer.** Model,
not product — no Descope/external IdP dependency now (that stays a future option).
Three pillars (the video's "Okta for agents", done locally):

1. **Identity** — every tool invocation runs under a declared agent identity
   (`claude` / `codex` / `gemini`, or a named sub-spawn).
2. **Scopes** — fail-closed capability grants, tiered by blast radius. No grant →
   the tool refuses and the denial is audited.
3. **Audit** — every grant / denial / invocation is appended to one queryable
   trail (extends the existing farmctl `events` table).

## Blast-radius tiers (the scope vocabulary)

- **Tier 0 — NEVER automated (no agent identity ever holds it):**
  `live.autotrade` (T_Live AutoTrading toggle). This sharpens the Hard Rule from
  "OWNER+Claude only" to "**no agent *tool* exists for it** — it is a deliberate
  out-of-band human action." Even Claude-as-agent gets no automated tool.
- **Tier 1 — irreversible / outward-facing:** `git.push.main`,
  `live.deploy_manifest`, `db.delete`, `external.send`, `registry.reserve_ea_ids`.
- **Tier 2 — heavy / contended:** `ea.compile`, `fleet.recompile`,
  `mt5.backtest.dispatch`, `pipeline.close_gate`.
- **Tier 3 — cheap / reversible:** `repo.read`, `repo.write` (own worktree only),
  `dashboard.render`, `card.draft`, `research.web`.

## Per-agent grants (v1)

| Scope | claude | codex | gemini |
|---|---|---|---|
| `live.autotrade` (T0) | ✗ | ✗ | ✗ |
| `git.push.main` (T1) | ✓ | ✗ (branch only → Claude merges) | ✗ |
| `live.deploy_manifest` (T1) | ✓ (verify) | ✗ | ✗ |
| `db.delete` (T1) | ✓ | ✗ | ✗ |
| `external.send` (T1) | ✗ (only the sanctioned 06:05 digest job) | ✗ | ✗ |
| `registry.reserve_ea_ids` (T1) | ✓ | ✓ | ✗ |
| `ea.compile` / `fleet.recompile` (T2) | ✓ | ✓ | ✗ |
| `mt5.backtest.dispatch` (T2) | ✓ | ✓ | ✗ |
| `pipeline.close_gate` (T2) | ✓ | ✓ | ✗ |
| `repo.write` own-worktree (T3) | ✓ | ✓ | ✓ |
| `repo.read` / `dashboard.render` / `card.draft` / `research.web` (T3) | ✓ | ✓ | ✓ |

Rationale: **codex pushes branches, never `main`** (Claude/OWNER review-merges —
tightens today's behaviour where orchestration codex pushed straight to main).
**gemini gets the tightest set** (research only; no MT5, no main, no DB-delete) —
consistent with its known sandbox-hallucination risk. `external.send` belongs to
no interactive agent; only the sanctioned daily digest job sends mail.

## Binding rules

- **R-065-1 — fail-closed.** A tool wrapper checks `is_allowed(identity, scope)`
  before acting. Unknown identity or missing grant → refuse + audit `DENY`. Never
  fail-open.
- **R-065-2 — AMENDED 2026-06-01 (Windows reality).** Original intent: use
  `-s workspace-write` instead of `danger-full-access`. **Empirically infeasible
  on this Windows VPS** — codex `workspace-write` degrades to read-only (no OS
  sandbox backend since the elevated sandbox was removed 2026-05-16 after an
  account lockout; headless `approval=never` cannot escalate). Only
  `danger-full-access` writes. **Amended rule:** `danger-full-access` is permitted
  **only inside an isolated throwaway git worktree** (`--cd <worktree>`), which is
  the blast-radius confinement on this platform. The codex sandbox mode is NOT the
  security boundary on Windows — **the boundary is the tool-level scope layer
  (R-065-1 / Task H)**, which is platform-independent and fail-closed for spawned
  agent identities. Every spawn sets `QM_AGENT_ID` so the scope layer can identify
  and enforce against it.
- **R-065-3 — claim/lease for every spawn.** Orchestration AND direct spawns must
  register a lease keyed by task identity before executing, so the same work is
  never done twice (the Task-E duplication).
- **R-065-4 — one audit trail.** Every scoped tool call appends
  `event(conn, "agent_audit", <agent_id>, <scope>, {tool, args_summary, decision})`.
- **R-065-5 — T_Live stays fail-closed end-to-end.** No scope, no remote-control
  path, no workflow may toggle AutoTrading. Remote Control (Opus 4.8) may check
  status / resume / rebase-after-ask, but never force-push `main`/deploy/live.

## Relationship to existing machinery

Router `capabilities` = *what work to route*. These scopes = *what tools may
fire*, fail-closed, on top. The two are complementary, not a replacement. Dynamic
Workflows, when piloted, inherit the spawning agent's scopes; a read-only audit
workflow needs only Tier-3 + `research.web`.

## Out of scope (future options, not now)
- Descope / external IdP, MCP OAuth token vaults — revisit only if QM exposes
  tools to third parties or needs human-OAuth-delegated external APIs.
- Per-sub-agent ephemeral identities beyond the three named agents.

## Rejected alternatives
- **Buy Descope now.** Rejected — it solves human-OAuth-delegation to external
  SaaS; our risk is internal irreversible actions on our own VPS/DB/broker. The
  *pattern* (identity+scope+audit) is what we need, locally and fail-closed.
- **Keep capabilities-as-enforcement.** Rejected — routing hints are not a
  security boundary; this session proved tools fire with no scope check.
- **Read/write scopes only.** Rejected — under-models our threat surface; a
  `repo.write` and a `live.deploy_manifest` are not the same risk class.

## Implementation
Engineering spec: `docs/ops/AGENT_CAPABILITY_SCOPES_SPEC_2026-06-01.md`.
Policy data: `framework/registry/agent_capabilities.json` (authored by Claude).
Enforcement module + audit + spawn-flag changes + lease → Codex (scoped
`workspace-write`, applying R-065-2 to its own build).
