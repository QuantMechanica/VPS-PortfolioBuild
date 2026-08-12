# QM5_20167 xng-spring-dualtrend - Strategy Spec

**EA ID:** QM5_20167
**Slug:** `xng-spring-dualtrend`
**Source:** `EIA-MOP-XNG-SPRING-DUALTREND-2026`

## 1. Strategy Logic

During April and May, sell XNG only when the completed D1 close, SMA(21),
SMA(84), and both five-day SMA slopes form a negative falling stack. Use one
position per magic, a frozen ATR stop, trend/season exits, and framework
Friday close.

## 2. Parameters

Locked baseline: SMA 21/84, five slope bars, ATR(20), 3.5-ATR stop, 35-day
stale exit, and 1,000-point spread ceiling.

## 3. Symbol Universe

Exact registered carrier: `XNGUSD.DWX`.

## 4. Timeframe

D1 only, with one decision per new D1 bar.

## 5. Expected Behaviour

Approximately 5-10 completed April-May packages per year when the trend state
is valid. Q02 retires below five completed trades per year.

## 6. Source Citation

U.S. EIA (2015), “Natural gas use features two seasonal peaks per year,” for
the spring demand shoulder; Moskowitz, Ooi and Pedersen (2012), “Time Series
Momentum,” JFE 104(2), for price persistence. Exact parameters are QM
hypotheses.

## 7. Risk Model

Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live setfile is authorized.
