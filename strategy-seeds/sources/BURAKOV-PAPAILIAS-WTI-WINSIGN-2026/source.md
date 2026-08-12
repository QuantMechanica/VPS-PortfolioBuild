---
source_id: BURAKOV-PAPAILIAS-WTI-WINSIGN-2026
title: WTI November-May regime with twelve-month return-sign momentum
publisher: International Journal of Energy Economics and Policy / Journal of Banking & Finance
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-05
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-05
strategy_ids:
  - BURAKOV-PAPAILIAS-WTI-WINSIGN-2026_S01
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - PAPAILIAS-RSM-2021
---

# WTI Winter-Regime / Return-Sign Momentum Source Packet

## Source identity and complete-read evidence

This packet joins two governed peer-reviewed source lineages whose complete
texts and adverse evidence are already preserved in the repository:

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

Burakov et al. supply the fixed WTI winter interval from the last October
close through the following last May close. Papailias et al. supply the
monthly return-sign momentum rule: count the non-negative signs among the
last twelve completed monthly returns, divide by twelve, buy when that
probability is at least 0.40, otherwise sell, and renew after one month.

Neither source tests their conjunction. No source result validates a single
Darwinex WTI CFD, the seasonal interaction, completed broker-month
reconstruction, fixed cash risk, an ATR stop, costs, future efficacy, or
portfolio correlation. Burakov's positive unconditional winter result and
Papailias et al.'s adverse WTI drawdown evidence are both retained as
falsification risks.

## Bounded mechanization

`BURAKOV-PAPAILIAS-WTI-WINSIGN-2026_S01` is one predeclared interaction:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable D1 bar of each broker-calendar month;
- active regime: November through May; forced flat June through October;
- formation: thirteen synchronized completed broker-month closes defining
  twelve consecutive monthly returns;
- statistic: `non_negative_return_count / 12`;
- direction: buy at probability at least `0.40`, otherwise sell;
- lifecycle: close and, when eligible, renew at the next month boundary;
- fixed `3.5 * ATR(20,D1)` hard stop, forty-day stale guard, 1,500-point
  spread ceiling, and one restart-safe attempt per active month; and
- backtest-only `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The seven eligible months supply exactly seven possible packages per complete
post-warm-up year when history and execution gates pass. Q02 must retire the
candidate below five completed packages per year. Runtime reads native OHLC,
ATR, broker calendar, quotes, positions, deal history, and framework state
only.

## Non-duplicate boundary

The deterministic pre-allocation checker scanned 4,278 EA registry rows and
394 canonical cards. It found no exact identity and flagged the two expected
same-signal relatives for manual review:

- `QM5_13150_wti-signmom` uses the same twelve-sign probability year-round.
  This candidate owns only the November-May interaction and is forced flat
  for five months; seasonal exposure and exit are load-bearing.
- `QM5_13116_xng-signmom` uses the same source statistic on natural gas, not
  WTI, and has no WTI winter regime.
- `QM5_20209_wti-winter-mom1` uses only the exact immediately completed
  monthly return sign, not the distribution of twelve monthly signs.
- `QM5_20218_wti-winter-rev1` uses that same one-month object with the
  opposite direction.
- `QM5_20015_wti-halloween-winter` is unconditional long-only winter
  exposure; it contains no price-conditioned state.
- `QM5_20135_wti-winter-trend` uses one completed 252-D1 cumulative return.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback above a
  long-horizon filter and has neither this clock nor this statistic.

The twelve binary monthly signs, fixed 0.40 threshold, November-May gate,
June-October flat state, and monthly renewal are jointly load-bearing. Removing
the seasonal gate recreates `QM5_13150`; replacing the statistic with one
return recreates `QM5_20209`.

## Reputable-source criteria

- R1: PASS. Two named-author peer-reviewed papers, official or institutional
  access, durable complete-read records, and a DOI for the JBF paper.
- R2: PASS. Fixed months, completed endpoints, sign statistic, threshold,
  direction, renewal, stop, stale exit, spread cap, and retry state.
- R3: PASS. Registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4: PASS. Deterministic native arithmetic only; no trained model, external
  runtime feed, grid, martingale, scale-in, or pyramiding.

## Safety and claim boundary

This packet authorizes one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk backtest setfile,
and one paced Q02 enqueue under the 2026-08-05 OWNER mission. It does not
authorize a manual backtest; live, demo, or shadow execution; AutoTrading;
`T_Live`; deploy or T_Live manifests; portfolio admission; portfolio-gate
changes; or correlation waivers.
