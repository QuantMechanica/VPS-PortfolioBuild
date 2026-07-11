---
copy_of: strategy-seeds/cards/energy-bab_card.md
strategy_id: FRAZZINI-BAB-2014_XTI_XNG_S01
source_id: FRAZZINI-BAB-2014
ea_id: QM5_13132
slug: energy-bab
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13132_XTI_XNG_BAB_D1
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# Approved Card Copy - QM5_13132_energy-bab

The canonical approved card is `strategy-seeds/cards/energy-bab_card.md`.
Approval covers exactly the source's one-year daily Dimson beta estimator,
five market-return lags, 0.5 shrinkage toward one, low-beta-long and
high-beta-short direction, two-leg equal-risk energy benchmark, inverse-beta
notional target, post-rounding beta-mismatch guard, monthly package, frozen
ATR hard stops, stale exit, same-month deal-history guard, and orphan cleanup.

Approval preserves the broad-futures-to-two-CFD narrowing, benchmark
endogeneity, raw-return proxy, financing/roll mismatch, and commodity-only
source weakness as binding Q02 kill risks. No live artifact or portfolio
admission is approved.

Q01 passed with zero compile errors or warnings. Logical-basket Q02 work item
`92097f32-58bb-4c86-9b54-5ee371716499` is pending and unclaimed.
