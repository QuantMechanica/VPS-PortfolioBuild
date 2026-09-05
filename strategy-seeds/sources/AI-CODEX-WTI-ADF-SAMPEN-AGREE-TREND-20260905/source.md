---
source_id: AI-CODEX-WTI-ADF-SAMPEN-AGREE-TREND-20260905
title: WTI monthly ADF and sample-entropy agreement trend
publisher: QuantMechanica governed synthesis from approved ADF, sample-entropy, and WTI continuation sources
source_type: ai_originated_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-05_wti_monthly_adf_sampen_agreement_trend_source_approval.md
parent_source_ids:
  - AI-CODEX-WTI-MADF-PERSIST-TREND-20260903
  - RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902
  - MOP-TSMOM-2012
created: 2026-09-05
created_by: Research+Development
cards_extracted:
  - wti-adf-sampen-agree-tr
---

# WTI Monthly ADF and Sample-Entropy Agreement Trend

## Authority and bounded read

The current OWNER mission authorizes one new structural, low-frequency
commodity/energy card and non-live build outside the certified
XAU/SP500/NDX/XNG carrier set. This packet imports no new external source. The
complete local evidence chain is pinned in `retrieval_route_20260905.json`:

1. Chan's governed lag-one ADF extraction fixes the intercept/no-time-trend
   regression and inclusive `-2.594` state boundary.
2. Tomcala's completely read peer-reviewed article and the completely pinned
   CRAN implementation fix sample entropy with `m=2`, lag one, radius
   `0.2*sample_sd`, strict Chebyshev matching, and no self matches.
3. Moskowitz, Ooi, and Pedersen's completely read peer-reviewed paper fixes
   monthly own-return continuation and explicitly includes NYMEX WTI.

The sources do not test this exact conjunction, sample alignment, threshold
efficacy, Darwinex continuous CFD, fixed risk, costs, activity, or correlation.

## Locked hypothesis and sample

WTI carries physical production, storage, transport, refining, geopolitical,
producer-hedging, and demand exposure absent from the current index/metal book.
The falsifiable hypothesis is that its newest twelve-month direction is worth
holding for one further broker month only when both a price-level persistence
state and a low return-path-complexity state qualify.

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition, reconstruct exactly 61 consecutive completed month-end closes
`C[0..60]`, oldest to newest, and exclude current-month prices. Set
`x[t]=ln(C[t])` and `r[i]=x[i+1]-x[i]` for `i=0..59`.

## ADF component

Use the newest 60 log levels `x[1..60]`. For local index `j=2..59`, regress
`y=x[j+1]-x[j]` on intercept, `z=x[j]`, and `w=x[j]-x[j-1]` using centered
cross-products. There are 58 observations and 55 residual degrees of freedom.
Require finite positive energy, `det>1e-12*Szz*Sww`, and `SSE>1e-18`.
Compute `adf_t=gamma/se_gamma` and qualify inclusively at `adf_t>=-2.594`.

This boundary is a frozen classifier, not a p-value or a claim that a unit root
has been proved.

## Sample-entropy component

On all 60 returns, compute sample standard deviation with denominator 59 and
radius `tol=0.2*sd`. For dimensions two and three, count unordered distinct
template pairs whose maximum coordinate distance is strictly below `tol`:

```text
B = matching length-two pairs among starts 0..58
A = matching length-three pairs among starts 0..57
SampEn = ln(B/A)
```

Require `sd>1e-12`, `B>=A>0`, and finite nonnegative entropy. Qualify
inclusively at `SampEn<=2.5`. A distance equal to the radius does not match.

## Agreement, side, risk, and lifecycle

```text
mom12 = x[60]-x[48]
BUY  iff adf_t >= -2.594 and SampEn <= 2.5 and mom12 > +1e-12
SELL iff adf_t >= -2.594 and SampEn <= 2.5 and mom12 < -1e-12
FLAT otherwise
```

Only `mom12` chooses side. Persist the month before every fallible gate and
never retry it. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen `3.5*ATR(20,D1)` hard stop, no target,
1,500-point spread ceiling, next-month exit, and 40-day stale repair. News,
Friday close, and stress rejection are off. No external runtime feed, trained
output, target, trail, scale-in, grid, martingale, or pyramid is permitted.

## Reputable-source criteria

- **R1 — PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE.** Complete governed
  book, peer-reviewed method, transparent implementation, and peer-reviewed
  trading-paper records are hash-bound with explicit synthesis boundaries.
- **R2 — PASS.** Clock, 61 endpoints, both complete arithmetic paths,
  boundaries, conjunction, side, attempt, risk, stop, spread, and lifecycle
  are deterministic and locked.
- **R3 — PASS_WITH_CONTINUOUS_CFD_BASIS_RISK.** Registered native WTI D1 and
  MT5 state provide every runtime input.
- **R4 — PASS.** Bounded arithmetic and native V5 execution only; no ML,
  banned signal indicator, external feed, or prohibited position escalation.

## Non-duplicate boundary

The corrected-root receipt
`artifacts/qm5_wti_adf_sampen_agree_tr_preallocation_dedup_20260905.json`
found no exact identity across 4,829 registry rows, 1,442 cards, and 45 Wiki
nodes. Expected fuzzy neighbors are manual-review items: the ADF-only and
sample-entropy-only parents omit one load-bearing gate; ADF-KPSS uses partial
sum/HAC level stationarity; ADF-spectral uses a frequency-energy distribution;
ADF-von-Neumann uses successive-difference dispersion; ADF-LZ76 parses a
twenty-bit sign word. Raw-magnitude overlapping template recurrence is not
interchangeable with any of those states.

The common WTI continuation carrier can still correlate with its neighbors.
Only Q09 may establish useful portfolio fit.

## Kill and safety boundary

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, formula/fixture mismatch,
current-month leakage, invalid fixed risk, missing stop, malformed lifecycle,
nondeterminism, or downstream hard failure. No post-result threshold repair is
authorized.

Authorized: one card, deterministic allocation, branch-only non-live build,
reference tests, strict Q01, one fixed-risk set, and one paced Q02 enqueue
below the CPU ceiling. Forbidden: manual backtests, optimization, live/demo/
shadow/stress sets, terminal control, portfolio-gate edits, admission or
correlation waivers, deploy/live manifests, `T_Live`, AutoTrading, and live use.
