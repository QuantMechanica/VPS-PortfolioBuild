---
source_id: AI-CODEX-WTI-MEPPS-SHIFT-20260901
title: WTI monthly Epps-Singleton distribution-shift continuation
publisher: QuantMechanica governed AI synthesis from peer-reviewed WTI and two-sample-method research plus official pinned implementation evidence
source_type: ai_originated_peer_reviewed_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_epps_singleton_shift_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
method_records:
  - EPPS-SINGLETON-1986
  - SCIPY-EPPS-SINGLETON-1.18.0
created: 2026-09-01
created_by: Research+Development
cards_extracted: []
proposed_card: wti-mepps-shift-tr
---

# WTI Monthly Epps-Singleton Distribution-Shift Continuation

## Approval And Complete Read

The durable approval is
`decisions/2026-09-01_wti_monthly_epps_singleton_shift_trend_source_approval.md`.
The current explicit OWNER commodity/energy mission authorizes one reputable-
source, structural low-frequency sleeve and identifies direct WTI trend or
seasonality as eligible. This packet is bounded to one card, one branch build,
strict Q01, and one paced non-live Q02 enqueue.

The complete bounded evidence was read before card extraction:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   which preserves a complete 23-page read of Moskowitz, Ooi, and Pedersen
   (2012), *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, including own-return continuation and
   explicit NYMEX WTI membership; and
2. SciPy 1.18.0 official `scipy.stats.epps_singleton_2samp` documentation plus
   the complete signed-tag-pinned implementation at commit
   `54ef5423f2e4376230ec3bfda6912a07a50958e3`, including sample limits,
   semi-IQR scaling, empirical-characteristic-function features, biased
   covariance, pooled covariance, inverse quadratic form, rank, small-sample
   boundary, and chi-square reference arithmetic used here.

Epps and Singleton (1986), "An Omnibus Test for the Two-Sample Problem Using
the Empirical Characteristic Function," *Journal of Statistical Computation
and Simulation* 26(3-4), 177-203, DOI
`10.1080/00949658608810963`, supplies the named peer-reviewed method record.
Publisher metadata and abstract plus Kenneth Singleton's Stanford bibliography
were read. The paper body was not accessible, so no complete-paper body read,
inaccessible formula, table value, or paper-file hash is claimed. The complete
pinned official SciPy record supplies the exact implementation arithmetic.
Retrieval boundaries and hashes are stored beside this packet.

No external runtime source, inferred result, trained output, or unpublished
performance number enters the hypothesis.

## Sources Of Record And Adverse Evidence

Moskowitz, Ooi, and Pedersen define a broad own-return momentum family on
liquid futures and explicitly include NYMEX WTI. Their pooled commodity result
does not establish a WTI-only effect, a twenty-five-session direction horizon,
an empirical-characteristic-function regime gate, a continuous-CFD
translation, fixed risk, or the QM lifecycle. Their excess returns, rolling
contracts, volatility sizing, costs, and portfolio results do not transfer.

Official SciPy documentation identifies Epps-Singleton as a two-sample test of
the same underlying distribution. Its pinned implementation divides the
default points `(0.4, 0.8)` by the pooled semi-interquartile range; forms
cosine features followed by sine features; estimates biased feature
covariances within each sample; pools them as `n/nx*cov_x+n/ny*cov_y`; and
forms `n*difference' * pseudoinverse(covariance) * difference`. The reference
distribution is chi-square with inverse-matrix rank degrees of freedom.

This EA uses exactly twenty-five observations per block, so the documented
small-sample correction is not active. It requires a full-rank four-feature
covariance and uses a direct inverse; a singular or ill-conditioned package
fails closed instead of attempting a pseudoinverse. For a full-rank statistic,
the fixed threshold `3.356693980033321` is the chi-square-four median, obtained
from `exp(-w/2)*(1+w/2)=0.5`. This is a disclosed activity-preserving QM gate,
not a conventional significance threshold and not an Epps, Singleton, SciPy,
or WTI result.

## Source Claim Boundary

The sources jointly motivate one bounded question: when the latest twenty-
five completed WTI daily returns differ sufficiently in empirical
characteristic-function space from the preceding twenty-five, does the recent
twenty-five-session WTI return direction continue for one broker month?

No source tests this conjunction. Fifty-one completed D1 closes, adjacent log
returns, fixed twenty-five/twenty-five membership, full-rank inverse, median
gate, recent-return side, monthly attempt, continuous-CFD mapping, fixed-dollar
risk, stop, spread, and lifecycle are pre-result QM choices.

No return, alpha, probability, trade count, profit factor, drawdown, cost,
significance, CFD equivalence, independence, decorrelation, or portfolio
statistic transfers from a source.

## Exact Statistical Contract

At a broker-month transition, reconstruct fifty-one positive, finite,
strictly chronological completed `XTIUSD.DWX` D1 closes `C[0..50]`, oldest to
newest. The current D1 bar is excluded and the newest completed label may be
no more than four calendar days stale.

Form fifty chronological adjacent log returns:

```text
r[i] = log(C[i+1]/C[i]), i=0..49
old = r[0..24]
recent = r[25..49]
```

