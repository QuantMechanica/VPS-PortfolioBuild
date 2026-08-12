---
source_id: QUAY-MOP-WTI-THUBEAR-2026
title: WTI Thursday premium conditioned on a negative completed 12-month return
source_type: governed_composite_research_packet
status: approved
approved_by: OWNER commodity/energy sleeve mission
approved_at: 2026-07-26
strategy_ids: [QUAY-MOP-WTI-THUBEAR-2026_S01]
---

# WTI Thursday Bear-Regime Bounce Source Packet

This bounded packet combines two completely reviewed peer-reviewed lineages.
Quayyum, Khan, and Ali (2020), preserved at
`strategy-seeds/sources/QUAY-WTI-DOW-2019/source.md`, supply the positive WTI
Thursday direction. Moskowitz, Ooi, and Pedersen (2012), preserved at
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, supply the sign of the
instrument's completed 12-month own return as a slow regime state.

The conjunction is explicitly a QM falsification hypothesis, not an author
claim: buy a genuine Thursday WTI D1 session only while the completed 252-D1
log return is negative, then flatten at the next D1 boundary. It tests whether
the weekday premium behaves as a bear-regime bounce rather than as another
year-round trend carrier.

Repository review distinguishes this mechanic from the unconditional Thursday
premium, `QM5_20153_wti-thu-trend` (which requires positive 252-D1 return),
other weekday/trend conjunctions, WTI event/calendar builds, XNG sleeves, and
commodity RSI logic. Runtime uses native MT5 D1 OHLC, ATR, calendar, quotes,
positions, deals, and persistent attempt state only. No ML, external data,
grid, martingale, scale-in, live action, or portfolio admission is authorized.
