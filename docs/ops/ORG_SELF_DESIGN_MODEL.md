# Paperclip Org Self-Design Model

Purpose: make the Paperclip organization adaptive instead of hard-coding a final 13-agent org chart on day 1.

## Principle

Fabian gives Paperclip the mission, constraints, source material, quality standards, and business model. Paperclip CEO designs the operating organization inside those boundaries.

The 13 roles from the Notion prompt pack are a role catalogue, not a mandatory day-1 org chart.

## Starting Point

Initial agents:

1. CEO - Claude
2. CTO - Codex
3. Research - Claude
4. Documentation-KM - Claude

The CEO's first organizational task is to propose:

- which roles are needed now
- which roles are deferred
- which model family should own each role
- which tasks justify each agent's heartbeat cost
- what quality gates prevent agent sprawl

## Capability-Based Routing

Working assumption for V5:

| Work type | Preferred model family | Reason |
|---|---|---|
| Web/deep research, source discovery, long-form synthesis | Claude | Better current fit for web-heavy research and narrative synthesis |
| Code, repo edits, scripts, MQL5 review, automation specs | Codex | Better current fit for codebase and terminal-driven engineering |
| Strategy-card extraction from fixed sources | Claude | Reading, citation discipline, source fidelity |
| Technical implementation and CI | Codex | Deterministic code changes and verification |
| Quality-Tech review | Mixed | Codex for code/stat artifacts, Claude for report reasoning |
| Quality-Business review | Claude | Portfolio/business reasoning and communication |
| Website/dashboard implementation | Codex primary, Claude design/content support | Code plus brand/narrative |
| Hourly public dashboard export | Codex/DevOps + Controlling | Scripted export with KPI interpretation |

This is not permanent doctrine. CEO must re-evaluate routing when tools, models, or task evidence change.

## Org Design Cadence

CEO produces:

- Day 1: initial org proposal
- Week 1: active roles and deferred roles
- Monthly: org effectiveness review
- After each incident: whether ownership boundaries caused or prevented the failure

## Hiring Gate

Before hiring an agent, CEO must answer:

1. What recurring work justifies this role?
2. Which current agent should not own it and why?
3. What is the write authority?
4. What is the heartbeat cadence or on-demand trigger?
5. What outputs prove the role is useful?
6. What condition retires or pauses the role?

## Quality System

Minimum quality roles or functions:

- Quality-Tech: code, statistics, overfit, walk-forward, robustness
- Quality-Business: portfolio fit, public track-record quality, investor-facing defensibility
- Documentation-KM: Notion/Git sync, public evidence, episode artifacts
- Observability-SRE: uptime, T6/DarwinexZero health, alerts

CEO may split these into more agents only when the backlog proves the split is needed.

## Process System

The organization is process-led. CEO does not only hire roles; CEO assigns roles to processes and verifies that every recurring activity has:

- owner
- checklist
- evidence standard
- review gate
- lessons-learned hook
- public/private output boundary

The process roadmap is a first-class artifact and should be visible on quantmechanica.com with private details redacted.

Core processes:

- source research
- strategy card extraction
- EA build
- baseline backtest
- quality review
- deploy manifest
- T6 LiveOps
- website snapshot export
- episode publishing
- incident response
- lessons learned

## Skill Assignment

Each agent should have a skill pack that matches its assigned processes. Skills may be code skills, web research skills, Notion/Git sync skills, frontend design skills, MT5 automation runbooks, or checklist-based SOPs.

CEO owns skill assignment. CTO audits technical skills. Documentation-KM keeps the skill matrix current.

The website/dashboard owner must have a frontend/dashboard skill pack and must verify responsive layout, public/private redaction, snapshot contract compatibility, and browser screenshots before release.

## Website / Hourly Update Ownership

The hourly quantmechanica.com update is not a side task. It is a system function:

- DevOps owns the export job and deployment plumbing.
- Controlling owns KPI correctness.
- Documentation-KM owns public wording and evidence links.
- Observability-SRE alerts if the export is stale.

## Guardrails

- No agent exists just because it existed in V1.
- No role has write authority by default.
- No web/deep-research role is assigned to a model without strong browsing/source-handling capability.
- No code/automation role is assigned without terminal/repo competence.
- New agents start on-demand unless the recurring workload proves a heartbeat is worth it.
