# QM5_1206_lento-sp500-csa-ma SPEC

## Strategy

Lento S&P 500 Combined MA Signal, long/flat D1 implementation for `SP500.DWX`.

## Card Mapping

- Entry: once per new D1 bar, enter long when `SMA(1) > SMA(200)` and `SMA(5) > SMA(150)` on the last closed D1 bar.
- Exit: close long when both source MA signals are bearish.
- Disagreement: hold through the first disagreeing D1 signal bar; flatten if disagreement persists for the configured next recomputation.
- Stop: initial and trailing stop at `3.0 * ATR(20)` below the relevant D1 reference price.
- Risk: backtest uses `RISK_FIXED=1000`; live set uses `RISK_PERCENT=0.25`.

## V5 Alignment

- No ML, grid, martingale, external data calls, or web/API dependencies.
- Magic is resolved only through `QM_Magic(qm_ea_id, qm_magic_slot_offset)`.
- Symbol suffix remains `.DWX`; deploy packaging owns any live symbol mapping.
- Build scope intentionally does not run backtests or pipeline phases.

## T6 Note

`SP500.DWX` is retained as the research/backtest route from the approved card. Live promotion requires later parallel validation on a broker-routable index route such as `NDX.DWX` or `WS30.DWX`.
