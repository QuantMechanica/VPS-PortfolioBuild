---
source_id: BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902
title: WTI monthly BDS nonlinear-dependence-gated trend
publisher: QuantMechanica governed synthesis from peer-reviewed and pinned scientific-computing records
source_type: ai_originated_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-02_wti_monthly_bds2_trend_source_approval.md
created: 2026-09-02
created_by: Research+Development
parent_source_ids:
  - MOP-TSMOM-2012
cards_extracted:
  - wti-bds2-tr
---

# WTI Monthly BDS Nonlinear-Dependence-Gated Trend

## Sources Of Record And Retrieval Boundary

The executable method record is the statsmodels project's complete pinned
`statsmodels/tsa/_bds.py` at commit
`2d1115dbd648b1e120a7e7454479d46481a73a9a`. The governed source router
returned `ROUTE_GITHUB_API`; the file and its complete upstream test plus both
test-data fixtures were retrieved through the public GitHub contents API and
read. The implementation source SHA-256 is
`5AF0914E7847241883EF2A689A87310643F40918E7DE86345FA297692C4F559F`.

The pinned implementation defines pairwise indicators with a strict distance
comparison and, when epsilon is omitted, uses `1.5` times sample standard
deviation (`ddof=1`). It recursively forms correlation sums, computes the
full-sample BDS variance term, conditions the one-dimensional correlation sum
on the first `m-1` observations, and returns a statistic asymptotically
standard normal under the i.i.d. null. This card locks embedding dimension
`m=2`; no library p-value enters the strategy.

Original peer-reviewed attribution is William A. Broock, Jose A. Scheinkman,
W. Davis Dechert, and Blake LeBaron (1996), "A Test for Independence Based on
the Correlation Dimension," *Econometric Reviews* 15(3), 197-235, DOI
`10.1080/07474939608800353`. The citation and method identity are preserved by
the pinned statsmodels source. Generic publisher retrieval is not used; no
claim depends on inaccessible paper body text.

The directional carrier is Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The existing complete-paper record at
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
preserves monthly own-return continuation and explicit NYMEX WTI membership.

No source tests the BDS/WTI-trend conjunction, forty-eight monthly returns,
embedding dimension two, the median-absolute-normal state boundary, a
Darwinex continuous CFD, fixed risk, costs, lifecycle, activity, or portfolio
correlation. Every conjunction and execution choice below is a transparent
pre-result QuantMechanica hypothesis.

## Exact Mechanic

On the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition, reconstruct exactly forty-nine consecutive completed broker-
month-end closes `C[0]..C[48]`, oldest to newest. Exclude current-month prices
and form forty-eight chronological adjacent log returns `r[0]..r[47]`.

Let `n=48`, let `s` be the sample standard deviation of all returns with
`ddof=1`, set `epsilon=1.5*s`, and define the complete symmetric indicator
matrix, including its unit diagonal:

```text
I[a,b] = 1 iff abs(r[a]-r[b]) < epsilon, else 0

C1 = mean(I[a,b] for 0 <= a < b < 48)
row[a] = sum(I[a,b] for b=0..47)
S = sum(I[a,b] for a,b=0..47)
k = (sum(row[a]^2)-3*S+2*n)/(n*(n-1)*(n-2))

C1_truncated = mean(I[a,b] for 1 <= a < b < 48)
J[a,b] = I[a,b] * I[a+1,b+1], 0 <= a,b < 47
C2 = mean(J[a,b] for 0 <= a < b < 47)

variance2 = 4*(k-C1^2)^2
BDS2 = sqrt(47)*(C2-C1_truncated^2)/sqrt(variance2)
mom12 = sum(r[i], i=36..47)

BUY  iff abs(BDS2) >= 0.6744897501960817 and mom12 > +1e-12
SELL iff abs(BDS2) >= 0.6744897501960817 and mom12 < -1e-12
FLAT otherwise
```

Each written `mean` is the ordinary upper-triangle pair average. The stable
`4*(k-C1^2)^2` variance expression is the exact embedding-dimension-two
simplification of statsmodels' general BDS variance formula. Require positive
finite closes; finite returns, mean, variance, epsilon, correlation sums,
`k`, effect, and statistic; sample variance above `1e-18`; epsilon above
`1e-12`; and BDS variance above `1e-18`. A degenerate or invalid state consumes
the month flat.

The gate is directionless: it measures departure from i.i.d. structure and
does not distinguish linear, nonlinear, stochastic, deterministic, trend, or
reversion dependence. Only the independently sourced newest twelve-month
return supplies side. Neither statistic sign nor magnitude changes risk.

