# QM5_1218 Carver Relative Momentum Within Asset Class

## Strategy Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1218_carver-relmomentum.md`
- Status: APPROVED
- EA label: `QM5_1218_carver-relmomentum`
- Framework: QuantMechanica V5

## Framework Alignment

- No-trade: D1 only, registered symbol-slot only, warmup validation, spread cap, V5 news and Friday-close guardrails.
- Entry: once per closed D1 bar, compute each instrument's cumulative volatility-normalised price versus its asset-group equal-weight average; enter long above `EntryForecast` and short below `-EntryForecast`.
- Management: emergency ATR stop is placed on entry; structural-break guard closes and blocks the symbol after an adverse `strategy_break_atr_mult * ATR(20)` move.
- Exit: close long when forecast falls below zero; close short when forecast rises above zero. Opposite-threshold flips can only occur on a later closed D1 bar.
- Stop: emergency ATR stop via `QM_StopATR`, default `2.5 * ATR(20, D1)`.

## Universe And Slots

Slots `0..4` are the equity-index group: `GER40.DWX`, `NDX.DWX`, `WS30.DWX`, `UK100.DWX`, `FRA40.DWX`.

Slots `5..10` are the FX-major group: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `USDCAD.DWX`.

## Parameters

- Default variant: `horizon=40`, `EntryForecast=2`, `EMA span=10`.
- P3 variants are represented by setfiles for `horizon=10`, `20`, `40`, and `80`.
- ATR variants are represented by setfiles for `2.0`, `2.5`, and `3.0`.
- Cross-sectional cap: at most two long and two short slots per asset group.

## Notes

- Build only. No backtests or pipeline phases were run.
- `.DWX` suffixes remain in build and setfiles. Deploy-time stripping is outside this scope.
