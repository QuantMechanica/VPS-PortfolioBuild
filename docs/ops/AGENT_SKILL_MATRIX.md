# Agent Skill Matrix

Purpose: define which Paperclip roles need which skills, tools, and operating processes — and **which roles are actually hired today** vs deferred to a later wave.

**V5 refresh:** 2026-04-27 (initial); refreshed 2026-04-28 for Wave 2 hires (Quality-Tech, Development, Quality-Business). `processes/process_registry.md` § Active agents is the operational source-of-truth; this matrix is the planning/skill-pack overlay. See [DL-039](../../decisions/2026-04-28_quality_business_hire.md) for the 9th-agent OWNER override and QUA-441 for the registry reconciliation. Original refresh task: QUA-213.

## Principle

Prompts are not enough. Each role should have a skill pack that matches its real work. CEO owns assignment; CTO verifies technical capability; Documentation-KM keeps the matrix current.

Skills can be native Paperclip skills, Codex skills, Claude project instructions, scripts, SOP checklists, or repo-local runbooks. A role may use a skill only within its write authority.

## Hiring Reality (2026-04-28)

The org runs 9 agents today (Wave 0 + Wave 1 + Wave 2 all live). Wave 3+ roles below are **placeholders** — they appear in the skill rows so the future skill pack exists, but no agent is assigned and no heartbeat budget is consumed until the wave's hire trigger fires. The Wave 2 cap was originally 8 (per `2026-04-27_v5_org_proposal.md` § 6); OWNER granted a one-time override on 2026-04-28 to seat Quality-Business as the 9th active agent — see [DL-039](../../decisions/2026-04-28_quality_business_hire.md). The 8-cap remains in force for any further hires.

| Wave | Role | Status | Agent ID | Adapter |
|------|------|--------|----------|---------|
| 0 | CEO | **Live** | `7795b4b0-...` | claude_local |
| 0 | CTO | **Live** | `241ccf3c-...` | codex_local |
| 0 | Research | **Live** | `7aef7a17-...` | claude_local |
| 0 | Documentation-KM | **Live** | `8c85f83f-...` | claude_local |
| 1 | DevOps | **Live** | `0e8f04e5-...` | codex_local |
| 1 | Pipeline-Operator | **Live** | `46fc11e5-...` | codex_local |
| 2 | Quality-Tech | **Live** (2026-04-28) | `c1f90ba8-...` | claude_local |
| 2 | Development | **Live** (2026-04-28) | `ebefc3a6-...` | codex_local |
| 2 | Quality-Business 2 | **Live** (2026-04-28, DL-039 override) | `0ab3d743-...` | claude_local |
| 3 | Controlling | Planned | — | claude_local (lightweight) |
| 3 | Observability-SRE | Planned | — | codex_local (lightweight) |
| 4 | LiveOps | Planned | — | codex_local + strict runbooks |
| 5 | R-and-D | Planned | — | mixed |
| 6 | Chief of Staff | **Deferred indefinitely** | — | — |

Source of truth: live agent list = `paperclipai agent list`; this table reflects the snapshot at refresh time. Operational roster (full role/source/reports-to detail) lives at `processes/process_registry.md` § Active agents. Adapter note: Quality-Tech was originally provisioned as `codex_local` in the Wave-2 trigger plan but landed as `claude_local` (Opus 4.7) at hire time — the live agent record is authoritative. QB note: the original Quality-Business agent (`f2c79849-...`) hit a `cwd` path-mangle bug at hire (CTO follow-up [QUA-439](/QUA/issues/QUA-439)) and was retired the same day; CEO stood up **Quality-Business 2** (`0ab3d743-...`, cwd `C:\QM\worktrees\quality-business`) as the working replacement — the retired record is preserved as `Quality-Business (RETIRED 2026-04-28)`.

## Wave Hire Triggers

Triggers are conjunctive (ALL conditions must hold). Source: `decisions/2026-04-27_v5_org_proposal.md` § Wave plan.

### Wave 2 — Quality-Tech → Development → Quality-Business
1. PC1-00 Drive-sync `.git/` mass-delete mitigation merged + verified
2. CTO Implementation Order steps 1–5 committed (`framework/include/QM_*.mqh` + magic registry template) and compiling
3. ≥1 approved Strategy Card from Research

Hire order inside Wave 2:
- **Quality-Tech first** — independent EA code-review gate beyond CTO
- **Development second** — only when framework includes exist for `EA_Skeleton.mq5`
- **Quality-Business third** — gated on first PASS-eligible EA producing reports

### Wave 3 — Controlling, Observability-SRE
- Trigger: ≥3 EAs in P10 burn-in **OR** live trading begins on T6 (whichever first).
- Until then DevOps' monitoring scripts + CEO's gate decisions cover the same surface.

