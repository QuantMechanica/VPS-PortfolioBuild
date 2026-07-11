---
copy_of: strategy-seeds/cards/energy-cv-rank_card.md
strategy_id: SZYMANOWSKA-CV-2014_XTI_XNG_S01
source_id: SZYMANOWSKA-CV-2014
ea_id: QM5_13139
slug: energy-cv-rank
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13139_XTI_XNG_CV_D1
period: D1
expected_trades_per_year_per_symbol: 6
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# Approved Card Copy - QM5_13139_energy-cv-rank

The canonical approved card is
`strategy-seeds/cards/energy-cv-rank_card.md`. Approval covers exactly the 36
completed monthly log-return formula, sample variance divided by absolute mean,
high-CV-versus-low-CV XTI/XNG rank, odd-month bimonthly cadence, equal half-risk
paired package, ATR hard stops, next-period/stale exits, same-period deal-
history guard, and orphan cleanup.

Approval preserves the broad-futures-to-two-CFD narrowing, missing maturity
decomposition, 2010 source end date, and six-package annual density as binding
Q02 kill risks. No live artifact or portfolio admission is approved.
