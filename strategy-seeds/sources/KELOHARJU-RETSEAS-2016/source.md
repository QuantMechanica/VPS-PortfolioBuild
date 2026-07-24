---
source_id: KELOHARJU-RETSEAS-2016
title: Return Seasonalities / Common Factors in Return Seasonalities
publisher: Journal of Finance / NBER
source_type: peer_reviewed_paper_with_open_working_paper
status: cards_ready
approval_basis: OWNER mission directive 2026-07-10
created: 2026-07-10
created_by: Codex
cards_extracted:
  - energy-samecal
  - wti-samecal
  - xng-samecal
---

# Keloharju, Linnainmaa, and Nyberg Return-Seasonality Source Packet

## Source Identity And Approval

- Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
  "Return Seasonalities", *The Journal of Finance* 71(4), 1557-1590.
- Published DOI: https://doi.org/10.1111/jofi.12398.
- Full open working-paper version: NBER Working Paper 20815,
  https://www.nber.org/papers/w20815 and
  https://www.nber.org/system/files/working_papers/w20815/w20815.pdf.
- Approval basis: the OWNER mission dated 2026-07-10 directs Codex to select,
  card, build, and enqueue one new structural commodity/energy sleeve.

The complete 57-page NBER version was reviewed, including the model, data,
commodity construction, portfolio rules, risk analysis, robustness, tables,
conclusions, and references. The later *Journal of Finance* publication is the
peer-reviewed primary citation; the NBER file is the reproducible full text.

## Bounded Extraction

The paper tests whether assets with high historical returns in a given calendar
month continue to outperform other assets in that same calendar month. Its
commodity panel contains 24 futures, explicitly including crude oil and natural
gas, from January 1970 through July 2011. Each month it ranks eligible
commodities by their average return in that calendar month over prior history,
using at least five years of data, then buys the high-ranked group and sells the
low-ranked group.

This packet extracts three constrained energy carriers. `energy-samecal` ranks
only `XTIUSD.DWX` and `XNGUSD.DWX` by their historical same-calendar-month
returns, buys the higher seasonal leg, and shorts the lower seasonal leg.
`wti-samecal` tests the WTI component as an absolute seasonal-sign carrier:
buy WTI when its own historical same-calendar average is positive and sell it
when that average is negative. `xng-samecal` applies the same locked
absolute-sign translation to natural gas as a monthly structural carrier that
is materially different from the incumbent short-horizon cumulative-RSI2
pullback. The source uses a broad 24-future cross-section and up to 20 years of
history. All three DWX ports are falsifiable reductions, not replications of
the paper's diversified portfolio.

## QM Translation

On the first tradable D1 bar of each broker month, the EA reconstructs each
leg's completed return for that same calendar month in prior years:

`r(symbol, year, month) = ln(month_end_close / prior_month_end_close)`.

For every year in which both energy legs have synchronized data, it computes
the cross-sectional relative seasonal return:

`relative_return = r_XTI - r_XNG`.

The signal is the average relative return across the bounded historical window.
A positive signal opens long XTI / short XNG; a negative signal opens short XTI
/ long XNG. Both legs close and rerank at the next month transition. Per-leg
ATR hard stops, orphan cleanup, and a 35-day stale guard implement the V5 risk
contract without changing the source ranking direction.

The WTI-only extraction uses the same completed-month estimator but compares
WTI's own historical average with zero instead of comparing it with XNG. A
positive average opens one long `XTIUSD.DWX` package and a negative average
opens one short package. It closes and recomputes at the next month boundary,
requires at least five prior same-month samples, and never trades either leg
of `energy-samecal`. This absolute-sign translation is not a result separately
reported by the paper; Q02 must reject it if the broad cross-sectional finding
does not survive the single-CFD reduction.

The XNG-only extraction is the corresponding natural-gas falsification port.
It averages only `XNGUSD.DWX` returns from the same calendar month in prior
years, compares that average with zero, and holds the resulting sign for one
broker month. It never reads or trades WTI. The source explicitly includes
natural-gas futures in its 24-contract panel, but it does not report a
standalone natural-gas time-series sign result. That gap is binding and no
source performance claim is transferred to the CFD carrier.

## Evidence And Limitations

- The source commodity portfolio earns 0.93% per month in its sample with a
  reported t-value of 1.93; this is marginal, diversified evidence, not a
  forecast for a two-leg CFD basket.
