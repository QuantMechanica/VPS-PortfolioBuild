# QM5_1139_qp-sp500-rsi35-rebound SPEC

## Source

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1139_qp-sp500-rsi35-rebound.md`
- Strategy: Quantpedia RSI 35 Rebound on `SP500.DWX`
- Status at build: `g0_status: APPROVED`

## Framework Alignment

- No-Trade: blocks non-`SP500.DWX`, unsupported timeframes, non-regular US cash days, full US cash holidays, and spread above `3x` cached median H1 spread over the prior 20 trading days.
- Entry: on closed D1 bars, detects RSI(14) crossing below 35 from above and opens one long after the next New York regular cash-session open.
- Management: no trailing, break-even, partial close, pyramiding, or discretionary management beyond the initial hard ATR stop.
- Close: exits when closed D1 RSI(14) is above 55, or after 10 regular US cash trading days.

## Parameters

- `strategy_rsi_period = 14`
- `strategy_entry_rsi = 35.0`
- `strategy_exit_rsi = 55.0`
- `strategy_min_d1_closes = 60`
- `strategy_time_stop_days = 10`
- `strategy_atr_period = 20`
- `strategy_atr_sl_mult = 2.0`
- `strategy_spread_median_mult = 3.0`
- `strategy_spread_lookback_days = 20`
- `strategy_entry_hour_ny = 9`
- `strategy_entry_minute_ny = 30`

## Risk

- Backtest defaults: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Live defaults in setfile: `RISK_PERCENT=0.25`, `RISK_FIXED=0`

## Symbols and Magic

- Slot `0`: `SP500.DWX`
- Magic formula: `1139 * 10000 + symbol_slot`

## Notes

- `SP500.DWX` is a backtest/research symbol. Per card caveat, T6 live promotion requires parallel validation on a broker-routable route such as `NDX.DWX` or `WS30.DWX` before deploy.
- No backtests or pipeline phases are part of this build.
