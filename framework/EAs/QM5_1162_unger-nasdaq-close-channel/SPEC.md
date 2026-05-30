# QM5_1162 unger-nasdaq-close-channel

## Build Scope

- Implements APPROVED Strategy Card `QM5_1162_unger-nasdaq-close-channel`.
- V5 build-only artifact; no backtests or pipeline phases are part of this build.
- Universe: `NDX.DWX`, `WS30.DWX`, optional `SP500.DWX` backtest-only caveat from the card.
- Timeframe: H1.

## Strategy Mapping

- Entry: on a newly closed H1 bar, buy when the close breaks above the prior rolling highest close and EMA(50,H1) is above EMA(200,H1); sell when the close breaks below the prior rolling lowest close and EMA(50,H1) is below EMA(200,H1).
- Channel: `strategy_close_lookback_bars`, default `24`, using completed H1 closes before the signal bar.
- Stop: `strategy_sl_atr_mult * ATR(14,H1)`, default `2.5`.
- Management: move SL to breakeven after `strategy_be_trigger_atr_mult * ATR(14,H1)` favorable excursion.
- Exit: close long when H1 close is below EMA(50), close short when H1 close is above EMA(50), or after `strategy_max_hold_bars`, default `120`.
- Friday forced close is delegated to the standard V5 Friday-close hook.

## V5 Alignment

- Risk inputs follow the V5 fixed/backtest and percent/live contract.
- Magic is resolved from `qm_ea_id=1162` plus symbol slot.
- Standard V5 news, Friday close, kill-switch, and equity stream hooks are preserved.
- No ML, grid, martingale, or external data/API dependency.

## Symbol Slots

- Slot 0: `NDX.DWX`
- Slot 1: `WS30.DWX`
- Slot 2: `SP500.DWX`

## Notes

`SP500.DWX` remains the card's backtest-only/T6 caveat. Live promotion requires parallel validation on a broker-routable index symbol such as `NDX.DWX` or `WS30.DWX`.
