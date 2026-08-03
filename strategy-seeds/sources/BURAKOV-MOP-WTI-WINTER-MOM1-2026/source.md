---
source_id: BURAKOV-MOP-WTI-WINTER-MOM1-2026
title: WTI November-May regime with one-month time-series momentum
publisher: International Journal of Energy Economics and Policy / Journal of Financial Economics
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-03
created_by: Research+Development
last_updated: 2026-08-03
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-03
strategy_ids:
  - BURAKOV-MOP-WTI-WINTER-MOM1-2026_S01
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - MOP-TSMOM-2012
---

# WTI Winter-Regime / One-Month Momentum Source Packet

## Source identity and complete-read evidence

This packet joins two already governed peer-reviewed source lineages that were
read completely for this extraction:

1. Burakov, Dmitry; Freidin, Max; and Solovyev, Yuriy (2018), "The
   Halloween Effect on Energy Markets: An Empirical Study," *International
   Journal of Energy Economics and Policy* 8(2), 121-126. The complete open
   six-page paper and its conflicting abstract/table labels are documented in
   `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
   DOI `10.1016/j.jfineco.2011.11.003`. The complete published-paper review,
   retrieval hash, and one-month commodity result are documented in
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

Burakov et al. define their WTI alternative-two winter interval from the last
October close through the following last May close. MOP define a commodity
time-series-momentum family in which the sign of an instrument's own past
`k`-month return selects long or short exposure for `h` months; their Table 2
explicitly includes `k=1`, `h=1`, and Appendix A includes NYMEX WTI.

Neither source tests the conjunction below. Burakov's reported WTI winter
premium is not imported as an unconditional long instruction, and MOP do not
report a WTI-only one-month result. No source performance, correlation,
transaction-cost, CFD-basis, drawdown, or portfolio statistic transfers.

## Bounded mechanization

`BURAKOV-MOP-WTI-WINTER-MOM1-2026_S01` is one predeclared interaction:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable D1 bar of each broker-calendar month;
- active regime: November through May; forced flat June through October;
- formation: the exact just-completed consecutive broker-calendar-month WTI
  close-to-close log return;
- positive return: buy one monthly package; negative return: short one monthly
  package; equality or invalid endpoints: remain flat for the consumed month;
- exit and, when eligible, renew at the next month boundary;
- frozen `3.5 * ATR(20,D1)` hard stop, forty-day stale guard, 1,500-point
  spread ceiling, and one restart-safe attempt per active month; and
- backtest-only `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The seven eligible months supply an expected seven decisions per complete
year. Q02 must retire the candidate below five completed packages per full
post-warm-up year. The EA reads only native OHLC, ATR, broker calendar,
quotes, positions, deal history, and V5 framework state.

## Non-duplicate boundary

The deterministic pre-allocation check scanned 4,265 EA registry rows and 386
cards and returned `CLEAN` for slug `wti-winter-mom1`, strategy ID
`BURAKOV-MOP-WTI-WINTER-MOM1-2026_S01`, and the exact mechanic. Manual review
fixes the nearest boundaries:

- `QM5_20135_wti-winter-trend` uses a completed 252-D1 return inside the same
  winter regime; it does not use exact consecutive month-end endpoints.
- `QM5_20187_wti-tsmom1m` uses the completed one-month sign year-round; it has
  no November-May regime or June season exit.
- `QM5_20015_wti-halloween-winter` is unconditional long-only in winter.
- `QM5_20046_wti-halloween-ls` maps calendar season directly to direction and
  has no price-conditioned state.
- `QM5_20205_wti-calmom1` estimates each decision month's recurring historical
  return and requires agreement; this packet has no same-calendar estimator.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback with a
  multiday lifecycle, not a monthly WTI seasonal trend state.

The exact prior completed month, symmetric sign map, fixed November-May gate,
June-October flat state, and monthly renewal are jointly load-bearing. A
different horizon, regime, direction map, or carrier requires a new card.

## Reputable-source criteria

- R1: PASS. Two named-author peer-reviewed papers, official or institutional
  access, durable complete-read records, and DOI where assigned.
- R2: PASS. Fixed months, completed endpoints, sign directions, renewal, hard
  stop, stale exit, spread cap, and retry state are deterministic.
- R3: PASS. Registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4: PASS. Native arithmetic only; no trained model, external runtime feed,
  grid, martingale, scale-in, or pyramiding.

## Safety and claim boundary

This packet authorizes one branch-only Strategy Card, registry allocation,
non-live V5 build, strict compile, one fixed-risk setfile, and one paced Q02
enqueue under the 2026-08-03 OWNER mission. It does not authorize live, demo,
or shadow execution; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio admission; portfolio-gate changes; or correlation waivers.

