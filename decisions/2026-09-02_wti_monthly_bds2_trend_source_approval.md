# WTI Monthly BDS2 Trend - Source Approval

Date: 2026-09-02

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue is not tester dispatch and remains
subject to the active whole-host CPU ceiling.

Authority: the current explicit OWNER commodity/energy sleeve mission on
branch `agents/board-advisor`. It requests one new structural low-frequency
commodity edge, reputable-source criteria, fixed-risk backtests, committed
non-duplicate work, and Q02 enqueue while excluding live and portfolio-gate
changes.

## Candidate Identity

- proposed slug: `wti-bds2-tr`
- proposed strategy ID: `BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902_S01`
- proposed source ID: `BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902`
- exact host/traded slot zero: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine broker month
- signal: absolute embedding-dimension-two BDS i.i.d.-departure statistic at
  or above `0.6744897501960817` on forty-eight completed monthly WTI log
  returns, followed in the newest twelve-month return direction

The governed allocator owns the numeric EA ID. This record neither predicts
nor hand-allocates it.

## Reviewed Evidence

1. statsmodels `_bds.py`, pinned at commit
   `2d1115dbd648b1e120a7e7454479d46481a73a9a`. The governed router returned
   `ROUTE_GITHUB_API`; the complete file was read through the public GitHub
   contents API. It fixes the sample standard deviation, strict epsilon
   comparison, correlation sums, full-sample `k`, conditioned effect,
   variance, and BDS statistic.
2. statsmodels' complete pinned `test_bds.py`, `bds_data.csv`, and
   `bds_results.csv`, which verify dimensions two through five against
   Kanzler MATLAB reference outputs. These are implementation fixtures only;
   their observations and p-values do not enter the strategy.
3. Broock, Scheinkman, Dechert, and LeBaron (1996), *Econometric Reviews*
   15(3), 197-235, DOI `10.1080/07474939608800353`. Bibliographic attribution
   is bound through the pinned implementation record; no inaccessible body
   claim is used.
4. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves the complete published-paper read, monthly own-return
   continuation, and explicit WTI membership.
5. `strategy-seeds/sources/BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902/source.md`,
   SHA-256
   `AF16FC65A4E3AA9DEF87B3DE9BFBB6DDB04D98373A04A6E093C3EF616E6A87E1`,
   and `retrieval_route_20260902.json`, SHA-256
   `FBB48A41AD7B8D92A41FDB4BFF5427CFC583C42EF147480B0F4F75880587D36E`,
   bind the exact extraction and claim limits.

No source tests the exact raw-return BDS/twelve-month-direction conjunction,
the boundary as a profitable gate, Darwinex CFD equivalence, fixed risk,
costs, lifecycle, activity, or portfolio correlation. No source p-value,
rejection result, return, accuracy, alpha, Sharpe ratio, drawdown, or
decorrelation statistic transfers.

## Locked Mechanic

For forty-eight chronological completed-month log returns, set epsilon to
`1.5` sample standard deviations with `ddof=1`. Construct strict pairwise
distance indicators, the full 48-observation one-dimensional correlation
sum and `k` variance term, the first-observation-conditioned 47-observation
one-dimensional sum, and the adjacent-pair two-dimensional correlation sum.
The exact statsmodels-aligned dimension-two statistic is:

```text
variance2 = 4*(k-C1_full^2)^2
BDS2 = sqrt(47)*(C2-C1_truncated^2)/sqrt(variance2)
```

Require positive finite closes and finite valid arithmetic, with sample
variance, epsilon, and BDS variance floors. Qualify inclusively when
`abs(BDS2)>=0.6744897501960817`; buy when the newest twelve-return sum exceeds
`1e-12`, sell below `-1e-12`, and consume ties, degenerate states,
nonqualifying statistics, or invalid states flat. The BDS gate assigns no side
and makes no chaos, nonlinearity-cause, or predictability claim.

The boundary is the exact standard-normal 75th percentile. Because the source
statistic is asymptotically standard normal under the i.i.d. null, this is a
pre-data symmetric 50% state divider and implies six theoretical qualifying
clocks per twelve months. It is not a significance threshold. The small-
sample and overlapping-window limitations are material and explicit in
`artifacts/qm5_wti_bds2_tr_null_density_20260902.json`, SHA-256
`596589494498C313E9F814B60ADEFCAE70FA73331FEAC2D9A9855E607952780F`;
Q02 owns realized density and economics.

There is one attempt per broker month, persisted before every fallible gate.
Risk is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen `3.5*ATR(20,D1)` hard stop, no target, a
1,500-point spread ceiling, next-month renewal, and forty-day stale exit.
Both news axes, legacy news, Friday close, and stress rejection are OFF.

## Reputable-Source And Duplicate Decision

- R1: `PASS_WITH_SYNTHESIS_BOUNDARY`.
- R2: `PASS` with all arithmetic, clock, risk, and lifecycle rules fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` on registered native WTI D1.
- R4: `PASS`; bounded deterministic arithmetic, no ML or banned signal.

The corrected-root dedup receipt scanned 4,801 registry rows, 1,430 cards,
and 45 Wiki nodes with a `CLEAN` verdict:
`artifacts/qm5_wti_bds2_tr_preallocation_dedup_20260902.json`, SHA-256
`CFC997B7033FE3C36863B8837D47881493965254AF25DD22EB5E6DDE783F3F40`.

The nearest semantic systems remain mechanically distinct:

- `QM5_41313` aggregates squared linear autocorrelations. BDS instead counts
  close delay-vector pairs and can respond to non-linear dependence.
- `QM5_41315` regresses squared returns on squared-return lags. BDS neither
  squares returns nor fits a conditional-variance regression.
- entropy EAs use ordinal patterns, Lempel-Ziv words, template-match counts,
  or Fourier power. BDS uses correlation-integral geometry and its own
  variance normalization.
- `QM5_41314` measures marginal distribution shape and is permutation
  invariant; BDS is explicitly sequence dependent.
- certified `QM5_12567` is a two-day long-only XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_48_RETURN_BDS_EMBED2_ABS_GE_NORMAL_MEDIAN_GATED_12M_CONTINUATION`.

## Kill And Safety Boundary

Retire below five completed positions in any full post-warm-up year, at zero
positions, on nonpositive governed economics, or on any deterministic
contract defect. No result-based change to sample, embedding dimension,
epsilon multiplier, boundary, direction, carrier, stop, hold, spread, or retry
is allowed.

This approval excludes manual backtests; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; and manual terminal
control. If the measured factory ceiling binds, stop without compiling,
enqueuing, or dispatching.
