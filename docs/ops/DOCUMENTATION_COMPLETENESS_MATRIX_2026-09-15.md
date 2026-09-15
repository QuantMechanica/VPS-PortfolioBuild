# Company Documentation Completeness Matrix — 2026-09-15

**Authority:** OWNER follow-up directive §10 (COMPANY / RESEARCH / FACTORY / PORTFOLIOS / FTMO /
OPERATIONS) under OWNER-DEC-CBE-20260915. **Slice:** `i3_old_rules_sweep_docs`.

For every §10 item this matrix names the **vault page** and the **repo doc** that carry it,
verifies it against the real system TODAY (the code/config it describes was read), and marks
**EXISTS_MATCHES** / **EXISTS_DRIFTED** / **MISSING**. Drifted → corrected (dated annex, no
history deletion). Missing → vault page created (hand-written, sourced from the repo, repo paths
cited). Vault root: `G:/My Drive/QuantMechanica - Company Reference/`.

Legend: **[fix i3]** = fixed by this slice; **[b3]/[b4]/[H1]/[d1/d2]** = landed by that earlier
slice and verified here.

## COMPANY

| Item | Vault page | Repo doc | Status |
|---|---|---|---|
| Mission / North Star | `08 Current State/Current Objective.md` (CONTINUOUS BOOK EVOLUTION) [b4] | `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` | EXISTS_MATCHES |
| Economic model | `01 Identity/Business Model.md` (60d≥0.80 hard target → evidence annex **[fix i3]**) | `CLAUDE.md`; `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` | EXISTS_MATCHES (after fix) |
| DXZ purpose | `02 Org/Company Structure.md` [b4]; `Current Objective.md` | `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` | EXISTS_MATCHES |
| FTMO purpose | `08 Current State/FTMO Campaign.md` [b4] | `docs/ops/FTMO_CHALLENGE_READINESS.md` | EXISTS_MATCHES |
| Authority model | `02 Org/Stehende Vollmacht Claude 2026-08-20.md` (§64 annex [b4]); `07 Decision Rights/` | `CLAUDE.md` (ROT/GELB/GRÜN) | EXISTS_MATCHES |
| AI / provider roles | `02 Org/AI Agent Routing and Role Contracts.md` [b4]; `02 Org/Kimi Research Provider.md` [b4] | `CLAUDE.md` | EXISTS_MATCHES |

## RESEARCH

| Item | Vault page | Repo doc | Status |
|---|---|---|---|
| External research process | `04 Processes/Research Methodology.md` | `processes/qb_reputable_source_criteria.md` | EXISTS_MATCHES |
| Internal edge discovery | `04 Processes/Research Methodology.md` (Autonomous Edge Discovery annex [b4]) | `docs/research/AUTONOMOUS_EDGE_DISCOVERY.md` | EXISTS_MATCHES |
| Kimi research | `02 Org/Kimi Research Provider.md` [b4] | `docs/ops/KIMI_INTEGRATION_ARCHITECTURE.md`, `KIMI_EDGE_DISCOVERY_DESIGN.md`, `INTERNAL_RESEARCH_SOURCE_CONTRACT.md` | EXISTS_MATCHES |
| Fable autonomous hypothesis generation | `04 Processes/Research Methodology.md`; `START_HERE.md` [b4] | `docs/research/AUTONOMOUS_EDGE_DISCOVERY.md` | EXISTS_MATCHES |
| ML research policy | `01 Identity/Hard Rules.md` (HR14 annex); `START_HERE.md` Rule 8 [b4] | `CLAUDE.md` (HR14 offline-research-only) | EXISTS_MATCHES |
| Mechanization policy | `04 Processes/Research Methodology.md` | `processes/qb_reputable_source_criteria.md` (R2); `card_intake_prescreen.py` | EXISTS_MATCHES |
| Preregistration | `04 Processes/Research Methodology.md` (annex) | `docs/research/AUTONOMOUS_EDGE_DISCOVERY.md` | EXISTS_MATCHES |
| Failure mining | `04 Processes/Research Methodology.md`; `04 Processes/Lessons Learned Loop.md` [b4] | `docs/research/AUTONOMOUS_EDGE_DISCOVERY.md` | EXISTS_MATCHES |
| Lessons Learned | `04 Processes/Lessons Learned Loop.md` (§67 annex [b4]) | — | EXISTS_MATCHES |

## FACTORY

| Item | Vault page | Repo doc | Status |
|---|---|---|---|
| Q00–Q17 current contracts | `03 Pipeline/*` (Q00–Q17 pages, gate diff) | `tools/strategy_farm/config/gate_manifest.v4.json` | EXISTS_MATCHES |
| Pipeline operation | `03 Pipeline/Pipeline Operations Workflow.md` (book-trigger ASCII fixed **[fix i3]**) | `gate_manifest.v4.json`; `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` | EXISTS_MATCHES (after fix) |
| Evidence semantics | `03 Pipeline/Pipeline Overview.md` | `docs/ops/COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md` (+ CBE annex [b3]) | EXISTS_MATCHES |
| Deterministic truth model | `04 Processes/Determinism Over LLM Calls.md` [b4] | `docs/ops/COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md` | EXISTS_MATCHES |

## PORTFOLIOS