Sort a pooled copy of all fifty returns. Use NumPy/SciPy default linear
percentiles for a fifty-value sample:

```text
q25 = sorted[12] + 0.25*(sorted[13]-sorted[12])
q75 = sorted[36] + 0.75*(sorted[37]-sorted[36])
sigma = (q75-q25)/2
t1 = 0.4/sigma
t2 = 0.8/sigma
```

Require finite positive `sigma`, finite positive `t1,t2`, and `t1<t2`. For
each return `x`, form the four-vector:

```text
g(x) = [cos(t1*x), cos(t2*x), sin(t1*x), sin(t2*x)]
```

For each fixed block compute its four feature means and biased covariance
`cov=(1/25)*sum((g-mean)*(g-mean)')`. Then:

```text
est_cov = 2*cov_old + 2*cov_recent
delta = mean_old - mean_recent
W = 50 * delta' * inverse(est_cov) * delta
```

Invert the symmetric 4x4 matrix by deterministic scaled partial-pivot
Gauss-Jordan elimination. Require every pivot greater than
`1e-12*max(1,max_abs_matrix_element)`, finite inverse entries, residual
`max_abs(est_cov*inverse-I)<=1e-8`, and a finite statistic. Values in
`[-1e-10,0)` caused only by roundoff clamp to zero; a lower statistic fails.
This full-rank path equals the source pseudoinverse path when the covariance is
invertible; rank-deficient packages consume flat.

Qualify iff `W>=3.356693980033321`. No CDF, adaptive critical value,
optimizer, statistic-magnitude sizing, or probability enters the EA. Compute
`recent_return=sum(r[25..49])`; buy above `1e-12`, sell below `-1e-12`, and
consume flat otherwise.

## Pre-Result Activity And Duplicate Boundary

Under the full-rank asymptotic chi-square-four reference, a median threshold
qualifies half of null-state observations, giving a rough six-attempt-per-year
prior before overlap, dependence, direction neutrality, data, and execution
gates. This is not a WTI frequency or performance result. Q02 must retire the
candidate below five completed positions in any full post-warm-up year.

The corrected-root receipt
`artifacts/qm5_wti_mepps_shift_tr_preallocation_dedup_20260901.json`, SHA-256
`239D9D85B296F529E01D092031C1457E92E263259B2CEC5879577B5FC460CF69`,
returned CLEAN across 4,767 registry rows, 1,404 cards, and 45 Wiki nodes.

Manual family review separates the mechanic from its nearest WTI shift gates:

- `QM5_41255` uses an empirical-CDF Cramer-von Mises distance on monthly
  returns, not characteristic-function feature means and covariance.
- `QM5_41258` uses pairwise Euclidean energy distance on monthly returns,
  with no trigonometric features or covariance normalization.
- `QM5_41259` uses sorted-quantile Wasserstein distance on monthly returns.
- `QM5_41262` uses one completed month's raw close mean-location and forms no
  two-sample return distribution.
- `QM5_41267` uses pooled squared ranks of twelve monthly returns to classify
  relative scale, with no empirical characteristic function.

This card alone uses fifty completed daily returns, source-default Fourier
points scaled by pooled semi-IQR, four feature covariances, a full-rank
quadratic form, and a chi-square-four median gate. Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_25_BY_25_DAILY_RETURN_EPPS_SINGLETON_ECF_DISTRIBUTION_SHIFT_MEDIAN_GATE_RECENT_RETURN_CONTINUATION`.

## Mechanical Execution Contract

- Exact host/traded symbol `XTIUSD.DWX`, exact `PERIOD_D1`, slot 0, registered
  magic, and one consumed attempt per normalized broker month.
- Persist the month marker before history, signal, spread, quote, ATR, sizing,
  margin, or order checks. No outcome retry is permitted in that month.
- Backtest risk is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Use one completed-bar `ATR(20,D1)` frozen at entry and a broker hard stop at
  `3.5*ATR`; no target.
- Reject spread above 1,500 points; use deviation 20 points.
- Exit on the first processed tick in a later normalized broker month or
  after forty calendar days as stale repair.
- Repair duplicate, wrong-symbol, wrong-magic, wrong-side, or stopless owned
  exposure before entry-only gates.
- Both news axes, legacy news mode, and Friday close are OFF.
- No target, trail, break-even, partial close, intramonth flip, scale-in,
  pyramid, grid, martingale, external feed, file read, randomization, trained
  output, optimization, or portfolio-state input is authorized.

## Falsification And Safety Boundary

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, failed SciPy/fixture parity, nonpositive governed economics,
or any downstream gate failure. A change to symbol, cadence, close/return
count, block membership, percentile convention, Fourier points, covariance,
inverse guard, statistic threshold, direction, attempt timing, risk, stop,
spread, or lifecycle requires a new EA identity and full pipeline
requalification.

This source authorizes only one Strategy Card. After G0 it may authorize one
branch build, deterministic reference tests, strict Q01, one D1 `RISK_FIXED`
backtest setfile, and one paced non-live Q02 handoff if the CPU ceiling
permits. It does not authorize a manual tester run, optimization,
live/demo/shadow/stress setfile, AutoTrading, `T_Live`, deploy/live manifest,
portfolio-gate mutation, portfolio admission, or correlation waiver.

