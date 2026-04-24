# Agent Skill Matrix

Purpose: define which Paperclip roles need which skills, tools, and operating processes.

## Principle

Prompts are not enough. Each role should have a skill pack that matches its real work. CEO owns assignment; CTO verifies technical capability; Documentation-KM keeps the matrix current.

Skills can be native Paperclip skills, Codex skills, Claude project instructions, scripts, SOP checklists, or repo-local runbooks. A role may use a skill only within its write authority.

## Initial Skill Matrix

| Role | Model default | Required skills / tools | Primary processes |
|---|---|---|---|
| CEO | Claude | project-management, org-design, decision-log, risk-register, escalation | milestone review, hiring gate, gate decisions |
| CTO | Codex | repo-code, MQL5-review, architecture-review, automation-review | technical design, pipeline change review |
| Research | Claude | web/deep-research, source-card extraction, citation discipline | source research, strategy card extraction |
| Documentation-KM | Claude | Notion/Git sync, lessons-learned, episode artifact packaging | process registry, public docs, video support CTA |
| DevOps | Codex | VPS, Windows, cron, GitHub Actions/Netlify, snapshot export | infrastructure setup, website snapshot export |
| Development | Codex | MQL5, Python, build scripts, compile verification | EA build, test harness changes |
| Pipeline-Operator | Codex or automation agent | MT5 tester automation, report validation, queue discipline | backtest baseline, retest, evidence collection |
| Quality-Tech | Mixed | statistics review, overfit checks, report audit, code review | technical PASS review |
| Quality-Business | Claude | portfolio fit, narrative defensibility, public claim review | business PASS review, investor-facing quality |
| Controlling | Claude or lightweight agent | KPI accounting, expense tracking, public snapshot validation | expense log, KPI snapshot |
| Observability-SRE | Codex or lightweight agent | logs, uptime, stale export alerting, T6 health checks | monitoring, incident response |
| LiveOps | Codex + strict runbooks | MT5 profiles/templates, UI automation fallback, manifest execution | T6 deploy, T6 monitoring, emergency halt |
| R-and-D | Mixed | experiment design, pipeline improvement proposals | process/pipeline change proposal |

## Website Role Skill Pack

The agent or worker maintaining quantmechanica.com needs:

- frontend design skill for layout, hierarchy, dashboard usability, and responsive polish
- static-site implementation skill for Astro/11ty, Tailwind, build pipeline, and Netlify
- data-contract skill for public snapshot JSON schemas
- content-redaction skill for public/private boundaries
- accessibility and mobile verification checklist
- screenshot/browser verification before public release

Design rule: retain the current QuantMechanica design direction, then add a Paperclip-style operations surface. Do not replace the whole site with a generic dashboard.

## Skill Governance

Before assigning a new skill to a role, CEO must answer:

1. What process requires this skill?
2. What actions may the skill perform?
3. What actions are forbidden?
4. What evidence proves it was used correctly?
5. Who reviews the output?
6. When is the skill retired or restricted?

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

1. `frontend-dashboard`: for quantmechanica.com dashboard integration.
2. `website-snapshot-export`: for hourly public updates.
3. `strategy-research`: for source-by-source strategy extraction.
4. `backtest-evidence`: for report validation and NO_REPORT handling.
5. `t6-liveops`: for manifest-driven EA placement on T6.
6. `episode-publishing`: for YouTube, website, newsletter, Buy-me-a-coffee CTA, and artifact packaging.

