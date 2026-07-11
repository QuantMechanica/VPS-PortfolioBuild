---
copy_of: strategy-seeds/cards/energy-es-rank_card.md
strategy_id: YIYI-ES-2025_XTI_XNG_S02
source_id: YIYI-ES-2025
ea_id: QM5_13143
slug: energy-es-rank
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13143_XTI_XNG_ES_D1
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
---

# Approved Card Copy - QM5_13143_energy-es-rank

The canonical approved card is
strategy-seeds/cards/energy-es-rank_card.md. Approval covers exactly the prior
twelve completed broker calendar months; simple D1 returns; the mean of the
lowest ceil(N times 0.05) returns; higher-ES-versus-lower-ES XTI/XNG direction;
monthly cadence; equal fixed-risk paired package; frozen ATR hard stops;
next-month and stale exits; same-month deal-history guard; and orphan cleanup.

Approval preserves weak full-sample one-way source significance,
broad-futures-to-two-CFD narrowing, continuous-CFD basis, tail-estimator
sampling, gaps, legging, and costs as binding Q02 kill risks. Live artifacts,
portfolio admission, and portfolio-gate changes are not approved.
