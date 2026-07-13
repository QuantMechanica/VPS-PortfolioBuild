---
copy_of: strategy-seeds/cards/energy-idmom_card.md
strategy_id: SHPAK-IDMOM-2017_XTI_XNG_S01
source_id: SHPAK-IDMOM-2017
ea_id: QM5_13145
slug: energy-idmom
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13145_ENERGY_IDMOM_D1
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
---

# Approved Card Copy - QM5_13145_energy-idmom

The canonical approved card is
`strategy-seeds/cards/energy-idmom_card.md`. Approval covers exactly eleven
completed monthly returns; the fixed equal-weight XTI/XNG/XAU/XAG market
factor; closed-window OLS beta; cumulative alpha-not-subtracted residual-return
rank; higher-versus-lower XTI/XNG direction; monthly cadence; equal fixed-risk
paired package; frozen ATR hard stops; next-month/stale exits; restart guard;
and orphan cleanup.

Approval preserves working-paper source quality, omitted term-structure/size
factors, four-CFD benchmark substitution, futures/CFD basis, two-name breadth,
gaps, legging, and costs as binding Q02 kill risks. Live artifacts, portfolio
admission, and portfolio-gate changes are not approved.
