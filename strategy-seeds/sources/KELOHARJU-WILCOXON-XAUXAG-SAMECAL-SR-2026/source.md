---
source_id: KELOHARJU-WILCOXON-XAUXAG-SAMECAL-SR-2026
title: XAU/XAG paired same-calendar-month signed-rank relative seasonality extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading research and pinned R Core statistical code
source_type: peer_reviewed_and_primary_software_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-29_xauxag_same_calendar_signed_rank_source_approval.md
parent_source_ids:
  - KELOHARJU-FMR-XAUXAG-SAMECAL-2026
  - KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026
parent_sha256:
  KELOHARJU-FMR-XAUXAG-SAMECAL-2026: 9266E47C7F3235D900C9432FEAC33A417807AE1E2CC9685FF2FEADAB46DBF75E
  KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026: 57FF7096210C5E48A7236DAD6799A3E6CE706E726BD704416064D5A803D10B98
created: 2026-08-29
created_by: Research+Development
cards_extracted: []
---

# XAU/XAG Paired Same-Calendar Signed-Rank Source Packet

## Approval And Retrieval Boundary

The durable approval is
`decisions/2026-08-29_xauxag_same_calendar_signed_rank_source_approval.md`.
The complete-read receipt is
`artifacts/qm5_xauxag_samecal_srank_source_provenance_20260829.json`.

Four governed repository packets were read completely before approval. The
trading lineages are Keloharju, Linnainmaa, and Nyberg (2016), "Return
Seasonalities," *Journal of Finance* 71(4), 1557-1590, DOI
`10.1111/jofi.12398`, and Fuertes, Miffre, and Rallis (2010), "Tactical
Allocation in Commodity Futures Markets," *Journal of Banking & Finance*
34(10), 2530-2548, DOI `10.1016/j.jbankfin.2010.04.009`. Their governed
packets preserve complete reviews of the open manuscripts.

The operative statistic comes from the pinned R Core Team `stats`
implementation and manual already preserved by
`KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026`: R source commit
`bac583951b728e97b9786804d3b4081f0fe18df5`, implementation blob
`60eb142e6a6c6a1355d96a881d9464ea017cdf18`, and manual blob
`b630339352861e45975540421b408124414bbea8`. The governed packet records a
complete read of both pinned files and the one-sample arithmetic
`rank(abs(x))` followed by summing the ranks whose signed observations are
positive.

No fresh public retrieval is used. This composite reuses immutable local
source evidence and changes only the predeclared carrier/mechanization.

## Findings Used

- Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar-month
  commodity return information, monthly renewal, and a minimum five-year
  history rule.
- Fuertes, Miffre, and Rallis supply a governed XAU/XAG cross-sectional
  commodity carrier and a one-month long/short hold translation.
- R Core supplies exact one-sample signed absolute-rank arithmetic and
  distinguishes it from the two-sample Mann-Whitney/rank-sum statistic.
- The existing governed XAU/XAG packet supplies synchronized paired month-end
  reconstruction, opposite-leg execution, shared risk, and the explicit
  narrow-two-name and futures/CFD translation limits.

None of the sources tests a paired signed-rank score of XAU-minus-XAG
same-calendar returns, a Darwinex CFD basket, strict tie rejection, equal
stop-risk halves, ATR stops, or QM portfolio behavior. The conjunction is a
falsification hypothesis, not an inherited result.

## Exact Statistical Contract

For target calendar month `M` and historical year `H`, reconstruct synchronized
completed log returns:

```text
r_xau(H,M) = ln(xau_month_end_close / xau_prior_month_end_close)
r_xag(H,M) = ln(xag_month_end_close / xag_prior_month_end_close)
d(H,M)     = r_xau(H,M) - r_xag(H,M)
```

Inspect exact years `Y-1` through `Y-10`, skip an invalid or unsynchronized
year without substitution, and require `5 <= n <= 10` valid differences.
Require every `d[k]` finite, `abs(d[k]) > 1e-12`, and every pair of absolute
differences distinct by more than `1e-12`.

Assign strict integer rank `a[k]` from 1 for the smallest `abs(d[k])` through
`n` for the largest. Then:

```text
V_plus = sum(a[k] where d[k] > 0)
T      = n*(n+1)/2
S      = 2*V_plus - T

S > 0  => BUY XAU, SELL XAG
S < 0  => SELL XAU, BUY XAG
S = 0  => consume the month flat
```

The score magnitude never changes risk. No p-value, significance threshold,
average-rank tie handling, Pratt zero convention, mean, median, or hit-rate
fallback is permitted.

## Locked Calendar And Basket Translation

At the first tradable `XAUUSD.DWX` D1 bar after a genuine broker-month
transition:

