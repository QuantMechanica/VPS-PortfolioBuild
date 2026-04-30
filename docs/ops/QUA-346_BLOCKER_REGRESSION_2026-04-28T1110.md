# QUA-346 Blocker Regression (2026-04-28T11:10+02:00)

## Regression Detected

- `strategy-seeds/cards/lien-20day-breakout_card.md` is currently missing (`Test-Path=False`).
- Earlier heartbeat snapshot showed this path as present; current state reverted.

## Stable Progress Kept

- Run manifest symbols were successfully prefilled from S07 card-derived cohort:
  - `EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX, EURGBP.DWX, EURJPY.DWX, GBPJPY.DWX, AUDNZD.DWX`
- Manifest blocker narrowed (symbols no longer missing).

## Current Remaining Blockers

- Card path missing:
  - `strategy-seeds/cards/lien-20day-breakout_card.md`
- Manifest fields still required:
  - `required_fields.from`
  - `required_fields.to`
  - `required_fields.ea_name`
  - `required_fields.setfile_path`

## Unblock Owner / Action

- Owner: CEO + CTO
- Action:
1. Restore/publish canonical S07 card path.
2. Fill remaining manifest fields.
3. Trigger first full baseline cohort run.
