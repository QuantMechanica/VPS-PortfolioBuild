---
source_id: KELOHARJU-MOP-WTI-CALMOM1-2026
title: WTI same-calendar seasonality and one-month time-series-momentum agreement
publisher: The Journal of Finance / Journal of Financial Economics
source_type: peer_reviewed_composite_lineage
status: approved_source_complete
approval_basis: OWNER commodity/energy sleeve mission 2026-08-03
created: 2026-08-03
created_by: Research+Development
parent_sources:
  - KELOHARJU-RETSEAS-2016
  - MOP-TSMOM-2012
strategy_ids:
  - KELOHARJU-MOP-WTI-CALMOM1-2026_S01
---

# WTI Same-Calendar / One-Month Momentum Source Packet

## Approval And Complete-Read Scope

The OWNER mission dated 2026-08-03 directs one new structural, low-frequency
commodity/energy card, build, and paced Q02 enqueue. This packet joins two
already approved and completely reviewed peer-reviewed source lineages:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI https://doi.org/10.1111/jofi.12398. The complete 57-page NBER version
   was reviewed under
   `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
   DOI https://doi.org/10.1016/j.jfineco.2011.11.003. The complete 23-page
   published paper and its retrieval hash are recorded under
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

Both bounded repository packets were read completely for this extraction.
No fresh public-page text substitutes for them, and no external source is read
at runtime.

## Findings Used

- Keloharju, Linnainmaa, and Nyberg rank commodities by their average return
  in the same calendar month over prior years. Their commodity universe
  explicitly contains crude oil, and the governed translation requires at
  least five prior annual observations.
- Moskowitz, Ooi, and Pedersen define time-series momentum from the sign of an
  instrument's own prior `k`-month return and explicitly report the commodity
  `k=1`, `h=1` family. Their universe explicitly contains NYMEX WTI.
- Both papers use diversified rolling futures portfolios. Neither tests the
  conjunction below, a one-name WTI continuous-CFD carrier, fixed cash risk,
  Darwinex month boundaries, broker costs, or the QM portfolio.

No source profit factor, return, drawdown, hit rate, WTI-only alpha, trade
count, CFD-basis, or portfolio-correlation statistic is imported.

## Bounded Mechanization

`KELOHARJU-MOP-WTI-CALMOM1-2026_S01` locks one monthly two-state WTI package:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable WTI D1 bar of every broker-calendar month;
- seasonal state: arithmetic mean of WTI log returns for the decision
  calendar month in the prior ten years, requiring at least five valid
  completed-month observations;
- momentum state: WTI log return over the immediately completed consecutive
  broker-calendar month;
- positive agreement buys WTI; negative agreement shorts WTI; disagreement,
  exact zero, missing/nonconsecutive endpoints, or invalid state remains flat;
- close and re-evaluate at the next month boundary, with a 35-calendar-day
  stale guard, a frozen `3.5 * ATR(20,D1)` hard stop, and one consumed attempt
  per month; and
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The conjunction tests whether recurring physical/hedging seasonality and
short-horizon price continuation identify the same WTI direction. It is a
predeclared QM falsification hypothesis, not a result reported by either
paper. Q02 and later gates must reject it if costs, basis, gaps, sparse
agreement, or source decay dominate.

## Non-Duplicate Boundary

The deterministic pre-allocation scan covered 4,261 registry rows and 384
cards and returned `CLEAN` for slug `wti-calmom1`, strategy ID
`KELOHARJU-MOP-WTI-CALMOM1-2026_S01`, and the exact mechanic.

Manual semantic review resolves the nearest systems:

- `QM5_20099_wti-samecal` owns the same-calendar state alone and never
  requires an independent recent-return state.
- `QM5_20187_wti-tsmom1m` owns the exact completed-month continuation state
  alone and never estimates recurring month-of-year history.
- `QM5_20136_wti-caltrend` confirms the seasonal state with a completed
  63-D1 return, not an exact broker-calendar-month endpoint pair.
- `QM5_20137_wti-seas-pb` uses the same seasonal and exact one-month clocks
  but requires strict sign disagreement and trades the seasonal direction.
  This candidate requires strict sign agreement, follows the one-month
  continuation direction, and therefore trades a disjoint state.
- Fixed-month, weekday, inventory, expiry, channel, and pure trend WTI EAs do
  not combine these two information objects.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback above a
  long price filter, with a materially different entry and hold.

The recurring seasonal estimator, exact immediately completed month, strict
agreement, shared direction, and monthly lifecycle are jointly load-bearing.
Removing either state recreates a built parent. Replacing agreement with
disagreement recreates `QM5_20137`.

## Reputable-Source Criteria

- R1: PASS. Two named-author, peer-reviewed lineages in *The Journal of
  Finance* and *Journal of Financial Economics*, each with a DOI and a
  complete durable repository review.
- R2: PASS. Month endpoints, ten-year bounded estimator, five-sample floor,
  exact one-month return, agreement direction, attempt state, stop, spread,
  and exits are deterministic and frozen.
- R3: PASS. Registered `XTIUSD.DWX` D1 supplies every runtime input; no
  futures curve or external series is required.
- R4: PASS. Runtime uses native OHLC, ATR, calendar, quote, deal, position,
  and framework state only; no trained model, banned indicator, external
  feed, grid, martingale, scale-in, or pyramiding.

## Claim And Safety Boundary

The source papers use rolling futures and broad portfolios. Continuous-CFD
roll construction, financing, gaps, limited history, one-name breadth, and
agreement sparsity are binding Q02 risks. Direct WTI exposure is economically
different from the current XAU/SP500/NDX/XNG book, but only the unchanged
portfolio gate may establish realized decorrelation.

This approval covers one card, deterministic allocation `QM5_20205`, one
magic row, one V5 build, one `RISK_FIXED` backtest setfile, and one paced Q02
enqueue. It does not authorize a live setfile, AutoTrading, `T_Live`, a deploy
or T_Live manifest, portfolio admission, a portfolio-gate change, or a
correlation waiver.

