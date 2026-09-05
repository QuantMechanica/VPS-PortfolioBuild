# QM5_41357 — XTI/XNG Monthly Fixed-Tail Winsorized Reversion

**EA ID:** QM5_41357

**Strategy:** `AI-CODEX-XTIXNG-MWINSOR2-RV-20260906_S01`

**Carrier:** logical basket `QM5_41357_XTI_XNG_MWINSOR2_RV_D1`, hosted on
`XTIUSD.DWX` D1; slot 0 magic `413570000`, slot 1 magic `413570001`

## 1. Strategy Logic

On the first synchronized executable D1 bar of a broker month, collect the
latest common XTIUSD.DWX/XNGUSD.DWX completed close in each of the immediately
prior thirteen consecutive broker months. Form twelve chronological adjacent
log-ratio returns, sort ascending, replace indexes `0,1` by index `2` and indexes `10,11` by
index `9`, then average all twelve capped observations. Fade the sign outside `1e-12`:

- positive Winsorized mean: sell XTI, buy XNG;
- negative Winsorized mean: buy XTI, sell XNG;
- otherwise: consume the month flat.

Open only an equal-target-notional opposed pair. Hold to the next broker month,
and repair after forty elapsed days or any malformed package state.

## 2. Parameters

- 13 synchronized completed month-end ratio endpoints and 12 adjacent returns.
- Ascending sort; cap indexes `0,1` at `2` and `10,11` at `9`; divide the twelve-value sum by 12.
- Sign epsilon `1e-12`; history scan 1,200 D1 bars; freshness 10 days.
- Month-entry grace 180 minutes; one persistent consumed attempt per month.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Per-leg frozen `3.5*ATR(20,D1)` hard stops and no targets.
- Equal target notionals with a 20% live-notional mismatch ceiling.
- XTI/XNG spread caps 1,500/3,000 points; stale repair after 40 days.
- No retry, fallback, trail, scale-in, grid, martingale, or optimization.

## 3. Symbol Universe

Trade exactly registered native `XTIUSD.DWX` in slot zero and `XNGUSD.DWX` in
slot one as one opposed logical basket. XTI is the host only; neither leg may
trade alone or serve as an absolute-direction fallback.

## 4. Timeframe

Attach and test on XTI D1. Decisions occur only on the first synchronized
executable D1 bar of a new broker month and use completed prior-month data.

## 5. Expected Behaviour

Fail closed on missing or nonconsecutive months, unsynchronized endpoints,
nonpositive closes, nonfinite arithmetic, a near-zero Winsorized mean, invalid
quotes/ATR/sizing/margin/stops, foreign exposure, or malformed package state.
Consume the month before fallible entry gates and never retry it. Open or close
the pair atomically where possible; defensive management removes orphan,
duplicate, wrong-side, stopless, or materially mismatched exposure.

## 6. Source Citation

Approved composite `AI-CODEX-XTIXNG-MWINSOR2-RV-20260906`, grounded in
Villar and Joutz (2006), *The Relationship Between Crude Oil and Natural Gas
Prices*, U.S. EIA; Ramberg and Parsons (2012), *The Energy Journal* 33(2),
DOI `10.5547/01956574.33.2.2`; and Moskowitz, Ooi, and Pedersen (2012),
*JFE* 104(2), DOI `10.1016/j.jfineco.2011.11.003`, with governed Winsor
arithmetic. No source validates this exact conjunction, continuous-CFD
transport, profitability, or book decorrelation.

## 7. Risk Model

The sole Q02 baseline divides one aggregate fixed USD 1,000 frozen-stop budget
across the two `3.5*ATR(20,D1)` stops, with percent risk zero and portfolio
weight one. Equal target notionals reduce first-order energy beta but do not
prove market neutrality. Legging, financing, gap, spread, roll/basis,
synchronization, and residual energy-factor risks remain material. Signal
magnitude never changes size, and Q09 alone determines realized correlation.

## Framework Alignment

| Contract | Implementation |
|---|---|
| no-trade and attempt | exact identity/input checks, synchronized monthly clock, persistent consumed-month key |
| entry | synchronized endpoint reconstruction, fixed-tail Winsorization, contrarian side, fixed aggregate risk, equal notionals, atomic two-leg open |
| management | pair integrity, expected side, notional tolerance, original hard stops |
| close | next-month, forty-day stale, malformed-pair, and framework kill-switch closure |

## Validation And Safety

`docs/test_xtixng_mwinsor2_rv_reference.py` independently pins sorting, capped
indexes, sign/reflection, degeneracy, synchronized ratio returns, and the
side-disagreement fixture versus the nearest fixed-trim EA.

This build does not establish profitability or decorrelation. Q02 owns baseline
economics and retires on zero trades, fewer than five completed packages in a
full scored post-warm-up year, nonpositive economics, or contract failure. Q09
alone owns realized book overlap. Portfolio gates, deploy/live manifests,
`T_Live`, AutoTrading, and terminal control remain outside scope.

## Revision

2026-09-06: governed Q01 COMPILE_OK / BUILD_CHECK_PASS on work item
`c67931b2-7fd1-42d0-80b0-4c857739b31f`; one logical basket Q02 work item
`328cdef5-6458-4079-b898-b4220efbd6bb` is ENQUEUED_PENDING after CPU admission.
