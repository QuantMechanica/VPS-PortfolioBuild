# QM5_1198 qp-sp500-highret-fade

## Scope
- Strategy Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1198_qp-sp500-highret-fade.md`
- Framework: QuantMechanica V5
- Symbol slot: `0 = SP500.DWX`
- Build only: no backtests or pipeline phases.

## Strategy Mapping
- No-Trade: blocks non-`SP500.DWX`, disabled symbols, and spread above card threshold.
- Entry: on the next intraday bar after the configured regular-session open, ranks the most recent completed D1 close-to-close return against the previous 250 completed returns; opens short when it is in the top 25.
- Management: no trailing, partial, or pyramiding logic; the card specifies hard stop plus fixed holding period.
- Exit: closes after the configured fixed number of D1 trading bars at the configured regular-session close, with safety exit on the next available bar. Gap-risk kill closes if open loss exceeds `2.5x` planned risk.
- Stop: hard stop at `2.0x ATR(20) D1` from entry.

## Parameters
- Baseline: lookback `250`, top rank count `25`, hold `1` trading day, ATR stop `2.0`.
- P3 variants: hold `2` and hold `3` trading days.
- Spread filter: current spread must not exceed `3x` the 20-day median M30 spread.

## Live Caveat
`SP500.DWX` is a backtest-only/T6 caveat route per the card. Live promotion requires parallel validation on a broker-routable proxy such as `NDX.DWX` or `WS30.DWX`.
