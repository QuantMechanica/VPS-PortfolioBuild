# QM5_1231 Carver PCA Alpha Persistence

## Strategy Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1231_carver-pca-alpha.md`
- Status: APPROVED
- EA label: `QM5_1231_carver-pca-alpha`
- Framework: QuantMechanica V5

## Framework Alignment

- No-trade: D1 only, registered symbol-slot only, complete basket warmup, spread cap, V5 news and Friday-close guardrails.
- Entry: first tradable D1 bar of each month; compute 252-bar volatility-normalised returns across the registered DWX basket, fit fixed PCA components, regress each instrument on retained components, winsorise alpha, convert to capped forecast, then enter top positive and negative forecasts.
- Management: emergency ATR stop is placed on entry. No residual mean-reversion branch or adaptive management is added.
- Exit: monthly rebalance only; close long when forecast crosses non-positive or close short when forecast crosses non-negative.
- Stop: emergency ATR stop via `QM_StopATR`, default `2.5 * ATR(20, D1)`.

## Universe And Slots

Slots `0..4` are the equity-index members: `GER40.DWX`, `NDX.DWX`, `WS30.DWX`, `UK100.DWX`, `FRA40.DWX`.

Slots `5..10` are the FX-major members: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `USDCAD.DWX`.

## Parameters

- Default variant: `lookback=252`, `NumPC=3`, `EntryForecast=5`.
- P3 PC variant is represented by a `NumPC=1` setfile.
- ATR variants are represented by setfiles for `2.0`, `2.5`, and `3.0`.
- Cross-sectional cap: at most two long and two short slots in the basket.

## Notes

- Build only. No backtests or pipeline phases were run.
- `.DWX` suffixes remain in build and setfiles. Deploy-time stripping is outside this scope.
