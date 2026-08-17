# QM5_21503_xti-weekly-tsmom-lowvol

**EA ID:** QM5_21503

**Source strategy:** `ZHAO-ST-MOMREV-2026_XTI_S02`

## 1. Strategy Logic

On the first executable tick within 180 minutes of a genuine broker Monday,
require the six immediately preceding completed WTI sessions to be the exact
prior Friday-through-Monday sequence plus its preceding Friday anchor. Read
exactly 206 completed D1 closes. Compute the five close-to-close log returns
of the exact completed week, their total return, and their realized volatility.

Rank current realized volatility against forty immediately older,
non-overlapping five-return blocks. BUY when the inclusive count of older RVs
less than or equal to current RV is at most 13 and the completed weekly return
is positive; SELL under the same rank gate when it is negative. Equality,
invalid history, high RV, or zero return remains flat. The Monday attempt is
persisted before every fallible gate.

## 2. Parameters

- Monday entry grace: 180 minutes from executable session open, measured from
  native or governed uniformly shifted energy labels modulo one day.
- Formation: one exact completed Monday-Friday week plus forty older disjoint
  five-return RV blocks; 206 completed closes in total.
- Rank: inclusive `base_rv <= current_rv`; maximum admitted count 13 of 40.
- Risk stop: completed-bar ATR(20), multiplier 3.0.
- Entry spread ceiling: 1,500 points; modeled zero `.DWX` spread is valid.
- Lifecycle: framework Friday close at broker hour 21, later-week repair, and
  eight-calendar-day final stale guard.
- All parameters are locked; no Q02 sweep or baseline rescue is authorized.

## 3. Symbol Universe

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot 0: `215030000`.
- No paired leg, synthetic symbol, implicit port, or external runtime feed.

## 4. Timeframe

The EA runs only on an `XTIUSD.DWX` D1 chart and evaluates entry on the
framework new-bar edge. The current Monday bar never enters the signal. Native
same-day labels and the single governed `+1`-day energy normalization are
supported uniformly; shifted individual bars and holiday substitutes fail
closed.

## 5. Expected Behaviour

The EA consumes at most one attempt per genuine broker Monday. The card expects
approximately 10-18 completed positions per full post-warm-up year after the
low-volatility and calendar gates; Q02 must retire below five per year.

Q02 must also retire for zero trades, wrong endpoints, overlapping return
intervals, rank or direction errors, invalid risk mode, carry beyond the
governed lifecycle, or nonpositive governed economics. Q09 alone may measure
correlation with the certified book.

## 6. Source Citation

Zhao, S., Ding, Y., Yu, J., and Kang, W. (2026), "Momentum and Reversal on the
Short-Term Horizon: Evidence from Commodity Markets," SSRN 6425598, DOI
`10.2139/ssrn.6425598`.

The source supports short-horizon commodity continuation and stronger momentum
in low-volatility states. It does not test this exact calendar, native-price
proxy, rank estimator, continuous-CFD carrier, or fixed entry/exit package.
Complete bounded evidence and access limits are recorded in
`strategy-seeds/sources/28681f5d-aa78-584e-9698-750d1402e485/source.md`.

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
| v1 | 2026-08-17 | approved build-directory identity | G0 approved |
| v1-build | 2026-08-17 | deterministic implementation, 13 passing reference tests, fixed-risk setfile, strict compile and target build checks | Q01 PASS |
| v1-capacity | 2026-08-17 | fresh capacity gate found eight governed testers and 100% CPU | Q02 not enqueued; hard-ceiling stop |
