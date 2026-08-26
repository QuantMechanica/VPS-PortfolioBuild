---
source_id: MOP-SPEARMAN-WTI-MRANK-TREND-2026
title: WTI thirteen-month Spearman price-rank trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading and statistical research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-26_wti_monthly_spearman_rank_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-26
created_by: Research+Development
cards_extracted:
  - wti-mspearman-tr
---

# WTI Thirteen-Month Spearman Price-Rank Trend Source Packet

## Approved Sources Of Record

The trading lineage is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete governed
packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md` records an end-to-end
read of the 23-page author-hosted published paper, monthly own-price
continuation, monthly renewal, and explicit NYMEX WTI membership.

The statistical lineage is C. Spearman (1904), "The Proof and Measurement of
Association between Two Things," *The American Journal of Psychology* 15(1),
DOI `10.2307/1412159`. Crossref confirms the named author, title, journal,
volume, issue, year, publisher, and DOI. The deterministic source router
classified the publisher route `DEFERRED:SOURCE_POLICY`, so the article body
is not represented as completely read and no body text, table, probability,
or performance result is used.

The exact public method record is the R Core Team `stats::cor` implementation
and documentation in the public `wch/r-source` mirror, branch `trunk`, commit
`7344a2d9d96b3c2b997535d3abc8c3a44af16e82`. After the deterministic router
selected the public GitHub API, `src/library/stats/R/cor.R` and
`src/library/stats/man/cor.Rd` were read completely. The implementation rank-
transforms both inputs and computes ordinary correlation of those ranks; the
documentation identifies Spearman rho as a rank-based association measure.
Exact blob identifiers, byte counts, hashes, and retrieval evidence are in
`retrieval_route_20260826.json`.

No blocked text, inferred table, executed third-party code, binary, or
ungoverned performance claim is used.

## Source Findings Used

- Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
  continuation experiment and monthly renewal.
- Spearman supplies the named rank-association lineage.
- The complete pinned R files fix the operative method as Pearson correlation
  after rank-transforming both ordered inputs.

The records do not establish that Spearman rho predicts WTI or that any fixed
rho boundary is significant. The thirteen endpoints, strict no-tie rule,
integer boundary, continuous-CFD mapping, fixed-dollar risk, stop, consumed
attempt, and lifecycle are transparent QM choices.

No source return, alpha, probability, Sharpe ratio, drawdown, WTI-only result,
trade density, cost, CFD equivalence, decorrelation, or portfolio-correlation
statistic transfers.

## Exact Statistical Contract

For thirteen positive, finite, pairwise-distinct completed WTI month-end
closes `C[0]..C[12]`, oldest to newest, assign strict price ranks `R[i]` from 1
(smallest) to 13 (largest). Time ranks are fixed as `I[i]=i+1`.

The complete R method record defines Spearman rho as the ordinary correlation
of `rank(I)` and `rank(C)`. With two no-tie permutations of `1..13`, both rank
means are 7 and both centered sums of squares are 182. The card therefore uses
the following algebraically identical integer form:

```text
require sorted(R) = [1,2,...,13]

D = sum((R[i] - (i + 1))^2) for i = 0..12
T = 364 - D
rho = T / 364

require 0 <= D <= 728
require -364 <= T <= 364
require D and T even

BUY  iff T >= 104
SELL iff T <= -104
FLAT otherwise
```

This is equivalent to `rho = 1 - D/364`; the fixed gate is
`abs(rho) >= 2/7`. Signal magnitude never changes risk. Exact ties are rejected
rather than average-ranked, and no p-value is calculated.

## Pre-Result Density Boundary

The threshold was locked before any WTI backtest. An exact subset-assignment
dynamic program counted all `13! = 6,227,020,800` no-tie rank permutations.
Exactly `2,139,842,508` satisfy `abs(T) >= 104`, split symmetrically into
`1,069,921,254` positive and negative cases. The random-order qualification
rate is `0.3436382463986631`, or `4.123658956783957` qualifying months per
twelve decisions. This is a density-oriented design fact, not a null-model
claim about WTI and not a significance threshold.

The pre-result operating prior is four to eight completed positions per full
post-warm-up year. Q02 must retire the candidate below four in any full year,
at zero trades, or with nonpositive governed economics.

## Locked Trading Translation

At the first executable `XTIUSD.DWX` D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` as consumed before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry that
   month after a flat signal, invalid state, reject, stop, or restart.
