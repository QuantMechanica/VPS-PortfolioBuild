<!--
AUTO-GENERATED MIRROR — DO NOT EDIT.
Source: Notion page 34947da58f4a81c28045ebec3ad6d78a
Title: Paperclip Company Operating System & Process Roadmap
Mirrored: 2026-04-27T11:24:00Z by Documentation-KM (QUA-151)
Editing surface: Notion. Direct edits will be overwritten by the next sync.
Manifest: infra/notion-sync/manifest.yaml
Mapping note: BASIS lists "Process Roadmap"; per CEO 2026-04-27 (QUA-151
comment 2e2f2b1f), this Notion page is the closest match. Local
processes/ registry remains Git-canonical for the operational process
specs themselves.
-->

# Paperclip Company Operating System & Process Roadmap

**Purpose:** make the QuantMechanica V5 Paperclip company operate like a professional company, not a loose agent chat.

## Operating Principle

Agents work through processes. A process has an owner, inputs, checklist, evidence, review cadence, and a clear done condition. If a task has money-at-risk, public claims, infrastructure risk, or portfolio impact, it must move through a named process.

## Core Management System

- **Project management** — Owner: CEO. Cadence: daily / on event. Output: prioritized issue board, milestone status.
- **Milestones** — Owner: CEO + CTO. Cadence: weekly. Output: milestone review, next-gate decision.
- **Process roadmap** — Owner: Documentation-KM. Cadence: hourly public snapshot, weekly review. Output: public process roadmap and internal process registry.
- **Checklists** — Owner: process owner. Cadence: every execution. Output: signed checklist with evidence links.
- **Reviews** — Owner: Quality-Tech + Quality-Business. Cadence: per gate. Output: PASS / FAIL / NEEDS_WORK decision.
- **Lessons learned** — Owner: Documentation-KM. Cadence: after incident/gate/video. Output: kept/changed/discarded entry.
- **Risk register** — Owner: CEO + Controlling. Cadence: weekly / on event. Output: risk state and mitigation owner.
- **Public reporting** — Owner: Controlling + Documentation-KM. Cadence: hourly/daily. Output: website snapshot, episode artifacts, expense log.

## Process Roadmap

- **P0 Foundation Setup** — Status: active. Public: yes. Owner: CEO + DevOps. Trigger: project start.
- **Source Research** — Status: draft-active. Public: yes. Owner: Research. Trigger: new source approved.
- **Strategy Card Extraction** — Status: draft-active. Public: yes. Owner: Research. Trigger: source section identified.
- **EA Build** — Status: draft. Public: partial. Owner: Development + CTO. Trigger: strategy card approved.
- **Backtest Baseline** — Status: draft. Public: partial. Owner: Pipeline-Operator. Trigger: EA compiles.
- **Quality-Tech Review** — Status: draft. Public: partial. Owner: Quality-Tech. Trigger: baseline evidence ready.
- **Quality-Business Review** — Status: draft. Public: partial. Owner: Quality-Business. Trigger: technical PASS candidate.
- **Deploy Manifest** — Status: draft. Public: partial. Owner: LiveOps + CEO. Trigger: demo/live candidate.
- **T6 LiveOps** — Status: draft. Public: partial. Owner: LiveOps + Observability-SRE. Trigger: approved manifest.
- **Incident Response** — Status: draft. Public: redacted. Owner: Observability-SRE + CEO. Trigger: alert or breach.
- **Website Snapshot Export** — Status: active. Public: yes. Owner: DevOps + Controlling. Trigger: hourly Windows Task Scheduler job on Hetzner VPS (`export_public_snapshot.ps1`, usually HH:07).
- **Episode Publishing** — Status: draft-active. Public: yes. Owner: Documentation-KM. Trigger: milestone complete.
- **Lessons Learned** — Status: active. Public: yes. Owner: Documentation-KM. Trigger: gate, incident, retrospective.

## Required Process Template

```
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

- **M0 Foundation:** VPS, repo, docs, first agents, T1-T6 architecture. Exit evidence: setup screenshots, repo skeleton, prompt export.
- **M1 Operating System:** process registry, issue board, snapshot schema. Exit evidence: process roadmap page, first hourly snapshot.
- **M2 Strategy Factory MVP:** first source -> first EA -> first baseline. Exit evidence: strategy card, EA, baseline report.
- **M3 Public Dashboard MVP:** real project data on [quantmechanica.com](http://quantmechanica.com). Exit evidence: hourly JSON, dashboard page, stale alert.
- **M4 Demo Portfolio MVP:** first approved EA running on T6 demo. Exit evidence: manifest, screenshot proof, 7-day health.
- **M5 DarwinexZero Live-Test MVP:** first tiny approved live allocation. Exit evidence: human approval, risk cap, live monitoring.
- **M6 Portfolio Expansion:** add EAs/symbols incrementally. Exit evidence: each addition has manifest and review.

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

The public process roadmap on [quantmechanica.com](http://quantmechanica.com) should be generated from the internal process registry with redactions. It should show process name, owner role, status, last review date, next milestone, public checklist progress, and latest lesson learned.

The same hourly VPS Task Scheduler export job writes `public-data/process-roadmap.json`. The website must display a stale state if `generated_at` is older than 90 minutes.

It must not expose credentials, internal paths, account IDs, RDP details, or raw broker logs.
