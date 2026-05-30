# QM5_1154 unger-dax-4h-high-breakout

## Scope

V5 implementation of the approved Strategy Card `QM5_1154_unger-dax-4h-high-breakout`.

## Framework Alignment

- No-Trade: V5 kill switch, news, Friday close, spread guard, Monday-Wednesday entry-days, and 09:00-12:00 entry window.
- Entry: long-only M15 buy-stop above the highest high of the previous 16 completed M15 bars plus `0.05 * ATR(14, M15)`.
- Management: fixed SL/TP only; no trailing, break-even, partial close, grid, or martingale.
- Close: broker stop loss, broker take profit, V5 Friday close, or strategy close after `MAX_HOLD_SESSIONS`.

## Defaults

- Symbol: `GDAXI.DWX`
- Timeframe: `M15`
- Risk: `RISK_FIXED=1000` for backtest, `RISK_PERCENT=0.25` for live setfile
- Stop loss: `2.0 * ATR(14, M15)`
- Take profit: `3.0 * ATR(14, M15)`
- Range filter: previous 16 completed M15 bars must be between `0.25` and `1.25` times `ATR(14, D1)`

## Notes

Session inputs are broker-time inputs with card defaults `09:00-12:00`. No backtests or pipeline phases are part of this build.
