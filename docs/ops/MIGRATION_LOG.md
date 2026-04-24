# Migration Log

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
