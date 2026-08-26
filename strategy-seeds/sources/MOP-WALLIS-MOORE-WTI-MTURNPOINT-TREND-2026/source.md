---
source_id: MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026
title: WTI thirteen-month turning-point persistence trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading and statistical research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-26_wti_monthly_turning_point_persistence_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-26
created_by: Research+Development
cards_extracted:
  - wti-mturnpoint-tr
---

# WTI Thirteen-Month Turning-Point Persistence Trend Source Packet

## Approved Sources Of Record

The trading lineage is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete governed
packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md` records an end-to-end
read of the 23-page author-hosted published paper, PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`,
monthly own-price continuation, monthly renewal, and explicit NYMEX WTI
membership.

The statistical lineage is W. Allen Wallis and Geoffrey H. Moore (1941), "A
Significance Test for Time Series Analysis," *Journal of the American
Statistical Association* 36(215), 401-409, DOI
`10.1080/01621459.1941.10500577`. Crossref metadata confirms the bibliographic
record. The deterministic source reader classified the public PDF
`DEFERRED:SOURCE_POLICY`, so the article body is not represented as completely
read and no body text or table is used.

The exact public algorithm record is Andrew Hart and Servet Martinez's CRAN
package `spgs` 1.0-4. Repository mirror commit
`987257510f8b2a7ffe903d6b840021befbb4de58` was read through the public GitHub
API after the deterministic source router returned `ROUTE_GITHUB_API`.
Complete relevant-file hashes and retrieval evidence are in
`retrieval_route_20260826.json`.

At that fixed commit, `R/auxtests.R` counts a turning point when the two
successive strict differences have opposite signs and sets the iid null mean
to `2*(n-2)/3` and variance to `(16*n-29)/90`.
`man/turningpoint.test.Rd` independently documents strict local peaks and
troughs, the same moments, and the independence-test interpretation.

These bounded records were reviewed before the durable OWNER approval at
`decisions/2026-08-26_wti_monthly_turning_point_persistence_trend_source_approval.md`.
No blocked text, inferred table, executed third-party code, or ungoverned
performance claim is used.

## Source Findings Used

- Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
  continuation experiment and monthly position renewal.
- Wallis and Moore provide named-author peer-reviewed phase-frequency lineage.
- The complete public `spgs` method files fix strict local-extrema counting
  and its iid null mean and variance.

The records do not establish that a below-mean turning-point count predicts
WTI, is a significance boundary, or is superior to another path statistic.
The thirteen-endpoint sample, strict integer split, endpoint-direction
conjunction, direct-CFD mapping, fixed-dollar risk, stop, spread cap, attempt
state, and lifecycle are transparent QM choices.

No source return, alpha, probability, Sharpe ratio, drawdown, WTI-only result,
trade density, transaction cost, CFD equivalence, estimator superiority,
decorrelation, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive finite pairwise-distinct completed month-end closes
`C[0]..C[12]`, oldest to newest:

```text
TP = 0
for i = 1..11:
  peak   = C[i-1] < C[i] and C[i] > C[i+1]
  trough = C[i-1] > C[i] and C[i] < C[i+1]
  if peak or trough:
    TP += 1

require 0 <= TP <= 11
null_mean = 2*(13-2)/3 = 22/3
persistent = 3*TP < 22          # exactly TP <= 7

BUY  iff persistent and C[12] > C[0]
SELL iff persistent and C[12] < C[0]
FLAT otherwise
```

All close comparisons are strict. Any equal closes, nonpositive or nonfinite
close, wrong endpoint count, wrong chronology, impossible count, or nonfinite
state consumes the month flat. `3*TP<22` is exact integer arithmetic for a
count below the iid null mean; a p-value, continuity correction, normal
approximation, phase-duration chi-square, fitted threshold, or magnitude
fallback is forbidden. Count magnitude never changes direction or risk.

