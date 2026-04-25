# Phase 0 Execution Board

Date range: 2026-04-21 to 2026-04-28
Goal: turn the V5 plan into a runnable, public, auditable foundation.

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
| P0-21 | Migrate canonical reconstruction docs from laptop | Claude Board Advisor | `docs/ops/CANONICAL_LAPTOP_STATE_2026-04-25.md` and `docs/ops/CANONICAL_STRATEGY_ARCHIVE_2026-04-25.md` byte-identical from Drive — DONE 2026-04-25 |
| P0-22 | Replace 10-phase pipeline outline with 15-phase canonical spec | CTO + Claude Board Advisor | `docs/ops/PIPELINE_PHASE_SPEC.md` written from laptop `doc/pipeline-v2-1-detailed.md`; `PIPELINE_AUTONOMY_MODEL.md` rewritten; decision log entry — DONE 2026-04-25 |
| P0-23 | Migrate process registry from laptop | Documentation-KM + CEO | DONE 2026-04-25: 13 files (12 process docs + README) byte-identical from `Company/Processes/`; SHA256 in `MIGRATION_LOG.md` Phase E. Content review by CEO + CTO still pending. |
| P0-24 | Migrate strategy specs and locked-basket evidence | Research + Documentation-KM | DONE 2026-04-25: 5 markdown specs in `strategy-seeds/specs/`; `strategy-seeds/v5_locked_basket_2026-04-18.md` written; lane-drift on 3 of 5 sleeves flagged for closure before P10. SHA256 in `MIGRATION_LOG.md` Phase F. |
| P0-25 | Migrate news-impact tooling from laptop | DevOps + Development | PENDING: `run_news_impact_tests.py` not located by recursive search of `G:\My Drive\QuantMechanica\`. Codex Task A queued (see `Phase0_Migration_Pack_2026-04-25` request). After Codex reply: copy script + helpers into repo `scripts/`, rewire to VPS paths, smoke-run with `D:\QM\data\news_calendar\`. |

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
