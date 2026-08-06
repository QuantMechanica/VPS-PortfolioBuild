---
source_id: VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026
title: XAU/XAG cross-sectional momentum during the CTA turn-of-month flow window
publisher: SSRN / Journal of Banking & Finance
source_type: governed_composite
status: approved_source_complete
approval_basis: OWNER commodity/energy sleeve mission 2026-08-06
created: 2026-08-06
created_by: Research+Development
uri: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2515900
cards_extracted:
  - xauxag-tom-xmom3
---

# XAU/XAG MOM-TOM Cross-Sectional Momentum Source Packet

## Approval And Review Scope

The OWNER mission dated 2026-08-06 authorizes one new structural
commodity/energy sleeve, card, non-live build, and paced Q02 enqueue. This
packet combines two already governed source lineages without importing either
source's performance claims:

- `VANHEMERT-MOMTOM-2014`: Otto van Hemert, "The MOM-TOM Effect: Detecting
  the Market Impact of CTA Trading," SSRN 2515900 (2014). The public SSRN
  record and the complete governed source packet were reviewed. The paper
  defines the TOM period as the last two days of a month and the first day of
  the next month and studies whether CTA inflows temporarily push momentum
  positions in their existing direction.
- `FMR-MOMTS-2010`: Fuertes, Miffre, and Rallis (2010), "Tactical Allocation
  in Commodity Futures Markets: Combining Momentum and Term Structure
  Signals," *Journal of Banking & Finance* 34(10), 2530-2548, DOI
  `10.1016/j.jbankfin.2010.04.009`. Its complete 47-page accepted manuscript
  has a durable end-to-end review. Pages 6-7 and 17-18 specify commodity
  cross-sectional momentum using average past returns at one-, three-, and
  twelve-month formation horizons with a one-month hold.

The peer-reviewed FMR paper supplies the three-month commodity rank. The
Van Hemert working paper supplies only the short turn-of-month flow window.
Neither source tests their intersection, a two-metal cross-section, Darwinex
CFDs, fixed-dollar risk, ATR stops, or the QM book.

## Bounded Mechanization

For each broker-calendar cycle keyed to the month being ended, the candidate
may attempt one two-leg package during exactly the last two calendar dates of
that month or the first calendar date of the next month. This is a transparent
calendar-date proxy for the paper's trading-day window; weekends and holidays
can shorten or remove a cycle.

To prevent the signal from changing across the three-date window, formation
ends at the completed month immediately before the cycle month. For each of
`XAUUSD.DWX` and `XAGUSD.DWX`, the EA reconstructs four synchronized month-end
closes and averages the three consecutive simple monthly returns. It buys the
higher-average-return metal and shorts the lower. Equality or invalid history
consumes the cycle flat. The package is closed on the first D1 bar outside the
same TOM cycle or after six calendar days.

One `RISK_FIXED=1000` package budget is divided equally between independent
`3.5 * ATR(20,D1)` hard-stop risks. There is no take-profit. Both news axes and
Friday close are disabled so the native price-only signal can span a
month-end weekend. Persistent attempt state, deal-history recovery, two-leg
validation, and immediate orphan repair are V5 safety translations.

## Claim And Translation Boundary

FMR studies diversified collateralized commodity-futures portfolios, not a
two-name precious-metals CFD pair. Van Hemert studies returns to trend-following
CTA indices and a commodity-futures replication, not XAU/XAG cross-sectional
momentum. Broker calendar dates are not exchange trading-day ranks; Darwinex
continuous CFDs differ from maturity-specific futures; equal stop risk is not
dollar, beta, volatility, or factor neutrality.

No source PF, return, alpha, Sharpe ratio, drawdown, cost, trade count,
neutrality, or portfolio-correlation result transfers. Q02 must establish
density and economics; Q09 alone may establish realized decorrelation.

## Non-Duplicate Boundary

The canonical pre-allocation check found no exact identity and only the
expected fuzzy XAU/XAG one-, three-, and twelve-month momentum siblings.
Manual review resolves them:

- `QM5_20184_xauxag-xmom3` forms the same source-declared three-month rank at
  a month boundary and holds for the entire next month.
- This extraction freezes the rank before the cycle, exposes only the
  source-defined three-date TOM window, and is flat for the rest of the month.
- `QM5_20057` and `QM5_20050` use different one- and twelve-month formation
  horizons and month-long holds.
- Ratio z-scores, OLS/M-TAR/quantile residuals, breakouts, weekday/weekend
  effects, volatility ranks, and same-calendar baskets use different state
  variables or decision clocks.
- Existing WTI, XNG, and Brent TOM EAs are outright time-series systems on
  different carriers, not an opposite-direction XAU/XAG rank.

The three-date exposure window, cycle-frozen three-month rank, and opposite
two-leg package are jointly load-bearing. Replacing the TOM exit with a
month-long hold recreates `QM5_20184`.

## R1-R4

- R1 reputable source: PASS. One peer-reviewed JBF article with DOI and a
  complete institutional-manuscript read, plus a named-author public SSRN
  working paper and an existing governed source lineage.
- R2 mechanical: PASS. Fixed cycle dates, four exact synchronized month ends,
  three simple-return average, strict rank, shared fixed risk, hard stops,
  persisted attempt, window exit, stale exit, and orphan repair.
- R3 data available: PASS. Registered `XAUUSD.DWX` and `XAGUSD.DWX` D1 routes
  and the governed logical-basket tester path require no external runtime data.
- R4 no ML/banned logic: PASS. Native calendar/OHLC/ATR/execution arithmetic
  only; no trained model, banned indicator, external feed, grid, martingale,
  scale-in, or pyramiding.
