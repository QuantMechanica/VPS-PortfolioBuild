---
copy_of: strategy-seeds/cards/energy-sal-rank_card.md
strategy_id: HE-SALIENCE-2025_XTI_XNG_S01
source_id: HE-SALIENCE-2025
ea_id: QM5_13142
slug: energy-sal-rank
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13142_XTI_XNG_SAL_D1
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
---

# Approved Card Copy - QM5_13142_energy-sal-rank

The canonical approved card is
`strategy-seeds/cards/energy-sal-rank_card.md`. Approval covers exactly the
immediately prior complete broker month; synchronized simple XTI/XNG/XAU/XAG
returns; four-CFD equal-weight reference payoff; source constants theta 0.1
and delta 0.7; deterministic descending salience ranks; normalized weights;
population weight-return covariance; high-ST-versus-low-ST XTI/XNG direction;
monthly cadence; approximately equal-notional paired package; fixed-risk ATR
hard stops; next-month and stale exits; same-month deal-history guard; and
orphan cleanup.

Approval preserves the author-uploaded preprint status, broad futures universe
versus two traded CFDs, four-CFD reference endogeneity, continuous-CFD basis,
history synchronization, rank ties, rounding, and costs as binding Q02 kill
risks. Live artifacts, portfolio admission, and portfolio-gate changes are not
approved.
