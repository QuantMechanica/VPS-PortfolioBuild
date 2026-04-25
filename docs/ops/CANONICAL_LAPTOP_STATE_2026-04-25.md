# Canonical Laptop State Reconstruction - 2026-04-25

## Purpose

This document reconstructs the real QuantMechanica project state on the laptop as of 2026-04-25. It exists because the current Notion restart/VPS build pages are materially incomplete and simplify away important parts of the project that still exist locally.

This file is intended to become the canonical source for:

- the real pre-VPS company and Paperclip operating state
- the actual pipeline and deploy model
- the news backtesting and calendar dependency
- the current V5 lineup / exclusions
- the process and fallback system
- VPS bootstrap prompts and future agent onboarding

## Source Precedence

For this reconstruction, source precedence is:

1. Filesystem artifacts on the laptop
2. Current local runbooks / process docs / results receipts
3. Local Paperclip bootstrap and recovery docs
4. Existing Notion pages

If Notion conflicts with local receipts, the local receipts win.

## Executive Summary

The laptop project is materially richer than the current Notion restart narrative. The local system already contains:

- a real Paperclip cutover and recovery model
- a 13-agent operating system with routines, heartbeats, and a Portfolio-Factory project
- a more complete V2.1 pipeline than the simplified current Notion page
- real P8 News Impact work and a preserved news/calendar seed asset
- risk review artifacts, locked-basket evidence, and explicit sleeve exclusions
- a large local strategy archive, not just a few strategy references
- process OS documents, runner guides, and incident / recovery playbooks

The restart/VPS build in Notion is useful as a forward build plan, but it is not yet an accurate representation of the full laptop state.

## Critical Corrections To The Current Restart Narrative

### 1. News backtesting is part of the project

News backtesting is not missing conceptually. It already exists locally as:

- pipeline phase `P8 News Impact`
- local tool references to `run_news_impact_tests.py`
- local result receipt `Company/Results/SM_221_P8_NEWS_IMPACT_20260418.md`
- preserved seed files under `Company/V5_Public_Build/seed_assets/news_calendar/`

This means the project must explicitly model news-aware validation, not just generic backtesting.

### 2. There is no canonical "30-day demo testing" gate

The current Notion `V5 Pipeline Design` page still describes `P8 Demo Deploy` as a 30-day DarwinexZero/demo observation phase. That is not the canonical laptop-state model.

The actual local pipeline and process docs describe:

- `P8` = News Impact
- `P9` = Portfolio Construction
- `P9b` = Operational Readiness
- `P10` = Shadow Deploy

The detailed local pipeline describes `P10 Shadow Deploy` as a **2-week forward test with KS-test kill-switch policy**, not a generic 30-day demo holding pen.

### 3. A sleeve can end up live at the end of the portfolio flow

The local process model does not describe a permanent demo-only phase. It describes a promotion path:

- validated candidate
- portfolio admission
- operational readiness
- VPS deploy
- first live heartbeat
- smoke checks
- live monitoring

So the project must model that an EA can become live at the end of the portfolio/deploy flow once gates are cleared.

### 4. "Richer thinking" already exists locally

The current Notion pages understate the amount of operational and governance thinking already present on the laptop. Local evidence includes:

- `RECOVERY.md`
- `Company/BOOTSTRAP_FINAL_CUTOVER.md`
- `Company/HANDOFF.md`
- `Company/TODO.md`
- `Company/Processes/*.md`
- `Company/Analysis/Process_Audit_20260419.md`
- `Company/scripts/README_V2.1_RUNNERS.md`

This is already a company operating system, not just a strategy notebook.

## Local Company / Paperclip Operating State

### Current Paperclip reality on the laptop

The laptop state documents a real Paperclip cutover, not just a future plan.

Key evidence:

- `RECOVERY.md`
- `Company/BOOTSTRAP_FINAL_CUTOVER.md`

Key facts:

