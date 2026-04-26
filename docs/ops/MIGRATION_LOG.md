# Migration Log

## 2026-04-26 (late evening) — Project backlog + Paperclip reality check

Scope: stand up `PROJECT_BACKLOG.md` as the single backlog across all phases of V5; record the obvious-but-unwritten reality that Paperclip is not installed yet; codify the Specification Density Principle.

Operator: Claude Board Advisor under OWNER direction.

### Why

Across recent commits, workstream owners have piled up as `CTO + Development`, `CEO + Pipeline-Operator`, `Quality-Tech`. These reflect Wave 0+ Paperclip agents per `ORG_SELF_DESIGN_MODEL.md`. **Those agents do not exist yet**. Today the only actors on the VPS are OWNER and this Claude instance. The backlog read as if work was queued when in fact most of it is blocked on Phase 1 (Paperclip Bootstrap).

OWNER also clarified: Paperclip should work things out itself wherever it can. This file should pre-specify the outer boundary, not the interior.

### Files

| File | Purpose |
|---|---|
| `PROJECT_BACKLOG.md` (new, repo root) | Single backlog across Phase 0 → Phase Final. Per-row "today's actual owner" so OWNER can answer "what can I do right now?" without grepping five docs. |
| `decisions/2026-04-26_paperclip_reality_and_phase_map.md` | ADR: Paperclip reality + 7-phase project map + Specification Density Principle |
| `CLAUDE.md` | Pointer to `PROJECT_BACKLOG.md` added; "Paperclip Reality" + "Specification Density Principle" sections added; Required Local Docs list expanded with V5 specs and brand guide |
| `docs/ops/PHASE0_EXECUTION_BOARD.md` | Owner-field-reading-rule banner added at top: named owners are *planned long-term* owners (Paperclip agents); see `PROJECT_BACKLOG.md` for *today's actual* owner |

### Phase map adopted

```
Phase 0 — VPS Foundation + Specs                  ← we are here
Phase 1 — Paperclip Bootstrap (install + Wave 0)
Phase 2 — V5 Framework Implementation
Phase 3 — First V5 EA Through Pipeline
Phase 4 — V5 Portfolio Build
Phase 5 — Live Deployment on T6
Phase 6 — Public Dashboard Live (parallel-eligible from Phase 1)
Phase Final — Founder-Comms / Chief of Staff (frozen)
```

### Specification Density Principle

Hard-bounded: hard rules, gate criteria, brand tokens, magic-number formula, set-file format, news-data location, T6 isolation, broker-time convention.

Skeleton + acceptance gate (interior left to Paperclip): phase workstreams, individual EA design, sub-gate recalibration, dashboard widget content, episode artifacts.

When Paperclip Wave 0 comes online, the answer to "what should I do here?" is usually "what do you propose, given the constraints?" — not "here is the answer pre-baked".

### Out of scope (NOT done)

- Paperclip install — that is Phase 1's first task
- 13 prompt review and Wave 0 prompt authoring — Phase 1
- DST validation on T1 — separate physical-VPS task, see `PROJECT_BACKLOG.md` § Phase 0 not-started-actionable-today
- EP01 publishing artifacts — Phase 0 unblocked-actionable, OWNER's call

## 2026-04-26 (evening) — V5 brand application + framework trade-mgmt + chart UI

Scope: pull QuantMechanica brand system from Drive into repo, write V5-application brand guide, extend framework with standardized trade-management modules and a per-EA in-chart dashboard widget.

Operator: Claude Board Advisor under OWNER direction.

### Brand-system migration

Source on Drive (canonical, read-only for V5):

- `G:\My Drive\QuantMechanica\ClaudeDesign_Upload\01_Brand_System\Brand_Guidelines.docx`
- `G:\My Drive\QuantMechanica\ClaudeDesign_Upload\01_Brand_System\QuantMechanica_Brand_Book.html`
- `G:\My Drive\QuantMechanica\ClaudeDesign_Upload\03_Website\style.css` (full design system)
- `G:\My Drive\QuantMechanica\ClaudeDesign_Upload\04_Voice_Content\Brand_Voice_Samples.md`
- `G:\My Drive\QuantMechanica\Company\Research\DASHBOARD_DESIGN_BRIEF.md`

