# QM5_1208 Carver Normalised Momentum

Status: APPROVED

Source: Rob Carver qoppac blog.

## Mechanik

Trend rule that first converts price into a cumulative series of volatility-normalised daily returns, then applies an EWMAC trend filter to that transformed series.

## Entry

- On each closed D1 bar, compute raw return, rolling return standard deviation, clipped normalised return, cumulative normalised price, and EWMAC forecast.
- Default variant: `Fast=16`, `Slow=64`, `VolLookback=25`, `EntryForecast=2`.
- LONG when forecast is above `+EntryForecast`.
- SHORT when forecast is below `-EntryForecast`.

## Exit

- Close LONG when forecast falls below zero.
- Close SHORT when forecast rises above zero.
- Flip only on a later closed bar with opposite threshold.

## Stop Loss

- Emergency stop: `2.5 * ATR(20,D1)`.
- P3 variants: `2.0`, `2.5`, `3.0` ATR.

## Position Sizing

- P2 baseline: `RISK_FIXED=1000`.
- Live: `RISK_PERCENT=0.5`.
- One position per symbol/magic.

## Universe

`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `GER40.DWX`, `NDX.DWX`, `WS30.DWX`, `XAUUSD.DWX`.

## Filters

- Skip entries when sigma is unavailable or non-positive.
- Rebalance once per D1 bar.
- V5 high-impact news hook available.
