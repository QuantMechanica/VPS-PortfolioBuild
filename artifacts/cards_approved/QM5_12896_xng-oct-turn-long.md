---
copy_of: strategy-seeds/cards/xng-oct-turn-long_card.md
ea_id: QM5_12896
slug: xng-oct-turn-long
type: strategy
strategy_id: EIA-XNG-OCT-TURN-2026
source_id: 706222b7-2d60-5fdb-8dab-d722d3c96f92
target_symbols: [XNGUSD.DWX]
timeframes: [D1]
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-02
---

# XNG October Winter-Turn Long

Canonical card: `strategy-seeds/cards/xng-oct-turn-long_card.md`.

Build scope: `XNGUSD.DWX` D1, long-only October-November seasonal transition
rule. Runtime uses only Darwinex OHLC/spread, broker calendar, ATR/SMA, and
framework guards. Backtest setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`.
No live manifest, `T_Live`, AutoTrading, or portfolio gate is touched.
