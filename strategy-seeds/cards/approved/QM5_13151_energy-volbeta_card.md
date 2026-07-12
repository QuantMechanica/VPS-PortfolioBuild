---
copy_of: strategy-seeds/cards/energy-volbeta_card.md
strategy_id: HOLLSTEIN-AGGVOL-2021_XTI_XNG_S01
source_id: HOLLSTEIN-AGGVOL-2021
ea_id: QM5_13151
slug: energy-volbeta
status: APPROVED
g0_status: APPROVED
created: 2026-07-12
created_by: Research
last_updated: 2026-07-12
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13151_XTI_XNG_VBETA_D1
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# Approved Card Copy - QM5_13151_energy-volbeta

The canonical approved card is
`strategy-seeds/cards/energy-volbeta_card.md`. Approval covers exactly 272
synchronized completed D1 returns; a 20-return realized-volatility warm-up;
fixed inverse-volatility XTI/XNG benchmark; two-sigma return-jump exclusion;
market-controlled OLS smooth-volatility beta; high-beta versus low-beta monthly
basket; equal fixed-risk halves; frozen ATR hard stops; next-month and stale
exits; same-month deal-history guard; and orphan cleanup.

Approval preserves the option-factor-to-realized-volatility substitution,
endogenous two-CFD factor, return-based smooth/jump separation, continuous-CFD
basis, gaps, legging, and costs as binding Q02 kill risks. Live artifacts,
portfolio admission, and portfolio-gate changes are not approved. Q01 passed
and Q02 work item `d792f306-3b9c-4ff6-b317-61c1137e6c92` is pending.
