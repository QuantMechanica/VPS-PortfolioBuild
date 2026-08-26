---
source_id: MOP-BARTELS-WTI-MRANKPERSIST-TREND-2026
title: WTI thirteen-month Bartels rank-persistence trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading and statistical research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-26_wti_monthly_bartels_rank_persistence_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-26
created_by: Research+Development
cards_extracted:
  - wti-bartels-rank-tr
---

# WTI Thirteen-Month Bartels Rank-Persistence Trend Source Packet

## Approved Sources Of Record

The trading lineage is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete governed
packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md` records an end-to-end
read of the 23-page author-hosted published paper, PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`,
monthly own-price continuation, monthly renewal, and explicit NYMEX WTI
membership.

The statistical lineage is Robert Bartels (1982), "The Rank Version of von
Neumann's Ratio Test for Randomness," *Journal of the American Statistical
Association* 77(377), 40-46, DOI
`10.1080/01621459.1982.10477764`. Crossref metadata confirms the bibliographic
record. The original body is not represented as completely read.

The exact public algorithm record is Frederico Caeiro and Ayana Mateus's CRAN
package `randtests` 1.0.2. Repository mirror commit
`7244d86764445e657634c9ae4d59ce942a5fcbc8` was read through the public GitHub
API after the deterministic source router returned `ROUTE_GITHUB_API`.
Complete relevant-file hashes and retrieval evidence are in
`retrieval_route_20260826.json`.

At that fixed commit, `R/bartels.rank.test.R` ranks the observations, sums
squared successive rank differences, divides by the centered rank-square
sum, sets the null mean to two, and implements the documented asymptotic
variance. `man/bartels.rank.test.Rd` defines the same formula and identifies a
left-sided low ratio as the trend alternative and a high ratio as systematic
oscillation.

These bounded records were reviewed before the durable OWNER approval at
`decisions/2026-08-26_wti_monthly_bartels_rank_persistence_trend_source_approval.md`.
No blocked text, inferred table, executed third-party code, or ungoverned
performance claim is used.

## Source Findings Used

- Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
  continuation experiment and monthly position renewal.
- Bartels provides peer-reviewed rank von-Neumann test lineage.
- The complete public `randtests` method files fix the rank, numerator,
  denominator, null mean, variance, and low-ratio trend interpretation used by
  this extraction.

The records do not establish that `RVN<2` predicts WTI, is a significance
boundary, or is better than another trend statistic. The thirteen-endpoint
sample, null-mean boundary, endpoint-direction conjunction, direct-CFD
mapping, fixed-dollar risk, stop, spread cap, attempt state, and lifecycle are
transparent QM choices.

No source return, alpha, probability, Sharpe ratio, drawdown, WTI-only result,
trade density, transaction cost, CFD equivalence, estimator superiority,
decorrelation, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive finite pairwise-distinct completed month-end closes
`C[0]..C[12]`, oldest to newest:

```text
R[i] = ordinal rank of C[i] among all thirteen closes
       (1 = smallest, 13 = largest)

require R is exactly the permutation 1..13
denominator = sum((R[i] - 7)^2, i=0..12) = 182
NM          = sum((R[i+1] - R[i])^2, i=0..11)
RVN         = NM / 182

BUY  iff NM < 364 and C[12] > C[0]
SELL iff NM < 364 and C[12] < C[0]
FLAT otherwise
```

All close and rank comparisons are strict. Any equal closes, nonpositive or
nonfinite close, wrong endpoint count, wrong chronology, impossible rank,
denominator other than 182, or nonfinite state consumes the month flat.
`NM<364` is exact integer arithmetic for `RVN<2`; a p-value, finite-sample
table, Beta approximation, normal approximation, fitted threshold, or
magnitude fallback is forbidden. Statistic magnitude never changes direction
or risk.

The boundary is fixed before observing a market result. The source's normal
and Beta approximations are centered at `RVN=2`, implying a rank-uniform
density prior near one half at the mean split, or roughly six monthly
decisions/year. No exact discrete probability or empirical WTI frequency is
claimed.

## Exact Event And Execution Contract

1. Require exact `XTIUSD.DWX`, D1, slot zero, and an entry attempt no later
   than 180 elapsed minutes after the raw current D1 bar open in a genuine new
   broker month.
