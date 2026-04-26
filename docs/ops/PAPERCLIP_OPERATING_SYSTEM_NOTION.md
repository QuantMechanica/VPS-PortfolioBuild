# Paperclip Operating System & Process Roadmap (Notion mirror)

> **V5 Source:** Notion `Paperclip Company Operating System & Process Roadmap` (id `34947da5-8f4a-81c2-8045-ebec3ad6d78a`)
> **Migrated to repo:** 2026-04-26
> **Note:** complementary to `docs/ops/PAPERCLIP_OPERATING_SYSTEM.md` (laptop-version, migrated 2026-04-25). Where the two diverge, the laptop version typically has more concrete table-formatted detail; this Notion-mirror has the original V5 plan wording. Wave 0 / Documentation-KM reconciles.

**Purpose:** make the QuantMechanica V5 Paperclip company operate like a professional company, not a loose agent chat.

## Operating Principle

Agents work through processes. A process has an owner, inputs, checklist, evidence, review cadence, and a clear done condition. If a task has money-at-risk, public claims, infrastructure risk, or portfolio impact, it must move through a named process.

## Core Management System

| System | Owner | Cadence | Output |
|---|---|---|---|
| Project management | CEO | daily / on event | prioritized issue board, milestone status |
| Milestones | CEO + CTO | weekly | milestone review, next-gate decision |
| Process roadmap | Documentation-KM | hourly public snapshot, weekly review | public process roadmap and internal process registry |
| Checklists | process owner | every execution | signed checklist with evidence links |
| Reviews | Quality-Tech + Quality-Business | per gate | PASS / FAIL / NEEDS_WORK decision |
| Lessons learned | Documentation-KM | after incident/gate/video | kept/changed/discarded entry |
| Risk register | CEO + Controlling | weekly / on event | risk state and mitigation owner |
| Public reporting | Controlling + Documentation-KM | hourly/daily | website snapshot, episode artifacts, expense log |

## Process Roadmap

| Process | Status | Public | Owner | Trigger |
|---|---|---|---|---|
| P0 Foundation Setup | active | yes | CEO + DevOps | project start |
| Source Research | draft-active | yes | Research | new source approved |
| Strategy Card Extraction | draft-active | yes | Research | source section identified |
| EA Build | draft | partial | Development + CTO | strategy card approved |
| Backtest Baseline | draft | partial | Pipeline-Operator | EA compiles |
| Quality-Tech Review | draft | partial | Quality-Tech | baseline evidence ready |
| Quality-Business Review | draft | partial | Quality-Business | technical PASS candidate |
| Deploy Manifest | draft | partial | LiveOps + CEO | demo/live candidate |
| T6 LiveOps | draft | partial | LiveOps + Observability-SRE | approved manifest |
| Incident Response | draft | redacted | Observability-SRE + CEO | alert or breach |
| Website Snapshot Export | active | yes | DevOps + Controlling | hourly Windows Task Scheduler job (`export_public_snapshot.ps1`, usually HH:07) |
| Episode Publishing | draft-active | yes | Documentation-KM | milestone complete |
| Lessons Learned | active | yes | Documentation-KM | gate, incident, retrospective |

## Required Process Template

```text
Name:
Purpose:
Owner:
Supporting roles:
Trigger:
Inputs:
Steps:
Checklist:
Evidence required:
Abort conditions:
Reviewers:
Output:
Public fields:
Private fields:
Lessons-learned hook:
```

## Gate Rule

No strategy, EA, deployment, public KPI, or live portfolio action is accepted because an agent says it is done. It is accepted when the process checklist is complete and the required evidence exists.

Minimum evidence examples:

- source citation for research
- strategy card for implementation
- compile log for EA build
- report file and file-size sanity check for backtests
- Quality-Tech and Quality-Business signatures for PASS
- deploy manifest for T6
- screenshot/log proof for MT5 placement
- redacted public snapshot for website publication

## Milestone Model

| Milestone | Goal | Exit evidence |
|---|---|---|
| M0 Foundation | VPS, repo, docs, first agents, T1-T6 architecture | setup screenshots, repo skeleton, prompt export |
| M1 Operating System | process registry, issue board, snapshot schema | process roadmap page, first hourly snapshot |
| M2 Strategy Factory MVP | first source → first EA → first baseline | strategy card, EA, baseline report |
| M3 Public Dashboard MVP | real project data on quantmechanica.com | hourly JSON, dashboard page, stale alert |
| M4 Demo Portfolio MVP | first approved EA running on T6 demo | manifest, screenshot proof, 7-day health |
| M5 DarwinexZero Live-Test MVP | first tiny approved live allocation | human approval, risk cap, live monitoring |
| M6 Portfolio Expansion | add EAs/symbols incrementally | each addition has manifest and review |

## Professional Tooling Expectations

Paperclip should use the same basic management disciplines a human company would use:

- issue board with owners and due evidence
- process registry
- milestone reviews
- checklists for repeatable work
- decision log
- risk register
- deploy manifests
- incident reports
- weekly retrospective
- lessons-learned archive
- public/private data boundary

## Website Publishing

The public process roadmap on quantmechanica.com is generated from the internal process registry with redactions. It shows process name, owner role, status, last review date, next milestone, public checklist progress, latest lesson learned.

The same hourly VPS Task Scheduler export job writes `public-data/process-roadmap.json`. The website displays a stale state if `generated_at` is older than 90 minutes.

Must not expose credentials, internal paths, account IDs, RDP details, or raw broker logs.
