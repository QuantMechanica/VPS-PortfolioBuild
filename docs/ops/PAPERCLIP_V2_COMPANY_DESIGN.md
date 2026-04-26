# Paperclip V2 Company Design

> **V5 Source:** Notion `Paperclip V2 Company Design` (id `34947da5-8f4a-8127-b842-f5b123b63287`)
> **Migrated to repo:** 2026-04-26

**Company name (inside Paperclip):** QuantMechanica V5
**Project:** Portfolio Factory V5
**Operating language:** English (all prompts, all agent-to-agent communication)
**Agent count:** adaptive. Start with 4 bootstrap agents; the 13 prompts are a role catalogue, not a mandatory day-1 org chart.

## Design Philosophy

V1 had too many agents doing overlapping work with vague boundaries. V2 is leaner, more specialized, and every agent prompt has **explicit learnings baked in** from V1 failures. The final org is proposed by Paperclip CEO after reading the backlog and capability constraints. Each role answers three questions clearly:

1. **What does this agent do?**
2. **What does this agent NEVER do?**
3. **What did V1 teach us about this role that changed the prompt?**

## Company Operating System

Paperclip V2 is process-led. The CEO must define the process registry, process roadmap, milestone board, checklists, review gates, decision log, risk register, lessons-learned loop, and skill matrix before scaling the company. See `docs/ops/PAPERCLIP_OPERATING_SYSTEM.md` and `docs/ops/AGENT_SKILL_MATRIX.md`.

## Org Design Model

The chart below is a candidate role map, not a fixed hiring plan. Paperclip CEO must create the actual org proposal on Day 1, using the backlog, task cadence, process needs, quality needs, skill requirements, and Claude/Codex capability routing. See `docs/ops/ORG_SELF_DESIGN_MODEL.md`.

## Candidate Org Chart

```text
               OWNER (Human Founder)
               Claude-Assistant (Board Member)
                       |
                  Paperclip CEO
                  /    |    |    \
         CTO  Research Controlling  Documentation
          |       |         |              |
Development  Quality-Tech  Observability  Quality-Business
     |          |              |               |
Pipeline-Op  R-and-D        DevOps         LiveOps
```

## Heartbeat Schedule (Revised from V1)

Heartbeat rates are defaults. CEO may reduce, pause, or keep agents on-demand until recurring workload justifies a heartbeat. The hourly quantmechanica.com export is a first-class system task owned by DevOps + Controlling + Documentation-KM, monitored by Observability-SRE.

| Agent | V1 Heartbeat | V2 Heartbeat | Reason |
|---|---|---|---|
| CEO | 20min | 30min | V1 too chatty, created noise |
| CTO | 30min | 1h | Deep work needs longer cycles |
| Research | 4h | **Source-completion** | No time-based, event-driven per source |
| Controlling | 30min | 1h | Weekly rollup enough |
| Documentation | 1h | 2h | Reactive better than proactive here |
| Quality-Business | 8h | Daily | Lower cadence, higher signal |
| Quality-Tech | on-demand | on-demand | Unchanged |
| R-and-D | on-demand | on-demand | Unchanged |
| DevOps | on-demand | on-demand | Unchanged |
| Development | on-demand | on-demand | Unchanged |
| Observability-SRE | 2min | 5min | V1 2min caused quota issues |
| Pipeline-Operator | 5min | 10min | V1 too eager, wasted tokens on no-op ticks |
| LiveOps | 15min | 15min | Unchanged (live-exec-critical) |

## Heartbeat Budget

Total heartbeat cycles/day across 13 agents = ~800 (V1 was ~2400 after including Obs-SRE at 2min). Net token spend should drop ~60% vs V1 without losing coverage, because V1 wasted heavily on no-op ticks.

## Bootstrap Correction

V5 starts as a fresh Paperclip company. Do not import old QUAA issues, heartbeats, agent IDs, or managed `AGENTS.md` bundles. Old strategies are imported only as `strategy-seeds` after re-source/re-test review.

First wave: CEO (Claude), CTO (Codex), Research (Claude), Documentation-KM (Claude). Add Pipeline-Operator only after T1-T5 exist. Add LiveOps only after T6 exists and the deploy-manifest dry run passes. CEO must produce a capability-routing matrix before hiring beyond the first wave.

## Skill Pack Rule

Each active agent needs an explicit skill pack. A skill can be a Paperclip skill, Codex skill, Claude instruction set, repo-local SOP, checklist, or automation runbook. CEO owns skill assignment, CTO audits technical skills, and Documentation-KM keeps the matrix current. The website/dashboard owner must have frontend/dashboard, snapshot JSON, redaction, accessibility, and browser-verification skills.

## Sub-pages — Agent System Prompts

13 individual agent system prompts. **All migrated to repo at `paperclip-prompts/<role>.md` on 2026-04-26.** Each carries:

- Full English system prompt
- Explicit V1-to-V2 learnings section
- Tools available
- Heartbeat cadence
- Reports-to / reports-from graph
- First assigned issues on startup

| Role | Repo file | Notion id |
|---|---|---|
| CEO | `paperclip-prompts/ceo.md` | `34947da5-8f4a-817e-aeb6-c6b324fe7f73` |
| CTO | `paperclip-prompts/cto.md` | `34947da5-8f4a-81e3-a49b-f0940c7e331f` |
| Research | `paperclip-prompts/research.md` | `34947da5-8f4a-81ca-8b24-fe5a7fe57cb2` |
| Pipeline-Operator | `paperclip-prompts/pipeline-operator.md` | `34947da5-8f4a-8104-a95b-ce4337631374` |
| Controlling | `paperclip-prompts/controlling.md` | `34947da5-8f4a-815c-8d89-e28596e7d0ac` |
| Documentation-KM | `paperclip-prompts/documentation-km.md` | `34947da5-8f4a-8125-9d97-c8c0b3422305` |
| Quality-Business | `paperclip-prompts/quality-business.md` | `34947da5-8f4a-8197-ba26-ccd8a93d3e06` |
| Quality-Tech | `paperclip-prompts/quality-tech.md` | `34947da5-8f4a-811b-94e3-d4aa8079ceda` |
| R-and-D | `paperclip-prompts/r-and-d.md` | `34947da5-8f4a-813d-83e4-cef62de294cc` |
| DevOps | `paperclip-prompts/devops.md` | `34947da5-8f4a-8197-ae2b-f3fbfe648e93` |
| Development | `paperclip-prompts/development.md` | `34947da5-8f4a-8172-aa7a-cbeba3433322` |
| Observability-SRE | `paperclip-prompts/observability-sre.md` | `34947da5-8f4a-8188-932f-dfee5d1b0856` |
| LiveOps | `paperclip-prompts/liveops.md` | `34947da5-8f4a-81fb-8a66-eb1ceb91adac` |

## Wave Hiring Order

Per `docs/ops/PAPERCLIP_V2_BOOTSTRAP.md`:

| Wave | Agents | Trigger |
|---|---|---|
| 0 | CEO, CTO, Research, Documentation-KM | Phase 0 close + Paperclip install |
| 1 | DevOps, Pipeline-Operator | T1-T5 installed |
| 2 | Development, Quality-Tech, Quality-Business | First Strategy Cards approved |
| 3 | Controlling, Observability-SRE | Dashboard / monitoring contracts exist |
| 4 | LiveOps | T6 demo + manifest dry-run passes |
| 5 | R-and-D | First pipeline-methodology change proposed |
| 6 (deferred) | Chief of Staff (founder-comms) | All triggers per `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md` |
