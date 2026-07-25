---
source_id: BOROWSKI-MOP-XNG-TUETREND-2026
status: approved
approved_by: OWNER commodity/energy sleeve mission
approved_at: 2026-07-25
---

# XNG Tuesday premium / slow-trend composite

This bounded composite joins two already governed, completely reviewed,
peer-reviewed source packets:

- `strategy-seeds/sources/BOROWSKI-COMM-DOW-2016/source.md`: Borowski (2016)
  reports a positive Tuesday natural-gas futures sample return and a weekday
  population-test p-value of 0.0136.
- `strategy-seeds/sources/MOP-TSMOM-2012/source.md`: Moskowitz, Ooi and
  Pedersen (2012) provide the instrument-own trailing-return-sign state.

QM's falsification hypothesis is narrower than either parent: buy
`XNGUSD.DWX` only at a genuine Tuesday D1 boundary when the completed
252-D1 log return is positive, then flatten at the next D1 boundary. The
weekday direction and slow state are jointly load-bearing.

Neither paper tests this conjunction, the Darwinex continuous CFD, the
five-minute attachment rule, ATR stop, spread cap, persistent weekly attempt,
or QM portfolio correlation. Those are fixed implementation and risk choices,
not source claims.

Runtime uses registered native MT5 OHLC, ATR, quotes, calendar, positions and
deal history only. No external feed, ML, grid, martingale, pyramiding, or
adaptive fitting is authorized.

The closest build, `QM5_12818_xng-tue-prem`, is unconditional and never reads
the 252-D1 trend. `QM5_12567_cum-rsi2-commodity` is a two-day oscillator
pullback. This interaction is therefore mechanically distinct, while Q02 and
later portfolio evidence retain full authority to retire it.
