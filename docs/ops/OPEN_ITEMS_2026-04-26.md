# Open Items Audit — 2026-04-26 (post-Sweep-3)

After 13 commits and three migration sweeps, this is the honest inventory of what is NOT done. Grouped by the actor who can move it, ordered roughly by impact.

This file replaces / supersedes the "Open / Weak Items" section in `PROJECT_BACKLOG.md` for the moment-in-time view. Backlog stays the rolling source-of-truth; this is a one-shot snapshot for OWNER decision-making.

## OWNER + Board Advisor — actionable today

These can move forward with this Claude session and OWNER walking the steps.

| Priority | Item | Why it matters | Anchor |
|---|---|---|---|
| 1 | **P0-21 Tick Data Manager DST verification on T1** | Pflicht-Voraussetzung vor jedem Backtest; unverified TDM = `SETUP_DATA_MISMATCH` risk on every future result | `docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md` |
| 2 | **PC1-00 Drive `.git/` exclusion + git mutex** | V4 mass-delete root cause (`lessons-learned/2026-04-20_mass_delete_incident.md`); same architecture on VPS unless mitigated. Must close BEFORE Wave 0 hire. | `PROJECT_BACKLOG.md` § Phase 1 |
| 3 | **VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json measurement on Darwinex demo via T1** | P5 Stress + P5b Calibrated Noise both depend on this; without it, every V5 EA stalls before P5 | `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` § P5 |
| 4 | **MT5 install + T1-T5 + T6 isolation proof** (P0-04 / P0-05) | Hard prereq for Pipeline-Operator (Wave 1) and LiveOps (Wave 4) to do anything | Phase 0 board |
| 5 | **DarwinexZero MT5 access confirmation** (P0-06) | New DXZ account decision is in the docs; actual login test pending | Phase 0 board |
| 6 | **Public Expense Log first commit to dashboard cycle** | P0-15 partially done (file exists); needs cron job + first hourly export before dashboard MVP | `expenses/expenses.csv` + `WEBSITE_DASHBOARD_PAPERCLIP_STYLE.md` |
| 7 | **EP01 artifact pack** (script + thumbnail + show-notes) | Phase 0 acceptance gate item; OWNER-driven content production | `docs/ops/EPISODE_GUIDE.md` |
| 8 | **First T6 deploy manifest dry-run** (harmless EA, AutoTrading OFF) | LiveOps spec requires dry-run before any real EA touch; can run before Paperclip if OWNER + Board Advisor walk it | `docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md` § First Implementation Task |

## OWNER alone — gate decisions, no Board-Advisor work

| Priority | Item | What's needed |
|---|---|---|
| A | News-Compliance Hybrid A+C confirmation | Read `decisions/2026-04-25_news_compliance_variants_TBD.md`, accept or revise the recommendation, name first-wave deploy targets (FTMO? 5ers? DXZ-only?) |
| B | Brand Guide § 10 questions | Sync auto-generation `sync_brand_tokens.ps1` design (default proposed: yes), mascot in framework (default: no) |
| C | V5/V6 deploy folder choice | `Company/VPS/V5/` vs `V6/` (laptop legacy decision per V5_COMPOSITION_LOCK) — only matters if V4 sleeves ever revisited |
| D | Tick Data Suite renewal decision | License expires ~2026-05-05: Monthly €32.90 / Yearly €189 / Lifetime €549 |
| E | MyOEM Windows Server license decision | Defer to Month 5 per current plan (~2026-09); remind closer to date |

## Wave 0 — blocked until Paperclip installed

These are first-issues for the four Wave 0 hires once Paperclip is online.

### CEO-Claude (first issues)

- Org proposal: which Wave-1+ roles get hired when, given the actual backlog
- Process registry expansion: review the 12 migrated processes, mark Wave-0-relevant ones, write any V5-only processes still missing
- Skill matrix: confirm Wave 0 has the skills its assigned processes need
- First source approval (for Research first dispatch)
- Cross-challenge protocol calibration with Quality-Business once that role is hired

### CTO-Codex (first issues — biggest workload)

- Implement V5 Framework per `framework/V5_FRAMEWORK_DESIGN.md` § Implementation Order — 25 steps:
  1. `QM_Errors.mqh` → 2. `QM_Branding.mqh` → 3. `QM_Logger.mqh` → 4. `QM_MagicResolver.mqh` → ... → 25. Quality-Tech review
- `framework/scripts/sync_brand_tokens.ps1` (auto-generates `QM_Branding.mqh` from `branding/brand_tokens.json`)
- `framework/scripts/build_check.ps1` with greps for: hard-coded `clr*` constants, ML library imports, `we`-as-collective, profit-promise vocab, missing input groups
- `framework/scripts/compile_one.ps1`, `compile_all.ps1`, `run_smoke.ps1`, `validate_setfile.ps1`, `brand_report.ps1`, `rotate_logs.ps1`
- Strategy Card Template review + finalize
- EA-vs-Card review checklist as reusable template

### Research-Claude (first issues)

- Propose first source per `RESEARCH_METHODOLOGY_V2.md` seed list (Chan / Kaufman / Grimes / Ehlers / Raschke)
- Wait for OWNER + CEO approval, then exhaustive extraction

### Documentation-KM-Claude (first issues)

