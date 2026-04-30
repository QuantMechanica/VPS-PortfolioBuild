# Paperclip Company Reboot Plan — 2026-04-30

Purpose: turn the QuantMechanica Paperclip setup into a real, token-aware AI operating company instead of a loose set of agents. This is not a human-company org chart. Paperclip should run as a control tower plus focused capability cells: a few persistent coordinators, many sleeping/on-demand specialists, machine-readable state, and a dashboard that lets OWNER supervise from high altitude.

## Operating Thesis

The company exists to turn researched trading ideas into verified EAs and ultimately a profitable portfolio. Every role must support one of four flows:

1. Source -> Strategy Card
2. Strategy Card -> EA
3. EA -> T1-T5 pipeline evidence
4. Evidence -> portfolio/dashboard/decision

Roles outside those flows are control functions and must prove that they reduce bottlenecks, uncertainty, or token waste.

## AI-Native Shape

Do not mirror human departments like Finance, Procurement, Scrum, Marketing, and Sales unless the system has a recurring workload that needs that exact capability. In an AI company, most "departments" become:

- a data contract
- an issue template
- a checklist
- an on-demand specialist
- a dashboard panel

Only stable, recurring coordination loops become standing agents.

## Control Tower And Capability Cells

Keep the live company small. Use on-demand specialists before adding scheduled heartbeat roles.

| Tier | Role | Status | Primary skill | Model class | Why it exists |
|---|---|---|---|---|---|
| Control tower | CEO | live | delegation + gates | strongest reasoning | turns OWNER intent into issues and gate decisions |
| Control tower | Chief of Staff / OS Controller | hire now, light heartbeat | org design + token efficiency | mid/strong reasoning | keeps agents scoped, detects bottlenecks, owns model/skill routing |
| Control tower | Token Controller | sub-role under Chief of Staff first | token budget accounting | lightweight | monitors token pressure before expanding into a separate agent |
| Technical | CTO | live | architecture review | Codex strong | owns framework and technical gates |
| Research | Research Lead | live | source research | strong reasoning | owns one approved source at a time |
| Research specialist | PDF Researcher | on demand | PDF extraction | strong only when needed | extracts dense papers/books into Research-ready notes |
| Research specialist | Video Researcher | on demand | video transcript analysis | mid/strong | analyzes approved YouTube sources and hands notes to Research/CoS |
| Build | Development | active/triggered | EA implementation | Codex strong | builds one EA task at a time |
| Build ops | DevOps | live | infra/schedulers | Codex mid/strong | keeps Paperclip, exports, MT5 tooling running |
| Factory ops | Pipeline-Operator | live | backtest execution | Codex mid | load balances T1-T5 and records evidence |
| Data ops | Data Environment Steward | on demand first | .DWX symbol verification | Codex lightweight | audits T1-T5 symbol/data readiness |
| Quality | Quality-Tech | active/triggered | technical/stat review | Codex strong | independent bug/overfit gate |
| Quality | Quality-Business | active/triggered | source/claim/business review | mid/strong reasoning | keeps public claims and strategy narratives defensible |
| Reporting | Visualization Controller | hire when dashboard feed has data | KPI dashboard | lightweight/mid | maintains project dashboard and progress accounting |
| Knowledge | Documentation-KM | live | process + lessons loop | mid/strong | captures lessons and updates processes |
| Inbox | Gmail Intake | on demand until volume justifies heartbeat | link triage | lightweight | extracts links from info@ inbox and creates CEO-ready briefs |

Do not create separate Finance, Scrum Master, Procurement, Sales, Marketing, Mathematics, Physics, Chemistry, or Trading agents yet. Those are capabilities, not current bottleneck roles. Add them only when a recurring issue class proves the need.

## Chief of Staff / OS Controller Mandate

The Chief of Staff is not a human-style executive assistant. It is the operating-system controller. The current bottleneck is not raw labor; it is routing, token waste, missing state, and unclear accountability.

Responsibilities:

- Maintain the org chart and agent roster.
- Enforce one primary skill per agent.
- Recommend model tier per role and task: lightweight for monitoring, mid for summaries, strong for strategy and technical judgment.
- Own a weekly bottleneck review: idle agents, blocked agents, duplicate work, overloaded roles, stale issues.
- Own Token Controller duties until volume justifies a separate role.
- Convert lessons learned into process-change proposals for Documentation-KM.
- Keep teams small: recommend hire only when a recurring queue has no accountable owner or an existing role is measurably overloaded.
- Maintain the OWNER high-altitude view: what is running, what is blocked, what changed, what needs a decision.

Forbidden:

