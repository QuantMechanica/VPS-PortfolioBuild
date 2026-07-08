# Strategy Card Copy - QM5_13061_brent-jun-prem

Canonical card: `strategy-seeds/cards/brent-jun-prem_card.md`

This EA mechanizes the approved Brent June calendar-premium card. It trades
only `XBRUSD.DWX` at D1, enters long on broker-calendar June bars, and exits
on the next D1 bar, on month-end, or by the stale-position guard.

Runtime uses Darwinex MT5 OHLC, broker calendar, ATR, spread, and V5 framework
state only. No live manifest, `T_Live`, AutoTrading setting, or portfolio gate
is touched by this build.
