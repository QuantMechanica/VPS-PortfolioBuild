---
copy_of: strategy-seeds/cards/energy-ie-rank_card.md
strategy_id: HAN-IE-2023_XTI_XNG_S01
source_id: HAN-IE-2023
ea_id: QM5_13141
slug: energy-ie-rank
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13141_XTI_XNG_IE_D1
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
---

# Approved Card Copy - QM5_13141_energy-ie-rank

The canonical approved card is
`strategy-seeds/cards/energy-ie-rank_card.md`. Approval covers exactly the
six-completed-month, four-CFD equal-weight factor; intercept, linear, and
squared-return OLS residualization; empirical `+/-0.5` standardized residual
tail counts; low-IE-versus-high-IE XTI/XNG direction; monthly cadence;
approximately equal-notional paired package; fixed-risk ATR hard stops;
next-month and stale exits; same-month deal-history guard; and orphan cleanup.

Approval preserves the source S&P GSCI versus four-CFD proxy, 27 futures versus
two traded CFDs, benchmark endogeneity, continuous-CFD basis, regression
condition, history synchronization, rounding, and costs as binding Q02 kill
risks. Live artifacts, portfolio admission, and portfolio-gate changes are not
approved.
