# QM5_1253 Carver Low-Beta Relative Value

## Strategy Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1253_carver-lowbeta-rv.md`
- Status: APPROVED
- EA label: `QM5_1253_carver-lowbeta-rv`
- Framework: QuantMechanica V5

## Framework Alignment

- No-trade: D1 only, registered symbol-slot only, warmup validation, V5 news and Friday-close guardrails.
- Entry: on the first tradable D1 close of a new month, compute each symbol's beta to its equal-weight asset-group return over `strategy_beta_lookback_days`; long the lowest-beta ranks and short the highest-beta ranks.
- Management: emergency ATR stop is placed on entry; group stop closes EA positions in the current asset group if combined open loss exceeds `strategy_group_stop_r * RISK_FIXED`.
- Exit: on monthly rebalance, close a long if it leaves the bottom `strategy_exit_long_quantile`; close a short if it leaves the top `strategy_exit_short_quantile`; close if group breadth is no longer sufficient.
- Spread: new entries are skipped when current spread exceeds `strategy_spread_mult` times the median D1 spread window.

## Universe And Slots

Slots `0..4` are the equity-index group: `GER40.DWX`, `NDX.DWX`, `WS30.DWX`, `UK100.DWX`, `FRA40.DWX`.

Slots `5..10` are the FX-major group: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `USDCAD.DWX`.

Metals are not included because the approved rule requires group breadth of at least four active symbols.

## Parameters

- Baseline: `BetaLookbackDays=756`, `LongQuantile=0.25`, `ShortQuantile=0.25`.
- Exit bands: bottom/top `0.35`.
- Slot cap: `MaxSlotsPerSidePerGroup=2`.
- Stop: `3.0 * ATR(20, D1)`.

## Notes

- Build only. No backtests or pipeline phases were run.
- `.DWX` suffixes remain in build and setfiles. Deploy-time stripping is outside this scope.
