---
source_id: LI-MOP-WTI-WEDTREND-2026
title: WTI Wednesday premium conditioned on completed 12-month time-series momentum
source_type: governed_composite_research_packet
status: approved
approved_by: OWNER commodity/energy sleeve mission
approved_at: 2026-07-25
strategy_ids: [LI-MOP-WTI-WEDTREND-2026_S01]
---

# WTI Wednesday Positive-Trend Source Packet

This governed packet mechanizes one interaction from two completely reviewed
peer-reviewed lineages already in the repository. Li, Zhu, Wen, and Nor (2022), `strategy-seeds/sources/LI-WTI-DOW-2022.md`, supply the positive WTI Wednesday direction. Moskowitz, Ooi, and Pedersen (2012),
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, supply the sign of the
instrument's own completed 12-month return as a slow directional state.

The conjunction is a QM falsification hypothesis: buy only a genuine Wednesday
WTI D1 session when the completed 252-D1 log return is positive, then flatten
at the next D1 boundary. Neither paper tests this conjunction, Darwinex's
continuous CFD, the broker-day mapping, ATR stop, spread cap, or fixed-risk
implementation.

Repository-wide deterministic dedup was CLEAN for slug `wti-wed-trend`,
strategy ID `LI-MOP-WTI-WEDTREND-2026_S01`, and mechanic "Wednesday WTI long
only when completed 252-D1 return is positive". Manual review distinguishes it
from unconditional `wti-wed-long`, year-round trend carriers,
`QM5_20149_wti-montrend`, `QM5_20145_wti-fri-trend`, and RSI2 commodity logic.

Runtime uses only native MT5 D1 OHLC, ATR, calendar, quotes, position/deal
history, and persistent attempt state. No ML, external data, grid, martingale,
scale-in, portfolio admission, live setfile, T_Live action, or manifest change
is authorized.
