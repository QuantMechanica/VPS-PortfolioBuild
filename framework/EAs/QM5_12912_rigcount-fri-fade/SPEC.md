# QM5_12912_rigcount-fri-fade - Strategy Spec

**EA ID:** QM5_12912
**Slug:** `rigcount-fri-fade`
**Source:** `BAKERHUGHES-RIGCOUNT-2026`
**Host:** `XTIUSD.DWX` D1

## 1. Strategy Logic

The EA trades a single-symbol WTI sleeve tied to the weekly Baker Hughes North
America rig-count release cadence. On the first D1 bar of a new broker week, it
checks the prior completed D1 bar, which is the final workday of the prior week
and the market-reaction proxy for the rig-count window. If that bar has a large
close-to-close displacement and closes near the bar extreme, the EA enters
opposite the displacement.

This is not a WTI static weekday/month anomaly, weekend-gap bounce/fade, WPSR,
Cushing, refinery, hurricane, OPEC, SPR, expiry, ETF-roll, broad seasonality,
XTI/XNG ratio, metals-ratio, XNG, or RSI commodity sleeve. It is also distinct
from `QM5_12858_rigcount-fri-mom`: this card fades the same event-proxy
displacement instead of following it.

## 2. Parameters

- `strategy_min_signal_return_pct`: minimum absolute final-workday log return.
- `strategy_min_atr_return_mult`: minimum signal return relative to D1 ATR.
- `strategy_max_signal_return_pct`: outlier guard for abnormal bars.
- `strategy_close_location_min`: directional close-location confirmation.
- `strategy_signal_min_dow`: allowed final-workday gate, Thursday or Friday.
- `strategy_atr_period`: D1 ATR period for stop and signal scaling.
- `strategy_atr_sl_mult`: ATR hard-stop distance.
- `strategy_max_hold_days`: time-stop length.
- `strategy_reversion_close_atr_mult`: favorable closed-bar reversion exit.
- `strategy_adverse_close_atr_mult`: adverse closed-bar continuation exit.
- `strategy_max_spread_points`: maximum entry spread in broker points.

## 3. Symbol Universe

The universe is `XTIUSD.DWX` only. The magic registry uses slot 0 with magic
`129120000`. The EA rejects any other host symbol or timeframe.

## 4. Timeframe

The strategy runs on `PERIOD_D1`. It uses completed D1 OHLC and ATR reads only;
there is no intraday trigger, no cross-timeframe confirmation, and no external
runtime Baker Hughes or EIA data feed.

## 5. Expected Behaviour

Expected frequency is low, approximately 6-14 trades per year before Q02
confirms realized history. Entries occur only on the first new-week D1 bar after
a qualifying prior final-workday displacement. Positions close by ATR hard stop,
time stop, framework Friday close handling, favorable reversion close, or
adverse completed-close continuation.

## 6. Source Citation

Primary source packet: `strategy-seeds/sources/BAKERHUGHES-RIGCOUNT-2026/`.
The cited official sources are Baker Hughes Rig Count Overview and Summary Count
and the Baker Hughes Rig Count FAQ. The source establishes the weekly North
America rig-count cadence and the rig count's role as an industry activity
barometer. The EA does not consume the report at runtime.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
The EA uses one position at a time, an ATR hard stop, a short time stop, and no
grid, martingale, pyramiding, partial close, ML, portfolio gate change, live
manifest change, or AutoTrading control.
