# Paperclip V2 Bootstrap Plan

Purpose: start a fresh Paperclip company for QuantMechanica V5 without importing old QUAA runtime state.

## Bootstrap Principle

New company, new project, new issue tree. Old QUAA content is archive and learning material only.

## Company

- Company name: `QuantMechanica V5`
- Project name: `Portfolio Factory V5`
- Public repo: `https://github.com/QuantMechanica/VPS-PortfolioBuild`
- Operating language: English
- Public narrative: Build in Public on YouTube
- Human final authority: Fabian
- Board reviewers: Claude-Assistant, Codex

## First Agents

Start with four agents, not all thirteen:

1. CEO - issue decomposition, strategy gates, queue control
2. CTO - technical architecture, EA-vs-card review, pipeline rules
3. Research - first source proposal and strategy cards
4. Documentation-KM - Notion/Git sync, episode artifacts, public docs

Add the rest only when their first real issue exists.

## Company Operating System

The first company deliverable after the org proposal is the operating system:

- process registry
- process roadmap
- milestone board
- checklists
- review gates
- decision log
- risk register
- lessons-learned loop
- skill matrix

Agents should not improvise recurring work. They should execute named processes and update the evidence trail.

## Org Self-Design

The first four agents are a bootstrap team, not the final org. The CEO's first organizational deliverable is an org proposal based on the actual Phase 0 backlog.

The 13 prompt pages are a role catalogue. CEO decides which roles become live agents and when.

Capability routing starts with this assumption:
- Claude for CEO, web/deep research, source synthesis, Quality-Business, Documentation-KM.
- Codex for CTO, repo/code work, MQL5 review, DevOps, automation, website/dashboard implementation.
- Mixed review for high-stakes gates: Claude checks business/source reasoning; Codex checks code/evidence/stat artifacts.

The assumption is reviewed monthly and after incidents.

## Skills

Every active agent needs an explicit skill pack. A skill can be a Paperclip skill, Codex skill, Claude instruction set, repo-local SOP, checklist, or automation runbook.

Initial required skills:
- CEO: org design, project management, gate decisions, risk register.
- CTO: code architecture, MQL5 review, automation review, technical audit.
- Research: web/deep research, source fidelity, strategy-card extraction.
- Documentation-KM: Notion/Git sync, process registry, lessons learned, episode artifacts.
- Website owner: frontend/dashboard skill, snapshot JSON contract, redaction, browser verification.
- LiveOps later: T6 manifest execution, MT5 chart placement automation, halt procedure.

## Seed Data Assets

Paperclip must know about preserved seed data before the first VPS backtest run. The current local seed asset is:

```text
Company/V5_Public_Build/seed_assets/news_calendar/
```

It contains the V1-V5 economic news/calendar CSVs and `MANIFEST.md` with source paths, row counts, SHA256 hashes, and VPS placement rules.

VPS canonical destination:

```text
D:\QM\data\news_calendar\
```

DevOps must verify hashes and row counts after copy. Pipeline-Operator must not treat a missing news file as a strategy failure; classify it as `SETUP_DATA_MISSING` and stop the run until the data path is fixed.

## Do Not Import

- old QUAA issues
- old heartbeats
- old `TODO.md` feed
- old `HANDOFF.md` as current memory
- old agent IDs
- old managed `AGENTS.md` bundles

## Prompt Hygiene

The Notion prompt pages are good drafts, but Git should become canonical after repo creation.

Target repo layout:

```text
paperclip-prompts/
  ceo.md
  cto.md
  research.md
  documentation-km.md
  pipeline-operator.md
  development.md
  quality-tech.md
  quality-business.md
  controlling.md
  r-and-d.md
  devops.md
  observability-sre.md
  liveops.md
```

Every prompt needs:
- role
- reports-to
- owns / does-not-own
- write authority
- first issues
- escalation rules
- file-deletion policy
- V5 fresh-start boundary

## Agent Expansion Order

| Wave | Agents | Trigger |
|---|---|---|
| 0 | CEO, CTO, Research, Documentation-KM | Phase 0 start |
| 1 | DevOps, Pipeline-Operator | VPS and T1-T5 installed; hourly dashboard export path scoped |
| 2 | Development, Quality-Tech, Quality-Business | First Strategy Cards approved |
| 3 | Controlling, Observability-SRE | Dashboard and monitoring contracts exist |
| 4 | LiveOps | T6 demo terminal exists and manifest schema passes dry run |
| 5 | R-and-D | First pipeline-methodology change is proposed |

## First Issue Tree

```text
M0 - Foundation Week
  P0-01 VPS purchase and Windows install
  P0-02 Populate public repo skeleton
  P0-03 Export V5 docs and prompt pack
  P0-04 T1-T6 terminal layout proof
  P0-05 T6 deploy manifest dry run
  P0-06 Seed-strategy import index
  P0-07 EP01 artifact pack
  P0-08 Process registry + process roadmap
  P0-09 Agent skill matrix
  P0-10 quantmechanica.com support CTA and process roadmap spec
  P0-11 News calendar seed asset registered and copied to VPS
```

## Fresh-Start Guard

CEO must reject any task that says "continue QUAA issue X" unless it is explicitly an archive/import task. The correct phrasing is:

```text
Import learning from QUAA-X into V5 docs, then create a new V5 issue if still relevant.
```

## Phase 0 Done Criteria

- Fresh company exists.
- First four agents are online.
- Prompt pack is exported to Git or staged locally.
- No old QUAA issue is active in the new company.
- T1-T6 architecture is documented.
- News calendar seed asset is registered, copied to the VPS data disk, and verified by hash before news-aware runs.
- T6 LiveOps is not enabled for real money.
- CEO has delivered the first org proposal and capability-routing matrix.
- CEO has delivered process registry, process roadmap, and skill matrix.
