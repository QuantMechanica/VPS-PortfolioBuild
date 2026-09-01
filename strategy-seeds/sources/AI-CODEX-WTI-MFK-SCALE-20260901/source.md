---
source_id: AI-CODEX-WTI-MFK-SCALE-20260901
title: WTI monthly Fligner-Killeen scale-expansion continuation
publisher: QuantMechanica governed AI synthesis from peer-reviewed WTI and scale-method research plus official pinned implementation evidence
source_type: ai_originated_peer_reviewed_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_fligner_killeen_scale_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
method_records:
  - FLIGNER-KILLEEN-1976
  - SCIPY-FLIGNER-1.18.0
created: 2026-09-01
created_by: Research+Development
cards_extracted: []
---

# WTI Monthly Fligner-Killeen Scale-Expansion Continuation

## Approval And Complete Read

The durable approval is
`decisions/2026-09-01_wti_monthly_fligner_killeen_scale_trend_source_approval.md`.
The current explicit OWNER commodity/energy mission authorizes one reputable-
source, structural low-frequency sleeve and identifies direct WTI trend or
seasonality as eligible. This packet is bounded to one card, one branch build,
strict Q01, and one paced non-live Q02 enqueue.

The complete bounded evidence was read before card extraction:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   which preserves a complete 23-page read of Moskowitz, Ooi, and Pedersen
   (2012), *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, including monthly own-return continuation
   and explicit NYMEX WTI membership; and
2. SciPy 1.18.0 official `scipy.stats.fligner` documentation plus the signed-
   tag-pinned implementation at commit
   `54ef5423f2e4376230ec3bfda6912a07a50958e3`, including the complete median
   centering, absolute-deviation, pooled-midrank, normal-score, and statistic
   arithmetic.

Fligner and Killeen (1976), "Distribution-Free Two-Sample Tests for Scale,"
*Journal of the American Statistical Association* 71(353), 210-213, DOI
`10.1080/01621459.1976.10481517`, supplies the named peer-reviewed method
record. Publisher metadata and abstract were read through the indexed
publisher page. Direct scripted retrieval returned HTTP 403, so no complete-
paper read, inaccessible derivation, or paper-file hash is claimed. The
official pinned SciPy record supplies the complete arithmetic used here.
Exact access boundaries and response hashes are stored beside this packet.

No external runtime source, inferred result, trained output, or unpublished
performance number enters the hypothesis.

## Sources Of Record And Adverse Evidence

Moskowitz, Ooi, and Pedersen define a broad monthly time-series-momentum
family on liquid futures and explicitly include NYMEX WTI. Their pooled
commodity result does not establish a WTI-only effect, this six-month
direction horizon, a scale-regime gate, a continuous-CFD translation, fixed
risk, or the QM lifecycle. The paper's excess returns, rolling contracts,
volatility sizing, costs, and portfolio results do not transfer.

Fligner and Killeen identify a distribution-free two-sample scale-test class
when populations are identical. Official SciPy documentation describes the
test as robust to non-normality and defaults to group medians. Its pinned
implementation centers each group, takes absolute deviations, pools and
midranks them, maps the ranks to positive normal scores, then measures
between-group score dispersion relative to pooled score variance.

This EA uses no chi-square critical value or p-value. It uses the recent-
minus-old normal-score mean to orient the scale state and computes the exact
statistic only as a finite, nondegenerate arithmetic guard. That directional
translation is a disclosed QM choice, not a source-reported statistical test
or trading result.

## Source Claim Boundary

The sources jointly motivate one bounded question: when median-centered
dispersion in the latest six completed WTI monthly returns occupies higher
pooled normal-score ranks than the preceding six, does the recent WTI return
direction continue for one broker month?

No source tests this conjunction. Thirteen completed endpoints, adjacent log
returns, fixed six/six membership, even medians, relative tie handling,
recent-only score direction, six-month cumulative-return side, continuous-CFD
mapping, fixed-dollar risk, stops, spread cap, consumed attempt, and lifecycle
are pre-result QM choices.

No return, alpha, probability, trade count, profit factor, drawdown, cost,
significance, CFD equivalence, independence, decorrelation, or portfolio
statistic transfers from a source.

