---
source_id: BURAKOV-MOP-WTI-SEASMOM12-2026
title: WTI physical-season and completed twelve-month momentum concordance
publisher: International Journal of Energy Economics and Policy / Journal of Financial Economics
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-05
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-05
strategy_ids:
  - BURAKOV-MOP-WTI-SEASMOM12-2026_S01
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - MOP-TSMOM-2012
---

# WTI Physical-Season / Twelve-Month Momentum Concordance Source Packet

## Source Identity And Complete-Read Evidence

This packet joins two governed peer-reviewed lineages whose complete texts,
methods, source statistics, conflicts, and limitations are preserved in the
repository and were read completely for this extraction:

1. Burakov, Dmitry; Freidin, Max; and Solovyev, Yuriy (2018), "The
   Halloween Effect on Energy Markets: An Empirical Study," *International
   Journal of Energy Economics and Policy* 8(2), 121-126. The official open
   six-page paper was reviewed end to end. Its methods-section alternative
   two defines WTI winter from the last October close through the last May
   close and summer from the last May close through the last October close.
   The durable review is
   `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2),
   228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete 23-page
   published paper was retrieved from an author faculty site, hashed, and
   reviewed end to end. Section 3.2 defines the own-past-`k`-month return-sign
   family, the selected security-level evidence uses the twelve-month signal,
   and Appendix A includes NYMEX WTI. The durable review and retrieval receipt
   are in `strategy-seeds/sources/MOP-TSMOM-2012/`.

Burakov et al. supply a positive November-May WTI physical-season direction
and a negative June-October direction. Moskowitz, Ooi, and Pedersen supply the
sign of the completed twelve-month own return as a monthly directional state.

Neither source tests the agreement filter below. The seasonal paper does not
condition on momentum; the momentum paper does not report this WTI-only
seasonal interaction. Neither tests a Darwinex continuous CFD, exact broker-
month reconstruction, fixed cash risk, an ATR stop, transaction costs,
financing, or the QM portfolio. No source return, significance, Sharpe,
drawdown, correlation, or neutrality statistic transfers to this candidate.

## Bounded Mechanization

`BURAKOV-MOP-WTI-SEASMOM12-2026_S01` is one predeclared monthly concordance
rule:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision: the first tradable D1 bar of every broker-calendar month;
- seasonal direction: BUY in November-May and SELL in June-October;
- formation: the close-to-close log return across the latest twelve completed
  broker-calendar months, reconstructed from thirteen consecutive completed
  month-end D1 closes;
- momentum direction: BUY after a strictly positive cumulative return, SELL
  after a strictly negative cumulative return, and flat after equality or
  invalid history;
- entry: open only when seasonal and momentum directions agree, so negative
  winter or positive summer state consumes the month and stays flat;
- lifecycle: close the prior package before the next month decision, with a
  forty-calendar-day stale guard;
- risk: one frozen `3.5 * ATR(20,D1)` server-side hard stop, no target, a
  1,500-point spread ceiling, and one restart-safe consumed attempt per month;
  and
- backtest contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close OFF.

The maximum cadence is twelve decisions per full post-warm-up year. The
predeclared expectation is five to eight concordant packages per year. Q02
must retire the candidate if it averages below five completed packages per
year. No lookback, threshold, season, direction, or holding-period sweep is
authorized.

Runtime reads native D1 OHLC, ATR, broker calendar, executable quotes,
positions, deal history, and framework state only. It does not read a futures
chain, inventory, volume, open interest, external files, APIs, or forecasts.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,288 EA-registry rows and
404 canonical cards. It found no exact identity and four expected fuzzy
matches in the `wti-seas-*` family. Manual mechanic review fixes the boundary:

- `QM5_20046_wti-halloween-ls` maps season directly to position direction;
  it has no price-conditioned disagreement-flat state.
- `QM5_12603_wti-tsmom12m` follows a twelve-month return sign year-round; it
  has no physical-season direction or agreement requirement.
- `QM5_20135_wti-winter-trend` reads completed 252-D1 closes and can buy or
  sell only in November-May. This candidate reconstructs exact calendar-month
  endpoints, never shorts winter, and also expresses the June-October short
  leg when the two states agree.
- `QM5_20141_wti-sumtrend` is a weekly July-November short-only interaction
  using a completed 252-D1 state. It has a different source season, clock,
  hold, and no winter-long leg.
- `QM5_20222_wti-seas-sign` classifies twelve individual monthly return signs
  with a fixed `0.40` probability threshold. This candidate uses one
  cumulative twelve-calendar-month endpoint return and no breadth threshold.
- `QM5_20227_wti-seas-mom1` uses only the immediately completed one-month
  return. The twelve-month formation endpoint here is load-bearing.
- `QM5_20205_wti-calmom1` estimates a ten-year same-calendar-month direction
  and then requires one-month agreement, rather than the fixed physical
  partition and twelve-month cumulative state.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback above a
  long-horizon filter, not a monthly energy calendar/trend interaction.

The exact twelve completed calendar months, fixed two-season map,
agreement-only entry, disagreement-flat state, and month-to-month lifecycle
are jointly load-bearing. Changing the formation horizon or replacing the
cumulative endpoint return with sign breadth would create a different card.

## Reputable-Source Criteria

- R1: PASS. Two named-author peer-reviewed papers with DOI or official
  journal/author access and durable complete-read repository records.
- R2: PASS. Fixed season map, thirteen consecutive month-end endpoints,
  strict cumulative-return sign, agreement rule, renewal, stop, stale guard,
  spread cap, and retry state are deterministic and frozen before testing.
- R3: PASS. Registered `XTIUSD.DWX` D1 history supplies every runtime input;
  no external data dependency exists.
- R4: PASS. Native price and calendar arithmetic only; no trained output,
  banned indicator, grid, martingale, scale-in, or pyramiding.

## Safety And Claim Boundary

The 2026-08-05 OWNER commodity/energy sleeve mission authorizes this bounded
source lineage for one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk backtest
setfile, and one paced Q02 enqueue. It does not authorize a manual backtest;
live, demo, or shadow execution; AutoTrading; `T_Live`; deploy or T_Live
manifests; portfolio admission; portfolio-gate changes; correlation waivers;
or any performance or decorrelation claim.
