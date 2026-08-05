---
source_id: BURAKOV-MOP-WTI-SEASMOM1-2026
title: WTI physical-season and immediately completed one-month momentum concordance
publisher: International Journal of Energy Economics and Policy / Journal of Financial Economics
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-05
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-05
strategy_ids:
  - BURAKOV-MOP-WTI-SEASMOM1-2026_S01
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - MOP-TSMOM-2012
---

# WTI Physical-Season / One-Month Momentum Concordance Source Packet

## Source Identity And Complete-Read Evidence

This packet joins two governed peer-reviewed lineages whose complete texts,
methods, source statistics, conflicts, and limitations are already preserved
in the repository and were read completely for this extraction:

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
   reviewed end to end. Section 3.2 and Table 2 include the source-declared
   `k=1`, `h=1` commodity-futures rule, while Appendix A includes NYMEX WTI.
   The durable review and retrieval receipt are in
   `strategy-seeds/sources/MOP-TSMOM-2012/`.

Burakov et al. supply a positive November-May WTI physical-season state and a
negative June-October state. Moskowitz, Ooi, and Pedersen supply the sign of
the immediately completed one-month own return as a directional state with a
one-month holding horizon.

Neither source tests the agreement filter below. The first paper does not
condition its seasonal result on price momentum; the second reports a pooled
commodity result rather than a WTI-only one-month result. Neither tests a
Darwinex continuous CFD, broker-month reconstruction, a fixed cash risk
budget, an ATR hard stop, transaction costs, financing, or the QM portfolio.
No source return, significance, Sharpe, drawdown, correlation, or neutrality
statistic transfers to this candidate.

## Bounded Mechanization

`BURAKOV-MOP-WTI-SEASMOM1-2026_S01` is one predeclared monthly concordance
rule:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision: the first tradable D1 bar of every broker-calendar month;
- seasonal direction: BUY in November-May and SELL in June-October;
- formation: the exact close-to-close log return of the immediately completed
  broker-calendar month, reconstructed from two consecutive completed
  month-end D1 closes;
- momentum direction: BUY after a strictly positive return, SELL after a
  strictly negative return, and flat after equality or invalid history;
- entry: open only when seasonal and momentum directions agree, so a winter
  negative return or summer positive return consumes the month and stays flat;
- lifecycle: close the prior package before the next month decision, with a
  forty-calendar-day stale guard;
- risk: one frozen `3.5 * ATR(20,D1)` server-side hard stop, no target,
  1,500-point spread ceiling, and one restart-safe consumed attempt per month;
  and
- backtest contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close OFF.

The maximum cadence is twelve decisions per full post-warm-up year. With two
binary directions and a fixed agreement gate, the predeclared expectation is
five to seven completed packages per year. Q02 must retire the candidate if
it averages below five completed packages per year. No horizon, threshold,
season, direction, or holding-period sweep is authorized.

Runtime reads native D1 OHLC, ATR, broker calendar, executable quotes,
positions, deal history, and framework state only. It does not read a futures
chain, inventory, volume, open interest, external files, APIs, or forecasts.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,284 EA-registry rows and
400 canonical cards. It found no exact identity and one expected fuzzy match
to `wti-seas-dow` because both slugs and mechanic labels begin with the WTI
physical-season agreement family. Manual mechanic review fixes the boundary:

- `QM5_20046_wti-halloween-ls` maps season directly to direction and enters
  every month; it has no price-conditioned agreement state.
- `QM5_20187_wti-tsmom1m` follows the exact completed one-month return sign
  year-round; it has no seasonal direction or disagreement-flat state.
- `QM5_20209_wti-winter-mom1` and `QM5_20213_wti-summer-mom1` trade either
  return-sign direction inside disjoint seasons. This candidate never shorts
  winter or buys summer and covers all twelve months with one agreement rule.
- `QM5_20222_wti-seas-sign` classifies twelve completed monthly return signs
  using a fixed 0.40 probability threshold. This candidate uses only the exact
  immediately completed month and has no breadth estimator.
- `QM5_20226_wti-seas-dow` trades one signed weekday session when the fixed
  season agrees with a weekday effect. This candidate has no weekday signal
  and holds a concordant month-to-month package.
- `QM5_20205_wti-calmom1` estimates a ten-year same-calendar-month return
  direction before requiring one-month momentum agreement; this candidate
  uses the fixed November-May/June-October physical partition.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback above a
  long-horizon price filter, not a monthly energy calendar/trend interaction.

The exact immediately completed month, fixed two-season direction map,
agreement-only entry, disagreement-flat state, and month-to-month lifecycle
are jointly load-bearing. Removing either parent state recreates a built
carrier; replacing the one-month sign with twelve-sign breadth recreates
`QM5_20222`.

## Reputable-Source Criteria

- R1: PASS. Two named-author peer-reviewed papers with DOI or official
  journal/author access and durable complete-read repository records.
- R2: PASS. Fixed season map, exact completed-month endpoints, strict sign
  mapping, agreement rule, renewal, stop, stale guard, spread cap, and retry
  state are deterministic and frozen before testing.
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
