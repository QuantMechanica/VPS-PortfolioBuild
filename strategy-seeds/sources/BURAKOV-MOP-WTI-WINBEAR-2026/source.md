---
source_id: BURAKOV-MOP-WTI-WINBEAR-2026
title: WTI winter-season negative-trend counterfade composite
publisher: International Journal of Energy Economics and Policy / Journal of Financial Economics
source_type: peer_reviewed_composite_lineage
status: approved_source_complete
approval_basis: OWNER commodity/energy sleeve mission 2026-07-31
created: 2026-07-31
created_by: Research+Development
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - MOP-TSMOM-2012
strategy_ids:
  - BURAKOV-MOP-WTI-WINBEAR-2026_S01
---

# WTI Winter Negative-Trend Counterfade Source Packet

## Approval and review scope

The OWNER mission dated 2026-07-31 directs one new structural,
low-frequency commodity/energy card, build, and paced Q02 enqueue. This packet
joins two already governed source lineages that were reviewed completely and
preserved in the repository:

1. Burakov, Dmitry; Freidin, Max; and Solovyev, Yuriy (2018), "The
   Halloween Effect on Energy Markets: An Empirical Study," *International
   Journal of Energy Economics and Policy* 8(2), 121-126. Governed packet:
   `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2),
   228-250. Governed packet:
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

The current source-intake router classified fresh generic retrieval of both
publisher pages as `DEFERRED:SOURCE_POLICY`; no newly retrieved page text is
used here. The exact router evidence is retained in
`retrieval_route_20260731.json`. R1 rests on the pre-existing, OWNER-approved,
complete repository reviews rather than on the blocked retrieval attempt.

## Findings used

- Burakov, Freidin, and Solovyev define their alternative-two WTI winter
  interval from the last October close through the following last May close.
  Their WTI sample reports average winter return `16.65%` versus summer return
  `-5.3%`, with preferred Wilcoxon comparison `p=0.0031` in the governed
  review packet. Those are source statistics, not QM return expectations.
- Moskowitz, Ooi, and Pedersen provide a transparent structural state: an
  instrument's own completed trailing-return sign.
- Neither paper tests a WTI winter long restricted to a negative trailing
  return, weekly CFD packages, an ATR stop, or QM portfolio correlation. The
  conjunction is a predeclared falsification hypothesis, not an inherited
  performance claim.

## Bounded mechanization

`BURAKOV-MOP-WTI-WINBEAR-2026_S01` locks one interaction:

- host and only traded symbol: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable D1 bar of each Monday-anchored broker week;
- active months: November through May; flat June through October;
- state: completed 252-D1 close-to-close log return;
- negative state: buy one WTI package; non-negative or invalid state: flat;
- ordinary exit: framework Friday close at broker hour 21;
- frozen `3.0 * ATR(20)` stop, seven-day stale guard, 1,500-point spread cap,
  and one consumed attempt per broker week; and
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

The negative state is deliberately contrary to the MOP trend direction. MOP
is used only to define a reproducible slow state; Burakov supplies the winter
long direction. The interaction asks whether the documented winter premium
is concentrated after weak trailing years. It does not claim that either
paper established that conditional result.

The seven-month window contains roughly thirty weekly boundaries per full
year. A negative 252-D1 state is expected to admit approximately 5-14
completed packages per year, but that is a queue-planning estimate only. Q02
must retire the EA below five completed packages per year on average.

## Non-duplicate boundary

The deterministic pre-allocation check scanned 4,242 EA registry rows and 377
root cards and returned `CLEAN` for slug `wti-win-bearfade`, strategy ID
`BURAKOV-MOP-WTI-WINBEAR-2026_S01`, and mechanic
`November-May weekly WTI long only when completed 252-D1 return is negative`.

Manual semantic review resolved the closest systems:

- `QM5_20135_wti-winter-trend` sells the negative 252-D1 state and renews
  monthly; this card buys that mutually exclusive directional branch weekly.
- `QM5_20015_wti-halloween-winter` is an unconditional November-May long and
  reads no price state.
- `QM5_20046_wti-halloween-ls` maps season directly to direction and reads no
  252-D1 state.
- `QM5_12963_wti-winter-exhaust` is a short-only price-stretch fade.
- `QM5_20141_wti-sumtrend` and `QM5_20182_wti-sum-bull` trade the disjoint
  July-November short window.
- `QM5_12603_wti-tsmom12m` follows the return sign year-round and would sell,
  not buy, in this card's admitted state.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback on the
  incumbent commodity carrier, not calendar/slow-state WTI logic.

The active season, negative completed return state, long direction, weekly
attempt clock, and Friday-flat lifecycle are jointly load-bearing. Changing
any one creates a different or already-built mechanic.

## Reputable-source criteria

- R1: PASS. Two named-author peer-reviewed source lineages have complete,
  durable, OWNER-approved repository reviews.
- R2: PASS. Months, return horizon, sign, direction, attempt clock, stop,
  stale exit, spread cap, and Friday close are deterministic and locked.
- R3: PASS. Registered `XTIUSD.DWX` D1 history supplies all runtime data.
- R4: PASS. Runtime uses native OHLC, ATR, calendar, execution, position/deal
  history, and framework state only; no prohibited model, external feed,
  grid, martingale, scale-in, or pyramiding.

## Evidence and claim boundary

No source PF, drawdown, trade count, transaction-cost result, CFD/futures
basis assumption, or correlation estimate transfers to QM. Continuous CFD
roll construction, financing, gaps, source-sample decay, conditional density,
and winter crash behavior are binding Q02 and downstream kill risks.

This approval covers one card, one deterministic registry allocation, one V5
build, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does
not authorize a live setfile, AutoTrading, `T_Live`, a deploy manifest,
portfolio admission, a portfolio-gate change, or a correlation waiver.