- The source uses 24 exchange-traded futures and long/short tail portfolios;
  this port has only two continuous CFD legs.
- The source uses a 20-year estimation window when available. Local DWX
  history supports a shorter bounded window, with at least five complete
  synchronized same-month samples required.
- The source reports near-zero correlation between its commodity seasonality
  strategy and equity seasonality strategies. That does not establish
  correlation against the current QM book; only Q09 may do so.
- Futures rolls, collateral returns, and contract selection are absent from the
  continuous Darwinex CFDs. Q02 and later gates must reject the port if that
  translation destroys economics.

## Non-Duplicate Boundary

- Not `QM5_12733_xti-xng-xmom`: that ranks recent price momentum, not recurring
  same-calendar-month history.
- Not `QM5_12840_xti-xng-rspread`: that fades a short-horizon standardized
  return spread, while this basket holds the historical seasonal rank.
- Not `QM5_12850_xti-xng-vcb`: no volatility-contraction breakout.
- Not `QM5_13089_xti-xng-carry`: no swap/carry rank.
- Not `QM5_13113_energy-mom-ivol`: no momentum or residual-volatility screen.
- Not the single-symbol WTI or XNG month cards: those use fixed directions in
  selected months; this reranks two energy legs independently every month from
  rolling same-calendar-month evidence.
- Not `QM5_12567_cum-rsi2-commodity`: no RSI, pullback, oscillator, or
  directional single-leg commodity logic.

For `wti-samecal`, the deterministic helper reports the expected fuzzy match
to `energy-samecal`; manual review resolves it as non-identical. The existing
EA compares the XTI seasonal estimate with the XNG seasonal estimate and
requires a jointly sized two-leg basket. The WTI card compares only the XTI
estimate with zero and forbids an XNG leg. Fixed-direction month cards,
contiguous-return trend systems, and the one-year stock-seasonality EA use
different signals or markets. No exact single-WTI historical same-calendar
average-sign carrier exists in the repository.

For `xng-samecal`, the helper again reports the expected `energy-samecal`
fuzzy sibling. Manual repository review also identifies `wti-samecal` as the
same estimator on a different carrier. The new EA is a governed symbol port,
not a claim to a globally new signal family: it compares XNG with zero, owns
one XNG position, and cannot read or trade XTI. No existing EA combines that
single-XNG information object with the historical same-calendar average-sign
rule. `QM5_12567` instead uses a 200-day trend filter and cumulative RSI(2)
pullback state with a short holding period. The port is therefore a new
XNG-carrier/mechanic combination, while Q09 remains the only authority on
realized correlation.

Repository dedup was run before each allocation. The original
`energy-samecal` basket returned `CLEAN`. The later single-carrier checks used
their own strategy IDs and complete mechanic fingerprints; each surfaced the
expected sibling for manual review rather than an exact duplicate. The XNG
check used slug `xng-samecal`, strategy ID
`KELOHARJU-RETSEAS-2016_XNG_S03`, and mechanic
`single-XNG historical same-calendar-month average-sign monthly renewal`.

## Runtime Guardrails

- Native `XTIUSD.DWX` and `XNGUSD.DWX` D1 OHLC, ATR, spread, broker calendar,
  symbol metadata, and framework position state only.
- No futures curve, contract chain, inventory, volume, open interest, COT,
  EIA, weather, external file, API, ML, adaptive PnL fit, grid, martingale, or
  pyramiding.
- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, split equally across the
  two legs for `energy-samecal`; `wti-samecal` applies the same fixed budget to
  its sole WTI position and `xng-samecal` applies it to its sole XNG position.
  No live setfile is created.
- Friday close is disabled for the source-aligned monthly package; monthly
  reset, per-leg ATR stops, orphan repair, and the 35-day stale guard remain.

## Reputable-Source Criteria

- R1: PASS. Peer-reviewed *Journal of Finance* paper with DOI and complete open
  NBER version; explicit crude-oil and natural-gas membership and commodity
  portfolio evidence.
- R2: PASS. Fixed same-calendar-month historical return estimate, deterministic
  cross-sectional rank, monthly rebalance, ATR hard stops, and stale exit.
- R3: PASS. Registered XTIUSD.DWX and XNGUSD.DWX D1 data only.
- R4: PASS. Deterministic arithmetic; no banned indicator, ML, external runtime
  data, grid, martingale, pyramiding, or adaptive fitting.
