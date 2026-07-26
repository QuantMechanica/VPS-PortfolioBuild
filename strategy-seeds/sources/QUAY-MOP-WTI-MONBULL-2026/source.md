---
source_id: QUAY-MOP-WTI-MONBULL-2026
title: "WTI Monday Weakness With Positive 12-Month Trend Counterfade"
source_type: governed_composite_of_peer_reviewed_papers
quality_tier: A
status: approved_for_cards
approved_for_cards: true
approval_record: "OWNER commodity/energy sleeve mission, 2026-07-25"
created: 2026-07-25
created_by: Research+Development
parent_sources:
  - QUAY-WTI-DOW-2019
  - MOP-TSMOM-2012
cards_extracted:
  - wti-mon-bullfade
---

# WTI Monday Weakness / Positive-Trend Counterfade Composite Source

## Source Identity

This packet combines two existing governed source lineages that were read in
full before extraction:

- Quayyum, H. A., Khan, M. A. M., and Ali, S. M. (2020), "Seasonality in
  crude oil returns", *Soft Computing* 24, 7857-7873,
  https://doi.org/10.1007/s00500-019-04329-0. The governed repository parent
  is `strategy-seeds/sources/QUAY-WTI-DOW-2019/source.md`.
- Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
  Momentum", *Journal of Financial Economics* 104(2), 228-250,
  https://doi.org/10.1016/j.jfineco.2011.11.003. The governed repository
  parent is `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

The bounded parent packets are the extraction authority. No new web claim is
imported by this composite.

## Bounded Extraction

Quayyum et al. provide peer-reviewed structural lineage for crude-oil
day-of-week seasonality and the weak WTI Monday side already isolated by
`QM5_12596_wti-mon-fade`.

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, including commodities. The governed QM translation uses the sign of
an instrument's own completed 12-month return as a slow directional state.

This card tests one predeclared interaction:

- require a genuine broker-calendar Monday D1 bar immediately following a
  completed Friday D1 bar;
- inspect the completed 252-D1 WTI log-return sign;
- permit the source-directed WTI Monday short only when that sign is strictly
  positive;
- flatten at the first non-Monday D1 bar, with a frozen ATR hard stop and a
  two-calendar-day stale repair.

Neither paper tests this conjunction, a continuous Darwinex WTI CFD, the
Friday-close to Monday-open attachment point, the ATR stop, or the
QuantMechanica portfolio. Those are explicit QM hypotheses and must be
falsified by Q02 and later gates.

## Claim And Translation Boundary

The source evidence concerns futures returns. `XTIUSD.DWX` is a continuous CFD
and cannot reproduce a matched futures-contract series. Opening at the first
observed tick of the Monday D1 bar also cannot capture any return between the
prior Friday close and that executable quote. The candidate therefore tests a
Monday-session CFD carrier, not a reproduction of the source sample.

The completed 252-D1 sign is a fixed source-lineage state, not a fitted overlay.
No source profit factor, return, hit rate, drawdown, frequency, correlation, or
portfolio statistic is imported as a QM expectation.

## Runtime Guardrails

- Exact host and traded symbol: `XTIUSD.DWX`, D1.
- MT5-native completed OHLC, ATR, executable quote, spread, broker calendar,
  position/deal history, and framework state only.
- No futures curve, contract chain, inventory, WPSR, OPEC, COT, volume, open
  interest, options, analyst forecast, API, CSV, external feed, or trained
  output.
- No grid, martingale, scale-in, pyramid, partial close, trailing stop,
  discretionary switch, or post-result weekday/lookback search.
- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Non-Duplicate Record

The deterministic pre-allocation helper scanned 4,206 EA-registry rows and 376
research cards and returned `CLEAN` for slug `wti-mon-bullfade`, strategy ID
`QUAY-MOP-WTI-MONBULL-2026_S01`, and mechanic
`Monday WTI short only when completed 252-D1 return is positive`.

Manual semantic review separates the composite from its closest systems:

- `QM5_12596_wti-mon-fade` shorts every eligible Monday and never reads a
  slow countertrend state.
- `QM5_12603_wti-tsmom12m` trades the completed 252-D1 sign symmetrically and
  monthly throughout the year, without a weekday gate.
- `QM5_12750` and `QM5_12779` trade Monday opening gaps and use gap-fill
  targets; this card never reads the Monday opening gap.
- `QM5_20016_xti-xng-mon-rv` is a two-leg XTI/XNG Monday basket with fixed
  opposing directions; this card is single-symbol WTI and trend-conditioned.
- `QM5_20029_wti-monfri-daily` rotates an unconditional Monday short and Friday
  long; this card has no Friday entry and requires positive slow trend.
- `QM5_20141_wti-sumtrend` shorts weekly only in July-November; this card is
  year-round but Monday-session-only.
- `QM5_20145_wti-fri-trend` buys positive-trend Fridays; this card shorts
  positive-trend Mondays.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback, not a
  weekday/trend interaction.

The Monday session and positive completed 252-D1 sign are jointly
load-bearing. Removing either recreates an already-built parent.

## R-Rules

- R1 reputable source: PASS. Two named-author peer-reviewed journal lineages,
  each with a DOI and a durable governed repository packet.
- R2 mechanical: PASS. Fixed Monday/Friday calendar boundary, completed
  return sign, weekly consumed attempt, short-only direction, ATR stop,
  next-D1 flatten, and stale repair.
- R3 data available: PASS. Registered `XTIUSD.DWX` D1 history route and native
  tester inputs only.
- R4 no ML/banned logic: PASS. Deterministic calendar, OHLC, logarithm, and ATR
  arithmetic only.

