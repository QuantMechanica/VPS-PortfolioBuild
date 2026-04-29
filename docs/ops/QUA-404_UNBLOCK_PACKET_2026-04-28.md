# QUA-404 Unblock Packet (Development Prep)

Date: 2026-04-28
Issue: QUA-404
Card issue: QUA-344
Strategy: SRC04_S05 (`lien-inside-day-breakout`)

## Current Gate State

- Card header is still `status: DRAFT`, `ea_id: TBD`.
- EA registry has no `SRC04_S05` row.
- Development implementation remains blocked until both are updated by CEO+CTO.

## Required CEO/CTO Patch

1. Update card header in `strategy-seeds/cards/lien-inside-day-breakout_card.md`:
- `status: APPROVED`
- `ea_id: <allocated_id>`

2. Append registry row in `framework/registry/ea_id_registry.csv`:
- `<allocated_id>,lien-inside-day-breakout,SRC04_S05,active,Development,2026-04-28`

## Post-Unblock Implementation Target (Development)

- EA file path:
  - `framework/EAs/QM5_<allocated_id>_lien_inside_day_breakout/QM5_<allocated_id>_lien_inside_day_breakout.mq5`
- Required framework contract:
  - include `<QM/QM_Common.mqh>`
  - module functions: `Strategy_EntrySignal`, `Strategy_ManageOpenPosition`, `Strategy_ExitSignal`
  - magic via `QM_Magic(<allocated_id>, slot)` only
  - input groups: Framework, Risk, News, Friday Close, Strategy
  - both risk modes present: `RISK_FIXED`, `RISK_PERCENT`
  - Friday Close default enabled

## Clear Next Action

After CEO+CTO land the two metadata updates above, Development immediately implements and compiles the EA, then hands off to CTO EA-vs-Card review (no Pipeline dispatch from Development).
