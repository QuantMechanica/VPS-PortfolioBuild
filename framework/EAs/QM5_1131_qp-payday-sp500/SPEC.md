# QM5_1131_qp-payday-sp500 SPEC

## Source

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1131_qp-payday-sp500.md`
- Strategy: Quantpedia Payday Anomaly on `SP500.DWX`
- Status at build: `g0_status: APPROVED`

## Framework Alignment

- No-Trade: blocks non-`SP500.DWX`, unsupported timeframes, non-regular US cash days, early closes, full US holidays, and current spread above `3x` cached median H1 spread over the prior 20 trading days.
- Entry: one long per month on the 16th calendar day, shifted to the next regular US cash trading day when the 16th is weekend/full holiday. Entry is allowed from the configured NY cash-session open time.
- Management: no trailing, break-even, partial close, pyramiding, or discretionary management beyond the initial stop.
- Close: exits on the same NY cash-session day near regular close, with a safety exit at or after 16:00 NY if the scheduled close was missed.

## Parameters

- `strategy_payday_day = 16`
- `strategy_entry_hour_ny = 9`
- `strategy_entry_minute_ny = 30`
- `strategy_exit_hour_ny = 15`
- `strategy_exit_minute_ny = 55`
- `strategy_safety_exit_hour_ny = 16`
- `strategy_atr_period = 20`
- `strategy_atr_sl_mult = 1.5`
- `strategy_spread_median_mult = 3.0`
- `strategy_spread_lookback_days = 20`

## Risk

- Backtest defaults: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Live defaults in setfile: `RISK_PERCENT=0.25`, `RISK_FIXED=0`

## Symbols and Magic

- Slot `0`: `SP500.DWX`
- Magic formula: `1131 * 10000 + symbol_slot`

## Notes

- `SP500.DWX` is a backtest/research symbol. Per card caveat, T6 live promotion requires parallel validation on a broker-routable index route such as `NDX.DWX` or `WS30.DWX` before deploy.
- No backtests or pipeline phases are part of this build.