## Exact Statistical Contract

At a broker-month transition, reconstruct thirteen positive, finite,
consecutive completed-month `XTIUSD.DWX` closes `C[0..12]`, oldest to newest:

```text
r[i] = ln(C[i+1] / C[i]), i=0..11
old    = r[0..5]
recent = r[6..11]

median6(x) = (sort(x)[2] + sort(x)[3]) / 2
m_old      = median6(old)
m_recent   = median6(recent)

z[i]   = abs(old[i]    - m_old),    i=0..5
z[i+6] = abs(recent[i] - m_recent), i=0..5

For each z[i], assign an ascending pooled midrank R[i] in [1,12].
Values equal within relative tolerance
1e-12*max(1,abs(z[i]),abs(z[j])) share the average occupied rank.

a[i] = Phi^-1(0.5 + R[i] / (2*(12+1)))
A_old    = sum(a[0..5]) / 6
A_recent = sum(a[6..11]) / 6
A_all    = sum(a[0..11]) / 12
s2       = sum((a[i]-A_all)^2, i=0..11) / 11

require s2 > 1e-18
X2 = 6*((A_old-A_all)^2 + (A_recent-A_all)^2) / s2
require finite X2

scale_tol = 1e-12*max(1,abs(A_old),abs(A_recent))
require A_recent > A_old + scale_tol

recent_return = sum(r[6..11])
BUY  iff recent_return >  1e-12
SELL iff recent_return < -1e-12
FLAT otherwise
```

The normal-score map is locked for every integer or half-integer midrank from
1 through 12 using the exact SciPy formula. The EA stores these 23 constants
and performs no runtime approximation, lookup file, library import, fit, or
optimization. All closes, logarithms, returns, medians, deviations, ranks,
scores, means, variance, statistic, and comparisons must be finite.

There is no chi-square lookup, p-value, theoretical significance boundary,
randomized permutation, searched split, fallback center, current-month price,
or signal-magnitude sizing. `X2` is logged and guarded but does not determine
position size or add a strength threshold.

## Pre-Result Density Boundary

For any fixed pooled score vector, swapping equal old/recent labels swaps the
two group means. Exhaustive enumeration of the 924 ways to allocate six of
twelve distinct ranks places the recent mean above the older mean in exactly
462 assignments and below it in 462, with no ties for the locked normal-score
constants. That produces an approximately six-per-year market-free prior
before deviation ties, neutral recent return, history, spread, and execution
gates.

This is label arithmetic, not a market distribution, trade-count result, or
claim that adjacent time blocks are exchangeable. Q02 must retire the card
below five completed positions in every full post-warm-up year.

## Locked Trading Translation

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition:

1. Normalize and persist current broker `yyyymm` before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry the
   month.
2. Exclude every current-month price. Select the latest close in each of the
   thirteen immediately prior consecutive broker months. Reject missing,
   duplicate, nonchronological, nonpositive, nonfinite, or stale endpoints.
3. Form twelve adjacent log returns and preserve fixed old/recent membership.
   Sort copies only for the two even medians.
4. Form group-median absolute deviations, assign pooled relative-tolerance
   midranks, map the 23 locked normal scores, and compute both score means,
   pooled variance, and exact two-group statistic.
5. Consume flat unless recent scale ranks strictly exceed older scale ranks
   and the recent six-month cumulative return has a nonzero sign. Continue
   that sign for one broker month.
6. Open at most one position under `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`; attach a frozen `3.5*ATR(20,D1)` hard stop, reject
   spread above 1,500 points, and attach no target.
7. Close on the first processed tick in a later normalized broker month or
   after forty elapsed calendar days. No intramonth flip, target, trail,
   break-even, partial close, Friday close, or news exit is authorized.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered native D1 history/timestamps, logarithms, sorting, finite
arithmetic, comparisons, broker calendar, quotes, metadata, ATR, positions,
deals, and terminal-persistent attempt state.

## Non-Duplicate Functional Boundary

