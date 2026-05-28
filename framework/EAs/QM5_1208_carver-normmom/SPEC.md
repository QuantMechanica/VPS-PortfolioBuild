# QM5_1208 Carver Normalised Momentum

## Scope

Build-only implementation of approved Strategy Card `QM5_1208_carver-normmom`.

## Framework Alignment

- No-Trade: V5 kill switch, DXZ high-impact news hook, Friday close, D1-only gate, symbol/slot gate, and optional spread cap.
- Trade Entry: on a newly closed D1 bar, compute volatility-normalised returns, cumulative normalised price, EWMAC forecast, and enter long above `+EntryForecast` or short below `-EntryForecast`.
- Trade Management: no trailing logic; emergency ATR stop is placed at entry.
- Trade Close: close long when forecast falls below zero; close short when forecast rises above zero. Same-bar flip is blocked.

## Symbols

- Slot 0: `EURUSD.DWX`
- Slot 1: `GBPUSD.DWX`
- Slot 2: `USDJPY.DWX`
- Slot 3: `GER40.DWX`
- Slot 4: `NDX.DWX`
- Slot 5: `WS30.DWX`
- Slot 6: `XAUUSD.DWX`

## Parameters

- Baseline: `Fast=16`, `Slow=64`, `VolLookback=25`, `EntryForecast=2`, `ForecastCap=20`.
- P3 speed sweeps: `Fast in {2,4,8,16,32,64}`, `Slow=4*Fast`.
- Stop: `2.5 * ATR(20,D1)` with variants `2.0`, `3.0`.
- Risk: backtest uses `RISK_FIXED=1000`; live uses `RISK_PERCENT=0.5`.

## Notes

The Strategy Card specifies a `2 * MedianSpread(20D)` entry block. MT5 does not expose historical spread as a D1 price series, so the EA uses a build-time configurable `strategy_max_spread_points` cap. A value of `0` disables the cap.
