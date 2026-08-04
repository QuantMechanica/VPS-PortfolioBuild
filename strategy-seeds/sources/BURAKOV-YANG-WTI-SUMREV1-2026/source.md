---
source_id: BURAKOV-YANG-WTI-SUMREV1-2026
title: WTI June-October regime with exact one-month reversal
publisher: International Journal of Energy Economics and Policy / SSRN
source_type: peer_reviewed_and_academic_composite_lineage
status: approved
created: 2026-08-04
created_by: Research+Development
last_updated: 2026-08-04
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-04
strategy_ids:
  - BURAKOV-YANG-WTI-SUMREV1-2026_S01
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - YANG-COMM-REVERSAL-2017
---

# WTI Summer-Regime / One-Month Reversal Source Packet

## Source identity and complete-read evidence

This governed packet joins two bounded repository sources that were read in
full before extraction:

1. Burakov, Dmitry; Freidin, Max; and Solovyev, Yuriy (2018), "The
   Halloween Effect on Energy Markets: An Empirical Study," *International
   Journal of Energy Economics and Policy* 8(2), 121-126. The complete open
   six-page paper, both seasonal definitions, all result tables, and the
   paper's conflicting abstract/table labels are documented in
   `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`.
2. Yang, Hongbing; Goncu, Ahmet; and Pantelous, Athanasios A. (2017),
   "Momentum and Reversal in Commodity Futures," SSRN 3069253. Its governed
   commodity-reversal extraction, runtime boundary, and previously allocated
   fixed-horizon cards are documented in
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`.

Burakov et al. define their alternative-two WTI summer interval from the last
May close through the last October close and report a negative WTI summer
sample relative to the November-May winter leg. Yang et al. supply the
academic lineage for systematic commodity reversal at fixed return horizons.

Neither source tests the conjunction below. Yang et al. do not report this
single-WTI summer state, and Burakov et al. do not condition their summer leg
on the preceding month's return. No source performance, CFD-basis,
transaction-cost, drawdown, correlation, or portfolio statistic transfers.

## Bounded mechanization

`BURAKOV-YANG-WTI-SUMREV1-2026_S01` is one predeclared interaction:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable D1 bar of each broker-calendar month;
- active regime: June through October; forced flat November through May;
- formation: the exact just-completed consecutive broker-calendar-month WTI
  close-to-close log return;
- positive return: SELL one monthly WTI package;
- negative return: BUY one monthly WTI package;
- equality or invalid endpoints: remain flat for the consumed month;
- exit and, when eligible, renew at the next month boundary;
- frozen `3.5 * ATR(20,D1)` hard stop, forty-day stale guard, 1,500-point
  spread ceiling, and one restart-safe attempt per active month; and
- backtest-only `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The five eligible months supply exactly five possible decisions per complete
year. Q02 must retire the candidate below five completed packages per full
post-warm-up year. The EA reads only native OHLC, ATR, broker calendar,
quotes, positions, deal history, and V5 framework state.

## Non-duplicate boundary

The deterministic pre-allocation check scanned 4,270 EA registry rows and 388
cards. It found no exact duplicate and one expected fuzzy sibling,
`QM5_20213_wti-summer-mom1`, at mechanic score 0.80. Manual review resolves
that match and the closest other builds:

- `QM5_20213_wti-summer-mom1` trades in the same June-October window but
  follows the completed prior month. This packet always takes the opposite
  direction. Continuation versus reversal is the load-bearing signal, not a
  parameter change.
- `QM5_20093_wti-summer-short` is unconditionally short in June-October and
  never reads a completed return.
- `QM5_20209_wti-winter-mom1` follows one-month momentum in the disjoint
  November-May regime and is forced flat during this candidate's active
  months.
- `QM5_20187_wti-tsmom1m` follows one-month momentum year-round.
- `QM5_12979_wti-6m-reversal` fades an intermediate 120-D1 return year-round;
  it has neither an exact completed-month information object nor a summer
  gate.
- `QM5_12621_comm-reversal-4wk-xtiusd` is a weekly 20-D1 overreaction rule
  with a different decision clock, horizon, and exit.
- `QM5_20137_wti-seas-pb` trades the historical same-calendar sign only after
  a counter-move; this packet has no historical same-month estimator.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The fixed June-October gate, exact completed broker-month endpoints, opposite
sign map, monthly renewal, and November-May flat state are jointly
load-bearing. Changing any of them creates a different candidate.

## Reputable-source criteria

- R1: PASS. One composite `source_id` preserves lineage to a named-author,
  peer-reviewed open paper and a named-author academic commodity-reversal
  paper, each with a durable complete repository review.
- R2: PASS. Fixed months, completed endpoints, opposite-sign directions,
  renewal, hard stop, stale exit, spread cap, and attempt state are
  deterministic.
- R3: PASS. Registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4: PASS. Native arithmetic only; no trained model, external runtime feed,
  grid, martingale, scale-in, pyramiding, or multiple same-magic positions.

## Safety and claim boundary

This packet authorizes one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk setfile, and one
paced Q02 enqueue under the 2026-08-04 OWNER mission. It does not authorize
live, demo, or shadow execution; AutoTrading; `T_Live`; deploy or T_Live
manifests; portfolio admission; portfolio-gate changes; or correlation
waivers.
