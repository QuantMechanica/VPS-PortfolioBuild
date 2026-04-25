# Google Drive and Notion Source Guide

This guide exists because the VPS Claude instance cannot assume that all important QuantMechanica V5 knowledge already lives under `C:\QM\repo`.

At onboarding time, the knowledge base is distributed across:
- Google Drive on the VPS host (`G:\My Drive\` — canonical; NOT `G:\MyDrive` or `G:\Meine Ablage\`, those do not resolve on this VPS)
- the VPS bootstrap pack (`G:\My Drive\QuantMechanica - VPS Portfolio Build\`)
- the older project archive on the same Drive (`G:\My Drive\QuantMechanica\`)
- Notion
- the actual VPS operational filesystem (`C:\QM`, `D:\QM`)

## Critical Distinction
There are two different kinds of truth:

### 1. Operational truth
For the current live VPS state, the real filesystem state on the VPS wins.
Examples:
- where T1 actually lives
- which files exist under T1 MQL5
- which symbols are present now
- which reports exist now
- what is installed now

### 2. Knowledge-source truth
For company context, prompts, runbooks, historic assets, and migration candidates, Google Drive and Notion may still contain the richest information.

Claude must not confuse these two layers.

## Source Order

CLAUDE.md is the binding rule. Per CLAUDE.md, source-of-truth order is:

1. Actual filesystem state on this VPS (`C:\QM`, `D:\QM`)
2. Local private docs in `.private\`
3. Local exported ops docs in `docs\ops\`
4. Explicit user instructions
5. Notion references only when local docs are missing

Google Drive (`G:\My Drive\QuantMechanica\` and `G:\My Drive\QuantMechanica - VPS Portfolio Build\`) is a migration source for material that has not yet been mirrored into `C:\QM\repo`. It is read-only reference, not authoritative truth — once content is exported into the repo, the repo wins.

If local repo and Drive disagree, treat the repo as canonical and report the drift. If local repo and Notion disagree, treat the repo as canonical and report the drift.

## Known Google Drive Context
- `G:\My Drive\` is the Google Drive mount on the VPS host (with a space; the German-locale alias `Meine Ablage` does not exist here, and `MyDrive` without space does not resolve either).
- `G:\My Drive\QuantMechanica\` contains the complete old project (laptop archive: pipeline-v2-1-detailed.md, Company/, etc.).
- `G:\My Drive\QuantMechanica - VPS Portfolio Build\` contains the bootstrap pack used for the initial VPS migration.
- Treat both as migration sources, not as automatically valid operational truth for V5.

Claude should inventory the old project and explicitly classify findings into:
- reuse as-is
- reuse after validation
- archive only
- ignore / obsolete

## Things Claude Must Try To Locate In Google Drive
Claude should search `G:\My Drive\QuantMechanica\` for:
- old strategy archive material
- previous prompts and agent definitions
- company/process docs
- Paperclip-related notes
- dashboard / website artifacts
- old CSV datasets
- news calendar sources
- test / backtest outputs that may still be useful as reference

## News Data Guidance
Known current seed set in the bootstrap pack (already installed on `D:\QM\data\news_calendar\` per `MIGRATION_LOG.md`):
- `G:\My Drive\QuantMechanica - VPS Portfolio Build\Seeds\news_calendar\news_calendar_2015_2025.csv`
- `G:\My Drive\QuantMechanica - VPS Portfolio Build\Seeds\news_calendar\forex_factory_calendar_clean.csv`
- `G:\My Drive\QuantMechanica - VPS Portfolio Build\Seeds\news_calendar\MANIFEST.md`

Claude should treat this as the currently known seed set, then search Google Drive for:
- newer calendar files
- fuller historical coverage
- cleaner normalized versions
- pipeline docs that explain how those files were produced

Claude must then recommend one canonical news-data source for V5 and justify that choice.

## Notion Guidance
Notion is available and should be used as a planning and cross-check surface.

Known V5 root page:
- `https://www.notion.so/34947da58f4a81acac28fb82f3d7e7aa`

Important V5 areas Claude should try to confirm in Notion if access exists:
- Project Charter
- Infrastructure Setup
- Paperclip V2 Company Design
- Research Methodology V2
- V5 Pipeline Design
- Website Relaunch Plan
- Learnings Archive
- Episode Guide

If Notion access is unavailable in the VPS Claude environment, Claude must report that clearly and continue with Google Drive plus filesystem sources.

## Required Onboarding Deliverables
Before doing DST validation or Paperclip implementation, Claude should produce:
1. A source inventory summary
2. A migration map from Google Drive / Notion into local repo docs
3. A recommendation for the canonical news CSV source
4. A list of reusable old-project assets
5. A list of docs or prompts that must be exported into `C:\QM\repo`
6. The next 5 recommended setup steps before DST validation

## Explicit Sequencing Rule
Do NOT jump directly into DST/custom-symbol validation until the onboarding inventory is complete.

Correct sequence:
1. Read local bootstrap docs
2. Inventory Google Drive old project
3. Cross-check Notion if available
4. Identify reusable assets and canonical news source
5. Recommend migration actions
6. Then proceed to DST/custom-symbol validation in T1
7. After DST is resolved, move to Paperclip bootstrap

## Hard Reminders
- Do not modify T6_Live during onboarding.
- Do not expose credentials while reading Drive or Notion material.
- Do not assume that older docs are still valid for V5.
- If different sources conflict, report the conflict explicitly.