2. Persist the broker `yyyymm` before all fallible gates. A flat result,
   invalid state, reject, stop, or restart never retries the month.
3. Select the latest close in each of the immediately prior thirteen
   consecutive broker months. Require positive finite pairwise-distinct
   closes, strict chronology, the immediately prior newest month, and no more
   than ten calendar days of endpoint staleness. The current month contributes
   no signal close.
4. Compute the exact ordinal ranks, denominator invariant, `NM`, and
   `RVN<2` qualification; use only the oldest/newest close comparison for
   direction.
5. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`. Size against a frozen `3.5*ATR(20,D1)` hard stop,
   attach no target, and cap entry spread at 1,500 points.
6. Close on the first tick in a later broker month or after forty calendar
   days. Immediately repair duplicate, wrong-symbol, wrong-magic, wrong-side,
   invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 history, timestamps, calendar, quotes, symbol metadata,
ATR, positions, deals, and terminal-persistent state.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,669 registry identities, 1,320
cards, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. The
receipt is
`artifacts/qm5_wti_bartels_rank_tr_preallocation_dedup_20260826.json`.

Manual review fixes a new path statistic:

- `QM5_20264_wti-rank-trend` compares every ordered endpoint pair; this rule
  uses only successive squared rank distances.
- `QM5_20274_wti-path-eff` retains move magnitudes; this rule discards them
  after ordinal ranking.
- `QM5_41167_wti-coxstuart-tr` uses seven disjoint half-sample pairs among
  fourteen endpoints; this rule uses twelve adjacent distances among thirteen
  endpoints.
- `QM5_41169_wti-foster-record-tr` counts new running extremes; this rule
  uses neither records nor crossings.
- On zero-based ranks `[2,3,10,5,6,12,11,4,1,0,9,8,7]`, `NM=255<364` and
  the endpoint rises, so this rule buys; Mann-Kendall is `4` and the
  Foster-Stuart imbalance is `1`, so both named neighbors stay flat.
- On `[2,5,7,0,9,3,4,12,1,10,6,8,11]`, `NM=475` and this rule stays flat
  even though the endpoint rises, Mann-Kendall is `28`, and Foster-Stuart is
  `3`.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not monthly WTI rank-persistence continuation.

The WTI carrier, thirteen consecutive endpoints, strict no-tie ranks,
successive-rank numerator, fixed denominator, below-two boundary, endpoint
direction, consumed month, fixed risk, and renewal clock are jointly
load-bearing. Verdict:
`CLEAN_WTI_MONTHLY_BARTELS_RANK_RVN_LT2_ENDPOINT_TREND`.

## Reputable-Source Criteria

- R1: `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`. Named-author,
  peer-reviewed WTI trading evidence with complete-paper provenance; a
  peer-reviewed Bartels method record; and complete public CRAN implementation
  and documentation files. The original 1982 body and exact trading
  conjunction are not claimed as tested.
- R2: `PASS`. Observation order, strict no-tie ranks, invariant, numerator,
  mean boundary, direction, attempt, risk, stop, and lifecycle are exact.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history and native MT5 state supply every runtime input.
- R4: `PASS`. Deterministic comparisons, ranks, integer arithmetic, calendar,
  ATR risk controls, and execution state only; no trained output, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Claim, Kill, And Safety Boundary

The source supports testing monthly WTI continuation conditional on low
Bartels successive-rank dispersion, not the efficacy or significance of the
`RVN<2` trading boundary. Q02 must retire below five completed positions in
any full post-warm-up year, at zero trades, with nonpositive governed
economics, or on a state, endpoint, rank, invariant, numerator, side, risk,
attempt, or lifecycle defect. Downstream gates alone own robustness and
correlation.

No failed result may be rescued by changing the sample, rank definition,
boundary, direction, carrier, stop, hold, spread cap, or retry contract. This
packet supports one V5 card, one non-live build, strict compile/Q01, and one
paced Q02 handoff only. It does not authorize a manual backtest, live artifact,
`T_Live`, AutoTrading, deploy manifest, portfolio-gate change, portfolio
admission, correlation waiver, terminal control, or claim that the sleeve is
already profitable, certified, or uncorrelated.

