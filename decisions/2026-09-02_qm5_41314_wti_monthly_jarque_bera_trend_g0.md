# QM5_41314 WTI Monthly Jarque-Bera Trend - G0 Decision

Date: 2026-09-02

Decision: `APPROVED` for governed magic allocation, one branch-only non-live
V5 build, strict Q01 validation, and one paced fixed-risk Q02 enqueue if the
whole-host CPU ceiling permits.

Authority: current explicit OWNER commodity/energy sleeve mission on branch
`agents/board-advisor` plus the durable source approval committed as
`de179a4236` at
`decisions/2026-09-02_wti_monthly_jarque_bera_trend_source_approval.md`.

## Bound Identity

- EA: `QM5_41314`
- slug: `wti-mjb-tr`
- strategy ID: `JARQUEBERA-MOP-WTI-OMNIBUS-20260902_S01`
- source ID: `JARQUEBERA-SCIPY-MOP-WTI-OMNIBUS-20260902`
- approved card:
  `strategy-seeds/cards/approved/QM5_41314_wti-mjb-tr_card.md`
- exact symbol/timeframe: `XTIUSD.DWX`, D1, slot zero
- active identity reservation commit: `a23feef4d5`

The identity remains conditional on the governed magic allocator accepting
this exact approved card and producing an active slot-zero registry/resolver
row. A mismatch voids build authorization until corrected through the
allocator; no hand-edited fallback is authorized.

## Gate Findings

- R1 `PASS_WITH_SYNTHESIS_BOUNDARY`: peer-reviewed original attribution,
  complete pinned scientific implementation and test read, and complete
  governed peer-reviewed WTI continuation record. Raw-return gating and the
  exact conjunction remain untested synthesis; no small-sample p-value is
  claimed.
- R2 `PASS`: forty-nine completed month endpoints, forty-eight log returns,
  biased population central moments, skewness, Fisher excess kurtosis, exact
  Jarque-Bera aggregation, inclusive pre-data `1.04` gate, newest twelve-
  month side, consumed attempt, fixed risk, stop, spread, and lifecycle are
  locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 supplies every signal input; roll, basis, financing, gap,
  and broker-month-label risks remain.
- R4 `PASS`: bounded deterministic arithmetic and native MT5/framework state;
  no trained output, banned signal indicator, or external runtime feed.

The source of record, SHA-256
`6C50EFC59F3C036C5107BAB15CCCD4804365595E8CC6F774C2ED1AE5BCFAA3AB`,
was approved and committed before this extraction.

## Duplicate Boundary

The corrected-root receipt, SHA-256
`3185D235BA92BA469C33605D2EE4E102644120100106F9152925CE40E61334CC`,
returned `CLEAN` across 4,799 registered identities, 1,428 cards, and 45
Strategy Wiki nodes.

The statistic jointly squares and aggregates standardized skewness and excess
kurtosis and never takes side from either. It cannot collapse to the
directional WTI skewness premium (`QM5_20290`), directional WTI Pearson-
kurtosis premium (`QM5_20295`), serial-dependence portmanteau
(`QM5_41313`), entropy, rank, pure momentum, or calendar/event/channel
filters. Certified `QM5_12567` remains a long-only two-day XNG oscillator
pullback.

Verdict:
`CLEAN_WTI_MONTHLY_48_RETURN_JARQUE_BERA_JB_GE1P04_GATED_12M_CONTINUATION`.

## Locked Execution Contract

- one consumed attempt at the first executable D1 bar of each genuine broker
  month, within 180 minutes;
- forty-nine consecutive completed month-end closes, no current-month price;
- biased central moments `m2`, `m3`, and `m4`, each divided by 48;
- `skew=m3/m2^1.5`, `excess=m4/m2^2-3`, and
  `JB=48/6*(skew^2+excess^2/4)`;
- inclusive `JB>=1.04`, then newest twelve-return continuation side;
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
