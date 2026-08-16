# QM5_41022_wti-wdual-mom

**EA ID:** QM5_41022

**Source strategy:** `MOP-ZHAO-WTI-WDUAL-MOM-2026_S01`

## 1. Strategy Logic

On the first executable tick, within 180 minutes, of a genuine broker-clock
Monday, require the six immediately preceding completed WTI sessions to be
Friday, Thursday, Wednesday, Tuesday, Monday, and the preceding Friday.
Consume the exact broker-date Monday attempt before fallible gates. Compute
`log(PriorTuesdayClose / PrecedingFridayClose)` and
`log(PriorFridayClose / PriorTuesdayClose)`. BUY only when both are positive,
SELL only when both are negative, and remain flat on disagreement, equality,
or invalid history.

The position is a direct WTI structural sleeve held through the new broker
week and flattened by framework Friday close at broker hour 21. The cited
sources establish broad own-return continuation and bounded weekly commodity
context; they do not test this split-week agreement or CFD package. Q02 is a
falsification, not a transferred performance or decorrelation claim.

## 2. Parameters

- Monday entry grace: 180 minutes from executable session open. Native
  same-day labels and governed energy prior-date labels use elapsed time
  modulo one day.
- Formation: exact six-bar Friday-through-Friday sequence; disjoint opening
  and closing segment return signs must agree.
- Risk stop: completed-bar ATR(20), multiplier 3.5.
- Entry spread ceiling: 1,500 points.
- Lifecycle: framework Friday close at broker hour 21, next-week repair, and
  seven-calendar-day final stale guard.
- All parameters are locked; no Q02 sweep or baseline rescue is authorized.

## 3. Symbol Universe

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot 0: `410220000`.
- No paired leg, synthetic symbol, implicit port, or external runtime feed.

## 4. Timeframe

The EA runs only on an `XTIUSD.DWX` D1 chart. It reads exactly six completed
D1 bars behind one framework new-bar edge and rejects missing or shifted
weekday sequences. Broker time defines the decision date. If the factory
labels the current energy session 24-48 hours behind broker time, one uniform
`+1`-day offset normalizes the current and completed labels; no other shift or
substitution is allowed. The current Monday bar never enters either return.

## 5. Expected Behaviour

The EA consumes at most one attempt per genuine broker Monday and expects
approximately 20-35 completed positions per full post-warm-up year after
agreement and holiday exclusions. Positions normally remain open until the
Friday sweep.

Q02 must retire below five completed positions per year, for zero trades,
wrong weekday/timing or agreement behavior, invalid risk mode, carry beyond
the governed lifecycle, or nonpositive governed economics. Q09 alone may
measure correlation with the certified book.

## 6. Source Citation

- Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
  Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`.
- Zhao, S., Ding, Y., Yu, J., and Kang, W. (2026), "Momentum and Reversal on
  the Short-Term Horizon: Evidence from Commodity Markets," SSRN 6425598,
  DOI `10.2139/ssrn.6425598`.

Complete governed source evidence is recorded in
`strategy-seeds/sources/MOP-ZHAO-WTI-WDUAL-MOM-2026/source.md`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Lots derive only from the frozen hard-stop distance;
signal magnitude never changes risk. Both news axes are OFF. Friday close is
ON at broker hour 21 and is the ordinary lifecycle exit.

This build has no live/demo/shadow/stress/optimization preset or live
authorization. AutoTrading, `T_Live`, deploy/T_Live manifests, portfolio
admission, portfolio-gate changes, and correlation waivers are outside scope.

## Version History

| Version | Date | Change | Status |
|---|---|---|---|
| v1 | 2026-08-16 | approved build scaffold | G0 approved |
| v1-build | 2026-08-16 | deterministic implementation | magic/resolver verified; strict compile and build check PASS |
