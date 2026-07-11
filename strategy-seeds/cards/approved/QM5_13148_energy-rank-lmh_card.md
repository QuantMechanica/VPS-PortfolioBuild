---
copy_of: strategy-seeds/cards/energy-rank-lmh_card.md
strategy_id: FERNHOLZ-KOCH-RANK-2016_XTI_XNG_S01
source_id: FERNHOLZ-KOCH-RANK-2016
ea_id: QM5_13148
slug: energy-rank-lmh
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13148_XTI_XNG_RANK_LMH_D1
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# Approved Card Copy - QM5_13148_energy-rank-lmh

The canonical approved card is
`strategy-seeds/cards/energy-rank-lmh_card.md`. Approval covers exactly the
locked 2017-01-03 normalization origin; seven-day anchor bound; common anchor
and completed endpoint timestamps; 20-bar post-anchor warm-up; direct
low-normalized-price versus high-normalized-price direction; monthly cadence;
equal fixed-risk paired package; frozen ATR hard stops; next-month and stale
exits; same-month deal-history guard; and orphan cleanup.

Approval preserves the broad-futures-to-two-CFD narrowing, daily-to-monthly
translation, fixed-origin dependence, continuous-CFD basis, financing, gaps,
legging, and costs as binding Q02 kill risks. Live artifacts, portfolio
admission, and portfolio-gate changes are not approved.
