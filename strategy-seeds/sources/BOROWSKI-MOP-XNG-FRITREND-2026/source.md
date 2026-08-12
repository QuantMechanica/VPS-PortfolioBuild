---
source_id: BOROWSKI-MOP-XNG-FRITREND-2026
title: XNG Friday weakness conditioned on completed 12-month negative time-series momentum
source_type: governed_composite_research_packet
quality_tier: A
status: approved_for_cards
approved_for_cards: true
approval_record: "OWNER commodity/energy sleeve mission, 2026-07-25"
created: 2026-07-25
created_by: Research+Development
parent_sources:
  - BOROWSKI-COMM-DOW-2016
  - MOP-TSMOM-2012
cards_extracted:
  - xng-fri-trend
strategy_ids:
  - BOROWSKI-MOP-XNG-FRITREND-2026_S01
---

# XNG Friday Weakness / Slow-Trend Composite

This bounded composite joins two governed, completely reviewed,
peer-reviewed source packets:

- `strategy-seeds/sources/BOROWSKI-COMM-DOW-2016/source.md`: Borowski
  (2016) reports a negative Friday natural-gas futures sample return.
- `strategy-seeds/sources/MOP-TSMOM-2012/source.md`: Moskowitz, Ooi, and
  Pedersen (2012) provide the instrument-own trailing-return-sign state.

QM's falsification hypothesis is narrower than either parent: sell
`XNGUSD.DWX` only at a genuine Friday D1 boundary when the completed
252-D1 log return is negative, then flatten through the governed Friday-close
control. The weekday direction and slow state are jointly load-bearing.

Neither paper tests this conjunction, the Darwinex continuous CFD, the
five-minute attachment rule, ATR stop, spread cap, persistent weekly attempt,
or QM portfolio correlation. Those are fixed implementation and risk choices,
not source claims.

Runtime uses registered native MT5 OHLC, ATR, quotes, calendar, positions, and
deal history only. No external feed, ML, grid, martingale, pyramiding, or
adaptive fitting is authorized.

The closest build, `QM5_20094_xng-fri-short`, is unconditional and never reads
the completed 252-D1 trend. `QM5_12567_cum-rsi2-commodity` is a two-day
oscillator pullback. The interaction is mechanically distinct, while Q02 and
later portfolio evidence retain full authority to retire it.
