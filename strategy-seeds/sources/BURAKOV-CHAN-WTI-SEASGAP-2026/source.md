---
source_id: BURAKOV-CHAN-WTI-SEASGAP-2026
title: WTI physical-season and weekend breakaway-gap agreement
publisher: International Journal of Energy Economics and Policy / Wiley / Journal of Finance Issues
source_type: peer_reviewed_and_tier_a_composite_lineage
status: approved
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-05
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-05
strategy_ids:
  - BURAKOV-CHAN-WTI-SEASGAP-2026_S01
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - CHAN-TGIF-WTI-WKENDMOM-2026
---

# WTI Physical-Season / Weekend Breakaway-Gap Source Packet

## Source identity and complete-read evidence

This governed packet joins two bounded repository lineages that were read
completely before extraction:

1. Burakov, Dmitry; Freidin, Max; and Solovyev, Yuriy (2018), "The
   Halloween Effect on Energy Markets: An Empirical Study," *International
   Journal of Energy Economics and Policy* 8(2), 121-126. The complete open
   six-page paper, its two seasonal definitions, result tables, and editorial
   inconsistencies are preserved in
   `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`.
2. Ernest P. Chan (2013), *Algorithmic Trading: Winning Strategies and Their
   Rationale*, Wiley, Chapter 7, Example 7.1, printed pages 156-157, together
   with Hoelscher, Mbanga, and Nelson (2017), "TGIF? The Weekend Effect in
   Energy Commodities," *Journal of Finance Issues* 16(1), 47-68. Chan's
   exact opening-gap rule and the complete peer-reviewed WTI weekend review
   are bounded in
   `strategy-seeds/sources/CHAN-TGIF-WTI-WKENDMOM-2026/source.md`.

Burakov et al. supply the fixed positive November-May and negative
June-October WTI physical-season directions. Chan supplies a mechanical
opening-gap continuation rule: trade beyond the prior session's full range
plus `0.1` times lagged 90-return sample volatility. Hoelscher, Mbanga, and
Nelson supply target-market evidence that WTI has a distinct weekend/Monday
clock, without prescribing Chan's direction or threshold.

None of the sources tests the exact conjunction below. No source return,
significance, Sharpe ratio, profit factor, drawdown, trade count, CFD basis,
cost, correlation, or portfolio statistic transfers to the QM candidate.

## Bounded mechanization

`BURAKOV-CHAN-WTI-SEASGAP-2026_S01` locks one interaction:

- carrier: exact `XTIUSD.DWX`, D1, magic slot 0;
- decision: a broker-calendar Monday whose immediately prior completed D1
  bar is Friday;
- fixed physical-season direction: BUY November-May and SELL June-October;
- formation: Monday D1 open, completed Friday high/low, and the sample
  standard deviation of exactly 90 completed arithmetic D1 close-to-close
  returns;
- November-May: BUY only when Monday open is strictly above
  `FridayHigh * (1 + 0.10 * stdret90)`;
- June-October: SELL only when Monday open is strictly below
  `FridayLow * (1 - 0.10 * stdret90)`;
- a gap in the direction opposing the fixed season, an in-band open,
  equality, invalid history, or a non-Friday predecessor remains flat for the
  consumed Monday;
- attach only within five minutes of the Monday D1 bar open and persist the
  attempt before fallible gates;
- close on the first following D1 bar, with a two-calendar-day stale repair;
- frozen `3.0 * ATR(20,D1)` hard stop, 2,500-point spread ceiling, one
  same-magic position, and framework Friday close enabled at broker hour 21;
  and
- backtest-only `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

The all-season parent estimates approximately 6-18 threshold-crossing
packages per year. Freezing one season-agreeing direction per month is
expected to admit roughly 4-10 packages per full post-warm-up year. That is a
planning estimate only: Q02 must retire the candidate below five completed
packages per year on average.

## Non-duplicate boundary

Before allocation, `research_dedup_check.py` scanned 4,287 EA-registry rows
and 403 canonical cards. It found no exact identity and three expected fuzzy
matches in the `wti-seas-*` slug family. Manual mechanic review fixes the
boundary:

- `QM5_20217_wti-wkend-mom` is the all-season source parent. It buys upside
  and sells downside threshold gaps in every month. This candidate introduces
  the separately sourced fixed physical-season information object and rejects
  every gap whose direction disagrees with it. The season map is load-bearing,
  not an optimized threshold or post-result rescue.
- `QM5_20226_wti-seas-dow` trades signed ordinary weekday sessions from
  completed prior-day sequences. It does not require a Friday-to-Monday gap,
  a prior-range break, or lagged 90-return volatility.
- `QM5_20227_wti-seas-mom1` and `QM5_20229_wti-seas-rev1` decide only at
  broker-month boundaries from completed month-end returns and hold month to
  month. This candidate decides at genuine Monday reopens from a breakaway
  gap and exits at the next D1 boundary.
- `QM5_20046_wti-halloween-ls` takes unconditional month-long seasonal
  exposure and reads no weekend gap or volatility threshold.
- `QM5_12750_wti-weekend-gap-fade` and
  `QM5_12779_wti-weekend-gap-bounce` fade gaps toward Friday's close. This
  candidate follows only a season-agreeing gap beyond Friday's full range.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback and
  contains no physical-season or weekend breakaway state.

The WTI carrier, fixed season map, genuine Friday-to-Monday sequence,
prior-range volatility threshold, season-agreeing continuation direction,
and next-D1 lifecycle are jointly load-bearing. Removing the season map
recreates the all-season parent; reversing direction recreates gap-fill logic.

## Reputable-source criteria

- R1: PASS. The composite preserves one named-author peer-reviewed open WTI
  seasonality paper, one Tier-A named-author Wiley book with exact executable
  logic, and one named-author peer-reviewed WTI weekend paper, all with
  durable complete repository reviews.
- R2: PASS. Months, seasonal directions, weekday sequence, completed sample,
  sample-variance denominator, `0.10` threshold, direction gate, attachment
  window, attempt state, hard stop, spread cap, exit, and stale repair are
  deterministic and locked.
- R3: PASS. Registered native `XTIUSD.DWX` D1 history supplies every runtime
  input; no external feed is required.
- R4: PASS. Native broker calendar, OHLC, arithmetic returns, variance, ATR,
  quote, deal, position, and framework state only; no trained model, banned
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Safety and claim boundary

This packet authorizes one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk setfile, and one
paced Q02 enqueue under the 2026-08-05 OWNER mission. It does not authorize a
manual backtest; live, demo, or shadow execution; AutoTrading; `T_Live`; a
deploy or T_Live manifest; portfolio admission; portfolio-gate changes; a
correlation waiver; or any source-performance claim.
