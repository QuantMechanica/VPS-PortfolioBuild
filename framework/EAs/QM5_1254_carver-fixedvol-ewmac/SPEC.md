# QM5_1254 Carver Fixed-Volatility EWMAC

## Scope
- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1254_carver-fixedvol-ewmac.md`
- V5 EA: `framework/EAs/QM5_1254_carver-fixedvol-ewmac/QM5_1254_carver-fixedvol-ewmac.mq5`
- Timeframe: `D1`
- Universe: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`

## Strategy Mapping
- Entry: on a closed D1 bar, compute `EMA(64)-EMA(256)` and divide by a monthly frozen fixed-vol estimate from `median(abs(daily_return), 1500) * 16 * close`, then scale and cap forecast to `[-20,+20]`.
- Signal: enter long when forecast is above `+4`; enter short when forecast is below `-4`; one position per symbol/magic.
- Filter: require at least `FixedVolLookbackDays + 256` D1 bars and reject new entries when current spread exceeds `2.0 * median spread(20D)`.
- Stop: emergency initial stop at `3.0 * ATR(20, D1)`.
- Exit: close long when forecast is `<= 0`; close short when forecast is `>= 0`. Opposite entries can only occur on a later D1 close after the previous exit bar.
- Sizing: V5 risk contract, fixed USD risk in backtest and percent risk in live setfiles; fixed volatility only affects forecast generation.

## Framework Alignment
- No-Trade: timeframe, universe, slot, and input sanity checks.
- Entry: closed D1 signal only, with spread and history gates.
- Management: no trailing management beyond the card-authorized emergency ATR stop.
- Close: forecast zero-cross exit.
- Magic: uses V5 framework magic resolution and per-symbol `symbol_slot`.

## Boundaries
- No ML, optimizer, external market-data API, grid, or martingale logic.
- No backtests or pipeline phases were run as part of this build.