The fail-closed corrected-root receipt
`artifacts/qm5_wti_mfk_scale_tr_preallocation_dedup_20260901.json` scanned
4,765 registry identities, 1,402 cards, and all 45 Strategy Wiki nodes. It
found no exact identity and conservatively surfaced
`QM5_41261_wti-mab-scale-tr` as one fuzzy neighbor. Receipt SHA-256:
`26F24CE6AB0AA859ACC4B6711B1F4DD2C07DDBD33744CB078F623DBFE031AF70`.

- `QM5_41261` ranks raw returns, scores symmetric distance from the pooled
  tails, enumerates 924 allocations, and qualifies a fixed lower tail. This
  rule subtracts separate block medians first, ranks absolute deviations,
  maps midranks through normal scores, and uses no permutation tail.
- `QM5_41250_wti-mperm-scale-tr` recomputes raw median absolute deviations
  under all 924 old/recent relabelings and applies an upper-tail cap. This rule
  never relabels data; it preserves the observed group centers and pooled
  normal-score path.
- `QM5_41252_wti-css-volshift-tr` searches an interior break through 252
  ordered daily squared returns. This rule has a fixed monthly split and no
  daily return or break-location search.
- `QM5_20298_wti-vov-regime` compares long rolling volatility-of-volatility
  distributions. This rule uses twelve completed monthly returns and one
  contemporaneous pooled score state.
- Certified `QM5_12567` is a short-horizon, long-only XNG cumulative-RSI2
  pullback. This rule is symmetric long/short direct WTI, monthly, and uses no
  oscillator or oversold state.

Fixed fixtures establish decision disagreement:

```text
FK-only returns:
[6.75,-4.25,0.50,5.00,7.50,4.50 | -3.00,-3.25,6.25,-6.25,2.50,-2.75]
A_old/A_recent = 0.7476358421 / 0.7715454367; X2 = 0.0064536333
=> this rule qualifies SELL; Ansari-Bradley score 22 and negative
   permutation-MAD expansion both stay flat.

Ansari-only returns:
[5.25,-1.75,-6.75,3.50,-4.50,7.50 | 6.25,4.25,-6.25,0.25,7.75,-2.00]
A_old/A_recent = 0.8197335318 / 0.6994477469; X2 = 0.1633384683
=> this rule stays flat; Ansari-Bradley score 21 qualifies BUY;
   permutation-MAD stays flat.
```

Verdict:
`FUZZY_ANSARI_BRADLEY_RESOLVED_DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_GROUP_MEDIAN_ABSOLUTE_DEVIATION_POOLED_MIDRANK_NORMAL_SCORE_FLIGNER_KILLEEN_RECENT_SCALE_EXPANSION_CUMULATIVE_RETURN_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE`: complete governed
  peer-reviewed WTI evidence, named peer-reviewed Fligner-Killeen method
  metadata/abstract with explicit body-access boundary, complete signed-tag-
  pinned official SciPy documentation/source, hashes, and explicit
  translation limits.
- R2 `PASS`: month clock, endpoints, return orientation, fixed membership,
  medians, deviations, relative ties, midranks, normal scores, group means,
  score variance, statistic, scale condition, side, attempt, risk, stop,
  spread, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5-native state provide every runtime input;
  roll, basis, financing, gaps, and broker-month labels remain material.
- R4 `PASS`: deterministic native arithmetic and framework state only; no
  trained output, prohibited signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire on a failed score/table fixture, zero positions, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, downstream gate failure, or any month, endpoint, return, median,
deviation, rank, score, statistic, side, attempt, risk, lifecycle, or
determinism defect. A failed result may not be rescued by changing the sample,
split, center, score transform, scale direction, side, carrier, risk, hold, or
by adding a gate.

Q09 alone owns realized overlap. This packet authorizes one card, one branch-
only non-live build, deterministic reference tests, strict Q01, one canonical
fixed-risk WTI backtest preset, and one paced Q02 enqueue below the CPU
ceiling. Excluded: manual backtest, optimization, live/demo/shadow/stress
preset, `T_Live`, AutoTrading, deploy/live manifest, portfolio-gate change,
portfolio admission, correlation waiver, or terminal control.

## Revision History

| version | date | change | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-01 | bounded carrier/method synthesis fixed before market testing | source approval | APPROVED_SOURCE |

