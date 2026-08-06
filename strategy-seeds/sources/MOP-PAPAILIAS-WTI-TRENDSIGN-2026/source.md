---
source_id: MOP-PAPAILIAS-WTI-TRENDSIGN-2026
title: WTI twelve-month trend and return-sign concordance
publisher: Journal of Financial Economics / Journal of Banking & Finance
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-06
strategy_ids:
  - MOP-PAPAILIAS-WTI-TRENDSIGN-2026_S01
parent_sources:
  - MOP-TSMOM-2012
  - PAPAILIAS-RSM-2021
---

# WTI Trend / Return-Sign Concordance Source Packet

## Source identity and complete-read evidence

This packet joins two governed peer-reviewed lineages whose complete texts,
mechanics, source statistics, and adverse boundaries are preserved locally:

1. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
   DOI `10.1016/j.jfineco.2011.11.003`. The complete 23-page published paper,
   durable PDF hash, WTI universe membership, and monthly own-return rule are
   recorded in `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.
2. Papailias, Fotis; Liu, Jiadong; and Thomakos, Dimitrios D. (2021),
   "Return Signal Momentum," *Journal of Banking & Finance* 124, 106063,
   DOI `10.1016/j.jbankfin.2021.106063`. The complete 83-page accepted
   manuscript, including WTI-specific Tables G.1-G.3 and adverse drawdown
   evidence, is reviewed in
   `strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md`.

Moskowitz et al. supply the sign of an instrument's own prior twelve-month
return and a monthly decision/hold cadence. Papailias et al. supply the
distributional sign state: encode each of twelve completed monthly returns as
one when non-negative and zero when negative, average the indicators, and hold
long at a fixed probability of at least 0.40 or short below 0.40.

Both papers explicitly include WTI futures. Neither tests the agreement filter
created here. No source result validates the Darwinex continuous WTI CFD, the
conjunction, broker-month reconstruction, fixed cash risk, an ATR stop,
transaction costs, future efficacy, or portfolio correlation. Papailias et
al.'s worse WTI maximum-drawdown result versus conventional time-series
momentum remains an explicit adverse boundary.

## Bounded mechanization

`MOP-PAPAILIAS-WTI-TRENDSIGN-2026_S01` is one predeclared concordance rule:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable D1 bar of every broker-calendar month;
- formation: thirteen consecutive completed broker-month closes defining
  twelve completed monthly log returns;
- trend state: long when the cumulative twelve-month log return is positive,
  short when negative, and flat when exactly zero;
- sign state: `non_negative_return_count / 12`, long at `>= 0.40` and short
  below `0.40`;
- entry: open only when trend and sign directions agree; otherwise consume the
  month and remain flat;
- lifecycle: close before every monthly decision and hold no longer than forty
  calendar days;
- fixed `3.5 * ATR(20,D1)` hard stop, 1,500-point spread ceiling, and one
  restart-safe consumed attempt per calendar month; and
- backtest-only `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The clock offers twelve decisions per complete post-warm-up year. The
predeclared expectation is eight to eleven completed packages per year; Q02
must retire the candidate below five completed packages per full year. Runtime
reads native OHLC, ATR, broker calendar, quotes, positions, deal history, and
framework state only.

## Non-duplicate boundary

The deterministic pre-allocation checker scanned 4,301 EA-registry rows and
418 canonical cards. It found no exact identity and no fuzzy match above its
threshold. Manual mechanic review fixes the nearest boundaries:

- pure WTI time-series-momentum EAs, including `QM5_12603_wti-tsmom12m`, use
  one cumulative-return direction without the twelve-return sign-distribution
  agreement gate;
- `QM5_13150_wti-signmom` follows the sign-distribution state every month
  without requiring agreement from the cumulative twelve-month return;
- `QM5_20056_wti-dual-mom` requires 63-D1 and 252-D1 cumulative-return signs
  to agree; it does not count twelve separate completed-month signs;
- `QM5_20222_wti-seas-sign` combines the sign state with a fixed
  November-May/June-October calendar direction, not WTI's own cumulative
  return;
- `QM5_20239_wti-pulltrend` uses a twelve-month trend ending before a separate
  adverse newest month and requires opposition, not concordance over the same
  twelve-return formation window; and
- `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator pullback
  with neither this information object nor this clock.

The common twelve-return window, cumulative log-return direction, twelve
binary signs, fixed 0.40 threshold, agreement-only entry, disagreement-flat
state, and monthly renewal are jointly load-bearing. Removing the agreement
gate recreates a built parent.

## Reputable-source criteria

- R1: PASS. Two named-author peer-reviewed papers, DOI records, durable
  complete-read packets, and explicit WTI membership.
- R2: PASS. Completed endpoints, both state formulas, threshold, concordance
  mapping, renewal, stop, stale exit, spread cap, and retry state are fixed.
- R3: PASS. Registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4: PASS. Deterministic native arithmetic only; no trained model, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramiding.

## Safety and claim boundary

This packet authorizes one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk backtest setfile,
and one paced Q02 enqueue under the 2026-08-06 OWNER mission. It does not
authorize a manual backtest; live, demo, or shadow execution; AutoTrading;
`T_Live`; deploy or T_Live manifests; portfolio admission; portfolio-gate
changes; or correlation waivers.