- Notion ↔ repo reconciliation pass: Notion `V5 Pipeline Design` superseded-banner is set; full content rewrite still needed
- Notion `Phase 0 Execution Board` extends to P0-21 only; repo extends to P0-34 — sync
- Reconcile `PAPERCLIP_OPERATING_SYSTEM.md` (laptop) vs `PAPERCLIP_OPERATING_SYSTEM_NOTION.md` (this Sweep 2)
- Reconcile `WEBSITE_DASHBOARD_PAPERCLIP_STYLE.md` (laptop) vs `QUANTMECHANICA_DASHBOARD_SPEC.md` (Sweep 2)
- Migrate from Notion to repo: `VPS Bootstrap PowerShell`, `Paperclip V2 Install & Company Creation`, `Episode Production Prompts`, `Common Dispatch Templates` (per `PROMPTS_AND_SCRIPTS_LIBRARY_INDEX.md`)
- Author Buy-me-a-coffee CTA copy
- EP01 show-notes draft from this session's transcripts

## Wave 1+ — blocked on Wave 0 + earlier waves

### DevOps (Wave 1)

- PC1-00 implementation if not closed by OWNER + Board Advisor first
- VPS Bootstrap PowerShell idempotent script
- Daily backup to Google Drive
- IPBan alerting config
- `export_public_snapshot.ps1` Windows Task Scheduler job (HH:07 hourly)
- Stale-snapshot alerting (90+ min trigger)
- `.git/` mutex / stale-`index.lock` monitor

### Pipeline-Operator (Wave 1)

- Verify T1-T5 spawn-respawn cycle works and T6 stays untouched
- Confirm aggregator loop pattern works on V5 framework output (V4 `standalone_aggregator_loop.py` is reference, not port)
- Run first known-good baseline cohort end-to-end smoke test

### Development (Wave 2)

- Wait for CTO framework PASS (PC2-25 Quality-Tech review)
- Take first approved Strategy Card from CEO
- Build first V5 EA per 4-module Modularity

### Quality-Tech (Wave 2)

- Build overfitting detection scripts (parameter sensitivity, MC runner)
- Document Darwinex typical spread ranges
- First sub-gate calibration pass after first V5 EA reaches P5b — re-evaluate provisional defaults in `PIPELINE_V5_SUB_GATE_SPEC.md`

### Quality-Business (Wave 2)

- Establish portfolio fit metric baseline
- Define reputable source criteria
- First month's review template

### Controlling (Wave 3)

- Verify dashboard HTML path writable (V5 path is `public-data/`)
- Integrate Public Expense Log source
- Establish Myfxbook API access credentials when live

### Observability-SRE (Wave 3)

- Verify monitoring endpoints reachable
- Tune alert thresholds against 48h baseline
- Set up escalation channels
- Implement stale-`index.lock` monitor per PC1-00

### LiveOps (Wave 4 — gated on T6 dry-run)

- Verify new DXZ account credentials in secrets store
- Configure T6 portable MT5 install + isolation tests
- Create deploy manifest schema YAML in Git (or confirm existing in `LIVE_T6_AUTOMATION_RUNBOOK.md` is final)
- Execute first dry-run manifest (harmless EA, AutoTrading OFF)
- Establish DXZ dashboard external monitoring cadence

### R-and-D (Wave 5)

- Review current Pipeline Design vs DSR/PBO/Walk-Forward literature
- First proposal under proposal-template format

## Phase Final — explicitly deferred

- Founder-Comms / Chief of Staff (`docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`)
- Trigger conditions in that doc; do NOT start until OWNER says "now build founder-comms"

## Repo housekeeping

| Item | Action |
|---|---|
| `docs/ops/DWX_IMPORT_AUTOMATION.md` (untracked since session start) | OWNER decide: commit, edit, or leave untracked |
| `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md` (untracked since session start) | Same — file deliberately frozen content; commit-or-leave is OWNER's call |
| Empty stub READMEs: `checklists/`, `risks/`, `skills/` | Wave 0 (CEO + Documentation-KM) populates as processes generate need |
| `processes/` content (12 V4 process docs migrated as basis) | CEO + Documentation-KM (Wave 0) review for V5-boundary; some reference QUAA tickets / old paths |
| `decisions/README.md` | Single line — would benefit from format spec + index of existing ADRs |
| `lessons-learned/README.md` | Single line — would benefit from format spec + V4-vs-V5 separation pointer |
| `prompts/` (legacy bootstrap prompts) | Wave 0 / Documentation-KM decides: keep, supersede, or move to `reference/` |

## Sweep-3 known-missing files (referenced but not on Drive)

Per Codex 2026-04-26 second-pass investigation, these scripts are referenced in V4 docs but do not exist on Drive:

- `Company/scripts/p35_csr_runner.py` — referenced in `Company/scripts/README_V2.1_RUNNERS.md`
- `Company/scripts/p5_calibrated_noise_runner.py` — referenced in same
- `Company/scripts/run_news_impact_tests.py` — referenced in `Company/TODO.md`

V5 builds these natively per `framework/V5_FRAMEWORK_DESIGN.md` and `PIPELINE_V5_SUB_GATE_SPEC.md`. No further migration possible.

## Honest summary

**What's done:** the entire spec layer. Pipeline (15 phases + sub-gates), framework (25-step impl order, V4 patterns encoded as code-rules), brand (tokens + assets + voice), V4 learnings as basis, 13 agent prompts, 4 critical V5-hub docs, process registry (12 docs, basis), public expense log, dashboard spec, V4 reference material. **12 commits, 13 ADRs.**

**What's not done:** anything that produces evidence. No EA compiles. No tick data verified. No calibration measured. No T6 isolation proven. No Paperclip running. No agent has acted.

The next concrete artifact is **P0-21 Tick Data Manager DST verification on T1**. Until that produces a CSV in `D:\QM\reports\setup\tick-data-timezone\`, V5 has paper, not artifacts.

Recommended next session: walk P0-21 with OWNER on T1.