- Paperclip installed locally at `C:\Paperclip`
- local Paperclip data under `C:\Users\fabia\.paperclip`
- browser health check / control plane expected at `http://localhost:3100`
- local Claude is no longer the company CEO in the old setup
- Paperclip CEO was the intended operational decision-maker for the pipeline / portfolio system
- `Portfolio-Factory` project existed in Paperclip
- the cutover docs refer to 13 system prompts and multiple active spawned agents

### Agent system

The local state includes a richer agent system than the VPS restart pages currently show. The old laptop state references:

- 13 system prompts
- recurring heartbeat expectations
- specialized roles such as CEO, CTO, Pipeline-Operator, Observability-SRE, Quality roles, Controlling, Research, Documentation, LiveOps

This must be reflected in the future company docs, even if the VPS rebuild starts smaller.

### Process operating system

The local project has a real process registry in `Company/Processes/` including:

- EA lifecycle
- ZT / NO_REPORT recovery
- V-Portfolio deploy
- Incident response
- Dashboard refresh cadence
- Issue triage
- CEO <-> CTO dialectic
- Daily operating rhythm
- Disaster recovery
- Agent re-scope
- Disk and sync
- Board escalation

This process layer is part of the real project state and should not be omitted from canonical documentation.

## Canonical Pipeline Model From The Laptop

The detailed local pipeline in `doc/pipeline-v2-1-detailed.md` is currently the best available source for the real phase structure:

- `G0` Research Intake
- `P1` Build Validation
- `P2` Baseline Screening
- `P3` Parameter Sweep
- `P3.5` Cross-Sectional Robustness
- `P4` Walk-Forward
- `P5` Stress
- `P5b` Calibrated Noise
- `P5c` Crisis Event Slices
- `P6` Multi-Seed
- `P7` Statistical Validation
- `P8` News Impact
- `P9` Portfolio Construction
- `P9b` Operational Readiness
- `P10` Shadow Deploy

This is materially more complete than the simplified current Notion page.

## Deploy / Live Model

The actual local deploy model is not a vague demo phase. The process doc `Company/Processes/03-v-portfolio-deploy.md` states:

- candidate is promoted onto the V-Portfolio and VPS trading environment
- monitoring is attached
- first live heartbeat follows deploy
- smoke checks occur inside the first 24h of live trading
- rollback decision happens inside that early live window

This matters because the canonical project model must distinguish:

- research/test factory work
- operational readiness
- shadow deploy
- live deploy with monitoring

## News Backtesting And Calendar Dependency

### Canonical statement

The project has a real news-aware testing lane. News/calendar data is not optional for any strategy, EA, or backtest that depends on:

- news filters
- news pause windows
- economic calendar events
- event-impact analysis

### Local evidence

#### Pipeline and result evidence

- `Company/Results/SM_221_P8_NEWS_IMPACT_20260418.md`
- `Company/TODO.md` references to `run_news_impact_tests.py`
- `Company/Controlling/build_kpi_sections.py` scanning P8 artifacts
- `doc/pipeline-v2-1-detailed.md` explicit `P8 News Impact`

#### Preserved seed asset

The laptop already contains the preserved V1-V5 news seed asset:

- `Company/V5_Public_Build/seed_assets/news_calendar/MANIFEST.md`
- `Company/V5_Public_Build/seed_assets/news_calendar/news_calendar_2015_2025.csv`
- `Company/V5_Public_Build/seed_assets/news_calendar/forex_factory_calendar_clean.csv`

From the manifest:

- `news_calendar_2015_2025.csv`
	- original common-files source path documented
	- size: `4,430,868 bytes`
	- rows: `47,992`
- `forex_factory_calendar_clean.csv`
	- original common-files source path documented
	- size: `4,300,927 bytes`
	- rows: `48,001`

### Canonical rule

Missing news files must be classified as:

- `SETUP_DATA_MISSING`

and **not** as strategy failure.

## Current V5 Composition State

The local risk review is currently the strongest source for the active locked V5 lineup.

Source:

- `Company/Results/V5_PORTFOLIO_RISK_REVIEW_20260418.md`

### Locked 5-sleeve basket

Locked basket:

- `SM_124`
- `SM_221`
- `SM_345`
- `SM_157`
- `SM_640`

