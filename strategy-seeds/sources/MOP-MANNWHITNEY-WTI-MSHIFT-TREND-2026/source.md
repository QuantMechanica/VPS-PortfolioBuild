---
source_id: MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026
title: WTI twelve-month fixed-block Mann-Whitney location-shift trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading and statistical research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_wti_monthly_mann_whitney_location_shift_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - wti-mwilcoxon-shift-tr
---

# WTI Twelve-Month Fixed-Block Mann-Whitney Location-Shift Source Packet

## Approved Sources Of Record

The trading lineage is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete governed
packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md` records an end-to-end
read of the 23-page author-hosted published paper, monthly own-price
continuation, monthly renewal, and explicit NYMEX WTI membership.

The statistical lineage is H. B. Mann and D. R. Whitney (1947), "On a Test of
Whether one of Two Random Variables is Stochastically Larger than the Other,"
*The Annals of Mathematical Statistics* 18(1), 50-60, DOI
`10.1214/aoms/1177730491`. Crossref confirms the bibliographic identity. The
deterministic source router classified the publisher route
`DEFERRED:SOURCE_POLICY`, so the article body is not represented as completely
read and no body text, table, probability, or result is used.

The exact public method record is the R Core Team `stats::wilcox.test`
implementation and documentation in the public `wch/r-source` mirror at
commit `7344a2d9d96b3c2b997535d3abc8c3a44af16e82`. After the deterministic
router selected the public GitHub API, `src/library/stats/R/wilcox.test.R` and
`src/library/stats/man/wilcox.test.Rd` were read completely. The implementation
forms the two-sample statistic as the first sample's combined rank sum less
`m(m+1)/2`; the manual identifies this as the Wilcoxon rank-sum/Mann-Whitney
test and gives the equivalent pair-count interpretation. Exact blob IDs,
byte counts, hashes, routes, and the deferred-body boundary are recorded in
`retrieval_route_20260827.json`.

No blocked text, inferred table, executed third-party code, binary, or
ungoverned performance claim is used.

## Source Findings Used

- Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
  continuation experiment and monthly renewal.
- Mann and Whitney supply the named two-sample ordinal comparison lineage.
- The complete pinned R files fix the operative no-tie statistic as the first
  sample's rank sum minus its minimum possible rank sum, equivalently its
  favorable cross-sample pair count.

The records do not establish that a fixed half-versus-half rank location shift
predicts WTI. The twelve endpoints, six/six split, strict tie rejection,
integer boundary, continuous-CFD mapping, fixed-dollar risk, stop, consumed
attempt, and lifecycle are transparent QM choices.

No source return, alpha, probability, significance, Sharpe ratio, drawdown,
WTI-only result, trade density, cost, CFD equivalence, decorrelation, or
portfolio-correlation statistic transfers.

## Exact Statistical Contract

For twelve positive, finite, pairwise-distinct completed WTI month-end closes
`C[0]..C[11]`, oldest to newest, define the older block `O=C[0..5]` and newer
block `N=C[6..11]`. Assign strict combined ranks 1 through 12. Treat the newer
block as the first sample in the pinned R definition:

```text
W_new = sum(combined_rank(N[j]), j=0..5)
U_new = W_new - 6*7/2

equivalently, because ties are forbidden:
U_new = count(N[j] > O[i] for every i=0..5 and j=0..5)

require 0 <= U_new <= 36
require U_new + U_old == 36

BUY  iff U_new >= 24
SELL iff U_new <= 12
FLAT otherwise
```

The two inclusive boundaries are symmetric around 18. Signal magnitude never
changes risk. Exact ties are rejected rather than average-ranked, and no
p-value, fitted split, location estimate, endpoint return, or fallback is
calculated.

## Pre-Result Density Boundary

The thresholds were locked before any WTI test. Exact enumeration of the
`choose(12,6)=924` no-tie assignments of combined ranks to the newer block
gives 182 assignments at `U_new>=24` and 182 at `U_new<=12`. The symmetric
qualification rate is `364/924 = 0.3939393939393939`, or
`4.727272727272727` decisions per twelve monthly opportunities under random
rank assignment. This is a density design fact, not a statistical-significance
or WTI-performance claim.

The pre-result operating prior is four to eight completed positions per full
post-warm-up year. Q02 must retire below four in any full year, at zero trades,
or with nonpositive governed economics.

## Locked Trading Translation

At the first executable `XTIUSD.DWX` D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` as consumed before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry that
   month after a flat signal, invalid state, reject, stop, or restart.
