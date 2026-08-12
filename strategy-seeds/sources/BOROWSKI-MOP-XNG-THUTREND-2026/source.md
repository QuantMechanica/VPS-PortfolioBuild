---
source_id: BOROWSKI-MOP-XNG-THUTREND-2026
status: approved
approved_by: OWNER commodity/energy sleeve mission
approved_at: 2026-07-26
---

# XNG Thursday weakness / slow-trend composite

This bounded composite joins two governed, fully reviewed academic sources:

- `strategy-seeds/sources/MEEK-HOELSCHER-XNG-DOW-2023/source.md` reports a
  negative Thursday natural-gas futures coefficient across all five of its
  conditional-mean models.
- `strategy-seeds/sources/MOP-TSMOM-2012/source.md` documents own-instrument
  time-series momentum across liquid futures, including commodities.

QM tests their conjunction: sell `XNGUSD.DWX` at a genuine Thursday D1
boundary only when its strictly completed 252-D1 log return is negative, then
flatten at the next D1 boundary. Neither paper tests this interaction, the
Darwinex continuous CFD, first-five-minute attachment, ATR stop, spread cap,
or QM portfolio. Those are fixed falsification choices, not source claims.

The closest systems are `QM5_12819_xng-thu-fade`, which is unconditional;
`QM5_20052_xng-seas-trend`, which trades broad seasonal windows; and
`QM5_12567_cum-rsi2-commodity`, which is a two-day oscillator pullback. The
Thursday clock and negative 252-D1 state are jointly load-bearing, making this
mechanic new while leaving realized correlation to Q09.

R1 PASS: named-author governed academic sources. R2 PASS: fixed weekday,
direction, state, stop, exit, and attempt rule. R3 PASS: registered native
`XNGUSD.DWX` D1 data only. R4 PASS: calendar/OHLC/log/ATR arithmetic; no ML,
external feed, banned indicator, grid, martingale, scale-in, or pyramiding.

