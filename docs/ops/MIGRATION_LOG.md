# Migration Log

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