Brand stays canonical on Drive. Repo gets working artifacts only.

| Repo file | Purpose |
|---|---|
| `branding/QM_BRANDING_GUIDE.md` | V5-application brand guide — hard rules, MT5-applicable colour mapping, voice-applied-to-V5-artifacts, where-the-brand-lives matrix |
| `branding/brand_tokens.json` | Machine-readable colour / typography / spacing tokens; used by MQL5 (via `sync_brand_tokens.ps1` → `QM_Branding.mqh`) and CSS-consuming scripts |

### Framework extension

`framework/V5_FRAMEWORK_DESIGN.md` extended with 7 new MQL5 include modules:

- `QM_Branding.mqh` — colour + font constants generated from brand_tokens.json
- `QM_OrderTypes.mqh` — typed wrappers for MT5's 5 order types
- `QM_Entry.mqh` — single entry point with kill-switch / news / risk / dup-check enforcement
- `QM_Exit.mqh` — single exit point with named-reason enum
- `QM_StopRules.mqh` — ATR / structure / volatility / fixed-pip stop strategies
- `QM_TradeManagement.mqh` — position lifecycle (open / modify / partial / pyramiding opt-in)
- `QM_ChartUI.mqh` — per-EA in-chart dashboard widget

Implementation order grew from 15 to 25 steps. New steps include `sync_brand_tokens.ps1` and `brand_report.ps1` for the brand-toolchain side.

### Per-EA chart UI design

Specced in `framework/V5_FRAMEWORK_DESIGN.md` § QM_ChartUI:

- 720×200 px panel, configurable anchor corner, collapses below 720px chart width
- Header: wordmark + EA name + UTC timestamp
- 6 stat tiles: Risk %, Open P/L, Today P/L, Magic, News Mode, Kill Switch
- Status row: AutoTrading + NewsFilter + Calendar
- Log footer: last major event one-liner
- ChartObject API only (no custom indicator buffer); `OnTimer` 1s refresh
- Tester mode: minimal rendering, no tick overhead

### Decision log

| File | SHA256 |
|---|---|
| `decisions/2026-04-26_v5_branding_and_chart_ui.md` | computed at next build_check |

### Phase 0 board updates

- P0-28 added: brand-system migration + V5 brand guide — DONE
- P0-29 added: framework trade-mgmt + chart UI extension — DESIGN DONE, implementation pending Codex (continues from P0-26)

### Out of scope (NOT done)

- Codex framework implementation — Codex's task per implementation order
- Logo SVG copy into `branding/assets/` — pending OWNER confirm of brand guide § 10 default
- Backtest report styler (`brand_report.ps1`) implementation — pending Codex
- Public web dashboard work — separate workstream (P0-16 / WEBSITE_DASHBOARD_PAPERCLIP_STYLE.md), not affected by this commit

## 2026-04-26 (afternoon) — Codex second pass + V5 sub-gate reconstruction + framework defaults

Scope: receive Codex second-pass on the missing V2.1 sub-gate receipts, reconstruct V5 sub-gate spec from surviving evidence, lock in the 6 framework-design defaults so Codex can begin implementation.

Operator: Claude Board Advisor under OWNER direction.

### Codex second-pass result

