---
source_id: GORSKA-MOP-WTI-TUEBULL-2026
title: WTI Tuesday weakness conditioned on completed 12-month positive time-series momentum
source_type: governed_composite_research_packet
status: approved
approved_by: OWNER commodity/energy sleeve mission
approved_at: 2026-07-26
strategy_ids: [GORSKA-MOP-WTI-TUEBULL-2026_S01]
---

# WTI Tuesday Positive-Trend Counterfade Source Packet

This governed packet mechanizes one interaction from two completely reviewed
peer-reviewed lineages already in the repository. Gorska and Krawiec (2015),
`strategy-seeds/sources/GORSKA-WTI-CAL-2015/source.md`, supply the negative WTI
Tuesday direction. Moskowitz, Ooi, and Pedersen (2012),
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, supply the sign of the
instrument's own completed 12-month return as a slow directional state.

The conjunction is a QM falsification hypothesis: sell only a genuine Tuesday
WTI D1 session when the completed 252-D1 log return is positive, then flatten
at the next D1 boundary. The calendar effect therefore opposes, rather than
follows, the slow trend. Neither paper tests this conjunction, Darwinex's
continuous CFD, the broker-day mapping, ATR stop, spread cap, or fixed-risk
implementation.

Repository-wide text and registry review found no existing slug
`wti-tue-bullfade`, strategy ID `GORSKA-MOP-WTI-TUEBULL-2026_S01`, or mechanic
"Tuesday WTI short only when completed 252-D1 return is positive". The closest
systems are the unconditional `QM5_12610_wti-tue-fade` and
`QM5_20155_wti-tue-trend`, which requires the opposite, negative trend state.
The positive-state conjunction is load-bearing and cannot be removed without
recreating an existing parent.

Runtime uses only native MT5 D1 OHLC, ATR, calendar, quotes, position/deal
history, and persistent attempt state. No ML, external data, grid, martingale,
scale-in, portfolio admission, live setfile, T_Live action, or manifest change
is authorized.
