---
source_id: EWALD-MOP-WTI-SUMTREND-2026
title: "WTI July-November Trading-Time Seasonality With Negative 12-Month Trend"
source_type: governed_composite_of_peer_reviewed_papers
quality_tier: A
status: approved_for_cards
approved_for_cards: true
approval_record: "OWNER commodity/energy sleeve mission, 2026-07-25"
created: 2026-07-25
created_by: Research+Development
parent_sources:
  - EWALD-WTI-TRDTIME-2022
  - MOP-TSMOM-2012
cards_extracted:
  - wti-sumtrend
---

# WTI Summer Trading-Time / Trend Composite Source

## Source Identity

This packet combines two existing governed source lineages that were read in
full before this extraction:

- Ewald, Christian-Oliver; Haugom, Erik; Lien, Gudbrand; Stordal, Stale; and
  Wu, Yuexiang (2022), "Trading time seasonality in commodity futures: An
  opportunity for arbitrage in the natural gas and crude oil markets?",
  *Energy Economics* 115, article 106324,
  https://doi.org/10.1016/j.eneco.2022.106324. The open published manuscript is
  at https://eprints.gla.ac.uk/281581/1/281581.pdf.
- Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), "Time
  Series Momentum", *Journal of Financial Economics* 104(2), 228-250,
  https://doi.org/10.1016/j.jfineco.2011.11.003. The governed repository parent
  is `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

The bounded repository packets
`strategy-seeds/sources/EWALD-WTI-TRDTIME-2022/source.md` and
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` are the extraction authority.
No new web claim is imported by this composite.

## Bounded Extraction

Ewald et al. distinguish trading-time seasonality from ordinary contract
maturity seasonality. Their fixed-maturity WTI samples show the highest prices
when contracts are traded in July and the lowest when traded in December.
Section 5.1 expresses the effect as shorting WTI in July and taking the
offsetting position in December.

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, including commodities. The governed QM translation uses the sign of
an instrument's completed 12-month return as its slow directional state.

The card tests one predeclared interaction:

- inspect the completed 252-D1 WTI log-return sign;
- only during July through November, permit the source-directed WTI short when
  that sign is strictly negative;
- express permitted risk as one non-overlapping weekly D1 package, closed by
  the Friday framework control or a seven-day stale guard.

Neither paper tests this conjunction, a continuous Darwinex WTI CFD, weekly
fixed-risk tranches, an ATR hard stop, or the QuantMechanica portfolio. Those
are explicit QM hypotheses and must be falsified by Q02 and later gates.

## Claim And Translation Boundary

Ewald et al. use fixed-maturity futures panels. `XTIUSD.DWX` is a continuous
CFD and cannot reproduce their matched-maturity construction. The EA therefore
tests only the directional carrier of the July-to-December trading-time effect.
Weekly tranches preserve the already-governed CFD translation, avoid
overlapping packages, and provide enough independent decisions for baseline
screening.

The 252-D1 sign is a fixed source-lineage state, not a fitted overlay. No source
profit factor, return, hit rate, drawdown, correlation, or portfolio statistic
is imported as a QM expectation.

## Runtime Guardrails

- Exact host and traded symbol: `XTIUSD.DWX`, D1.
- Native MT5 completed OHLC, ATR, executable quote, spread, broker calendar,
  position/deal history, and framework state only.
- No futures curve, fixed-maturity matrix, inventory, WPSR, OPEC, COT, volume,
  open interest, options, analyst forecast, API, CSV, external feed, or trained
  output.
- No grid, martingale, scale-in, pyramid, partial close, trailing stop,
  discretionary switch, or post-result month/lookback search.
- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Non-Duplicate Record

The deterministic pre-allocation helper scanned 4,198 EA-registry rows and 376
research cards and returned `CLEAN` for slug `wti-sumtrend`, strategy ID
`EWALD-MOP-WTI-SUMTREND-2026_S01`, and mechanic
`July-November weekly WTI short only when completed 252-D1 return is negative`.

Manual semantic review separates the composite from its closest parents:

- `QM5_13107_wti-juldec-short` is the unconditional weekly seasonal short and
  never reads a trend state.
- `QM5_12603_wti-tsmom12m` trades the 252-D1 sign symmetrically year-round and
  has no July-November gate.
- `QM5_20135_wti-winter-trend` trades both directions monthly in November-May;
  this extraction is short-only, July-November, and weekly.
- `QM5_20093_wti-summer-short` is an unconditional calendar short without a
  252-D1 state.
- `QM5_20136_wti-caltrend` estimates adaptive same-calendar-month history and
  uses a 63-D1 agreement state rather than a fixed summer risk-premium window.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The July-November trading-time window and negative completed 252-D1 sign are
jointly load-bearing. Removing either recreates an already-built parent.

## R-Rules

- R1 reputable source: PASS. Two named-author peer-reviewed journal lineages,
  each with DOI and a durable governed repository packet.
- R2 mechanical: PASS. Fixed month window, completed return sign, weekly
  attempt clock, short-only direction, ATR stop, Friday flatten, and stale
  exit.
- R3 data available: PASS. Registered `XTIUSD.DWX` D1 history route and native
  tester inputs only.
- R4 no ML/banned logic: PASS. Deterministic calendar, OHLC, logarithm, and ATR
  arithmetic only.

