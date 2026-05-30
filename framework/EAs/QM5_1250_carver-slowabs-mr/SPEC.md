# QM5_1250 Carver Very Slow Absolute Mean Reversion

## Scope
- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1250_carver-slowabs-mr.md`
- V5 EA: `framework/EAs/QM5_1250_carver-slowabs-mr/QM5_1250_carver-slowabs-mr.mq5`
- Timeframe: `D1`
- Universe: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`

## Strategy Mapping
- Entry: on closed D1 bars, compute cumulative return normalised by 25-day EWMA volatility, compare it with a 1000-day normalised-price anchor, and trade contrarian at `z < -1.5` or `z > +1.5`.
- Exit: close longs when `z >= -0.25`, close shorts when `z <= +0.25`, or when the position reaches the 180 D1-bar time stop.
- Stop: initial emergency stop at `3.0 * ATR(20, D1)`.
- Filters: require `LookbackDays + 250` warmup plus additional calculation history and reject new entries when spread is above `2.0 * median spread(20D)`.
- Sizing: V5 risk contract, fixed USD risk in backtest setfiles and percent risk in live setfiles.

## Framework Alignment
- No-Trade: framework kill-switch, Friday close, news axes, and risk-contract checks are left intact.
- Entry: one closed D1 signal per bar; one position per symbol/magic through the V5 entry guard.
- Management: no discretionary trailing is added; the card only authorizes emergency ATR stop and time stop.
- Close: z-score reversion and time-stop exits only.
- Magic: uses V5 `QM_MagicChecked` through framework init and per-symbol `symbol_slot`.

## Boundaries
- No ML, optimizer, external market-data API, grid, martingale, or source-dependent runtime call.
- No backtests or pipeline phases were run as part of this build.