2. Exclude the current month. Reconstruct exactly thirteen consecutive
   completed broker calendar months ending with the immediately prior month.
   Retain the latest WTI D1 close in each month. Reject missing or duplicate
   months, nonchronological timestamps, nonpositive closes, any pairwise equal
   closes, or a newest endpoint more than ten calendar days stale.
3. Assign strict ranks, prove the permutation and integer invariants, compute
   `D` and `T`, and trade only at the locked `abs(T) >= 104` boundary.
4. Buy when `T >= 104`; sell when `T <= -104`. A weak or invalid path consumes
   the month flat. No endpoint, Mann-Kendall, slope, moving-average, seasonal,
   volatility, p-value, or prior-result fallback is permitted.
5. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`, sized against a frozen `3.5*ATR(20,D1)` broker
   hard stop. Attach no target and cap entry spread at 1,500 points.
6. Close on the first tick in a later broker month or after forty calendar
   days. Immediately repair duplicate, wrong-symbol, wrong-magic, wrong-side,
   invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
native/custom MT5 D1 prices, broker time, quotes, symbol metadata, positions,
deals, terminal global variables, and V5 framework services.

## Non-Duplicate Functional Boundary

The canonical checker found no exact or fuzzy match across 4,672 registry
identities, 1,323 card files, and 45 Strategy Wiki nodes. Its receipt is
`artifacts/qm5_wti_mspearman_tr_preallocation_dedup_20260826.json`.

Manual review separates the mechanic from its nearest neighbors:

- `QM5_20264_wti-rank-trend` counts the signs of all 78 ordered pairs and
  gates `abs(S)>=28`; this rule squares each endpoint's displacement from its
  own time rank and gates `abs(T)>=104`.
- `QM5_41167_wti-coxstuart-tr` compares seven fixed lag-seven pairs among
  fourteen endpoints; this rule uses all thirteen time and price ranks.
- `QM5_41169_wti-foster-record-tr` retains only running high/low records;
  this rule weights every observation by its exact time-rank displacement.
- `QM5_41170_wti-bartels-rank-tr` sums squared adjacent price-rank moves;
  this rule compares price rank with absolute calendar rank and is unaffected
  by which adjacent jump produced a displacement.
- `QM5_41172_wti-mpettitt-shift-tr` locates one unique central cumulative
  rank-sum maximum; this rule has no split search or change-point condition.
- `QM5_10473_mql5-spearman` is an H4 FX price/indicator zero-crossing system,
  not a WTI completed-month price-rank-versus-time-rank continuation rule.

Rank vector `[3,2,10,1,4,12,11,8,7,9,6,5,13]` gives `T=170` and BUY here,
while Mann-Kendall is flat at `S=20`. Vector
`[13,1,4,12,5,2,3,6,7,8,9,10,11]` gives Mann-Kendall BUY at `S=28` while this
rule is flat at `T=98`. Vector `[1,11,3,5,7,12,4,8,10,2,13,9,6]` gives BUY
here at `T=106` while Pettitt is flat because its maximum absolute rank sum is
tied at `K=4` and `K=5`. Vector `[8,3,9,2,13,11,1,12,6,7,4,5,10]` is flat
here at `T=8` while Pettitt buys from a unique central `U*` at `K=4`.

Verdict: `CLEAN_WTI_MONTHLY_SPEARMAN_TIME_PRICE_RANK_T104_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: named-author,
  peer-reviewed JFE trading evidence with complete-paper provenance and
  explicit WTI membership; named original Spearman journal record; and
  complete pinned R Core method files. The 1904 body and exact trading
  conjunction are explicitly untested.
- R2 `PASS`: clock, month selection, ranks, integer arithmetic, threshold,
  side, attempt, risk, stop, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1
  history plus native MT5 state supply every runtime input.
- R4 `PASS`: deterministic ranks, integer arithmetic, ATR risk controls, and
  execution state only; no trained output, banned signal method, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire or fail on any month-selection, rank, displacement, parity, threshold,
side, attempt, fixed-risk, stop, lifecycle, or determinism defect; fewer than
four completed positions in any full post-warm-up year; zero trades;
nonpositive governed economics; or downstream portfolio-correlation
rejection. No failed result may be rescued by changing the sample, tie rule,
threshold, direction, risk, hold, or by adding another filter.

WTI is a direct crude-oil carrier absent from the stated XAU/SP500/NDX/XNG
book, but this does not prove low or negative realized correlation. Q09 alone
owns overlap. This packet authorizes no manual backtest, live/demo/shadow
preset, AutoTrading, `T_Live`, deploy manifest, live manifest, portfolio-gate
change, portfolio admission, or correlation waiver.
