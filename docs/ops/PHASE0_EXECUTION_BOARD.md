# Phase 0 Execution Board

Date range: 2026-04-21 to 2026-04-28
Goal: turn the V5 plan into a runnable, public, auditable foundation.

> **Owner-field reading rule (added 2026-04-26):** the `Owner` column lists the *planned long-term owner* (CEO, CTO, Pipeline-Operator, etc.). Paperclip is not installed yet, so most named owners do not exist as agents. For *today's actual owner* of each row see `PROJECT_BACKLOG.md` § Phase 0 — most rows are owned by OWNER + Board Advisor Claude in interim, others are blocked on Phase 1 (Paperclip Bootstrap). When Paperclip Wave 0 comes online, the named owners take over per `docs/ops/ORG_SELF_DESIGN_MODEL.md`.

## Decision

V5 is a restart. The first week should produce a clean public skeleton and a reproducible VPS factory, not revive the old QUAA company.

## Workstreams

| ID | Workstream | Owner | Done evidence |
|---|---|---|---|
| P0-01 | Order Hetzner AX42-U dedicated server | OWNER | DONE 2026-04-22: order B20260421-3420195-2995101, server #2982904 online in Rescue System, HEL1, IPv4 `37.27.225.167`, 1 TB extra NVMe, expense log updated; root/rescue password not stored |
| P0-02 | Install Windows Server 2022 Evaluation | OWNER + DevOps | Windows Server 2022 Eval boots, `slmgr /xpr` documented, Month-5 license reminder created |
| P0-03 | Harden Windows Server | OWNER + DevOps | RDP on non-default port, IPBan installed, firewall verified |
| P0-04 | Install MT5 T1-T5 factory terminals | DevOps + Pipeline-Operator | 5 terminals boot, separate portable data paths |
| P0-05 | Install MT5 T6 Live/Demo terminal | LiveOps + OWNER approval | T6 boots, no Strategy Tester use, AutoTrading initially OFF |
| P0-06 | Confirm DarwinexZero/Darwinex MT5 access and data path | OWNER + DevOps | DarwinexZero reset/new account decision documented, MT5 Demo/Live login verified, MT5-native data path or alternative backtest-data approach approved |
| P0-07 | Populate public repo skeleton | OWNER + Documentation-KM | `https://github.com/QuantMechanica/VPS-PortfolioBuild` contains `README.md`, `docs/`, `paperclip-prompts/`, `episodes/`, `expenses/` |
| P0-08 | Export V5 Notion docs to repo | Documentation-KM | Charter, pipeline, research, learnings exported |
| P0-09 | Export 13 Paperclip V2 prompts to repo | Documentation-KM | `paperclip-prompts/*.md` present, old QUAA prompts not reused |
| P0-10 | Install fresh Paperclip company | OWNER + CEO | Company `QuantMechanica V5`, project `Portfolio Factory V5` |
| P0-11 | Hire first four agents | OWNER | CEO, CTO, Research, Documentation-KM online |
| P0-12 | Create seed-strategy import list | Research + CEO | `strategy-seeds/index.md` with keep/retest/reject buckets |
| P0-13 | Create T6 deploy manifest schema | CTO + LiveOps | `deploy-manifests/schema.yaml` reviewed |
| P0-14 | Record EP01 | OWNER | Script, recording, thumbnail, show notes archived |
| P0-15 | Publish public expense log v0 | Documentation-KM | CSV + Notion mirror agree |
| P0-16 | Define quantmechanica.com dashboard snapshot schema | Documentation-KM + Controlling | `public-snapshot.schema.json` drafted; hourly export path documented |
| P0-17 | Create Paperclip process registry and roadmap | CEO + Documentation-KM | `processes/` registry drafted; public process roadmap spec linked |
| P0-18 | Create agent skill matrix | CEO + CTO | `skills/` / `checklists/` plan drafted; role-to-skill matrix approved |
| P0-19 | Add website support CTA and process-roadmap contract | Documentation-KM + Website owner | Buy-me-a-coffee CTA copy, get-in-contact path, process roadmap widget spec |
| P0-20 | Register news calendar seed asset and install on VPS | DevOps + Pipeline-Operator | `seed_assets/news_calendar/MANIFEST.md` reviewed; files copied to `D:\QM\data\news_calendar\`; SHA256 and row counts verified — DONE 2026-04-24 (see `MIGRATION_LOG.md`) |
| **P0-21** | **Verify Tick Data Manager DarwinexZero GMT/DST settings** (Notion-canonical) | DevOps + Pipeline-Operator + Quality-Tech | **ACTIVE — current Phase-0 task per OWNER 2026-04-26.** Method: configure Tick Data Manager with base GMT offset `+2` and DST enabled, then export a small sample around US/EU DST transition weeks before any bulk download. Compare M15/H1 timestamps against a connected DarwinexZero MT5 terminal. Evidence: TDM settings screenshot, exported sample path, MT5 chart screenshot for same symbol/time window, QA note confirming `GMT+2` winter / `GMT+3` US-summer behavior under `D:\QM\reports\setup\tick-data-timezone\`. Failure class: `SETUP_DATA_MISMATCH`, never strategy failure. Detail: `docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md`. |
| P0-22 | Migrate canonical reconstruction docs from laptop | Claude Board Advisor | DONE 2026-04-25: `docs/ops/CANONICAL_LAPTOP_STATE_2026-04-25.md` and `docs/ops/CANONICAL_STRATEGY_ARCHIVE_2026-04-25.md` byte-identical from Drive. (Renumbered from previous P0-21 to resolve drift with Notion-canonical P0-21.) |
| P0-23 | Replace 10-phase pipeline outline with 15-phase canonical spec | CTO + Claude Board Advisor | DONE 2026-04-25: `docs/ops/PIPELINE_PHASE_SPEC.md` written from laptop `doc/pipeline-v2-1-detailed.md`; `PIPELINE_AUTONOMY_MODEL.md` rewritten; decision log entry. |
| P0-24 | Migrate process registry from laptop | Documentation-KM + CEO | DONE 2026-04-25: 13 files (12 process docs + README) byte-identical from `Company/Processes/`; SHA256 in `MIGRATION_LOG.md` Phase E. Content review by CEO + CTO still pending Wave 0 hire. |
| P0-25 | Migrate V4 strategy artifacts as labelled basis-reference | Research + Documentation-KM | DONE 2026-04-26: 5 markdown specs in `strategy-seeds/specs/` with V4-basis banner; `strategy-seeds/v5_locked_basket_2026-04-18.md` rewritten as V4-historical snapshot. **V5 strategy bestand (specific SM_XXX sleeves) starts fresh; V4 framework patterns and learnings ARE inherited (see `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md`).** |
| P0-26 | Decide fate of V4 news-impact tooling | DevOps + Development + CTO | CLOSED 2026-04-26: Codex confirmed `run_news_impact_tests.py` does **not** exist on laptop. V4 P8 was hand-orchestrated. V5 builds news-impact tooling from scratch as part of V5 framework. |
| P0-27 | Establish V5 EA framework | CTO + Development | DESIGN DONE + DEFAULTS CONFIRMED + V4-PATTERNS ENCODED 2026-04-26: spec at `framework/V5_FRAMEWORK_DESIGN.md` covers 25-step Codex implementation order, 6 confirmed defaults, plus V4-inherited patterns (Friday Close, BT-Fixed/Live-Percent risk convention, .DWX discipline, Model 4, magic schema, Enhancement Doctrine, Darwinex-native data, 4-module Modularity, gridding 1%-cap, ML ban). Implementation pending Codex (continues after Phase 1 hire). |
| P0-28 | Reconstruct V5 sub-gate spec | CTO + Quality-Tech | DONE 2026-04-26: `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` written from surviving evidence after Codex second-pass confirmed `CODEX_PIPELINE_V2.1_SPEC/IMPACT/DIFF.md` MISSING. Per-phase defaults for P3.5, P5, P5b, P5c, P6, P7, P10. Quality-Tech recalibration triggers documented. |
| P0-29 | Migrate brand system + write V5 brand guide | OWNER + Documentation-KM | DONE 2026-04-26: `branding/QM_BRANDING_GUIDE.md` and `branding/brand_tokens.json` written from canonical Drive `ClaudeDesign_Upload/`. |
| P0-30 | Extend framework with trade-mgmt + chart UI | CTO + Development | DESIGN DONE 2026-04-26: 7 new include modules — `QM_Branding`, `QM_OrderTypes`, `QM_Entry`, `QM_Exit`, `QM_StopRules`, `QM_TradeManagement`, `QM_ChartUI`. Per-EA in-chart dashboard widget specced. Implementation pending Codex. |
| P0-31 | Migrate V4 lessons-learned (basis for V5) | Documentation-KM + Claude Board Advisor | DONE 2026-04-26: `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md` (22 KEPT/CHANGED/DISCARDED entries from Notion as V5 BASIS, not legacy archive). `lessons-learned/2026-04-20_mass_delete_incident.md` and `lessons-learned/2026-04-20_file_deletion_policy_v1.md` byte-identical from Drive. **Mass-delete root-cause was Drive-sync conflict on `.git/` — same architectural risk applies to VPS unless mitigated; tracked in `PROJECT_BACKLOG.md` § Open / Weak Items.** |

## Acceptance Gate For Phase 0

Phase 0 is done only if:
- T1-T5 can run non-live factory work without touching T6.
- T6 can start, connect, and stay isolated with AutoTrading OFF.
- Fresh Paperclip V5 company exists with no old QUAA issue import.
- Public repo exists from commit 1: https://github.com/QuantMechanica/VPS-PortfolioBuild
- Process registry, skill matrix, and first milestone board exist.
- Expense log contains the real Hetzner order; later license/software purchases are added as they happen.
- News calendar seed asset is copied to the VPS and verified before any news-aware strategy run.
- EP01 is published or ready for final human publish approval.
- Codex reviews Notion vs repo docs and signs off on no contradictions.

## Explicit Non-Goals

- No live-money deployment.
- No old QUAA issue migration.
- No strategy PASS claims from old reports.
- No marketplace/shop work.
- No dashboard relaunch beyond placeholder JSON contracts.

## First Paperclip Issues To Create

1. `P0: Verify VPS baseline and hardening`
2. `P0: Export Notion V5 docs to public repo`
3. `P0: Export clean Paperclip V2 prompts`
4. `P0: Build T1-T6 MT5 layout and isolation proof`
5. `P0: Draft T6 deploy manifest schema`
6. `P0: Create seed-strategy import index`
7. `P0: Prepare EP01 artifact pack`
8. `P0: Draft quantmechanica.com public dashboard snapshot schema`
9. `P0: Draft Paperclip process registry and process roadmap`
10. `P0: Draft agent skill matrix`
11. `P0: Add Buy-me-a-coffee and get-in-contact website CTA contract`
12. `P0: Register news calendar seed asset and install on VPS`

## Phase 0 Review Questions

- Did we accidentally reuse old QUAA runtime state?
- Is the T6 live terminal protected from factory sweeps?
- Are all public claims backed by a file, receipt, report, or screenshot?
- Is every recurring task attached to a named process, checklist, owner, and evidence standard?
- Are required seed data assets present and verified before the first dependent run?
- Does each active agent have the skills needed for its assigned processes?
- Can a new viewer understand the build from the public repo alone?
- Is OWNER still only approving, steering, and observing?
