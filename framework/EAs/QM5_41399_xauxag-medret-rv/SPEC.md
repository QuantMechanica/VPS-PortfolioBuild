# QM5_41399 — XAU/XAG Ordinary Monthly Return-Median Reversion

**EA ID:** QM5_41399

**Strategy:** `SCHWEIKERT-CME-MOP-XAUXAG-MEDRET-RV-20260909_S01`

**Carrier:** logical basket `QM5_41399_XAU_XAG_MEDRET_RV_D1`, hosted on
`XAUUSD.DWX` D1; slot 0 magic `413990000`, slot 1 magic `413990001`

## 1. Strategy Logic

At the first synchronized executable D1 bar of a broker month, collect the
latest common XAU/XAG completed close in each of the immediately prior
thirteen consecutive broker months. Form twelve chronological adjacent
log-ratio changes, sort all twelve individual values, and average sorted
indexes five and six. Fade the sign outside `1e-12`: positive sells XAU/buys
XAG; negative buys XAU/sells XAG; otherwise consume the month flat.

Open only an equal-target-notional opposed pair. Hold to the next broker month
and repair after forty elapsed days or any malformed package state.

## 2. Parameters

- 13 synchronized completed endpoints and 12 adjacent changes.
- Full ascending sort; ordinary even median indexes 5 and 6; divisor two.
- Sign epsilon `1e-12`; 1,200 D1 history bars; endpoint freshness ten days.
- Month-entry grace 180 minutes; one persistent attempt per month.
- Backtest `RISK_FIXED>0`, `RISK_PERCENT=0`; setfile portfolio weight one.
- Per-leg frozen `3.5*ATR(20,D1)` hard stops and no targets.
- Equal target notionals with a 20% live-notional mismatch ceiling.
- XAU/XAG spread caps 1,500/500 points; stale repair after 40 days.

## 3. Symbol Universe And Timeframe

Trade exactly registered native `XAUUSD.DWX` slot zero and `XAGUSD.DWX` slot
one as one opposed logical basket. Attach and test on XAU D1. Neither leg may
trade alone or serve as an outright-direction fallback.

## 4. Expected Behaviour

Fail closed on missing/nonconsecutive months, unsynchronized endpoints,
nonpositive closes, nonfinite arithmetic, an epsilon state, invalid execution
state, or malformed exposure. Consume the month before fallible gates and
never retry. Defensive management removes orphan, duplicate, wrong-side,
stopless, or materially mismatched exposure.

## 5. Source Citation

Approved composite `SCHWEIKERT-CME-MOP-XAUXAG-MEDRET-RV-20260909`, grounded
in Schweikert (2018), *Journal of Banking & Finance* 88, DOI
`10.1016/j.jbankfin.2017.11.010`; CME Group's Gold & Silver Ratio Spread; and
Moskowitz, Ooi, and Pedersen (2012), *JFE* 104(2), DOI
`10.1016/j.jfineco.2011.11.003`. No source validates this exact conjunction,
continuous-CFD transport, profitability, or book decorrelation.

## 6. Risk And Framework Alignment

One aggregate fixed-dollar frozen-stop budget is split across the two legs.
Equal target notionals reduce first-order metal beta but do not prove market
neutrality. Legging, financing, gap, spread, roll/basis, synchronization, and
residual metal-factor risks remain material.

| Contract | Implementation |
|---|---|
| no-trade and attempt | exact identity/strategy checks, framework-owned input freedom, synchronized monthly clock, durable consumed-month key |
| entry | endpoint reconstruction, raw-return sort, ordinary median, contrarian side, fixed aggregate risk, equal notionals, atomic open |
| management | pair integrity, expected side, notional tolerance, original hard stops |
| close | next-month, forty-day stale, malformed-pair, and framework kill-switch closure |

## 7. Validation And Safety

`docs/test_xauxag_medret_rv_reference.py` independently pins the sort and even
median, sign/reflection, degeneracy, synchronized ratio changes, PACER-safe
input guard, and disagreement with block-median and Winsorized neighbors.

Q02 owns baseline economics and Q09 alone owns realized overlap. Portfolio
gates, deploy/live manifests, `T_Live`, AutoTrading, terminal control, manual
tests, and optimization remain outside scope.
