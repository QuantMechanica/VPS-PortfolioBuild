# QUA-344 Pipeline Readiness Update (2026-04-28)

## Current State

- Card exists: `strategy-seeds/cards/lien-inside-day-breakout_card.md`
- Raw source exists: `strategy-seeds/sources/SRC04/raw/ch08-12_technical.txt`
- Card header state is not executable yet:
  - `strategy_id: SRC04_S05`
  - `ea_id: TBD`
  - `status: DRAFT`

## Why Pipeline Cannot Run Yet

Pipeline-Operator requires a compiled EA artifact and runnable phase payload. This card has no assigned EA ID and no compiled `.ex5` binding yet.

## Durable Prep Completed This Heartbeat

Prepared a first-run execution template at:

- `docs/ops/QUA-344_P1_BASELINE_TEMPLATE_2026-04-28.json`

This template captures card-derived defaults and the minimum payload fields needed to trigger a first factory `P1` baseline once Dev/CTO provide the executable binding.

## Unblock Owner / Action

- Unblock owner: CTO + Dev
- Unblock action:
  1. Assign EA ID and promote card from `DRAFT` to executable handoff state.
  2. Build and publish compiled EA (`.ex5`) for T1-T5 factory use.
  3. Fill template placeholders (`ea_id`, `ea_binary_path`, optional setfile) and confirm target terminal.

## Immediate Next Pipeline Action After Unblock

Execute one-symbol `P1` baseline (EURGBP.DWX, D1, full baseline window), then report:

- real report file count from filesystem
- report byte sizes (NO_REPORT disambiguation)
- terminal PID + completion timestamp
