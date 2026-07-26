# QM5_20166_xng-shoulder-brk — Strategy Spec

**EA ID:** QM5_20166  
**Slug:** xng-shoulder-brk  
**Source:** EIA-XNG-SHOULDER-2026  
**Last revised:** 2026-07-26

## 1. Strategy Logic

During March-April and September-October, trade a D1 close outside the prior
20 completed-bar range only when the prior range is compressed below 0.8 ATR.
Trade in the breakout direction. Exit after 15 days or when the shoulder
window ends.

## 2. Parameters

20-day channel, ATR(20), 0.8 ATR compression ceiling, 3 ATR frozen stop,
15-day maximum hold, and 2,500-point spread cap.

## 3. Symbol Universe

`XNGUSD.DWX`, magic slot 0 only.

## 4. Timeframe

D1 using completed bars.

## 5. Expected Behaviour

Approximately 5-15 trades/year. Q02 must prove the five-trades/year floor.

## 6. Source Citation

U.S. Energy Information Administration, “Natural gas consumption, production
respond to seasonal changes,” Today in Energy, 2015-09-24.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1. No live set exists.
