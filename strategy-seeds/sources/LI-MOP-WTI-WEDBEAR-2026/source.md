---
source_id: LI-MOP-WTI-WEDBEAR-2026
title: WTI Wednesday premium conditioned on a negative completed 12-month return
source_type: governed_composite_research_packet
status: approved
approved_by: OWNER commodity/energy sleeve mission
approved_at: 2026-07-26
strategy_ids: [LI-MOP-WTI-WEDBEAR-2026_S01]
---

# WTI Wednesday Bear-Regime Bounce Source Packet

This bounded packet combines two completely reviewed peer-reviewed lineages.
Li, Zhu, Wen, and Nor (2022), preserved at
`strategy-seeds/sources/LI-WTI-DOW-2022.md`, supply the positive WTI Wednesday
direction.
Moskowitz, Ooi, and Pedersen (2012), preserved at
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, supply the sign of the
instrument's completed 12-month own return as a slow regime state.

The conjunction is explicitly a QM falsification hypothesis, not an author
claim: buy a genuine Wednesday WTI D1 session only while the completed 252-D1
log return is negative, then flatten at the next D1 boundary. It tests whether
the weekday premium behaves as a bear-regime bounce rather than as another
positive-trend carrier.

Repository review distinguishes this mechanic from positive-regime Wednesday
`QM5_20154_wti-wed-trend`, negative-regime Thursday
`QM5_20169_wti-thu-bear`, other calendar/event builds, XNG sleeves, and
commodity RSI logic. Runtime uses native MT5 D1 OHLC, ATR, broker calendar,
quotes, positions, deals, and persistent attempt state only. No ML, external
data, grid, martingale, scale-in, live action, or portfolio admission is
authorized.
