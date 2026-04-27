# Paperclip Org Self-Design Model

Purpose: make the Paperclip organization adaptive instead of hard-coding a final 13-agent org chart on day 1.

**V5 refresh:** 2026-04-27 — synced with `decisions/2026-04-27_v5_org_proposal.md`, DL-017 (CEO hire-approval waiver), DL-023 (broadened CEO autonomy v2 / QUA-188), and the CLAUDE.md T6 boundary update of 2026-04-27 (deploy of approved EAs is in scope; AutoTrading toggle stays manual OWNER). See QUA-213 for the refresh task.

## Principle

OWNER gives Paperclip the mission, constraints, source material, quality standards, and business model. Paperclip CEO designs the operating organization inside those boundaries.

The 13 roles in `paperclip-prompts/` are a **role catalogue**, not a mandatory day-1 org chart.

## Hiring Reality (2026-04-27)

The org runs **6 agents** today — Wave 0 (4) + Wave 1 (2). The CTO vacancy of 2026-04-26 closed on 2026-04-27 with the CTO hire (`241ccf3c-...`); see § Decision history below. Source of truth: live agent list from `paperclipai agent list`.

| Wave | Role | Status | Adapter | Hired |
|------|------|--------|---------|-------|
| 0 | CEO | Live | claude_local | 2026-04-26 |
| 0 | CTO | Live | codex_local | 2026-04-27 |
| 0 | Research | Live | claude_local | 2026-04-27 |
| 0 | Documentation-KM | Live | claude_local | 2026-04-27 |
| 1 | DevOps | Live | codex_local | 2026-04-26 |
| 1 | Pipeline-Operator | Live | codex_local | 2026-04-26 |

The CEO's first organizational task — **first org proposal** — landed on 2026-04-27 at [`decisions/2026-04-27_v5_org_proposal.md`](../../decisions/2026-04-27_v5_org_proposal.md). It addressed:

- which roles are needed now
- which roles are deferred (Wave 2..5 with explicit triggers; Wave 6 indefinitely)
- which model family should own each role
- which tasks justify each agent's heartbeat cost
- what quality gates prevent agent sprawl (max 8 active agents until framework step 25)

## Capability-Based Routing (V5 confirmed)

Working assumption confirmed by the 2026-04-27 org proposal:

| Work type | Preferred model family | Reason |
|-----------|------------------------|--------|
| Web/deep research, source discovery, long-form synthesis | Claude Opus 4.7 | Better current fit for web-heavy research and narrative synthesis |
| Code, repo edits, scripts, MQL5 review, automation specs | Codex (gpt-5.3-codex) | Better current fit for codebase and terminal-driven engineering |
| Strategy-card extraction from fixed sources | Claude Opus 4.7 | Reading, citation discipline, source fidelity |
| Technical implementation and CI | Codex | Deterministic code changes and verification |
| Quality-Tech review | Codex primary | Code/stat artifacts; Claude only for the report-reasoning subset if a clear case appears |
| Quality-Business review | Claude Opus 4.7 | Portfolio/business reasoning and communication |
| Website/dashboard implementation | Codex (build) + Claude (design/content) | Code plus brand/narrative |
| Hourly public dashboard export | Codex/DevOps + Controlling KPI review | Scripted export with KPI interpretation |

This is not permanent doctrine. CEO must re-evaluate routing when tools, models, or task evidence change. Quarterly review per § Org Design Cadence.

## Org Design Cadence

CEO produces:

- **Day 1:** initial org proposal — **DONE** 2026-04-27 (`decisions/2026-04-27_v5_org_proposal.md`).
- **Week 1:** active roles and deferred roles — covered in the same proposal § Wave plan.
- **Quarterly:** org effectiveness review — first review **2026-07-27**.
- **After each incident:** ownership-boundary review — was the failure caused or prevented by the org chart?

## CEO Authority Boundaries

Two cumulative waivers govern what CEO may decide unilaterally vs what must surface to OWNER. **DL-023 is additive to DL-017** — DL-017 (hires) is a subset of DL-023's broader policy.

### DL-017 — Hire-approval waiver (2026-04-27)

`requireBoardApprovalForNewAgents=false`. CEO may hire any role in the catalogue without per-hire OWNER ratification, subject to the Hiring Gate below. Source: Paperclip company config + QUA-188 narrative reference.

