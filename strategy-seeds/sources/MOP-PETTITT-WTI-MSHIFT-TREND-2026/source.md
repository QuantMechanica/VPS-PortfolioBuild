---
source_id: MOP-PETTITT-WTI-MSHIFT-TREND-2026
title: WTI thirteen-month Pettitt central change-point continuation extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading and statistical research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-26_wti_monthly_pettitt_change_point_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-26
created_by: Research+Development
cards_extracted:
  - wti-mpettitt-shift-tr
---

# WTI Thirteen-Month Pettitt Central Change-Point Trend Source Packet

## Approved Sources Of Record

The trading lineage is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete governed
packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md` records an end-to-end
read of the 23-page author-hosted published paper, monthly own-price
continuation, monthly renewal, and explicit NYMEX WTI membership.

The statistical lineage is A. N. Pettitt (1979), "A Non-Parametric Approach
to the Change-Point Problem," *Applied Statistics* 28(2), 126-135, DOI
`10.2307/2346729`. Crossref and the publisher record confirm the named author,
title, journal, volume, issue, year, and pages. The deterministic source
reader classified the publisher route `DEFERRED:SOURCE_POLICY`, so the article
body is not represented as completely read and no body text or table is used.

The exact public method record is Thorsten Pohlert's CRAN package `trend`
1.1.7. Repository mirror commit
`d0ec3cf8b99b4f3226f5211f592955b85565721d` was read through the public
GitHub API after the deterministic source router returned
`ROUTE_GITHUB_API`. `DESCRIPTION`, `R/pettitt.test.R`, and
`man/pettitt.test.Rd` were read completely. File hashes and retrieval evidence
are in `retrieval_route_20260826.json`.

The pinned implementation ranks the complete observations, computes
`U[k] = 2*sum(r[1..k]) - k*(n+1)`, defines `U* = max(abs(U[k]))`, and locates
the probable change point at every `k` attaining that maximum. Its
documentation identifies the target as a shift in central tendency and gives
the approximate two-sided probability formula. Runtime will not import or
execute this package; the formula is implemented directly in MQL5.

No blocked text, inferred table, executed third-party code, or ungoverned
performance claim is used.

## Source Findings Used

- Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
  continuation experiment and monthly position renewal.
- Pettitt supplies peer-reviewed change-point lineage.
- The complete pinned CRAN files fix the rank-sum path, absolute maximum, and
  change-point location.

The records do not establish that a central Pettitt split predicts WTI or that
the proposed trading conjunction is significant. The thirteen endpoints,
strict no-tie ranks, unique central split, continuation side, direct-CFD
mapping, fixed-dollar risk, stop, spread cap, attempt state, and lifecycle are
transparent QM choices.

No source return, alpha, probability, Sharpe ratio, drawdown, WTI-only result,
trade density, cost, CFD equivalence, decorrelation, or portfolio-correlation
statistic transfers.

## Exact Statistical Contract

For thirteen positive, finite, pairwise-distinct completed WTI month-end
closes `C[0]..C[12]`, oldest to newest, assign strict ranks `R[i]` from 1
(smallest) to 13 (largest):

```text
require sorted(R) = [1,2,...,13]

for k = 1..12:
  U[k] = 2*sum(R[0..k-1]) - 14*k

Ustar = max(abs(U[k]), k=1..12)
Kset  = { k : abs(U[k]) == Ustar }

qualify iff size(Kset) == 1 and 4 <= K <= 9

BUY  iff qualify and U[K] < 0    # earlier ranks lower; later regime higher
SELL iff qualify and U[K] > 0    # earlier ranks higher; later regime lower
FLAT otherwise
```

`Ustar` must be positive, even, and no greater than 42. A tied maximum,
endpoint tie, average rank, p-value gate, fitted threshold, endpoint-direction
fallback, or alternate split is forbidden. The central band leaves at least
four completed observations on either side. It is a density and lifecycle
choice, not a statistical-significance claim. `Ustar` magnitude never changes
side or risk.

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
4. Assign the exact rank permutation, compute all twelve `U[k]`, prove the
   bounds/parity, require one maximum in the locked central band, and take the
   post-shift continuation side from the sign of `U[K]`.
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

The fail-closed canonical checker scanned 4,671 registry identities, 1,322
cards, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. The
receipt is
`artifacts/qm5_wti_mpettitt_shift_tr_preallocation_dedup_20260826.json`.

Manual review fixes a new change-point statistic:

- `QM5_41170_wti-bartels-rank-tr` sums squared adjacent rank moves and tests
  `NM<364`; this rule scans signed cumulative rank sums and requires a unique
  central maximizing split.
- `QM5_41171_wti-mturnpoint-tr` counts strict local extrema and takes side
  from the oldest/newest endpoint; this rule does neither.
- `QM5_41169_wti-foster-record-tr` counts running records; this rule retains
  the location and sign of a maximum two-sample rank separation.
- On zero-based ranks
  `[0,7,4,6,1,9,10,5,11,2,8,3,12]`, `U*=24` uniquely at `K=5` with
  `U[K]=-24`, so this rule buys. Bartels `NM=436` and turning points `TP=10`
  both stay flat.
- On zero-based ranks
  `[0,1,12,5,4,6,7,11,9,2,3,10,8]`, the maximum is only `22` at edge split
  `K=2`, so this rule stays flat. Bartels `NM=300` and turning points `TP=5`
  both qualify long from their rising endpoints.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a monthly WTI central-tendency shift.

The WTI carrier, thirteen consecutive endpoints, strict rank permutation,
signed cumulative rank sums, unique central maximum, consumed month, fixed
risk, and renewal clock are jointly load-bearing. Verdict:
`CLEAN_WTI_MONTHLY_PETTITT_UNIQUE_CENTRAL_SHIFT_CONTINUATION`.

## Reputable-Source Criteria

- R1: `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`. Named-author,
  peer-reviewed WTI trading evidence with complete-paper provenance; a
  peer-reviewed Pettitt method record; and complete pinned CRAN method files.
  The 1979 body and exact trading conjunction are not claimed as tested.
- R2: `PASS`. Observation order, strict ranks, all cumulative sums, unique
  maximum, central band, direction, attempt, risk, stop, and lifecycle are
  exact.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history and native MT5 state supply every runtime input.
- R4: `PASS`. Deterministic ranks, integer arithmetic, calendar, ATR risk
  controls, and execution state only; no trained output, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Claim, Kill, And Safety Boundary

The source supports testing monthly WTI continuation after a central rank-sum
shift, not its efficacy or statistical significance. The pre-result density
prior is four to eight completed positions per full post-warm-up year. Q02
must retire below four completed positions in any full year, at zero trades,
with nonpositive governed economics, or on a state, endpoint, rank, split,
side, risk, attempt, or lifecycle defect. Q09 alone owns overlap and
correlation.

No failed result may be rescued by changing the sample, rank rule, central
band, direction, carrier, stop, hold, spread cap, or retry contract. This
packet supports one V5 card, one non-live build, strict compile/Q01, and one
paced Q02 handoff only. It does not authorize a manual backtest, live artifact,
`T_Live`, AutoTrading, deploy manifest, portfolio-gate change, portfolio
admission, correlation waiver, terminal control, or claim that the sleeve is
already profitable, certified, or uncorrelated.
