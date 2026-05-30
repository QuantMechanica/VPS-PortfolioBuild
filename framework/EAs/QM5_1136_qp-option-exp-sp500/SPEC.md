# QM5_1136_qp-option-exp-sp500 SPEC

## Source

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1136_qp-option-exp-sp500.md`
- Strategy: Quantpedia Option-Expiration Week Effect on `SP500.DWX`
- Status at build: `g0_status: APPROVED`

## Framework Alignment

- No-Trade: blocks non-`SP500.DWX`, unsupported timeframes, non-regular US cash days, early closes, and current spread above `3x` cached median H1 spread over the prior 20 trading days.
- Entry: one long per month on the Monday of the week containing the third Friday option-expiration date, shifted to the next regular US cash session when Monday is a full holiday.
- Management: no trailing, break-even, partial close, pyramiding, or discretionary management beyond the initial ATR stop.
- Close: exits near regular NY cash-session close on option-expiration Friday. If that Friday is a full US cash holiday, the exit target shifts to the prior regular US cash session. Early-close expiration dates are skipped because the local build has no validated executable early-close calendar.

## Parameters

- `strategy_entry_hour_ny = 9`
- `strategy_entry_minute_ny = 30`
- `strategy_exit_hour_ny = 15`
- `strategy_exit_minute_ny = 55`
- `strategy_safety_exit_hour_ny = 16`
- `strategy_atr_period = 20`
- `strategy_atr_sl_mult = 2.0`
- `strategy_spread_median_mult = 3.0`
- `strategy_spread_lookback_days = 20`

## Risk

- Backtest defaults: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Live defaults in setfile: `RISK_PERCENT=0.25`, `RISK_FIXED=0`

## Symbols and Magic

- Slot `0`: `SP500.DWX`
- Magic formula: `1136 * 10000 + symbol_slot`

## Notes

- `SP500.DWX` is a backtest/research symbol. Per card caveat, T6 live promotion requires parallel validation on a broker-routable index route such as `NDX.DWX` or `WS30.DWX` before deploy.
- No backtests or pipeline phases are part of this build.
