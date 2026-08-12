---
source_id: KELOHARJU-FMR-XAUXAG-SAMECAL-2026
title: XAU/XAG same-calendar-month relative seasonality composite
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
  - KELOHARJU-FMR-XAUXAG-SAMECAL-2026_S01
---

# XAU/XAG Same-Calendar Relative Seasonality Source Packet

## Approval and review scope

The OWNER mission dated 2026-07-31 directs one new structural,
low-frequency commodity card, build, and paced Q02 enqueue. This packet joins
two already governed, completely reviewed peer-reviewed source lineages:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590.
   Governed packet: `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`.
2. Fuertes, Ana-Maria; Miffre, Joelle; and Rallis, Georgios (2010),
   "Tactical Allocation in Commodity Futures Markets: Combining Momentum and
   Term Structure Signals," *Journal of Banking & Finance* 34(10), 2530-2548.
   Governed packet: `strategy-seeds/sources/FMR-MOMTS-2010/source.md`.

Fresh routing of both institutional PDF URLs returned
`DEFERRED:SOURCE_POLICY`. The deterministic evidence is retained in
`retrieval_route_20260731.json`; no newly fetched page text is used. R1 rests
on the pre-existing complete repository reviews.

## Findings used

- Keloharju, Linnainmaa, and Nyberg define a cross-sectional commodity signal
  from each contract's average return in the same calendar month over prior
  years. Their governed construction requires at least five prior annual
  observations and buys high-ranked commodities while selling low-ranked
  commodities for the decision month.
- Fuertes, Miffre, and Rallis establish the governed XAU/XAG commodity-futures
  cross-sectional carrier and one-month holding translation. That lineage
  supports using gold and silver as two opposite commodity legs, but supplies
  no same-calendar result.
- Neither paper tests a two-name XAU/XAG same-calendar basket, Darwinex CFDs,
  equal stop-risk sizing, per-leg ATR stops, or QM portfolio correlation. The
  conjunction is a predeclared falsification hypothesis, not an inherited
  performance claim.

## Bounded mechanization

`KELOHARJU-FMR-XAUXAG-SAMECAL-2026_S01` locks one monthly relative-seasonality
translation:

- host/slot 0: `XAUUSD.DWX`, D1; companion/slot 1: `XAGUSD.DWX`, D1;
- decision: first tradable host D1 bar of every broker calendar month;
- history: the decision calendar month's completed log return in exactly the
  ten prior years, using only synchronized XAU/XAG month-end observations and
  requiring at least five valid paired samples;
- score: mean XAU same-calendar return minus mean XAG same-calendar return;
- direction: positive score buys XAU and sells XAG; negative score sells XAU
  and buys XAG; exact zero or invalid state remains flat;
- lifecycle: close and rerank at the next month boundary, with a 40-day stale
  guard, frozen `3.5 * ATR(20)` per-leg stops, and one consumed attempt per
  broker month; and
- Q02 risk: one `RISK_FIXED=1000` package budget split equally by stop risk,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The two opposite legs target relative precious-metal seasonality. They do not
prove dollar, beta, volatility, or portfolio neutrality. Q02 and later gates
must reject the carrier if narrow-cross-section costs or common-metal exposure
dominate.

## Non-duplicate boundary

The deterministic pre-allocation scan covered 4,243 registry rows and 377
cards and returned `CLEAN` for slug `xauxag-samecal`, strategy ID
`KELOHARJU-FMR-XAUXAG-SAMECAL-2026_S01`, and the exact mechanic.

Manual semantic review resolved every existing XAU/XAG family:

- `QM5_20157_xau-xag-ratio` fades a rolling log-price ratio z-score.
- `QM5_20161_xauxag-ols-rv` fades a rolling OLS residual z-score.
- `QM5_20012_xauxag-cmtar` uses a fixed published threshold residual.
- `QM5_13205_xau-xag-qc` trades conditional-quantile envelopes.
- `QM5_12724_cme-xauxag-brk` follows ratio channel breakouts.
- `QM5_12862_xauxag-rspread` fades standardized ten-D1 return shocks.
- `QM5_20019_xauxag-wkend` and `QM5_20095_auag-mon-diff` are session-calendar
  packages, not prior-year same-month estimators.
- `QM5_20057`, `QM5_20184`, and `QM5_20050` rank contiguous one-, three-, and
  twelve-month returns; this card ranks recurring returns for the decision
  calendar month across prior years.
- `QM5_13115_energy-samecal` uses the same source information family on the
  economically different XTI/XNG energy pair; it cannot trade either metal.

The same-calendar estimator, XAU/XAG pair, monthly rank, and opposite-leg hold
are jointly load-bearing. Replacing the estimator with a contiguous return,
ratio, residual, channel, weekday, or weekend state recreates an existing EA.

## Reputable-source criteria

- R1: PASS. Two named-author peer-reviewed lineages with complete durable
  repository reviews; the primary seasonality paper is in *The Journal of
  Finance* and the carrier paper is in *Journal of Banking & Finance*.
- R2: PASS. Calendar endpoints, ten-year bounded estimator, five-sample floor,
  rank direction, attempt ledger, stops, spreads, and exits are deterministic
  and frozen.
- R3: PASS. Registered synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 routes
  supply every runtime input.
- R4: PASS. Runtime uses native OHLC, ATR, calendar, symbol, deal, position,
  and framework state only; no trained model, external feed, grid, martingale,
  scale-in, or pyramiding.

## Evidence and claim boundary

No source PF, drawdown, trade count, cost result, hedge ratio, CFD/futures
basis assumption, or portfolio correlation transfers to QM. Narrow two-name
breadth, limited same-calendar samples, continuous-CFD rolls, financing,
gaps, legging, stop asymmetry, and common precious-metal beta are binding Q02
and downstream kill risks.

This approval covers one card, one deterministic EA allocation, two magic
rows, one V5 build, one logical-basket `RISK_FIXED` setfile, and one paced Q02
enqueue. It does not authorize a live setfile, AutoTrading, `T_Live`, a deploy
manifest, portfolio admission, a portfolio-gate change, or a correlation
waiver.
