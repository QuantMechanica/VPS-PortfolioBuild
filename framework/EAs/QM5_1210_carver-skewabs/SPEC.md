# QM5_1210 Carver Absolute Skew Rule

## Scope

Implements the approved V5 Strategy Card `QM5_1210_carver-skewabs`.

## Framework Alignment

- No-Trade: D1 timeframe only, symbol/slot guard, minimum history guard, parameter sanity checks.
- Entry: on each closed D1 bar, compute rolling skew of log returns, demean by baseline skew, scale by rolling absolute median signal, cap forecast to `[-20,+20]`, enter long above `+EntryForecast` and short below `-EntryForecast`.
- Management: no discretionary trailing; emergency ATR stop is placed at entry.
- Exit: close long when forecast drops below `0`; close short when forecast rises above `0`. Same-bar flip is suppressed.

## Parameters

- Default lookback: `365` D1 bars.
- P3 lookback variant: `180` D1 bars.
- Optional exploratory variant: `90` D1 bars.
- Baseline skew: `0`.
- Entry forecast threshold: `2`.
- Forecast cap: `20`.
- Stop: `3.0 * ATR(20, D1)`, with P3 variants `2.5` and `3.5`.
- Spread gate: current spread must be no more than `2 * MedianSpread(20D)`.

## Symbols

Backtest and live templates are generated for:

- `GER40.DWX`
- `NDX.DWX`
- `WS30.DWX`
- `EURUSD.DWX`
- `GBPUSD.DWX`
- `USDJPY.DWX`
- `XAUUSD.DWX`
- `XTIUSD.DWX`

The approved card listed `XAUUSD` and `XTIUSD`; these are normalized to the project-standard `.DWX` build symbols.

## Validation

Build-only scope. No backtests or pipeline phases are run by this EA build.