1. Repair owned exposure, then persist the current broker `yyyymm` before
   every fallible entry gate. Never retry a flat, blocked, rejected, failed,
   stopped, or restarted month.
2. Load completed synchronized XAU and XAG D1 history. For each exact prior
   year, require the historical target-month final bar, the immediately prior
   bar in the adjacent preceding month, and a following bar in the adjacent
   next month on both legs with matching endpoint timestamps.
3. Calculate the paired relative return differences and the exact signed-rank
   score above. Invalid, epsilon-zero, absolute-tie, or centered-zero state
   consumes the month flat.
4. Open one opposite-direction two-leg package. Split one
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` budget equally by
   per-leg stop risk and attach frozen `3.5*ATR(20,D1)` hard stops. Attach no
   target.
5. Reject a genuinely positive spread above 1,500 XAU points or 3,000 XAG
   points. If the second leg fails or final composition is malformed,
   immediately flatten every opened leg.
6. Close both legs at the next broker-month boundary. Forty elapsed calendar
   days is survivor repair only.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 OHLC/timestamps, broker time, quotes, contract metadata,
positions, deals, terminal global variables, and V5 framework services.

## Pre-Result Density Boundary

The rule consumes one decision each broker month and trades whenever a valid
centered score is nonzero. Its structural ceiling is twelve packages per full
post-warm-up year and its pre-result operating prior is ten to twelve, above
the unchanged five-packages/year Q02 floor. This is a design-density bound,
not a market probability or performance result.

## Non-Duplicate Functional Boundary

The canonical checker scanned 4,702 registry identities, 1,348 card files,
and 45 Strategy Wiki nodes. It found no exact collision and surfaced two
expected fuzzy neighbors. Receipt:
`artifacts/qm5_xauxag_samecal_srank_preallocation_dedup_20260829.json`.

- `QM5_20186_xauxag-samecal` takes the arithmetic mean of synchronized XAU
  returns minus the arithmetic mean of synchronized XAG returns. This is the
  mean of `d[k]`; one extreme relative-return year can reverse it while the
  signed-rank score keeps the side supported by the other absolute ranks.
  For `d=[.01,.02,.03,.04,-.20]`, this rule buys (`S=5`) while 20186 sells
  because the mean is negative.
- `QM5_41191_wti-samecal-srank` uses the same statistical family on one WTI
  return series and opens a single crude-oil position. This rule observes
  synchronized paired metal returns, ranks `r_xau-r_xag`, and always owns an
  opposite-direction XAU/XAG package. Carrier, state, sizing, atomicity, and
  exposure are load bearing.
- `QM5_41177_xauxag-mwilcoxon-shift-rv` uses a two-sample
  Mann-Whitney/Wilcoxon rank-sum comparison between two contiguous halves of
  a recent ratio path. It is not a one-sample signed-rank score and does not
  use disjoint returns for the same month across prior years.
- `QM5_41174`, `QM5_41181`, and `QM5_41187` use recent-month rank trend or
  distribution-shift states, not paired same-calendar observations.
- Ratio z-score, OLS/CADF residual, channel, weekday, weekend, and contiguous
  momentum baskets use different information objects and state functions.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_PAIRED_SAMECAL_SIGNED_ABSOLUTE_RANK_SUM_MONTHLY_BASKET_RENEWAL`.

## Reputable-Source Criteria

- R1 `PASS_WITH_STATISTIC_PAIR_AND_CFD_TRANSLATION_RISK`: two completely
  reviewed peer-reviewed trading lineages support the seasonal information
  and XAU/XAG carrier; complete pinned primary software fixes the statistic.
- R2 `PASS`: calendar, synchronized endpoints, year bounds, sample floor,
  epsilon, tie rejection, ranks, score, side, attempt, shared risk, stops,
  atomicity, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5-native
  execution state supply every runtime input.
- R4 `PASS`: timestamps, logarithms, sorting, comparisons, integer arithmetic,
  ATR risk controls, and execution state only; no trained signal, banned
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire or fail on wrong calendar endpoints, cross-leg desynchronization,
sample/zero/tie/rank/score defects, wrong side, same-month retry, orphaned or
same-direction legs, missing stops, invalid fixed-risk mode, wrong lifecycle,
nondeterminism, fewer than five completed packages in any full post-warm-up
year, zero trades, nonpositive governed economics, or downstream correlation
rejection. No result may be rescued by changing the sample, statistic,
epsilon, carrier, direction, risk, hold, spread caps, or adding a filter.

Opposite metal legs target relative rather than outright precious-metal
returns, but this packet does not prove market, dollar, beta, volatility, or
portfolio neutrality. Unchanged Q09 alone owns realized overlap. This packet
authorizes no manual backtest, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, deploy or live manifest, portfolio-gate change,
portfolio admission, correlation waiver, terminal control, or tester dispatch.