| Item | Vault page | Repo doc | Status |
|---|---|---|---|
| Continuous DXZ evolution | `04 Processes/Weekly Book Recomposition.md` [H1]; `08 Current State/Book Evolution/_index.md` **[fix i3]** | `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` | EXISTS_MATCHES |
| FTMO evolution | `08 Current State/FTMO Campaign.md` [b4]; `Weekly Book Recomposition.md` [H1] | `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md`; `FTMO_DEMO_VALIDATION_CONTRACT.md` | EXISTS_MATCHES |
| Weekly recomposition | `04 Processes/Weekly Book Recomposition.md` [H1] (broken index link fixed **[fix i3]**) | `tools/strategy_farm/book_evolution_runner.py`; `portfolio/recompose/` | EXISTS_MATCHES |
| Portfolio fitness methodology | `04 Processes/Weekly Book Recomposition.md` | `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` §57; `portfolio/recompose/recompose.py` | EXISTS_MATCHES |
| Current risk policy | `06 Infrastructure/Risk Conventions.md` [b4] | `config/concentration_tail_limits.v1.json`; `ftmo_probability_contract.v1.json` | EXISTS_MATCHES |
| Live change authority | `06 Infrastructure/Live Controls.md` **[created i3]**; `Stehende Vollmacht` §64 [b4] | `CLAUDE.md` (T_Live workflow) | EXISTS_MATCHES (created) |

## FTMO

| Item | Vault page | Repo doc | Status |
|---|---|---|---|
| Demo validation contract | `08 Current State/FTMO Campaign.md` [b4] | `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md` | EXISTS_MATCHES |
| Challenge readiness | `08 Current State/FTMO Campaign.md` [b4] | `docs/ops/FTMO_CHALLENGE_READINESS.md`; `tools/strategy_farm/ftmo/challenge_readiness.py` | EXISTS_MATCHES |
| One paid Challenge policy | `08 Current State/FTMO Campaign.md` [b4] | `CLAUDE.md` CBE bullet; `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md` | EXISTS_MATCHES |
| Current 100k / 2-Step preference | `08 Current State/FTMO Campaign.md` [b4] | `config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json` | EXISTS_MATCHES |
| Success probability priority | `08 Current State/FTMO Campaign.md` [b4]; `Business Model.md` **[fix i3]** | `tools/strategy_farm/ftmo/ftmo_fitness.py` (time-to-target SECONDARY) | EXISTS_MATCHES |
| Current product / rule snapshot | `08 Current State/FTMO Campaign.md` [b4] | `config/target_rulepacks/FTMO_2S_100K_{STANDARD,SWING}_V2.json`; `FTMO_DEMO_VALIDATION_CONTRACT.md` (rules snapshot 2026-09-15) | EXISTS_MATCHES |

## OPERATIONS

| Item | Vault page | Repo doc | Status |
|---|---|---|---|
| Mission Control | `06 Infrastructure/Mission Control.md` [b4] (Phase-D-landed annex **[fix i3]**) | `tools/strategy_farm/render_cockpit_v2.py`; `mission_control_v2_data.py` | EXISTS_MATCHES |
| Quota governance | `06 Infrastructure/AI Spend and Quota Governance.md` [b4] | `tools/strategy_farm/quota_governor.py`, `codex_budget_line.py`, `agy_governor.py` | EXISTS_MATCHES |
| Kimi quota | `06 Infrastructure/AI Spend and Quota Governance.md` (Kimi lane section [b4]); `02 Org/Kimi Research Provider.md` [b4] | `tools/strategy_farm/kimi_governor.py` | EXISTS_MATCHES |
| Backups | `06 Infrastructure/Backups.md` **[created i3]** | `scripts/backup_nightly.ps1`; `continuous_retention_runner.py`; `report_retention.py`; `tester_cache_purge.ps1` | **was MISSING → FIXED** |
| Live controls | `06 Infrastructure/Live Controls.md` **[created i3]** | `T_Live_ON.ps1`, `T_Live_Watchdog.ps1`, `FTMO_ON.ps1`, `Factory_{ON,OFF}.ps1`, `live_supervisor_watchdog.ps1` | **was MISSING → FIXED** |
| Current scheduled automation | `06 Infrastructure/Scheduled Automation.md` (generated) **[created i3]**; `Background Automation and Scheduled Tasks.md` (drift annex **[fix i3]**) | `tools/strategy_farm/render_scheduled_automation.py` (generator) | **was DRIFTED (78→86 tasks) → FIXED** |

## Summary

- **§10 items total: 33.** EXISTS_MATCHES: 30. Fixed to MATCHES by this slice: 3 (Backups
  created, Live Controls created, Scheduled Automation created + Background Automation
  de-drifted). No item remains MISSING or DRIFTED after this slice.
- All "expected missing" items the directive named (backups, live controls, current scheduled
  automation, Kimi quota, Mission Control, weekly recomposition) are now present and verified;
  the three genuinely missing/drifted ones were created/annexed here.
- Generated surfaces (`08 Current State/Heartbeat`, `10 Morning Briefing/*`,
  `09 Strategy Wiki/*`, the new `Scheduled Automation.md`) are refreshed by their generators,
  not hand-maintained.

See the drift report `docs/ops/evidence/2026-09-15_continuous_book_evolution/DOCUMENTATION_DRIFT_REPORT_2026-09-15.md`
for what drifted, what was fixed, what remains, and the vault-lint before/after.
