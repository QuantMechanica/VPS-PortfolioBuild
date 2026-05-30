# QM5_1153 unger-nasdaq-priorclose-expansion

## Build Scope

- Implements APPROVED Strategy Card `QM5_1153_unger-nasdaq-priorclose-expansion`.
- V5 build-only artifact; no backtests or pipeline phases are part of this build.
- Universe: `NDX.DWX`, `WS30.DWX`, optional `SP500.DWX` backtest-only caveat from the card.
- Timeframe: M5.

## Strategy Mapping

- Entry: Tuesday-Friday, after US index session start, place a buy-stop at previous D1 close plus `strategy_expansion_mult * ATR(14,D1)` and a sell-stop at previous D1 close minus that expansion.
- OCO: first filled position cancels the opposite pending order.
- Cutoff: unfilled pending orders are cancelled at 15:30 New York time.
- Exit: intraday-only flatten before US session close.
- Stop/target: `SL = 1.5 * ATR(14,M15)`, `TP = 2.5 * ATR(14,M15)`.
- Filter: skip when previous D1 range exceeds `2.5 * ATR(14,D1)`.

## V5 Alignment

- Risk inputs follow the V5 fixed/backtest and percent/live contract.
- Magic is resolved from `qm_ea_id=1153` plus symbol slot.
- Standard V5 news, Friday close, kill-switch, and equity stream hooks are preserved.
- No ML, grid, martingale, or external data/API dependency.

## Symbol Slots

- Slot 0: `NDX.DWX`
- Slot 1: `WS30.DWX`
- Slot 2: `SP500.DWX`

## Notes

`SP500.DWX` remains the card's backtest-only/T6 caveat. Live promotion requires parallel validation on a broker-routable index symbol such as `NDX.DWX` or `WS30.DWX`.