- No strategy gate decisions.
- No code edits.
- No T6/live-money authority.
- No broad “manage everything” delegation. The role manages routing and efficiency, not execution.

## Research Team Expansion

Research remains one-source-at-a-time. Specialists do not create independent strategy queues.

Workflow:

1. CEO approves a source.
2. Research Lead decides whether source needs a specialist.
3. PDF Researcher or Video Researcher produces notes with citations/timestamps.
4. Research Lead writes Strategy Cards and source completion report.
5. CEO/Quality-Business review before build.

First video task:

- Source: `https://www.youtube.com/watch?v=UIdH5Ac1Db8`
- Assignee: Video Researcher, under Research Lead
- Output: timestamped brief to Chief of Staff and Research Lead
- Objective: extract process/token-efficiency/org-design insights, not trading claims unless the video contains them

## Data And Pipeline Control

Data Environment Steward starts as an on-demand issue owner, not a standing hourly agent.

Acceptance criteria:

- Inventory T1-T5 `.DWX` symbols.
- Verify each required backtest symbol exists on every factory terminal.
- Flag missing/stale/broken symbols with terminal, symbol, timeframe, and evidence path.
- Feed findings to Pipeline-Operator and DevOps.

Pipeline-Operator remains the only role that schedules T1-T5 jobs. It must never duplicate a dedup key and must keep one sequential task list per active issue.

## Dashboard And Project Database

Use layered storage instead of one overloaded database:

- Paperclip Postgres: issues, agents, comments, runtime state.
- Git Markdown: Strategy Cards, source reports, processes, lessons, decisions.
- Public JSON snapshots: redacted dashboard contract for website.
- Filesystem reports: MT5/Pipeline evidence and raw backtest outputs.

New dashboard menu sections should read from public JSON:

- `Project Dashboard`: strategy count, EA count, phase distribution, active blockers, T1-T5 status, next planned tests.
- `Company Operating Model`: control tower, capability cells, role statuses, process list, improvement loop, hiring gates.

This change adds `public-data/company-operating-model.json` as the first contract for the second section.

OWNER high-altitude view must answer five questions in one screen:

1. What is running right now?
2. What changed since the last review?
3. What is blocked and who owns the unblock?
4. Which strategies/EAs are advancing through the factory?
5. What decision, if any, does OWNER need to make?

## Continuous Improvement Loop

Documentation-KM owns the lessons archive, but the loop has four accountable steps:

1. Any agent writes a lesson candidate when work fails, repeats, or wastes tokens.
2. Documentation-KM turns it into a normalized lesson.
3. Chief of Staff decides whether it changes routing/model/skill usage.
4. CEO approves process updates or hire/defer decisions.

No lesson is complete until it links to at least one changed process, checklist, prompt proposal, or explicit no-change decision.

## GitHub And Notion

Do not create separate GitHub and Notion agents yet.

- GitHub is a tool surface owned by DevOps/CTO/Documentation-KM depending on issue type.
- Notion mirror is owned by Documentation-KM.
- Add a dedicated GitHub/Notion agent only if sync/review volume becomes a measured bottleneck for two consecutive weekly reviews.

## Gmail Intake

Gmail is an intake channel, not an autonomous agent surface at first.

Phase 1 uses the existing human-controlled Gmail session and Claude Chrome extension as a manual bridge:

1. OWNER labels or opens relevant emails in `info@quantmechanica.com`.
2. Claude extension extracts links and a short summary.
3. The summary is pasted into the Gmail Intake issue or directly assigned to CEO.
4. CEO decides whether the link becomes Research, CTO, DevOps, Documentation-KM, or no-action.

Phase 2 is only justified if mail volume becomes recurring:

- read-only Gmail API/OAuth scope
- label-only polling, e.g. `QM/Paperclip-Inbox`
- no send/delete/archive authority
- dedupe by message id + URL
- output is a CEO brief, not direct execution

The first implementation issue is `[Gmail Intake] Design info@quantmechanica.com link intake workflow`.

## First 48 Hours

1. Create Chief of Staff / OS Controller issue and hire as light heartbeat / on-demand role.
2. Assign Chief of Staff the org/model/token review.
3. Create Video Researcher on-demand task for the YouTube source.
4. Create Data Environment Steward audit issue for T1-T5 `.DWX`.
5. Create Controlling/Visualization issue to wire `company-operating-model.json` into the website/Paperclip menu.
6. Create Documentation-KM issue to update processes and lessons-loop references.

## Hiring Gate

Before any new agent is created, CEO must record:

- recurring bottleneck or queue it solves
- one primary skill
- model tier
- heartbeat mode and interval
- write authority
- forbidden actions
- evidence proving usefulness
- retirement condition
