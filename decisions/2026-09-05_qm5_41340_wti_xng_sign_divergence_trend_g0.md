# QM5_41340 WTI/XNG Sign-Divergence Trend — G0 Decision

- Date: 2026-09-05
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED`
- Gate: G0 approval for falsification
- EA ID: `QM5_41340` (atomically reserved)
- Slug: `wti-xng-divtrend`
- Strategy ID: `MOP-EIA-WTI-XNG-SIGN-DIVERGENCE-20260905_S01`

## R1–R4 decision

The current OWNER mission directs a new structural, low-frequency energy edge,
its card and build, and one paced Q02 enqueue. Source approval is recorded in
`decisions/2026-09-05_wti_xng_sign_divergence_trend_source_approval.md`.

- R1 `PASS`: complete peer-reviewed WTI/natural-gas time-series-momentum
  evidence plus complete government and peer-reviewed oil/gas relationship
  evidence.
- R2 `PASS`: synchronized completed history, exact thirteen monthly endpoints
  per series, two exact twelve-month log returns, strict opposite-sign gate,
  WTI direction, consumed month, stop, risk, spread, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: native registered XTI/XNG D1 data;
  XNG has no order authority.
- R4 `PASS`: deterministic native arithmetic only, with no ML, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Identity and implementation decision

The corrected-root deterministic scan returned `CLEAN`; manual review finds
the single-leg sign-divergence carrier distinct from the existing weak-
correlation WTI gate and every two-leg energy spread/rank package. The locked
implementation uses `XTIUSD.DWX` D1 slot zero, magic `413400000`, read-only
`XNGUSD.DWX`, exact twelve-month signs, a 180-minute new-month entry grace,
one consumed attempt, `RISK_FIXED=1000`, frozen `3.5*ATR(20)` stop, 1,500-point
spread ceiling, next-month exit, and forty-day stale repair. News, Friday close,
and stress are off.

This decision grants deterministic allocation, branch-only non-live V5 build,
reference tests, strict compile/Q01, and one paced Q02 enqueue only if CPU
admission is clear. It grants no manual backtest, performance/decorrelation
claim, portfolio waiver or admission, portfolio-gate change, deployment/live
manifest, `T_Live`, AutoTrading, or live use.
