---
source_id: GORSKA-MOP-WTI-TUETREND-2026
title: WTI Tuesday weakness conditioned on completed 12-month negative time-series momentum
source_type: governed_composite_research_packet
status: approved
approved_by: OWNER commodity/energy sleeve mission
approved_at: 2026-07-25
strategy_ids: [GORSKA-MOP-WTI-TUETREND-2026_S01]
---

# WTI Tuesday Negative-Trend Source Packet

This governed packet mechanizes one interaction from two completely reviewed
peer-reviewed lineages already in the repository. Gorska and Krawiec (2015),
`strategy-seeds/sources/GORSKA-WTI-CAL-2015/source.md`, supply the negative WTI
Tuesday direction. Moskowitz, Ooi, and Pedersen (2012),
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, supply the sign of the
instrument's own completed 12-month return as a slow directional state.

The conjunction is a QM falsification hypothesis: sell only a genuine Tuesday
WTI D1 session when the completed 252-D1 log return is negative, then flatten
at the next D1 boundary. Neither paper tests this conjunction, Darwinex's
continuous CFD, the broker-day mapping, ATR stop, spread cap, or fixed-risk
implementation.

Repository-wide deterministic dedup was CLEAN for slug `wti-tue-trend`,
strategy ID `GORSKA-MOP-WTI-TUETREND-2026_S01`, and mechanic "Tuesday WTI
short only when completed 252-D1 return is negative". Manual review
distinguishes it from unconditional `QM5_12610_wti-tue-fade`, year-round WTI
trend carriers, the other weekday/trend conjunctions `QM5_20145`,
`QM5_20149`, `QM5_20153`, and `QM5_20154`, and RSI2 commodity logic.

Runtime uses only native MT5 D1 OHLC, ATR, calendar, quotes, position/deal
history, and persistent attempt state. No ML, external data, grid, martingale,
scale-in, portfolio admission, live setfile, T_Live action, or manifest change
is authorized.
