---
source_id: BURAKOV-YANG-WTI-SEASREV1-2026
title: WTI fixed physical-season direction after an opposing completed month
publisher: International Journal of Energy Economics and Policy / SSRN
source_type: peer_reviewed_and_academic_composite_lineage
status: approved
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-05
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-05
strategy_ids:
  - BURAKOV-YANG-WTI-SEASREV1-2026_S01
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - YANG-COMM-REVERSAL-2017
---

# WTI Physical-Season / One-Month Pullback Source Packet

## Source identity and complete-read evidence

This governed packet joins two bounded repository source records that were
read completely before extraction:

1. Burakov, Dmitry; Freidin, Max; and Solovyev, Yuriy (2018), "The
   Halloween Effect on Energy Markets: An Empirical Study," *International
   Journal of Energy Economics and Policy* 8(2), 121-126. The complete open
   six-page paper, both seasonal definitions, all result tables, and its
   conflicting abstract/table labels are documented in
   `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`.
2. Yang, Hongbing; Goncu, Ahmet; and Pantelous, Athanasios A. (2017),
   "Momentum and Reversal in Commodity Futures," SSRN 3069253. Its governed
   commodity-reversal extraction and native-data boundary are documented in
   `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`.

Burakov et al. define their alternative-two WTI winter interval from the last
October close through the following last May close and report a positive WTI
winter sample versus a negative June-October summer sample. Yang et al.
supply the academic lineage for systematic commodity reversal at fixed
return horizons.

Neither source tests the interaction below. Burakov et al. do not condition
their fixed seasonal directions on the preceding month's return. Yang et al.
do not report a single-WTI rule that enters only when a completed month moves
against a physical-season direction. No source return, significance, Sharpe,
drawdown, CFD-basis, cost, correlation, or portfolio statistic transfers.

## Bounded mechanization

`BURAKOV-YANG-WTI-SEASREV1-2026_S01` is one predeclared interaction:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable D1 bar of each broker-calendar month;
- fixed physical-season direction: BUY November-May and SELL June-October;
- formation: the exact just-completed consecutive broker-calendar-month WTI
  close-to-close log return;
- November-May plus a strictly negative completed return: BUY one package;
- June-October plus a strictly positive completed return: SELL one package;
- aligned return, equality, or invalid endpoints: remain flat for the
  consumed month;
- close and, when eligible, renew at the next broker-month boundary;
- frozen `3.5 * ATR(20,D1)` hard stop, forty-day stale guard, 1,500-point
  spread ceiling, and one restart-safe attempt per broker month; and
- backtest-only `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

The calendar supplies twelve possible decisions per complete year. The
opposing-return condition is expected to admit approximately five to seven
packages per full post-warm-up year; Q02 must retire the candidate below five.
Runtime reads only native OHLC, ATR, broker calendar, quotes, positions, deal
history, and V5 framework state.

## Non-duplicate boundary

Before allocation, the deterministic helper scanned 4,286 EA-registry rows
and 402 canonical cards. It found no exact identity and two expected fuzzy
slug-family matches. Manual mechanic review resolves them and the closest
other builds:

- `QM5_20227_wti-seas-mom1` shares the fixed physical-season map and exact
  completed-month information object, but trades only when the return agrees
  with that map. This packet requires disagreement and enters in the seasonal
  direction, so the entry states are mutually exclusive.
- `QM5_20226_wti-seas-dow` requires a signed weekday event and holds one
  session. This packet uses no weekday state and holds month to month.
- `QM5_20137_wti-seas-pb` estimates a rolling ten-year same-calendar-month
  direction. This packet uses the fixed Burakov winter/summer direction and
  has no historical same-calendar estimator.
- `QM5_20218_wti-winter-rev1` trades both reversal directions only in
  November-May. This packet takes only seasonal-direction BUY pullbacks in
  winter and adds seasonal-direction SELL rallies in summer.
- `QM5_20214_wti-sum-rev1` trades both reversal directions only in
  June-October. This packet takes only seasonal-direction SELL rallies in
  summer and adds seasonal-direction BUY pullbacks in winter.
- `QM5_20046_wti-halloween-ls` takes unconditional seasonal exposure and
  never reads a completed return.
- `QM5_20222_wti-seas-sign` uses twelve binary return signs and requires
  seasonal agreement rather than a one-month counter-move.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback above a
  long-horizon filter.

The fixed two-season direction map, exact completed broker-month endpoints,
strict opposing-return gate, seasonal-direction entry, monthly renewal, and
flat state on agreement are jointly load-bearing. Removing the opposing move
duplicates an unconditional seasonal parent; following it duplicates the
momentum-concordance sibling.

## Reputable-source criteria

- R1: PASS. One composite `source_id` preserves lineage to a named-author,
  peer-reviewed open WTI-seasonality paper and a named-author academic
  commodity-reversal paper, each with a durable complete repository review.
- R2: PASS. Fixed months and directions, completed endpoints, strict
  opposing-sign gate, renewal, hard stop, stale exit, spread cap, and attempt
  state are deterministic.
- R3: PASS. Registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4: PASS. Native calendar, OHLC, logarithm, and ATR arithmetic only; no
  trained model, banned indicator, external runtime feed, grid, martingale,
  scale-in, pyramiding, or multiple same-magic positions.

## Safety and claim boundary

This packet authorizes one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk setfile, and one
paced Q02 enqueue under the 2026-08-05 OWNER mission. It does not authorize a
manual backtest; live, demo, or shadow execution; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio admission; portfolio-gate changes; or
correlation waivers.