2. Exclude the current month. Reconstruct exactly twelve consecutive completed
   broker calendar months ending with the immediately prior month. Retain the
   latest WTI D1 close in each month. Reject missing or duplicate months,
   nonchronological timestamps, nonpositive closes, any pairwise equal closes,
   or a newest endpoint more than ten calendar days stale.
3. Split the ordered endpoints once and only once after observation six. Count
   the 36 strict newer-versus-older comparisons and prove the complementary
   pair-count invariant.
4. Buy when `U_new>=24`; sell when `U_new<=12`. A central or invalid result
   consumes the month flat. No variable split, maximum search, Mann-Kendall
   all-time-pair score, slope, moving average, seasonal, volatility, p-value,
   or prior-result fallback is permitted.
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

The fail-closed canonical checker scanned 4,675 registry identities, 1,326
card files, and 45 Strategy Wiki nodes and found no exact or fuzzy match. Its
receipt is
`artifacts/qm5_wti_mwilcoxon_shift_tr_preallocation_dedup_20260827.json`.

Manual review separates the mechanic from its nearest neighbors:

- `QM5_20264_wti-rank-trend` compares every ordered pair across thirteen
  month-end prices and gates the signed Mann-Kendall score at 28. This rule
  ignores within-block order and counts only the 36 comparisons crossing one
  fixed six/six boundary among the latest twelve endpoints.
- `QM5_41172_wti-mpettitt-shift-tr` scans all twelve split locations on
  thirteen ranks and requires a unique dominant central maximum. This rule
  has one prespecified split, no maximum search, and a fixed U boundary.
- `QM5_41173_wti-mspearman-tr` weights every endpoint's squared rank
  displacement from its calendar rank. This rule is invariant to any
  permutation within either six-observation block.
- `QM5_41137_wti-mmedian-shift-mom` compares full daily log-price samples from
  two adjacent months. This rule compares twelve monthly endpoints in two
  six-month regimes.
- `QM5_20272_wti-qtrvote-tr` follows four disjoint return-block signs; this
  rule uses a combined ordinal location statistic and no block returns.
- Certified `QM5_12567_cum-rsi2-commodity` is a two-day long-only XNG
  oscillator pullback with neither WTI exposure nor monthly rank logic.

For a thirteen-price rank path, the candidate uses the latest twelve values.
Path `[11,13,2,4,6,1,3,10,5,7,8,9,12]` gives candidate BUY at `U_new=29`,
while Mann-Kendall is flat at `S=16`, Spearman is flat at `T=52`, and Pettitt
is flat because its unique maximum is at edge split `K=2`. Path
`[1,8,3,5,7,11,9,4,2,12,13,6,10]` gives candidate FLAT at `U_new=20`, while
Mann-Kendall buys at `S=28`, Spearman buys at `T=176`, and Pettitt buys from
its unique central maximum. Path `[11,10,9,8,3,2,1,13,4,5,6,12,7]` gives
candidate BUY at the inclusive boundary `U_new=24`, while Pettitt sells from
its unique `K=4` maximum and the other two trend ranks stay flat.

Verdict:
`CLEAN_WTI_MONTHLY_FIXED_SIX_BY_SIX_MANN_WHITNEY_U24_LOCATION_SHIFT_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete-read,
  peer-reviewed WTI trading evidence; named original Mann-Whitney journal
  record; and complete pinned R Core method files. The 1947 body and exact
  trading conjunction remain explicitly untested.
- R2 `PASS`: clock, month selection, fixed block membership, strict ties,
  rank/pair-count identity, integer thresholds, side, attempt, risk, stop, and
  lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1
  history plus native MT5 state supplies every runtime input.
- R4 `PASS`: deterministic comparisons, integer arithmetic, ATR risk controls,
  and execution state only; no trained output, banned signal method, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire or fail on any month-selection, fixed-split, tie, rank/pair-count,
threshold, side, attempt, fixed-risk, stop, lifecycle, or determinism defect;
fewer than four completed positions in any full post-warm-up year; zero
trades; nonpositive governed economics; or downstream portfolio-correlation
rejection. No failed result may be rescued by changing the sample, split, tie
rule, boundary, direction, risk, hold, or by adding another filter.

WTI is a direct crude-oil carrier absent from the stated XAU/SP500/NDX/XNG
book, but this does not prove low or negative realized correlation. Q09 alone
owns overlap. This packet authorizes no manual backtest, live/demo/shadow
preset, AutoTrading, `T_Live`, deploy manifest, live manifest, portfolio-gate
change, portfolio admission, correlation waiver, terminal control, or tester
dispatch.
