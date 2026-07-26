---
source_id: GORSKA-MOP-WTI-FRIBEAR-2026
title: WTI Friday premium conditioned on a negative completed 12-month return
source_type: governed_composite_research_packet
status: approved
approved_by: OWNER commodity/energy sleeve mission
approved_at: 2026-07-26
strategy_ids: [GORSKA-MOP-WTI-FRIBEAR-2026_S01]
---

# WTI Friday Bear-Regime Bounce Source Packet

This bounded packet combines two fully reviewed peer-reviewed lineages.
Gorska and Krawiec (2015), preserved at
`strategy-seeds/sources/GORSKA-WTI-CAL-2015/source.md`, supply the positive WTI
Friday direction. Moskowitz, Ooi, and Pedersen (2012), preserved at
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, supply the sign of the
instrument's completed 12-month own return as a slow regime state.

The conjunction is explicitly a QM falsification hypothesis, not an author
claim: buy a genuine Friday WTI D1 session only while the completed 252-D1 log
return is negative, then flatten through the framework Friday-close control.
It tests whether the weekday premium behaves as a bear-regime bounce instead
of adding another positive-trend commodity carrier.

Repository review distinguishes this mechanic from the unconditional Friday
premium, `QM5_12597_wti-fri-prem`; `QM5_20145_wti-fri-trend`, which requires a
positive 252-D1 return; the Thursday and Wednesday bear-regime variants; WTI
event/calendar builds; XNG sleeves; and `QM5_12567_cum-rsi2-commodity`.
Runtime uses native MT5 D1 OHLC, ATR, calendar, quotes, positions, deals, and
persistent attempt state only. No ML, external data, grid, martingale,
scale-in, live action, or portfolio admission is authorized.
