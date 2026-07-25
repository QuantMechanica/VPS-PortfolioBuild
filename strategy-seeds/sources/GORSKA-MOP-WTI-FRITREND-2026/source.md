---
source_id: GORSKA-MOP-WTI-FRITREND-2026
title: "WTI Friday Calendar Premium With Positive 12-Month Trend"
source_type: governed_composite_of_academic_papers
quality_tier: A
status: approved_for_cards
approved_for_cards: true
approval_record: "OWNER commodity/energy sleeve mission, 2026-07-25"
created: 2026-07-25
created_by: Research+Development
parent_sources:
  - GORSKA-WTI-CAL-2015
  - MOP-TSMOM-2012
cards_extracted:
  - wti-fri-trend
---

# WTI Friday Calendar / Trend Composite Source

## Source Identity

This packet combines two existing governed source lineages that were read
completely before this extraction:

- Gorska, Anna and Krawiec, Malgorzata (2015), "Calendar Effects in the
  Market of Crude Oil", *Quantitative Methods in Economics* 16(4),
  https://ageconsearch.umn.edu/record/230857/files/2015_4_7.pdf.
- Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
  "Time Series Momentum", *Journal of Financial Economics* 104(2), 228-250,
  https://doi.org/10.1016/j.jfineco.2011.11.003.

The bounded repository packets
`strategy-seeds/sources/GORSKA-WTI-CAL-2015/source.md` and
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` are the extraction
authority. No new web claim is imported by this composite.

## Bounded Extraction

Gorska and Krawiec study WTI daily returns and report Friday as the strongest
positive average weekday in their sample. The governed `wti-fri-prem` parent
translates that finding into one long `XTIUSD.DWX` D1 Friday package, flattened
before the weekend.

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, including commodities. The governed QM translation uses the sign of
an instrument's completed 12-month return as a slow directional state.

The card tests one predeclared interaction:

- inspect the strictly completed 252-D1 WTI log-return sign at the start of a
  genuine Friday D1 bar;
- permit the source-directed Friday WTI long only when that sign is strictly
  positive; and
- flatten the package through the framework Friday-close control, with a
  broker hard stop and deterministic stale repair.

Neither paper tests this conjunction, a continuous Darwinex WTI CFD,
Friday-open execution, a fixed-risk ATR stop, or the QuantMechanica
portfolio. Those are explicit QM hypotheses and must be falsified by Q02 and
later gates.

## Claim And Translation Boundary

The calendar paper's WTI return is a daily close-to-close observation. An EA
first attached to the Friday D1 bar cannot capture the Thursday-close to
Friday-open gap. The card therefore requires entry during the first five
minutes of the Friday broker bar and explicitly treats the omitted overnight
component as a load-bearing falsification risk.

The 252-D1 sign is a fixed source-lineage state, not a fitted overlay. No
source profit factor, return, hit rate, drawdown, trade count, correlation, or
portfolio statistic is imported as a QM expectation.

## Runtime Guardrails

- Exact host and traded symbol: `XTIUSD.DWX`, D1.
- Native MT5 completed OHLC, ATR, executable quote, spread, broker calendar,
  position/deal history, and framework state only.
- No futures curve, contract chain, inventory, WPSR, OPEC, COT, volume, open
  interest, options, analyst forecast, API, CSV, external feed, or trained
  output.
- No grid, martingale, scale-in, pyramid, partial close, trailing stop,
  discretionary switch, or post-result weekday/lookback search.
- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Non-Duplicate Record

The deterministic pre-allocation helper scanned 4,202 EA-registry rows and
376 research cards and returned `CLEAN` for slug `wti-fri-trend`, strategy ID
`GORSKA-MOP-WTI-FRITREND-2026_S01`, and mechanic `XTIUSD D1 Friday long only
when the completed 252-D1 own-price log return is strictly positive`.

Manual semantic review separates the composite from its closest parents and
neighbors:

- `QM5_12597_wti-fri-prem` buys every eligible Friday and never reads a trend
  state.
- `QM5_12603_wti-tsmom12m` trades the completed 252-D1 sign symmetrically on a
  monthly clock and has no Friday-only calendar gate.
- `QM5_20141_wti-sumtrend` sells on the first tradable bar of July-November
  weeks when the 252-D1 sign is negative; it is not a Friday premium.
- `QM5_20135_wti-winter-trend` is a monthly November-May symmetric trend
  package.
- `QM5_20117_wti-fri-lagrev` sells Friday only after a completed Thursday
  surge of at least 4.5%; it is a one-day tail reversal.
- `QM5_12753_wti-thu-pb-fri-bounce` buys after a one-day Thursday pullback and
  has no slow trend state.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The Friday calendar gate and positive completed 252-D1 sign are jointly
load-bearing. Removing either recreates an already-built parent.

## R-Rules

- R1 reputable source: PASS. Two named-author academic journal lineages, one
  peer-reviewed in the *Journal of Financial Economics*, with durable
  governed repository packets.
- R2 mechanical: PASS. Fixed Friday clock, completed return sign, long-only
  direction, consumed weekly attempt, ATR stop, Friday flatten, and stale
  repair.
- R3 data available: PASS. Registered `XTIUSD.DWX` D1 history route and native
  tester inputs only.
- R4 no ML/banned logic: PASS. Deterministic calendar, OHLC, logarithm, and
  ATR arithmetic only.