The boundary is fixed before observing a market result. Splitting at the null
mean implies an iid continuous pre-result density prior near one half, or
roughly six monthly decisions/year. No exact discrete probability or empirical
WTI frequency is claimed.

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
4. Compute the exact strict local-extrema count, count invariant, below-mean
   qualification, and oldest/newest direction.
5. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`. Size against a frozen `3.5*ATR(20,D1)` hard stop,
   attach no target, and cap entry spread at 1,500 points.
6. Close on the first tick in a later broker month or after forty calendar
   days. Immediately repair duplicate, wrong-symbol, wrong-magic, wrong-side,
   invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 history, timestamps, calendar, quotes, symbol metadata, ATR,
positions, deals, and terminal-persistent state.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,670 registry identities, 1,321
cards, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. The
receipt is `artifacts/qm5_wti_mturnpoint_tr_preallocation_dedup_20260826.json`.

Manual review fixes a new path statistic:

- `QM5_20273_wti-signrun-tr` retains two longest-run lengths and selects the
  unique run direction; this rule retains only the total reversal count and
  uses the endpoints for direction.
- `QM5_20264_wti-rank-trend` compares all 78 ordered endpoint pairs; this rule
  compares only eleven overlapping local triples.
- `QM5_20274_wti-path-eff` retains move magnitudes; this rule discards them
  after strict comparisons.
- `QM5_41169_wti-foster-record-tr` counts running records; local peaks and
  troughs in this rule need not be records.
- `QM5_41170_wti-bartels-rank-tr` sums squared adjacent rank distances; this
  rule assigns no ranks and counts only direction reversals.
- On zero-based ranks `[8,4,1,7,9,10,3,12,6,0,5,2,11]`, `TP=7` and the
  endpoint rises, so this rule buys. Bartels `NM=383`, Mann-Kendall `S=0`,
  Foster-Stuart `d=0`, and longest runs `L+=3,L-=2` all stay flat.
- On `[5,1,6,2,0,8,3,7,12,4,11,9,10]`, `TP=9`, so this rule stays flat,
  while Bartels `NM=309` and Mann-Kendall `S=36` both qualify long.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not monthly WTI path-shape continuation.

The WTI carrier, thirteen consecutive endpoints, strict no-tie comparisons,
local-extrema count, below-null-mean boundary, endpoint direction, consumed
month, fixed risk, and renewal clock are jointly load-bearing. Verdict:
`CLEAN_WTI_MONTHLY_TURNING_POINT_COUNT_LT_NULL_MEAN_ENDPOINT_TREND`.

## Reputable-Source Criteria

- R1: `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`. Named-author,
  peer-reviewed WTI trading evidence with complete-paper provenance; a
  peer-reviewed Wallis-Moore method record; and complete public CRAN
  implementation and documentation files. The 1941 body and exact trading
  conjunction are not claimed as tested.
- R2: `PASS`. Observation order, strict comparisons, count invariant, mean
  boundary, direction, attempt, risk, stop, and lifecycle are exact.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history and native MT5 state supply every runtime input.
- R4: `PASS`. Deterministic comparisons, integer arithmetic, calendar, ATR
  risk controls, and execution state only; no trained output, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Claim, Kill, And Safety Boundary

The source supports testing monthly WTI continuation conditional on a low
strict turning-point count, not the efficacy or significance of the `TP<=7`
trading boundary. Q02 must retire below five completed positions in any full
post-warm-up year, at zero trades, with nonpositive governed economics, or on
a state, endpoint, count, side, risk, attempt, or lifecycle defect. Downstream
gates alone own robustness and correlation.

No failed result may be rescued by changing the sample, comparison rule,
boundary, direction, carrier, stop, hold, spread cap, or retry contract. This
packet supports one V5 card, one non-live build, strict compile/Q01, and one
paced Q02 handoff only. It does not authorize a manual backtest, live artifact,
`T_Live`, AutoTrading, deploy manifest, portfolio-gate change, portfolio
admission, correlation waiver, terminal control, or claim that the sleeve is
already profitable, certified, or uncorrelated.
