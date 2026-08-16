# QM5_41020_wti-wclose-mom

**EA ID:** QM5_41020

**Source strategy:** `MOP-WTI-WCLOSE-MOM-2026_S01`

## 1. Strategy Logic

On the first executable tick, within 180 minutes, of a genuine broker-clock
Monday, require the four immediately preceding completed WTI sessions to be
Friday, Thursday, Wednesday, and Tuesday. Consume the exact broker-date Monday
attempt, then follow the sign of
`log(PriorFridayClose / PriorTuesdayClose)`: BUY positive, SELL negative, and
remain flat on exact zero or invalid history.

The position is a direct WTI structural sleeve held through Monday and Tuesday
and closed on the first genuine Wednesday D1 boundary. Framework Friday close
at broker hour 21 remains an additional fail-safe. Moskowitz, Ooi, and Pedersen
establish the broad own-return-sign continuation family and include WTI in
their futures universe; they do not test this weekly segment or CFD package.
Q02 is a falsification, not a transferred performance or decorrelation claim.

## 2. Parameters

- Monday entry grace: 180 minutes from executable session open. Native
  same-day labels and factory energy prior-date labels use elapsed time modulo
  one day.
- Formation: exact prior Tuesday, Wednesday, Thursday, Friday sequence;
  prior-Tuesday close through prior-Friday close; sign only.
- Risk stop: completed-bar ATR(20), multiplier 3.5.
- Entry spread ceiling: 1,500 points.
- Lifecycle: first-Wednesday D1 exit, Thursday/Friday repair, five-calendar-
  day final stale guard, and framework Friday close at broker hour 21 as a
  fail-safe.
- All parameters are locked; no Q02 sweep or baseline rescue is authorized.

## 3. Symbol Universe

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot 0: `410200000`.
- No paired leg, synthetic symbol, implicit port, or external runtime feed.

## 4. Timeframe

The EA runs only on an `XTIUSD.DWX` D1 chart. It reads exactly four completed
D1 bars behind one framework new-bar edge and rejects missing or shifted
Tuesday/Wednesday/Thursday/Friday sequences. Broker time defines the decision
date. If the factory labels the current energy session 24-48 hours behind
broker time, one uniform +1-day offset normalizes the current and completed
labels before the sequence checks; no other shift or substitution is allowed.
The current Monday bar never enters the signal.

## 5. Expected Behaviour

Before holidays and fail-closed exclusions, the EA consumes at most one
attempt per genuine Monday and expects approximately 45-52 completed positions
per full post-warm-up year. Positions normally remain open through Tuesday and
are flat on Wednesday.

Q02 must retire the strategy below five completed positions per year, for zero
trades, wrong weekday/timing behavior, invalid risk mode, carry past Wednesday,
or governed economic failure. Q09 alone may measure correlation with the
certified book.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Complete-paper evidence and the durable PDF retrieval hash are recorded in
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. The governed weekly
translation is
`strategy-seeds/sources/MOP-WTI-WCLOSE-MOM-2026/source.md`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Lots derive only from the frozen hard-stop distance;
signal magnitude never changes risk. Both news axes are OFF. Friday close is
ON at broker hour 21 only as a fail-safe.

This build has no live/demo/shadow/stress/optimization preset or live
authorization. AutoTrading, `T_Live`, deploy/T_Live manifests, portfolio
admission, portfolio-gate changes, and correlation waivers are outside scope.