### Explicit exclusions / outlier sleeves

Not in the locked V5 lineup:

- `SM_890 AUDUSD`
- `SM_890 EURUSD`
- `SM_882 WS30`

The outlier review states these remain at zero active V5 weight in the current locked composition.

### Important nuance

Even in this locked-basket state, the local risk review still documents open waivers and missing artifacts on some lanes. So the canonical state is not "finished / perfect"; it is "documented, partially locked, and still carrying explicit evidence gaps".

## V4 / V5 Live Divergence Is Part Of The Canonical Story

The laptop `Company/TODO.md` explicitly documents severe backtest-vs-live divergence for the V4 live portfolio and an explicit decision not to pause the V5 launch, but instead to re-run live EAs through the new pipeline constraints.

This is a critical part of the project history and must remain visible in canonical documentation because it directly explains:

- the stricter pipeline
- the emphasis on richer evidence
- the refusal to trust simplistic deploy narratives
- the stronger separation between setup failures and strategy failures

## Strategy State

The laptop project contains two different strategy archives:

### 1. Rich markdown strategy specs

Under `Company/Research/strategies/`:

- `ath-breakout-atr-trail.md`
- `good-carry-bad-carry.md`
- `modernising-turtle-trading.md`
- `seasonality-trend-mr-bitcoin.md`
- `two-regime-trend-following.md`

These contain detailed economic thesis, failure thesis, inputs, MT5-native feasibility, and CTO implementation notes.

### 2. Historical website strategy archive

Local path:

- `Backups/pre_claude_design_20260418/Website/strategies/`

Count:

- `402` HTML strategy pages

This historical archive is real project knowledge and should be reflected in Notion as a local strategy archive snapshot, even if it is not converted into 402 fully separate Notion pages immediately.

## Fallbacks, Hard Rules, And Recovery

Canonical laptop-state rules include:

- filesystem is truth
- smoke != baseline-equivalent
- NO_REPORT must be separated from EA weakness
- missing seed data is setup failure, not strategy weakness
- `.DWX` remains part of research/backtest workflow and is stripped only at VPS deploy packaging
- unique deterministic magic numbers are mandatory
- Git is canonical source of truth for project files

Operational fallback / recovery artifacts include:

- `RECOVERY.md`
- `Company/Processes/09-disaster-recovery.md`
- `Company/Processes/11-disk-and-sync.md`

These are part of the canonical system and must survive into the VPS-oriented documentation.

## What The VPS Build Must Inherit From The Laptop

At minimum, the VPS build must inherit:

- the real pipeline phase model
- the news-calendar seed asset requirement
- the Paperclip / company operating model
- the current process registry
- the locked basket / excluded-sleeve state
- the distinction between setup-data failures and strategy failures
- the strategy archive snapshot

## Canonical Source Artifacts For Reconstruction

The most important local source files used for this reconstruction are:

- `CLAUDE.md`
- `RECOVERY.md`
- `Company/BOOTSTRAP_FINAL_CUTOVER.md`
- `Company/HANDOFF.md`
- `Company/TODO.md`
- `Company/Processes/README.md`
- `Company/Processes/03-v-portfolio-deploy.md`
- `Company/Processes/08-daily-operating-rhythm.md`
- `Company/scripts/README_V2.1_RUNNERS.md`
- `Company/Analysis/Process_Audit_20260419.md`
- `doc/pipeline-v2-1-detailed.md`
- `Company/Results/SM_221_P8_NEWS_IMPACT_20260418.md`
- `Company/Results/V5_PORTFOLIO_RISK_REVIEW_20260418.md`
- `Company/V5_Public_Build/seed_assets/news_calendar/MANIFEST.md`
- `Company/Research/strategies/*.md`
- `Backups/pre_claude_design_20260418/Website/strategies/*.html`

## Immediate Documentation Consequence

New Notion documentation must not overwrite the existing restart pages blindly. It should add canonical reconstruction pages that:

- explain the delta versus the simplified restart narrative
- preserve the real laptop operating state
- become the source material for future VPS agent onboarding
