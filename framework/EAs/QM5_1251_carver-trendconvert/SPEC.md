# QM5_1251 Carver Trend-Converter Asset Filter

## Scope
- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1251_carver-trendconvert.md`
- V5 EA: `framework/EAs/QM5_1251_carver-trendconvert/QM5_1251_carver-trendconvert.mq5`
- Timeframe: `D1`
- Universe: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`

## Strategy Mapping
- Entry: on each closed D1 bar, calculate EWMAC `64/256`, volatility-normalise the forecast, cap it to `[-20,+20]`, and enter long above `+4` or short below `-4`.
- Asset-class gate: calculate a fixed-window `ConversionSR` from lagged EWMAC forecast times next-day return over `1500` D1 bars. FX and indices use the median score across class members; metals and energy fall back to symbol-level score because each class has fewer than three members.
- Exit: close longs when forecast is `<= 0`, close shorts when forecast is `>= 0`, or close either side when the conversion score falls below `0`.
- Stop: initial emergency stop at `2.5 * ATR(20, D1)`.
- Filters: require enough D1 history for conversion plus slow EWMAC warmup and reject new entries when spread exceeds `2.0 * median spread(20D)`.
- Sizing: V5 risk contract, fixed USD risk in backtest setfiles and percent risk in live setfiles.

## Framework Alignment
- No-Trade: framework kill-switch, Friday close, news axes, and risk-contract checks are left intact.
- Entry: one closed D1 signal per bar; one position per symbol/magic through the V5 entry guard.
- Management: no trailing or discretionary management is added; only the card-authorized emergency ATR stop is attached at entry.
- Close: forecast zero-cross and conversion-score deterioration only.
- Magic: uses V5 framework magic resolution through `QM_FrameworkInit` and per-symbol `symbol_slot`.

## Boundaries
- No ML, optimizer, external market-data API, grid, martingale, or source-dependent runtime call.
- No backtests or pipeline phases were run as part of this build.
