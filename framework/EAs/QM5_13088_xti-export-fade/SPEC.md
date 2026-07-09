# QM5_13088 XTI Export-Flow Failed-Probe Fade

Implements `strategy-seeds/cards/xti-export-fade_card.md`.

## Strategy

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Window: last `strategy_window_business_days` broker business days of the
  month.
- Entry: fade a failed Donchian channel probe when the signal bar rejects back
  inside the channel with ATR-sized range, rejection tail, and SMA stretch.
- Exit: ATR hard stop/target, SMA mean-reversion completion, opposite
  exit-channel failure, max hold, and V5 Friday close.

## Risk Contract

- Backtest setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- No live manifest, AutoTrading, `T_Live`, portfolio gate, or deploy manifest
  is touched by this build.

## Registry

- `ea_id`: 13088.
- `slug`: `xti-export-fade`.
- Magic slot 0: `XTIUSD.DWX`.

## Pipeline

- G0: APPROVED on 2026-07-09.
- Q01: compile/build-check target.
- Q02: enqueue after strict build pass.
