# QM5_1252 Carver Handcrafted Live-Rule Ensemble

## Scope
- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1252_carver-handcraft-ens.md`
- V5 EA: `framework/EAs/QM5_1252_carver-handcraft-ens/QM5_1252_carver-handcraft-ens.mq5`
- Timeframe: `D1`
- Universe: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`

## Strategy Mapping
- Entry: on each closed D1 bar, compute an ensemble forecast from EWMAC, breakout, normalised momentum, skew, mean-reversion, and acceleration component families.
- Component availability: unavailable components are skipped and the remaining Level-3-style handcrafted weights are renormalised; at least three valid families are required before entry.
- Cost gate: component families are skipped when estimated turnover times `MedianSpread(20D)/ATR(20,D1)` exceeds `0.13`.
- Combined forecast: weighted forecast is capped to `[-20,+20]`; long entry requires `> +5`, short entry requires `< -5`.
- Exit: close longs when combined forecast is `<= +1`; close shorts when combined forecast is `>= -1`.
- Stop: initial emergency stop at `3.0 * ATR(20,D1)`.
- Filters: new entries are rejected when current spread is above `2.0 * median spread(20D)`.
- Sizing: V5 risk contract, fixed USD risk in backtest setfiles and percent risk in live setfiles.

## Framework Alignment
- No-Trade: framework kill-switch, Friday close, news axes, and risk-contract checks are left intact.
- Entry: one closed D1 signal per bar; one position per symbol/magic through the V5 entry guard.
- Management: no discretionary trailing is added; the card only authorizes the emergency ATR stop.
- Close: forecast-neutralisation exits only.
- Magic: uses V5 `QM_MagicChecked` through framework init and per-symbol `symbol_slot`.

## Boundaries
- Carry and relative-carry rules are intentionally skipped at runtime unless deterministic DWX carry data is available; this build does not introduce an external data dependency.
- No ML, optimizer, external market-data API, grid, martingale, or source-dependent runtime call.
- No backtests or pipeline phases were run as part of this build.