### DL-023 — Broadened CEO autonomy v2 (2026-04-27)

OWNER directive via QUA-188. CEO may act without surfacing on:

1. **Hires** (already DL-017).
2. **Technical implementation choices within the framework spec** — adapter choices, library structure, internal scripts, test harness shape, gitignore/artifact retention, Notion ↔ Git mirror layout, scheduler choice, Linux/PowerShell tooling.
3. **Operational decisions for non-T6 deploys** — file paths, scheduler windows, log rotation, retention windows, agent confirmation cadence, worktree layout, lock-file monitoring, bookkeeping cleanups.
4. **Internal process choices** — heartbeat cadence, issue-tree shape, sub-issue spawning, agent-vs-agent escalation rules, parallel-run rules.

Decision rule for ambiguous cases: **err toward acting**. CEO can retroactively raise via a successor DL-NNN if ratification is needed.

### Still requires OWNER surfacing (DL-023 § Still requires)

1. **T6 anything** — OFF LIMITS without explicit OWNER approval per `CLAUDE.md` hard rule. Per OWNER 2026-04-27, **deploy of approved EAs (`.ex5` + `.set` + templates / profiles) under an OWNER-approved deploy manifest is in scope** for non-T6 work; the **AutoTrading toggle stays manual OWNER**. Agents must verify AutoTrading is OFF before/after any T6 placement and abort if it becomes ON without OWNER action.
2. **Live deploy** — first T6 deploy manifest, AutoTrading toggle, live-account credential touches, live capital exposure changes.
3. **Strategic direction** — source-queue ordering, Strategy Card approval, EA inclusion in V5 portfolio, brand application choices that affect public-facing artifacts.
4. **Compliance / legal** — news-compliance variant decisions (FTMO / 5ers / DXZ blackout windows), broker-of-record changes, account-class transitions.
5. **Budget step-changes** — anything materially raising monthly token/compute spend beyond the existing operating envelope.
6. **Boundary modifications to V5 hard rules** — ML ban, Model 4, .DWX suffix, Friday Close default, magic-formula registry.

Full text: [`decisions/2026-04-27_ceo_autonomy_waiver_v2.md`](../../decisions/2026-04-27_ceo_autonomy_waiver_v2.md).

## Hiring Gate

Before hiring an agent, CEO must answer **all six** of the following in the hire-request comment (per `decisions/2026-04-27_v5_org_proposal.md` § 5):

1. What recurring work justifies this role? (concrete: queue or projected within 7 days)
2. Which current agent should not own this and why? (capability gap, not capacity)
3. What is the write authority? (paths, repos, external systems)
4. What is the heartbeat cadence or on-demand trigger? (default: event-driven)
5. What outputs prove the role is useful? (artifact + cadence)
6. What condition retires or pauses the role?

CEO will not file a new `agent-hires` POST without writing those six answers in the hire-request comment. Per DL-017, OWNER is informed but does not gate the hire.

## Anti-Sprawl Rules

- **Maximum 8 active agents until Phase 2 framework is fully implemented (Implementation Order step 25).** That ceiling = Wave 0 (4) + Wave 1 (2) + 2 Wave-2 hires. Any 9th hire requires explicit OWNER approval.
- **No agent without a named recurring deliverable.** "Just in case" agents get paused.
- **Quarterly org effectiveness review** — first 2026-07-27.
- **Any incident triggers an ownership-boundary review** — was the failure caused or prevented by the org chart?

## Quality System

Minimum quality roles or functions:

- **Quality-Tech** — code, statistics, overfit, walk-forward, robustness (Wave 2 hire; CTO covers until then)
- **Quality-Business** — portfolio fit, public track-record quality, investor-facing defensibility (Wave 2 hire; CEO covers until then)
- **Documentation-KM** — Notion/Git sync, public evidence, episode artifacts, lessons archive (Wave 0, live)
- **Observability-SRE** — uptime, T6/DarwinexZero health, alerts (Wave 3 hire; DevOps covers until then)

CEO may split these into more agents only when the backlog proves the split is needed.

## Process System

The organization is process-led. CEO does not only hire roles; CEO assigns roles to processes and verifies that every recurring activity has:

