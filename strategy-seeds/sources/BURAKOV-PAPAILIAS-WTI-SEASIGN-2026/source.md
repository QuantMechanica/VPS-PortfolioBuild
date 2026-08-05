---
source_id: BURAKOV-PAPAILIAS-WTI-SEASIGN-2026
title: WTI seasonal-direction and twelve-month return-sign concordance
publisher: International Journal of Energy Economics and Policy / Journal of Banking & Finance
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-05
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-05
strategy_ids:
  - BURAKOV-PAPAILIAS-WTI-SEASIGN-2026_S01
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - PAPAILIAS-RSM-2021
---

# WTI Seasonal / Return-Sign Concordance Source Packet

## Source identity and complete-read evidence

This packet joins two governed peer-reviewed lineages whose complete texts,
method details, source statistics, and adverse evidence are preserved locally:

1. Burakov, Dmitry; Freidin, Max; and Solovyev, Yuriy (2018), "The
   Halloween Effect on Energy Markets: An Empirical Study," *International
   Journal of Energy Economics and Policy* 8(2), 121-126. The complete open
   paper and its conflicting abstract/table labels are reconciled in
   `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`.
2. Papailias, Fotis; Liu, Jiadong; and Thomakos, Dimitrios D. (2021),
   "Return Signal Momentum," *Journal of Banking & Finance* 124, 106063,
   DOI `10.1016/j.jbankfin.2021.106063`. The complete 83-page accepted
   manuscript, including WTI-specific Tables G.1-G.3, is reviewed in
   `strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md`.

Burakov et al. supply a fixed WTI seasonal direction: positive November-May
exposure and negative June-October exposure under their alternative-two
partition. Papailias et al. supply the monthly return-sign state: count the
non-negative signs among the twelve completed monthly returns, divide by
twelve, classify the state long at probability at least 0.40 and short below
0.40, and renew monthly.

Neither source tests the agreement filter created here. No source result
validates a Darwinex continuous WTI CFD, the interaction, broker-month
reconstruction, fixed cash risk, an ATR stop, transaction costs, future
efficacy, or portfolio correlation. Burakov's editorial inconsistencies and
Papailias et al.'s adverse WTI drawdown evidence remain explicit kill risks.

## Bounded mechanization

`BURAKOV-PAPAILIAS-WTI-SEASIGN-2026_S01` is one predeclared concordance rule:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable D1 bar of every broker-calendar month;
- seasonal state: long November-May and short June-October;
- formation: thirteen consecutive completed broker-month closes defining
  twelve completed monthly returns;
- sign state: `non_negative_return_count / 12`, long at `>= 0.40`, short
  below `0.40`;
- entry: open only when seasonal direction and sign direction agree; remain
  flat for a disagreement;
- lifecycle: close before every monthly decision and hold no longer than
  forty calendar days;
- fixed `3.5 * ATR(20,D1)` hard stop, 1,500-point spread ceiling, and one
  restart-safe consumed attempt per calendar month; and
- backtest-only `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The calendar offers twelve decisions per complete post-warm-up year. The
predeclared expectation is six to nine completed packages per year because
disagreement months remain flat; Q02 must retire the candidate below five
completed packages per year. Runtime reads native OHLC, ATR, broker calendar,
quotes, positions, deal history, and framework state only.

## Non-duplicate boundary

The deterministic pre-allocation checker scanned 4,279 EA registry rows and
395 canonical cards. It found no exact identity and no fuzzy match above its
threshold. Manual mechanic review fixes the nearest boundaries:

- `QM5_20046_wti-halloween-ls` and `QM5_20093_wti-summer-short` take
  unconditional calendar exposure; this candidate must remain flat whenever
  the price state disagrees.
- `QM5_13150_wti-signmom` follows the twelve-sign state in all months without
  a seasonal-direction agreement requirement.
- `QM5_20221_wti-win-signmom` applies the sign state symmetrically only in
  November-May and is forced flat June-October; this candidate never shorts
  winter or buys summer and can trade either season only on concordance.
- `QM5_20205_wti-calmom1` requires a ten-year same-calendar mean and the exact
  immediately completed one-month sign; it does not count twelve binary
  return signs or use the Burakov partition.
- `QM5_20136_wti-caltrend` combines a same-calendar historical mean with a
  63-D1 cumulative-return sign, not the fixed seasonal direction and
  twelve-sign probability used here.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback above a
  long-horizon filter and has neither this clock nor this state.

The two fixed seasonal directions, twelve binary signs, 0.40 threshold,
agreement-only entry, disagreement-flat state, and monthly renewal are
jointly load-bearing. Removing the agreement gate recreates a built parent.

## Reputable-source criteria

- R1: PASS. Two named-author peer-reviewed papers, official or institutional
  access, durable complete-read records, and a DOI for the JBF paper.
- R2: PASS. Fixed months, seasonal direction, completed endpoints, sign
  statistic, threshold, concordance mapping, renewal, stop, stale exit,
  spread cap, and retry state.
- R3: PASS. Registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4: PASS. Deterministic native arithmetic only; no trained model, external
  runtime feed, grid, martingale, scale-in, or pyramiding.

## Safety and claim boundary

This packet authorizes one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk backtest
setfile, and one paced Q02 enqueue under the 2026-08-05 OWNER mission. It does
not authorize a manual backtest; live, demo, or shadow execution;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio admission;
portfolio-gate changes; or correlation waivers.
