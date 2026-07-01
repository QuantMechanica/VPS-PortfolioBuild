# QM5_12861_xng-hurr-fade - Strategy Spec

**EA ID:** QM5_12861
**Slug:** `xng-hurr-fade`
**Source:** `EIA-NOAA-XNG-HURR-2026_S02`
**Host:** `XNGUSD.DWX` D1

## 1. Strategy Logic

The EA trades a single-symbol natural-gas sleeve during the Atlantic hurricane
risk window. It does not ingest weather, EIA, LNG, storage, futures-curve, CSV,
API, or analyst data at runtime. It uses the official EIA/NOAA source packet
only to define structural context, then waits for `XNGUSD.DWX` itself to print a
failed upside spike.

Entry is short-only: the completed D1 signal bar must be inside August 15
through October 31, make a new `strategy_reject_lookback` high, stretch above
SMA by `strategy_min_stretch_atr` ATR, and close with bearish rejection near
the bar low. The EA exits on SMA normalization, upside exit-channel
invalidation, season end, max hold, Friday close, or ATR hard stop.

This is not `QM5_12601_eia-xng-hurr-brk`, which buys confirmed upside
hurricane-window breakouts. It is also not XNG winter freeze fade, shoulder
short, storage, LNG, broad monthly seasonality, weekend gap, XTI/XNG basket,
XAU/XAG, index, or `QM5_12567` RSI commodity logic.

## 2. Parameters

- `strategy_start_month`, `strategy_start_day`: start of hurricane fade window.
- `strategy_end_month`, `strategy_end_day`: end of hurricane fade window.
- `strategy_reject_lookback`: prior high window excluding the signal bar.
- `strategy_exit_channel`: upside invalidation window.
- `strategy_trend_period`: SMA normalization reference.
- `strategy_atr_period`: ATR period for signal scaling and hard stop.
- `strategy_min_range_atr`: minimum signal-bar range.
- `strategy_min_body_ratio`: minimum bearish body share of range.
- `strategy_reversal_tail_ratio`: maximum close location for bearish rejection.
- `strategy_min_stretch_atr`: minimum high-to-SMA stretch in ATR units.
- `strategy_atr_sl_mult`: ATR hard-stop distance.
- `strategy_max_hold_days`: stale-position time stop.
- `strategy_max_spread_points`: entry spread cap.

## 3. Symbol Universe

The universe is `XNGUSD.DWX` only. The magic registry uses slot 0 with magic
`128610000`. The EA rejects any other host symbol, timeframe, or slot.

## 4. Timeframe

The strategy runs on `PERIOD_D1`. It uses completed D1 OHLC, ATR, and SMA reads
only. Bar-array reads are bounded and new-bar gated by the framework.

## 5. Expected Behaviour

Expected frequency is low, approximately 3-7 trades per year before Q02
confirms realized history. Positions close by ATR hard stop, SMA normalization,
exit-channel invalidation, season end, time stop, or the framework Friday-close
guard.

## 6. Source Citation

Primary source packet: `strategy-seeds/sources/EIA-NOAA-XNG-HURR-2026/`.
The cited official sources are EIA's hurricane energy-market analysis and the
NOAA/NHC tropical cyclone climatology page. The EA does not consume those
sources at runtime.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
The EA uses one position at a time, an ATR hard stop, short max hold, and no
grid, martingale, pyramiding, partial close, ML, portfolio gate change, live
manifest change, or AutoTrading control.
