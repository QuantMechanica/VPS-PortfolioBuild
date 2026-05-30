# QM5_1165 unger-gold-linreg-trend

## Scope

Build-only V5 EA for approved Strategy Card `QM5_1165_unger-gold-linreg-trend`.

## Framework Alignment

- No-Trade: framework kill-switch, news, Friday close, symbol/timeframe, spread, session and parameter guards.
- Entry: H1 close crosses above/below linear-regression residual channel.
- Management: fixed ATR-derived SL/TP only; no trailing, scale-out or pyramiding.
- Exit: H1 close crosses back through regression line, SL/TP, or `strategy_max_hold_bars`.

## Parameters

- Symbol: `XAUUSD.DWX`
- Timeframe: H1
- `strategy_lr_period`: 40 default
- `strategy_lr_dev`: 1.0 default
- `strategy_atr_period`: 14 default
- `strategy_sl_atr_mult`: 2.0 default
- `strategy_tp_atr_mult`: 4.0 default
- `strategy_max_hold_bars`: 72 default

## Notes

- Build does not run backtests or pipeline phases.
- FOMC/CPI/NFP avoidance is mapped to V5 high-impact `SKIP_DAY` plus DXZ compliance inputs.
