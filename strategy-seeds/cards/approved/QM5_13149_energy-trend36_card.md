---
copy_of: strategy-seeds/cards/energy-trend36_card.md
strategy_id: HOLLSTEIN-3YR-2021_XTI_XNG_S01
source_id: HOLLSTEIN-3YR-2021
ea_id: QM5_13149
slug: energy-trend36
status: APPROVED
g0_status: APPROVED
created: 2026-07-12
created_by: Research
last_updated: 2026-07-12
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13149_XTI_XNG_TREND36_D1
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# Approved Card Copy - QM5_13149_energy-trend36

The canonical approved card is
`strategy-seeds/cards/energy-trend36_card.md`. Approval covers exactly 36
consecutive completed monthly simple returns, arithmetic-average ranking,
high-minus-low XTI/XNG direction, monthly cadence, equal half-risk paired
execution, ATR hard stops, next-month/stale exits, same-month deal-history
guard, and orphan cleanup.

Approval preserves the source's insignificant two-portfolio result,
insignificant cross-sectional slope, broad-futures-to-two-CFD narrowing,
continuous-CFD basis, and legging as binding Q02 kill risks. Q01 passed and
logical basket work item `be4eb919-5e5a-4b0b-8c88-561a5fcc2b1e` is pending at
Q02. No live artifact or portfolio admission is approved.
