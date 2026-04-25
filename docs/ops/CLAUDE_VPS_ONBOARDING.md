# Claude VPS Onboarding

This document exists to onboard the VPS Claude instance before it performs DST validation, Paperclip setup, or company bootstrap work.

## Access Surfaces
- Local VPS repo target: `C:\QM\repo`
- Local Paperclip target: `C:\QM\paperclip`
- Local MT5 factory terminals: `D:\QM\mt5\T1` ... `D:\QM\mt5\T5`
- Local live terminal: `C:\QM\mt5\T6_Live`
- Local reports: `D:\QM\reports`
- Local exports: `D:\QM\exports`
- Local news seed target: `D:\QM\data\news_calendar`
- Google Drive mount on Windows host: `G:\My Drive\` (canonical; older docs may say `G:\MyDrive` or `G:\Meine Ablage\` — those do not resolve on this VPS)
- QuantMechanica Drive root on host: `G:\My Drive\QuantMechanica\`
- VPS bootstrap pack on host: `G:\My Drive\QuantMechanica - VPS Portfolio Build\`
- Notion is available for review and cross-checks, but local files remain higher priority once exported.

## Old Project Context
The old QuantMechanica project still exists under Google Drive and may contain reusable assets:
- prior strategy archive material
- old automation scripts
- previous research outputs
- older Paperclip prompts or agent system notes
- historical CSV seed data
- dashboard or website artifacts

Claude may inspect the old project to identify reusable assets, but must not assume old project state is still valid for V5 without verification.

## News Calendar / CSV Data
Current known seed location in the bootstrap pack:
- `G:\My Drive\QuantMechanica - VPS Portfolio Build\Seeds\news_calendar\news_calendar_2015_2025.csv`
- `G:\My Drive\QuantMechanica - VPS Portfolio Build\Seeds\news_calendar\forex_factory_calendar_clean.csv`
- `G:\My Drive\QuantMechanica - VPS Portfolio Build\Seeds\news_calendar\MANIFEST.md`

Already installed on VPS at `D:\QM\data\news_calendar\` (verified 2026-04-24 by SHA256 + row count, see `MIGRATION_LOG.md`).

If additional or better news datasets exist in `G:\My Drive\QuantMechanica\`, Claude may inventory them and recommend migration, but it must document the source path and why the replacement is better.

## Notion Usage Rule
Notion can be used to:
- cross-check the latest planning state
- inspect the V5 operating model
- review Paperclip company design decisions
- verify phase status or open questions

Notion should not override verified filesystem state on the VPS.
If Notion and the filesystem conflict, Claude must report the inconsistency and treat filesystem state as operational truth.

## Pre-DST Priority
Before spending time on DST/custom-symbol validation, Claude must first understand:
1. the system architecture
2. the company operating model
3. the available source material in Google Drive
4. the known seed data for news/calendar handling
5. the intended role of Paperclip in the V5 company setup

## Expected Immediate Responsibilities
Claude should be prepared to help with:
- Paperclip setup and governance structure
- migration planning from old project assets into V5
- identifying where reusable prompts, checklists, and runbooks live
- locating the best news CSV source and documenting it
- T1-based DST/custom-symbol validation
- tester commission setup only after data/time assumptions are validated
- company/process bootstrap planning after Paperclip is online

## Required First Pass Inventory
Before major implementation work, Claude should inventory and summarize:
- `G:\My Drive\QuantMechanica\`
- local `docs\ops\`
- local `.private\VPS_SERVER_RECORD.md`
- local `D:\QM\data\news_calendar\` (already installed)

The result should be a concise migration/inventory summary that answers:
- what should be reused from the old project
- what should be ignored
- what must be rebuilt cleanly for V5
- where the best current news CSV source lives
- what the next operational steps are

## Ordered Work Queue
Recommended execution order for Claude on the VPS:
1. Read local control docs and summarize role / boundaries / architecture.
2. Inventory `G:\MyDrive\QuantMechanica` and identify reusable assets for V5.
3. Identify and document the canonical news CSV source.
4. Propose the Paperclip bootstrap sequence and required local exports.
5. Perform DST/custom-symbol validation in T1.
6. After DST is settled, help set up tester commission assumptions.
7. After Paperclip is online, help bootstrap the company operating model and routines.

## Hard Safety Reminder
- No changes to T6_Live without explicit approval.
- No credential exposure.
- No live deployment.
- No commission or DST assumptions without evidence.
- No reliance on screenshots where scripted checks are available.