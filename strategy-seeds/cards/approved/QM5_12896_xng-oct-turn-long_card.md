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

Approved G0 summary: `XNGUSD.DWX` D1 long-only October-November transition
rule using the official EIA natural-gas seasonality source. Entries are weekly
gated and require a 10-D1 positive turn plus fast/slow SMA confirmation. Exits
are ATR hard stop, fast-SMA failure, season end, or max hold.

This is non-duplicate versus `QM5_12567` because it uses no cumulative-RSI,
oscillator, or short-horizon pullback trigger. It is a structural seasonal
transition sleeve and remains subject to Q02/Q04 correlation and robustness
gates.