### Wave 4 — LiveOps
- Trigger: T6 Live/Demo automation runbook (`docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md`) operational AND DXZ funded account active.
- Hard rule: T6 OFF LIMITS to factory automation until LiveOps is hired AND OWNER explicit-approves the runbook.

### Wave 5 — R-and-D
- Trigger: Pipeline producing ≥10 PASS-eligible EAs/month (throughput threshold justifying dedicated R&D heartbeat).
- Until then CTO's "deep-research pre-check via Research" pattern (per `paperclip-prompts/cto.md`) covers the surface.

### Wave 6 — Chief of Staff
- **Deferred indefinitely** per `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`.
- Re-open only if OWNER → CEO bandwidth becomes the constraint.

## Skill Matrix (V5)

| Wave | Role | Model default | Required skills / tools | Primary processes |
|------|------|---------------|-------------------------|-------------------|
| 0 | CEO | Claude Opus | project-management, org-design, decision-log, risk-register, escalation, hiring-gate, gate-decisions | issue triage, hire approval, gate decisions, decision-log curation, board escalation packet |
| 0 | CTO | Codex | repo-code, MQL5-review, architecture-review, automation-review, EA-vs-Card review, framework spec authoring | technical design, EA code review, pipeline change review, framework implementation order |
| 0 | Research | Claude Opus | web/deep-research, source discovery, citation discipline, Strategy Card extraction | source research, Strategy Card extraction, deep-research pre-checks for CTO |
| 0 | Documentation-KM | Claude Opus | Notion ↔ Git sync, lessons-learned curation, episode artifact packaging, process registry maintenance, decision-log recording | Notion/Git nightly sync, lessons archive, process docs upkeep, episode show-notes draft, public/private wording boundary |
| 1 | DevOps | Codex | VPS, Windows, cron, GitHub Actions / Netlify, snapshot export, Drive-sync hygiene, lock-file monitoring | infrastructure setup, public-snapshot export, PC1-00 Drive-sync mitigation, MT5 portable factory state |
| 1 | Pipeline-Operator | Codex | MT5 tester automation, report validation, queue discipline, smoke-harness execution | backtest baseline, retest, evidence collection, smoke harness |
| 2 | Quality-Tech | Codex | statistics review, overfit checks, walk-forward audit, report audit, code review | technical PASS review, EA-vs-Card check, gate-evidence audit |
| 2 | Development | Codex | MQL5, Python, build scripts, compile verification | EA build, test harness changes, framework include implementation |
| 2 | Quality-Business | Claude | portfolio fit, narrative defensibility, public claim review, FTMO/DXZ compliance reading | business PASS review, investor-facing quality, public claim sign-off |
| 3 | Controlling | Claude (lightweight) | KPI accounting, expense tracking, public snapshot validation, sizing maths | expense log, KPI snapshot, V-Portfolio sizing, monthly performance review |
| 3 | Observability-SRE | Codex (lightweight) | logs, uptime, stale-export alerting, T6 health checks, ALERT-file authoring | monitoring, incident detection, disaster-recovery liveness probing |
| 4 | LiveOps | Codex + strict runbooks | MT5 profiles/templates, UI automation fallback, manifest execution, AutoTrading-OFF verification | T6 deploy (per OWNER manifest), T6 monitoring, emergency halt |
| 5 | R-and-D | Mixed | experiment design, pipeline improvement proposals, V4 lessons interpretation | process/pipeline change proposals, edge research |

## Mapping prompt-defined responsibilities → skill rows

Each agent's V5 BASIS prompt at `paperclip-prompts/<role>.md` lists their concrete duties. This skill matrix is the index from those duties to a discrete skill name. When CEO assigns a new responsibility, Doc-KM adds a row or extends an existing row here so the skill ↔ duty mapping stays explicit.

Convention: when a duty in `paperclip-prompts/<role>.md` is not yet covered by a row in this matrix, raise it through the **Skill Governance** flow below before assigning the work.

## Process ownership matrix

This is the **V5 working matrix** as of 2026-04-27. Owners are accountable agents; reviewers are independent verifiers. Wave-2+ rows show the future owner with a **Wave N interim** note where applicable. See `decisions/2026-04-27_v5_org_proposal.md` § 7 for the canonical version.

