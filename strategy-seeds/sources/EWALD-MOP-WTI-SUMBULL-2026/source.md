---
source_id: EWALD-MOP-WTI-SUMBULL-2026
title: "WTI July-November Trading-Time Short In A Positive 12-Month State"
source_type: governed_composite_of_peer_reviewed_papers
quality_tier: A
status: approved_for_cards
approved_for_cards: true
approval_record: "OWNER commodity/energy sleeve mission, 2026-07-29"
created: 2026-07-29
created_by: Research+Development
parent_sources:
  - EWALD-WTI-TRDTIME-2022
  - MOP-TSMOM-2012
cards_extracted:
  - wti-sum-bull
---

# WTI Summer Trading-Time / Positive-Trend Counterfade Composite

## Source identity and approval

This packet combines two durable source lineages that were read completely
before this extraction:

- Ewald, Christian-Oliver; Haugom, Erik; Lien, Gudbrand; Stordal, Stale; and
  Wu, Yuexiang (2022), "Trading time seasonality in commodity futures: An
  opportunity for arbitrage in the natural gas and crude oil markets?",
  *Energy Economics* 115, article 106324,
  DOI `10.1016/j.eneco.2022.106324`. The complete bounded review is in
  `strategy-seeds/sources/EWALD-WTI-TRDTIME-2022/source.md`.
- Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), "Time
  Series Momentum", *Journal of Financial Economics* 104(2), 228-250,
  DOI `10.1016/j.jfineco.2011.11.003`. The complete governed review is in
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

The current OWNER commodity/energy sleeve mission authorizes one reputable-
source, structural WTI build and Q02 enqueue. No new web claim is introduced;
the two reviewed repository packets are the bounded extraction authority.

## Bounded extraction

Ewald et al. distinguish trading-time seasonality from ordinary contract-
maturity seasonality. Their fixed-maturity WTI samples show the highest prices
when contracts are traded in July and the lowest when traded in December.
Section 5.1 expresses the source effect by selling WTI in July and taking the
offsetting position in December.

Moskowitz, Ooi, and Pedersen document an instrument-own completed trailing-
return sign as a slow, observable futures state. The 12-month horizon is the
governed QM translation of that state.

This packet predeclares one interaction that is not already built:

1. During July through November, inspect WTI's completed 252-D1 log return.
2. Permit the source-directed WTI short only when that slow return is strictly
   positive.
3. Express the permitted risk as one non-overlapping weekly D1 package, with a
   frozen ATR hard stop, framework Friday close, and a seven-day stale guard.

The positive state deliberately opposes the seasonal short. It tests whether
the source calendar effect survives when a slow WTI uptrend makes the trade a
counterfade. Neither paper tests this conjunction, a continuous Darwinex CFD,
weekly fixed-risk tranches, the ATR stop, or QuantMechanica portfolio behavior.
Those are explicit, falsifiable QM translations rather than source claims.

## Claim and translation boundary

Ewald et al. use fixed-maturity futures panels. `XTIUSD.DWX` is a continuous
CFD and cannot reproduce their matched-maturity construction. The EA therefore
tests only the directional carrier of the July-to-December effect. July through
November is the entry window; December is the source cover boundary.

The completed 252-D1 return sign is fixed before Q02. No performance, trade
count, drawdown, correlation, or portfolio statistic is imported from either
paper. Downstream gates alone decide whether the CFD translation is economic
and whether its realized return stream is useful to the book.

## Runtime guardrails

- Exact host and traded symbol: `XTIUSD.DWX`, D1.
- Native MT5 completed OHLC, ATR, executable quote, spread, broker calendar,
  positions, deals, terminal-persistent attempt state, and V5 safety state.
- No futures curve, fixed-maturity matrix, inventory, WPSR, OPEC, COT, volume,
  open interest, options, analyst forecast, API, CSV, or external signal feed.
- No trained model, adaptive PnL fitting, grid, martingale, scale-in, pyramid,
  partial close, trailing stop, or discretionary switch.
- Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Non-duplicate record

The deterministic pre-allocation command scanned 4,239 EA-registry rows and
375 research cards and returned `CLEAN` for:

- slug `wti-sum-bull`;
- strategy ID `EWALD-MOP-WTI-SUMBULL-2026_S01`; and
- mechanic `July-November weekly WTI short only when completed 252-D1 return
  is positive`.

Manual semantic review separates the candidate from its closest systems:

- `QM5_20141_wti-sumtrend` requires a strictly negative completed 252-D1
  return. The candidate requires the mutually exclusive positive state.
- `QM5_13107_wti-juldec-short` and `QM5_20093_wti-summer-short` are
  unconditional seasonal shorts and never read a slow state.
- `QM5_12603_wti-tsmom12m` follows the 252-D1 sign year-round; it would buy,
  rather than short, in the candidate's positive state.
- `QM5_20136_wti-caltrend` estimates adaptive same-calendar-month history and
  a 63-D1 agreement state rather than using Ewald's fixed window and the
  locked 252-D1 positive state.
- `QM5_12567_cum-rsi2-commodity` is an XNG short-horizon oscillator pullback,
  with neither WTI nor a calendar/trend interaction.

The July-November gate, positive 252-D1 state, weekly attempt clock, and short
direction are jointly load-bearing. The positive-state carrier is disjoint
from QM5_20141 rather than a parameter retune of it.

## R1-R4

- R1: PASS. Two named-author, peer-reviewed journal lineages with DOI and
  completely reviewed durable repository packets.
- R2: PASS. Fixed month window, completed-return sign, weekly attempt state,
  short direction, hard stop, Friday flatten, and stale exit.
- R3: PASS. Registered `XTIUSD.DWX` D1 history and native tester inputs only.
- R4: PASS. Deterministic calendar, logarithm, OHLC, ATR, and framework state;
  no prohibited runtime component.

## Safety boundary

This approval covers one backtest-only Strategy Card, deterministic registry
allocation, one EA build, strict compilation, one `RISK_FIXED` setfile, and one
paced Q02 enqueue. It does not authorize a live setfile, deploy manifest,
`T_Live` mutation, AutoTrading change, portfolio admission, portfolio-gate
change, or correlation waiver.
