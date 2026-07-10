---
source_id: AMP-VALUE-2013
title: Value and Momentum Everywhere
publisher: The Journal of Finance
source_type: peer_reviewed_paper
status: cards_ready
approval_basis: OWNER commodity-sleeve mission directive 2026-07-10
created: 2026-07-10
created_by: Codex
cards_extracted:
  - energy-val-rank
---

# Asness-Moskowitz-Pedersen Commodity Value Source Packet

## Source Identity And Approval

- Asness, Clifford S.; Moskowitz, Tobias J.; and Pedersen, Lasse Heje
  (2013), "Value and Momentum Everywhere", *The Journal of Finance* 68(3),
  929-985, DOI https://doi.org/10.1111/jofi.12021.
- Author-hosted full text:
  https://w4.stern.nyu.edu/facdir/lpederse/papers/ValMomEverywhere.pdf.
- Full 57-page paper and the complete 11-page Internet Appendix reviewed,
  including data, signal construction, results, risk tests, implementation
  discussion, robustness tables, conclusions, and references.
- Approval basis: the OWNER mission dated 2026-07-10 directs Codex to select,
  card, build, and enqueue one new structural commodity/energy sleeve.

## Bounded Extraction And Existing Coverage

The paper studies value and momentum jointly across eight markets and asset
classes. For commodities it uses 27 futures, explicitly including WTI crude
and natural gas, at monthly frequency. Its commodity value signal is the log
of the average spot price 4.5 to 5.5 years before the decision divided by the
most recent spot price. It ranks the commodity cross-section and forms a
zero-cost long-short portfolio.

This packet extracts the missing pure commodity-value mechanic into one
mission-bounded card, `energy-val-rank`. Existing repository work already
covers the paper's adjacent mechanics: `QM5_1057_asness-xsmom-rank` covers
cross-sectional momentum lineage, while
`QM5_12919_amp-value-momentum-xasset` covers a value/momentum combination on
an equity-index/FX subset and explicitly excludes commodities. No second card
is created from this packet.

## Source Rule And QM Translation

- Source current price: the most recent commodity spot price at the monthly
  portfolio decision.
- Source anchor: average commodity spot price from 4.5 to 5.5 years earlier.
- Source value score: `ln(anchor_average / current_spot)`; a higher score is
  cheaper.
- Source portfolio: long high-value commodities and short low-value
  commodities, rebalanced monthly; non-stock portfolios are equal weighted.
- QM universe: `XTIUSD.DWX` and `XNGUSD.DWX` only.
- QM current proxy: latest valid completed D1 close before the current broker-
  month boundary.
- QM anchor proxy: arithmetic mean of the 13 completed month-end D1 closes at
  inclusive lags 54 through 66 months.
- QM rank: buy the higher score and sell the lower score; exact ties stay flat.
- QM lifecycle: close and rerank at the next broker month, with a 35-day stale
  guard, per-leg ATR hard stops, and orphan/package repair.

The 54-66 inclusive endpoint rule is the deterministic monthly discretization
of the source's stated 4.5-5.5-year averaging window. It is locked for the
baseline and is not a tuned parameter.

## Evidence Boundary

The source's commodity results use 27 rolled futures, futures excess returns,
and a broad cross-section. The QM carrier narrows that evidence to two
Darwinex CFDs and uses D1 CFD closes as a spot-price proxy. It does not
reproduce contract rolls, collateral, term structure, source rank weights, or
the source universe.

No source return, Sharpe ratio, drawdown, correlation, or cost estimate is
imported into the QM prior. The paper's commodity table is lineage evidence,
not a performance forecast for an XTI/XNG CFD pair.

## Non-Duplicate Boundary

- Not `QM5_12567_cum-rsi2-commodity`: no RSI, two-day pullback, long-only
  state, or five-day holding rule.
- Not `QM5_12733_xti-xng-xmom`: no 12-month momentum winner-following rule.
- Not `QM5_12840_xti-xng-rspread`: no recent-return spread or z-score fade.
- Not `QM5_12895_xng-6m-reversal`, `QM5_12979_wti-6m-reversal`, or the
  52-week anchors: this is a paired 54-66-month cross-sectional value rank,
  not a single-leg 6-12-month reversal.
- Not `QM5_13089_xti-xng-carry`: no broker swap or futures carry signal.
- Not `QM5_13113_energy-mom-ivol`, `QM5_13115_energy-samecal`,
  `QM5_13118_energy-skew-rank`, `QM5_13120_energy-momrev`, or
  `QM5_13121_energy-tfmom`: no residual volatility, calendar-month history,
  skewness, momentum-reversal disagreement, or trend confirmation.
- Not `QM5_12919_amp-value-momentum-xasset`: that EA combines 12-month
  momentum and 60-month value across eight index/FX instruments and explicitly
  excludes XTI/XNG; this card is pure value, paired, and commodity-only.

The repository dedup helper returned `CLEAN` before the atomic EA-ID
allocation for slug `energy-val-rank`, strategy ID
`AMP-VALUE-2013_XTI_XNG_S01`, authors, and the complete mechanic.

## Runtime Guardrails

- Native XTI/XNG D1 closes, ATR, spread, broker calendar, symbol metadata, and
  framework position state only.
- No RSI, COT, inventory, futures chain, external file/API, ML, adaptive PnL
  fit, grid, martingale, pyramiding, or dynamic parameter fitting.
- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`; no live artifact is made.

## Reputable-Source Criteria

- R1 PASS: peer-reviewed *Journal of Finance* article with DOI, author-hosted
  full text, Internet Appendix, and explicit WTI/natural-gas source universe.
- R2 PASS: fixed 54-66-month anchor average, closed-form log value score,
  deterministic two-asset rank, monthly renewal, and deterministic exits.
- R3 PASS: the carrier uses registered `XTIUSD.DWX` and `XNGUSD.DWX` D1
  history; the long warm-up is an explicit Q02 falsification risk.
- R4 PASS: deterministic price arithmetic only; no banned indicator, ML,
  external runtime dependency, grid, martingale, or adaptive fitting.
