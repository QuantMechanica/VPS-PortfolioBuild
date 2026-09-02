# WTI Monthly ARCH-LM Trend - Source Approval

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

- proposed slug: `wti-archlm-tr`
- proposed strategy ID: `ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902_S01`
- proposed source ID: `ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902`
- exact host/traded slot zero: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine broker month
- signal: six-lag Engle ARCH-LM squared-residual serial-dependence statistic
  at or above `4.73` on sixty completed monthly WTI log returns, followed in
  the newest twelve-month return direction

The governed allocator owns the numeric EA ID. This record neither predicts
nor hand-allocates it.

## Reviewed Evidence

1. statsmodels `het_arch`, `acorr_lm`, and `lagmat`, pinned at commit
   `724510a0f1f1ab0ea79ab31e4bdd56df098f4f58`. The governed router returned
   `ROUTE_GITHUB_API`; the complete bounded functions were read through the
   public GitHub contents API. They fix residual squaring, exact lag
   alignment, intercept-bearing OLS, centered R-squared, and
   `LM=(nobs-ddof)*R2`.
2. statsmodels' pinned ARCH tests, which verify the implementation against R
   `FinTS::ArchTest` to twelve decimal places. These are implementation
   fixtures only; their data and p-values do not enter the strategy.
3. Engle (1982), *Econometrica* 50(4), 987-1007, DOI
   `10.2307/1912773`. Bibliographic attribution only; the generic router
   returned `PERMISSION_REQUIRED` for a third-party PDF mirror, which is
   excluded. No inaccessible body claim is used.
4. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves the complete published-paper read, monthly own-return
   continuation, and explicit WTI membership.
5. `strategy-seeds/sources/ENGLE-STATSMODELS-MOP-WTI-ARCHLM-20260902/source.md`,
   SHA-256
   `910C3D4900A9732810C5A8799F60196F6AF869F29BF4315029FC63F26BBB923C`,
   and `retrieval_route_20260902.json`, SHA-256
   `0CE6C7C615F186567B583FCA9AE4FC6B2F9C26434FF52B6E9EEABC699D631405`,
   bind the exact extraction and claim limits.

No source tests the exact raw-return ARCH-LM/twelve-month-direction
conjunction, the `4.73` boundary as a profitable gate, Darwinex CFD
equivalence, fixed risk, costs, lifecycle, activity, or portfolio
correlation. No source p-value, rejection result, return, accuracy, alpha,
Sharpe ratio, drawdown, or decorrelation statistic transfers.

## Locked Mechanic

For sixty chronological completed-month log returns, subtract their arithmetic
mean and form mean-normalized squared residuals. For observations `t=6..59`,
regress the current normalized square on an intercept and its exact lags one
through six. With 54 regression rows and statsmodels' default `ddof=0` path:

```text
ARCH_LM = 54 * centered_OLS_R_squared
```

The positive common normalization is mathematically R-squared invariant and
is locked for numerical conditioning. Require positive finite closes, finite
intermediate arithmetic, positive residual energy, a full-rank seven-column
normal equation under scaled partial pivoting, and positive centered dependent
sum of squares. Qualify inclusively at `ARCH_LM>=4.73`; buy when the newest
twelve-return sum exceeds `1e-12`, sell below `-1e-12`, and consume ties,
singular regressions, nonqualifying statistics, or invalid states flat. The
squared-residual gate intentionally detects volatility dependence without
assigning side; the independent continuation carrier owns direction.

The boundary is the two-decimal pre-data approximation to the empirical
median `4.734633677704946` from 200,000 independent standard-normal
sixty-observation paths using NumPy 2.4.6 PCG64 seed `20260902`. It is a state
divider, not a significance test. The receipt, SHA-256
`277F824BDAAEEA5900A0C4F831A19AD9127FF765904EA47C4916CBE681E4BF0C`,
qualifies `50.0665%`, or `6.00798` theoretical clocks per twelve months. It is
only a market-free cadence check; Q02 owns actual activity and economics.

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

The corrected-root dedup receipt scanned 4,800 registry rows, 1,429 cards,
and 45 Wiki nodes with a `CLEAN` verdict:
`artifacts/qm5_wti_archlm_tr_preallocation_dedup_20260902.json`, SHA-256
`40BBE77CFD0663E737FD81EDD50284933DAEFDFE5CABF6B5C3586AE251DE682A`.

The nearest semantic systems remain mechanically distinct:

- `QM5_37008` recursively forecasts daily GARCH variance using fixed
  coefficients and trades a cone breakout. This candidate does not forecast
  variance, is monthly, and uses an omnibus squared-residual dependence test
  only as a directionless state gate.
- `QM5_41313` aggregates serial autocorrelations of return levels; ARCH-LM
  regresses squared demeaned returns on their own lags and can fire with zero
  linear return autocorrelation.
- `QM5_41314` measures marginal skew/kurtosis and ignores return order;
  ARCH-LM is explicitly order-dependent and conditional-variance oriented.
- `QM5_20298` measures volatility of volatility. Block-scale, change-point,
  and distribution-shift systems compare samples or marginal blocks rather
  than a six-lag auxiliary regression within one state.
- Certified `QM5_12567` is a two-day long-only XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_60_RETURN_ARCH_LM6_GE4P73_GATED_12M_CONTINUATION`.

## Kill And Safety Boundary

Retire below five completed positions in any full post-warm-up year, at zero
positions, on nonpositive governed economics, or on any deterministic
contract defect. No result-based change to sample, lag count, regression,
boundary, direction, carrier, stop, hold, spread, or retry is allowed.

This approval excludes manual backtests; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; and manual terminal
control. If the measured factory ceiling binds, stop without compiling,
enqueuing, or dispatching.