- `CODEX_PIPELINE_V2.1_SPEC.md` — confirmed MISSING anywhere on `G:\`
- `CODEX_PIPELINE_V2.1_IMPACT.md` — confirmed MISSING
- `CODEX_PIPELINE_V2.1_DIFF.md` — confirmed MISSING
- Search scope: full recursive filename + full-text across `G:\`, including backups
- Git provenance unusable on laptop (`fatal: bad object refs/heads/main`)
- Defensible conclusion: not recoverable from current Drive / backup state
- New file in pack: `pipeline_spec_second_pass_provenance.md`

### V5 sub-gate reconstruction

OWNER approved Codex's suggestion to reconstruct from surviving evidence into a V5-local receipt set. Single file chosen over three (cleaner single-source-of-truth):

| File | Purpose |
|---|---|
| `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` | per-phase sub-gate parameters for P3.5, P5, P5b, P5c, P6, P7, P10 with provenance, V5 vs V2.1 diff section, recalibration triggers, open items for Quality-Tech |
| `decisions/2026-04-26_v5_sub_gate_reconstruction.md` | ADR documenting the reconstruction approach, source-by-source mapping, alternatives rejected |

Provenance built from surviving evidence:

- laptop `doc/pipeline-v2-1-detailed.md` (one-line spec table)
- laptop `Company/scripts/README_V2.1_RUNNERS.md` (concrete CLI + defaults)
- laptop `Company/Results/V5_PORTFOLIO_RISK_REVIEW_20260418.md`
- laptop `Company/Results/V5_COMPOSITION_LOCK_20260418.md`
- laptop `Company/Results/V5_P6_MULTISEED_WAIVERS_20260418.md`
- laptop `Company/Results/SM_221_P5B_YELLOW_DECISION_20260418.md`
- laptop `Company/Results/SM_221_P8_NEWS_IMPACT_20260418.md`
- laptop `Company/Results/P5_CALIBRATED_NOISE_RECAL_SM_124_UK100_20260418_R002.md`

V5 additions over V4 evidence (each documented in the spec): P5 trade-count guard, P5b one-YELLOW-per-basket cap, P6 4-state verdict, P7 consolidated runner, P10 numeric KS thresholds + lookback + minimum sample size + shadow magic offset, broad-asset-class taxonomy, crisis-slice list.

### Framework defaults locked

`framework/V5_FRAMEWORK_DESIGN.md` § Open Questions replaced with § Confirmed Defaults:

1. Logger output → per-EA file (rejected: shared rotating)
2. `PORTFOLIO_WEIGHT > 1.0` → hard fail (rejected: clamp + warn)
3. News CSV refresh → in-place + hash log at OnInit (rejected: weekly cron + manifest re-deploy)
4. EA layout → one folder per EA (rejected: flat with shared setfiles/)
5. `OnTester` default → Profit Factor, switchable per-EA (rejected as default: Sharpe, V5-composite)
6. Compile tool → `metaeditor.exe` (rejected: `terminal64.exe /compile`)

Codex implementation can now begin without further OWNER round-trip on these six.

### Phase 0 board updates

- P0-26 status updated to "DESIGN DONE + DEFAULTS CONFIRMED, implementation pending Codex"
- P0-27 added: V5 sub-gate spec reconstruction — DONE

### PIPELINE_PHASE_SPEC.md updates

Open Questions section updated to reference the new sub-gate spec; sub-gate-detail TBD removed (now satisfied by `PIPELINE_V5_SUB_GATE_SPEC.md`).

### Out of scope (NOT done)

- Codex framework implementation — Codex's next task
- Quality-Tech first calibration pass on the provisional defaults — blocked on first V5 EA producing distributions
- Re-author of the three V4 receipts as literal V4 files — explicitly rejected per ADR
- Notion mirror update for the new sub-gate spec — Documentation-KM follow-up

## 2026-04-26 — Codex laptop pack delivery + V5 framework design

Scope: receive Codex laptop investigation pack, fold findings into VPS docs, write V5 EA framework design.

Operator: Claude Board Advisor under OWNER direction.

### Codex pack delivered

Pack location (laptop side):

```
G:\Meine Ablage\QuantMechanica - VPS Portfolio Build\Phase0_Migration_Pack_2026-04-25\
```

Note: Codex used the German-locale alias `G:\Meine Ablage\` which the laptop OS exposes as the same Drive mount that the VPS reaches via `G:\My Drive\`. Both paths resolve to the same Drive root from their respective machines. No file copy needed onto the VPS — the docs read are reports about laptop state, not artifacts to import.

Files in pack:

- `pipeline_spec/pipeline-v2-1-detailed.md` — same file already migrated 2026-04-25, included for parity
- `pipeline_spec/MANIFEST.md` — 4 rows; `CODEX_PIPELINE_V2.1_SPEC.md`, `_IMPACT.md`, `_DIFF.md` listed as **MISSING**
- `news_impact_tooling_location_report.md` — verdict: **RUNNER NOT PRESENT**
- `v4_framework_inventory.md` — 5 sections; top-3 keep / top-3 reconsider lists

### Findings folded into VPS docs

| Finding | Affected doc | Action |
|---|---|---|
| `CODEX_PIPELINE_V2.1_SPEC/IMPACT/DIFF.md` MISSING | `docs/ops/PIPELINE_PHASE_SPEC.md` | Evidence Index restructured into V5 / V4-legacy / confirmed-missing sections; Open Questions block now states sub-gate detail must be authored fresh by V5 |
| `run_news_impact_tests.py` NOT PRESENT (P8 hand-orchestrated) | `decisions/2026-04-25_news_compliance_variants_TBD.md` | Sub-decision 3 marked RESOLVED — V5 builds tooling from scratch, no legacy constraint |
| `Company/Include/` absent (V4 had no shared library) | `framework/V5_FRAMEWORK_DESIGN.md` | Single shared framework is now non-optional; explicitly addresses V4's root-cause failure mode |
| Keep: `SM_ID * 10000 + slot` magic, `RISK_FIXED + RISK_PERCENT` dual mode, evidence-first markdown receipts | `framework/V5_FRAMEWORK_DESIGN.md` | Both inherited from V4 verbatim; documented as "kept" with rationale |
| Reconsider: doc/code drift, no checked-in `.set` files, no compile harness | `framework/V5_FRAMEWORK_DESIGN.md` | Schema validation, registry-baked-into-binary, build_check pre-commit gate all designed in |

### V5 EA framework design

| File | SHA256 |
|---|---|
| `framework/V5_FRAMEWORK_DESIGN.md` | computed at next build_check |
| `framework/README.md` | computed at next build_check |
| `decisions/2026-04-26_v5_framework_design.md` | computed at next build_check |

### Phase 0 board updates

- P0-25 closed (RUNNER NOT PRESENT — V5 builds new)
- P0-26 design phase done; implementation pending OWNER + CTO sign-off on § Open Questions

### Out of scope (NOT done in this session)

- Codex framework implementation — pending design sign-off
- Authoring of V5 sub-gate detail (P5/P5b/P6/P7/P10 specifics) — Quality-Tech task once first V5 EA distributions exist
- Notion mirror update for V5_RESTART_SCOPE_BOUNDARY.md or V5_FRAMEWORK_DESIGN.md
- Tick Data Manager DST validation on T1

## 2026-04-25 — Phase 0 Reconstruction migration

Scope: pull canonical pipeline spec, process registry, strategy specs, and locked-basket evidence from the laptop snapshot on `G:\My Drive\QuantMechanica\` into `C:\QM\repo\` so the V5 build matches actual laptop state. Address Notion / Codex 10-phase pipeline drift documented in `decisions/2026-04-25_pipeline_15_phase_override.md`.

Operator: Claude Board Advisor under OWNER direction (single session, 2026-04-25).

### Source

- `G:\My Drive\QuantMechanica\` (old laptop project, fully synced as of 2026-04-25)
- `G:\My Drive\QuantMechanica\Company\V5_Public_Build\canonical_reconstruction\` (Codex laptop reconstruction, 2026-04-25)
- Notion `Canonical Laptop State Reconstruction — 2026-04-25` (id `34d47da5-8f4a-812b-8d21-de4f57e63c5c`) used for cross-check; Drive contents take precedence per CLAUDE.md source order.

### Phase A — Canonical reconstruction docs (byte-identical from Drive)

| Destination | SHA256 |
|---|---|
| `docs/ops/CANONICAL_LAPTOP_STATE_2026-04-25.md` | `8217eaff35029a31e496b045a604c5661494c2beabd7b3028c71ea39ba9360a8` |
| `docs/ops/CANONICAL_STRATEGY_ARCHIVE_2026-04-25.md` | `a1607aee05a37e60411ae20018242e0f2d9f5eac64091218af36ab33d2b17921` |

### Phase B — Pipeline spec rewrite

Replaced the stale 10-phase outline with the canonical 15-phase V2.1 model sourced from laptop `doc/pipeline-v2-1-detailed.md`. New file separates phase content from governance.

| File | Action | SHA256 |
|---|---|---|
| `docs/ops/PIPELINE_PHASE_SPEC.md` | new | `0cb6498af96fcf9cf93f5b0c302afa43c5c78fa7360487da0265d7926c1caa5a` |
| `docs/ops/PIPELINE_AUTONOMY_MODEL.md` | rewrite | `fcda00cbec0200c3d14edbac3995f13b6842df84a26ad774f5f24743c434f4cd` |

### Phase C — Decision log

| File | SHA256 |
|---|---|
| `decisions/2026-04-25_pipeline_15_phase_override.md` | `467b5959fb4a0e66210308b2d668d87d8907e987eefbd9cdfaaf41b6c4de1a07` |
| `decisions/2026-04-25_news_compliance_variants_TBD.md` | `e272ea391d6322a37f4a7c195dc0931d268e181e2ef2cca509dd6a0a7d400efd` |

### Phase D — V5 locked basket strategy seed

Source: `Company/Results/V5_COMPOSITION_LOCK_20260418.md` + `Company/Results/V5_PORTFOLIO_RISK_REVIEW_20260418.md`.

| File | SHA256 |
|---|---|
| `strategy-seeds/v5_locked_basket_2026-04-18.md` | `521a496bdac914d044061af268d5fa0f20baca855c209a92538eb589f430e383` |

### Phase E — Process registry migration

13 files copied byte-identical from `Company/Processes/` into `processes/`. The previous `processes/README.md` stub was overwritten by the laptop README index.

| Destination | SHA256 |
|---|---|
| `processes/README.md` | `85f5981ea327cc9b591670a8d6dfdc65580ec8fc2486dcbe76e6d228d262b933` |
| `processes/01-ea-lifecycle.md` | `ba71f2af1f8e2b9ecde598ec3cd9a4e0764220c1b07304bc0a07444a0df40918` |
| `processes/02-zt-recovery.md` | `0d880f2df0d754596bf12063592610c7dc9acae60aba17ec6c71ea984f0a5c63` |
| `processes/03-v-portfolio-deploy.md` | `50a021a59ba2b15f5dc872237aaae7763b6d9e1e69eaafd3bc6fa51c190784aa` |
| `processes/04-incident-response.md` | `e476b395c166bf30a2c7c582044324152eadfdc5563d16ccfcec62fb2c0f0377` |
| `processes/05-dashboard-refresh.md` | `6816f5345d3829105c3d9b13e0d161f9e4c4047ac1422062e5824cf628e91315` |
| `processes/06-issue-triage.md` | `533865e05249d91662bcccb00cac66fc33cee80b05908eb80c06728cb3d2b22e` |
| `processes/07-ceo-cto-dialectic.md` | `b7f0e3ac87e283c967e7bdfb6091a1692965f40f955cbb4186f53c6e34496706` |
| `processes/08-daily-operating-rhythm.md` | `32f635b800912b109a98520bdc0904e4a9aa1bf4fad1534ec6639a078e7dd541` |
| `processes/09-disaster-recovery.md` | `e7dc67798735ea29195be8901868cdbfc3e47f35a58a22cba77b1f99ac5b0132` |
| `processes/10-agent-rescope.md` | `8a2718306970269b76c4640e0f54c61369014d8e6544565f269af10b75ab8eb8` |
| `processes/11-disk-and-sync.md` | `60430c9249c2d8e440995250943e694da79e97762c70ca3cbb6d0af7342da55c` |
| `processes/12-board-escalation.md` | `053b99875cca55d1c09a6d0995eb5b64a77816e2faa5d5138b7a0be4bb898b5d` |

### Phase F — Strategy spec migration

5 files copied byte-identical from `Company/Research/strategies/` into `strategy-seeds/specs/`. New subfolder created.

| Destination | SHA256 |
|---|---|
| `strategy-seeds/specs/ath-breakout-atr-trail.md` | `511c3b9d0057a7e475c4dc85a59956f4a1b5434095c994144274f04375c5864b` |
| `strategy-seeds/specs/good-carry-bad-carry.md` | `ba1a2b43c00f4acdaab4fdd637d9c972f456d8549026b6ba76cb320332a81e78` |
| `strategy-seeds/specs/modernising-turtle-trading.md` | `6a7beafef1374744ae7fa932bd8914f46d6ffc57ce98871edd03ca9b8e374cf6` |
| `strategy-seeds/specs/seasonality-trend-mr-bitcoin.md` | `c8768538d79c22d95c4913bcf60c36c1153e6e6df70c920d9004f1ca07692f67` |
| `strategy-seeds/specs/two-regime-trend-following.md` | `3c888eb37e967b1a680061a9ea26b37d0c981bdafa00e7457b801dd28d233632` |

### Phase G — Onboarding doc consolidation

Drive-path inconsistencies removed from `docs/ops/CLAUDE_VPS_ONBOARDING.md` and `docs/ops/GOOGLE_DRIVE_AND_NOTION_SOURCE_GUIDE.md`. Canonical mount is now `G:\My Drive\` everywhere; Notion source order corrected to match CLAUDE.md (filesystem first, Notion last).

### Phase H — Phase 0 Execution Board update

Added rows P0-21..P0-25 to `docs/ops/PHASE0_EXECUTION_BOARD.md`. P0-21 and P0-22 marked DONE in this same session; P0-23 and P0-24 partial (process docs and strategy specs migrated; supporting board sign-off pending); P0-25 remains pending (news-impact tooling not yet migrated — `run_news_impact_tests.py` not located in expected `Company/scripts/` path on Drive; needs Codex follow-up to confirm laptop location).

### Out of scope (explicitly NOT done in this session)

- News-impact tooling migration (`run_news_impact_tests.py` and helpers) — see P0-25.
- 402 historical website strategy HTML pages migration — captured as IDs only via `CANONICAL_STRATEGY_ARCHIVE_2026-04-25.md`.
- Notion `V5 Pipeline Design` page update to reflect 15-phase model — Documentation-KM follow-up.
- Tick Data Manager DST validation on T1 — separate prerequisite for any backtest.
- Process content review — laptop process docs imported as-is; CEO + CTO must review and tag any items that need V5 boundary updates.
- Git commit — repo working tree left dirty; OWNER will trigger commit.

### Memory updates

- Updated `MEMORY.md` to reference `PIPELINE_PHASE_SPEC.md` as the canonical V5 pipeline source.

## 2026-04-24 — V5 repo bootstrap migration

Scope: migrate required onboarding docs, prompts, and seed-data provenance from Google Drive into the local repo so future Claude sessions can operate from `C:\QM\repo` without Drive dependency. Install the news-calendar seed on `D:\` and verify integrity.

Operator: Claude (Board Advisor session) under human direction.

### Source of truth

- Drive mount on this VPS: `G:\My Drive\` (NOT `G:\Meine Ablage\...` — that appears in older docs but does not resolve here; see memory `reference_qm_drive_mount.md`).
- Bootstrap pack: `G:\My Drive\QuantMechanica - VPS Portfolio Build\`.

### Phase A — Scaffolding

Thirteen empty top-level folders created under `C:\QM\repo\` with single-line README stubs (purpose only; no policy, no owner assignments):

```
processes\   skills\              checklists\        decisions\
lessons-learned\  risks\           deploy-manifests\  strategy-seeds\
public-data\ scripts\             expenses\          episodes\
seed_assets\news_calendar\
```

### Phase B — Docs and prompts migrated into repo

| Destination | SHA256 | Bytes |
|---|---|---:|
| `docs/ops/CLAUDE_VPS_ONBOARDING.md` | `4C7E3C58EEFFB4D6BD9BA3B75BC2E80ACDFAC70DF3C0387EEC745EE643096A87` | 4,241 |
| `docs/ops/GOOGLE_DRIVE_AND_NOTION_SOURCE_GUIDE.md` | `664DFDCE74CCC96AF40D71E142A1CC134B9866016E18341767CACEEDE416A059` | 4,803 |
| `prompts/claude_vps_deep_onboarding_prompt.txt` | `FF2C64006790FB0B3E002B526507663A23C58D54FC3A4A2247C8B6F64277A7C7` | 3,299 |
| `prompts/claude_paperclip_bootstrap_prompt.txt` | `E7A09046E55693BFB62261926E2DE19C30FF45D72486DC4B04E7C639E45F2ACD` | 1,426 |
| `prompts/claude_symbol_dst_validation_prompt.txt` | `EE66D9B84B972DA7FC52CF96EDA143CBD78FB6ED01CA3BA20FD1FC9B009F3A72` | 3,306 |
| `seed_assets/news_calendar/MANIFEST.md` | `C52A812DFB83F8E54B61B0766F269846768E4F23C0722A96EE220DE6991F8A31` | 1,949 |

All six files verified byte-for-byte against their Drive originals (source and destination SHA256 computed post-copy and compared).

### Phase B5 — CLAUDE.md updated

Added two lines to the Required Local Docs list (inserted before `PHASE0_EXECUTION_BOARD.md` to match the reading order in `claude_vps_deep_onboarding_prompt.txt`):

- `docs/ops/CLAUDE_VPS_ONBOARDING.md`
- `docs/ops/GOOGLE_DRIVE_AND_NOTION_SOURCE_GUIDE.md`

### Phase C — Evidence tree created on D:\

On `D:\` (operational, not in repo):

```
D:\QM\reports\setup\
  README.md
  tick-data-timezone\README.md
  symbols\README.md
  news-calendar\README.md
