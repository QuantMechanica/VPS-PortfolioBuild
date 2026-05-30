# QM5_1243 Carver Leveraged EWMAC

## Scope
- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1243_carver-ewmac-lev.md`
- V5 EA: `framework/EAs/QM5_1243_carver-ewmac-lev/QM5_1243_carver-ewmac-lev.mq5`
- Timeframe: `D1`
- Universe: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`

## Strategy Mapping
- Entry: forecast `(EMA(16)-EMA(64))/ATR(25)` crossing `+/-1.0` on closed D1 bar, gated by `Close` relative to `SMA(100)`.
- Filters: minimum D1 history, ATR not below `0.50 * median ATR(252)`, spread not above `2.0 * median spread(60D)`.
- Stop: initial `3.0 * ATR(25)`.
- Management: once open profit exceeds `1.5R`, trail stop toward `SlowEMA +/- 1.0 * ATR(25)`.
- Exit: forecast crossing back through zero, close crossing slow EMA, or `160` D1 bars max hold.
- Sizing: V5 risk contract, fixed USD risk in backtest and percent risk in live setfiles.

## Framework Alignment
- No-Trade: timeframe, universe, slot, and input sanity checks.
- Entry: closed D1 signal only, one position per symbol/magic via framework duplicate guard.
- Management: card-authorized slow EMA / ATR trailing only.
- Close: forecast, slow EMA, and time-stop exits.
- Magic: uses `QM_MagicChecked` through V5 framework and per-symbol `symbol_slot`.

## Boundaries
- No ML, optimizer, external market-data API, or portfolio leverage optimizer.
- No backtests or pipeline phases were run as part of this build.
