# QM5_41315 WTI Monthly ARCH-LM Trend - G0 Decision

Date: 2026-09-02

Decision: `APPROVED` for governed magic allocation, one branch-only non-live
V5 build, strict Q01 validation, and one paced fixed-risk Q02 enqueue if the
whole-host CPU ceiling permits.

Authority: current explicit OWNER commodity/energy sleeve mission on branch
`agents/board-advisor` plus the durable source approval committed as
`a122eb2029` at
`decisions/2026-09-02_wti_monthly_arch_lm_trend_source_approval.md`.

## Bound Identity

- EA: `QM5_41315`
- slug: `wti-archlm-tr`
- strategy ID: `ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902_S01`
- source ID: `ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902`
- approved card:
  `strategy-seeds/cards/approved/QM5_41315_wti-archlm-tr_card.md`
- exact symbol/timeframe: `XTIUSD.DWX`, D1, slot zero
- active identity reservation commit: `6249ea2807`

The identity remains conditional on the governed magic allocator accepting
this exact approved card and producing an active slot-zero registry/resolver
row. A mismatch voids build authorization until corrected through the
allocator; no hand-edited fallback is authorized.

## Gate Findings

- R1 `PASS_WITH_SYNTHESIS_BOUNDARY`: peer-reviewed original attribution,
  complete pinned scientific implementation/lag alignment/test read, and
  complete governed peer-reviewed WTI continuation record. Raw-return gating
  and the exact conjunction remain untested synthesis; no small-sample p-value
  is claimed.
- R2 `PASS`: sixty-one completed month endpoints, sixty log returns,
  arithmetic-mean residuals, common positive squared-residual normalization,
  exact six-lag intercept OLS, centered R-squared, `ARCH_LM=54*R2`, inclusive
  pre-data `4.73` gate, newest twelve-month side, consumed attempt, fixed
  risk, stop, spread, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 supplies every signal input; roll, basis, financing, gap,
  and broker-month-label risks remain.
- R4 `PASS`: bounded deterministic arithmetic and native MT5/framework state;
  no trained output, banned signal indicator, or external runtime feed.

The source of record, SHA-256
`910C3D4900A9732810C5A8799F60196F6AF869F29BF4315029FC63F26BBB923C`,
was approved and committed before this extraction.

## Duplicate Boundary

The corrected-root receipt, SHA-256
`40BBE77CFD0663E737FD81EDD50284933DAEFDFE5CABF6B5C3586AE251DE682A`,
returned `CLEAN` across 4,800 registered identities, 1,429 cards, and 45
Strategy Wiki nodes.

This mechanic cannot collapse to the fixed-coefficient daily GARCH forecast
and cone breakout (`QM5_37008`), the return-level Ljung-Box portmanteau
(`QM5_41313`), marginal Jarque-Bera shape (`QM5_41314`), volatility-of-
volatility (`QM5_20298`), block-scale/change-point families, pure momentum,
or calendar/event/channel filters. Certified `QM5_12567` remains a long-only
two-day XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_60_RETURN_ARCH_LM6_GE4P73_GATED_12M_CONTINUATION`.

## Locked Execution Contract

- one consumed attempt at the first executable D1 bar of each genuine broker
  month, within 180 minutes;
- sixty-one consecutive completed month-end closes, no current-month price;
- sixty arithmetic-mean residuals and positive common square normalization;
- current auxiliary rows `t=6..59`, intercept plus exact lags one through six,
  ordinary centered OLS R-squared, default `ddof=0`;
- inclusive `ARCH_LM=54*R2>=4.73`, then newest twelve-return continuation side;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`;
- frozen `3.5*ATR(20,D1)` hard stop, no target, one position, 1,500-point
  spread ceiling;
- next-month exit plus forty-calendar-day stale repair;
- both news axes, legacy news, Friday close, and stress rejection OFF; and
- no parameter sweep or result-based rescue.

## Kill And Safety Boundary

Retire below five completed positions in any full scored post-warm-up year,
at zero positions, on nonpositive governed economics, nondeterminism, or any
formula, risk, stop, attempt, or lifecycle defect.

This decision authorizes no manual tester run, optimization, live/demo/shadow
or stress preset, portfolio-gate edit, portfolio admission, correlation
waiver, deployment, live manifest, `T_Live`, AutoTrading, terminal control,
or live use. Q09 alone owns realized portfolio correlation.
