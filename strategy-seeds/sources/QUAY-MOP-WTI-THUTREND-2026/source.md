---
source_id: QUAY-MOP-WTI-THUTREND-2026
title: WTI Thursday premium conditioned on completed 12-month time-series momentum
source_type: governed_composite_research_packet
status: approved
approved_by: OWNER commodity/energy sleeve mission
approved_at: 2026-07-25
strategy_ids: [QUAY-MOP-WTI-THUTREND-2026_S01]
---

# WTI Thursday Positive-Trend Source Packet

This governed packet mechanizes one interaction from two completely reviewed
peer-reviewed lineages already in the repository. Quayyum, Khan, and Ali
(2020), `strategy-seeds/sources/QUAY-WTI-DOW-2019/source.md`, supply the
positive WTI Thursday direction. Moskowitz, Ooi, and Pedersen (2012),
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, supply the sign of the
instrument's own completed 12-month return as a slow directional state.

The conjunction is a QM falsification hypothesis: buy only a genuine Thursday
WTI D1 session when the completed 252-D1 log return is positive, then flatten
at the next D1 boundary. Neither paper tests this conjunction, Darwinex's
continuous CFD, the broker-day mapping, ATR stop, spread cap, or fixed-risk
implementation.

Repository-wide deterministic dedup was CLEAN for slug `wti-thu-trend`,
strategy ID `QUAY-MOP-WTI-THUTREND-2026_S01`, and mechanic "Thursday WTI long
only when completed 252-D1 return is positive". Manual review distinguishes it
from unconditional `wti-thu-prem`, year-round trend carriers,
`QM5_20149_wti-montrend`, `QM5_20145_wti-fri-trend`, and RSI2 commodity logic.

Runtime uses only native MT5 D1 OHLC, ATR, calendar, quotes, position/deal
history, and persistent attempt state. No ML, external data, grid, martingale,
scale-in, portfolio admission, live setfile, T_Live action, or manifest change
is authorized.