```

Pre-existing artefacts observed in `tick-data-timezone\` (from a prior session): `EURUSD_GMT+2_EU-DST.csv`, `EURUSD_GMT+2_EU-DST_M1.csv`. Left untouched; relevance to be assessed during DST validation.

### Phase D — News seed installed on D:\

Copied from drive to `D:\QM\data\news_calendar\`:

| File | Expected (MANIFEST) | Actual | Verdict |
|---|---|---|---|
| `news_calendar_2015_2025.csv` | SHA `1DC345FC…A307E`, 4,430,868 B, 47,992 rows | all three match | PASS |
| `forex_factory_calendar_clean.csv` | SHA `C2B196EE…D66A69`, 4,300,927 B, 48,001 rows | all three match | PASS |

Evidence file: `D:\QM\reports\setup\news-calendar\news_calendar_install.md`.

### Phase E1 — .gitignore hardened

Added patterns: `desktop.ini`, `*.env`, `*.key`, `*.pem`. Existing patterns retained: `.private/`, `*.log`, `Thumbs.db`, `Desktop.ini`.

### Memory updates

- Added `reference_qm_drive_mount.md` — canonical Drive mount path and sync sanity check.

### Out of scope (explicitly NOT done)

- No DST validation on T1.
- No Paperclip install — `C:\QM\paperclip\` remains empty by design (Paperclip installer will create it).
- No T6_Live access.
- No strategy-seed bucket decisions — `strategy-seeds/` remains purpose-stub only.
- No process/skill/checklist/decision/lesson/risk content authored.
- No old-project assets from `G:\My Drive\QuantMechanica\` migrated — they remain on drive as reference material to be mined selectively when the relevant agent is assigned.

### Next unblocked step

Run `prompts/claude_symbol_dst_validation_prompt.txt` against T1 for DST / custom-symbol validation, per the order in `docs/ops/CLAUDE_VPS_ONBOARDING.md`.