The inclusive absolute boundary `0.6744897501960817` is the 75th percentile
of a standard normal distribution. Under the source's asymptotic i.i.d. null,
half of observations lie outside the symmetric interval bounded by that
value, yielding a theoretical six qualifying clocks per twelve months. It is
a pre-data cadence divider, not a significance threshold, p-value, WTI
calibration, or profitability claim. At only forty-eight observations the
asymptotic approximation can be materially distorted; Q02 owns realized
activity. The receipt is `artifacts/qm5_wti_bds2_tr_null_density_20260902.json`.

## Entry, Risk, And Lifecycle

Persist the normalized broker month as attempted before history, signal,
news, spread, quote, ATR, sizing, margin, or order gates. Never retry a
consumed month. Permit no foreign WTI exposure and no second owned position.

The only Q02 preset uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A qualifying month opens one market position with a
frozen completed-D1 `3.5*ATR(20)` broker hard stop, no target, and a finite
inclusive 1,500-point spread ceiling. Both news axes, legacy news, Friday
close, and stress rejection are OFF.

Close on the first processed tick in a later normalized broker month or after
forty elapsed calendar days. Missing or inconsistent symbol, ownership, side,
stop, entry time, or persisted entry-month state causes defensive strategy
closure. There is no intramonth flip, statistic exit, target, trail,
break-even move, partial close, retry, scale-in, grid, martingale, or pyramid.

## Reputable-Source Criteria

- R1: `PASS_WITH_SYNTHESIS_BOUNDARY`. Peer-reviewed original attribution,
  complete pinned statsmodels implementation, complete upstream verification
  fixtures, and a governed complete peer-reviewed WTI continuation paper are
  preserved. The exact conjunction is explicitly untested.
- R2: `PASS`. Clock, endpoints, sample standard deviation, epsilon, strict
  pair comparison, both correlation sums, full-sample `k`, BDS variance,
  conditioned effect, pre-data boundary, direction, attempt, risk, hard stop,
  spread, and lifecycle are fixed before market testing.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered native WTI D1 data
  supplies all runtime inputs, while roll, basis, financing, gap, and broker-
  month-label risks remain.
- R4: `PASS`. Only bounded deterministic price/calendar arithmetic and native
  V5 execution state are used; no trained output, prohibited signal
  indicator, external runtime feed, grid, or martingale is authorized.

## Duplicate Boundary

The corrected-root deterministic scan found no exact or fuzzy identity across
4,801 registry rows, 1,430 cards, and 45 Strategy Wiki nodes. The receipt is
`artifacts/qm5_wti_bds2_tr_preallocation_dedup_20260902.json`.

- `QM5_41313` is a six-lag sum of squared linear autocorrelations. BDS uses
  strict pairwise closeness of delay vectors and can detect dependence not
  represented by ordinary autocorrelation.
- `QM5_41315` regresses squared demeaned returns on six squared-return lags.
  BDS neither squares returns nor fits a conditional-variance regression.
- `QM5_41309`, `QM5_41311`, and `QM5_41312` are Lempel-Ziv, sample-entropy,
  and spectral-entropy state gates. BDS uses correlation-integral geometry and
  its source variance normalization, not symbol counts, template matches, or
  frequency-domain entropy.
- `QM5_41314` is permutation-invariant marginal skew/kurtosis shape; BDS is
  explicitly sequence dependent. Variance-ratio, robust-location, calendar,
  event, and channel families operate on different state objects.
- Certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_48_RETURN_BDS_EMBED2_ABS_GE_NORMAL_MEDIAN_GATED_12M_CONTINUATION`.

## Validation And Kill Boundary

Reference fixtures must match pinned statsmodels for independent vectors and
prove strict epsilon comparison, `ddof=1`, full-versus-truncated correlation
sums, joint delay-vector orientation, full-sample `k`, dimension-two variance,
inclusive absolute boundary, sign-independent gating, endpoint ordering,
degenerate failure, attempt-before-fallible-gate semantics, fixed risk, and
next-month closure.

Retire below five completed positions in any full post-warm-up year, at zero
positions, on nonpositive governed economics, nondeterminism, or any formula,
attempt, fixed-risk, hard-stop, or lifecycle defect. No result-based change to
sample, embedding dimension, epsilon multiplier, boundary, direction, stop,
hold, spread, or retry is allowed.

This approval excludes manual backtests; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; and manual terminal
control. Q09 alone may establish or reject realized decorrelation.
