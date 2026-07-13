---
copy_of: strategy-seeds/cards/energy-jumpbeta_card.md
strategy_id: HOLLSTEIN-AGGJUMP-2021_XTI_XNG_S01
source_id: HOLLSTEIN-AGGJUMP-2021
ea_id: QM5_13147
slug: energy-jumpbeta
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13147_XTI_XNG_JBETA_D1
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# Approved Card Copy - QM5_13147_energy-jumpbeta

The canonical approved card is
`strategy-seeds/cards/energy-jumpbeta_card.md`. Approval covers exactly 252
synchronized completed D1 returns; a fixed inverse-volatility XTI/XNG energy
benchmark; a locked two-standard-deviation realized-jump factor; separate OLS
regressions controlling for continuous energy return; low-jump-beta versus
high-jump-beta direction; monthly cadence; equal fixed-risk paired package;
frozen ATR hard stops; next-month and stale exits; same-month deal-history
guard; and orphan cleanup.

Approval preserves the option-factor-to-realized-energy substitution,
endogenous two-CFD factor, D1 jump approximation, continuous-CFD basis, gaps,
legging, and costs as binding Q02 kill risks. Live artifacts, portfolio
admission, and portfolio-gate changes are not approved.
