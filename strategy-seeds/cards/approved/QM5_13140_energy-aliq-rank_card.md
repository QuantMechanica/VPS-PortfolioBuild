---
copy_of: strategy-seeds/cards/energy-aliq-rank_card.md
strategy_id: YIYI-ALIQ-2025_XTI_XNG_S01
source_id: YIYI-ALIQ-2025
ea_id: QM5_13140
slug: energy-aliq-rank
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13140_XTI_XNG_ALIQ_D1
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# Approved Card Copy - QM5_13140_energy-aliq-rank

The canonical approved card is
strategy-seeds/cards/energy-aliq-rank_card.md. Approval covers exactly the
prior-12-completed-month mean of daily absolute log return divided by same-day
MT5 tick volume, high-ALIq-versus-low-ALIq XTI/XNG rank, monthly cadence,
equal half-risk paired package, ATR hard stops, next-month and stale exits,
same-month deal-history guard, and orphan cleanup.

Approval preserves tick volume versus source dollar volume, two CFDs versus
the source's 34-futures universe, continuous-CFD construction, and execution
costs as binding Q02 kill risks. IPCA, PCA, regression, live artifacts,
portfolio admission, and portfolio-gate changes are not approved.