| Process | Owner | Reviewer | Cadence | V5 interim notes |
|---------|-------|----------|---------|-----------------|
| Hire approval | CEO | OWNER | per-event | Per DL-017 + DL-023, hires no longer require board approval; OWNER reviews retroactively |
| Strategy Card extraction | Research | CEO + Quality-Business | per-source | Quality-Business absent until Wave 2 → CEO covers business gate |
| EA spec | CTO | Research (deep-research pre-check) | per-card | — |
| EA code review | CTO | Quality-Tech | pre-smoke | Quality-Tech absent until Wave 2 → CTO is sole reviewer until then |
| Smoke harness execution | Pipeline-Operator | CTO | per-EA | — |
| Pipeline phase gates G0..P10 | CEO | CTO + Quality-Business | per-EA per-phase | Quality-Business deferred → CEO covers business reasoning |
| Notion ↔ Git sync | Documentation-KM | DevOps (cron health) | nightly 23:00 UTC | — |
| Episode publishing (no auto-publish) | Documentation-KM | OWNER | per-episode | OWNER sign-off mandatory; Doc-KM never auto-publishes |
| Infra reproducibility | DevOps | CTO | per-change | — |
| Public dashboard export | DevOps + Controlling | CEO | hourly | Controlling absent → DevOps + CEO until Wave 3 |
| Lessons archive | Documentation-KM | CEO | per-lesson | — |
| Disaster recovery | DevOps | Observability-SRE | event | Obs-SRE absent → DevOps owns liveness probing until Wave 3 |
| Disk + Drive-sync maintenance | DevOps | Observability-SRE | continuous | DevOps owns full surface until Obs-SRE Wave 3 |
| Live T6 deploy | LiveOps | OWNER | per-manifest | LiveOps absent → OWNER + DevOps **manual only** until Wave 4 |

## Website Role Skill Pack

The agent or worker maintaining quantmechanica.com needs:

- frontend design skill for layout, hierarchy, dashboard usability, and responsive polish
- static-site implementation skill for Astro/11ty, Tailwind, build pipeline, and Netlify
- data-contract skill for public snapshot JSON schemas
- content-redaction skill for public/private boundaries
- accessibility and mobile verification checklist
- screenshot/browser verification before public release
- support/CTA wording isolation: Buy-me-a-coffee + episode-pack copy stays separated from investment/portfolio claims

In V5 today this surface is owned by **DevOps** (build + deploy) + **Documentation-KM** (public/private wording). Hourly snapshot export is a **DevOps cron** with **Controlling** (Wave 3) reviewing KPI correctness when hired; **CEO** reviews the rendered output until Controlling lands.

Design rule: retain the current QuantMechanica design direction, then add a Paperclip-style operations surface. Do not replace the whole site with a generic dashboard.

## Skill Governance

Before assigning a new skill to a role, CEO must answer:

1. What process requires this skill?
2. What actions may the skill perform?
3. What actions are forbidden?
4. What evidence proves it was used correctly?
5. Who reviews the output?
6. When is the skill retired or restricted?

Outcome of this gate is recorded as a comment on the skill-introduction issue **and** a one-line row update in this matrix.

## Suggested Repo Layout

```text
skills/
  frontend-dashboard.md
  mt5-liveops.md
  strategy-research.md
  backtest-evidence.md
  quality-tech-review.md
  quality-business-review.md
  incident-response.md
processes/
  source-research.md
  strategy-card.md
  ea-build.md
  baseline-backtest.md
  deploy-manifest.md
  website-snapshot-export.md
  episode-publishing.md
  lessons-learned.md
checklists/
  t6-deploy.md
  public-dashboard-release.md
  episode-publish.md
  live-risk-halt.md
```

## First Required Skills

1. `frontend-dashboard` — for quantmechanica.com dashboard integration.
2. `website-snapshot-export` — for hourly public updates.
3. `strategy-research` — for source-by-source Strategy Card extraction.
4. `backtest-evidence` — for report validation and NO_REPORT handling.
5. `t6-liveops` — for manifest-driven EA placement on T6 (locked behind LiveOps Wave 4 hire).
6. `episode-publishing` — for YouTube + website + newsletter + Buy-me-a-coffee CTA + artifact packaging.

## References

- V5 org proposal: [`decisions/2026-04-27_v5_org_proposal.md`](../../decisions/2026-04-27_v5_org_proposal.md)
- CEO hire-approval waiver: DL-017 (registered in [`decisions/REGISTRY.md`](../../decisions/REGISTRY.md))
- CEO autonomy waiver v2: [`decisions/2026-04-27_ceo_autonomy_waiver_v2.md`](../../decisions/2026-04-27_ceo_autonomy_waiver_v2.md) (DL-023)
- BASIS prompts: [`paperclip-prompts/`](../../paperclip-prompts/) (OWNER-managed; agents do not edit)
- Org self-design: [`docs/ops/ORG_SELF_DESIGN_MODEL.md`](ORG_SELF_DESIGN_MODEL.md)
- Bootstrap context: [`docs/ops/PAPERCLIP_V2_BOOTSTRAP.md`](PAPERCLIP_V2_BOOTSTRAP.md)