- owner
- checklist
- evidence standard
- review gate
- lessons-learned hook
- public/private output boundary

The process roadmap is a first-class artifact and should be visible on quantmechanica.com with private details redacted. Investment / portfolio claims must remain separated from support / Buy-me-a-coffee CTA copy on every public surface.

Core processes (current V5 set):

- source research
- strategy card extraction
- EA build
- baseline backtest
- quality review
- deploy manifest
- T6 LiveOps (locked behind Wave 4 LiveOps hire)
- website snapshot export
- episode publishing
- incident response
- disaster recovery
- disk + Drive-sync maintenance
- agent re-scope
- board escalation
- lessons learned

See [`processes/`](../../processes/) for per-process flow specs.

## Skill Assignment

Each agent should have a skill pack that matches its assigned processes. Skills may be code skills, web research skills, Notion/Git sync skills, frontend design skills, MT5 automation runbooks, or checklist-based SOPs.

CEO owns skill assignment. CTO audits technical skills. **Documentation-KM keeps the skill matrix current at [`docs/ops/AGENT_SKILL_MATRIX.md`](AGENT_SKILL_MATRIX.md).**

The website/dashboard owner must have a frontend/dashboard skill pack and must verify responsive layout, public/private redaction, snapshot contract compatibility, and browser screenshots before release.

## Website / Hourly Update Ownership

The hourly quantmechanica.com update is a system function, not a side task:

- **DevOps** owns the export job and deployment plumbing.
- **Controlling** (Wave 3) owns KPI correctness — until hired, **CEO** reviews KPI sanity.
- **Documentation-KM** owns public wording and evidence links, including the support/CTA boundary.
- **Observability-SRE** (Wave 3) alerts if the export is stale — until hired, DevOps cron health is its own monitor.

## Decision history

- **DL-016 (CTO vacancy / CEO absorption pattern)** — between 2026-04-26 evening and 2026-04-27 morning the company had no CTO; CEO absorbed sign-off on infra/code issues per CLAUDE.md hard rule "Disk-check + V4-boundary-check before EA/sleeve approval." **Now obsolete:** CTO `241ccf3c-...` was hired 2026-04-27. CEO no longer absorbs CTO sign-off; DL-016 is retained in the registry as historical context only.
- **DL-017 (CEO hire-approval waiver)** — 2026-04-27. `requireBoardApprovalForNewAgents=false`. Source: Paperclip company config + QUA-188 narrative reference.
- **DL-023 (Broadened CEO autonomy v2)** — 2026-04-27 ~12:00 local, additive to DL-017. Full text in [`decisions/2026-04-27_ceo_autonomy_waiver_v2.md`](../../decisions/2026-04-27_ceo_autonomy_waiver_v2.md).
- **CLAUDE.md T6 boundary update (2026-04-27)** — deploy of approved EAs (`.ex5` + `.set` + templates / profiles) under an OWNER-approved deploy manifest is in scope; AutoTrading toggle stays manual OWNER. T6 still OFF LIMITS for any other modification.

## Guardrails

- No agent exists just because it existed in V1.
- No role has write authority by default.
- No web/deep-research role is assigned to a model without strong browsing/source-handling capability.
- No code/automation role is assigned without terminal/repo competence.
- New agents start on-demand unless the recurring workload proves a heartbeat is worth it.
- T6 stays isolated; AutoTrading stays manual OWNER; live deploy still surfaces to OWNER.

## References

- V5 org proposal: [`decisions/2026-04-27_v5_org_proposal.md`](../../decisions/2026-04-27_v5_org_proposal.md)
- DL registry: [`decisions/REGISTRY.md`](../../decisions/REGISTRY.md)
- DL-023: [`decisions/2026-04-27_ceo_autonomy_waiver_v2.md`](../../decisions/2026-04-27_ceo_autonomy_waiver_v2.md)
- BASIS prompts: [`paperclip-prompts/`](../../paperclip-prompts/) (OWNER-managed)
- Bootstrap doc: [`docs/ops/PAPERCLIP_V2_BOOTSTRAP.md`](PAPERCLIP_V2_BOOTSTRAP.md)
- Skill matrix: [`docs/ops/AGENT_SKILL_MATRIX.md`](AGENT_SKILL_MATRIX.md)
