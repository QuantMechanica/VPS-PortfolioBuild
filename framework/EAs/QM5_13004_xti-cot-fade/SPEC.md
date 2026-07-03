# QM5_13004_xti-cot-fade - Strategy Spec

**EA ID:** QM5_13004
**Slug:** `xti-cot-fade`
**Source:** `CFTC-COT-RELEASE-2026`
**Host:** `XTIUSD.DWX` D1

## 1. Strategy Logic

The EA trades a single-symbol WTI sleeve tied to the official CFTC
Commitments of Traders release cadence. On the first D1 bar of a new broker
week, it checks the prior completed Friday D1 bar. If that bar has a large
close-to-close displacement, closes near the bar extreme, and is stretched from
SMA, the EA enters opposite the displacement.

This is not WPSR/inventory, OPEC, IEA, STEO, DPR, SPR, Cushing, refinery,
product-seasonality, roll, expiry, WTI/Brent, XTI/XNG, oil-metal ratio, broad
commodity TSMOM/reversal/carry, or XNG rig-count logic. It uses the CFTC COT
release window only as structural lineage and does not read COT data at
runtime.

## 2. Parameters

- `strategy_min_signal_return_pct`: minimum absolute Friday log return.
- `strategy_min_atr_return_mult`: minimum signal return relative to D1 ATR.
- `strategy_max_signal_return_pct`: outlier guard for abnormal bars.
- `strategy_close_location_min`: directional close-location confirmation.
- `strategy_signal_dow`: required prior D1 signal day; default Friday.
- `strategy_atr_period`: D1 ATR period for stop and signal scaling.
- `strategy_mean_period`: SMA period for stretch and mean exits.
- `strategy_min_stretch_atr`: required signal-bar distance from SMA in ATRs.
- `strategy_atr_sl_mult`: ATR hard-stop distance.
- `strategy_max_hold_days`: time-stop length.
- `strategy_reversion_close_atr_mult`: favorable closed-bar reversion exit.
- `strategy_adverse_close_atr_mult`: adverse closed-bar continuation exit.
- `strategy_max_spread_points`: maximum entry spread in broker points.

## 3. Symbol Universe

The universe is `XTIUSD.DWX` only. The magic registry uses slot 0 with magic
`130040000`. The EA rejects any other host symbol or timeframe.

## 4. Timeframe

The strategy runs on `PERIOD_D1`. It uses completed D1 OHLC, ATR, SMA, spread,
and broker calendar reads only; there is no intraday trigger, cross-symbol
confirmation, external CFTC feed, CSV, API, futures curve, or ML model.

## 5. Expected Behaviour

Expected frequency is low, approximately 4-12 trades per year before Q02
confirms realized history. Entries occur only on the first new-week D1 bar
after a qualifying prior Friday displacement. Positions close by ATR hard stop,
SMA mean exit, favorable reversion close, adverse continuation close, time
stop, or framework Friday-close handling.

## 6. Source Citation

Primary source packet: CFTC Commitments of Traders pages and release schedule:
`https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm` and
`https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm`.
CME COT context is cited as supplemental exchange context. The EA does not
consume any report at runtime.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
The EA uses one position at a time, an ATR hard stop, a short time stop, no
grid, no martingale, no pyramiding, no partial close, no ML, no portfolio gate
change, no live manifest change, and no AutoTrading control.
