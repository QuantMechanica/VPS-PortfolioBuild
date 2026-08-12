# QM5_20164 xng-summer-dualtrend - Strategy Spec

**EA ID:** QM5_20164
**Slug:** `xng-summer-dualtrend`
**Source:** `EIA-MOP-XNG-SUMMER-DUALTREND-2026`

## 1. Strategy Logic

During May through September, buy XNG only when the completed D1 close,
SMA(21), SMA(84), and both five-day SMA slopes form a positive rising stack.
Use one position per magic, a frozen ATR stop, trend/season exits, and the
framework Friday close.

## 2. Parameters

The locked baseline uses SMA periods 21/84, five slope bars, ATR(20), a
3.5-ATR stop, a 35-day stale exit, and a 1,000-point spread ceiling.

## 3. Symbol Universe

Exact registered carrier: `XNGUSD.DWX`.

## 4. Timeframe

D1 only. The framework `QM_IsNewBar()` gate permits one decision per D1 bar.

## 5. Expected Behaviour

Approximately 8-18 completed May-September packages per year when the trend
state is valid. Q02 retires the EA below five completed trades per year.

## 6. Source Citation

U.S. EIA (2015), “Natural gas use features two seasonal peaks per year,” for
summer electric-power demand; Moskowitz, Ooi and Pedersen (2012), “Time
Series Momentum,” Journal of Financial Economics 104(2), for price
persistence. Exact implementation parameters are QM hypotheses.

## 7. Risk Model

Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live setfile is authorized.
