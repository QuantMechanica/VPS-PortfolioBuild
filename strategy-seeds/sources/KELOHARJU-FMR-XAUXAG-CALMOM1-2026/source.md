---
source_id: KELOHARJU-FMR-XAUXAG-CALMOM1-2026
title: XAU/XAG same-calendar and one-month relative-momentum agreement
publisher: Journal of Finance / Journal of Banking & Finance
source_type: peer_reviewed_composite_lineage
status: approved_source_complete
approval_basis: OWNER commodity/energy sleeve mission 2026-07-31
created: 2026-07-31
created_by: Research+Development
parent_sources:
  - KELOHARJU-RETSEAS-2016
  - FMR-MOMTS-2010
strategy_ids:
  - KELOHARJU-FMR-XAUXAG-CALMOM1-2026_S01
---

# XAU/XAG Same-Calendar Momentum-Agreement Source Packet

## Approval And Review Scope

The OWNER mission dated 2026-07-31 directs one new structural,
low-frequency commodity card, build, and paced Q02 enqueue. This packet joins
two already approved and completely reviewed peer-reviewed source lineages:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI https://doi.org/10.1111/jofi.12398. The complete 57-page NBER version
   was reviewed under `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`.
2. Fuertes, Ana-Maria; Miffre, Joelle; and Rallis, Georgios (2010),
   "Tactical Allocation in Commodity Futures Markets: Combining Momentum and
   Term Structure Signals," *Journal of Banking & Finance* 34(10), 2530-2548,
   DOI https://doi.org/10.1016/j.jbankfin.2010.04.009. The complete 47-page
   accepted manuscript was reviewed under
   `strategy-seeds/sources/FMR-MOMTS-2010/source.md`.

Both bounded repository packets were read completely for this extraction.
No fresh public-page text is used and no external source is read at runtime.

## Findings Used

- Keloharju, Linnainmaa, and Nyberg define a commodity signal from each
  contract's average return in the same calendar month over prior years. The
  governed construction requires at least five prior annual observations and
  buys high-ranked commodities while selling low-ranked commodities.
- Fuertes, Miffre, and Rallis explicitly test one-month cross-sectional
  commodity momentum with a one-month hold: buy recent winners and sell recent
  losers.
- Both papers use diversified futures cross-sections. Neither tests the
  conjunction below, a two-name XAU/XAG CFD basket, equal stop-risk legs,
  Darwinex month boundaries, broker costs, or the QM portfolio.

No source profit factor, return, drawdown, hit rate, trade count, hedge ratio,
or portfolio-correlation statistic is imported.

## Bounded Mechanization

`KELOHARJU-FMR-XAUXAG-CALMOM1-2026_S01` locks one monthly two-state package:

- host/slot 0: `XAUUSD.DWX`, D1; companion/slot 1: `XAGUSD.DWX`, D1;
- decision: first tradable XAU D1 bar of every broker calendar month;
- seasonal state: mean of synchronized XAU-minus-XAG log returns for the
  decision calendar month in exactly the ten prior years, requiring at least
  five valid paired observations;
- momentum state: the synchronized XAU-minus-XAG log return over the
  immediately completed broker month;
- positive agreement buys XAU and sells XAG; negative agreement sells XAU and
  buys XAG; disagreement, exact zero, or invalid state remains flat;
- close and rerank at the next month boundary, with a 40-calendar-day stale
  guard, frozen `3.5 * ATR(20)` hard stops, and one consumed attempt per month;
- one `RISK_FIXED=1000` package budget split equally by stop risk,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The opposite legs target relative precious-metal seasonality confirmed by a
distinct recent-return clock. They do not prove dollar, beta, volatility, or
portfolio neutrality. Q02 and later gates must reject the narrow carrier if
costs, basis, common-metal exposure, or sparse agreement dominate.

## Non-Duplicate Boundary

The deterministic pre-allocation scan covered 4,246 registry rows and 377
cards and returned `CLEAN` for slug `xauxag-calmom1`, strategy ID
`KELOHARJU-FMR-XAUXAG-CALMOM1-2026_S01`, and the exact mechanic.

Manual semantic review resolves the nearest systems:

- `QM5_20186_xauxag-samecal` trades the same-calendar rank alone and never
  requires an independent recent-return state.
- `QM5_20057_xauxag-xmom1` trades the immediately completed relative month
  alone and never estimates recurring calendar-month history.
- `QM5_20184_xauxag-xmom3` averages three contiguous completed returns and has
  no recurring same-calendar estimator.
- `QM5_20157_xau-xag-ratio` and `QM5_20161_xauxag-ols-rv` fade continuous
  ratio or regression residual z-scores; this package follows two agreeing
  completed-return states and has no z-score.
- `QM5_12862_xauxag-rspread` fades a standardized ten-D1 shock, while this
  package is monthly and follows rather than fades its one-month rank.
- `QM5_20136_wti-caltrend` is an outright WTI carrier using a 63-D1 trend. It
  cannot trade either precious-metal leg or form a relative XAU/XAG package.

The recurring seasonal estimator, exact immediately completed relative month,
strict sign agreement, and opposite two-leg package are jointly load-bearing.
Removing either state recreates a built parent; replacing agreement with a
ratio, residual, breakout, reversal, or different horizon recreates another
family.

## Reputable-Source Criteria

- R1: PASS. Two named-author peer-reviewed lineages in *The Journal of
  Finance* and *Journal of Banking & Finance*, each with a DOI and a complete
  durable repository review.
- R2: PASS. Calendar endpoints, ten-year bounded estimator, five-sample floor,
  exact one-month return, agreement direction, attempt state, stops, spreads,
  and exits are deterministic and frozen.
- R3: PASS. Registered synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 routes
  supply every runtime input.
- R4: PASS. Runtime uses native OHLC, ATR, calendar, symbol, deal, position,
  and framework state only; no trained model, external feed, grid, martingale,
  scale-in, or pyramiding.

## Claim And Safety Boundary

The interaction is a predeclared QM falsification hypothesis, not an
author-tested portfolio. Narrow two-name breadth, ten-year same-calendar
sampling, continuous-CFD rolls, financing, gaps, legging, stop asymmetry, and
common precious-metal beta are binding Q02 and downstream kill risks.

This approval covers one card, deterministic allocation `QM5_20189`, two
magic rows, one V5 build, one logical-basket `RISK_FIXED` setfile, one basket
manifest, and one paced Q02 enqueue. It does not authorize a live setfile,
AutoTrading, `T_Live`, a deploy or T_Live manifest, portfolio admission, a
portfolio-gate change, or a correlation waiver.
