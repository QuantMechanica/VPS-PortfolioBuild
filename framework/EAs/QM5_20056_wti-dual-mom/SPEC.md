# QM5_20056_wti-dual-mom - Strategy Spec

**EA ID:** QM5_20056

## 1. Strategy Logic

Monthly WTI time-series momentum entry only when 63-D1 and 252-D1 return signs agree.

## 2. Parameters

Fast lookback 63, slow lookback 252, ATR 20, stop 3.5 ATR, maximum hold 31 days.

## 3. Symbol Universe

`XTIUSD.DWX`, magic slot 0.

## 4. Timeframe

D1 with first-bar-of-month entry evaluation.

## 5. Expected Behaviour

Approximately 6-12 trades/year; flat while the two horizons disagree.

## 6. Source Citation

Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, JFE 104(2).

## 7. Risk Model

Q02 uses `RISK_FIXED=1000` and `RISK_PERCENT=0`; no live artifact is included.
