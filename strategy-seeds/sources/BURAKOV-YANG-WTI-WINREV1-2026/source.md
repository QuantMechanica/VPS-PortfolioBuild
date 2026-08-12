---
source_id: BURAKOV-YANG-WTI-WINREV1-2026
title: WTI November-May regime with exact one-month reversal
publisher: International Journal of Energy Economics and Policy / SSRN
source_type: peer_reviewed_and_academic_composite_lineage
status: approved
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-05
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-05
strategy_ids:
  - BURAKOV-YANG-WTI-WINREV1-2026_S01
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - YANG-COMM-REVERSAL-2017
---

# WTI Winter-Regime / One-Month Reversal Source Packet

## Source identity and complete-read evidence

This governed packet joins two bounded repository source records that were
read completely before extraction:

1. Burakov, Dmitry; Freidin, Max; and Solovyev, Yuriy (2018), "The
   Halloween Effect on Energy Markets: An Empirical Study," *International
   Journal of Energy Economics and Policy* 8(2), 121-126. The complete open
   six-page paper, both seasonal definitions, all result tables, and the
   paper's conflicting abstract/table labels are documented in
   `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`.
2. Yang, Hongbing; Goncu, Ahmet; and Pantelous, Athanasios A. (2017),
   "Momentum and Reversal in Commodity Futures," SSRN 3069253. Its governed
   commodity-reversal extraction, native-data boundary, and fixed-horizon
   cards are documented in
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`.

Burakov et al. define their alternative-two WTI winter interval from the last
October close through the following last May close. Yang et al. supply the
academic lineage for systematic commodity reversal at fixed return horizons.

Neither source tests the conjunction below. Burakov et al. report a positive
unconditional WTI winter sample and do not condition it on the preceding
month. Yang et al. do not report this single-WTI November-May state. A short
signal after a positive prior month is therefore a deliberate falsification
of the interaction, not a source claim. No source performance, CFD-basis,
transaction-cost, drawdown, correlation, or portfolio statistic transfers.

## Bounded mechanization

`BURAKOV-YANG-WTI-WINREV1-2026_S01` is one predeclared interaction:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable D1 bar of each broker-calendar month;
- active regime: November through May; forced flat June through October;
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

The seven eligible months supply at most seven decisions per complete year.
Q02 must retire the candidate below five completed packages per full
post-warm-up year. Runtime reads only native OHLC, ATR, broker calendar,
quotes, positions, deal history, and V5 framework state.

## Non-duplicate boundary

The deterministic pre-allocation check scanned 4,275 EA registry rows and
391 cards. It found no exact identity and two expected fuzzy siblings. Manual
mechanic review resolves them and the closest other builds:

- `QM5_20209_wti-winter-mom1` uses the same November-May gate and exact
  completed-month information object, but follows the prior-month sign. This
  packet always takes the opposite direction. Continuation versus reversal is
  the load-bearing alpha map.
- `QM5_20214_wti-sum-rev1` uses the same opposite-sign mapping only in the
  disjoint June-October regime and is forced flat during this packet's active
  months. The seasonal partition is load-bearing.
- `QM5_20185_wti-win-bearfade` is a weekly bearish-state fade with a different
  formation object, decision clock, and lifecycle.
- `QM5_20015_wti-halloween-winter` is unconditional long-only winter
  exposure; it never reads a completed return.
- `QM5_20135_wti-winter-trend` follows a completed 252-D1 return rather than
  fading exact consecutive broker-month endpoints.
- `QM5_12979_wti-6m-reversal` is year-round 120-D1 reversal with no winter
  gate or exact calendar-month endpoints.
- `QM5_12621_comm-reversal-4wk-xtiusd` is a weekly 20-D1 overreaction rule.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The fixed November-May gate, exact completed broker-month endpoints,
opposite-sign mapping, monthly renewal, and June-October flat state are jointly
load-bearing. Changing any of them creates a different candidate.

## Reputable-source criteria

- R1: PASS. One composite `source_id` preserves lineage to a named-author,
  peer-reviewed open WTI-seasonality paper and a named-author academic
  commodity-reversal paper, each with a durable complete repository review.
- R2: PASS. Fixed months, completed endpoints, opposite-sign directions,
  renewal, hard stop, stale exit, spread cap, and attempt state are
  deterministic.
- R3: PASS. Registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4: PASS. Native arithmetic only; no trained model, external runtime feed,
  grid, martingale, scale-in, pyramiding, or multiple same-magic positions.

## Safety and claim boundary

This packet authorizes one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk setfile, and one
paced Q02 enqueue under the 2026-08-05 OWNER mission. It does not authorize a
manual backtest; live, demo, or shadow execution; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio admission; portfolio-gate changes; or
correlation waivers.
