# WTI Monthly KPSS Trend - Source Approval

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

- proposed slug: `wti-mkpss-tr`
- proposed strategy ID:
  `KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902_S01`
- proposed source ID: `KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902`
- exact host/traded slot zero: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine broker month
- signal: constant-only KPSS statistic on sixty completed monthly WTI
  log-price levels with four fixed Bartlett/Newey-West covariance lags;
  qualify at the inclusive 10% critical value `0.347`, then trade in the
  newest twelve-month cumulative log-return direction

The governed allocator owns the numeric EA ID. This record neither predicts
nor hand-allocates it.

## Reviewed Evidence

1. statsmodels `statsmodels/tsa/stattools/_stattools.py`, pinned at commit
   `2d1115dbd648b1e120a7e7454479d46481a73a9a`. The governed router returned
   `ROUTE_GITHUB_API`; the complete bounded `kpss`, `_sigma_est_kpss`, and
   `_kpss_autolag` definitions and documentation were read through the public
   GitHub contents API. They fix the null, mean/trend residuals, partial-sum
   statistic, Bartlett/Newey-West long-run variance, integer-lag contract,
   critical values, and p-value boundary.
2. statsmodels' complete pinned `test_stattools.py`, whose `TestKPSS` section
   checks fixed-lag constant/trend statistics against R/tseries values and
   covers lag/failure behavior. It is implementation evidence only; no
   macrodata value or result enters the strategy.
3. Kwiatkowski, Phillips, Schmidt, and Shin (1992), *Journal of Econometrics*
   54, 159-178, DOI `10.1016/0304-4076(92)90104-Y`. Original attribution,
   equations, null, and Table-1 critical-value identity are bound through the
   pinned implementation; no inaccessible publisher-body claim is used.
4. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves the complete published-paper read, monthly own-return
   continuation, and explicit WTI membership.
5. `strategy-seeds/sources/KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902/source.md`,
   SHA-256
   `484F927088FCA0A01E4332B289A6A195A29152FDDE3BF08D7FD47CD8D86BEAD9`,
   and `retrieval_route_20260902.json`, SHA-256
   `CBABE38A7AEE263C417A55692697C1A8FD5D35D6D50A99482D073A948E89D42D`,
   bind the exact extraction and claim limits.

No source tests the exact log-level KPSS/twelve-month-direction conjunction,
the selected sample and lag, the critical value as a profitable gate,
Darwinex CFD equivalence, fixed risk, costs, lifecycle, activity, or portfolio
correlation. No published p-value, return, accuracy, alpha, Sharpe ratio,
drawdown, or decorrelation statistic transfers.

## Locked Mechanic

For sixty chronological completed-month positive closes, take natural logs,
subtract their arithmetic mean, and form all sixty cumulative residual sums.
Set `eta` to the sum of their squares divided by `60^2`. Set the long-run
variance to the residual sum of squares plus twice the lag-one-through-lag-four
residual cross-products weighted `0.8`, `0.6`, `0.4`, and `0.2`, divided by
60. The KPSS statistic is `eta/s_hat`.

Require positive finite closes, finite valid arithmetic, residual energy above
`1e-18`, nonnegative `eta`, and long-run variance above `1e-18`. Qualify
inclusively when `KPSS>=0.347`; buy when `ln(C[59]/C[47])>1e-12`, sell below
`-1e-12`, and consume ties, invalid states, or nonqualifying statistics flat.
This rejects the level-stationarity null only under the locked source boundary;
it does not prove a unit root, trend, predictability, or profit.

The deterministic arithmetic receipt
`artifacts/qm5_wti_mkpss_tr_reference_fixture_20260902.json`, SHA-256
`F8A08B4B4777676EAA59D173F0579CC38D4C131BB7781C1AF4F2042F3EDF9411`,
pins one nonqualifying oscillatory path and one qualifying trending path. It
contains no market data and supplies no frequency or performance prior.

There is one attempt per broker month, persisted before every fallible gate.
Risk is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen `3.5*ATR(20,D1)` hard stop, no target, a
1,500-point spread ceiling, next-month renewal, and forty-day stale exit. Both
news axes, legacy news, Friday close, and stress rejection are OFF.

## Reputable-Source And Duplicate Decision

- R1: `PASS_WITH_SYNTHESIS_BOUNDARY`.
- R2: `PASS` with all arithmetic, clock, risk, and lifecycle rules fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` on registered native WTI D1.
- R4: `PASS`; bounded deterministic arithmetic, no ML or banned signal.

The corrected-root dedup receipt scanned 4,802 registry rows, 1,431 cards, and
45 Wiki nodes with a `CLEAN` verdict:
`artifacts/qm5_wti_mkpss_tr_preallocation_dedup_20260902.json`, SHA-256
`1DF4B584404A2CA3DE33B7D4812119DE7CB74248774FEFDD6A8AEB88D564AD69`.

The nearest semantic systems remain mechanically distinct:

- `QM5_41313` uses squared autocorrelations of returns; KPSS uses cumulative
  demeaned log-price-level residuals and a long-run-variance denominator.
- `QM5_41315` uses a squared-return auxiliary regression; KPSS has neither
  squared returns nor a conditional-variance regression.
- `QM5_41316` uses BDS delay-vector pair geometry; KPSS has no pair distance,
  embedding dimension, epsilon, or BDS variance.
- entropy, marginal-shape, robust-block-shift, variance-ratio, calendar,
  event, channel, and pure-momentum systems use different state objects.
- certified `QM5_12567` is a two-day long-only XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_60_LOG_LEVEL_KPSS_C_LAG4_GE_0P347_GATED_12M_CONTINUATION`.

## Capacity And Safety Boundary

The admission sample completed at `2026-09-02T20:48:27.926Z`: `83%`, `95%`,
`89%`, `79%`, and `73%`, average `83.8%`, maximum `95%`. Both measures were
strictly below the binding 97% stop line, so research intake was admitted.
A fresh capacity sample is still required before compile or Q02 mutation.

Retire below five completed positions in any full post-warm-up year, at zero
positions, on nonpositive governed economics, or on any deterministic contract
defect. No result-based change to sample, lag, boundary, direction, carrier,
stop, hold, spread, or retry is allowed.

This approval excludes manual backtests; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; and manual terminal
control. If a fresh measured factory ceiling binds, stop without compiling,
enqueuing, or dispatching.
