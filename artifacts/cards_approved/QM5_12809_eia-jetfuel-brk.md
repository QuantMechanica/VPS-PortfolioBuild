---
ea_id: QM5_12809
slug: eia-jetfuel-brk
source_id: EIA-JETFUEL-SEASON-2026
g0_status: APPROVED
pipeline_phase: Q02
target_symbols: [XTIUSD.DWX]
period: D1
expected_trades_per_year_per_symbol: 8
created: 2026-06-30
q02_work_item: bf861753-130b-49d4-9f0b-3e6623d8f515
---

# QM5_12809 EIA Jet Fuel Summer Breakout

Approved structural card for a single-symbol `XTIUSD.DWX` D1 WTI sleeve.

Source lineage:

- EIA, "Jet fuel made up a record share of U.S. refinery output in 2024",
  March 24, 2025, https://www.eia.gov/todayinenergy/detail.php?id=64786.
- EIA, "U.S. jet fuel consumption growth slows after air travel recovers from
  pandemic slowdown", August 26, 2025,
  https://www.eia.gov/todayinenergy/detail.php?id=66004.
- EIA, "U.S. jet fuel production rises after prices doubled in March", June 8,
  2026, https://www.eia.gov/todayinenergy/detail.php?id=67764.

Mechanization: May 15-August 31 long-only D1 breakout on `XTIUSD.DWX`, gated by
SMA trend, ATR hard stop, Donchian/date/time exits, one magic slot, RISK_FIXED
backtest setfile. No EIA/runtime external feed, ML, grid, martingale, or live
manifest changes.

Q02 enqueue: `bf861753-130b-49d4-9f0b-3e6623d8f515`, status `pending`, symbol
`XTIUSD.DWX`, timeframe `D1`.
