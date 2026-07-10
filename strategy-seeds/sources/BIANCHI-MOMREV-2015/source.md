---
source_id: BIANCHI-MOMREV-2015
title: Combining Momentum with Reversal in Commodity Futures
publisher: Journal of Banking and Finance
source_type: peer_reviewed_paper_with_open_accepted_manuscript
status: cards_ready
approval_basis: OWNER mission directive 2026-07-10
created: 2026-07-10
created_by: Codex
cards_extracted:
  - energy-momrev
---

# Bianchi-Drew-Fan Commodity Momentum-Reversal Source Packet

## Source Identity And Approval

- Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua (2015),
  "Combining Momentum with Reversal in Commodity Futures", *Journal of
  Banking & Finance* 59, 423-444.
- Published DOI: https://doi.org/10.1016/j.jbankfin.2015.07.006.
- Full accepted manuscript: Griffith University Research Repository,
  https://research-repository.griffith.edu.au/server/api/core/bitstreams/a06d0c4b-7648-4269-a5d7-0b1f2e4e065a/content.
- Approval basis: the OWNER mission dated 2026-07-10 directs Codex to select,
  card, build, and enqueue one new structural commodity/energy sleeve.

The complete 59-page accepted manuscript was reviewed end to end, including
method, post-formation analysis, factor tests, robustness tests, transaction
cost discussion, tables, figures, appendix, conclusions, and references.

## Bounded Extraction

The paper uses monthly returns for 27 S&P GSCI commodity futures from 1977 to
2011 and an independent 26-contract Dow Jones-UBS dataset from 1991 to 2011.
At the beginning of each month it first sorts commodities on returns over a
momentum horizon, then sorts the winner and loser groups on a longer reversal
horizon. Its preferred `Mom12-Ctr18` portfolio buys 12-month winners that are
18-month losers, shorts 12-month losers that are 18-month winners, and holds
the long-short portfolio for one month. The formation horizons overlap; the
paper reports that skipping the overlap weakens the combination.

This packet extracts one mission-bounded carrier: `energy-momrev`. On the
first tradable D1 bar of each broker month it ranks `XTIUSD.DWX` and
`XNGUSD.DWX` by synchronized 12-completed-month and 18-completed-month log
returns. It opens a package only when the two horizons rank the legs in
opposite order: long the 12-month winner/18-month loser and short the
12-month loser/18-month winner. Otherwise it remains flat.

The source forms extreme portfolios inside a broad cross-section. A two-leg
energy rank is therefore a constrained, falsifiable translation rather than a
replication. Other ranking/holding combinations in the paper are robustness
variants of the same double-sort family and are not extracted for this
one-edge mission.

## QM Translation

- Host: `XTIUSD.DWX`, D1; companion: `XNGUSD.DWX`, D1.
- Decision: first tradable D1 bar of each broker month.
- Formation endpoints: completed month-end closes only; no current-month data.
- Momentum rank: synchronized 12-completed-month log return.
- Reversal rank: synchronized 18-completed-month log return.
- Long XTI / short XNG only when XTI is the 12-month winner and 18-month loser.
- Short XTI / long XNG only when XTI is the 12-month loser and 18-month winner.
- Same rank at both horizons, ties, stale endpoints, or insufficient history:
  flat for that month.
- Close and reconsider on the next month transition; 35-day stale guard.
- Split the fixed package risk equally and attach frozen per-leg ATR stops.

## Evidence And Limitations

- The source reports that `Mom12-Ctr18` is its strongest diversified
  double-sort and remains significant across subsamples and the independent
  dataset. Those portfolio results are not an expectation for this carrier.
- Table 10 reports correlations close to zero between the source double-sort
  and the S&P 500, GSCI, and U.S. equity momentum. This motivates the sleeve;
  it does not establish correlation for two Darwinex CFDs. Q09 is authoritative.
- Table 4 also reports substantial volatility, tail loss, and drawdown. Equal
  fixed-risk sizing and hard stops limit trade risk but do not reproduce the
  source's portfolio distribution.
- The paper uses continuous exchange-traded futures series and a broad
  cross-section. Darwinex CFDs do not reproduce collateral yield, futures
  roll, term structure, or the paper's tercile membership.
- Crude oil and natural gas are explicit energy constituents in both source
  datasets, but two instruments cannot recreate a 27-future double sort.
- Friday close is disabled to preserve the one-month hold. Monthly rollover,
  hard stops, orphan repair, and the 35-day stale guard remain active.

## Non-Duplicate Boundary

- Not `QM5_12567_cum-rsi2-commodity`: no RSI, pullback, long-only state, or
  short holding period.
- Not `QM5_12623_comm-mom-rev-interaction-xauusd`: that is a single-symbol
  3-month trend filtered by 4-week confirmation, not a cross-sectional 12/18
  horizon disagreement package.
- Not `QM5_12733_xti-xng-xmom`: raw 126-D1 relative momentum always ranks the
  two legs; this card trades only when a longer reversal rank contradicts it.
- Not `QM5_12840_xti-xng-rspread`: no z-score or spread fade.
- Not `QM5_13089_xti-xng-carry`: no swap or carry input.
- Not `QM5_13113_energy-mom-ivol`: no residual-volatility regression.
- Not `QM5_13115_energy-samecal`: no same-calendar-month history.
- Not `QM5_13118_energy-skew-rank`: no third moment or skewness rank.
- Exact source, strategy ID, slug, two-horizon rule, universe, and cadence were
  clean in the pre-allocation repository search.

## Runtime Guardrails

- Native XTI/XNG D1 closes, ATR, spread, broker calendar, symbol metadata, and
  framework position state only.
- No RSI, MACD, COT, inventory, weather, volume, open interest, futures chain,
  external file/API, ML, adaptive PnL fit, grid, martingale, or pyramiding.
- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, split equally across the
  legs. No live setfile or deploy artifact is created.

## Reputable-Source Criteria

- R1: PASS. Peer-reviewed *Journal of Banking & Finance* paper with DOI and a
  complete institutional-repository accepted manuscript; crude oil and
  natural gas are explicit source contracts.
- R2: PASS. Fixed 12/18 completed-month returns, deterministic opposite-rank
  gate, monthly hold, ATR hard stops, orphan repair, and stale exit.
- R3: PASS. Registered XTIUSD.DWX and XNGUSD.DWX D1 data only.
- R4: PASS. Deterministic price arithmetic; no banned indicator, ML, external
  runtime data, grid, martingale, pyramiding, or adaptive fitting.

