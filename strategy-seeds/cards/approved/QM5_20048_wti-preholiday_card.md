---
copy_of: strategy-seeds/cards/wti-preholiday_card.md
ea_id: QM5_20048
slug: wti-preholiday
strategy_id: QADAN-AHARON-EICHEL-2019_WTI_HOL_S01
source_id: QADAN-AHARON-EICHEL-2019
status: APPROVED
g0_status: APPROVED
created: 2026-07-22
created_by: Research+Development
last_updated: 2026-07-22
target_symbols: [XTIUSD.DWX]
period: D1
expected_trades_per_year_per_symbol: 8
pipeline_phase: Q02
r1_track_record: TIER_A
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_pf: 1.05
expected_dd_pct: 18.0
review_focus: "Adds a holiday-sentiment WTI return driver; retire on source-decay, density, economics, or correlation failure."
---

# Approved Card Copy — QM5_20048_wti-preholiday

Approval covers exactly the eight-holiday, long-only WTI D1 carrier defined in
`strategy-seeds/cards/wti-preholiday_card.md`: deterministic observed-holiday
mapping, one pre-holiday attempt, first-subsequent-bar exit, fixed ATR stop,
`RISK_FIXED` backtest sizing, and no parameter or direction fishing.

Q02 must retire the edge below five completed packages/year or on governed
economics. No live or portfolio mutation is approved.
